import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/domain/kit_clash.dart';
import 'package:gedfa_connect/features/fixtures/domain/postpone_job.dart';
import 'package:gedfa_connect/features/fixtures/domain/postpone_plan.dart';
import 'package:gedfa_connect/features/fixtures/domain/season_plan.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/team_colours.dart';

const _timeout = Duration(seconds: 15);

/// A team as a match needs it, read fresh from its team document when the
/// FA saves: the copy for the match (the rules compare it with the team)
/// and the kits of the competition, exactly as stored.
class MatchTeam {
  const MatchTeam({
    required this.side,
    required this.rawKits,
    required this.kits,
    required this.homeGround,
    this.colours,
  });

  final FixtureSide side;

  /// The kits of this competition exactly as on the team document.
  final Map<String, Map<String, dynamic>> rawKits;
  final Map<KitSlot, Kit> kits;
  final TeamColours? colours;
  final String homeGround;

  TeamKits get teamKits => TeamKits(kits: kits, colours: colours);

  /// The match's copy of one of this team's kits.
  KitChoice choice(KitSlot slot) =>
      KitChoice(slot: slot, kit: kits[slot]!, raw: rawKits[slot.name]!);

  static MatchTeam fromTeamDoc(
    String id,
    Map<String, dynamic> data,
    Competition category,
  ) {
    // A club in both competitions has separate juvenile kits (2.13b)
    final juvenile = (data['juvenileKits'] as Map<String, dynamic>?) ?? {};
    final source = category == Competition.juvenile && juvenile.isNotEmpty
        ? juvenile
        : (data['kits'] as Map<String, dynamic>?) ?? {};
    final rawKits = {
      for (final e in source.entries)
        if (e.value is Map<String, dynamic>)
          e.key: e.value as Map<String, dynamic>,
    };
    final kits = <KitSlot, Kit>{
      for (final slot in KitSlot.values)
        if (rawKits[slot.name] case final raw?) slot: ?Kit.fromMap(raw),
    };
    final colours = TeamColours.fromMap(
      data['colours'] as Map<String, dynamic>?,
    );
    return MatchTeam(
      side: FixtureSide(
        id: id,
        name: data['name'] as String? ?? '',
        shortName: data['shortName'] as String? ?? '',
        logoUrl: data['logoUrl'] as String?,
        colour:
            colours?.home.main ??
            kits[KitSlot.home]?.primary ??
            const Color(0xFF1E88E5),
      ),
      rawKits: rawKits,
      kits: kits,
      colours: colours,
      homeGround: data['homeGround'] as String? ?? '',
    );
  }
}

/// What the FA fills in for a match (add or change).
class FixtureDraft {
  const FixtureDraft({
    required this.category,
    required this.round,
    required this.home,
    required this.away,
    required this.kickoffAt,
    required this.venue,
    required this.kits,
    this.ageGroup,
  });

  final Competition category;
  final AgeGroup? ageGroup;
  final int round;
  final MatchTeam home;
  final MatchTeam away;
  final DateTime kickoffAt;
  final String venue;

  /// Which kit each side wears (from [planKits], or the FA's choice).
  final ({KitSlot home, KitSlot away, KitSlot homeGk, KitSlot awayGk}) kits;

  MatchKits get matchKits => MatchKits(
    home: home.choice(kits.home),
    away: away.choice(kits.away),
    homeGk: home.choice(kits.homeGk),
    awayGk: away.choice(kits.awayGk),
  );
}

/// Matches (3.0a). Every save writes the match, a line in its history and
/// a note in each team's bell in ONE batch: all of it, or none of it.
class FixtureRepository {
  FixtureRepository(this._db);

  final FirebaseFirestore _db;

  CollectionReference<Map<String, dynamic>> get _fixtures =>
      _db.collection(FirestorePaths.fixtures);

  List<Fixture> _read(QuerySnapshot<Map<String, dynamic>> snap) => [
    for (final doc in snap.docs) ?Fixture.fromMap(doc.id, doc.data()),
  ];

  /// FA: every match of the season.
  Stream<List<Fixture>> watchSeason(String season) =>
      _fixtures.where('season', isEqualTo: season).snapshots().map(_read);

  /// A team's matches (this season, filtered in the app so no extra index
  /// is needed).
  Stream<List<Fixture>> watchForTeam(String teamId, String season) => _fixtures
      .where('teamIds', arrayContains: teamId)
      .snapshots()
      .map((snap) => _read(snap).where((f) => f.season == season).toList());

  Stream<Fixture?> watchOne(String id) =>
      _fixtures.doc(id).snapshots().map((doc) {
        final data = doc.data();
        return data == null ? null : Fixture.fromMap(doc.id, data);
      });

  /// FA: a team as a match needs it, read fresh.
  Future<MatchTeam> loadTeam(String teamId, Competition category) async {
    final doc = await _db
        .doc(FirestorePaths.team(teamId))
        .get()
        .timeout(_timeout);
    return MatchTeam.fromTeamDoc(doc.id, doc.data() ?? {}, category);
  }

  /// "Add one match": the match, its first history line, and "New match"
  /// in both teams' bells.
  Future<void> add(FixtureDraft d, {required User by}) {
    final ref = _fixtures.doc();
    final batch = _db.batch()..set(ref, _newFixture(d, by));
    _history(batch, ref.id, 'Match added', null, by);
    for (final team in [d.home.side, d.away.side]) {
      _notify(
        batch,
        NotificationKind.fixtureAdded,
        team,
        _line(team.id, d.round, d.home.side, d.away.side, d.kickoffAt),
      );
    }
    return batch.commit().timeout(_timeout);
  }

  /// "Publish and tell all teams" (3.0b): a whole season of matches.
  ///
  /// The rules may look up only about 20 documents per save, so the
  /// matches go up 3 at a time. Each match has a fixed ID (draft, matchday
  /// and teams), so publishing again after a lost connection skips the
  /// ones already saved and carries on. Each team then gets ONE note
  /// ("34 matches, the first …"), and the saved draft is removed.
  Future<void> publishSeason({
    required String draftId,
    required String leagueName,
    required List<FixtureDraft> matches,
    required User by,
    void Function(int done, int total)? onProgress,
  }) async {
    if (matches.isEmpty) return;
    final competitionId = Fixture.leagueId(
      Season.current,
      matches.first.category,
    );
    final existing = {
      for (final doc
          in (await _fixtures
                  .where('competitionId', isEqualTo: competitionId)
                  .get()
                  .timeout(_timeout))
              .docs)
        doc.id,
    };
    String idOf(FixtureDraft d) =>
        '${draftId}_md${d.round}_${d.home.side.id}_v_${d.away.side.id}';

    final todo = [
      for (final d in matches)
        if (!existing.contains(idOf(d))) d,
    ];
    var done = matches.length - todo.length;
    onProgress?.call(done, matches.length);
    for (var i = 0; i < todo.length; i += 3) {
      final batch = _db.batch();
      for (final d in todo.skip(i).take(3)) {
        batch.set(_fixtures.doc(idOf(d)), _newFixture(d, by));
      }
      await batch.commit().timeout(_timeout);
      done += todo.skip(i).take(3).length;
      onProgress?.call(done, matches.length);
    }

    // One note per team: how many matches, and the first one
    final byTeam = <String, List<FixtureDraft>>{};
    final sides = <String, FixtureSide>{};
    for (final d in matches) {
      for (final side in [d.home.side, d.away.side]) {
        byTeam.putIfAbsent(side.id, () => []).add(d);
        sides[side.id] = side;
      }
    }
    final teamIds = byTeam.keys.toList();
    for (var i = 0; i < teamIds.length; i += 9) {
      final batch = _db.batch();
      for (final id in teamIds.skip(i).take(9)) {
        final list = byTeam[id]!
          ..sort((a, b) => a.kickoffAt.compareTo(b.kickoffAt));
        final first = list.first;
        final other = first.home.side.id == id
            ? first.away.side
            : first.home.side;
        _notify(
          batch,
          NotificationKind.fixtureAdded,
          sides[id]!,
          '$leagueName: ${list.length} matches, the first v ${other.name} '
          'on ${formatShortDate(first.kickoffAt)}',
        );
      }
      if (i + 9 >= teamIds.length) {
        batch.delete(_db.doc(FirestorePaths.fixtureDraft(draftId)));
      }
      await batch.commit().timeout(_timeout);
    }
  }

  // ---------- "Make the season" drafts (3.0b) ----------

  /// FA: every approved team in [category], read fresh, A to Z.
  Future<List<MatchTeam>> loadTeams(Competition category) async {
    final snap = await _db
        .collection(FirestorePaths.teams)
        .get()
        .timeout(_timeout);
    final teams =
        [
          for (final doc in snap.docs)
            if (Competition.fromList(
              doc.data()['categories'] as List<dynamic>?,
            ).contains(category))
              MatchTeam.fromTeamDoc(doc.id, doc.data(), category),
        ]..sort(
          (a, b) =>
              a.side.name.toLowerCase().compareTo(b.side.name.toLowerCase()),
        );
    return teams;
  }

  Stream<Map<String, dynamic>?> watchDraft(String draftId) => _db
      .doc(FirestorePaths.fixtureDraft(draftId))
      .snapshots()
      .map((doc) => doc.data());

  /// "Save the draft for later" (FA only).
  Future<void> saveDraft({
    required String draftId,
    required Competition category,
    required AgeGroup? ageGroup,
    required SeasonSettings settings,
    required List<String> teamIds,
    required List<DraftMatch> matches,
    required User by,
  }) {
    return _db
        .doc(FirestorePaths.fixtureDraft(draftId))
        .set({
          'season': Season.current,
          'competitionId': Fixture.leagueId(Season.current, category),
          'category': category.name,
          'ageGroup': ?ageGroup?.label,
          'settings': settings.toMap(),
          'teamIds': teamIds,
          'matches': [for (final m in matches) m.toMap()],
          'updatedBy': by.uid,
          'updatedAt': FieldValue.serverTimestamp(),
        })
        .timeout(_timeout);
  }

  Future<void> deleteDraft(String draftId) =>
      _db.doc(FirestorePaths.fixtureDraft(draftId)).delete().timeout(_timeout);

  /// A new match, as [add] and [publishSeason] write it.
  Map<String, dynamic> _newFixture(FixtureDraft d, User by) => {
    ..._fields(d, status: FixtureStatus.scheduled, note: null, by: by),
    'season': Season.current,
    'competitionId': Fixture.leagueId(Season.current, d.category),
    'category': d.category.name,
    'ageGroup': ?d.ageGroup?.label,
    'createdBy': by.uid,
    'createdAt': FieldValue.serverTimestamp(),
  };

  /// "Change a match": anything but the competition. Teams that leave the
  /// match are told too.
  Future<void> change(
    Fixture old,
    FixtureDraft d, {
    required String reason,
    required User by,
  }) {
    final what = _changes(old, d);
    final batch = _db.batch()
      ..update(
        _fixtures.doc(old.id),
        _fields(
          d,
          status: FixtureStatus.scheduled,
          note: reason.trim().isEmpty ? null : reason.trim(),
          by: by,
        ),
      );
    _history(batch, old.id, what, reason, by);
    final told = <String>{};
    for (final team in [d.home.side, d.away.side, old.home, old.away]) {
      if (!told.add(team.id)) continue;
      _notify(
        batch,
        NotificationKind.fixtureChanged,
        team,
        '${_line(team.id, d.round, d.home.side, d.away.side, d.kickoffAt)}'
        '${reason.trim().isEmpty ? '' : '. ${_sentence(reason)}'}',
      );
    }
    return batch.commit().timeout(_timeout);
  }

  /// The match's copy of both teams, read again: a team may have changed
  /// its name, logo or kits since the match was saved, and the rules want
  /// the copy to match the team. Each side keeps its kit if it still has it.
  Future<Map<String, dynamic>> _freshTeams(Fixture f) async {
    final home = await loadTeam(f.home.id, f.category);
    final away = await loadTeam(f.away.id, f.category);
    return _freshCopy(f, home, away);
  }

  Map<String, dynamic> _freshCopy(Fixture f, MatchTeam home, MatchTeam away) {
    KitChoice keep(MatchTeam team, KitSlot slot, KitSlot fallback) =>
        team.choice(team.kits[slot] != null ? slot : fallback);
    return {
      'home': home.side.toMap(),
      'away': away.side.toMap(),
      'kits': MatchKits(
        home: keep(home, f.kits.home.slot, KitSlot.home),
        away: keep(away, f.kits.away.slot, KitSlot.away),
        homeGk: keep(home, f.kits.homeGk.slot, KitSlot.goalkeeper),
        awayGk: keep(away, f.kits.awayGk.slot, KitSlot.goalkeeper),
      ).toMap(),
    };
  }

  /// Postponed with a reason; with [newKickoff] the new date is set at once.
  Future<void> postpone(
    Fixture f, {
    required String reason,
    DateTime? newKickoff,
    required User by,
  }) async {
    final fresh = await _freshTeams(f);
    final batch = _db.batch()
      ..update(_fixtures.doc(f.id), {
        ...fresh,
        'status': newKickoff == null
            ? FixtureStatus.postponed.name
            : FixtureStatus.scheduled.name,
        'kickoffAt': newKickoff == null ? null : Timestamp.fromDate(newKickoff),
        'note': reason.trim(),
        ..._stamp(by),
      });
    final when = newKickoff == null
        ? 'new date to come'
        : 'now ${formatShortDate(newKickoff)}, ${formatTime(newKickoff)}';
    _history(batch, f.id, 'Postponed ($when)', reason, by);
    for (final team in [f.home, f.away]) {
      _notify(
        batch,
        NotificationKind.fixturePostponed,
        team,
        '${_vs(team.id, f)}: postponed, $when. ${_sentence(reason)}',
      );
    }
    return batch.commit().timeout(_timeout);
  }

  /// "Postpone" a league (3.0c1c, mockup C11): saves the job first
  /// (3.0c1d), every match in [plan] with its new kick-off, before
  /// anything moves. The rules refuse a second job for the same league
  /// while one is there. Then [finishPostpone] moves the matches.
  Future<PostponeJob> startPostpone(
    PostponePlan plan, {
    required String competitionName,
    required String reason,
    required User by,
  }) async {
    final name = by.displayName?.trim();
    final job = PostponeJob.fromPlan(
      plan,
      name: competitionName,
      reason: reason,
      byName: name == null || name.isEmpty ? (by.email ?? 'FA') : name,
    );
    await _db
        .doc(FirestorePaths.postponeJob(job.competitionId))
        .set({
          ...job.toMap(),
          'startedBy': by.uid,
          'startedAt': FieldValue.serverTimestamp(),
          ..._stamp(by),
        })
        .timeout(_timeout);
    return job;
  }

  /// Moves the matches of [job] not moved yet (3.0c1c, 3.0c1d, mockups
  /// C12, C15), each with a line in its history and ticked off in the job
  /// in the same batch. The rules look up both teams of every match, so
  /// they go 3 at a time. A match changed by hand since is left as it is.
  /// Then each team gets ONE note (its next match and the reason), and the
  /// job is removed with the last notes.
  Future<void> finishPostpone(
    PostponeJob job, {
    required User by,
    void Function(int done, int total)? onProgress,
  }) async {
    final jobRef = _db.doc(FirestorePaths.postponeJob(job.competitionId));
    final total = job.moves.length;
    final now = {
      for (final doc
          in (await _fixtures
                  .where('competitionId', isEqualTo: job.competitionId)
                  .get()
                  .timeout(_timeout))
              .docs)
        doc.id: ?Fixture.fromMap(doc.id, doc.data()),
    };
    final todo = <(Fixture, PostponeMove)>[];
    final skipped = <String>[];
    for (final m in job.left) {
      final f = now[m.id];
      if (f != null && f.isScheduled && f.kickoffAt == m.from) {
        todo.add((f, m));
      } else {
        // Already at its new date, or changed by hand since
        skipped.add(m.id);
      }
    }
    var done = job.movedCount;
    onProgress?.call(done, total);
    if (skipped.isNotEmpty) {
      await jobRef
          .update({'done': FieldValue.arrayUnion(skipped), ..._stamp(by)})
          .timeout(_timeout);
      done += skipped.length;
      onProgress?.call(done, total);
    }

    // Each team read once, fresh (the copy in the match must match it)
    final teams = <String, MatchTeam>{};
    Future<MatchTeam> team(String id, Competition category) async =>
        teams['$id:${category.name}'] ??= await loadTeam(id, category);

    String when(DateTime t) => '${formatShortDate(t)}, ${formatTime(t)}';
    for (var i = 0; i < todo.length; i += 3) {
      final part = todo.skip(i).take(3).toList();
      final batch = _db.batch();
      for (final (f, m) in part) {
        batch.update(_fixtures.doc(f.id), {
          ..._freshCopy(
            f,
            await team(f.home.id, f.category),
            await team(f.away.id, f.category),
          ),
          'kickoffAt': Timestamp.fromDate(m.to),
          'note': job.reason,
          ..._stamp(by),
        });
        _history(
          batch,
          f.id,
          '${job.name} postponed: ${when(m.from)} → ${when(m.to)}',
          job.reason,
          by,
        );
      }
      batch.update(jobRef, {
        'done': FieldValue.arrayUnion([for (final (f, _) in part) f.id]),
        ..._stamp(by),
      });
      await batch.commit().timeout(_timeout);
      done += part.length;
      onProgress?.call(done, total);
    }

    // One note per team, with its next match; the job goes with the last
    final next = <String, (Fixture, PostponeMove)>{};
    for (final m in job.moves) {
      final f = now[m.id];
      if (f == null || f.isCancelled) continue;
      next.putIfAbsent(f.home.id, () => (f, m));
      next.putIfAbsent(f.away.id, () => (f, m));
    }
    final teamIds = next.keys.toList();
    for (var i = 0; i == 0 || i < teamIds.length; i += 9) {
      final batch = _db.batch();
      for (final id in teamIds.skip(i).take(9)) {
        final (f, m) = next[id]!;
        _notify(
          batch,
          NotificationKind.fixturePostponed,
          f.isHome(id) ? f.home : f.away,
          '${job.name} postponed ${laterLabel(job.days)}: '
          '${_vs(id, f)} now ${when(m.to)}. ${_sentence(job.reason)}',
        );
      }
      if (i + 9 >= teamIds.length) batch.delete(jobRef);
      await batch.commit().timeout(_timeout);
    }
  }

  /// A postponed match gets its new date.
  Future<void> setNewDate(
    Fixture f, {
    required DateTime kickoff,
    required User by,
  }) async {
    final fresh = await _freshTeams(f);
    final batch = _db.batch()
      ..update(_fixtures.doc(f.id), {
        ...fresh,
        'status': FixtureStatus.scheduled.name,
        'kickoffAt': Timestamp.fromDate(kickoff),
        ..._stamp(by),
      });
    final when = '${formatShortDate(kickoff)}, ${formatTime(kickoff)}';
    _history(batch, f.id, 'New date: $when', null, by);
    for (final team in [f.home, f.away]) {
      _notify(
        batch,
        NotificationKind.fixtureChanged,
        team,
        '${_vs(team.id, f)}: new date $when',
      );
    }
    return batch.commit().timeout(_timeout);
  }

  /// Called off for good, with a reason. It keeps its date.
  Future<void> cancel(
    Fixture f, {
    required String reason,
    required User by,
  }) async {
    final fresh = await _freshTeams(f);
    final batch = _db.batch()
      ..update(_fixtures.doc(f.id), {
        ...fresh,
        'status': FixtureStatus.cancelled.name,
        'note': reason.trim(),
        ..._stamp(by),
      });
    _history(batch, f.id, 'Cancelled', reason, by);
    for (final team in [f.home, f.away]) {
      _notify(
        batch,
        NotificationKind.fixtureCancelled,
        team,
        '${_vs(team.id, f)}: cancelled. ${_sentence(reason)}',
      );
    }
    return batch.commit().timeout(_timeout);
  }

  // ---------- Helpers ----------

  Map<String, dynamic> _fields(
    FixtureDraft d, {
    required FixtureStatus status,
    required String? note,
    required User by,
  }) => {
    'round': d.round,
    'teamIds': [d.home.side.id, d.away.side.id],
    'home': d.home.side.toMap(),
    'away': d.away.side.toMap(),
    'kits': d.matchKits.toMap(),
    'kickoffAt': Timestamp.fromDate(d.kickoffAt),
    'venue': d.venue.trim(),
    'status': status.name,
    'note': note,
    ..._stamp(by),
  };

  Map<String, dynamic> _stamp(User by) => {
    'updatedBy': by.uid,
    'updatedAt': FieldValue.serverTimestamp(),
  };

  void _history(
    WriteBatch batch,
    String fixtureId,
    String what,
    String? reason,
    User by,
  ) {
    final name = by.displayName?.trim();
    batch.set(_db.collection(FirestorePaths.fixtureHistory(fixtureId)).doc(), {
      'what': what.length > 400 ? '${what.substring(0, 397)}...' : what,
      if (reason != null && reason.trim().isNotEmpty) 'reason': reason.trim(),
      'by': by.uid,
      'byName': name == null || name.isEmpty ? (by.email ?? 'FA') : name,
      'at': FieldValue.serverTimestamp(),
    });
  }

  void _notify(
    WriteBatch batch,
    NotificationKind kind,
    FixtureSide team,
    String line,
  ) {
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: kind,
      teamId: team.id,
      teamName: team.name,
      name: line,
    );
  }

  /// "Matchday 4: v Gomoa Royals (home), Sat 14 Nov, 3:00 pm", as the
  /// team [teamId] reads it.
  static String _line(
    String teamId,
    int round,
    FixtureSide home,
    FixtureSide away,
    DateTime kickoff,
  ) {
    final isHome = home.id == teamId;
    final other = isHome ? away : home;
    return 'Matchday $round: v ${other.name} (${isHome ? 'home' : 'away'}), '
        '${formatShortDate(kickoff)}, ${formatTime(kickoff)}';
  }

  /// "v Gomoa Royals (Matchday 4)"
  static String _vs(String teamId, Fixture f) =>
      'v ${f.opponentOf(teamId).name} (Matchday ${f.round})';

  /// "Pitch waterlogged." (one full stop, even if they typed one)
  static String _sentence(String text) =>
      '${text.trim().replaceAll(RegExp(r'[.!\s]+$'), '')}.';

  /// "Kick-off: Sat 14 Nov, 3:00 pm → Sun 15 Nov, 4:00 pm; Venue: …"
  static String _changes(Fixture old, FixtureDraft d) {
    String when(DateTime? t) =>
        t == null ? 'no date' : '${formatShortDate(t)}, ${formatTime(t)}';
    final parts = <String>[
      if (old.home.id == d.away.side.id && old.away.id == d.home.side.id)
        'Home and away swapped'
      else ...[
        if (old.home.id != d.home.side.id)
          'Home: ${old.home.name} → ${d.home.side.name}',
        if (old.away.id != d.away.side.id)
          'Away: ${old.away.name} → ${d.away.side.name}',
      ],
      if (old.kickoffAt != d.kickoffAt)
        'Kick-off: ${when(old.kickoffAt)} → ${when(d.kickoffAt)}',
      if (old.venue != d.venue.trim())
        'Venue: ${old.venue} → ${d.venue.trim()}',
      if (old.round != d.round) 'Matchday ${old.round} → ${d.round}',
      if (old.kits.home.slot != d.kits.home ||
          old.kits.away.slot != d.kits.away ||
          old.kits.homeGk.slot != d.kits.homeGk ||
          old.kits.awayGk.slot != d.kits.awayGk)
        'Kits changed',
    ];
    return parts.isEmpty ? 'Saved again (no change)' : parts.join('; ');
  }
}

final fixtureRepositoryProvider = Provider<FixtureRepository>((ref) {
  return FixtureRepository(ref.watch(firestoreProvider));
});

/// FA: every match of the live season.
final seasonFixturesProvider = StreamProvider<List<Fixture>>((ref) {
  return ref.watch(fixtureRepositoryProvider).watchSeason(Season.current);
});

/// FA: a team as a match needs it, read fresh for the form and the kits
/// screen. Key: (team ID, competition).
final matchTeamProvider = FutureProvider.autoDispose
    .family<MatchTeam, (String, Competition)>((ref, key) {
      return ref.watch(fixtureRepositoryProvider).loadTeam(key.$1, key.$2);
    });

/// One line of a match's history: what changed, why, when.
typedef FixtureChange = ({String what, String? reason, DateTime? at});

/// A match's history, newest first (Match details: "What changed").
final fixtureHistoryProvider = StreamProvider.autoDispose
    .family<List<FixtureChange>, String>((ref, id) {
      return ref
          .watch(firestoreProvider)
          .collection(FirestorePaths.fixtureHistory(id))
          .orderBy('at', descending: true)
          .snapshots()
          .map(
            (snap) => [
              for (final doc in snap.docs)
                (
                  what: doc.data()['what'] as String? ?? '',
                  reason: doc.data()['reason'] as String?,
                  at: (doc.data()['at'] as Timestamp?)?.toDate(),
                ),
            ],
          );
    });

/// FA: the season's postpones that are not finished (3.0c1d, C13), by
/// competition ID.
final postponeJobsProvider = StreamProvider<Map<String, PostponeJob>>((ref) {
  return ref
      .watch(firestoreProvider)
      .collection(FirestorePaths.postponeJobs)
      .where('season', isEqualTo: Season.current)
      .snapshots()
      .map(
        (snap) => {
          for (final doc in snap.docs)
            doc.id: ?PostponeJob.fromMap(doc.id, doc.data()),
        },
      );
});

/// One match, live (change and kits screens).
final fixtureProvider = StreamProvider.family<Fixture?, String>((ref, id) {
  return ref.watch(fixtureRepositoryProvider).watchOne(id);
});

/// The signed-in team admin's matches this season.
final myFixturesProvider = StreamProvider<List<Fixture>>((ref) async* {
  final appUser = await ref.watch(appUserProvider.future);
  final teamId = appUser?.teamId;
  if (teamId == null || teamId.isEmpty) {
    yield const [];
    return;
  }
  yield* ref
      .watch(fixtureRepositoryProvider)
      .watchForTeam(teamId, Season.current);
});
