import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/players/data/player_photos.dart';

// 3.6a: the registered photo copied by the FA for the face check

void main() {
  const player = {
    'teamId': 'ruf',
    'photoUrl': 'https://example.com/photo-1.jpg',
    'thumbUrl': 'https://example.com/thumb-1.jpg',
    'fullName': 'Kwame Asante',
  };

  test('the copy holds only the team and the two photo links', () {
    final copy = playerPhotoCopy(player)!;
    expect(copy.keys, {'teamId', 'photoUrl', 'thumbUrl', 'updatedAt'});
    expect(copy['photoUrl'], 'https://example.com/photo-1.jpg');
    expect(copy['thumbUrl'], 'https://example.com/thumb-1.jpg');
    expect(copy['teamId'], 'ruf');
  });

  test('no copy without both links', () {
    expect(playerPhotoCopy({...player, 'photoUrl': null}), isNull);
    expect(playerPhotoCopy({...player, 'thumbUrl': ''}), isNull);
    expect(playerPhotoCopy({...player, 'teamId': null}), isNull);
  });

  test('PlayerPhoto reads a copy, and nothing from a broken one', () {
    final p = PlayerPhoto.fromMap('p1', player)!;
    expect(p.playerId, 'p1');
    expect(p.teamId, 'ruf');
    expect(p.photoUrl, 'https://example.com/photo-1.jpg');
    expect(PlayerPhoto.fromMap('p1', null), isNull);
    expect(PlayerPhoto.fromMap('p1', {'teamId': 'ruf'}), isNull);
  });
}
