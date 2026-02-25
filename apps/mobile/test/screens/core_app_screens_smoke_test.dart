import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

// Screens under test
import 'package:mint_mobile/screens/profile_screen.dart';
import 'package:mint_mobile/screens/documents_screen.dart';
import 'package:mint_mobile/screens/document_detail_screen.dart';
import 'package:mint_mobile/screens/bank_import_screen.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:mint_mobile/screens/ask_mint_screen.dart';
import 'package:mint_mobile/screens/main_navigation_shell.dart';
import 'package:mint_mobile/screens/advisor/onboarding_30_day_plan_screen.dart';
import 'package:mint_mobile/screens/advisor/advisor_wizard_screen_v2.dart';

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

// Models
import 'package:mint_mobile/models/profile.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
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
        ChangeNotifierProvider<UserActivityProvider>(create: (_) => UserActivityProvider()),
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

      expect(find.textContaining('MON PROFIL'), findsWidgets);
    });

    testWidgets('shows Precision Index card', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Precision Index'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsWidgets);
    });

    testWidgets('shows FactFind sections', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Foyer'), findsWidgets);
      expect(find.textContaining('Revenus'), findsWidgets);
      expect(find.textContaining('LPP'), findsWidgets);
    });

    testWidgets('shows security and data section', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Data'), findsOneWidget);
    });

    testWidgets('shows delete data button', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const ProfileScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Supprimer'), findsOneWidget);
    });

    testWidgets('navigates to wizard from FactFind CTAs (no grey error screen)',
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
            builder: (context, state) => const AdvisorWizardScreenV2(),
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

      final identityLabel = find.textContaining('Identité & Foyer').last;
      await tester.ensureVisible(identityLabel);
      final identitySection = find.ancestor(
        of: identityLabel,
        matching: find.byType(InkWell),
      );
      await tester.tap(identitySection.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byType(AdvisorWizardScreenV2), findsOneWidget);
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
      expect(find.byconst Icon(Icons.account_balance_outlined), findsOneWidget);
      expect(find.textContaining('transactions'), findsWidgets);
    });

    testWidgets('shows privacy footer', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const DocumentsScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byconst Icon(Icons.lock_outline), findsWidgets);
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
      expect(find.byconst Icon(Icons.description_outlined), findsOneWidget);
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
      expect(find.byconst Icon(Icons.attach_file_rounded), findsOneWidget);
    });

    testWidgets('shows bank format info (CSV/PDF)', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const BankImportScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('CSV'), findsOneWidget);
    });

    testWidgets('shows privacy footer', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const BankImportScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byconst Icon(Icons.lock_outline), findsOneWidget);
      expect(find.textContaining('localement'), findsOneWidget);
    });
  });

  // ===========================================================================
  // 6. LANDING SCREEN
  // ===========================================================================

  group('LandingScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byType(LandingScreen), findsOneWidget);
    });

    testWidgets('displays hero text', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('Tes finances'), findsOneWidget);
    });

    testWidgets('shows beta badge', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('ta'), findsWidgets);
    });

    testWidgets('shows feature rows with icons', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.byconst Icon(Icons.speed_rounded), findsOneWidget);
      expect(find.byconst Icon(Icons.show_chart_rounded), findsOneWidget);
      expect(find.byconst Icon(Icons.lock_rounded), findsOneWidget);
    });

    testWidgets('shows diagnostic CTA button', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const LandingScreen()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      expect(find.textContaining('score'), findsWidgets);
    });

    testWidgets('shows login button', (tester) async {
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
      expect(find.byconst Icon(Icons.lock_outline), findsWidgets);
    });
  });

  // ===========================================================================
  // 8. ONBOARDING 30 DAYS PLAN SCREEN
  // ===========================================================================

  group('Onboarding30DayPlanScreen', () {
    testWidgets('renders without crashing', (tester) async {
      await tester.pumpWidget(buildTestableScreen(
        const Onboarding30DayPlanScreen(),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.byType(Onboarding30DayPlanScreen), findsOneWidget);
      expect(find.textContaining('PLAN 30 JOURS'), findsOneWidget);
    });

    testWidgets('shows timeline action cards', (tester) async {
      await tester.pumpWidget(buildTestableScreen(
        const Onboarding30DayPlanScreen(stressChoice: 'budget'),
      ));
      await tester.pumpAndSettle(const Duration(seconds: 2));

      expect(find.textContaining('Jour 1-7'), findsWidgets);
      expect(find.textContaining('Jour 8-15'), findsOneWidget);
      expect(find.textContaining('Jour 16-30'), findsOneWidget);
    });

    testWidgets('tap "Completer mon diagnostic" navigates to wizard',
        (tester) async {
      final router = GoRouter(
        initialLocation: '/advisor/plan-30-days',
        routes: [
          GoRoute(
            path: '/advisor/plan-30-days',
            builder: (context, state) => const Onboarding30DayPlanScreen(),
          ),
          GoRoute(
            path: '/advisor/wizard',
            builder: (context, state) => const AdvisorWizardScreenV2(),
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
            ChangeNotifierProvider<CoachProfileProvider>(
                create: (_) => CoachProfileProvider()),
            ChangeNotifierProvider<UserActivityProvider>(
                create: (_) => UserActivityProvider()),
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

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -400));
      await tester.pumpAndSettle(const Duration(milliseconds: 400));

      final completeDiagnosticButton = find.byType(OutlinedButton).first;
      expect(completeDiagnosticButton, findsOneWidget);
      await tester.tap(completeDiagnosticButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AdvisorWizardScreenV2), findsOneWidget);
      expect(find.textContaining('Question'), findsWidgets);
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

      // Tab labels appear in the bottom nav (Sprint C10: 4-tab coach layout)
      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Agir'), findsOneWidget);
      expect(find.text('Apprendre'), findsOneWidget);
      expect(find.text('Profil'), findsOneWidget);
    });

    testWidgets('shows tab icons', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const MainNavigationShell()));
      await tester.pump(const Duration(seconds: 1));

      // Active tab shows filled icon (Dashboard = home), others show outlined
      expect(find.byconst Icon(Icons.home), findsOneWidget); // Active (Dashboard)
      expect(find.byconst Icon(Icons.flash_on_outlined), findsOneWidget);
      expect(find.byconst Icon(Icons.explore_outlined), findsOneWidget);
      expect(find.byconst Icon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('shows floating mentor FAB', (tester) async {
      await tester.pumpWidget(buildTestableScreen(const MainNavigationShell()));
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.byconst Icon(Icons.auto_awesome), findsWidgets);
    });
  });
}
