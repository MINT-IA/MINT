import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// Screens under test
// KILL-04: profile_screen.dart deleted (Phase 2)
import 'package:mint_mobile/screens/documents_screen.dart';
import 'package:mint_mobile/screens/document_detail_screen.dart';
import 'package:mint_mobile/screens/bank_import_screen.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
// KILL-07: main_navigation_shell.dart deleted (Phase 2)

// Providers
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
// Wave E-PRIME (2026-04-18): UserActivityProvider / AnticipationProvider /
// ContextualCardProvider / CoachEntryPayloadProvider deleted — Panel A façade
// audit (0 consumer prod).
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';

// Models
import 'package:mint_mobile/models/profile.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      // Prevent SLM onboarding modal from interfering with shell tests.
      'slm_auto_prompt_shown': true,
    });
  });

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Wraps a screen widget with MaterialApp + localization + common providers
  Widget buildTestableScreen(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ProfileProvider>(create: (_) {
          final p = ProfileProvider();
          p.setProfile(Profile(
            id: 'test-user',
            householdType: HouseholdType.single,
            goal: Goal.emergency,
            createdAt: DateTime(2025, 1, 1),
            birthYear: 1990,
            canton: 'VD',
            incomeNetMonthly: 6000,
          ));
          return p;
        }),
        ChangeNotifierProvider<AuthProvider>(create: (_) => AuthProvider()),
        ChangeNotifierProvider<ByokProvider>(create: (_) => ByokProvider()),
        ChangeNotifierProvider<DocumentProvider>(
            create: (_) => DocumentProvider()),
        ChangeNotifierProvider<BudgetProvider>(create: (_) => BudgetProvider()),
        ChangeNotifierProvider<SubscriptionProvider>(
            create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider<CoachProfileProvider>(
            create: (_) => CoachProfileProvider()),
        ChangeNotifierProvider<LocaleProvider>(create: (_) => LocaleProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
        ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider()),
        ChangeNotifierProvider<FinancialPlanProvider>(
            create: (_) => FinancialPlanProvider()),
        ChangeNotifierProvider<BiographyProvider>(
            create: (_) => BiographyProvider()),
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
        home: child,
      ),
    );
  }

  // ===========================================================================
  // 2. PROFILE SCREEN — DELETED (KILL-04, Phase 2)
  // ===========================================================================

  // ===========================================================================
  // 3. DOCUMENTS SCREEN
  // ===========================================================================

  group('DocumentsScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const DocumentsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(DocumentsScreen), findsOneWidget);
    });

    testWidgets('displays documents title', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const DocumentsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('documents'), findsWidgets);
    });

    testWidgets('shows upload LPP certificate card', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const DocumentsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('LPP'), findsWidgets);
      expect(find.textContaining('PDF'), findsOneWidget);
    });

    testWidgets('shows bank import card', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const DocumentsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Bank import card with bank icon
      expect(find.byIcon(Icons.account_balance_outlined), findsOneWidget);
      expect(find.textContaining('transactions'), findsWidgets);
    });

    testWidgets('the privacy footer says where the documents actually go',
        (tester) async {
      // Cet oracle affirmait « localement » — il GARDAIT donc une phrase
      // fausse : l'OCR local a ete supprime le 2026-04-17 et les documents
      // partent chez Claude Vision (Anthropic, Etats-Unis). Un test qui
      // protege un mensonge le rend plus dur a corriger que s'il n'existait
      // pas. Il garde desormais la phrase vraie.
      await tester.pumpWidget(buildTestableScreen(const DocumentsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      expect(find.textContaining('Claude Vision'), findsOneWidget);
      expect(find.textContaining('localement'), findsNothing,
          reason: 'aucun document n\'est analyse localement depuis avril 2026');
    });
  });

  // ===========================================================================
  // 4. DOCUMENT DETAIL SCREEN
  // ===========================================================================

  group('DocumentDetailScreen', () {
    testWidgets('renders without crashing with placeholder', (tester) async {
      await tester.pumpWidget(buildTestableScreen(
        const DocumentDetailScreen(documentId: 'test-doc-123'),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(DocumentDetailScreen), findsOneWidget);
    });

    testWidgets('displays Certificat LPP in app bar', (tester) async {
      await tester.pumpWidget(buildTestableScreen(
        const DocumentDetailScreen(documentId: 'test-doc-123'),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Certificat LPP'), findsWidgets);
    });

    testWidgets('shows placeholder when document not found', (tester) async {
      await tester.pumpWidget(buildTestableScreen(
        const DocumentDetailScreen(documentId: 'nonexistent'),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // When no document found, shows placeholder text
      expect(find.textContaining('Aucun document'), findsOneWidget);
      expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    });
  });

  // ===========================================================================
  // 5. BANK IMPORT SCREEN
  // ===========================================================================

  group('BankImportScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const BankImportScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(BankImportScreen), findsOneWidget);
    });

    testWidgets('displays import title', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const BankImportScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Importer'), findsWidgets);
    });

    testWidgets('shows file upload button', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const BankImportScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Choisir un fichier'), findsOneWidget);
      expect(find.byIcon(Icons.attach_file_rounded), findsOneWidget);
    });

    testWidgets('shows bank format info (CSV/PDF)', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const BankImportScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('CSV'), findsOneWidget);
    });

    testWidgets('shows privacy footer', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const BankImportScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byIcon(Icons.lock_outline), findsOneWidget);
      expect(find.textContaining('sécurisée'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 6. LANDING SCREEN
  // ===========================================================================

  group('LandingScreen', () {
    // The trust bar Row needs a wider viewport to avoid overflow.
    void setLandingViewport(WidgetTester tester) {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
    }

    void resetLandingViewport(WidgetTester tester) {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    }

    testWidgets('renders without crashing', (tester) async {
      setLandingViewport(tester);
      addTearDown(() => resetLandingViewport(tester));

      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(LandingScreen), findsOneWidget);
    });

    testWidgets('displays hero punchline text', (tester) async {
      setLandingViewport(tester);
      addTearDown(() => resetLandingViewport(tester));

      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Phase 73 (v2.11) landing-v3-editorial — hero line is now
      // landingV3Hero = "Voir clair, décider seul." (Cleo brand line,
      // panel-locked). The previous landingV2PromiseSober is retired from
      // the LandingScreen surface ; the ARB key remains for back-compat.
      expect(find.textContaining("Voir clair"), findsOneWidget);
    });

    testWidgets('shows MINT logo text', (tester) async {
      setLandingViewport(tester);
      addTearDown(() => resetLandingViewport(tester));

      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('MINT'), findsOneWidget);
    });

    testWidgets('no privacy subtitle (POLISH-01 removed it)', (tester) async {
      setLandingViewport(tester);
      addTearDown(() => resetLandingViewport(tester));

      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Phase 5 POLISH-01: privacy subtitle removed — coach explains when relevant.
      expect(find.textContaining('Rien ne sort de ton t\u00e9l\u00e9phone'), findsNothing);
    });

    testWidgets('shows CTA button Eclaire ma situation', (tester) async {
      setLandingViewport(tester);
      addTearDown(() => resetLandingViewport(tester));

      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // landingV2CtaSober = "Éclaire ma situation"
      expect(find.text('\u00c9claire ma situation'), findsOneWidget);
    });

    testWidgets('hides login behind wordmark long-press (D-12 hidden affordance)', (tester) async {
      setLandingViewport(tester);
      addTearDown(() => resetLandingViewport(tester));

      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Phase 7 Landing v2: no visible login button. The login affordance
      // is a long-press on the MINT wordmark (routes to /auth/login).
      expect(find.textContaining('connecter'), findsNothing);
      // The MINT wordmark still renders as the hidden entry point.
      expect(find.text('MINT'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 7. MAIN NAVIGATION SHELL — DELETED (KILL-07, Phase 2)
  // ===========================================================================
}
