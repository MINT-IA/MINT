import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// Navigation shell
import 'package:mint_mobile/web/web_navigation_shell.dart';
import 'package:mint_mobile/web/widgets/web_responsive_wrapper.dart';
import 'package:mint_mobile/web/screens/web_home_screen.dart';

// Feature flags
import 'package:mint_mobile/services/feature_flags.dart';

// Auth screens
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:mint_mobile/screens/auth/login_screen.dart';
import 'package:mint_mobile/screens/auth/register_screen.dart';
import 'package:mint_mobile/screens/auth/forgot_password_screen.dart';
import 'package:mint_mobile/screens/auth/verify_email_screen.dart';

// Profile (web-safe only — ProfileScreen excluded: imports dart:io via DocumentProvider)
import 'package:mint_mobile/screens/profile/financial_summary_screen.dart';
import 'package:mint_mobile/screens/consent_dashboard_screen.dart';
import 'package:mint_mobile/screens/byok_settings_screen.dart';
import 'package:mint_mobile/screens/admin_observability_screen.dart';
import 'package:mint_mobile/screens/admin_analytics_screen.dart';

// Simulators
import 'package:mint_mobile/screens/simulator_compound_screen.dart';
import 'package:mint_mobile/screens/simulator_leasing_screen.dart';
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
import 'package:mint_mobile/screens/consumer_credit_screen.dart';
import 'package:mint_mobile/screens/job_comparison_screen.dart';
import 'package:mint_mobile/screens/debt_risk_check_screen.dart';
import 'package:mint_mobile/screens/portfolio_screen.dart';
import 'package:mint_mobile/screens/tools_library_screen.dart';
import 'package:mint_mobile/screens/fiscal_comparator_screen.dart';

// Education
import 'package:mint_mobile/screens/education/comprendre_hub_screen.dart';
import 'package:mint_mobile/screens/education/theme_detail_screen.dart';

// Coach
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/screens/coach/optimisation_decaissement_screen.dart';
import 'package:mint_mobile/screens/coach/succession_patrimoine_screen.dart';
import 'package:mint_mobile/screens/coach/coach_agir_screen.dart';
// coach_checkin_screen excluded: imports notification_service → dart:io
// coach_chat_screen excluded: imports slm_engine → dart:io
import 'package:mint_mobile/screens/coach/annual_refresh_screen.dart';
import 'package:mint_mobile/screens/coach/cockpit_detail_screen.dart';

// Disability
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:mint_mobile/screens/disability/disability_insurance_screen.dart';
import 'package:mint_mobile/screens/disability/disability_self_employed_screen.dart';

// Life events
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/screens/succession_simulator_screen.dart';
import 'package:mint_mobile/screens/mariage_screen.dart';
import 'package:mint_mobile/screens/naissance_screen.dart';
import 'package:mint_mobile/screens/concubinage_screen.dart';
import 'package:mint_mobile/screens/expat_screen.dart';
import 'package:mint_mobile/screens/housing_sale_screen.dart';
import 'package:mint_mobile/screens/donation_screen.dart';
import 'package:mint_mobile/screens/frontalier_screen.dart';

// Segments
import 'package:mint_mobile/screens/gender_gap_screen.dart';
import 'package:mint_mobile/screens/independant_screen.dart';
import 'package:mint_mobile/screens/lamal_franchise_screen.dart';
import 'package:mint_mobile/screens/coverage_check_screen.dart';
import 'package:mint_mobile/screens/unemployment_screen.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';

// Open Banking
import 'package:mint_mobile/screens/open_banking/open_banking_hub_screen.dart';
import 'package:mint_mobile/screens/open_banking/transaction_list_screen.dart';
import 'package:mint_mobile/screens/open_banking/consent_screen.dart';

// LPP Deep
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/libre_passage_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/epl_screen.dart';

// Independants
import 'package:mint_mobile/screens/independants/avs_cotisations_screen.dart';
import 'package:mint_mobile/screens/independants/ijm_screen.dart';
import 'package:mint_mobile/screens/independants/pillar_3a_indep_screen.dart';
import 'package:mint_mobile/screens/independants/dividende_vs_salaire_screen.dart';
import 'package:mint_mobile/screens/independants/lpp_volontaire_screen.dart';

// Mortgage
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/screens/mortgage/amortization_screen.dart';
import 'package:mint_mobile/screens/mortgage/epl_combined_screen.dart';
import 'package:mint_mobile/screens/mortgage/imputed_rental_screen.dart';
import 'package:mint_mobile/screens/mortgage/saron_vs_fixed_screen.dart';

// Pillar 3a Deep
import 'package:mint_mobile/screens/pillar_3a_deep/provider_comparator_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/real_return_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/staggered_withdrawal_screen.dart';

// Debt Prevention
import 'package:mint_mobile/screens/debt_prevention/debt_ratio_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/help_resources_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/repayment_screen.dart';

// Timeline
import 'package:mint_mobile/screens/timeline_screen.dart';

// Advisor / Report
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/screens/advisor/score_reveal_screen.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';

// Onboarding
import 'package:mint_mobile/screens/onboarding/smart_onboarding_screen.dart';
import 'package:mint_mobile/screens/onboarding/quick_start_screen.dart';
import 'package:mint_mobile/screens/onboarding/chiffre_choc_screen.dart';
// data_block_enrichment_screen excluded: imports slm_provider → dart:io

// Arbitrage
import 'package:mint_mobile/screens/arbitrage/arbitrage_bilan_screen.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/screens/arbitrage/allocation_annuelle_screen.dart';
import 'package:mint_mobile/screens/arbitrage/location_vs_propriete_screen.dart';
import 'package:mint_mobile/screens/arbitrage/rachat_vs_marche_screen.dart';
import 'package:mint_mobile/screens/arbitrage/calendrier_retraits_screen.dart';

// Confidence
import 'package:mint_mobile/screens/confidence/confidence_dashboard_screen.dart';
import 'package:mint_mobile/services/confidence/enhanced_confidence_service.dart';

// Budget
import 'package:mint_mobile/screens/budget/budget_container_screen.dart';

// Household
import 'package:mint_mobile/screens/household/household_screen.dart';
import 'package:mint_mobile/screens/household/accept_invitation_screen.dart';

// Ask Mint
import 'package:mint_mobile/screens/ask_mint_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

String? _guardDecisionScaffold() {
  if (FeatureFlags.enableDecisionScaffold) return null;
  return '/tools';
}

/// Complete GoRouter configuration for the MINT web app.
///
/// Includes ALL routes from app.dart EXCEPT mobile-only ones:
/// - /documents, /documents/:id  (DocumentProvider / dart:io)
/// - /document-scan, /document-scan/avs-guide  (camera_ocr)
/// - /bank-import  (native file picker)
/// - /profile/slm  (SLM / flutter_gemma / dart:io)
final GoRouter webRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  errorBuilder: (context, state) => _WebErrorScreen(error: state.error),
  routes: [
    // ── Shell route: main sections with sidebar / bottom nav ──────────────
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => WebNavigationShell(child: child),
      routes: [
        // Home
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => NoTransitionPage(
            child: WebResponsiveWrapper(child: const WebHomeScreen()),
          ),
        ),
        // Tools library
        GoRoute(
          path: '/tools',
          pageBuilder: (context, state) => NoTransitionPage(
            child: WebResponsiveWrapper(child: const ToolsLibraryScreen()),
          ),
        ),
        // Coach dashboard (Prevoyance tab)
        GoRoute(
          path: '/coach/dashboard',
          pageBuilder: (context, state) => NoTransitionPage(
            child: WebResponsiveWrapper(child: const RetirementDashboardScreen()),
          ),
        ),
        // Education hub
        GoRoute(
          path: '/education/hub',
          pageBuilder: (context, state) => NoTransitionPage(
            child: WebResponsiveWrapper(child: const ComprendreHubScreen()),
          ),
        ),
        // Profile (placeholder — full ProfileScreen excluded due to dart:io)
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => NoTransitionPage(
            child: WebResponsiveWrapper(
              child: Scaffold(
                appBar: AppBar(title: const Text('Profil')),
                body: const Center(
                  child: Text('Profil — bientôt disponible sur le web'),
                ),
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: 'admin-observability',
              builder: (context, state) => WebResponsiveWrapper(
                child: const AdminObservabilityScreen(),
              ),
            ),
            GoRoute(
              path: 'admin-analytics',
              builder: (context, state) => WebResponsiveWrapper(
                child: const AdminAnalyticsScreen(),
              ),
            ),
            GoRoute(
              path: 'consent',
              builder: (context, state) => WebResponsiveWrapper(
                child: const ConsentDashboardScreen(),
              ),
            ),
            GoRoute(
              path: 'byok',
              builder: (context, state) => WebResponsiveWrapper(
                child: const ByokSettingsScreen(),
              ),
            ),
            GoRoute(
              path: 'bilan',
              builder: (context, state) => WebResponsiveWrapper(
                child: const FinancialSummaryScreen(),
              ),
            ),
          ],
        ),
      ],
    ),

    // ── Full-screen routes (outside shell) ───────────────────────────────

    // Auth
    GoRoute(
      path: '/landing',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const LandingScreen()),
    ),
    GoRoute(
      path: '/auth/login',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const LoginScreen()),
    ),
    GoRoute(
      path: '/auth/register',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const RegisterScreen()),
    ),
    GoRoute(
      path: '/auth/forgot-password',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const ForgotPasswordScreen()),
    ),
    GoRoute(
      path: '/auth/verify-email',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const VerifyEmailScreen()),
    ),

    // Main Dashboard — redirect to web home (MainNavigationShell excluded: dart:io)
    GoRoute(
      path: '/home',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/',
    ),

    // ── Coach routes ─────────────────────────────────────────────────────
    GoRoute(
      path: '/coach/agir',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const CoachAgirScreen()),
    ),
    // /coach/checkin excluded: notification_service → dart:io
    GoRoute(
      path: '/coach/checkin',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/coach/dashboard',
    ),
    // /coach/chat excluded: slm_engine → dart:io
    GoRoute(
      path: '/coach/chat',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/coach/dashboard',
    ),
    GoRoute(
      path: '/coach/refresh',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const AnnualRefreshScreen()),
    ),
    GoRoute(
      path: '/coach/cockpit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const CockpitDetailScreen()),
    ),
    GoRoute(
      path: '/coach/decaissement',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => WebResponsiveWrapper(
        child: const OptimisationDecaissementScreen(),
      ),
    ),
    GoRoute(
      path: '/coach/succession',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => WebResponsiveWrapper(
        child: const SuccessionPatrimoineScreen(),
      ),
    ),

    // ── Advisor redirects ────────────────────────────────────────────────
    GoRoute(
      path: '/advisor',
      redirect: (context, state) => '/onboarding/smart',
      builder: (context, state) => const SizedBox.shrink(),
    ),
    GoRoute(
      path: '/advisor/plan-30-days',
      redirect: (context, state) => '/coach/agir',
      builder: (context, state) => const SizedBox.shrink(),
    ),
    GoRoute(
      path: '/advisor/wizard',
      redirect: (context, state) {
        final section = state.uri.queryParameters['section'];
        if (section == null || section.isEmpty) return '/onboarding/smart';
        return '/onboarding/smart?section=$section';
      },
    ),

    // ── Ask Mint ─────────────────────────────────────────────────────────
    GoRoute(
      path: '/ask-mint',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const AskMintScreen()),
    ),

    // ── Household ────────────────────────────────────────────────────────
    GoRoute(
      path: '/household',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const HouseholdScreen()),
    ),
    GoRoute(
      path: '/household/accept',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return WebResponsiveWrapper(
          child: AcceptInvitationScreen(initialCode: code),
        );
      },
    ),

    // ── Budget ────────────────────────────────────────────────────────────
    GoRoute(
      path: '/budget',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const BudgetContainerScreen()),
    ),

    // ── Simulators ───────────────────────────────────────────────────────
    GoRoute(
      path: '/simulator/compound',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const SimulatorCompoundScreen()),
    ),
    GoRoute(
      path: '/simulator/leasing',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const SimulatorLeasingScreen()),
    ),
    GoRoute(
      path: '/simulator/3a',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const Simulator3aScreen()),
    ),
    GoRoute(
      path: '/simulator/credit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => WebResponsiveWrapper(
        child: const ConsumerCreditSimulatorScreen(),
      ),
    ),
    GoRoute(
      path: '/simulator/rente-capital',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/arbitrage/rente-vs-capital',
      builder: (context, state) => const SizedBox.shrink(),
    ),
    GoRoute(
      path: '/simulator/disability-gap',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/disability/gap',
    ),
    GoRoute(
      path: '/simulator/job-comparison',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const JobComparisonScreen()),
    ),

    // ── Disability ───────────────────────────────────────────────────────
    GoRoute(
      path: '/disability/gap',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const DisabilityGapScreen()),
    ),
    GoRoute(
      path: '/disability/insurance',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const DisabilityInsuranceScreen()),
    ),
    GoRoute(
      path: '/disability/self-employed',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => WebResponsiveWrapper(
        child: const DisabilitySelfEmployedScreen(),
      ),
    ),

    // ── Life Events ──────────────────────────────────────────────────────
    GoRoute(
      path: '/life-event/divorce',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const DivorceSimulatorScreen()),
    ),
    GoRoute(
      path: '/life-event/succession',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const SuccessionSimulatorScreen()),
    ),
    GoRoute(
      path: '/life-event/housing-sale',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const HousingSaleScreen()),
    ),
    GoRoute(
      path: '/life-event/donation',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const DonationScreen()),
    ),
    GoRoute(
      path: '/mariage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const MariageScreen()),
    ),
    GoRoute(
      path: '/naissance',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const NaissanceScreen()),
    ),
    GoRoute(
      path: '/concubinage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const ConcubinageScreen()),
    ),
    GoRoute(
      path: '/expatriation',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const ExpatScreen()),
    ),

    // ── Checks ───────────────────────────────────────────────────────────
    GoRoute(
      path: '/check/debt',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const DebtRiskCheckScreen()),
    ),
    GoRoute(
      path: '/portfolio',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const PortfolioScreen()),
    ),

    // ── Report ───────────────────────────────────────────────────────────
    GoRoute(
      path: '/report',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/report/v2',
    ),
    GoRoute(
      path: '/report/v2',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return WebResponsiveWrapper(
          child: FinancialReportScreenV2(wizardAnswers: extra),
        );
      },
    ),
    GoRoute(
      path: '/score-reveal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        if (extra != null &&
            extra['score'] is FinancialFitnessScore &&
            extra['profile'] is CoachProfile) {
          return WebResponsiveWrapper(
            child: ScoreRevealScreen(
              score: extra['score'] as FinancialFitnessScore,
              profile: extra['profile'] as CoachProfile,
              wizardAnswers:
                  extra['wizardAnswers'] as Map<String, dynamic>? ?? {},
            ),
          );
        }
        return const WebHomeScreen();
      },
    ),

    // ── Segments ─────────────────────────────────────────────────────────
    GoRoute(
      path: '/segments/gender-gap',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const GenderGapScreen()),
    ),
    GoRoute(
      path: '/segments/frontalier',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const FrontalierScreen()),
    ),
    GoRoute(
      path: '/segments/independant',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const IndependantScreen()),
    ),

    // ── Assurances ───────────────────────────────────────────────────────
    GoRoute(
      path: '/assurances/lamal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const LamalFranchiseScreen()),
    ),
    GoRoute(
      path: '/assurances/coverage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const CoverageCheckScreen()),
    ),

    // ── Open Banking ─────────────────────────────────────────────────────
    GoRoute(
      path: '/open-banking',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const OpenBankingHubScreen()),
    ),
    GoRoute(
      path: '/open-banking/transactions',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const TransactionListScreen()),
    ),
    GoRoute(
      path: '/open-banking/consents',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const ConsentScreen()),
    ),

    // ── LPP Deep ─────────────────────────────────────────────────────────
    GoRoute(
      path: '/lpp-deep/rachat',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const RachatEchelonneScreen()),
    ),
    GoRoute(
      path: '/lpp-deep/libre-passage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const LibrePassageScreen()),
    ),
    GoRoute(
      path: '/lpp-deep/epl',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const EplScreen()),
    ),

    // ── Independants ─────────────────────────────────────────────────────
    GoRoute(
      path: '/independants/avs',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const AvsCotisationsScreen()),
    ),
    GoRoute(
      path: '/independants/ijm',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const IjmScreen()),
    ),
    GoRoute(
      path: '/independants/3a',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const Pillar3aIndepScreen()),
    ),
    GoRoute(
      path: '/independants/dividende-salaire',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => WebResponsiveWrapper(
        child: const DividendeVsSalaireScreen(),
      ),
    ),
    GoRoute(
      path: '/independants/lpp-volontaire',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const LppVolontaireScreen()),
    ),

    // ── Unemployment / First job ─────────────────────────────────────────
    GoRoute(
      path: '/unemployment',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const UnemploymentScreen()),
    ),
    GoRoute(
      path: '/first-job',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const FirstJobScreen()),
    ),

    // ── Fiscal ───────────────────────────────────────────────────────────
    GoRoute(
      path: '/fiscal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const FiscalComparatorScreen()),
    ),

    // ── Retirement redirects ─────────────────────────────────────────────
    GoRoute(
      path: '/retirement',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/coach/dashboard',
      builder: (context, state) => const SizedBox.shrink(),
    ),
    GoRoute(
      path: '/retirement/projection',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/coach/cockpit',
      builder: (context, state) => const SizedBox.shrink(),
    ),

    // ── Mortgage ─────────────────────────────────────────────────────────
    GoRoute(
      path: '/mortgage/affordability',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const AffordabilityScreen()),
    ),
    GoRoute(
      path: '/mortgage/amortization',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const AmortizationScreen()),
    ),
    GoRoute(
      path: '/mortgage/epl-combined',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const EplCombinedScreen()),
    ),
    GoRoute(
      path: '/mortgage/imputed-rental',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const ImputedRentalScreen()),
    ),
    GoRoute(
      path: '/mortgage/saron-vs-fixed',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const SaronVsFixedScreen()),
    ),

    // ── Pillar 3a Deep ───────────────────────────────────────────────────
    GoRoute(
      path: '/3a-deep/comparator',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const ProviderComparatorScreen()),
    ),
    GoRoute(
      path: '/3a-deep/real-return',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const RealReturnScreen()),
    ),
    GoRoute(
      path: '/3a-deep/staggered-withdrawal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => WebResponsiveWrapper(
        child: const StaggeredWithdrawalScreen(),
      ),
    ),

    // ── Debt Prevention ──────────────────────────────────────────────────
    GoRoute(
      path: '/debt/ratio',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const DebtRatioScreen()),
    ),
    GoRoute(
      path: '/debt/help',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const HelpResourcesScreen()),
    ),
    GoRoute(
      path: '/debt/repayment',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const RepaymentScreen()),
    ),

    // ── Onboarding ───────────────────────────────────────────────────────
    GoRoute(
      path: '/onboarding/quick',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const QuickStartScreen()),
    ),
    GoRoute(
      path: '/onboarding/smart',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const SmartOnboardingScreen()),
    ),
    GoRoute(
      path: '/onboarding/minimal',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/onboarding/smart',
    ),
    GoRoute(
      path: '/onboarding/chiffre-choc',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const ChiffreChocScreen()),
    ),
    GoRoute(
      path: '/onboarding/enrichment',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/profile/bilan',
    ),
    // /data-block excluded: slm_provider → dart:io
    GoRoute(
      path: '/data-block/:type',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/profile',
    ),

    // ── Confidence ───────────────────────────────────────────────────────
    GoRoute(
      path: '/confidence',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        final result = extra is ConfidenceResult
            ? extra
            : EnhancedConfidenceService.computeConfidence(
                const <String, dynamic>{},
                const <FieldSource>[],
              );
        return WebResponsiveWrapper(
          child: ConfidenceDashboardScreen(result: result),
        );
      },
    ),

    // ── Timeline ─────────────────────────────────────────────────────────
    GoRoute(
      path: '/timeline',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) =>
          WebResponsiveWrapper(child: const TimelineScreen()),
    ),

    // ── Arbitrage ────────────────────────────────────────────────────────
    GoRoute(
      path: '/arbitrage/bilan',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => _guardDecisionScaffold(),
      builder: (context, state) =>
          WebResponsiveWrapper(child: const ArbitrageBilanScreen()),
    ),
    GoRoute(
      path: '/arbitrage/rente-vs-capital',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => _guardDecisionScaffold(),
      builder: (context, state) =>
          WebResponsiveWrapper(child: const RenteVsCapitalScreen()),
    ),
    GoRoute(
      path: '/arbitrage/allocation-annuelle',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => _guardDecisionScaffold(),
      builder: (context, state) =>
          WebResponsiveWrapper(child: const AllocationAnnuelleScreen()),
    ),
    GoRoute(
      path: '/arbitrage/location-vs-propriete',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => _guardDecisionScaffold(),
      builder: (context, state) => WebResponsiveWrapper(
        child: const LocationVsProprieteScreen(),
      ),
    ),
    GoRoute(
      path: '/arbitrage/rachat-vs-marche',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => _guardDecisionScaffold(),
      builder: (context, state) =>
          WebResponsiveWrapper(child: const RachatVsMarcheScreen()),
    ),
    GoRoute(
      path: '/arbitrage/calendrier-retraits',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => _guardDecisionScaffold(),
      builder: (context, state) =>
          WebResponsiveWrapper(child: const CalendrierRetraitsScreen()),
    ),

    // ── Education (theme detail — outside shell for back navigation) ────
    GoRoute(
      path: '/education/theme/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return WebResponsiveWrapper(
          child: ThemeDetailScreen(themeId: id),
        );
      },
    ),
  ],
);

// ─────────────────────────────────────────────────────────────────────────────

class _WebErrorScreen extends StatelessWidget {
  final Exception? error;
  const _WebErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page introuvable'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore_off_outlined,
                  size: 64, color: Colors.grey),
              const SizedBox(height: 24),
              const Text(
                'Cette page n\'existe pas ou a \u00e9t\u00e9 d\u00e9plac\u00e9e.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Retour \u00e0 l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
