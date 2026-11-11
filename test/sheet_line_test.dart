import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/team_sheets/domain/sheet_status.dart';
import 'package:gedfa_connect/features/team_sheets/domain/team_sheet.dart';
import 'package:gedfa_connect/features/team_sheets/presentation/widgets/sheet_line.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

/// The team sheet line on the Home card (3.1c, MS1 and MS1b).
void main() {
  final due = DateTime(2026, 11, 14, 14);
  final sheet = TeamSheet(
    fixtureId: 'm1',
    teamId: 'ruf',
    category: Competition.division,
    starters: [for (var i = 0; i < 11; i++) 'p$i'],
    bench: const ['a', 'b', 'c', 'd', 'e'],
    savedAt: DateTime(2026, 11, 10, 16, 12),
  );

  Future<List<String>> pump(WidgetTester tester, SheetStatus status) async {
    final tapped = <String>[];
    tester.view.physicalSize = const Size(360, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SheetLine(
            status: status,
            onOpen: () => tapped.add('open'),
            onView: () => tapped.add('view'),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    return tapped;
  }

  testWidgets('not started: gold, Make team sheet', (tester) async {
    final tapped = await pump(
      tester,
      SheetStatus(SheetState.notStarted, due: due),
    );
    expect(find.text('Team sheet: not started'), findsOneWidget);
    expect(
      find.text('Due Sat 14 Nov, 2:00 pm (1 hour before kick-off)'),
      findsOneWidget,
    );
    await tester.tap(find.text('Make team sheet'));
    expect(tapped, ['open']);
  });

  testWidgets('saved: green, View sheet and Change', (tester) async {
    final tapped = await pump(
      tester,
      SheetStatus(SheetState.saved, due: due, sheet: sheet),
    );
    expect(find.text('Team sheet saved · 16 players'), findsOneWidget);
    expect(
      find.text(
        '11 starting, 5 on the bench · saved Tue 4:12 pm · '
        'change until Sat 2:00 pm',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('View sheet'));
    await tester.tap(find.text('Change'));
    expect(tapped, ['view', 'open']);
  });

  testWidgets('locked: only View sheet', (tester) async {
    await pump(tester, SheetStatus(SheetState.locked, due: due, sheet: sheet));
    expect(find.text('Team sheet locked · 16 players'), findsOneWidget);
    expect(find.text('View sheet'), findsOneWidget);
    expect(find.text('Change'), findsNothing);
  });

  testWidgets('missed: red, no buttons', (tester) async {
    await pump(tester, SheetStatus(SheetState.missed, due: due));
    expect(find.text('No team sheet'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });
}
