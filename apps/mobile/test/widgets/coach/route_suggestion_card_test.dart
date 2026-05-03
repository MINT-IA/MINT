// ────────────────────────────────────────────────────────────
//  ROUTE SUGGESTION CARD TESTS — S58 route_to_screen wiring
// ────────────────────────────────────────────────────────────
//
//  Tests:
//  1.  Renders with context_message
//  2.  Shows CTA button via i18n key (no hardcoded strings)
//  3.  Shows partial-readiness warning banner when isPartial == true
//  4.  No partial-readiness warning when isPartial == false
//  5.  No hardcoded strings in widget tree (i18n locale test)
//  6.  Partial warning uses i18n label
//  7.  CTA button is tappable and navigates
//  8.  context_message is displayed as body text
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/coach/route_suggestion_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ────────────────────────────────────────────────────────────
//  HELPERS
// ────────────────────────────────────────────────────────────

/// Wraps [child] in a minimal app with i18n and a GoRouter stub.
///
/// The GoRouter is configured with a single `/` route that returns the
/// [child] directly, so no navigation is needed for rendering tests.
/// An additional `/rente-vs-capital` stub allows push-and-return tests.
Widget _buildTestApp(Widget child) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => Scaffold(body: child),
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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    RouteSuggestionNavLock.resetForTest();
  });

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
        find.textContaining('données incomplètes'),
        findsOneWidget,
      );
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
      // No warning text when readiness is full
      expect(find.textContaining('données incomplètes'), findsNothing);
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

  // ────────────────────────────────────────────────────────────
  //  Phase 54-02 T-05 — RouteSuggestionNavLock (500 ms debounce)
  // ────────────────────────────────────────────────────────────

  group('RouteSuggestionNavLock (Phase 54-02 T-05)', () {
    test('first acquire returns true', () {
      expect(RouteSuggestionNavLock.tryAcquire(now: DateTime(2026, 5, 4)),
          isTrue);
    });

    test('second acquire within 500ms window returns false', () {
      final t0 = DateTime(2026, 5, 4, 12, 0, 0);
      expect(RouteSuggestionNavLock.tryAcquire(now: t0), isTrue);
      expect(
        RouteSuggestionNavLock.tryAcquire(
          now: t0.add(const Duration(milliseconds: 100)),
        ),
        isFalse,
        reason: 'within window — must be dropped',
      );
      expect(
        RouteSuggestionNavLock.tryAcquire(
          now: t0.add(const Duration(milliseconds: 499)),
        ),
        isFalse,
        reason: 'still within window — must be dropped',
      );
    });

    test('acquire after 500ms window returns true again', () {
      final t0 = DateTime(2026, 5, 4, 12, 0, 0);
      expect(RouteSuggestionNavLock.tryAcquire(now: t0), isTrue);
      expect(
        RouteSuggestionNavLock.tryAcquire(
          now: t0.add(const Duration(milliseconds: 500)),
        ),
        isTrue,
        reason: 'window has elapsed — must allow next nav',
      );
    });

    testWidgets(
        'three rapid taps on the same chip route exactly once (no duplicate push)',
        (tester) async {
      var pushCount = 0;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => const Scaffold(
              body: RouteSuggestionCard(
                contextMessage: 'Ouvre le simulateur.',
                route: '/rente-vs-capital',
              ),
            ),
          ),
          GoRoute(
            path: '/rente-vs-capital',
            redirect: (_, __) {
              pushCount += 1;
              return '/';
            },
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

      // Three rapid taps within the 500ms window.
      await tester.tap(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(pushCount, 1,
          reason:
              'NavLock must dedupe rapid taps — exactly one push allowed per 500ms window');
    });
  });
}
