import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/core/constants/firestore_paths.dart';
import 'package:gedfa_connect/features/players/data/squad_list.dart';

/// Squad lists (3.1a1): which list a player goes on, and the writes the
/// rules expect (one player per write, named in `changed`).
void main() {
  test('a Division player goes on the division list', () {
    expect(squadGroupFor('division', null), 'division');
    // a stray age group on a Division player is ignored
    expect(squadGroupFor('division', 'U15'), 'division');
  });

  test('a juvenile player goes on their age group list', () {
    expect(squadGroupFor('juvenile', 'U13'), 'U13');
    expect(squadGroupFor('juvenile', 'U17'), 'U17');
  });

  test('the list path is team + group', () {
    expect(
      FirestorePaths.squad('royal', 'U15'),
      'districts/gomoa-east/squads/royal_U15',
    );
  });

  test('adding names the one player and the list it belongs to', () {
    final add = squadAddition('royal', 'division', 'p1');
    expect(add['teamId'], 'royal');
    expect(add['group'], 'division');
    expect(add['players'], {'p1': true});
    expect(add['changed'], 'p1');
    expect(add['updatedAt'], isA<FieldValue>());
  });

  test('removing deletes only that player', () {
    final remove = squadRemoval('p1');
    expect(remove.keys, {'players.p1', 'changed', 'updatedAt'});
    expect(remove['changed'], 'p1');
  });
}
