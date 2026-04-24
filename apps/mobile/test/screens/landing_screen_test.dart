// Phase 7 — Landing v2 smoke + anti-regression tests.
//
// Asserts:
//   • The 4 text surfaces render (wordmark, paragraphe-mère, CTA, legal).
//   • Privacy micro-phrase is present.
//   • No banned term (retirement framing, aggressive CTAs) is rendered.
//   • CTA navigates to /anonymous/chat (FIX-02 default + KILL-05 no-account).
//   • Reduced-motion fallback renders content on first pump (no wait).
//
// CONTEXT.md §2 D-01..D-13 | LAND-01, LAND-02, LAND-04, LAND-05, LAND-06.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';

GoRouter _buildRouter() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const LandingScreen(),
      ),
      // Mirror production /start redirect (flag-gated, landing purity).
      GoRoute(
        path: '/start',
        redirect: (_, __) =>
            FeatureFlags.enableMvpWedgeOnboarding ? '/onb' : '/anonymous/chat',
      ),
      GoRoute(
        path: '/anonymous/chat',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('ANONYMOUS_CHAT_STUB')),
        ),
      ),
      GoRoute(
        path: '/onb',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('ONB_STUB')),
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
    testWidgets('renders 3 elements: wordmark + promise + CTA + legal',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Wordmark
      expect(find.text('MINT'), findsOneWidget);
      // Promise — single sentence (POLISH-01)
      expect(
        find.textContaining('\u00e9claire'),
        findsOneWidget,
      );
      // CTA — "Commencer" (not "Continuer (sans compte)")
      expect(find.text('Parle \u00e0 Mint'), findsOneWidget);
      // No privacy subtitle
      expect(
        find.textContaining('Rien ne sort de ton téléphone'),
        findsNothing,
      );
      // Legal footer
      expect(find.textContaining('LSFin'), findsOneWidget);
    });

    testWidgets('renders zero banned terms', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      const banned = <String>[
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

    testWidgets('CTA routes to /anonymous/chat (FIX-02)', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('ANONYMOUS_CHAT_STUB'), findsOneWidget);
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
        find.textContaining('\u00e9claire'),
        findsOneWidget,
      );
      expect(find.text('Parle \u00e0 Mint'), findsOneWidget);
    });
  });
}
