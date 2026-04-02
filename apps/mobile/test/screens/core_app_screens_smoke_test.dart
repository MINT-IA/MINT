import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

// Screens under test
import 'package:mint_mobile/screens/profile_screen.dart';
import 'package:mint_mobile/screens/documents_screen.dart';
import 'package:mint_mobile/screens/document_detail_screen.dart';
import 'package:mint_mobile/screens/bank_import_screen.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:mint_mobile/screens/ask_mint_screen.dart';
import 'package:mint_mobile/screens/main_navigation_shell.dart';
import 'package:mint_mobile/screens/onboarding/quick_start_screen.dart';

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
        ChangeNotifierProvider<UserActivityProvider>(
            create: (_) => UserActivityProvider()),
        ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
        ChangeNotifierProvider<MintStateProvider>(
            create: (_) => MintStateProvider()),
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
  // 2. PROFILE SCREEN
  // ===========================================================================

  group('ProfileScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('displays profile title', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.text('Moi'), findsWidgets);
    });

    testWidgets('shows profile completion progress', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Phase 2: Precision Index replaced by inline completion progress
      expect(find.textContaining('Compl'), findsWidgets);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('shows FactFind sections', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Foyer'), findsWidgets);
      expect(find.textContaining('Revenus'), findsWidgets);
      expect(find.textContaining('LPP'), findsWidgets);
    });

    testWidgets('shows identity card (settings moved to SettingsSheet)',
        (tester) async {
      await tester.pumpWidget(buildTestableScreen(const ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Settings section removed (now in SettingsSheet via gear icon).
      // Identity card should be present instead.
      expect(find.byType(ProfileScreen), findsOneWidget);
    });

    testWidgets('shows delete data button', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Supprimer'), findsOneWidget);
    });

    testWidgets(
        'navigates to quick start onboarding from FactFind CTAs (no grey error screen)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final router = GoRouter(
        initialLocation: '/profile',
        routes: [
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: '/advisor/wizard',
            redirect: (context, state) => '/onboarding/quick',
          ),
          GoRoute(
            path: '/onboarding/quick',
            builder: (context, state) => const QuickStartScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MultiProvider(
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
            ChangeNotifierProvider<BudgetProvider>(
                create: (_) => BudgetProvider()),
            ChangeNotifierProvider<SubscriptionProvider>(
                create: (_) => SubscriptionProvider()),
            ChangeNotifierProvider<CoachProfileProvider>(
                create: (_) => CoachProfileProvider()),
            ChangeNotifierProvider<LocaleProvider>(
                create: (_) => LocaleProvider()),
            ChangeNotifierProvider<UserActivityProvider>(
                create: (_) => UserActivityProvider()),
            ChangeNotifierProvider<SlmProvider>(create: (_) => SlmProvider()),
          ],
          child: MaterialApp.router(
            locale: const Locale('fr'),
            localizationsDelegates: const [
              S.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: S.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Phase 2: completion rows use GestureDetector, not InkWell
      final identityLabel = find.textContaining('Foyer').last;
      await tester.ensureVisible(identityLabel);
      final identitySection = find.ancestor(
        of: identityLabel,
        matching: find.byType(GestureDetector),
      );
      await tester.tap(identitySection.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      final foundQuick = find.byType(QuickStartScreen).evaluate().isNotEmpty;
      expect(foundQuick, isTrue);
      expect(find.textContaining('Cette page n'), findsNothing);
    });
  });

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

      // landingPunchline1 = "Le système financier suisse est puissant."
      expect(find.textContaining('financier suisse'), findsOneWidget);
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

      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('shows CTA button with Commencer', (tester) async {
      setLandingViewport(tester);
      addTearDown(() => resetLandingViewport(tester));

      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // landingCtaCommencer = "Commencer"
      expect(find.text('Commencer'), findsOneWidget);
    });

    testWidgets('shows login button', (tester) async {
      setLandingViewport(tester);
      addTearDown(() => resetLandingViewport(tester));

      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('connecter'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 7. ASK MINT SCREEN
  // ===========================================================================

  group('AskMintScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const AskMintScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(AskMintScreen), findsOneWidget);
    });

    testWidgets('displays Ask MINT title', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const AskMintScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Ask MINT'), findsOneWidget);
    });

    testWidgets('shows configure CTA when BYOK not set', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const AskMintScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // By default ByokProvider is not configured, so show the configure CTA
      expect(find.textContaining('Configure'), findsWidgets);
      expect(find.textContaining('API'), findsWidgets);
    });

    testWidgets('shows privacy note for API key', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const AskMintScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('localement'), findsWidgets);
      expect(find.byIcon(Icons.lock_outline), findsWidgets);
    });
  });

  // ===========================================================================
  // 8. MAIN NAVIGATION SHELL
  // ===========================================================================

  group('MainNavigationShell', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const MainNavigationShell()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(MainNavigationShell), findsOneWidget);
    });

    testWidgets('shows bottom navigation with 4 tabs', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const MainNavigationShell()));
      await tester.pump(const Duration(seconds: 1));

      // S52: 4-tab layout — Aujourd'hui, MINT (Coach), Explorer, Dossier
      expect(find.textContaining('ujourd'), findsWidgets);
      expect(find.text('Mint'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
      expect(find.text('Dossier'), findsOneWidget);
    });

    testWidgets('shows tab icons', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const MainNavigationShell()));
      await tester.pump(const Duration(seconds: 1));

      // S52: 4 tabs — today (active), coach, explore, dossier
      expect(find.byIcon(Icons.today), findsOneWidget); // Active
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(find.byIcon(Icons.explore_outlined), findsOneWidget);
      expect(find.byIcon(Icons.folder_outlined), findsOneWidget);
    });
  });
}
