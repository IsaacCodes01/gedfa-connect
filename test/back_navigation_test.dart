import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gedfa_connect/core/widgets/back_to_home.dart';
import 'package:gedfa_connect/core/widgets/gedfa_app_bar.dart';
import 'package:gedfa_connect/core/widgets/notification_bell.dart';
import 'package:go_router/go_router.dart';

/// Back (3.0f2) on a small copy of the app's shape: two tabs, a page
/// inside tab A, and full-screen pages (a note, an editor) above the tabs.
final _rootKey = GlobalKey<NavigatorState>();

late BuildContext _ctx;

Widget _page(String name, {String? fallback}) => Builder(builder: (context) {
      _ctx = context;
      return Scaffold(
        appBar: GedfaAppBar(
          title: name,
          leading: fallback == null ? null : AppBackButton(fallback: fallback),
        ),
        body: Text('page $name'),
      );
    });

GoRouter _router() => GoRouter(
      navigatorKey: _rootKey,
      initialLocation: '/a',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => Scaffold(
            body: shell,
            bottomNavigationBar: Text('tab ${shell.currentIndex}'),
          ),
          branches: [
            StatefulShellBranch(routes: [
              GoRoute(
                path: '/a',
                builder: (_, _) => _page('A'),
                routes: [
                  GoRoute(
                    path: 'list',
                    builder: (_, _) => _page('A list', fallback: '/a'),
                  ),
                  GoRoute(
                    path: 'note',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => _page('note', fallback: '/a'),
                  ),
                  // The bell and a note, full-screen like the app's
                  GoRoute(
                    path: 'bell',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => Builder(builder: (context) {
                      _ctx = context;
                      return const Scaffold(
                        appBar: GedfaAppBar(
                          title: 'bell',
                          leading: BellBackButton(),
                        ),
                        body: Text('page bell'),
                      );
                    }),
                    routes: [
                      GoRoute(
                        path: 'note',
                        parentNavigatorKey: _rootKey,
                        builder: (_, _) => _page('bell note'),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: _rootKey,
                    builder: (_, _) => _page('edit', fallback: '/a'),
                  ),
                ],
              ),
            ]),
            StatefulShellBranch(routes: [
              GoRoute(path: '/b', builder: (_, _) => _page('B')),
            ]),
          ],
        ),
      ],
    );

final _container = ProviderContainer();

Future<GoRouter> _start(WidgetTester tester) async {
  final router = _router();
  await tester.pumpWidget(UncontrolledProviderScope(
    container: _container,
    child: MaterialApp.router(routerConfig: router),
  ));
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('a full-screen page opens on top; ← comes back', (t) async {
    await _start(t);
    _ctx.open('/a/edit');
    await t.pumpAndSettle();
    expect(find.text('page edit'), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.text('page A'), findsOneWidget);
  });

  testWidgets('a page of the same tab opens on top', (t) async {
    await _start(t);
    _ctx.open('/a/list');
    await t.pumpAndSettle();
    expect(find.text('page A list'), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.text('page A'), findsOneWidget);
  });

  testWidgets('another tab from a note: no crash, ← goes back to the note',
      (t) async {
    final router = await _start(t);
    _ctx.open('/a/note');
    await t.pumpAndSettle();
    _ctx.open('/b');
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('page B'), findsOneWidget);
    expect(find.text('tab 1'), findsOneWidget);
    expect(router.state.uri.queryParameters['back'], '/a/note');
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.text('page note'), findsOneWidget);
  });

  testWidgets("the phone's Back does what ← does", (t) async {
    await _start(t);
    _ctx.open('/a/note');
    await t.pumpAndSettle();
    _ctx.open('/b');
    await t.pumpAndSettle();
    await t.binding.handlePopRoute();
    await t.pumpAndSettle();
    expect(find.text('page note'), findsOneWidget);
  });

  testWidgets("nothing behind: ← goes to the tab's main screen", (t) async {
    final router = await _start(t);
    router.go('/b');
    await t.pumpAndSettle();
    _ctx.goBack('/a');
    await t.pumpAndSettle();
    expect(find.text('page A'), findsOneWidget);
  });

  testWidgets('a page pushed by hand ("Coming soon") does not freeze',
      (t) async {
    await _start(t);
    Navigator.of(_ctx).push(MaterialPageRoute<void>(
      builder: (_) => const Scaffold(
        appBar: GedfaAppBar(title: 'Coming soon'),
        body: Text('soon'),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('soon'), findsOneWidget);
  });

  testWidgets("the bell's ← goes where it was opened, after another tab",
      (t) async {
    final router = await _start(t);
    router.go('/b');
    await t.pumpAndSettle();
    // Opened from tab B (the bell's address is under tab A, like Teams)
    _container.read(bellOriginProvider.notifier).set('/b');
    router.push('/a/bell');
    await t.pumpAndSettle();
    _ctx.open('/a/bell/note');
    await t.pumpAndSettle();
    // A tab's page from the note's button: go with back=
    t.element(find.text('page bell note')).open('/a/list');
    await t.pumpAndSettle();
    expect(find.text('page A list'), findsOneWidget);
    await t.tap(find.byType(BackButton)); // → the note
    await t.pumpAndSettle();
    expect(find.text('page bell note'), findsOneWidget);
    await t.tap(find.byType(BackButton)); // → the bell
    await t.pumpAndSettle();
    expect(find.text('page bell'), findsOneWidget);
    await t.tap(find.byType(BackButton)); // → tab B, not tab A
    await t.pumpAndSettle();
    expect(find.text('page B'), findsOneWidget);
  });
}
