import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/core/utils/name_match.dart';

void main() {
  test('normalizeName', () {
    expect(normalizeName('  Kwame  ASANTE-Jnr. '), 'kwame asante jnr');
  });

  test('editDistance', () {
    expect(editDistance('asante', 'asanteh'), 1);
    expect(editDistance('kofi', 'kofi'), 0);
    expect(editDistance('kofi', 'yaw'), 4);
  });

  group('similarNames', () {
    test('same words, any order', () {
      expect(similarNames('Kwame Asante', 'Asante Kwame'), isTrue);
    });
    test('one inside the other', () {
      expect(similarNames('Kwame Asante', 'Kwame Asante Jnr'), isTrue);
    });
    test('small spelling difference', () {
      expect(similarNames('Kwame Asante', 'Kwame Asanteh'), isTrue);
    });
    test('different people', () {
      expect(similarNames('Kwame Asante', 'Kofi Mensah'), isFalse);
      expect(similarNames('Kwame Asante', 'Kwame Owusu'), isFalse);
    });
  });
}
