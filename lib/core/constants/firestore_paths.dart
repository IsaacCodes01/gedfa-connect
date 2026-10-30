class FirestorePaths {
  FirestorePaths._();

  static const districtId = 'gomoa-east';
  static const district = 'districts/$districtId';

  static const users = '$district/users';
  static String user(String uid) => '$district/users/$uid';

  /// Invitations, one per email (the ID is the email in lower case).
  static const invites = '$district/invites';
  static String invite(String email) => '$district/invites/$email';

  /// Role history: invited, accepted, declined, cancelled, removed.
  static const roleLog = '$district/roleLog';

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

  /// Football details the team keeps up to date (2.3d).
  static const playerProfiles = '$district/playerProfiles';
  static String playerProfile(String playerId) =>
      '$district/playerProfiles/$playerId';

  /// Captain and vice-captain of one squad, e.g. teams/royal/armbands/division.
  static String armbands(String teamId, String category) =>
      '${team(teamId)}/armbands/$category';

  // Announcements and notifications (2.7 – 2.8)
  static const announcements = '$district/announcements';
  static String announcement(String id) => '$district/announcements/$id';
  static String announcementSeen(String id, String key) =>
      '$district/announcements/$id/seen/$key';
  static String announcementSeenAll(String id) =>
      '$district/announcements/$id/seen';
  static const notifications = '$district/notifications';
  static String notification(String id) => '$district/notifications/$id';
  static String readMark(String uid) => '$district/readMarks/$uid';

  // Season fee (2.13c)
  static const payments = '$district/payments';
  static const fees = '$district/fees';
  static String payment(String id) => '$district/payments/$id';

  /// Confirmed total for one club and season, e.g. `fees/2026-27_<uid>`.
  static String fee(String season, String requestUid) =>
      '$district/fees/${season}_$requestUid';

  /// The next receipt number: `{ next: 15 }`. FA only.
  static const receiptCounter = '$district/settings/receiptCounter';

  static const leagueSettings = '$district/settings/league';

  /// Who changed which league setting, and when (2.13d). FA only.
  static const settingsLog = '$district/settingsLog';

  /// The next player-ID number: `{ next: 43 }`. FA only.
  static const playerCounter = '$district/settings/playerCounter';
}

class StoragePaths {
  StoragePaths._();

  static String teamRequestLogo(String uid) =>
  '${FirestorePaths.district}/teamRequests/$uid/logo.jpg';

  /// The new club's letter (letter.pdf) and the licence
  /// (licence.pdf or licence.jpg), next to the request's logo.
  static String teamRequestFile(String uid, String fileName) =>
      '${FirestorePaths.district}/teamRequests/$uid/$fileName';

  /// Kit photos (2.13b): `kits/<set>-<slot>-<part>-<millis>.jpg`.
  static String teamRequestKitPhoto(String uid, String fileName) =>
      '${FirestorePaths.district}/teamRequests/$uid/kits/$fileName';

  /// Screenshot of a payment message (2.13c): `proof-<millis>.jpg`.
  static String paymentProof(String uid, String fileName) =>
      '${FirestorePaths.district}/payments/$uid/$fileName';

  static String playerFile(String teamId, String playerId, String fileName) =>
    '${FirestorePaths.district}/teams/$teamId/players/$playerId/$fileName';
}