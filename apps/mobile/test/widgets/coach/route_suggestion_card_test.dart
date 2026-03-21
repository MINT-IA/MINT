// ────────────────────────────────────────────────────────────
//  ROUTE SUGGESTION CARD TESTS — S58 route_to_screen wiring
//  ReturnContract V2 — ScreenOutcome lifecycle
// ────────────────────────────────────────────────────────────
//
//  Tests:
//  1.  Renders with context_message
//  2.  Shows CTA button via i18n key (no hardcoded strings)
//  3.  Shows partial-readiness warning banner when isPartial == true
//  4.  No partial-readiness warning when isPartial == false
//  5.  Calls onReturn(completed) after normal visit (≥ 5 s)
//  6.  Calls onReturn(abandoned) after quick return (< 5 s)
//  7.  Calls onReturn(changedInputs) when profile hash changes
//  8.  No hardcoded strings in widget tree
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';

// ────────────────────────────────────────────────────────────
//  HELPERS
// ────────────────────────────────────────────────────────────

/// Wraps [child] in a minimal app with i18n and a GoRouter stub.
///
/// The GoRouter is configured with a single `/` route that returns the
/// [child] directly, so no navigation is needed for rendering tests.
/// An additional `/test-target` stub allows push-and-return tests.
Widget _buildTestApp(Widget child) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: child),
      ),
      GoRoute(
        path: '/test-target',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Target Screen')),
        ),
      ),
      GoRoute(
        path: '/rente-vs-capital',
        builder: (context, state) => const Scaffold(
          body: Center(child: Text('Rente vs Capital')),
        ),
      ),
    ],
  );

  return MaterialApp.router(
    routerConfig: router,
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
  );
}

/// Wraps [card] in [_buildTestApp] with phone-sized viewport.
Future<void> _pumpCard(
  WidgetTester tester,
  RouteSuggestionCard card,
) async {
  tester.view.physicalSize = const Size(1080, 1920);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(_buildTestApp(card));
  await tester.pump(const Duration(milliseconds: 100));
}

// ────────────────────────────────────────────────────────────
//  TESTS
// ────────────────────────────────────────────────────────────

void main() {
  group('RouteSuggestionCard', () {
    testWidgets('renders with context_message', (tester) async {
      await _pumpCard(
        tester,
        const RouteSuggestionCard(
          contextMessage: 'Voici le simulateur rente vs capital pour ton profil.',
          route: '/rente-vs-capital',
        ),
      );
      expect(
        find.text('Voici le simulateur rente vs capital pour ton profil.'),
        findsOneWidget,
      );
    });

    testWidgets('shows CTA button with i18n label (routeSuggestionCta)',
        (tester) async {
      await _pumpCard(
        tester,
        const RouteSuggestionCard(
          contextMessage: 'Ouvre le simulateur.',
          route: '/rente-vs-capital',
        ),
      );
      // The CTA label is 'Ouvrir' in French (from routeSuggestionCta key)
      expect(find.text('Ouvrir'), findsOneWidget);
    });

    testWidgets('shows partial warning banner when isPartial is true',
        (tester) async {
      await _pumpCard(
        tester,
        const RouteSuggestionCard(
          contextMessage: 'Estimation disponible.',
          route: '/rente-vs-capital',
          isPartial: true,
        ),
      );
      // routeSuggestionPartialWarning key → 'Estimation — données incomplètes'
      expect(
        find.textContaining('Estimation'),
        findsWidgets, // appears in banner AND possibly context
      );
      // The info icon should be shown in the warning banner
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
    });

    testWidgets('no partial warning banner when isPartial is false',
        (tester) async {
      await _pumpCard(
        tester,
        const RouteSuggestionCard(
          contextMessage: 'Ton profil est complet.',
          route: '/rente-vs-capital',
          isPartial: false,
        ),
      );
      // Warning icon should NOT be present when readiness is full
      expect(find.byIcon(Icons.info_outline), findsNothing);
    });

    // ── ReturnContract V2 — resolveOutcome unit tests ────────
    // These test the static resolution logic directly because widget tests
    // cannot advance DateTime.now() (only the Flutter frame clock advances).

    test('resolveOutcome → completed when elapsed ≥ 5 s and no hash change',
        () {
      final outcome = RouteSuggestionCard.resolveOutcome(
        elapsed: const Duration(seconds: 6),
        hashBefore: 'same',
        hashAfter: 'same',
      );
      expect(outcome, ScreenOutcome.completed);
    });

    test('resolveOutcome → abandoned when elapsed < 5 s', () {
      final outcome = RouteSuggestionCard.resolveOutcome(
        elapsed: const Duration(seconds: 3),
        hashBefore: 'same',
        hashAfter: 'same',
      );
      expect(outcome, ScreenOutcome.abandoned);
    });

    test('resolveOutcome → abandoned exactly at 0 ms (immediate return)', () {
      final outcome = RouteSuggestionCard.resolveOutcome(
        elapsed: Duration.zero,
        hashBefore: null,
        hashAfter: null,
      );
      expect(outcome, ScreenOutcome.abandoned);
    });

    test('resolveOutcome → changedInputs when elapsed ≥ 5 s and hash differs',
        () {
      final outcome = RouteSuggestionCard.resolveOutcome(
        elapsed: const Duration(seconds: 10),
        hashBefore: 'hash_before',
        hashAfter: 'hash_after',
      );
      expect(outcome, ScreenOutcome.changedInputs);
    });

    test('resolveOutcome → completed when hash fn absent (no profileHashFn)',
        () {
      final outcome = RouteSuggestionCard.resolveOutcome(
        elapsed: const Duration(seconds: 8),
        hashBefore: null,
        hashAfter: null,
      );
      expect(outcome, ScreenOutcome.completed);
    });

    test('resolveOutcome → completed exactly at the 5 s threshold', () {
      final outcome = RouteSuggestionCard.resolveOutcome(
        elapsed: const Duration(seconds: 5),
        hashBefore: 'x',
        hashAfter: 'x',
      );
      expect(outcome, ScreenOutcome.completed);
    });

    testWidgets('onReturn callback fires after navigation and return',
        (tester) async {
      ScreenOutcome? receivedOutcome;

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: RouteSuggestionCard(
                contextMessage: 'Ouvre le simulateur.',
                route: '/rente-vs-capital',
                onReturn: (outcome) => receivedOutcome = outcome,
              ),
            ),
          ),
          GoRoute(
            path: '/rente-vs-capital',
            builder: (context, state) => Scaffold(
              appBar: AppBar(title: const Text('Rente vs Capital')),
              body: const Center(child: Text('Rente vs Capital')),
            ),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        locale: const Locale('fr'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // Tap CTA to navigate
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();

      // Pop back immediately (widget-test time = near 0 → abandoned outcome)
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Callback must have fired with a valid ScreenOutcome (not null)
      expect(receivedOutcome, isNotNull);
      expect(ScreenOutcome.values, contains(receivedOutcome));
    });

    testWidgets('contains arrow_forward icon in CTA button', (tester) async {
      await _pumpCard(
        tester,
        const RouteSuggestionCard(
          contextMessage: 'Ouvre la simulation.',
          route: '/rente-vs-capital',
        ),
      );
      expect(find.byIcon(Icons.arrow_forward), findsOneWidget);
    });

    testWidgets('no hardcoded "Ouvrir" string — uses i18n', (tester) async {
      // This test verifies the CTA label is localisation-driven.
      // We pump with English locale and verify the CTA changes.
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: RouteSuggestionCard(
                contextMessage: 'Open the simulator.',
                route: '/rente-vs-capital',
              ),
            ),
          ),
          GoRoute(
            path: '/rente-vs-capital',
            builder: (context, state) =>
                const Scaffold(body: Text('Target')),
          ),
        ],
      );

      tester.view.physicalSize = const Size(1080, 1920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(MaterialApp.router(
        routerConfig: router,
        locale: const Locale('en'),
        localizationsDelegates: const [
          S.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: S.supportedLocales,
      ));
      await tester.pump(const Duration(milliseconds: 100));

      // English locale: CTA should be 'Open' (routeSuggestionCta in en ARB)
      expect(find.text('Open'), findsOneWidget);
      // The French 'Ouvrir' must NOT appear
      expect(find.text('Ouvrir'), findsNothing);
    });

    testWidgets('partial warning uses i18n label (not hardcoded)',
        (tester) async {
      await _pumpCard(
        tester,
        const RouteSuggestionCard(
          contextMessage: 'Données partielles.',
          route: '/rente-vs-capital',
          isPartial: true,
        ),
      );
      // routeSuggestionPartialWarning FR = 'Estimation — données incomplètes'
      expect(
        find.textContaining('données incomplètes'),
        findsOneWidget,
      );
    });

    testWidgets('renders without crashing when onReturn is null',
        (tester) async {
      await _pumpCard(
        tester,
        const RouteSuggestionCard(
          contextMessage: 'Aucun callback.',
          route: '/rente-vs-capital',
          onReturn: null,
        ),
      );
      expect(find.byType(RouteSuggestionCard), findsOneWidget);
    });

    testWidgets('CTA button is tappable', (tester) async {
      await _pumpCard(
        tester,
        const RouteSuggestionCard(
          contextMessage: 'Simulateur.',
          route: '/rente-vs-capital',
        ),
      );
      // Verify the button is present and tappable (no exception)
      expect(find.text('Ouvrir'), findsOneWidget);
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      // Navigation should have happened (target screen visible)
      expect(find.text('Rente vs Capital'), findsOneWidget);
    });

    testWidgets('context_message is displayed as body text', (tester) async {
      const message = 'Ce simulateur te permettra de comparer les deux options.';
      await _pumpCard(
        tester,
        const RouteSuggestionCard(
          contextMessage: message,
          route: '/rente-vs-capital',
        ),
      );
      expect(find.text(message), findsOneWidget);
    });
  });
}
