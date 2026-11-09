import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/fixtures/domain/fixture.dart';
import 'package:gedfa_connect/features/fixtures/presentation/widgets/fixture_row.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/side_name.dart';

/// Juvenile side names (JSa): how a club is called in each competition.
void main() {
  const both = {Competition.division, Competition.juvenile};

  ({String name, String shortName}) names(
    Set<Competition> categories,
    Competition category, {
    String? juvenileName,
    String? juvenileShortName,
  }) => sideNames(
    name: 'Royal Unique FC',
    shortName: 'RUF',
    categories: categories,
    category: category,
    juvenileName: juvenileName,
    juvenileShortName: juvenileShortName,
  );

  test('a club in both plays its juvenile matches with "B"', () {
    expect(names(both, Competition.juvenile), (
      name: 'Royal Unique FC B',
      shortName: 'RUF B',
    ));
  });

  test('its Division side keeps the club name', () {
    expect(names(both, Competition.division), (
      name: 'Royal Unique FC',
      shortName: 'RUF',
    ));
  });

  test('a club in one competition never gets a "B"', () {
    expect(names({Competition.juvenile}, Competition.juvenile), (
      name: 'Royal Unique FC',
      shortName: 'RUF',
    ));
    expect(names({Competition.division}, Competition.division), (
      name: 'Royal Unique FC',
      shortName: 'RUF',
    ));
  });

  test('an own juvenile name replaces the "B"', () {
    expect(
      names(
        both,
        Competition.juvenile,
        juvenileName: 'Royal Unique Colts',
        juvenileShortName: 'RUC',
      ),
      (name: 'Royal Unique Colts', shortName: 'RUC'),
    );
  });

  test(
    'a match knows a "B" side from its short name; the crest drops the B',
    () {
      const b = FixtureSide(
        id: 'r',
        name: 'Royal Unique FC B',
        shortName: 'RUF B',
        colour: Colors.red,
      );
      const own = FixtureSide(
        id: 'r',
        name: 'Royal Unique Colts',
        shortName: 'RUC',
        colour: Colors.red,
      );
      expect(b.isBSide, isTrue);
      expect(b.crestLabel, 'RUF');
      expect(own.isBSide, isFalse);
      expect(own.crestLabel, 'RUC');
    },
  );

  testWidgets('a "B" crest keeps the same size as any other crest', (
    tester,
  ) async {
    const b = FixtureSide(
      id: 'r',
      name: 'Royal Unique FC B',
      shortName: 'RUF B',
      colour: Colors.red,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: FixtureCrest(side: b, size: 32)),
        ),
      ),
    );
    expect(tester.getSize(find.byType(FixtureCrest)), const Size(32, 32));
    expect(find.text('RUF'), findsOneWidget);
  });
}
