// Phase 73 — Landing v3 éditorial structural tests.
//
// Validates the panel-locked spec from
// `.planning/phases/73-landing-v3-editorial/PANEL-VERDICT.md` §3-§4 :
//   • Hero phrase rendered with Fraunces italic.
//   • CTA shape = RoundedRectangleBorder(14), NOT StadiumBorder.
//   • Wordmark letterSpacing = 2 (not 4).
//   • Long-press wordmark → /auth/login.
//   • Tap login link → /auth/login.
//   • Tap CTA → /start → /onb.
//   • Golden screenshot baseline for fr_CH (skipped first-run).

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

Widget _wrap({Locale locale = const Locale('fr')}) {
  return MaterialApp.router(
    locale: locale,
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: S.supportedLocales,
    routerConfig: _buildRouter(),
  );
}

void main() {
  group('Phase 73 — Landing v3 structural panel-lock', () {
    setUp(() {
      FeatureFlags.enableMvpWedgeOnboarding = false;
    });

    tearDown(() {
      FeatureFlags.enableMvpWedgeOnboarding = false;
    });

    testWidgets('Test 1: hero renders landingV3Hero in Fraunces italic',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final heroFinder = find.text('Voir clair, décider seul.');
      expect(heroFinder, findsOneWidget,
          reason: 'Phase 73 hero copy must be the locked option D.');

      final heroWidget = tester.widget<Text>(heroFinder);
      final style = heroWidget.style;
      expect(style, isNotNull);
      expect(style!.fontStyle, FontStyle.italic,
          reason: 'PANEL-VERDICT §3: italic ON.');
      expect(style.fontSize, 40, reason: 'PANEL-VERDICT §3: fontSize 40.');
      expect(style.fontWeight, FontWeight.w400,
          reason: 'PANEL-VERDICT §3: w400.');
      expect(style.height, closeTo(1.2, 0.001));
      expect(style.letterSpacing, closeTo(-0.4, 0.001));
      // Phase 92-03 (FONT-05/07) swapped Fraunces → Gambarino — see
      // apps/mobile/lib/screens/landing_screen.dart:133 + MintTextStyles.displayGambarinoItalic40.
      expect(style.fontFamily, contains('Gambarino'),
          reason:
              'PANEL-VERDICT §3: typography = Gambarino italic 40pt (post Phase 92).');
    });

    testWidgets(
        'Test 2: CTA shape is RoundedRectangleBorder(14), NOT StadiumBorder',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final filled = tester.widget<FilledButton>(find.byType(FilledButton));
      final shape = filled.style?.shape?.resolve(<WidgetState>{});
      expect(shape, isA<RoundedRectangleBorder>(),
          reason: 'PANEL-VERDICT §4 decision 4: PAS StadiumBorder.');
      final rounded = shape as RoundedRectangleBorder;
      final radius = rounded.borderRadius.resolve(TextDirection.ltr).topLeft;
      expect(radius.x, closeTo(14, 0.001),
          reason: 'PANEL-VERDICT §4 decision 4: borderRadius 14.');
    });

    testWidgets('Test 3: wordmark letterSpacing = 2 (not 4)', (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      final wordmark = tester.widget<Text>(find.text('MINT'));
      final ls = wordmark.style?.letterSpacing;
      expect(ls, isNotNull);
      expect(ls!, closeTo(2, 0.001),
          reason:
              'PANEL-VERDICT §4 decision 6: letterSpacing 2 (descended from 4).');
    });

    testWidgets('Test 4: long-press wordmark navigates to /auth/login',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.longPress(find.text('MINT'));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN_STUB'), findsOneWidget,
          reason: 'D-12 long-press hidden affordance preserved.');
    });

    testWidgets('Test 5: tap login link navigates to /auth/login',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('J’ai déjà un compte'));
      await tester.pumpAndSettle();

      expect(find.text('LOGIN_STUB'), findsOneWidget);
    });

    testWidgets('Test 6: tap CTA navigates to /start → /onb by default',
        (tester) async {
      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('ONB_STUB'), findsOneWidget,
          reason: 'CTA → /start, which enters diagnostic onboarding.');
      expect(find.text('ANONYMOUS_CHAT_STUB'), findsNothing);
    });

    testWidgets('Test 6b: tap CTA navigates to /start → /onb when flag is on',
        (tester) async {
      FeatureFlags.enableMvpWedgeOnboarding = true;

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(find.text('ONB_STUB'), findsOneWidget,
          reason:
              'CTA → /start, which redirects to /onb when the diagnostic flag is on.');
    });

    // Test 7: Golden baseline. Skipped on first run; flip to false once
    // a baseline PNG is committed (consistent with Phase 71a/72 pattern).
    testWidgets('Test 7: landing_v3 golden (fr_CH, iPhone 13 width 390)',
        (tester) async {
      tester.view.physicalSize = const Size(390 * 3, 844 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_wrap());
      await tester.pumpAndSettle();

      await expectLater(
        find.byType(LandingScreen),
        matchesGoldenFile('goldens/landing_v3.png'),
      );
    }, skip: true);
  });
}
