import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/core/utils/player_code.dart';

void main() {
  test('pads the number to 4 digits', () {
    expect(playerCodeFor(1, 2026), 'GE26-0001');
    expect(playerCodeFor(43, 2026), 'GE26-0043');
    expect(playerCodeFor(999, 2026), 'GE26-0999');
    expect(playerCodeFor(1000, 2026), 'GE26-1000');
  });

  test('uses the last two digits of the year', () {
    expect(playerCodeFor(7, 2027), 'GE27-0007');
  });
}
