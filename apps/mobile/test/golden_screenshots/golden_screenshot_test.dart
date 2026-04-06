// Golden screenshot regression tests for key v2.0 screens.
//
// Purpose: Pixel-level regression guard. NOT design approval.
// Phone sizes: iPhone SE (375x667), iPhone 15 (393x852).
// Languages: FR baseline + DE variant per screen.
//
// Run with --update-goldens to refresh baselines:
//   flutter test test/golden_screenshots/golden_screenshot_test.dart --update-goldens
//
// See README.md for update protocol and 1.5% threshold policy.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/anticipation_provider.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/contextual_card_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/main_tabs/mint_home_screen.dart';
import 'package:mint_mobile/screens/onboarding/intent_screen.dart';
import 'package:mint_mobile/screens/profile/privacy_control_screen.dart';
import 'package:mint_mobile/widgets/onboarding/premier_eclairage_card.dart';

import 'golden_test_helpers.dart';

// ---------------------------------------------------------------------------
// Phone size definitions
// ---------------------------------------------------------------------------

/// iPhone SE logical size (375 x 667).
const Size _kIPhoneSE = Size(375, 667);

/// iPhone 15 logical size (393 x 852).
const Size _kIPhone15 = Size(393, 852);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Sets viewport to the given logical size at 3x pixel ratio.
void _setViewport(WidgetTester tester, Size logicalSize) {
  tester.view.physicalSize = logicalSize * 3.0;
  tester.view.devicePixelRatio = 3.0;
}

/// Builds a localized MaterialApp with the given [locale] and providers.
Widget _buildLocalizedWidget(
  Widget child, {
  Locale locale = const Locale('fr'),
  List<SingleChildWidget> extraProviders = const [],
}) {
  return buildGoldenWidget(
    child,
    extraProviders: extraProviders,
  );
}

/// Builds the same widget but with a different locale for DE tests.
Widget _buildDeWidget(
  Widget child, {
  List<SingleChildWidget> extraProviders = const [],
}) {
  final providers = <SingleChildWidget>[
    ChangeNotifierProvider<CoachProfileProvider>(
      create: (_) => CoachProfileProvider(),
    ),
    ...extraProviders,
  ];

  return MultiProvider(
    providers: providers,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      locale: const Locale('de'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF00382E)),
        useMaterial3: true,
      ),
      home: child,
    ),
  );
}

void main() {
  setUp(() async {
    await setupGoldenEnvironment();
    SharedPreferences.setMockInitialValues({
      'analytics_consent_given': true,
      'nLPD_consent_given': true,
      // Ensure premier eclairage card is hidden by default in home tests.
      'has_seen_premier_eclairage': true,
    });
  });

  // =========================================================================
  // 0. Font warmup (shared across all groups)
  // =========================================================================

  group('Golden Screenshots — Font Warmup', () {
    testWidgets('warmup — preload fonts (no assertions)', (tester) async {
      setGoldenViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(
        tester,
        buildGoldenWidget(const Scaffold(body: Text('Warmup'))),
        warmup: kFontWarmupDuration,
      );
    });
  });

  // =========================================================================
  // 1. MintHomeScreen (empty state)
  // =========================================================================

  group('Golden Screenshots — MintHomeScreen (empty state)', () {
    List<SingleChildWidget> homeProviders() => [
          ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider(),
          ),
          ChangeNotifierProvider<ContextualCardProvider>(
            create: (_) => ContextualCardProvider(),
          ),
          ChangeNotifierProvider<AnticipationProvider>(
            create: (_) => AnticipationProvider(),
          ),
          ChangeNotifierProvider<BiographyProvider>(
            create: (_) => BiographyProvider(),
          ),
          ChangeNotifierProvider<UserActivityProvider>(
            create: (_) => UserActivityProvider(),
          ),
          ChangeNotifierProvider<FinancialPlanProvider>(
            create: (_) => FinancialPlanProvider(),
          ),
        ];

    testWidgets('home empty — iPhone SE FR', (tester) async {
      _setViewport(tester, _kIPhoneSE);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(
        tester,
        _buildLocalizedWidget(
          const MintHomeScreen(),
          extraProviders: homeProviders(),
        ),
      );

      await expectLater(
        find.byType(MintHomeScreen),
        matchesGoldenFile('goldens/home_empty_se_fr.png'),
      );
    });

    testWidgets('home empty — iPhone 15 FR', (tester) async {
      _setViewport(tester, _kIPhone15);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(
        tester,
        _buildLocalizedWidget(
          const MintHomeScreen(),
          extraProviders: homeProviders(),
        ),
      );

      await expectLater(
        find.byType(MintHomeScreen),
        matchesGoldenFile('goldens/home_empty_15_fr.png'),
      );
    });
  });

  // =========================================================================
  // 2. IntentScreen
  // =========================================================================

  group('Golden Screenshots — IntentScreen', () {
    testWidgets('intent — iPhone 15 FR', (tester) async {
      _setViewport(tester, _kIPhone15);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(
        tester,
        _buildLocalizedWidget(const IntentScreen()),
      );

      await expectLater(
        find.byType(IntentScreen),
        matchesGoldenFile('goldens/intent_15_fr.png'),
      );
    });

    testWidgets('intent — iPhone SE FR', (tester) async {
      _setViewport(tester, _kIPhoneSE);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(
        tester,
        _buildLocalizedWidget(const IntentScreen()),
      );

      await expectLater(
        find.byType(IntentScreen),
        matchesGoldenFile('goldens/intent_se_fr.png'),
      );
    });

    testWidgets('intent — iPhone 15 DE', (tester) async {
      _setViewport(tester, _kIPhone15);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(
        tester,
        _buildDeWidget(const IntentScreen()),
      );

      await expectLater(
        find.byType(IntentScreen),
        matchesGoldenFile('goldens/intent_15_de.png'),
      );
    });
  });

  // =========================================================================
  // 3. PremierEclairageCard
  // =========================================================================

  group('Golden Screenshots — PremierEclairageCard', () {
    // PremierEclairageCard has an AnimationController that starts after
    // async snapshot load. The first test in this group also triggers a
    // Google Fonts HTTP fetch which leaves a pending socket timer.
    // We add a dedicated warmup test (same pattern as other golden groups)
    // to absorb the timer, then capture goldens in subsequent tests.

    testWidgets('warmup — premier eclairage font cache (no assertions)',
        (tester) async {
      setGoldenViewport(tester);
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'premier_eclairage_snapshot':
            '{"value":"1\u00a0089","title":"Rente mensuelle","subtitle":"Test","colorKey":"warning","suggestedRoute":"/test","confidenceMode":"pedagogical"}',
        'has_seen_premier_eclairage': false,
      });

      await pumpGoldenWidget(
        tester,
        _buildLocalizedWidget(
          Scaffold(
            body: PremierEclairageCard(
              onDismiss: () {},
              onNavigate: (_) {},
            ),
          ),
        ),
        warmup: kFontWarmupDuration,
      );
    });

    testWidgets('premier eclairage — iPhone 15 FR', (tester) async {
      _setViewport(tester, _kIPhone15);
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'premier_eclairage_snapshot':
            '{"value":"1\u00a0089","title":"Rente mensuelle","subtitle":"Estimation basée sur votre profil","colorKey":"warning","suggestedRoute":"/retirement/projection","confidenceMode":"pedagogical"}',
        'has_seen_premier_eclairage': false,
      });

      await pumpGoldenWidget(
        tester,
        _buildLocalizedWidget(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PremierEclairageCard(
                onDismiss: () {},
                onNavigate: (_) {},
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(PremierEclairageCard),
        matchesGoldenFile('goldens/premier_eclairage_15_fr.png'),
      );
    });

    testWidgets('premier eclairage — iPhone SE FR', (tester) async {
      _setViewport(tester, _kIPhoneSE);
      addTearDown(() => tester.view.resetPhysicalSize());

      SharedPreferences.setMockInitialValues({
        'premier_eclairage_snapshot':
            '{"value":"1\u00a0089","title":"Rente mensuelle","subtitle":"Estimation basée sur votre profil","colorKey":"warning","suggestedRoute":"/retirement/projection","confidenceMode":"pedagogical"}',
        'has_seen_premier_eclairage': false,
      });

      await pumpGoldenWidget(
        tester,
        _buildLocalizedWidget(
          Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: PremierEclairageCard(
                onDismiss: () {},
                onNavigate: (_) {},
              ),
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(PremierEclairageCard),
        matchesGoldenFile('goldens/premier_eclairage_se_fr.png'),
      );
    });
  });

  // =========================================================================
  // 4. PrivacyControlScreen
  // =========================================================================

  group('Golden Screenshots — PrivacyControlScreen', () {
    List<SingleChildWidget> privacyProviders() {
      final bioProvider = BiographyProvider();
      // Pre-load mock facts so the screen has data to render.
      // BiographyProvider.facts is the public getter; we add facts
      // via the provider's test-accessible method or override.
      return [
        ChangeNotifierProvider<BiographyProvider>.value(value: bioProvider),
      ];
    }

    testWidgets('privacy — iPhone 15 FR', (tester) async {
      _setViewport(tester, _kIPhone15);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(
        tester,
        _buildLocalizedWidget(
          const PrivacyControlScreen(),
          extraProviders: privacyProviders(),
        ),
      );

      await expectLater(
        find.byType(PrivacyControlScreen),
        matchesGoldenFile('goldens/privacy_15_fr.png'),
      );
    });

    testWidgets('privacy — iPhone SE FR', (tester) async {
      _setViewport(tester, _kIPhoneSE);
      addTearDown(() => tester.view.resetPhysicalSize());

      await pumpGoldenWidget(
        tester,
        _buildLocalizedWidget(
          const PrivacyControlScreen(),
          extraProviders: privacyProviders(),
        ),
      );

      await expectLater(
        find.byType(PrivacyControlScreen),
        matchesGoldenFile('goldens/privacy_se_fr.png'),
      );
    });
  });
}
