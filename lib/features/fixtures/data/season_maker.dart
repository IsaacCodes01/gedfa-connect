import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/season.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/domain/kit_clash.dart';
import 'package:gedfa_connect/features/fixtures/domain/round_robin.dart';
import 'package:gedfa_connect/features/fixtures/domain/season_plan.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';

/// The season being made (3.0b): G1 sets it up, G2 shows and edits the
/// draft, then publishes it. Lives only on this phone until the FA saves
/// the draft for later or publishes.
class SeasonSession {
  const SeasonSession({
    required this.category,
    required this.group,
    required this.teams,
    required this.settings,
    required this.firstRound,
    required this.draft,
  });

  final Competition category;
  final AgeGroup? group;

  /// The chosen teams, in the (shuffled) order of the draw.
  final List<MatchTeam> teams;
  final SeasonSettings settings;
  final int firstRound;
  final SeasonDraft draft;

  /// '2026-27_division-league', or '…_juvenile-league_U15'
  String get draftId => draftIdFor(category, group);

  static String draftIdFor(Competition category, AgeGroup? group) =>
      '${Fixture.leagueId(Season.current, category)}'
      '${group == null ? '' : '_${group.label}'}';

  /// "Division League" or "Juvenile League U15"
  String get leagueName =>
      '${category.label} League${group == null ? '' : ' ${group!.label}'}';

  MatchTeam? team(String id) => teams.where((t) => t.side.id == id).firstOrNull;

  SeasonSession withDraft(SeasonDraft d) => SeasonSession(
        category: category,
        group: group,
        teams: teams,
        settings: settings,
        firstRound: firstRound,
        draft: d,
      );

  /// The matches as the repository saves them, each with its kits picked
  /// by GEDFA's rule (the FA can change them after publishing).
  List<FixtureDraft> toFixtureDrafts() => [
        for (final m in draft.matches)
          if ((team(m.homeId), team(m.awayId)) case (final h?, final a?))
            FixtureDraft(
              category: category,
              ageGroup: group,
              round: m.round,
              home: h,
              away: a,
              kickoffAt: m.kickoffAt,
              venue: m.venue,
              kits: _kits(h, a),
            ),
      ];

  static ({KitSlot home, KitSlot away, KitSlot homeGk, KitSlot awayGk})
      _kits(MatchTeam h, MatchTeam a) {
    final plan = planKits(
      home: h.teamKits,
      away: a.teamKits,
      homeName: h.side.name,
      awayName: a.side.name,
    );
    return (
      home: plan.home,
      away: plan.away,
      homeGk: plan.homeGk,
      awayGk: plan.awayGk,
    );
  }

  /// Matches whose away team has no kit that avoids a clash: the FA
  /// should choose their kits after publishing.
  int get kitProblems => toFixtureDrafts()
      .where((d) => !planKits(
            home: d.home.teamKits,
            away: d.away.teamKits,
            homeName: d.home.side.name,
            awayName: d.away.side.name,
          ).isClear)
      .length;
}

class SeasonMaker extends Notifier<SeasonSession?> {
  @override
  SeasonSession? build() => null;

  static List<PlanTeam> _planTeams(List<MatchTeam> teams) => [
        for (final t in teams)
          PlanTeam(id: t.side.id, name: t.side.name, ground: t.homeGround),
      ];

  /// "Make the draft": a new random order, then the round robin.
  void make({
    required Competition category,
    required AgeGroup? group,
    required List<MatchTeam> teams,
    required SeasonSettings settings,
    required int firstRound,
  }) {
    final order = shuffled(teams);
    state = SeasonSession(
      category: category,
      group: group,
      teams: order,
      settings: settings,
      firstRound: firstRound,
      draft: planSeason(
        teams: _planTeams(order),
        settings: settings,
        firstRound: firstRound,
      ),
    );
  }

  /// "Shuffle": the same settings, a new draw.
  void shuffle() {
    final s = state;
    if (s == null) return;
    make(
      category: s.category,
      group: s.group,
      teams: s.teams,
      settings: s.settings,
      firstRound: s.firstRound,
    );
  }

  /// The FA changed one match of the draft (swap, date, time, venue).
  void replace(DraftMatch old, DraftMatch updated) {
    final s = state;
    if (s == null) return;
    state = s.withDraft(SeasonDraft(
      matches: [
        for (final m in s.draft.matches) identical(m, old) ? updated : m,
      ],
      warnings: s.draft.warnings,
    ));
  }

  /// "Continue" a draft saved for later.
  void resume(SeasonSession session) => state = session;

  void clear() => state = null;
}

final seasonMakerProvider =
    NotifierProvider<SeasonMaker, SeasonSession?>(SeasonMaker.new);

/// FA: the approved teams of a competition, read fresh for the draw.
final seasonTeamsProvider = FutureProvider.autoDispose
    .family<List<MatchTeam>, Competition>((ref, category) {
  return ref.watch(fixtureRepositoryProvider).loadTeams(category);
});

/// The saved draft of a league (or juvenile age group), live; null if none.
final savedDraftProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, String>((ref, draftId) {
  return ref.watch(fixtureRepositoryProvider).watchDraft(draftId);
});
