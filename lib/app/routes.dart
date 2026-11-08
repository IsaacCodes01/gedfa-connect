class Routes {
  Routes._();

  static const startup = '/startup';
  static const login = '/login';
  static const signUp = '/login/signup';
  static const forgotPassword = '/login/forgot';
  static const verifyEmail = '/verify-email';
  static const welcome = '/welcome';
  static const registerTeam = '/welcome/register';
  /// The FA's area. [admin] itself is the Teams tab.
  static const admin = '/admin';

  /// FA: the Home tab (dashboard), where the FA lands after signing in
  /// (2.12a).
  static const adminHome = '/admin/home';

  /// A screen opened from a "Needs you" row on Home gets `from=home`, so it
  /// shows a back arrow to Home. Opened from the tabs, it has none.
  static String fromHome(String route) =>
      '$route${route.contains('?') ? '&' : '?'}from=home';
  static bool isFromHome(Uri uri) => uri.queryParameters['from'] == 'home';
  static String adminRequest(String uid) => '/admin/request/$uid';

  /// FA: Teams with the Changes switch on (2.10b), and all of one team's
  /// changes to decide (2.10c).
  static const adminChanges = '$admin?view=changes';
  static String adminTeamChanges(String teamId) => '/admin/changes/$teamId';

  /// The FA corrects an approved team's club details (2.11a)
  static String adminCorrectDetails(String teamId) => '/admin/correct/$teamId';

  /// The FA asks a team to correct something (2.11b); [item] ticks one
  static String adminAskCorrection(String teamId, {String? item}) =>
      item == null
          ? '/admin/ask/$teamId'
          : '/admin/ask/$teamId?item=$item';
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
  /// FA: the Fixtures tab (3.0a), adding one match, changing one, and
  /// the kits of a match.
  static const adminFixtures = '/admin/fixtures';
  static const adminNewFixture = '/admin/fixtures/new';

  /// FA: "Make the season" (3.0b, G1) and its draft (G2).
  static const adminSeason = '/admin/fixtures/season';
  static const adminSeasonDraft = '/admin/fixtures/season/draft';
  /// FA: Competitions (3.0c1, C1): the leagues, cups and galas; and a new
  /// cup or gala (C2, C2b).
  static const adminCompetitions = '/admin/fixtures/competitions';
  static const adminNewCup = '/admin/fixtures/competitions/new';
  static String adminEditFixture(String id) => '$adminFixtures/edit/$id';
  static String adminFixtureKits(String id) => '$adminFixtures/kits/$id';

  /// Match details (F5, F6), for the FA and for teams.
  static String adminMatch(String id) => '$adminFixtures/match/$id';
  static String teamMatch(String id) => '$teamFixtures/match/$id';

  static const team = '/team';

  /// Team: the Fixtures tab (3.0a) and the kits of one match.
  static const teamFixtures = '/team/fixtures';
  static String teamFixtureKits(String id) => '$teamFixtures/kits/$id';
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