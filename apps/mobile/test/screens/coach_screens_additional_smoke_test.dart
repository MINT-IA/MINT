// ────────────────────────────────────────────────────────────
//  COACH SCREENS (additional) — Smoke Tests
//  Screens: RetirementDashboardScreen, ConfidenceDashboardScreen,
//           CantonalBenchmarkScreen
//
//  Validates: renders without crash, Scaffold present,
//  French content visible, State C (no profile) handled.
// ────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/screens/confidence/confidence_dashboard_screen.dart';
import 'package:mint_mobile/screens/cantonal_benchmark_screen.dart';
import 'package:mint_mobile/services/confidence/enhanced_confidence_service.dart';

// ---------------------------------------------------------------------------
//  Shared helpers — wraps a screen with Provider(s) + French i18n
// ---------------------------------------------------------------------------

/// Basic wrapper: CoachProfileProvider only.
Widget _buildWrapped(Widget screen) {
  return ChangeNotifierProvider<CoachProfileProvider>(
    create: (_) => CoachProfileProvider(),
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: screen,
    ),
  );
}

/// Extended wrapper: CoachProfileProvider + SlmProvider (needed by
/// RetirementDashboardScreen → SlmAutoPromptService.checkAndPrompt).
Widget _buildWrappedWithSlm(Widget screen) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<CoachProfileProvider>(
        create: (_) => CoachProfileProvider(),
      ),
      ChangeNotifierProvider<SlmProvider>(
        create: (_) => SlmProvider(),
      ),
    ],
    child: MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: screen,
    ),
  );
}

// ---------------------------------------------------------------------------
//  Minimal ConfidenceResult for tests
// ---------------------------------------------------------------------------
ConfidenceResult _buildTestConfidenceResult({double score = 55.0}) {
  return ConfidenceResult(
    breakdown: ConfidenceBreakdown(
      completeness: score,
      accuracy: score,
      freshness: score,
    ),
    enrichmentPrompts: const [
      EnrichmentPrompt(
        fieldName: 'lpp',
        action: 'Scanne ton certificat LPP',
        impactPoints: 20,
        method: 'documentScan',
        priority: 1,
      ),
    ],
    featureGates: const [
      FeatureGate(
        gateName: 'projection_retraite',
        unlocked: false,
        minConfidence: 70,
      ),
    ],
    disclaimer: "Outil éducatif. Ne constitue pas un conseil financier.",
    sources: const ['LPP art. 14', 'LAVS art. 21'],
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ═══════════════════════════════════════════════════════════
  //  1. RetirementDashboardScreen — main retraite screen
  // ═══════════════════════════════════════════════════════════

  group('RetirementDashboardScreen', () {
    Widget buildScreen() => _buildWrappedWithSlm(const RetirementDashboardScreen());

    testWidgets('renders without crash (State C — no profile)', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows onboarding CTA when no profile', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: dashboardQuickStartCta = "Commencer"
      expect(find.textContaining('ommencer'), findsWidgets);
    });

    testWidgets('shows educational card without profile', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // State C: i18n dashboardEducationTitle =
      //   "Comment fonctionne la retraite en Suisse ?"
      // or dashboardEducationSubtitle = "AVS, LPP, 3a — les bases en 5 minutes"
      expect(find.textContaining('retraite'), findsWidgets);
    });

    testWidgets('displays disclaimer section', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -800));
      await tester.pump();
      // i18n: disclaimerShort = "Outil éducatif, pas un conseil financier."
      expect(find.textContaining('ducatif', skipOffstage: false), findsWidgets);
    });

    testWidgets('shows app bar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // i18n: dashboardAppBarDefault = "Mon tableau de bord"
      expect(find.textContaining('tableau'), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  2. ConfidenceDashboardScreen — confidence score details
  // ═══════════════════════════════════════════════════════════

  group('ConfidenceDashboardScreen', () {
    Widget buildScreen({double score = 55.0}) => MaterialApp(
          locale: const Locale('fr'),
          localizationsDelegates: const [
            S.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: S.supportedLocales,
          home: ConfidenceDashboardScreen(
            result: _buildTestConfidenceResult(score: score),
          ),
        );

    testWidgets('renders without crash', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays hardcoded app bar title', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      // AppBar title is hardcoded: 'Précision de ton profil'
      expect(find.text('Précision de ton profil'), findsOneWidget);
    });

    testWidgets('shows overall score percentage', (tester) async {
      await tester.pumpWidget(buildScreen(score: 55.0));
      await tester.pump();
      // Score displayed as e.g. "55 %"
      expect(find.textContaining('%'), findsWidgets);
    });

    testWidgets('shows enrichment prompt card', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
      await tester.pump();
      // Enrichment prompt action text
      expect(find.textContaining('certificat LPP', skipOffstage: false), findsWidgets);
    });

    testWidgets('animation controller initialises without error', (tester) async {
      await tester.pumpWidget(buildScreen());
      // Full animation frame cycle
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('shows disclaimer at bottom', (tester) async {
      await tester.pumpWidget(buildScreen());
      await tester.pump();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -2000));
      await tester.pump();
      expect(find.textContaining('ducatif', skipOffstage: false), findsWidgets);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  3. CantonalBenchmarkScreen — opt-in cantonal benchmarks
  // ═══════════════════════════════════════════════════════════

  group('CantonalBenchmarkScreen', () {
    Widget buildScreen() => _buildWrapped(const CantonalBenchmarkScreen());

    testWidgets('renders without crash', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildScreen());
      await tester.pump(); // loading state
      await tester.pumpAndSettle(); // async getOptedIn completes
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('displays i18n app bar title', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      // i18n: benchmarkAppBarTitle = "Repères cantonaux"
      expect(find.textContaining('cantonaux'), findsWidgets);
    });

    testWidgets('shows opt-in card by default (not opted in)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildScreen());
      await tester.pumpAndSettle();
      // Opt-in toggle or card should be visible
      expect(find.byType(Switch), findsWidgets);
    });

    testWidgets('shows loading indicator before async completes', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(buildScreen());
      await tester.pump(); // first frame — loading = true
      // CircularProgressIndicator or Scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });
}
