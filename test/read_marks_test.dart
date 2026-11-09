import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/notifications/data/notifications_repository.dart';
import 'package:gedfa_connect/features/notifications/domain/app_notification.dart';

void main() {
  final seen = DateTime.utc(2026, 11, 9, 9);
  final at = DateTime.utc(2026, 11, 9, 10, 42);

  group('ReadMark (3.0f)', () {
    test('older than Mark all read: read', () {
      final mark = ReadMark(seenAt: seen);
      expect(mark.isUnread('n1', seen.subtract(const Duration(hours: 1))),
          isFalse);
    });

    test('newer and never opened: unread', () {
      expect(ReadMark(seenAt: seen).isUnread('n1', at), isTrue);
      expect(const ReadMark().isUnread('n1', at), isTrue);
    });

    test('opened at this time: read, and only that note', () {
      final mark = ReadMark(seenAt: seen, reads: {'n1': at});
      expect(mark.isUnread('n1', at), isFalse);
      expect(mark.isUnread('n2', at), isTrue);
    });

    test('a grouped note that changed after I read it is unread again', () {
      final mark = ReadMark(seenAt: seen, reads: {'n1': at});
      final later = at.add(const Duration(minutes: 5));
      expect(mark.isUnread('n1', later), isTrue);
      expect(mark.changedSinceRead('n1', later), isTrue);
      expect(mark.changedSinceRead('n2', later), isFalse);
    });

    test('the web keeps no microseconds: still read', () {
      final withMicros = at.add(const Duration(microseconds: 700));
      final mark = ReadMark(seenAt: seen, reads: {'n1': at});
      expect(mark.isUnread('n1', withMicros), isFalse);
    });
  });

  group('Notification details text (3.0f)', () {
    const approved = AppNotification(
      id: 'n1',
      audience: 'team:royal',
      kind: NotificationKind.playersApproved,
      teamId: 'royal',
      teamName: 'Royal Unique FC',
      names: ['Kwame Asante', 'Yaw Mensah', 'Kofi Boateng', 'Ato Sam'],
      count: 4,
    );

    test('the list keeps "and 2 more"; details list every name', () {
      expect(
        approved.body,
        'Kwame Asante, Yaw Mensah and 2 more. They can now be picked on '
        'team sheets.',
      );
      expect(approved.listsNames, isTrue);
      expect(approved.detailText, 'They can now be picked on team sheets.');
    });

    test('team notes come from GEDFA, FA notes from the team', () {
      expect(approved.sender, 'GEDFA');
      const sent = AppNotification(
        id: 'n2',
        audience: 'fa',
        kind: NotificationKind.playersSubmitted,
        teamId: 'royal',
        teamName: 'Royal Unique FC',
        names: ['Ebo Quansah'],
        count: 1,
      );
      expect(sent.sender, 'Royal Unique FC');
    });

    test('a single-sentence note keeps its text in full', () {
      const asked = AppNotification(
        id: 'n3',
        audience: 'team:royal',
        kind: NotificationKind.correctionAsked,
        teamId: 'royal',
        teamName: 'Royal Unique FC',
        names: ['Home ground'],
        count: 1,
      );
      expect(asked.listsNames, isFalse);
      expect(asked.detailText, asked.body);
    });
  });
}
