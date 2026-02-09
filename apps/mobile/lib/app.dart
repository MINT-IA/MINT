import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:mint_mobile/screens/auth/login_screen.dart';
import 'package:mint_mobile/screens/auth/register_screen.dart';
import 'package:mint_mobile/screens/simulator_compound_screen.dart';
import 'package:mint_mobile/screens/simulator_leasing_screen.dart';
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
import 'package:mint_mobile/screens/consumer_credit_screen.dart';
import 'package:mint_mobile/screens/debt_risk_check_screen.dart';
import 'package:mint_mobile/screens/consent_dashboard_screen.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/screens/portfolio_screen.dart';
import 'package:mint_mobile/screens/advisor/advisor_wizard_screen_v2.dart';
import 'package:mint_mobile/screens/advisor/advisor_onboarding_screen.dart';
import 'package:mint_mobile/screens/advisor/advisor_report_screen.dart';
import 'package:mint_mobile/screens/profile_screen.dart';
import 'package:mint_mobile/screens/main_navigation_shell.dart';
import 'package:mint_mobile/screens/budget/budget_container_screen.dart';
import 'package:mint_mobile/screens/tools_library_screen.dart';
import 'package:mint_mobile/screens/education/comprendre_hub_screen.dart';
import 'package:mint_mobile/screens/education/theme_detail_screen.dart';
import 'package:mint_mobile/screens/simulator_rente_capital_screen.dart';
import 'package:mint_mobile/screens/simulator_disability_gap_screen.dart';
import 'package:mint_mobile/screens/job_comparison_screen.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/screens/succession_simulator_screen.dart';
import 'package:mint_mobile/screens/byok_settings_screen.dart';
import 'package:mint_mobile/screens/ask_mint_screen.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/screens/documents_screen.dart';
import 'package:mint_mobile/screens/document_detail_screen.dart';
import 'package:mint_mobile/screens/bank_import_screen.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/analytics_observer.dart';
import 'package:mint_mobile/screens/coaching_screen.dart';
import 'package:mint_mobile/screens/gender_gap_screen.dart';
import 'package:mint_mobile/screens/frontalier_screen.dart';
import 'package:mint_mobile/screens/independant_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: [AnalyticsRouteObserver()],
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingScreen(),
    ),
    // Auth Routes
    GoRoute(
      path: '/auth/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/auth/register',
      builder: (context, state) => const RegisterScreen(),
    ),
    // Main Dashboard (Shell with internal tabs)
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigationShell(),
    ),
    // Feature Routes (Full Screen)
    GoRoute(
      path: '/advisor',
      builder: (context, state) => const AdvisorOnboardingScreen(),
      routes: [
        GoRoute(
          path: 'wizard',
          builder: (context, state) => const AdvisorWizardScreenV2(),
        ),
      ],
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
      routes: [
        GoRoute(
          path: 'consent',
          builder: (context, state) => const ConsentDashboardScreen(),
        ),
        GoRoute(
          path: 'byok',
          builder: (context, state) => const ByokSettingsScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/ask-mint',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AskMintScreen(),
    ),
    // Documents
    GoRoute(
      path: '/documents',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DocumentsScreen(),
    ),
    GoRoute(
      path: '/documents/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DocumentDetailScreen(documentId: id);
      },
    ),
    // Bank Import
    GoRoute(
      path: '/bank-import',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BankImportScreen(),
    ),
    GoRoute(
      path: '/budget',
      builder: (context, state) => const BudgetContainerScreen(),
    ),
    // Simulateurs...
    GoRoute(
      path: '/simulator/compound',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SimulatorCompoundScreen(),
    ),
    GoRoute(
      path: '/simulator/leasing',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SimulatorLeasingScreen(),
    ),
    GoRoute(
      path: '/simulator/3a',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const Simulator3aScreen(),
    ),
    GoRoute(
      path: '/simulator/credit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConsumerCreditSimulatorScreen(),
    ),
    GoRoute(
      path: '/simulator/rente-capital',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SimulatorRenteCapitalScreen(),
    ),
    GoRoute(
      path: '/simulator/disability-gap',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SimulatorDisabilityGapScreen(),
    ),
    GoRoute(
      path: '/simulator/job-comparison',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const JobComparisonScreen(),
    ),
    // Life Events
    GoRoute(
      path: '/life-event/divorce',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DivorceSimulatorScreen(),
    ),
    GoRoute(
      path: '/life-event/succession',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SuccessionSimulatorScreen(),
    ),
    GoRoute(
      path: '/check/debt',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DebtRiskCheckScreen(),
    ),
    GoRoute(
      path: '/portfolio',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PortfolioScreen(),
    ),
    GoRoute(
      path: '/report',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return AdvisorReportScreen(answers: extra);
      },
    ),
    GoRoute(
      path: '/tools',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ToolsLibraryScreen(),
    ),
    // Coaching Proactif
    GoRoute(
      path: '/coaching',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CoachingScreen(),
    ),
    // Segments sociologiques
    GoRoute(
      path: '/segments/gender-gap',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const GenderGapScreen(),
    ),
    GoRoute(
      path: '/segments/frontalier',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FrontalierScreen(),
    ),
    GoRoute(
      path: '/segments/independant',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const IndependantScreen(),
    ),
    // Education Hub
    GoRoute(
      path: '/education/hub',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ComprendreHubScreen(),
    ),
    GoRoute(
      path: '/education/theme/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ThemeDetailScreen(themeId: id);
      },
    ),
  ],
);

class MintApp extends StatefulWidget {
  const MintApp({super.key});

  @override
  State<MintApp> createState() => _MintAppState();
}

class _MintAppState extends State<MintApp> {
  @override
  void initState() {
    super.initState();
    // Initialize analytics service
    AnalyticsService().init();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => BudgetProvider()),
        ChangeNotifierProvider(create: (_) {
          final provider = ByokProvider();
          provider.loadSavedKey();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => DocumentProvider()),
      ],
      child: MaterialApp.router(
        title: 'Mint',
        debugShowCheckedModeBanner: false,
        theme: _buildPremiumTheme(),
        themeMode: ThemeMode.light,
        routerConfig: _router,
        localizationsDelegates: S.localizationsDelegates,
        supportedLocales: S.supportedLocales,
        locale: const Locale('fr'),
      ),
    );
  }
}

ThemeData _buildPremiumTheme() {
  // Inter for UI, Outfit for Headlines (Premium Modern combination)
  final textTheme =
      GoogleFonts.interTextTheme(ThemeData.light().textTheme);

  return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: MintColors.background,
      colorScheme: const ColorScheme.light(
        primary: MintColors.primary,
        onPrimary: Colors.white,
        secondary: MintColors.accent,
        onSecondary: Colors.white,
        surface: MintColors.appleSurface,
        onSurface: MintColors.textPrimary,
        error: MintColors.error,
        outline: MintColors.border,
      ),
      textTheme: textTheme.copyWith(
        displayLarge: GoogleFonts.outfit(
          textStyle: textTheme.displayLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.5,
            color: MintColors.textPrimary,
          ),
        ),
        headlineLarge: GoogleFonts.outfit(
          textStyle: textTheme.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -1.0,
            color: MintColors.textPrimary,
          ),
        ),
        headlineMedium: GoogleFonts.outfit(
          textStyle: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: MintColors.textPrimary,
          ),
        ),
        titleLarge: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: MintColors.textPrimary,
        ),
        bodyLarge: textTheme.bodyLarge?.copyWith(
          color: MintColors.textPrimary,
          height: 1.5,
          fontSize: 16,
        ),
        bodyMedium: textTheme.bodyMedium?.copyWith(
          color: MintColors.textSecondary,
          height: 1.4,
          fontSize: 14,
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false, // Apple style left-aligned
        titleTextStyle: TextStyle(
          fontWeight: FontWeight.w700,
          fontFamily: 'Outfit',
          color: MintColors.textPrimary,
          fontSize: 20,
          letterSpacing: -0.5,
        ),
        iconTheme: IconThemeData(color: MintColors.textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: MintColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: MintColors.lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MintColors.textPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
          side: const BorderSide(color: MintColors.border, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MintColors.appleSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: MintColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      ),
      dividerTheme: const DividerThemeData(
        color: MintColors.lightBorder,
        thickness: 1,
      ),
    );
}
