import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/features/teams/domain/team_change.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/juvenile_name_picker.dart';

/// Juvenile side names, ask the FA (JSc1, mockups JS3, JS3b, JS4).
void main() {
  TeamChange change(Map<String, dynamic> data) =>
      TeamChange.fromMap('royal_juvenileName', {
        'teamId': 'royal',
        'teamName': 'Royal Unique FC',
        'kind': 'juvenileName',
        'reason': '',
        'status': 'pending',
        ...data,
      });

  group('TeamChange', () {
    test('an own name: the bell says "juvenile side name → <name>"', () {
      final c = change({
        'from': 'Royal Unique FC B',
        'fromShortName': 'RUF B',
        'to': 'Royal Unique Colts',
        'toShortName': 'RUC',
        'nameKey': 'royal-unique-colts',
      });
      expect(c.kind, TeamChangeKind.juvenileName);
      expect(c.isBackToB, isFalse);
      expect(c.summary, 'Juvenile side name → Royal Unique Colts');
      expect(c.toShortName, 'RUC');
      expect(c.fromShortName, 'RUF B');
    });

    test('back to "B": an empty name', () {
      final c = change({
        'from': 'Royal Unique Colts',
        'fromShortName': 'RUC',
        'to': '',
        'toShortName': '',
      });
      expect(c.isBackToB, isTrue);
      expect(c.summary, 'Juvenile side name → "B"');
    });

    test('"Add Juvenile" carries the juvenile name when one was picked', () {
      final c = TeamChange.fromMap('royal_competition', {
        'teamId': 'royal',
        'teamName': 'Royal Unique FC',
        'kind': 'competition',
        'from': ['division'],
        'to': 'juvenile',
        'juvenileName': 'Royal Unique Colts',
        'juvenileShortName': 'RUC',
        'reason': 'We start an academy',
        'status': 'pending',
      });
      expect(c.juvenileName, 'Royal Unique Colts');
      expect(c.juvenileShortName, 'RUC');
      expect(c.isBackToB, isFalse);
    });
  });

  group('JuvenileNamePicker, compact (JS3b)', () {
    Future<GlobalKey<FormState>> pump(
      WidgetTester tester, {
      required String name,
      required String shortName,
    }) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: JuvenileNamePicker(
                  compact: true,
                  clubName: 'Royal Unique FC',
                  clubShortName: 'RUF',
                  ownName: true,
                  onOwnNameChanged: (_) {},
                  name: TextEditingController(text: name),
                  shortName: TextEditingController(text: shortName),
                  enabled: true,
                  logoColor: const Color(0xFF7A1F2B),
                  currentName: 'Royal Unique Colts',
                  currentShortName: 'RUC',
                ),
              ),
            ),
          ),
        ),
      );
      return formKey;
    }

    testWidgets('just the choices and the fields, with the short texts', (
      tester,
    ) async {
      await pump(tester, name: 'Royal Unique Juniors', shortName: 'RUJ');
      expect(find.text("Your juvenile side's name"), findsNothing);
      expect(find.text('Your club\'s name with "B"'), findsOneWidget);
      expect(find.text('A different name and short name'), findsOneWidget);
      expect(find.textContaining('Only clubs in both'), findsNothing);
    });

    testWidgets('asking for the name it already has is refused', (
      tester,
    ) async {
      final form = await pump(
        tester,
        name: 'Royal Unique Colts',
        shortName: 'RUC',
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(
        find.text("This is your juvenile side's name already"),
        findsOneWidget,
      );
    });

    testWidgets('the same name with a new short name is fine', (tester) async {
      final form = await pump(
        tester,
        name: 'Royal Unique Colts',
        shortName: 'RUCO',
      );
      expect(form.currentState!.validate(), isTrue);
    });
  });
}
