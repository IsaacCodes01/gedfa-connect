class Routes {
  Routes._();

  static const startup = '/startup';
  static const login = '/login';
  static const signUp = '/login/signup';
  static const forgotPassword = '/login/forgot';
  static const verifyEmail = '/verify-email';
  static const welcome = '/welcome';
  static const registerTeam = '/welcome/register';
  static const admin = '/admin';
  static String adminRequest(String uid) => '/admin/request/$uid';

  /// FA: Teams with the Changes switch on, and one change to decide
  /// (2.10b, boards P4 and P5).
  static const adminChanges = '$admin?view=changes';
  static String adminChange(String id) => '/admin/change/$id';
  static const adminNotifications = '/admin/notifications';
  static const adminAnnouncements = '/admin/more/announcements';
  static const adminNewAnnouncement = '/admin/more/announcements/new';
  static String adminAnnouncement(String id) =>
      '/admin/more/announcements/view/$id';
  static const adminPlayers = '/admin/players';
  static String adminTeamPlayers(String teamId) =>
      '$adminPlayers/team/$teamId';

  /// FA: Players with the Juvenile switch on, and one team's juvenile
  /// players by age group (2.14b, board J5).
  static const adminPlayersJuvenile = '$adminPlayers?view=juvenile';

  /// FA: one juvenile child, read only (2.14c).
  static String adminJuvenileChild(String playerId) =>
      '$adminPlayers/child/$playerId';
  static String adminTeamJuvenile(String teamId) =>
      '$adminPlayers/team/$teamId/juvenile';
  static String adminPlayer(String playerId) =>
      '$adminPlayers/player/$playerId';
  static const adminMore = '/admin/more';
  static const adminPeople = '/admin/more/people';

  /// FA: what every team has paid this season, and one team (2.13c).
  static const adminFees = '/admin/more/fees';

  /// FA: juvenile screening days (2.14b, board J3).
  static const adminScreening = '/admin/more/screening';

  /// FA: screening one child after another on a day (2.14c, board J4).
  /// [childId]: "Screen player" from a child's page puts them first.
  static String adminScreeningDay(String dayId, {String? childId}) =>
      childId == null
          ? '$adminScreening/day/$dayId'
          : '$adminScreening/day/$dayId?child=$childId';

  /// FA: registration switches, squad numbers, season and fee (2.13d).
  static const adminLeagueSettings = '/admin/more/league';
  static String adminTeamFee(String teamId) => '$adminFees/team/$teamId';
  static const adminInvite = '/admin/more/people/invite';
  static String adminInviteReady(String email) =>
      '$adminPeople/invited/${Uri.encodeComponent(email)}';
  static String adminMember(String uid) => '$adminPeople/member/$uid';
  static const team = '/team';
  static const teamNotifications = '/team/notifications';
  static String teamAnnouncement(String id) =>
      '/team/notifications/announcement/$id';
  static const teamPositions = '/team/positions';
  static String teamPlayerProfile(String playerId) =>
      '$teamPositions/profile/$playerId';
  static String teamEditPlayerProfile(String playerId) =>
      '$teamPositions/profile/$playerId/edit';
  static const teamMore = '/team/more';
  static const teamProfile = '/team/more/profile';
  static const teamChangeEmail = '/team/more/profile/email';
  static const teamSettings = '/team/more/settings';

  /// The team's season fee, and adding a payment (2.13c).
  static const teamFee = '/team/more/fee';

  /// Team: More › Team profile, the CLUB's page (2.10a, board P1), and
  /// one section to edit straight away (details, colours, kits,
  /// officials). Not [teamProfile], which is the person's My profile.
  static const teamClub = '/team/more/club';
  static String teamClubEdit(String section) => '$teamClub/edit/$section';

  /// Team profile › "Ask the FA to change" (2.10b, board P2), opened on
  /// one kind: name, shortName, logo or competition.
  static String teamClubAsk(String kind) => '$teamClub/ask?kind=$kind';
  static const teamAddPayment = '/team/more/fee/add';
  static const referee = '/referee';
  static const teamPlayer = '/team/player';
  static String player(String playerId) => '$teamPlayer/$playerId';
  static const addPlayer = '/team/add';

  /// Add a juvenile player to an age group (2.14): /team/add?group=U13
  static String addJuvenilePlayer(String group) => '$addPlayer?group=$group';
  static String editPlayer(String playerId) => '/team/player/$playerId/edit';
}