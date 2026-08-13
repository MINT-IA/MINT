// Phase 7 — Landing v2 smoke + anti-regression tests.
// Phase 73 — Updated for Landing v3 éditorial (PANEL-VERDICT.md):
//   hero now `landingV3Hero` « Voir clair, décider seul. ».
//
// Asserts:
//   • The text surfaces render (wordmark, hero, CTA, legal, login link).
//   • No banned term (retirement framing, aggressive CTAs) is rendered.
//   • CTA navigates to /onb; the retired anonymous chat cold-open is not used.
//   • Reduced-motion fallback renders content on first pump (no wait).
//
// CONTEXT.md §2 D-01..D-13 | LAND-01, LAND-02, LAND-04, LAND-05, LAND-06.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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
      // Mirror production /start redirect: the chat-first anonymous cold-open
      // is retired; first experience enters the explicit onboarding flow.
      GoRoute(
        path: '/start',
        redirect: (_, __) => '/onb',
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
    testWidgets('renders elements: wordmark + hero + CTA + login + legal',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      // Wordmark
      expect(find.text('MINT'), findsOneWidget);
      // Phase 73 hero — landingV3Hero option D, locked.
      expect(find.text('Voir clair, décider seul.'), findsOneWidget);
      // CTA — landingV2CtaSober = « Éclaire ma situation » (D4 vérités: the
      // CTA now names the guided-preview destination, no longer a chat.).
      expect(find.text('Éclaire ma situation'), findsOneWidget);
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

    testWidgets('CTA routes to /onb, not the retired anonymous chat',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('ONB_STUB'), findsOneWidget);
      expect(find.text('ANONYMOUS_CHAT_STUB'), findsNothing);
    });

    testWidgets('AX tap on primary CTA routes to onboarding', (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();

        final node = tester.getSemantics(find.byType(FilledButton));
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        RendererBinding.instance.performSemanticsAction(
          ui.SemanticsActionEvent(
            type: SemanticsAction.tap,
            viewId: tester.view.viewId,
            nodeId: node.id,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ONB_STUB'), findsOneWidget);
        expect(find.text('ANONYMOUS_CHAT_STUB'), findsNothing);
        expect(find.text('LOGIN_STUB'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('primary CTA exposes stable Maestro identifier',
        (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();

        final cta = find.byKey(const Key('landing_talk_to_mint_cta'));
        expect(cta, findsOneWidget);
        expect(find.bySemanticsLabel('Éclaire ma situation'), findsOneWidget);
        final node = tester.getSemantics(cta);
        expect(node.identifier, 'landing_talk_to_mint_cta');
        expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

        RendererBinding.instance.performSemanticsAction(
          ui.SemanticsActionEvent(
            type: SemanticsAction.tap,
            viewId: tester.view.viewId,
            nodeId: node.id,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('ONB_STUB'), findsOneWidget);
        expect(find.text('ANONYMOUS_CHAT_STUB'), findsNothing);
      } finally {
        semantics.dispose();
      }
    });

    testWidgets('CTA actions are inert before reveal animation completes',
        (tester) async {
      Future<void> expectEarlyTapIgnored(
        Finder target, {
        required String unexpectedDestination,
      }) async {
        await tester.pumpWidget(_wrap());

        await tester.tap(target, warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.text(unexpectedDestination), findsNothing);
        expect(find.text('Éclaire ma situation'), findsOneWidget);
      }

      await expectEarlyTapIgnored(
        find.byType(FilledButton),
        unexpectedDestination: 'ONB_STUB',
      );
      // Le second lien vers la même destination a été supprimé
      // (bascule 4) : il ne reste qu'un point d'entrée à tester.
    });

    testWidgets('primary CTA hit area is isolated from the login link',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final cta = find.byKey(const Key('landing_talk_to_mint_cta'));
      final primaryRect = tester.getRect(cta);
      // Le lien redondant vers la même destination a disparu ; le seul
      // voisin cliquable est désormais la connexion.
      final loginRect = tester.getRect(find.text('J\u2019ai déjà un compte'));
      expect(primaryRect.overlaps(loginRect), isFalse);

      final tapPoints = <Offset>[
        primaryRect.center,
        primaryRect.centerLeft + const Offset(8, 0),
        primaryRect.centerRight - const Offset(8, 0),
        primaryRect.topCenter + const Offset(0, 8),
        primaryRect.bottomCenter - const Offset(0, 8),
      ];

      for (final point in tapPoints) {
        await tester.pumpWidget(_wrap());
        await tester.pumpAndSettle();

        await tester.tapAt(point);
        await tester.pumpAndSettle();

        expect(find.text('ONB_STUB'), findsOneWidget);
        expect(find.text('ANONYMOUS_CHAT_STUB'), findsNothing);
      }
    });

    // S005 (Phase 97 W7 iter#4 + fix 517774aa) — anonymous CTA routes to /onb
    // (not /home) so FATCA Q (T2.5) fires before coach chat — otherwise
    // archetype=unknown silently redirects to /waitlist on first message.
    testWidgets(
        'the redundant continue-without-account link is gone and the '
        'landing keeps a single primary destination', (tester) async {
      // Bascule 4 : ce lien menait à la MÊME destination que le CTA
      // principal — faux choix qui diluait le point focal (axes UX +
      // design). Le test devient l'assertion INVERSE.
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      expect(find.text('Continuer sans compte'), findsNothing);
      expect(find.text('Éclaire ma situation'), findsOneWidget,
          reason: 'une seule destination primaire');
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
      expect(find.text('Éclaire ma situation'), findsOneWidget);
    });
  });
}
