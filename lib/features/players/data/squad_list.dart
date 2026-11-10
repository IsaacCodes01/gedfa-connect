import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';

/// Squad lists (3.1a1): `squads/{teamId}_{group}` holds the IDs of a
/// team's APPROVED players, one list per competition: `division`, or a
/// juvenile age group (`U13`, `U15`, `U17`).
///
/// Why: a team sheet has up to 18 players, and the security rules may look
/// at only 10 to 20 documents per save. With the list they check all 18
/// players with ONE lookup.
///
/// The rules keep it exact: the FA's approval (or screening pass) must put
/// the player on it in the same write, and a team edit that sends an
/// approved player back to pending must take them off. One player per
/// write, named in `changed`.

/// The list a player belongs on: 'division', or their juvenile age group.
/// Same as `squadGroupOf` in firestore.rules.
String squadGroupFor(String category, String? ageGroup) =>
    category == 'juvenile' ? (ageGroup ?? '') : 'division';

/// `squads/{teamId}_{group}`.
DocumentReference<Map<String, dynamic>> squadRef(
  FirebaseFirestore db,
  String teamId,
  String group,
) => db.doc(FirestorePaths.squad(teamId, group));

/// Is [playerId] on the list in [snapshot]? (false when there is no list)
bool isOnSquad(
  DocumentSnapshot<Map<String, dynamic>> snapshot,
  String playerId,
) => (snapshot.data()?['players'] as Map?)?[playerId] == true;

/// The write that puts [playerId] on the list. Use with
/// `SetOptions(merge: true)`: it makes the list if it doesn't exist yet.
Map<String, dynamic> squadAddition(
  String teamId,
  String group,
  String playerId,
) => {
  'teamId': teamId,
  'group': group,
  'players': {playerId: true},
  'changed': playerId,
  'updatedAt': FieldValue.serverTimestamp(),
};

/// The update that takes [playerId] off the list.
Map<String, dynamic> squadRemoval(String playerId) => {
  'players.$playerId': FieldValue.delete(),
  'changed': playerId,
  'updatedAt': FieldValue.serverTimestamp(),
};
