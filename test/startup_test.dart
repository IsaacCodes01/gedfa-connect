import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/app/startup_gate.dart';
import 'package:gedfa_connect/app/startup_screen.dart';
import 'package:gedfa_connect/app/theme.dart';
import 'package:gedfa_connect/features/auth/presentation/widgets/auth_widgets.dart';

/// R-a2: the start-up grows from the splash, breathes, glides into Log in.
void main() {
  const logoLabel = 'GEDFA, Gomoa East District Football Association';

  Widget app(Widget child, {bool reduceMotion = false}) => MaterialApp(
    theme: AppTheme.light(),
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(360, 740),
        disableAnimations: reduceMotion,
      ),
      child: child,
    ),
  );

  /// The box the start-up screen puts its logo in (left, top, width).
  Positioned logoBox(WidgetTester tester) => tester.widget<Positioned>(
    find
        .ancestor(
          of: find.bySemanticsLabel(logoLabel),
          matching: find.byType(Positioned),
        )
        .first,
  );

  double logoCenterY(Positioned box) => box.top! + box.width! * 237 / 728 / 2;


  testWidgets('starts at the splash size in the middle, then grows', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const StartupView()));
    var box = logoBox(tester);
    expect(box.width, splashLogoWidth);
    expect(logoCenterY(box), closeTo(740 / 2, 0.5));

    await tester.pump(const Duration(milliseconds: 900));
    box = logoBox(tester);
    expect(box.width, 280);
    expect(logoCenterY(box), closeTo(740 * 0.40, 0.5));
  });

  testWidgets('glides into the exact spot of Log in\'s logo', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var glided = 0;
    Widget view(bool glide) =>
        app(StartupView(glideToLogin: glide, onGlided: () => glided++));
    await tester.pumpWidget(view(false));
    await tester.pump(const Duration(seconds: 2));

    await tester.pumpWidget(view(true));
    await tester.pump(const Duration(milliseconds: 700));
    expect(glided, 1);
    final box = logoBox(tester);
    expect(box.width, AuthScaffold.loginLogoWidth);
    expect(
      logoCenterY(box),
      closeTo(AuthScaffold.heroCenterY(0, AuthScaffold.loginHeroHeight), 0.5),
    );
  });

  testWidgets('Log in draws its logo where the glide ends', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    const logoHeight = AuthScaffold.loginLogoWidth * 237 / 728;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const AuthScaffold(
          heroHeight: AuthScaffold.loginHeroHeight,
          hero: SizedBox(
            key: Key('hero'),
            width: AuthScaffold.loginLogoWidth,
            height: logoHeight,
          ),
          card: SizedBox(height: 300),
        ),
      ),
    );
    final rect = tester.getRect(find.byKey(const Key('hero')));
    expect(rect.width, AuthScaffold.loginLogoWidth);
    expect(rect.center.dx, 180);
    expect(
      rect.center.dy,
      closeTo(AuthScaffold.heroCenterY(0, AuthScaffold.loginHeroHeight), 0.5),
    );
  });

  testWidgets('less motion: big at once, the glide ends at once', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var glided = 0;
    Widget view(bool glide) => app(
      StartupView(glideToLogin: glide, onGlided: () => glided++),
      reduceMotion: true,
    );
    await tester.pumpWidget(view(false));
    expect(logoBox(tester).width, 280);

    await tester.pumpWidget(view(true));
    await tester.pump();
    expect(glided, 1);
    expect(logoBox(tester).width, AuthScaffold.loginLogoWidth);
  });

  testWidgets('shown again later (after Log in): big at once', (tester) async {
    tester.view.physicalSize = const Size(360, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(app(const StartupView(entrance: false)));
    expect(logoBox(tester).width, 280);
  });

  group('the gate', () {
    test('closed, then open; Log in asks about the glide once', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final gate = container.read(startupGateProvider.notifier);

      expect(container.read(startupGateProvider), isFalse);
      gate.open(glideToLogin: true);
      expect(container.read(startupGateProvider), isTrue);
      expect(gate.glideToLogin, isTrue);
      expect(gate.takeGlide(), isTrue);
      expect(gate.takeGlide(), isFalse);
    });

    test('remembers the first page asked for, once', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final gate = container.read(startupGateProvider.notifier);

      gate.rememberWanted('/admin/teams');
      gate.rememberWanted('/admin/home');
      expect(gate.takeWanted(), '/admin/teams');
      expect(gate.takeWanted(), isNull);
    });

    test('the minimum is 2.5 s (Isaac)', () {
      expect(startupMinimum, const Duration(milliseconds: 2500));
    });
  });
}
