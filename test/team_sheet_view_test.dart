import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/team_sheets/data/team_sheet_repository.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/team_sheet_view_screen.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/kit_slot.dart';
import 'package:gedfa_connect/features/teams/domain/official.dart';
import 'package:go_router/go_router.dart';

/// One team's sheet, read only (3.2): the FA and, from the lock, the
/// opponent. Drawn from the copies saved on the sheet.
void main() {
  KitChoice kit(KitSlot slot) => KitChoice(
    slot: slot,
    kit: const Kit(
      primary: Colors.red,
      shorts: Colors.white,
      socks: Colors.red,
    ),
    raw: const {},
  );

  final match = Fixture(
    id: 'm1',
    season: '2026-27',
    competitionId: '2026-27_division-league',
    category: Competition.division,
    round: 3,
    home: const FixtureSide(
      id: 'ruf',
      name: 'Royal Unique Football Club of Apam',
      shortName: 'RUF',
      colour: Colors.red,
    ),
    away: const FixtureSide(
      id: 'ast',
      name: 'Asebu Stars',
      shortName: 'AST',
      colour: Colors.green,
    ),
    kits: MatchKits(
      home: kit(KitSlot.home),
      away: kit(KitSlot.away),
      homeGk: kit(KitSlot.goalkeeper),
      awayGk: kit(KitSlot.goalkeeper),
    ),
    kickoffAt: DateTime.now().add(const Duration(days: 3)),
    venue: 'Apam Park',
    status: FixtureStatus.scheduled,
  );

  final ids = [for (var i = 1; i <= 16; i++) 'p$i'];
  final sheet = TeamSheet(
    fixtureId: 'm1',
    teamId: 'ruf',
    category: Competition.division,
    starters: ids.take(11).toList(),
    bench: ids.skip(11).toList(),
    captainId: 'p4',
    viceCaptainId: 'p6',
    goalkeeperId: 'p1',
    numbers: {for (var i = 1; i <= 16; i++) 'p$i': i == 15 ? 33 : i},
    officials: const [
      Official(role: OfficialRole.teamManager, name: 'Kojo Antwi', phone: ''),
      Official(role: OfficialRole.headCoach, name: 'Kofi Mensah', phone: ''),
    ],
    players: {
      for (var i = 1; i <= 16; i++)
        'p$i': SheetPlayer(
          id: 'p$i',
          name: i == 16 ? 'Kojo Brew' : 'Emmanuel Tetteh-Asamoah $i',
          position: 'CB',
          usual: i,
          ageGroup: i == 16 ? AgeGroup.u15 : null,
        ),
    },
    savedAt: DateTime(2026, 11, 10, 16, 12),
  );

  Future<void> pump(WidgetTester tester, Size size, Brightness b) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          fixtureProvider.overrideWith((ref, id) => Stream.value(match)),
          teamSheetProvider.overrideWith((ref, key) => Stream.value(sheet)),
        ],
        child: MaterialApp.router(
          theme: b == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
          routerConfig: GoRouter(
            initialLocation: '/v',
            routes: [
              GoRoute(
                path: '/v',
                builder: (_, _) => const TeamSheetViewScreen(
                  fixtureId: 'm1',
                  teamId: 'ruf',
                  isFa: true,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }

  for (final b in Brightness.values) {
    testWidgets('small phone, ${b.name}: the whole sheet fits', (tester) async {
      await pump(tester, const Size(360, 1800), b);
      expect(find.text('STARTING 11'), findsOneWidget);
      expect(find.text('BENCH (5 of 7)'), findsOneWidget);
      // Armbands, a changed number, a juvenile's pill, the officials
      expect(find.text('C'), findsOneWidget);
      expect(find.text('GK'), findsOneWidget);
      expect(find.text('usual 15'), findsOneWidget);
      expect(find.text('U15'), findsOneWidget);
      expect(find.textContaining('Kojo Antwi (Team manager)'), findsOneWidget);
      expect(
        find.textContaining('the team can change it until'),
        findsOneWidget,
      );
    });
  }

  testWidgets('laptop: fits', (tester) async {
    await pump(tester, const Size(1280, 1600), Brightness.light);
  });
}
