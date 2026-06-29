import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

void main() {
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
