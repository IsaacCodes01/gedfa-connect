import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/domain/app_user.dart';
import 'package:gedfa_connect/features/dashboard/presentation/team_dashboard_screen.dart';
import 'package:gedfa_connect/features/fixtures/data/cup_repository.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/league/domain/league_settings.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/notifications/domain/announcement.dart';
import 'package:gedfa_connect/features/payments/data/payment_repository.dart';
import 'package:gedfa_connect/features/payments/domain/payment.dart';
import 'package:gedfa_connect/features/teams/data/team_change_repository.dart';
import 'package:gedfa_connect/features/teams/domain/team_change.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/screening/data/screening_repository.dart';
import 'package:gedfa_connect/features/teams/data/correction_request_repository.dart';
import 'package:gedfa_connect/features/teams/data/team_repository.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:gedfa_connect/features/team_sheets/data/team_sheet_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The team's Home (TDa) on a small phone, light and dark: no overflow,
/// and the Division | Juvenile switch changes the next match.

const _team = Team(
  id: 'ruf',
  name: 'Royal Unique Football Club of Apam',
  shortName: 'RUF',
  town: 'Apam',
  categories: {Competition.division, Competition.juvenile},
  adminUids: ['u'],
  requestUid: 'req',
);

KitChoice _kit(KitSlot slot) => KitChoice(
  slot: slot,
  kit: const Kit(primary: Colors.red, shorts: Colors.white, socks: Colors.red),
  raw: const {},
);

Fixture _match(
  String id,
  DateTime kickoff, {
  Competition category = Competition.division,
  AgeGroup? ageGroup,
  FixtureStatus status = FixtureStatus.scheduled,
}) => Fixture(
  id: id,
  season: '2026-27',
  competitionId: '2026-27_${category.name}-league',
  category: category,
  ageGroup: ageGroup,
  round: 3,
  home: const FixtureSide(
    id: 'ruf',
    name: 'Royal Unique Football Club of Apam',
    shortName: 'RUF',
    colour: Colors.red,
  ),
  away: FixtureSide(
    id: 'ast',
    name: category == Competition.juvenile
        ? 'Asebu Stars B'
        : 'Asebu Stars Sporting Club',
    shortName: category == Competition.juvenile ? 'AST B' : 'AST',
    colour: Colors.green,
  ),
  kits: MatchKits(
    home: _kit(KitSlot.home),
    away: _kit(KitSlot.away),
    homeGk: _kit(KitSlot.goalkeeper),
    awayGk: _kit(KitSlot.goalkeeper),
  ),
  kickoffAt: kickoff,
  venue: 'Apam Park, near the District Assembly',
  status: status,
);

var _n = 0;
Player _player({ApprovalStatus status = ApprovalStatus.approved}) => Player(
  id: 'p${_n++}',
  teamId: 'ruf',
  teamName: 'Royal Unique FC',
  category: Competition.division,
  fullName: 'Kwabena Mensah-Bonsu $_n',
  dob: DateTime(2000),
  position: Position.gk,
  jerseyNo: _n % 99 + 1,
  status: status,
);

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Brightness b, {
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final soon = DateTime.now().add(const Duration(days: 4));

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        myTeamProvider.overrideWith((ref) => Stream.value(_team)),
        appUserProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(uid: 'u', role: null, displayName: 'Isaac Otabil'),
          ),
        ),
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
        leagueSettingsProvider.overrideWith(
          (ref) => Stream.value(const LeagueSettings()),
        ),
        myTeamSheetsProvider.overrideWith((ref) => Stream.value(const {})),
        myFixturesProvider.overrideWith(
          (ref) => Stream.value([
            _match('div1', soon),
            _match('div2', soon.add(const Duration(days: 7))),
            _match(
              'div3',
              soon.add(const Duration(days: 14)),
              status: FixtureStatus.postponed,
            ),
            _match(
              'u15',
              soon.add(const Duration(days: 1)),
              category: Competition.juvenile,
              ageGroup: AgeGroup.u15,
            ),
          ]),
        ),
        teamPlayersProvider.overrideWith(
          (ref) => Stream.value([
            for (var i = 0; i < 16; i++) _player(),
            _player(status: ApprovalStatus.rejected),
            _player(status: ApprovalStatus.pending),
          ]),
        ),
        myCorrectionRequestProvider.overrideWith((ref) => Stream.value(null)),
        feeSummaryProvider.overrideWith(
          (ref, uid) =>
              Stream.value(const FeeSummary(confirmed: 300, fee: 500)),
        ),
        clubPaymentsProvider.overrideWith(
          (ref, uid) => Stream.value([
            const Payment(
              id: 'pay',
              requestUid: 'req',
              teamName: 'Royal Unique FC',
              season: '2026-27',
              method: PaymentMethod.momo,
              status: PaymentStatus.waiting,
              amount: 100,
            ),
          ]),
        ),
        myTeamChangesProvider.overrideWith(
          (ref) => Stream.value([
            const TeamChange(
              id: 'c',
              teamId: 'ruf',
              teamName: 'Royal Unique FC',
              kind: TeamChangeKind.shortName,
              to: 'ROYAL',
              reason: 'Shorter',
              status: ApprovalStatus.pending,
            ),
          ]),
        ),
        pinnedAnnouncementProvider.overrideWithValue(
          const Announcement(
            id: 'a',
            title: 'Season kick-off meeting for every team manager',
            body:
                'All team managers meet at the District Assembly hall on '
                'Saturday at 10:00 am. Bring your officials.',
            to: Audience.everyone,
            important: true,
            pinned: true,
            createdBy: 'fa',
            createdByName: 'GEDFA',
          ),
        ),
        myNotificationsProvider.overrideWith((ref) => Stream.value([])),
        seasonCupsProvider.overrideWith((ref) => Stream.value([])),
        upcomingScreeningsProvider.overrideWith((ref) => Stream.value([])),
        unreadCountProvider.overrideWithValue(3),
        myAudienceProvider.overrideWithValue('team'),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: b),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const TeamDashboardScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// No overflow, with the whole message (which widget) when there is one.
void _noError(WidgetTester tester) {
  final error = tester.takeException();
  expect(
    error,
    isNull,
    reason: error is FlutterError ? error.toStringDeep() : '$error',
  );
}

void main() {
  for (final b in Brightness.values) {
    for (final width in [320.0, 360.0]) {
      testWidgets('phone $width wide, $b', (tester) async {
        await _pump(tester, Size(width, 2400), b);
        _noError(tester);
        expect(find.textContaining('Good'), findsOneWidget);
        expect(find.text('Needs you'), findsOneWidget);
        expect(find.text('1 player sent back'), findsOneWidget);
        expect(find.text('Add 2 more for a full squad'), findsOneWidget);
        expect(find.text('NEXT MATCH · DIVISION · ROUND 3'), findsOneWidget);
        expect(find.text('Postponed'), findsOneWidget);
        // TDb
        expect(find.text('Squad at a glance'), findsOneWidget);
        expect(find.text('Match-ready'), findsOneWidget);
        expect(find.text('GH₵ 200 left'), findsOneWidget);
        expect(find.text('Waiting on the FA'), findsOneWidget);
        expect(find.text('Short name → ROYAL'), findsOneWidget);
        expect(find.text('Payment GH₵ 100'), findsOneWidget);
        expect(find.text('1 player'), findsOneWidget);
        expect(find.text('From GEDFA'), findsOneWidget);
        expect(find.text('Coming later'), findsOneWidget);
        // TDc
        expect(find.text('Match calendar'), findsOneWidget);
      });
    }

    testWidgets('laptop 1280 wide, $b', (tester) async {
      await _pump(tester, const Size(1280, 2000), b);
      _noError(tester);
      expect(find.text('Waiting on the FA'), findsOneWidget);
    });
  }

  testWidgets('phone 360 with large text (130%)', (tester) async {
    await _pump(
      tester,
      const Size(360, 3600),
      Brightness.light,
      textScale: 1.3,
    );
    _noError(tester);
  });

  testWidgets('Juvenile on the switch shows the U15 match', (tester) async {
    await _pump(tester, const Size(360, 2400), Brightness.light);
    await tester.tap(find.bySemanticsLabel(RegExp('^Juvenile matches')));
    await tester.pumpAndSettle();
    _noError(tester);
    expect(find.text('NEXT MATCH · JUVENILE U15 · ROUND 3'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
  });
}
