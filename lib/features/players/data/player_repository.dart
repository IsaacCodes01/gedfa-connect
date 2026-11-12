import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/core/errors/app_error_messages.dart';
import 'package:gedfa_connect/core/utils/date_format.dart';
import 'package:gedfa_connect/core/utils/passport_photo.dart';
import 'package:gedfa_connect/core/utils/player_code.dart';
import 'package:gedfa_connect/core/utils/player_key.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/notifications/data/notification_writer.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';
import 'package:gedfa_connect/features/players/data/player_photos.dart';
import 'package:gedfa_connect/features/players/data/squad_list.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_request_repository.dart'
    show firebaseStorageProvider;

const _timeout = Duration(seconds: 15);
const _uploadTimeout = Duration(seconds: 60);

/// The important things that changed, in plain words.
/// Empty list = nothing that needs the FA again.
List<String> reapprovalChanges(
  Player before,
  Player after, {
  bool photoChanged = false,
}) {
  String clean(String name) =>
      name.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

  return [
    if (clean(before.fullName) != clean(after.fullName)) 'name',
    if (before.dob != after.dob) 'date of birth',
    if (before.jerseyNo != after.jerseyNo) 'jersey number',
    if (photoChanged) 'photo',
  ];
}

/// The team's changes since the FA last reviewed the player, merged with
/// any changes already waiting. Keeps the first "from" of each field, and
/// drops a field that was changed back.
Map<String, PlayerChange> changesSinceReview(
  Player before,
  Player after, {
  String? newPhotoUrl,
}) {
  final changes = {...before.changes};

  void note(String field, String from, String to) {
    if (from == to) return;
    final original = changes[field]?.from ?? from;
    if (original == to) {
      changes.remove(field);
    } else {
      changes[field] = PlayerChange(original, to);
    }
  }

  String clean(String name) => name.trim().replaceAll(RegExp(r'\s+'), ' ');
  note('fullName', clean(before.fullName), clean(after.fullName));
  note('dob', formatDate(before.dob), formatDate(after.dob));
  note('jerseyNo', '#${before.jerseyNo}', '#${after.jerseyNo}');
  note('position', before.position.display, after.position.display);
  if (newPhotoUrl != null) note('photo', before.photoUrl ?? '', newPhotoUrl);
  return changes;
}

/// True if a change to an approved player must go back to the FA.
bool needsReapproval(
  Player before,
  Player after, {
  bool photoChanged = false,
}) =>
    reapprovalChanges(before, after, photoChanged: photoChanged).isNotEmpty;

/// What the reservation check needs to know about a player. A record, so
/// two keys with the same values are equal (the provider below then
/// checks only once, not every time the players list updates).
typedef ReservationKey = ({
  String playerId,
  String teamId,
  String jerseyId,
  String playerKey,
});

ReservationKey reservationKeyOf(Player player) => (
      playerId: player.id,
      teamId: player.teamId,
      jerseyId: player.jerseyId,
      playerKey: player.playerKey,
    );

class PlayerRepository {
  PlayerRepository(this._db, this._storage);

  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _players =>
      _db.collection(FirestorePaths.players);

  /// `teams/{teamId}/jerseys/{division-10 | juvenile-U13-10}`.
  DocumentReference<Map<String, dynamic>> _jerseyRef(Player player) =>
      _db.doc(FirestorePaths.jersey(player.teamId, player.jerseyId));

  /// `settings/juvenileCounter`: `{ next: 5 }` (GJ26-0005 next, 2.14c).
  DocumentReference<Map<String, dynamic>> get _juvenileCounterRef =>
      _db.doc(FirestorePaths.juvenileCounter);

  /// `settings/playerCounter`: `{ next: 43 }`.
  DocumentReference<Map<String, dynamic>> get _counterRef =>
      _db.doc(FirestorePaths.playerCounter);

  /// `playerKeys/{name_dob}` for this player.
  DocumentReference<Map<String, dynamic>> _keyRef(Player player) =>
      _db.doc(FirestorePaths.playerKey(player.playerKey));

  // ---------- Reading ----------

  /// All players of one team, live, sorted by jersey number.
  /// Sorting happens in the app, so Firestore needs no extra index.
  Stream<List<Player>> watchTeam(String teamId) {
    return _players
        .where('teamId', isEqualTo: teamId)
        .snapshots()
        .map((snapshot) {
      final players = [
        for (final doc in snapshot.docs) Player.fromMap(doc.id, doc.data()),
      ];
      players.sort((a, b) => a.jerseyNo.compareTo(b.jerseyNo));
      return players;
    });
  }

  /// One player, live. Gives null if it was deleted.
  Stream<Player?> watch(String playerId) {
    return _db.doc(FirestorePaths.player(playerId)).snapshots().map(
      (snapshot) {
        final data = snapshot.data();
        if (!snapshot.exists || data == null) return null;
        return Player.fromMap(snapshot.id, data);
      },
    );
  }

  /// FA: every player in the district, live. The Players tab groups them
  /// by team in the app, so this is the only query it needs.
  Stream<List<Player>> watchAll() {
    return _players.snapshots().map((snapshot) => [
          for (final doc in snapshot.docs) Player.fromMap(doc.id, doc.data()),
        ]);
  }

  /// FA: the number the next approved player gets (1 if nobody has been
  /// approved yet), live. Used to show "New player ID: GE26-0043".
  Stream<int> watchNextNumber() {
    return _counterRef.snapshots().map(
          (snapshot) => (snapshot.data()?['next'] as num?)?.toInt() ?? 1,
        );
  }

  /// FA: true if the player's jersey number and player key are both
  /// reserved for this player (the app's duplicate checks worked).
  Future<({bool jersey, bool key})> checkReservations(
    ReservationKey player,
  ) async {
    final results = await Future.wait([
      _db
          .doc(FirestorePaths.jersey(player.teamId, player.jerseyId))
          .get(),
      _db.doc(FirestorePaths.playerKey(player.playerKey)).get(),
    ]).timeout(_timeout);
    return (
      jersey: results[0].data()?['playerId'] == player.playerId,
      key: results[1].data()?['playerId'] == player.playerId,
    );
  }

  // ---------- Photos ----------

  /// Uploads the photo and thumbnail with a fresh file name each time
  /// (photo-<time>.jpg), so a new photo always gets a new link.
  Future<({String photoUrl, String thumbUrl})> _uploadPhoto({
    required String teamId,
    required String playerId,
    required ProcessedPhoto photo,
  }) async {
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final photoRef = _storage
        .ref(StoragePaths.playerFile(teamId, playerId, 'photo-$stamp.jpg'));
    final thumbRef = _storage
        .ref(StoragePaths.playerFile(teamId, playerId, 'thumb-$stamp.jpg'));
    final metadata = SettableMetadata(contentType: 'image/jpeg');

    await Future.wait([
      photoRef.putData(photo.full, metadata),
      thumbRef.putData(photo.thumb, metadata),
    ]).timeout(_uploadTimeout);

    return (
      photoUrl: await photoRef.getDownloadURL(),
      thumbUrl: await thumbRef.getDownloadURL(),
    );
  }

  /// Deletes old photo files. Best effort: a leftover file is harmless.
  Future<void> _deleteFiles(List<String?> urls) async {
    for (final url in urls) {
      if (url == null || url.isEmpty) continue;
      try {
        await _storage.refFromURL(url).delete();
      } catch (_) {
        // Already gone, or not ours to delete. Ignore.
      }
    }
  }

  // ---------- Checks ----------

  /// Throws a friendly error if the number or the person is already taken
  /// by someone other than [exceptPlayerId].
  Future<void> _checkFree(
    Player player, {
    String? exceptPlayerId,
    bool checkJersey = true,
    bool checkKey = true,
  }) async {
    if (checkJersey) {
      final jersey = await _jerseyRef(player).get().timeout(_timeout);
      if (jersey.exists && jersey.data()?['playerId'] != exceptPlayerId) {
        throw JerseyTakenException(player.jerseyNo);
      }
    }
    if (checkKey) {
      final key = await _keyRef(player).get().timeout(_timeout);
      if (key.exists && key.data()?['playerId'] != exceptPlayerId) {
        throw DuplicatePlayerException(
          sameTeam: key.data()?['teamId'] == player.teamId,
        );
      }
    }
  }

  /// Commits a batch. If the server refuses it, checks again whether
  /// someone took the number or the player meanwhile, to show a clear
  /// message instead of "not allowed".
  Future<void> _commit(
    WriteBatch batch,
    Future<void> Function() recheck,
  ) async {
    try {
      await batch.commit().timeout(_timeout);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') await recheck();
      rethrow;
    }
  }

  // ---------- Writing ----------

  /// Adds a new player as Pending: uploads the photo, then saves the
  /// player with their jersey and player-key reservations (all or none).
  /// Returns the new document ID.
  Future<String> create(Player player, {required ProcessedPhoto photo}) async {
    await _checkFree(player);

    final ref = _players.doc(); // Firestore makes the ID now
    final urls = await _uploadPhoto(
      teamId: player.teamId,
      playerId: ref.id,
      photo: photo,
    );

    final batch = _db.batch()
      ..set(ref, {
        ...player.toEditableMap(),
        'photoUrl': urls.photoUrl,
        'thumbUrl': urls.thumbUrl,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      })
      ..set(_jerseyRef(player), {
        'playerId': ref.id,
        'createdAt': FieldValue.serverTimestamp(),
      })
      ..set(_keyRef(player), {
        'playerId': ref.id,
        'teamId': player.teamId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    // The FA's bell: "4 new players from Royal Unique FC", or for
    // juvenile players "9 juvenile players from Royal Unique FC" (2.14b).
    // One note per team and day either way.
    NotificationWriter(_db).forFaInBatch(
      batch,
      kind: player.isJuvenile
          ? NotificationKind.juvenileSubmitted
          : NotificationKind.playersSubmitted,
      teamId: player.teamId,
      teamName: player.teamName,
      name: player.fullName.trim(),
    );

    try {
      await _commit(batch, () => _checkFree(player));
    } catch (_) {
      // The player wasn't saved, so remove the photo we just uploaded
      await _deleteFiles([urls.photoUrl, urls.thumbUrl]);
      rethrow;
    }
    return ref.id;
  }

  /// Saves changes. Uploads [newPhoto] if given. Moves the jersey and
  /// player-key reservations if the number, name or date of birth changed.
  /// An approved player stays approved only if nothing important changed.
  Future<void> update(
    Player before,
    Player after, {
    ProcessedPhoto? newPhoto,
  }) async {
    final photoChanged = newPhoto != null;
    // A juvenile player moving age group changes jersey reservation too
    final jerseyChanged = before.jerseyId != after.jerseyId;
    final keyChanged = before.playerKey != after.playerKey;
    final keepApproved = before.isApproved &&
        !needsReapproval(before, after, photoChanged: photoChanged);

    Future<void> check() => _checkFree(
          after,
          exceptPlayerId: before.id,
          checkJersey: jerseyChanged,
          checkKey: keyChanged,
        );
    await check();

    // An approved player going back to pending leaves their squad list in
    // the same batch (3.1a1; the rules insist). Read it first: a player
    // approved before the lists existed may not be on one.
    final squad = before.isApproved && !keepApproved
        ? squadRef(
            _db,
            before.teamId,
            squadGroupFor(before.category.name, before.ageGroup?.label),
          )
        : null;
    final leavesSquad = squad != null &&
        isOnSquad(await squad.get().timeout(_timeout), before.id);
    // A juvenile named for the Division leaves that list too (3.1d2): it
    // only holds approved juveniles, and the rules check it
    final divisionList = leavesSquad && before.isJuvenile
        ? squadRef(_db, before.teamId, 'divisionJuveniles')
        : null;
    final leavesDivisionList = divisionList != null &&
        ((await divisionList.get().timeout(_timeout)).data()?['players']
                as Map?)
            ?.containsKey(before.id) ==
            true;

    final urls = newPhoto == null
        ? null
        : await _uploadPhoto(
            teamId: before.teamId,
            playerId: before.id,
            photo: newPhoto,
          );

    // What changed, for the FA (2.3c). Kept while the player waits for
    // the FA after having been approved or rejected, so the FA sees
    // everything since their last look, not just the latest save.
    final recordChanges = !keepApproved &&
        (before.status != ApprovalStatus.pending || before.changes.isNotEmpty);
    final changes = recordChanges
        ? changesSinceReview(before, after, newPhotoUrl: urls?.photoUrl)
        : const <String, PlayerChange>{};
    // The FA compares the old and new photo, so the first old photo stays
    // until they have reviewed it (a leftover file is harmless).
    final keepOldPhoto = recordChanges &&
        urls != null &&
        !before.changes.containsKey('photo');

    final batch = _db.batch()
      ..update(_db.doc(FirestorePaths.player(before.id)), {
        ...after.toEditableMap(),
        if (urls != null) 'photoUrl': urls.photoUrl,
        if (urls != null) 'thumbUrl': urls.thumbUrl,
        'status': keepApproved ? 'approved' : 'pending',
        if (!keepApproved) 'rejectionReason': null,
        if (recordChanges)
          'changes': changes.isEmpty
              ? FieldValue.delete()
              : {for (final e in changes.entries) e.key: e.value.toMap()},
        'updatedAt': FieldValue.serverTimestamp(),
      });

    // The FA's bell, when a reviewed player comes back to them:
    // "Yaw Boateng: Jersey number #10 → #14"
    if (!keepApproved &&
        before.status != ApprovalStatus.pending &&
        !after.isJuvenile) {
      final first = changes.entries.firstOrNull;
      final what = first == null
          ? 'details updated'
          : first.key == 'photo'
              ? 'new photo'
              : '${PlayerChange.labels[first.key]} '
                  '${first.value.from} → ${first.value.to}';
      final more = changes.length > 1 ? ' (+${changes.length - 1} more)' : '';
      NotificationWriter(_db).forFaInBatch(
        batch,
        kind: NotificationKind.playersResubmitted,
        teamId: after.teamId,
        teamName: after.teamName,
        name: '${after.fullName.trim()}: $what$more',
      );
    }

    if (leavesSquad) batch.update(squad, squadRemoval(before.id));
    if (leavesDivisionList) {
      batch.update(divisionList, squadRemoval(before.id));
      NotificationWriter(_db).forFaInBatch(
        batch,
        kind: NotificationKind.divisionJuveniles,
        teamId: after.teamId,
        teamName: after.teamName,
        name: '− ${after.fullName.trim()} (${before.ageGroup?.label ?? ''}, '
            'corrected: waits for screening)',
      );
    }

    if (jerseyChanged) {
      batch
        ..delete(_jerseyRef(before))
        ..set(_jerseyRef(after), {
          'playerId': before.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
    }
    if (keyChanged) {
      batch
        ..delete(_keyRef(before))
        ..set(_keyRef(after), {
          'playerId': before.id,
          'teamId': after.teamId,
          'createdAt': FieldValue.serverTimestamp(),
        });
    }

    try {
      await _commit(batch, check);
    } catch (_) {
      if (urls != null) await _deleteFiles([urls.photoUrl, urls.thumbUrl]);
      rethrow;
    }

    // Saved: the old photo files are no longer used (unless the FA still
    // has to compare them, see keepOldPhoto)
    if (urls != null && !keepOldPhoto) {
      await _deleteFiles([before.photoUrl, before.thumbUrl]);
    }
  }

  // ---------- FA review ----------

  /// FA: approves a pending player and returns their player ID.
  ///
  /// Runs as a transaction (all or nothing, retried if two FA officials
  /// approve at the same moment):
  /// 1. Read the player. Stop if they are no longer pending.
  /// 2. A player approved before (then edited by the team) keeps their ID.
  ///    Otherwise read the counter, build the ID from it, and move the
  ///    counter on by 1.
  /// 3. Save the player as approved.
  Future<String> approve(String playerId, {required String faUid}) {
    final playerRef = _db.doc(FirestorePaths.player(playerId));

    return _db.runTransaction<String>((tx) async {
      final snapshot = await tx.get(playerRef);
      final data = snapshot.data();
      if (data == null || data['status'] != ApprovalStatus.pending.name) {
        throw const PlayerNotPendingException();
      }

      // The squad list the player goes on (3.1a1), read before any write
      final teamId = data['teamId'] as String? ?? '';
      final group = squadGroupFor(
        data['category'] as String? ?? '',
        data['ageGroup'] as String?,
      );
      final squad = squadRef(_db, teamId, group);
      final onSquad = isOnSquad(await tx.get(squad), playerId);

      var code = data['playerCode'] as String?;
      if (code == null) {
        final counter = await tx.get(_counterRef);
        final next = (counter.data()?['next'] as num?)?.toInt() ?? 1;
        code = playerCodeFor(next, DateTime.now().toUtc().year);
        if (counter.exists) {
          tx.update(_counterRef, {'next': next + 1});
        } else {
          tx.set(_counterRef, {'next': 2}); // the very first approval
        }
      }

      // The team's bell: "3 players approved: Kojo Arthur (GE26-0011), …"
      NotificationWriter(_db).forTeamInTransaction(
        tx,
        kind: NotificationKind.playersApproved,
        teamId: data['teamId'] as String? ?? '',
        teamName: data['teamName'] as String? ?? '',
        name: '${data['fullName']} ($code)',
      );

      tx.update(playerRef, {
        'status': ApprovalStatus.approved.name,
        'playerCode': code,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': faUid,
        'rejectionReason': null,
        'changes': FieldValue.delete(), // reviewed
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!onSquad) {
        tx.set(
          squad,
          squadAddition(teamId, group, playerId),
          SetOptions(merge: true),
        );
      }
      // The registered photo for the face check (3.6a), same write
      if (playerPhotoCopy(data) case final photo?) {
        tx.set(playerPhotoRef(_db, playerId), photo);
      }
      return code;
    }).timeout(_timeout);
  }

  /// FA: approves several players, one transaction each, in order.
  /// Keeps going if one fails. Returns the IDs given and how many failed.
  Future<({List<String> codes, int failed})> approveMany(
    List<String> playerIds, {
    required String faUid,
  }) async {
    final codes = <String>[];
    var failed = 0;
    for (final id in playerIds) {
      try {
        codes.add(await approve(id, faUid: faUid));
      } catch (_) {
        failed++;
      }
    }
    return (codes: codes, failed: failed);
  }

  /// FA: rejects a pending player. The team sees [reason] on the player.
  Future<void> reject(
    Player player, {
    required String reason,
    required String faUid,
  }) {
    final batch = _db.batch()
      ..update(_db.doc(FirestorePaths.player(player.id)), {
        'status': ApprovalStatus.rejected.name,
        'rejectionReason': reason.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': faUid,
        'changes': FieldValue.delete(), // reviewed
        'updatedAt': FieldValue.serverTimestamp(),
      });
    // The team's bell: "2 players rejected: …" (reasons are on the players)
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.playersRejected,
      teamId: player.teamId,
      teamName: player.teamName,
      name: player.fullName,
    );
    return batch.commit().timeout(_timeout);
  }

  // ---------- Juvenile screening (2.14c, board J4) ----------

  /// FA, on the screening day: passes a waiting child in [group] (their
  /// own group or an older one, never younger) and returns their ID.
  ///
  /// One transaction, like [approve]:
  /// 1. Read the child. Stop if they are no longer waiting.
  /// 2. Moving up (U13 -> U15)? Their jersey number must be free in the
  ///    new group; the reservation moves with them.
  /// 3. A new GJ26-… ID from the juvenile counter (kept if they had one).
  /// 4. Save the child as approved, in [group], and tell the team.
  ///
  /// [dayId] is the screening day the decision is made on (2.14d): the
  /// rules refuse it unless that day has started and covers the child.
  Future<String> passJuvenile(
    Player player, {
    required AgeGroup group,
    required String dayId,
    required String faUid,
  }) async {
    final playerRef = _db.doc(FirestorePaths.player(player.id));

    // Check the number BEFORE the transaction too. On the web, an error
    // thrown inside a transaction loses its type and arrives as a plain
    // "something went wrong", so the FA would not know why (Isaac,
    // 3 Nov 2026). The check inside stays as the safety net.
    final targetJerseyId = jerseyIdFor(
      player.category.name,
      player.jerseyNo,
      ageGroup: group.label,
    );
    if (targetJerseyId != player.jerseyId) {
      final taken = await _db
          .doc(FirestorePaths.jersey(player.teamId, targetJerseyId))
          .get()
          .timeout(_timeout);
      if (taken.exists && taken.data()?['playerId'] != player.id) {
        throw MoveUpJerseyTakenException(player.jerseyNo, group.label);
      }
    }

    return _db.runTransaction<String>((tx) async {
      // All reads first (Firestore transactions need reads before writes)
      final snapshot = await tx.get(playerRef);
      final data = snapshot.data();
      if (data == null || data['status'] != ApprovalStatus.pending.name) {
        throw const PlayerNotPendingException();
      }
      final child = Player.fromMap(snapshot.id, data);
      final from = child.ageGroup;
      if (from != null && group.index < from.index) {
        throw StateError('A child is never moved down.');
      }

      final newJerseyId = jerseyIdFor(
        child.category.name,
        child.jerseyNo,
        ageGroup: group.label,
      );
      final movesJersey = newJerseyId != child.jerseyId;
      final newJerseyRef =
          _db.doc(FirestorePaths.jersey(child.teamId, newJerseyId));
      if (movesJersey && (await tx.get(newJerseyRef)).exists) {
        throw MoveUpJerseyTakenException(child.jerseyNo, group.label);
      }

      // The child goes on the list of the age group they end in (3.1a1)
      final squad = squadRef(_db, child.teamId, group.label);
      final onSquad = isOnSquad(await tx.get(squad), child.id);

      var code = child.playerCode;
      DocumentSnapshot<Map<String, dynamic>>? counter;
      if (code == null) {
        counter = await tx.get(_juvenileCounterRef);
      }

      // Then the writes
      if (code == null) {
        final next = (counter?.data()?['next'] as num?)?.toInt() ?? 1;
        code = juvenilePlayerCodeFor(next, DateTime.now().toUtc().year);
        if (counter?.exists ?? false) {
          tx.update(_juvenileCounterRef, {'next': next + 1});
        } else {
          tx.set(_juvenileCounterRef, {'next': 2}); // the very first child
        }
      }

      if (movesJersey) {
        tx
          ..delete(_jerseyRef(child))
          ..set(newJerseyRef, {
            'playerId': child.id,
            'createdAt': FieldValue.serverTimestamp(),
          });
      }

      // The team's bell: "3 juvenile players passed: Esi Mensah (GJ26-0001)…"
      NotificationWriter(_db).forTeamInTransaction(
        tx,
        kind: NotificationKind.juvenilePassed,
        teamId: child.teamId,
        teamName: child.teamName,
        name: from == null || from == group
            ? '${child.fullName} ($code)'
            : '${child.fullName} ($code, moved up to ${group.label})',
      );

      tx.update(playerRef, {
        'status': ApprovalStatus.approved.name,
        'playerCode': code,
        'ageGroup': group.label,
        'screeningDayId': dayId,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': faUid,
        'rejectionReason': null,
        'changes': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!onSquad) {
        tx.set(
          squad,
          squadAddition(child.teamId, group.label, child.id),
          SetOptions(merge: true),
        );
      }
      // The registered photo for the face check (3.6a), same write
      if (playerPhotoCopy(data) case final photo?) {
        tx.set(playerPhotoRef(_db, child.id), photo);
      }
      return code;
    }).timeout(_timeout);
  }

  // ---------- Squad lists (3.1a1) ----------

  /// FA: puts every approved player on their squad list, and takes off
  /// anyone on a list who is no longer approved. Needed once for players
  /// approved before the lists existed (10 Nov 2026); safe to run again.
  /// One write per player (the rules allow one at a time).
  /// Returns how many it fixed.
  Future<int> repairSquadLists() async {
    final players = await _players
        .where('status', isEqualTo: ApprovalStatus.approved.name)
        .get()
        .timeout(_timeout);
    final lists =
        await _db.collection(FirestorePaths.squads).get().timeout(_timeout);
    final onList = {
      for (final list in lists.docs)
        list.id: ((list.data()['players'] as Map?)?.keys ?? const [])
            .whereType<String>()
            .toSet(),
    };

    var fixed = 0;
    final approvedIds = <String>{};
    for (final player in players.docs) {
      approvedIds.add(player.id);
      final data = player.data();
      final teamId = data['teamId'] as String? ?? '';
      final group = squadGroupFor(
        data['category'] as String? ?? '',
        data['ageGroup'] as String?,
      );
      if (onList['${teamId}_$group']?.contains(player.id) ?? false) continue;
      await squadRef(_db, teamId, group)
          .set(squadAddition(teamId, group, player.id), SetOptions(merge: true))
          .timeout(_timeout);
      fixed++;
    }
    for (final list in onList.entries) {
      for (final id in list.value.difference(approvedIds)) {
        await _db
            .doc('${FirestorePaths.squads}/${list.key}')
            .update(squadRemoval(id))
            .timeout(_timeout);
        fixed++;
      }
    }
    return fixed;
  }

  /// FA (3.6a): copies every approved player's photo links to
  /// `playerPhotos` where the copy is missing or old. Needed once for
  /// players approved before 3.6 (12 Nov 2026); safe to run again.
  /// Returns how many it fixed.
  Future<int> repairPlayerPhotos() async {
    final players = await _players
        .where('status', isEqualTo: ApprovalStatus.approved.name)
        .get()
        .timeout(_timeout);
    final copies = await _db
        .collection(FirestorePaths.playerPhotos)
        .get()
        .timeout(_timeout);
    final byId = {for (final c in copies.docs) c.id: c};

    var fixed = 0;
    for (final player in players.docs) {
      final data = player.data();
      if (isPhotoCopyUpToDate(byId[player.id], data)) continue;
      final photo = playerPhotoCopy(data);
      if (photo == null) continue;
      await playerPhotoRef(_db, player.id).set(photo).timeout(_timeout);
      fixed++;
    }
    return fixed;
  }

  /// FA, on the screening day: "Not eligible for Juvenile" with a
  /// [reason] the team sees. Final for every juvenile group: the team can
  /// no longer edit the child, and their player key stays taken.
  Future<void> markNotEligible(
    Player player, {
    required String reason,
    required String dayId,
    required String faUid,
  }) {
    final batch = _db.batch()
      ..update(_db.doc(FirestorePaths.player(player.id)), {
        'status': ApprovalStatus.rejected.name,
        'notEligible': true,
        'screeningDayId': dayId,
        'rejectionReason': reason.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': faUid,
        'changes': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.juvenileNotEligible,
      teamId: player.teamId,
      teamName: player.teamName,
      name: player.fullName,
    );
    return batch.commit().timeout(_timeout);
  }

  /// FA, on the screening day (2.14d): "Needs correcting". Back to the
  /// team with a [reason] (blurry photo, a typo…). Not final: the team
  /// fixes it, and the child waits for screening again.
  Future<void> sendBackJuvenile(
    Player player, {
    required String reason,
    required String dayId,
    required String faUid,
  }) {
    final batch = _db.batch()
      ..update(_db.doc(FirestorePaths.player(player.id)), {
        'status': ApprovalStatus.rejected.name,
        'screeningDayId': dayId,
        'rejectionReason': reason.trim(),
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': faUid,
        'changes': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    NotificationWriter(_db).forTeamInBatch(
      batch,
      kind: NotificationKind.juvenileToCorrect,
      teamId: player.teamId,
      teamName: player.teamName,
      name: player.fullName,
    );
    return batch.commit().timeout(_timeout);
  }
}

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepository(
    ref.watch(firestoreProvider),
    ref.watch(firebaseStorageProvider),
  );
});

/// Every player of my team (both competitions). Screens filter by
/// competition, position and search in the app.
final teamPlayersProvider = StreamProvider<List<Player>>((ref) async* {
  final team = await ref.watch(myTeamProvider.future);
  if (team == null) {
    yield const [];
    return;
  }
  yield* ref.watch(playerRepositoryProvider).watchTeam(team.id);
});

/// One player by ID, for the Player details screen.
final playerProvider =
    StreamProvider.family<Player?, String>((ref, playerId) {
  return ref.watch(playerRepositoryProvider).watch(playerId);
});

/// FA: every player in the district, live.
final allPlayersProvider = StreamProvider<List<Player>>((ref) {
  return ref.watch(playerRepositoryProvider).watchAll();
});

/// FA: the Division players only. The Players tab reviews these in the
/// app; juvenile players are checked on the screening day (2.14).
final divisionPlayersProvider = Provider<AsyncValue<List<Player>>>((ref) {
  return ref.watch(allPlayersProvider).whenData(
        (players) => [
          for (final p in players)
            if (!p.isJuvenile) p,
        ],
      );
});

/// FA: the juvenile players only (2.14b): Players › Juvenile.
final juvenilePlayersProvider = Provider<AsyncValue<List<Player>>>((ref) {
  return ref.watch(allPlayersProvider).whenData(
        (players) => [
          for (final p in players)
            if (p.isJuvenile) p,
        ],
      );
});

/// FA: how many Division players are waiting for review (gold number on
/// the Players tab). Juvenile players don't count: they wait for the
/// screening day, not for the FA to open the app.
final pendingPlayerCountProvider = Provider<int>((ref) {
  final players = ref.watch(divisionPlayersProvider).value ?? const [];
  return players.where((p) => p.status == ApprovalStatus.pending).length;
});

/// FA: the next player-ID number, live.
final nextPlayerNumberProvider = StreamProvider<int>((ref) {
  return ref.watch(playerRepositoryProvider).watchNextNumber();
});

/// FA: are this player's jersey and player key reserved for them?
/// It checks again only if the number, name or date of birth changes.
final playerReservationsProvider = FutureProvider.autoDispose
    .family<({bool jersey, bool key}), ReservationKey>((ref, key) {
  return ref.watch(playerRepositoryProvider).checkReservations(key);
});
