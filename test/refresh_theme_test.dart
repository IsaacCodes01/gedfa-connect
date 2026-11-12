import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/one_line.dart';
import 'package:gedfa_connect/core/widgets/sending.dart';

/// R-c: the navy bar, cards, dialogs, sheets, chips, snack bars; and
/// buttons whose words never stack on top of each other (Isaac).
void main() {
  group('theme', () {
    test('navy app bar, a shade deeper in dark mode', () {
      expect(AppTheme.light().appBarTheme.backgroundColor, AppColors.navy);
      expect(AppTheme.dark().appBarTheme.backgroundColor, AppColors.darkNavy);
    });

    for (final dark in [false, true]) {
      test('round cards, dialogs and sheets${dark ? ' (dark)' : ''}', () {
        final theme = dark ? AppTheme.dark() : AppTheme.light();
        final card = theme.cardTheme.shape! as RoundedRectangleBorder;
        expect(card.borderRadius, BorderRadius.circular(20));
        final dialog = theme.dialogTheme.shape! as RoundedRectangleBorder;
        expect(dialog.borderRadius, BorderRadius.circular(24));
        final sheet = theme.bottomSheetTheme.shape! as RoundedRectangleBorder;
        expect(
          sheet.borderRadius,
          const BorderRadius.vertical(top: Radius.circular(24)),
        );
        expect(theme.snackBarTheme.behavior, SnackBarBehavior.floating);
        expect(theme.chipTheme.shape, isA<StadiumBorder>());
      });
    }
  });

  testWidgets('the app bar keeps its 4 px Ghana stripe', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(appBar: GedfaAppBar(title: 'Teams')),
      ),
    );
    final bar = tester.widget<AppBar>(find.byType(AppBar));
    expect(bar.bottom!.preferredSize.height, 4);
  });

  // The narrowest phone, three buttons side by side with long words
  for (final dark in [false, true]) {
    testWidgets('buttons in a row keep their words on one line'
        '${dark ? ' (dark)' : ''}', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      const labels = ["Doesn't match", 'Send back to the FA', 'Absent'];
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      for (final label in labels) ...[
                        Expanded(
                          child: FilledButton(
                            onPressed: () {},
                            child: OneLine(Text(label)),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: BusyButton(
                          label: 'Approve all changes',
                          busyLabel: 'Approving…',
                          busy: false,
                          onPressed: () {},
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {},
                          child: const OneLine(Text('Reject with a reason')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      for (final label in [...labels, 'Approve all changes']) {
        final text = tester.renderObject<RenderParagraph>(find.text(label));
        // One line: its height is one line of its font, however narrow
        expect(
          text.size.height,
          lessThan(text.text.style!.fontSize! * 1.6),
          reason: label,
        );
        // and it fits inside its button
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        );
        final box = tester.getRect(button.first);
        final words = tester.getRect(find.text(label));
        expect(
          box.left <= words.left && words.right <= box.right,
          isTrue,
          reason: label,
        );
      }
    });
  }
}
