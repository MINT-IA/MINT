// Phase 10-04 — GoRouter health check for surviving onboarding routes
//
// Verifies that after the Phase 10 deletion sweep:
//   - `/` (landing) resolves
//   - `/onboarding/intent` resolves
//   - `/onboarding/quick` + siblings are redirect shims → `/onb`
//   - `/coach/chat` resolves
//   - `/data-block/:type` resolves
//
// This test uses a hermetic router mirroring the shim topology in app.dart
// rather than importing the full production router (which pulls in Firebase,
// providers, and platform channels unavailable in unit tests). The shim
// structure is copy-pasted from app.dart:839–867 and must be kept in sync.
// If this test starts drifting, the audit doc (ONBOARDING_V2_POST_AUDIT.md)
// is the canonical source for expected route behavior.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/app.dart' show accountLifecyclePublicEntryRedirect;
import 'package:mint_mobile/models/auth_lifecycle_state.dart';

class _Stub extends StatelessWidget {
  final String label;
  const _Stub(this.label);
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(child: Text(label, key: Key('stub_$label'))),
      );
}

GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _Stub('landing')),
      GoRoute(path: '/onb', builder: (_, __) => const _Stub('onb')),
      GoRoute(
        path: '/coach/chat',
        builder: (_, __) => const _Stub('coach_chat'),
      ),
      // Shims mirroring app.dart onboarding compatibility routes.
      GoRoute(path: '/onboarding/quick', redirect: (_, __) => '/onb'),
      GoRoute(path: '/onboarding/quick-start', redirect: (_, __) => '/onb'),
      GoRoute(
        path: '/onboarding/premier-eclairage',
        redirect: (_, __) => '/onb',
      ),
      GoRoute(path: '/onboarding/promise', redirect: (_, __) => '/onb'),
      GoRoute(path: '/onboarding/plan', redirect: (_, __) => '/onb'),
      GoRoute(path: '/onboarding/smart', redirect: (_, __) => '/onb'),
      GoRoute(path: '/onboarding/minimal', redirect: (_, __) => '/onb'),
      // KILL-01: intent_screen deleted, now a redirect shim
      GoRoute(path: '/onboarding/intent', redirect: (_, __) => '/onb'),
      GoRoute(
        path: '/data-block/:type',
        builder: (_, s) => _Stub('data_block_${s.pathParameters['type']}'),
      ),
    ],
  );
}

GoRouter _buildLifecycleRouter(AuthLifecycleState lifecycle) {
  return GoRouter(
    initialLocation: '/',
    redirect: (_, state) => accountLifecyclePublicEntryRedirect(
      lifecycle: lifecycle,
      path: state.uri.path,
    ),
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _Stub('landing')),
      GoRoute(path: '/home', builder: (_, __) => const _Stub('home')),
      GoRoute(path: '/onb', builder: (_, __) => const _Stub('onb')),
      GoRoute(
        path: '/coach/chat',
        builder: (_, __) => const _Stub('coach_chat'),
      ),
      GoRoute(path: '/start', redirect: (_, __) => '/onb'),
      GoRoute(path: '/anonymous/chat', redirect: (_, __) => '/onb'),
      GoRoute(path: '/onboarding/quick', redirect: (_, __) => '/onb'),
    ],
  );
}

GoRouter _buildAccountReadyRouter() {
  return _buildLifecycleRouter(
      AuthLifecycleState.syncOffAccount(userId: 'user-1'));
}

GoRouter _buildGuestRouter() {
  return _buildLifecycleRouter(
      AuthLifecycleState.guestEmpty(installId: 'install-1'));
}

GoRouter _buildProfileMissingRouter() {
  return _buildLifecycleRouter(
    AuthLifecycleState.signedInProfileMissing(
      userId: 'claim-user',
      cloudSyncEnabled: false,
    ),
  );
}

Future<void> _pumpAndGo(
  WidgetTester tester,
  GoRouter router,
  String location,
) async {
  router.go(location);
  await tester.pumpAndSettle();
}

void main() {
  group('P10-04 GoRouter health', () {
    testWidgets('/ resolves to landing', (tester) async {
      final router = _buildTestRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('stub_landing')), findsOneWidget);
    });

    testWidgets('/onboarding/intent redirects to /onb (KILL-01)', (
      tester,
    ) async {
      final router = _buildTestRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _pumpAndGo(tester, router, '/onboarding/intent');
      expect(find.byKey(const Key('stub_onb')), findsOneWidget);
      expect(find.byKey(const Key('stub_coach_chat')), findsNothing);
    });

    testWidgets('/coach/chat resolves', (tester) async {
      final router = _buildTestRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _pumpAndGo(tester, router, '/coach/chat');
      expect(find.byKey(const Key('stub_coach_chat')), findsOneWidget);
    });

    testWidgets('/data-block/:type resolves', (tester) async {
      final router = _buildTestRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _pumpAndGo(tester, router, '/data-block/revenu');
      expect(find.byKey(const Key('stub_data_block_revenu')), findsOneWidget);
    });

    // Shim redirects — each deleted route must land on /onb, not 404 or Coach.
    for (final shim in const [
      '/onboarding/quick',
      '/onboarding/quick-start',
      '/onboarding/premier-eclairage',
      '/onboarding/promise',
      '/onboarding/plan',
      '/onboarding/smart',
      '/onboarding/minimal',
    ]) {
      testWidgets('$shim redirects to /onb', (tester) async {
        final router = _buildTestRouter();
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await _pumpAndGo(tester, router, shim);
        expect(
          find.byKey(const Key('stub_onb')),
          findsOneWidget,
          reason: '$shim should redirect to /onb',
        );
        expect(find.byKey(const Key('stub_coach_chat')), findsNothing);
        expect(find.byKey(const Key('stub_landing')), findsNothing);
      });
    }

    testWidgets(
      '/onboarding/quick with ready account resolves to /home, not Coach',
      (tester) async {
        final router = _buildAccountReadyRouter();
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await _pumpAndGo(tester, router, '/onboarding/quick');
        expect(find.byKey(const Key('stub_home')), findsOneWidget);
        expect(find.byKey(const Key('stub_onb')), findsNothing);
        expect(find.byKey(const Key('stub_coach_chat')), findsNothing);
      },
    );

    testWidgets(
      '/onboarding/quick with missing profile resolves to /onb',
      (tester) async {
        final router = _buildProfileMissingRouter();
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await _pumpAndGo(tester, router, '/onboarding/quick');
        expect(find.byKey(const Key('stub_onb')), findsOneWidget);
        expect(find.byKey(const Key('stub_home')), findsNothing);
        expect(find.byKey(const Key('stub_coach_chat')), findsNothing);
      },
    );

    for (final entry in const ['/start', '/anonymous/chat']) {
      testWidgets('$entry with ready account resolves to /home', (
        tester,
      ) async {
        final router = _buildAccountReadyRouter();
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await _pumpAndGo(tester, router, entry);
        expect(find.byKey(const Key('stub_home')), findsOneWidget);
        expect(find.byKey(const Key('stub_onb')), findsNothing);
      });

      testWidgets('$entry with guest resolves to /onb', (tester) async {
        final router = _buildGuestRouter();
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await _pumpAndGo(tester, router, entry);
        expect(find.byKey(const Key('stub_onb')), findsOneWidget);
        expect(find.byKey(const Key('stub_home')), findsNothing);
      });
    }
  });
}
