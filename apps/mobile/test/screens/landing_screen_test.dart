// Phase 7 — Landing v2 smoke + anti-regression tests.
//
// Asserts:
//   • The 4 text surfaces render (wordmark, paragraphe-mère, CTA, legal).
//   • Privacy micro-phrase is present.
//   • No banned term (retirement framing, aggressive CTAs) is rendered.
//   • CTA navigates to /onboarding/intent.
//   • Reduced-motion fallback renders content on first pump (no wait).
//
// CONTEXT.md §2 D-01..D-13 | LAND-01, LAND-02, LAND-04, LAND-05, LAND-06.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/landing_screen.dart';

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const LandingScreen(),
      ),
      GoRoute(
        path: '/onboarding/intent',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('INTENT_STUB')),
        ),
      ),
      GoRoute(
        path: '/auth/login',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('LOGIN_STUB')),
        ),
      ),
    ],
  );
}

Widget _wrap({MediaQueryData? mediaQuery}) {
  final router = _buildRouter();
  final app = MaterialApp.router(
    locale: const Locale('fr'),
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    routerConfig: router,
  );
  if (mediaQuery != null) {
    return MediaQuery(data: mediaQuery, child: app);
  }
  return app;
}

void main() {
  group('LandingScreen — calm promise surface', () {
    testWidgets('renders 4 text surfaces and privacy line', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Wordmark
      expect(find.text('MINT'), findsOneWidget);
      // Paragraphe-mère (partial match — fr master text)
      expect(
        find.textContaining("Mint te dit ce que personne"),
        findsOneWidget,
      );
      // CTA
      expect(find.textContaining('Continuer'), findsOneWidget);
      // Privacy micro-phrase
      expect(
        find.textContaining('Rien ne sort de ton téléphone'),
        findsOneWidget,
      );
      // Legal footer
      expect(find.textContaining('LSFin'), findsOneWidget);
    });

    testWidgets('renders zero banned terms', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      const banned = <String>[
        'Commencer',
        'Démarrer',
        'Découvrir',
        'Explorer',
        'Parler au coach',
        'retraite',
        'Retraite',
        'Rente',
        'pension',
        'Ton chiffre',
        'chiffre choc',
      ];
      for (final term in banned) {
        expect(
          find.textContaining(term),
          findsNothing,
          reason: "Landing must not render banned term '$term'",
        );
      }
    });

    testWidgets('CTA routes to /onboarding/intent', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('INTENT_STUB'), findsOneWidget);
    });

    testWidgets('reduced-motion: content visible on first pump', (tester) async {
      final mq = MediaQueryData.fromView(tester.view).copyWith(
        disableAnimations: true,
      );
      await tester.pumpWidget(_wrap(mediaQuery: mq));
      // One extra pump to flush the post-frame callback that jumps to end.
      await tester.pump();

      // Paragraph is present immediately — no animation delay needed.
      expect(
        find.textContaining("Mint te dit ce que personne"),
        findsOneWidget,
      );
      expect(find.textContaining('Continuer'), findsOneWidget);
    });
  });
}
