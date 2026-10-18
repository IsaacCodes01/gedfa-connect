import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/core/utils/player_key.dart';
import 'package:gedfa_connect/core/utils/search_keys.dart';

void main() {
  group('playerKeyFor', () {
    final dob = DateTime(2004, 3, 15);

    test('makes name + date of birth', () {
      expect(playerKeyFor('Kwame Asante', dob), 'kwame-asante_2004-03-15');
    });

    test('ignores capitals and extra spaces', () {
      expect(
        playerKeyFor('  KWAME   asante ', dob),
        playerKeyFor('Kwame Asante', dob),
      );
    });

    test('drops symbols like apostrophes and dots', () {
      expect(playerKeyFor("Kofi O'Neil Jr.", dob), 'kofi-oneil-jr_2004-03-15');
    });

    test('keeps names that already use a dash', () {
      expect(
        playerKeyFor('Ama Boateng-Mensah', dob),
        'ama-boateng-mensah_2004-03-15',
      );
    });

    test('pads month and day to two digits', () {
      expect(
        playerKeyFor('Yaw Boateng', DateTime(2010, 1, 5)),
        'yaw-boateng_2010-01-05',
      );
    });

    test('different birthdays give different keys', () {
      expect(
        playerKeyFor('Kwame Asante', DateTime(2004, 3, 15)),
        isNot(playerKeyFor('Kwame Asante', DateTime(2005, 3, 15))),
      );
    });
  });

  group('jerseyIdFor', () {
    test('joins competition and number', () {
      expect(jerseyIdFor('division', 10), 'division-10');
    });
  });

  group('searchKeysFor', () {
    test('every word and its beginnings, from 2 letters', () {
      expect(
        searchKeysFor('Kwame Asante'),
        ['kw', 'kwa', 'kwam', 'kwame', 'as', 'asa', 'asan', 'asant', 'asante'],
      );
    });

    test('no repeats when words share a beginning', () {
      final keys = searchKeysFor('Kofi Kofi');
      expect(keys.length, keys.toSet().length);
    });
  });
}
