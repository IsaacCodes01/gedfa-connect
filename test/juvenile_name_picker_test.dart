import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/core/constants/approval_status.dart';
import 'package:gedfa_connect/features/teams/domain/competition.dart';
import 'package:gedfa_connect/features/teams/domain/kit.dart';
import 'package:gedfa_connect/features/teams/domain/team_request.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/b_side_ring.dart';
import 'package:gedfa_connect/features/teams/presentation/widgets/juvenile_name_picker.dart';

/// Juvenile side names, registration (JSb, mockups JS1, JS1b).
void main() {
  const kit = Kit(
    primary: Color(0xFF7A1F2B),
    shorts: Color(0xFFFFFFFF),
    socks: Color(0xFF7A1F2B),
  );

  TeamRequest request({
    Set<Competition> categories = const {
      Competition.division,
      Competition.juvenile,
    },
    String? juvenileName,
    String? juvenileShortName,
  }) => TeamRequest(
    uid: 'u1',
    teamName: 'Royal Unique FC',
    shortName: 'ruf',
    town: 'Gomoa Fetteh',
    homeGround: 'Fetteh Park',
    homeKit: kit,
    awayKit: kit,
    goalkeeperKit: kit,
    officials: const [],
    status: ApprovalStatus.pending,
    categories: categories,
    juvenileName: juvenileName,
    juvenileShortName: juvenileShortName,
  );

  group('TeamRequest', () {
    test('"B" sends no juvenile name; the side shows as "<name> B"', () {
      final r = request();
      expect(r.hasOwnJuvenileName, isFalse);
      expect(r.toEditableMap()['juvenileName'], isNull);
      expect(r.juvenileSide, (name: 'Royal Unique FC B', shortName: 'RUF B'));
    });

    test('an own name is sent trimmed, with a short name in capitals', () {
      final r = request(
        juvenileName: ' Royal Unique Colts ',
        juvenileShortName: 'ruc',
      );
      expect(r.hasOwnJuvenileName, isTrue);
      expect(r.toEditableMap()['juvenileName'], 'Royal Unique Colts');
      expect(r.toEditableMap()['juvenileShortName'], 'RUC');
      expect(r.juvenileSide, (name: 'Royal Unique Colts', shortName: 'RUC'));
    });

    test('a club in one competition never sends a juvenile name', () {
      final r = request(
        categories: {Competition.juvenile},
        juvenileName: 'Royal Unique Colts',
        juvenileShortName: 'RUC',
      );
      expect(r.hasOwnJuvenileName, isFalse);
      expect(r.toEditableMap()['juvenileName'], isNull);
      expect(r.toEditableMap()['juvenileShortName'], isNull);
    });
  });

  group('JuvenileNamePicker', () {
    Future<GlobalKey<FormState>> pump(
      WidgetTester tester, {
      required bool ownName,
      String name = '',
      String shortName = '',
    }) async {
      final formKey = GlobalKey<FormState>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: JuvenileNamePicker(
                  clubName: 'Royal Unique FC',
                  clubShortName: 'RUF',
                  ownName: ownName,
                  onOwnNameChanged: (_) {},
                  name: TextEditingController(text: name),
                  shortName: TextEditingController(text: shortName),
                  enabled: true,
                  logoColor: const Color(0xFF7A1F2B),
                ),
              ),
            ),
          ),
        ),
      );
      return formKey;
    }

    testWidgets('JS1: "B" is shown with the gold ring and the Division note', (
      tester,
    ) async {
      await pump(tester, ownName: false);
      // The option and the preview
      expect(find.text('Royal Unique FC B'), findsNWidgets(2));
      expect(find.byType(BSideRing), findsOneWidget);
      expect(
        find.textContaining('Only clubs in both competitions'),
        findsOneWidget,
      );
      expect(find.text('Juvenile side name'), findsNothing);
    });

    testWidgets('JS1b: its own name, previewed without the ring', (
      tester,
    ) async {
      final form = await pump(
        tester,
        ownName: true,
        name: 'Royal Unique Colts',
        shortName: 'RUC',
      );
      expect(find.text('Juvenile side name'), findsOneWidget);
      expect(find.text('RUC · U13, U15 and U17'), findsOneWidget);
      expect(find.byType(BSideRing), findsNothing);
      expect(form.currentState!.validate(), isTrue);
    });

    testWidgets("the club's own name or short name is refused", (tester) async {
      final form = await pump(
        tester,
        ownName: true,
        name: 'Royal Unique FC',
        shortName: 'RUF',
      );
      expect(form.currentState!.validate(), isFalse);
      await tester.pump();
      expect(find.textContaining("Not your club's name"), findsOneWidget);
      expect(find.text("Not your club's short name (RUF)"), findsOneWidget);
    });
  });
}
