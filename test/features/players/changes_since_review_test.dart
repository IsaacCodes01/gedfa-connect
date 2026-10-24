import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/players/data/player_repository.dart';
import 'package:gedfa_connect/features/players/domain/player.dart';
import 'package:gedfa_connect/features/players/domain/position.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';

Player _player({
  int jersey = 10,
  String name = 'Kwame Asante',
  Map<String, PlayerChange> changes = const {},
}) =>
    Player(
      id: 'p1',
      teamId: 'royal',
      teamName: 'Royal Unique FC',
      category: Competition.division,
      fullName: name,
      dob: DateTime(2004, 3, 15),
      position: Position.cm,
      jerseyNo: jersey,
      status: ApprovalStatus.approved,
      photoUrl: 'https://example.com/photo-1.jpg',
      changes: changes,
    );

void main() {
  test('records the jersey change from and to', () {
    final changes = changesSinceReview(_player(), _player(jersey: 14));
    expect(changes.keys, ['jerseyNo']);
    expect(changes['jerseyNo']!.from, '#10');
    expect(changes['jerseyNo']!.to, '#14');
  });

  test('keeps the first "from" over several saves', () {
    final first = _player(changes: {'jerseyNo': const PlayerChange('#10', '#14')});
    final changes = changesSinceReview(
      first.copyForTest(jersey: 14),
      first.copyForTest(jersey: 15),
    );
    expect(changes['jerseyNo']!.from, '#10');
    expect(changes['jerseyNo']!.to, '#15');
  });

  test('drops a field that was changed back', () {
    final waiting = _player(
      jersey: 14,
      changes: {'jerseyNo': const PlayerChange('#10', '#14')},
    );
    final changes = changesSinceReview(waiting, _player(jersey: 10));
    expect(changes, isEmpty);
  });

  test('records a new photo', () {
    final changes = changesSinceReview(
      _player(),
      _player(),
      newPhotoUrl: 'https://example.com/photo-2.jpg',
    );
    expect(changes['photo']!.from, 'https://example.com/photo-1.jpg');
  });
}

extension on Player {
  Player copyForTest({required int jersey}) => _player(
        jersey: jersey,
        name: fullName,
        changes: changes,
      );
}
