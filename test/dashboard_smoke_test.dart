import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/auth/data/app_user_repository.dart';
import 'package:gedfa_connect/features/auth/data/auth_repository.dart';
import 'package:gedfa_connect/features/auth/domain/app_user.dart';
import 'package:gedfa_connect/features/dashboard/data/dashboard_providers.dart';
import 'package:gedfa_connect/features/dashboard/domain/dashboard_stats.dart';
import 'package:gedfa_connect/features/dashboard/domain/fa_waiting.dart';
import 'package:gedfa_connect/features/dashboard/presentation/fa_dashboard_screen.dart';
import 'package:gedfa_connect/features/league/data/league_settings_repository.dart';
import 'package:gedfa_connect/features/league/domain/league_settings.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/screening/data/screening_repository.dart';

const _stats = DashboardStats(
  teams: 18,
  bothCompetitions: 4,
  suspended: 1,
  division: 296,
  juvenile: 116,
  approvedThisWeek: 17,
  waitingDivision: 14,
  waitingJuvenile: 9,
  juvenileByGroup: {AgeGroup.u13: 34, AgeGroup.u15: 41, AgeGroup.u17: 41},
  divisionPositions: {
    PositionGroup.gk: 32,
    PositionGroup.def: 104,
    PositionGroup.mid: 98,
    PositionGroup.fwd: 62,
  },
  juvenilePositions: {
    PositionGroup.gk: 12,
    PositionGroup.def: 40,
    PositionGroup.mid: 40,
    PositionGroup.fwd: 24,
  },
  collected: 13500,
  due: 18000,
  owing: 6,
  divisionTeams: 18,
  squadsReady: 12,
  squadSize: 16,
);

const _waiting = FaWaiting(
  newTeams: 2,
  teamChanges: 3,
  players: 14,
  screening: 9,
  payments: 4,
  correctionsBack: 1,
);

Future<void> _pump(
  WidgetTester tester,
  Size size,
  Brightness brightness, {
  FaWaiting waiting = _waiting,
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        faWaitingProvider.overrideWithValue(AsyncData(waiting)),
        dashboardStatsProvider.overrideWithValue(const AsyncData(_stats)),
        appUserProvider.overrideWith(
          (ref) => Stream.value(
            const AppUser(uid: 'u', role: null, displayName: 'Isaac Otabil'),
          ),
        ),
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
        leagueSettingsProvider.overrideWith(
          (ref) => Stream.value(const LeagueSettings()),
        ),
        upcomingScreeningsProvider.overrideWith((ref) => Stream.value([])),
        unreadCountProvider.overrideWithValue(5),
        myAudienceProvider.overrideWithValue('fa'),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true, brightness: brightness),
        // Large text on the phone (Settings › Display), when asked
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const FaDashboardScreen(),
      ),
    ),
  );
  // Every frame of the count-up, not only the end: numbers change size
  // while they count (the overflow Isaac saw on web, 7 Nov 2026)
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    final error = tester.takeException();
    // The whole message (which widget overflowed), not only the summary
    expect(
      error,
      isNull,
      reason:
          'frame $i: ${error is FlutterError ? error.toStringDeep() : error}',
    );
  }
  await tester.pumpAndSettle();
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('phone 360 wide, $brightness', (tester) async {
      await _pump(tester, const Size(360, 2600), brightness);
      expect(tester.takeException(), isNull);
      expect(find.text('Needs you'), findsOneWidget);
      expect(find.text('412'), findsOneWidget);
      expect(find.text('Squads ready'), findsOneWidget);
      expect(find.textContaining('Good'), findsOneWidget);
    });

    testWidgets('laptop 1280 wide, $brightness', (tester) async {
      await _pump(tester, const Size(1280, 1800), brightness);
      expect(tester.takeException(), isNull);
      expect(find.text('Season stats'), findsOneWidget);
    });
  }

  testWidgets('phone 360 with large text (130%)', (tester) async {
    await _pump(
      tester,
      const Size(360, 3200),
      Brightness.light,
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('small phone 320, all caught up', (tester) async {
    await _pump(
      tester,
      const Size(320, 2600),
      Brightness.light,
      waiting: const FaWaiting(
        newTeams: 0,
        teamChanges: 0,
        players: 0,
        screening: 0,
        payments: 0,
        correctionsBack: 0,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('All caught up'), findsOneWidget);
  });
}
