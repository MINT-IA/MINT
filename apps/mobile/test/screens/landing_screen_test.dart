// Phase 7 — Landing v2 smoke + anti-regression tests.
// Phase 73 — Updated for Landing v3 éditorial (PANEL-VERDICT.md):
//   hero now `landingV3Hero` « Voir clair, décider seul. ».
//
// Asserts:
//   • The text surfaces render (wordmark, hero, CTA, legal, login link).
//   • No banned term (retirement framing, aggressive CTAs) is rendered.
//   • CTA navigates through /start and falls back to /anonymous/chat when
//     diagnostic onboarding is disabled.
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
      // Mirror production /start redirect while keeping landing state-free.
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
        path: '/auth/login',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('LOGIN_STUB')),
        ),
      ),
      // Anonymous CTA target post-fix 517774aa: /onb (not /home) so FATCA Q fires.
      GoRoute(
        path: '/onb',
        builder: (_, __) => const Scaffold(
          body: Center(child: Text('ONB_STUB')),
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
  group('LandingScreen — Phase 73 v3 éditorial surface', () {
    setUp(() {
      FeatureFlags.enableMvpWedgeOnboarding = false;
    });

    tearDown(() {
      FeatureFlags.enableMvpWedgeOnboarding = false;
    });

    testWidgets('renders elements: wordmark + hero + CTA + login + legal',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Wordmark
      expect(find.text('MINT'), findsOneWidget);
      // Phase 73 hero — landingV3Hero option D, locked.
      expect(find.text('Voir clair, décider seul.'), findsOneWidget);
      // CTA — landingV2CtaSober kept (only the line changed, not button copy).
      expect(find.text('Parle à Mint'), findsOneWidget);
      // No privacy subtitle.
      expect(
        find.textContaining('Rien ne sort de ton téléphone'),
        findsNothing,
      );
      // Legal footer.
      expect(find.textContaining('LSFin'), findsOneWidget);
      // Login link visible.
      expect(find.text('J’ai déjà un compte'), findsOneWidget);
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

    testWidgets('CTA routes to /anonymous/chat when diagnostic flag is off',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('ANONYMOUS_CHAT_STUB'), findsOneWidget);
    });

    // S005 — anonymous local-mode link also delegates to /start so the router,
    // not LandingScreen, owns the first-run rollout switch.
    testWidgets(
        'S005 — « Continuer sans compte » falls back to /anonymous/chat when flag is off',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Continuer sans compte'), findsOneWidget);

      await tester.tap(find.text('Continuer sans compte'));
      await tester.pumpAndSettle();

      expect(find.text('ANONYMOUS_CHAT_STUB'), findsOneWidget);
    });

    testWidgets(
        'S005 — « Continuer sans compte » routes to /onb when flag is on',
        (tester) async {
      FeatureFlags.enableMvpWedgeOnboarding = true;

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Continuer sans compte'), findsOneWidget);

      await tester.tap(find.text('Continuer sans compte'));
      await tester.pumpAndSettle();

      expect(find.text('ONB_STUB'), findsOneWidget);
    });

    testWidgets('reduced-motion: content visible on first pump',
        (tester) async {
      final mq = MediaQueryData.fromView(tester.view).copyWith(
        disableAnimations: true,
      );
      await tester.pumpWidget(_wrap(mediaQuery: mq));
      // One extra pump to flush the post-frame callback that jumps to end.
      await tester.pump();

      // Hero is present immediately — no animation delay needed.
      expect(find.text('Voir clair, décider seul.'), findsOneWidget);
      expect(find.text('Parle à Mint'), findsOneWidget);
    });
  });
}
