import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/providers/anticipation_provider.dart';
import 'package:mint_mobile/providers/contextual_card_provider.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/coach_entry_payload_provider.dart';

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
        ChangeNotifierProvider<UserActivityProvider>(
            create: (_) => UserActivityProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
        ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider()),
        ChangeNotifierProvider<CoachEntryPayloadProvider>(
            create: (_) => CoachEntryPayloadProvider()),
        ChangeNotifierProvider<FinancialPlanProvider>(
            create: (_) => FinancialPlanProvider()),
        ChangeNotifierProvider<BiographyProvider>(
            create: (_) => BiographyProvider()),
        ChangeNotifierProvider<AnticipationProvider>(
            create: (_) => AnticipationProvider()),
        ChangeNotifierProvider<ContextualCardProvider>(
            create: (_) => ContextualCardProvider()),
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

    testWidgets('shows privacy footer', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const DocumentsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byIcon(Icons.lock_outline), findsWidgets);
      expect(find.textContaining('localement'), findsOneWidget);
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

      // Phase 7 Landing v2: paragraphe-mère (landingV2Paragraph) replaces
      // legacy "Le système financier suisse est puissant." punchline.
      expect(find.textContaining('personne n\'a intérêt'), findsOneWidget);
    });

    testWidgets('shows MINT logo text', (tester) async {
      setLandingViewport(tester);
      addTearDown(() => resetLandingViewport(tester));

      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('MINT'), findsOneWidget);
    });

    testWidgets('shows trust bar with icons', (tester) async {
      setLandingViewport(tester);
      addTearDown(() => resetLandingViewport(tester));

      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Phase 7 Landing v2 removed the trust bar (shield/lock/check icons).
      // The privacy reassurance is now a single micro-phrase (landingV2Privacy).
      expect(find.textContaining('Rien ne sort de ton téléphone'), findsOneWidget);
    });

    testWidgets('shows CTA button with Commencer', (tester) async {
      setLandingViewport(tester);
      addTearDown(() => resetLandingViewport(tester));

      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Phase 7 Landing v2: landingV2Cta = "Continuer (sans compte)".
      expect(find.textContaining('Continuer'), findsOneWidget);
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
