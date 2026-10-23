class FirestorePaths {
  FirestorePaths._();

  static const districtId = 'gomoa-east';
  static const district = 'districts/$districtId';

  static String user(String uid) => '$district/users/$uid';

  static const teamRequests = '$district/teamRequests';
  static String teamRequest(String uid) => '$district/teamRequests/$uid';
  static String teamName(String key) => '$district/teamNames/$key';
  static const teams = '$district/teams';
  static String team(String teamId) => '$district/teams/$teamId';

  static const players = '$district/players';
  static String player(String playerId) => '$district/players/$playerId';

  static String jersey(String teamId, String jerseyId) =>
    '${team(teamId)}/jerseys/$jerseyId';

  static String playerKey(String key) => '$district/playerKeys/$key';

  static const leagueSettings = '$district/settings/league';

  /// The next player-ID number: `{ next: 43 }`. FA only.
  static const playerCounter = '$district/settings/playerCounter';
}

class StoragePaths {
  StoragePaths._();

  static String teamRequestLogo(String uid) =>
  '${FirestorePaths.district}/teamRequests/$uid/logo.jpg';

    static String playerFile(String teamId, String playerId, String fileName) =>
    '${FirestorePaths.district}/teams/$teamId/players/$playerId/$fileName';
}