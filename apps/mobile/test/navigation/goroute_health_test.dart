// Phase 10-04 — GoRouter health check for surviving onboarding routes
//
// Verifies that after the Phase 10 deletion sweep:
//   - `/` (landing) resolves
//   - `/onboarding/intent` resolves
//   - `/onboarding/quick` + siblings are redirect shims → `/coach/chat`
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

class _Stub extends StatelessWidget {
  final String label;
  const _Stub(this.label);
  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(label, key: Key('stub_$label'))));
}

GoRouter _buildTestRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _Stub('landing')),
      GoRoute(path: '/coach/chat', builder: (_, __) => const _Stub('coach_chat')),
      // Shims (mirror app.dart:843-866)
      GoRoute(path: '/onboarding/quick', redirect: (_, __) => '/coach/chat'),
      GoRoute(
          path: '/onboarding/quick-start', redirect: (_, __) => '/coach/chat'),
      GoRoute(
          path: '/onboarding/premier-eclairage',
          redirect: (_, __) => '/coach/chat'),
      GoRoute(
          path: '/onboarding/promise', redirect: (_, __) => '/coach/chat'),
      GoRoute(path: '/onboarding/plan', redirect: (_, __) => '/coach/chat'),
      // Surviving real routes
      GoRoute(
          path: '/onboarding/intent',
          builder: (_, __) => const _Stub('intent')),
      GoRoute(
          path: '/data-block/:type',
          builder: (_, s) => _Stub('data_block_${s.pathParameters['type']}')),
    ],
  );
}

Future<void> _pumpAndGo(
    WidgetTester tester, GoRouter router, String location) async {
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

    testWidgets('/onboarding/intent resolves to intent screen',
        (tester) async {
      final router = _buildTestRouter();
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await _pumpAndGo(tester, router, '/onboarding/intent');
      expect(find.byKey(const Key('stub_intent')), findsOneWidget);
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

    // Shim redirects — each deleted route must land on coach chat, not 404.
    for (final shim in const [
      '/onboarding/quick',
      '/onboarding/quick-start',
      '/onboarding/premier-eclairage',
      '/onboarding/promise',
      '/onboarding/plan',
    ]) {
      testWidgets('$shim redirects to /coach/chat', (tester) async {
        final router = _buildTestRouter();
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await _pumpAndGo(tester, router, shim);
        expect(find.byKey(const Key('stub_coach_chat')), findsOneWidget,
            reason: '$shim should redirect to /coach/chat');
        expect(find.byKey(const Key('stub_landing')), findsNothing);
      });
    }
  });
}
