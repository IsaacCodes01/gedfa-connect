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
  static const adminNotifications = '/admin/notifications';
  static const adminAnnouncements = '/admin/more/announcements';
  static const adminNewAnnouncement = '/admin/more/announcements/new';
  static String adminAnnouncement(String id) =>
      '/admin/more/announcements/view/$id';
  static const adminPlayers = '/admin/players';
  static String adminTeamPlayers(String teamId) =>
      '$adminPlayers/team/$teamId';
  static String adminPlayer(String playerId) =>
      '$adminPlayers/player/$playerId';
  static const adminMore = '/admin/more';
  static const adminPeople = '/admin/more/people';

  /// FA: what every team has paid this season, and one team (2.13c).
  static const adminFees = '/admin/more/fees';

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
  static const teamAddPayment = '/team/more/fee/add';
  static const referee = '/referee';
  static const teamPlayer = '/team/player';
  static String player(String playerId) => '$teamPlayer/$playerId';
  static const addPlayer = '/team/add';
  static String editPlayer(String playerId) => '/team/player/$playerId/edit';
}