import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/router.dart';
import 'package:gedfa_connect/app/routes.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/app/theme_mode_provider.dart';
import 'package:gedfa_connect/features/onboarding/data/intro_seen.dart';
import 'package:gedfa_connect/features/onboarding/domain/intro_pages.dart';
import 'package:gedfa_connect/features/onboarding/presentation/intro_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// R-b: the three intro screens, once per phone, before Log in.
void main() {
  group('signed out: where to go', () {
    test('the intro until it has been seen', () {
      expect(signedOutRedirect(Routes.startup, introSeen: false), Routes.intro);
      expect(signedOutRedirect(Routes.login, introSeen: false), Routes.intro);
      expect(signedOutRedirect(Routes.intro, introSeen: false), isNull);
    });

    test('then Log in, Sign up and Forgot password', () {
      expect(signedOutRedirect(Routes.intro, introSeen: true), Routes.login);
      expect(signedOutRedirect(Routes.startup, introSeen: true), Routes.login);
      expect(signedOutRedirect(Routes.login, introSeen: true), isNull);
      expect(signedOutRedirect(Routes.signUp, introSeen: true), isNull);
      expect(signedOutRedirect(Routes.forgotPassword, introSeen: true), isNull);
    });
  });

  test('seen is remembered on the phone', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(introSeenProvider), isFalse);
    await container.read(introSeenProvider.notifier).markSeen();
    expect(container.read(introSeenProvider), isTrue);
    expect(prefs.getBool(IntroSeenNotifier.key), isTrue);

    // A new start of the app reads it back
    final again = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(again.dispose);
    expect(again.read(introSeenProvider), isTrue);
  });

  test('three screens, Isaac\'s words', () {
    expect(introPages, hasLength(3));
    expect(introPages.map((p) => p.kicker), [
      'Your club',
      'Match day',
      'Stay in the game',
    ]);
    for (final page in introPages) {
      expect(page.chips, hasLength(3));
    }
  });

  Widget app(VoidCallback onDone, {bool dark = false}) => MaterialApp(
    theme: dark ? AppTheme.dark() : AppTheme.light(),
    home: IntroView(onDone: onDone),
  );

  testWidgets('→, →, then Get started on the third', (tester) async {
    var done = 0;
    await tester.pumpWidget(app(() => done++));
    await tester.pumpAndSettle();

    expect(find.text(introPages[0].title), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Get started'), findsNothing);

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text(introPages[1].title), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.byTooltip('Next'));
    await tester.pumpAndSettle();
    expect(find.text(introPages[2].title), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(find.byTooltip('Next'), findsNothing);

    await tester.tap(find.text('Get started'));
    expect(done, 1);
  });

  testWidgets('swipe moves between screens; Skip leaves', (tester) async {
    var done = 0;
    await tester.pumpWidget(app(() => done++));
    await tester.pumpAndSettle();

    await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.text(introPages[1].title), findsOneWidget);

    await tester.tap(find.text('Skip'));
    expect(done, 1);
  });

  // Small phone, normal phone, laptop; light and dark: nothing overflows.
  for (final size in const [Size(320, 568), Size(360, 740), Size(1280, 800)]) {
    for (final dark in [false, true]) {
      testWidgets('fits at ${size.width.toInt()}×${size.height.toInt()}'
          '${dark ? ' dark' : ''}', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(app(() {}, dark: dark));
        await tester.pumpAndSettle();
        for (var i = 0; i < introPages.length; i++) {
          expect(tester.takeException(), isNull);
          expect(find.text(introPages[i].title), findsOneWidget);
          if (i < introPages.length - 1) {
            await tester.tap(find.byTooltip('Next'));
            await tester.pumpAndSettle();
          }
        }
        expect(find.text('Get started'), findsOneWidget);
        // The laptop card has ← too (no swiping with a mouse)
        expect(
          find.byTooltip('Back'),
          size.width >= 840 ? findsOneWidget : findsNothing,
        );
      });
    }
  }
}
