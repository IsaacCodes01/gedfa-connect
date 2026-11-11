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

  /// A team's requests to the FA (2.10b), e.g. `teamChanges/royal_name`.
  static const teamChanges = '$district/teamChanges';
  static String teamChange(String id) => '$district/teamChanges/$id';

  /// What the FA asked a team to correct (2.11b), one per team.
  static const correctionRequests = '$district/correctionRequests';
  static String correctionRequest(String teamId) =>
      '$district/correctionRequests/$teamId';

  /// A team's suspensions, one line each (2.11c).
  static String teamSuspensions(String teamId) =>
      '${team(teamId)}/suspensions';

  /// The FA's corrections log of a team (2.11a), one line per correction.
  static String teamCorrections(String teamId) =>
      '${team(teamId)}/corrections';

  /// Matches (3.0a), and each match's history of changes.
  static const fixtures = '$district/fixtures';
  static String fixture(String id) => '$district/fixtures/$id';
  static String fixtureHistory(String id) => '$district/fixtures/$id/history';

  /// "Make the season" drafts the FA saved for later (3.0b), FA only.
  static String fixtureDraft(String id) => '$district/fixtureDrafts/$id';

  /// Cups and galas (3.0c), read by everyone with a role.
  static const cups = '$district/cups';
  static String cup(String id) => '$district/cups/$id';

  /// A cup's history (3.0c1b): one doc per change, deleted with the cup.
  static String cupHistory(String id) => '$district/cups/$id/history';

  /// A league's postpone while it runs (3.0c1d), FA only; ID = the
  /// competition ('2026-27_division-league'). Deleted when finished.
  static const postponeJobs = '$district/postponeJobs';
  static String postponeJob(String competitionId) =>
      '$district/postponeJobs/$competitionId';

  static const players = '$district/players';
  static String player(String playerId) => '$district/players/$playerId';

  static String jersey(String teamId, String jerseyId) =>
    '${team(teamId)}/jerseys/$jerseyId';

  static String playerKey(String key) => '$district/playerKeys/$key';

  /// Approved player IDs of one squad (3.1a1), e.g. `squads/royal_division`
  /// or `squads/royal_U15`. Team sheets are checked against it.
  static const squads = '$district/squads';
  static String squad(String teamId, String group) =>
      '$district/squads/${teamId}_$group';

  /// All team sheets (3.1c: a team lists its own).
  static const teamSheets = '$district/teamSheets';

  /// A team's sheet for one match (3.1a2): `teamSheets/{fixtureId}_{teamId}`.
  static String teamSheet(String fixtureId, String teamId) =>
      '$district/teamSheets/${fixtureId}_$teamId';

  /// The FA suspends a player for a number of matches (3.1e1). Not the
  /// team suspensions of 2.11c (`teams/{id}/suspensions`).
  static const playerSuspensions = '$district/playerSuspensions';

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

  /// Juvenile screening days (2.14b): read by everyone with a role,
  /// written by the FA.
  static const screeningDays = '$district/screeningDays';
  static String screeningDay(String id) => '$district/screeningDays/$id';

  /// The next juvenile player-ID number (GJ26-…): `{ next: 5 }`. FA only.
  static const juvenileCounter = '$district/settings/juvenileCounter';

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

  /// A new logo a team asks the FA for (2.10b): `logo-<millis>.jpg`.
  static String teamLogo(String teamId, String fileName) =>
      '${FirestorePaths.district}/teams/$teamId/$fileName';

  static String playerFile(String teamId, String playerId, String fileName) =>
    '${FirestorePaths.district}/teams/$teamId/players/$playerId/$fileName';
}