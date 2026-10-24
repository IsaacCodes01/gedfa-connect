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
  static const adminPlayers = '/admin/players';
  static String adminTeamPlayers(String teamId) =>
      '$adminPlayers/team/$teamId';
  static String adminPlayer(String playerId) =>
      '$adminPlayers/player/$playerId';
  static const adminMore = '/admin/more';
  static const adminPeople = '/admin/more/people';
  static const adminInvite = '/admin/more/people/invite';
  static String adminInviteReady(String email) =>
      '$adminPeople/invited/${Uri.encodeComponent(email)}';
  static String adminMember(String uid) => '$adminPeople/member/$uid';
  static const team = '/team';
  static const teamPositions = '/team/positions';
  static const teamMore = '/team/more';
  static const teamProfile = '/team/more/profile';
  static const teamChangeEmail = '/team/more/profile/email';
  static const teamSettings = '/team/more/settings';
  static const referee = '/referee';
  static const teamPlayer = '/team/player';
  static String player(String playerId) => '$teamPlayer/$playerId';
  static const addPlayer = '/team/add';
  static String editPlayer(String playerId) => '/team/player/$playerId/edit';
}