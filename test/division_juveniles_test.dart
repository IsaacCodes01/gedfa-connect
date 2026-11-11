import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/players/data/division_juveniles_repository.dart';
import 'package:gedfa_connect/features/players/domain/age_group.dart';
import 'package:gedfa_connect/features/players/domain/division_juveniles.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/players/presentation/widgets/division_juveniles_card.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/team.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Juveniles in the Division (3.1d1, mockups DJ1, DJ2): up to 7, at most
/// 1 U13 and 3 U15. The same limits are in firestore.rules.
void main() {
  Player child(
    String id,
    AgeGroup group, {
    ApprovalStatus status = ApprovalStatus.approved,
  }) => Player(
    id: id,
    teamId: 'ruf',
    teamName: 'Royal Unique FC',
    category: Competition.juvenile,
    ageGroup: group,
    fullName: 'Kofi Child $id',
    dob: DateTime(2011),
    position: Position.cm,
    jerseyNo: id.hashCode % 40 + 1,
    playerCode: 'GJ26-$id',
    status: status,
  );

  group('the limits', () {
    const empty = DivisionJuveniles();

    test('an approved juvenile can be named', () {
      expect(empty.whyNot(child('a', AgeGroup.u15)), isNull);
    });

    test('not a pending child, nor a Division player', () {
      expect(
        empty.whyNot(child('a', AgeGroup.u15, status: ApprovalStatus.pending)),
        contains('approved'),
      );
    });

    test('1 U13 at most', () {
      const one = DivisionJuveniles({'a': AgeGroup.u13});
      expect(one.isFull(AgeGroup.u13), isTrue);
      expect(one.whyNot(child('b', AgeGroup.u13)), contains('U13 limit'));
      expect(one.whyNot(child('c', AgeGroup.u17)), isNull);
    });

    test('3 U15 at most', () {
      const three = DivisionJuveniles({
        'a': AgeGroup.u15,
        'b': AgeGroup.u15,
        'c': AgeGroup.u15,
      });
      expect(three.whyNot(child('d', AgeGroup.u15)), contains('U15 limit'));
    });

    test('7 at most; U17 has no limit of its own', () {
      final seven = DivisionJuveniles({
        for (var i = 0; i < 7; i++) 'u$i': AgeGroup.u17,
      });
      expect(DivisionJuveniles.limitOf(AgeGroup.u17), isNull);
      expect(seven.placesLeft, 0);
      expect(seven.whyNot(child('x', AgeGroup.u17)), contains('All 7'));
    });

    test('read from the list document', () {
      final list = DivisionJuveniles.fromMap({
        'players': {'a': 'U15', 'b': 'U17', 'bad': 'U19'},
      });
      expect(list.players, {'a': AgeGroup.u15, 'b': AgeGroup.u17});
    });
  });

  testWidgets('Squad card and picker fit a small phone (DJ1, DJ2)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // The avatars read the data saver setting
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final players = [
      child('a13', AgeGroup.u13),
      child('b13', AgeGroup.u13),
      child('a15', AgeGroup.u15),
      child('a17', AgeGroup.u17),
      child('b17', AgeGroup.u17),
    ];
    const team = Team(
      id: 'ruf',
      name: 'Royal Unique FC',
      shortName: 'RUF',
      town: 'Apam',
      categories: {Competition.division, Competition.juvenile},
      adminUids: ['u'],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          myDivisionJuvenilesProvider.overrideWith(
            (ref) => Stream.value(
              const DivisionJuveniles({
                'a13': AgeGroup.u13,
                'a17': AgeGroup.u17,
              }),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [DivisionJuvenilesCard(team: team, players: players)],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('2 of 7'), findsOneWidget);
    expect(find.text('Remove'), findsNWidgets(2));
    expect(find.text('Add a juvenile (5 places left)'), findsOneWidget);

    await tester.tap(find.text('Add a juvenile (5 places left)'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Add a juvenile to the Division'), findsOneWidget);
    // U13 is full: the other U13 shows the limit; two named, two to add
    expect(find.text('U13 limit reached'), findsOneWidget);
    expect(find.text('✓ Named'), findsNWidgets(2));
    expect(find.text('Add'), findsNWidgets(2));
  });
}
