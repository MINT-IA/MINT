import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/services/navigation/mint_nav.dart';
import 'package:mint_mobile/services/navigation/safe_pop.dart';

Widget _wrap(GoRouter router) {
  return MaterialApp.router(routerConfig: router);
}

GoRouter _router({
  required String initialLocation,
  required String fallbackRoute,
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/source',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('back'),
              onPressed: () =>
                  MintNav.back(context, fallbackRoute: fallbackRoute),
              child: const Text('Back'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
      GoRoute(
        path: '/onb',
        builder: (context, state) => const Scaffold(body: Text('onboarding')),
      ),
    ],
  );
}

GoRouter _stackRouter() {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/home',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('open-source'),
              onPressed: () => context.push('/source'),
              child: const Text('Open source'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/source',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('back'),
              onPressed: () => MintNav.back(
                context,
                fallbackRoute: MintNav.onboardingFallbackRoute,
              ),
              child: const Text('Back'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/onb',
        builder: (context, state) => const Scaffold(body: Text('onboarding')),
      ),
    ],
  );
}

GoRouter _safePopRouter() {
  return GoRouter(
    initialLocation: '/source',
    routes: [
      GoRoute(
        path: '/source',
        builder: (context, state) => Scaffold(
          body: Center(
            child: ElevatedButton(
              key: const ValueKey('safe-pop'),
              onPressed: () => safePop(context),
              child: const Text('Safe pop'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/home',
        builder: (context, state) => const Scaffold(body: Text('home')),
      ),
    ],
  );
}

GoRouter _shellOpenRouter() {
  return GoRouter(
    initialLocation: '/mon-argent',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return Scaffold(body: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/mon-argent',
                builder: (context, state) => Scaffold(
                  body: ElevatedButton(
                    key: const ValueKey('open-coach'),
                    onPressed: () => MintNav.open<void>(
                      context,
                      '/coach/chat?topic=budget',
                    ),
                    child: const Text('Open coach'),
                  ),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/coach/chat',
                builder: (context, state) => Scaffold(
                  body: Text(
                    'coach:${state.uri.queryParameters['topic']}',
                    key: const ValueKey('coach-topic'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

GoRouter _leafOpenRouter(ValueNotifier<String> result) {
  return GoRouter(
    initialLocation: '/source',
    routes: [
      GoRoute(
        path: '/source',
        builder: (context, state) => Scaffold(
          body: Column(
            children: [
              ElevatedButton(
                key: const ValueKey('open-leaf'),
                onPressed: () async {
                  final value = await MintNav.open<String>(
                    context,
                    '/leaf',
                    extra: {'id': '42'},
                  );
                  result.value = value ?? 'missing';
                },
                child: const Text('Open leaf'),
              ),
              ValueListenableBuilder<String>(
                valueListenable: result,
                builder: (context, value, child) => Text(
                  'result:$value',
                  key: const ValueKey('leaf-result'),
                ),
              ),
            ],
          ),
        ),
      ),
      GoRoute(
        path: '/leaf',
        builder: (context, state) {
          final extra = state.extra as Map<String, String>?;
          return Scaffold(
            body: Column(
              children: [
                Text(
                  'extra:${extra?['id']}',
                  key: const ValueKey('leaf-extra'),
                ),
                ElevatedButton(
                  key: const ValueKey('close-leaf'),
                  onPressed: () => context.pop('done'),
                  child: const Text('Close leaf'),
                ),
              ],
            ),
          );
        },
      ),
    ],
  );
}

void main() {
  group('coachFallbackRouteFor', () {
    test('fresh or incomplete lifecycles return to onboarding', () {
      expect(
        MintNav.coachFallbackRouteFor(AuthLifecycleState.freshVisitor()),
        MintNav.onboardingFallbackRoute,
      );
      expect(
        MintNav.coachFallbackRouteFor(
          AuthLifecycleState.signedInProfileMissing(
            userId: 'user-1',
            cloudSyncEnabled: false,
          ),
        ),
        MintNav.onboardingFallbackRoute,
      );
      expect(
        MintNav.coachFallbackRouteFor(AuthLifecycleState.sessionExpired()),
        MintNav.onboardingFallbackRoute,
      );
    });

    test('main-navigation lifecycles return to the shell', () {
      expect(
        MintNav.coachFallbackRouteFor(
          AuthLifecycleState.guestEmpty(installId: 'install-1'),
        ),
        MintNav.shellFallbackRoute,
      );
      expect(
        MintNav.coachFallbackRouteFor(
          AuthLifecycleState.syncOffAccount(userId: 'user-1'),
        ),
        MintNav.shellFallbackRoute,
      );
      expect(
        MintNav.coachFallbackRouteFor(
          AuthLifecycleState.cloudSyncOnAccount(userId: 'user-1'),
        ),
        MintNav.shellFallbackRoute,
      );
    });
  });

  group('isShellBranchRoot', () {
    test('matches shell roots exactly and preserves query support', () {
      expect(MintNav.isShellBranchRoot('/home'), isTrue);
      expect(MintNav.isShellBranchRoot('/mon-argent'), isTrue);
      expect(MintNav.isShellBranchRoot('/coach/chat'), isTrue);
      expect(MintNav.isShellBranchRoot('/coach/chat?topic=budget'), isTrue);
      expect(MintNav.isShellBranchRoot('/explore'), isTrue);
    });

    test('does not match leaf routes sharing a prefix', () {
      expect(MintNav.isShellBranchRoot('/explore/retraite'), isFalse);
      expect(MintNav.isShellBranchRoot('/coach/history'), isFalse);
      expect(MintNav.isShellBranchRoot('/budget'), isFalse);
      expect(MintNav.isShellBranchRoot('/scan'), isFalse);
    });
  });

  testWidgets('empty stack defaults to shell fallback route', (tester) async {
    final router = _router(
      initialLocation: '/source',
      fallbackRoute: MintNav.shellFallbackRoute,
    );

    await tester.pumpWidget(_wrap(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('back')));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('empty onboarding stack uses explicit onboarding fallback', (
    tester,
  ) async {
    final router = _router(
      initialLocation: '/source',
      fallbackRoute: MintNav.onboardingFallbackRoute,
    );

    await tester.pumpWidget(_wrap(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('back')));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/onb');
    expect(find.text('onboarding'), findsOneWidget);
  });

  testWidgets('non-empty stack pops instead of using fallback', (tester) async {
    final router = _stackRouter();

    await tester.pumpWidget(_wrap(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-source')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('back')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('back')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('open-source')), findsOneWidget);
    expect(find.text('onboarding'), findsNothing);
  });

  testWidgets('open switches shell branch roots with go semantics', (
    tester,
  ) async {
    final router = _shellOpenRouter();

    await tester.pumpWidget(_wrap(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-coach')));
    await tester.pumpAndSettle();

    final uri = router.routerDelegate.currentConfiguration.uri;
    expect(uri.path, '/coach/chat');
    expect(uri.queryParameters['topic'], 'budget');
    expect(router.canPop(), isFalse);
    expect(find.text('coach:budget'), findsOneWidget);
  });

  testWidgets('open pushes leaf routes and returns pop result', (tester) async {
    final result = ValueNotifier<String>('pending');
    final router = _leafOpenRouter(result);

    await tester.pumpWidget(_wrap(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-leaf')));
    await tester.pumpAndSettle();

    expect(router.canPop(), isTrue);
    expect(find.text('extra:42'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('close-leaf')));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/source');
    expect(find.text('result:done'), findsOneWidget);
  });

  testWidgets('safePop shim keeps legacy empty-stack fallback to home',
      (tester) async {
    final router = _safePopRouter();

    await tester.pumpWidget(_wrap(router));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('safe-pop')));
    await tester.pumpAndSettle();

    expect(router.routerDelegate.currentConfiguration.uri.path, '/home');
    expect(find.text('home'), findsOneWidget);
  });
}
