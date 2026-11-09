import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/fixtures/data/fixture_repository.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/rename_matches.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/renamed_pill.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';

/// Renamed teams in matches (JSc2, mockups R1–R5).
void main() {
  final until = DateTime(2026, 11, 9, 14, 10);
  const kit = {'primary': '#7A1F2B'};

  /// A match as stored: Royal (home) v Apam Stars.
  Map<String, dynamic> match({
    String category = 'division',
    String homeName = 'Royal Unique FC',
    String homeShort = 'RUF',
    Map<String, dynamic>? previousNames,
  }) => {
    'season': '2026-27',
    'competitionId': '2026-27_$category-league',
    'category': category,
    if (category == 'juvenile') 'ageGroup': 'U15',
    'round': 6,
    'teamIds': ['royal', 'aps'],
    'home': {
      'id': 'royal',
      'name': homeName,
      'shortName': homeShort,
      'logoUrl': null,
      'colour': '#7A1F2B',
    },
    'away': {
      'id': 'aps',
      'name': 'Apam Stars',
      'shortName': 'APS',
      'logoUrl': null,
      'colour': '#1259A8',
    },
    'kits': {
      for (final k in ['home', 'away', 'homeGk', 'awayGk'])
        k: {'slot': k.endsWith('Gk') ? 'goalkeeper' : k, 'kit': kit},
    },
    'kickoffAt': Timestamp.fromDate(DateTime(2026, 11, 21, 15)),
    'venue': 'Apam Park',
    'status': 'scheduled',
    'previousNames': ?previousNames,
  };

  Map<String, dynamic> team({
    String name = 'Royal Stars FC',
    String shortName = 'RUF',
    List<String> categories = const ['division', 'juvenile'],
    String? juvenileName,
  }) => {
    'name': name,
    'shortName': shortName,
    'categories': categories,
    'juvenileName': ?juvenileName,
    'juvenileShortName': ?(juvenileName == null ? null : 'RUC'),
  };

  group('renameUpdate', () {
    test(
      'a new club name: the side gets it, the old one goes in Previously',
      () {
        final update = FixtureRepository.renameUpdate(
          match(),
          'royal',
          team(),
          until,
        )!;
        expect(update['home']['name'], 'Royal Stars FC');
        // Nothing else of the side changes
        expect(update['home']['colour'], '#7A1F2B');
        expect(update.containsKey('away'), isFalse);
        expect(update['previousNames']['royal']['name'], 'Royal Unique FC');
        expect(
          (update['previousNames']['royal']['until'] as Timestamp).toDate(),
          until,
        );
      },
    );

    test('a "B" side follows its club', () {
      final update = FixtureRepository.renameUpdate(
        match(
          category: 'juvenile',
          homeName: 'Royal Unique FC B',
          homeShort: 'RUF B',
        ),
        'royal',
        team(),
        until,
      )!;
      expect(update['home']['name'], 'Royal Stars FC B');
      expect(update['previousNames']['royal']['name'], 'Royal Unique FC B');
    });

    test(
      'a juvenile side with its own name keeps it when the club is renamed',
      () {
        expect(
          FixtureRepository.renameUpdate(
            match(
              category: 'juvenile',
              homeName: 'Royal Unique Colts',
              homeShort: 'RUC',
            ),
            'royal',
            team(juvenileName: 'Royal Unique Colts'),
            until,
          ),
          isNull,
        );
      },
    );

    test('a new short name alone: no Previously', () {
      final update = FixtureRepository.renameUpdate(
        match(homeName: 'Royal Stars FC'),
        'royal',
        team(shortName: 'RSF'),
        until,
      )!;
      expect(update['home']['shortName'], 'RSF');
      expect(update['previousNames'], isEmpty);
    });

    test('renamed twice: Previously is the name just before', () {
      final update = FixtureRepository.renameUpdate(
        match(
          homeName: 'Royal Stars FC',
          previousNames: {
            'royal': {'name': 'Royal Unique FC', 'until': Timestamp.now()},
          },
        ),
        'royal',
        team(name: 'Royal Kings FC'),
        until,
      )!;
      expect(update['previousNames']['royal']['name'], 'Royal Stars FC');
    });

    test('a match that shows the right names already is left alone', () {
      expect(
        FixtureRepository.renameUpdate(
          match(homeName: 'Royal Stars FC'),
          'royal',
          team(),
          until,
        ),
        isNull,
      );
    });
  });

  group('The pill and its note', () {
    Fixture renamed() => Fixture.fromMap(
      'm1',
      match(
        homeName: 'Royal Stars FC',
        previousNames: {
          'royal': {
            'name': 'Royal Unique FC',
            'until': Timestamp.fromDate(until),
          },
        },
      ),
    )!;

    test('the match knows which side was renamed', () {
      final f = renamed();
      expect(f.renamedSides.single.$1.id, 'royal');
      expect(f.renamedSides.single.$2.name, 'Royal Unique FC');
    });

    test('the note says which side, the old name and the day', () {
      final f = renamed();
      final text = RenamedNote.text(
        f.home,
        f.previousNames['royal']!,
        true,
      ).toPlainText();
      expect(
        text,
        'Royal Stars FC (left) was called Royal Unique FC until Mon 9 Nov '
        '2026. Same club: its players and matches carry over.',
      );
    });

    test('a "B" side\'s note names its club', () {
      const side = FixtureSide(
        id: 'royal',
        name: 'Royal Stars FC B',
        shortName: 'RUF B',
        colour: Colors.red,
      );
      final text = RenamedNote.text(
        side,
        PreviousName(name: 'Royal Unique FC B', until: until),
        false,
      ).toPlainText();
      expect(
        text,
        'Royal Stars FC B (right), the juvenile side of Royal Stars FC, was '
        'called Royal Unique FC B until Mon 9 Nov 2026, when its club was '
        'renamed.',
      );
    });

    testWidgets('R1: the pill takes the top-right corner; a tap opens the note '
        'and another tap closes it', (tester) async {
      var opened = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FixtureRow(fixture: renamed(), onTap: () => opened++),
          ),
        ),
      );
      expect(find.text('Previously Royal Unique FC'), findsOneWidget);
      // The ground moves next to the date
      expect(find.textContaining('· Apam Park'), findsOneWidget);
      expect(find.byType(RenamedNote), findsNothing);

      await tester.tap(find.byType(RenamedPill));
      await tester.pump();
      expect(find.byType(RenamedNote), findsOneWidget);
      // The pill opens the note, not the match
      expect(opened, 0);

      await tester.tap(find.byType(RenamedPill));
      await tester.pump();
      expect(find.byType(RenamedNote), findsNothing);
    });

    testWidgets('a row without a renamed team is unchanged', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FixtureRow(fixture: Fixture.fromMap('m2', match())!),
          ),
        ),
      );
      expect(find.byType(RenamedPill), findsNothing);
      expect(find.text('Apam Park'), findsOneWidget);
    });
  });

  test('R5: matches whose names are not the team\'s yet', () {
    final t = Team.fromMap('royal', team());
    final season = [
      Fixture.fromMap('old', match())!,
      Fixture.fromMap('done', match(homeName: 'Royal Stars FC'))!,
    ];
    expect(staleMatchesOf(t, season).map((f) => f.id), ['old']);
    expect(t.sideName(Competition.division), 'Royal Stars FC');
  });
}
