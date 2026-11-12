import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/startup_screen.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/core/widgets/loading.dart';
import 'package:gedfa_connect/core/widgets/sending.dart';

/// M1, M2: the shared loading and sending looks.
void main() {
  Widget app(Widget child, {bool dark = false}) => MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: Scaffold(body: child),
  );

  group('L1 start-up', () {
    test('greets by the time of day', () {
      expect(greetingFor(7), 'Good morning!');
      expect(greetingFor(13), 'Good afternoon!');
      expect(greetingFor(19), 'Good evening!');
    });

    testWidgets('changes its friendly line and says when it is slow', (
      tester,
    ) async {
      await tester.pumpWidget(app(const StartupView()));
      expect(find.text('GEDFA Connect'), findsOneWidget);
      expect(find.text(slowLoadingText), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text(startupLines.first), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(slowLoadingText), findsOneWidget);
    });

    testWidgets('a failed start-up offers Try again', (tester) async {
      var tries = 0;
      await tester.pumpWidget(
        app(StartupView(failed: true, onRetry: () => tries++), dark: true),
      );
      await tester.tap(find.text('Try again'));
      expect(tries, 1);
    });
  });

  group('L2 loading', () {
    testWidgets('LoadingView shows its words, then the slow note', (
      tester,
    ) async {
      await tester.pumpWidget(
        app(const LoadingView(message: 'Loading the match…')),
      );
      expect(find.text('Loading the match…'), findsOneWidget);
      expect(find.byType(RollingBall), findsOneWidget);
      expect(find.text(slowLoadingText), findsNothing);

      await tester.pump(slowAfter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(slowLoadingText), findsOneWidget);
    });

    for (final dark in [false, true]) {
      testWidgets('SkeletonList lays out on a phone (dark: $dark)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          app(const SkeletonList(message: 'Getting your squad…'), dark: dark),
        );
        await tester.pump(const Duration(milliseconds: 700));
        expect(find.text('Getting your squad…'), findsOneWidget);
        expect(find.byType(SkeletonBox), findsWidgets);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('M2 sending', () {
    testWidgets('BusyButton shows what it is doing and ignores taps', (
      tester,
    ) async {
      var taps = 0;
      Widget button(bool busy) => app(
        Padding(
          padding: const EdgeInsets.all(16),
          child: BusyButton(
            label: 'Save',
            busyLabel: 'Saving…',
            busy: busy,
            onPressed: () => taps++,
          ),
        ),
      );

      await tester.pumpWidget(button(false));
      await tester.tap(find.text('Save'));
      expect(taps, 1);

      await tester.pumpWidget(button(true));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Saving…'), findsOneWidget);
      await tester.tap(find.text('Saving…'), warnIfMissed: false);
      expect(taps, 1);

      await tester.pump(slowAfter);
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text(slowSendingText), findsOneWidget);
    });

    testWidgets('SendingSheet shows progress and closes when done', (
      tester,
    ) async {
      late BuildContext ctx;
      await tester.pumpWidget(
        app(
          Builder(
            builder: (context) {
              ctx = context;
              return const SizedBox.shrink();
            },
          ),
        ),
      );

      void Function(int, int)? report;
      final finish = Future<int>.delayed(const Duration(seconds: 1), () => 7);
      final result = SendingSheet.run(
        ctx,
        title: 'Publishing the season…',
        unit: 'Match',
        task: (progress) {
          report = progress;
          return finish;
        },
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('Publishing the season…'), findsOneWidget);

      report!(21, 36);
      await tester.pump();
      expect(find.text('Match 21 of 36'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 500));
      expect(await result, 7);
      expect(find.text('Publishing the season…'), findsNothing);
    });
  });
}
