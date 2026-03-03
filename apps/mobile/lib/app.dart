import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:mint_mobile/screens/auth/login_screen.dart';
import 'package:mint_mobile/screens/auth/register_screen.dart';
import 'package:mint_mobile/screens/auth/forgot_password_screen.dart';
import 'package:mint_mobile/screens/auth/verify_email_screen.dart';
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
import 'package:mint_mobile/screens/advisor/onboarding_30_day_plan_screen.dart';
import 'package:mint_mobile/screens/profile_screen.dart';
import 'package:mint_mobile/screens/profile/financial_summary_screen.dart';
import 'package:mint_mobile/screens/main_navigation_shell.dart';
import 'package:mint_mobile/screens/budget/budget_container_screen.dart';
import 'package:mint_mobile/screens/tools_library_screen.dart';
import 'package:mint_mobile/screens/education/comprendre_hub_screen.dart';
import 'package:mint_mobile/screens/education/theme_detail_screen.dart';
import 'package:mint_mobile/screens/simulator_disability_gap_screen.dart';
import 'package:mint_mobile/screens/job_comparison_screen.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/screens/succession_simulator_screen.dart';
import 'package:mint_mobile/screens/byok_settings_screen.dart';
import 'package:mint_mobile/screens/slm_settings_screen.dart';
import 'package:mint_mobile/screens/ask_mint_screen.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/screens/documents_screen.dart';
import 'package:mint_mobile/screens/document_detail_screen.dart';
import 'package:mint_mobile/screens/bank_import_screen.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/analytics_observer.dart';
import 'package:mint_mobile/services/notification_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
// coaching_screen.dart import removed — route superseded by coach/*
import 'package:mint_mobile/screens/gender_gap_screen.dart';
import 'package:mint_mobile/screens/frontalier_screen.dart';
import 'package:mint_mobile/screens/independant_screen.dart';
import 'package:mint_mobile/screens/lamal_franchise_screen.dart';
import 'package:mint_mobile/screens/coverage_check_screen.dart';
import 'package:mint_mobile/screens/open_banking/open_banking_hub_screen.dart';
import 'package:mint_mobile/screens/open_banking/transaction_list_screen.dart';
import 'package:mint_mobile/screens/open_banking/consent_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/rachat_echelonne_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/libre_passage_screen.dart';
import 'package:mint_mobile/screens/lpp_deep/epl_screen.dart';
// Independants complet (Sprint S18)
import 'package:mint_mobile/screens/independants/avs_cotisations_screen.dart';
import 'package:mint_mobile/screens/independants/ijm_screen.dart';
import 'package:mint_mobile/screens/independants/pillar_3a_indep_screen.dart';
import 'package:mint_mobile/screens/independants/dividende_vs_salaire_screen.dart';
import 'package:mint_mobile/screens/independants/lpp_volontaire_screen.dart';
// Chomage + Premier emploi (Sprint S19)
import 'package:mint_mobile/screens/unemployment_screen.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
// Fiscalite cantonale (Sprint S20)
import 'package:mint_mobile/screens/fiscal_comparator_screen.dart';
// Famille & Concubinage (Sprint S22)
import 'package:mint_mobile/screens/mariage_screen.dart';
import 'package:mint_mobile/screens/naissance_screen.dart';
import 'package:mint_mobile/screens/concubinage_screen.dart';
// Expatriation + Frontaliers (Sprint S23)
import 'package:mint_mobile/screens/expat_screen.dart';
// Report V2
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
// Score Reveal (Post-Wizard)
import 'package:mint_mobile/screens/advisor/score_reveal_screen.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
// Housing Sale + Donation (Sprint S24)
import 'package:mint_mobile/screens/housing_sale_screen.dart';
import 'package:mint_mobile/screens/donation_screen.dart';
// Mortgage screens (Sprint S16)
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/screens/mortgage/amortization_screen.dart';
import 'package:mint_mobile/screens/mortgage/epl_combined_screen.dart';
import 'package:mint_mobile/screens/mortgage/imputed_rental_screen.dart';
import 'package:mint_mobile/screens/mortgage/saron_vs_fixed_screen.dart';
import 'package:mint_mobile/screens/admin_observability_screen.dart';
import 'package:mint_mobile/screens/admin_analytics_screen.dart';
// Pillar 3a Deep (Sprint S17)
import 'package:mint_mobile/screens/pillar_3a_deep/provider_comparator_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/real_return_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/staggered_withdrawal_screen.dart';
// Debt Prevention (Sprint S13)
import 'package:mint_mobile/screens/debt_prevention/debt_ratio_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/help_resources_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/repayment_screen.dart';
// Timeline
import 'package:mint_mobile/screens/timeline_screen.dart';
// Coach screens (Sprint C5-C10)
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/screens/coach/coach_agir_screen.dart';
import 'package:mint_mobile/screens/coach/coach_checkin_screen.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:mint_mobile/screens/coach/annual_refresh_screen.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
import 'package:mint_mobile/providers/onboarding_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
// Onboarding Redesign (Sprint S31)
import 'package:mint_mobile/screens/onboarding/smart_onboarding_screen.dart';
import 'package:mint_mobile/screens/onboarding/chiffre_choc_screen.dart';
import 'package:mint_mobile/screens/onboarding/progressive_enrichment_screen.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
// Arbitrage Phase 1 (Sprint S32)
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/screens/arbitrage/allocation_annuelle_screen.dart';
// Arbitrage Phase 2 (Sprint S33)
import 'package:mint_mobile/screens/arbitrage/location_vs_propriete_screen.dart';
import 'package:mint_mobile/screens/arbitrage/rachat_vs_marche_screen.dart';
import 'package:mint_mobile/screens/arbitrage/calendrier_retraits_screen.dart';
import 'package:mint_mobile/screens/confidence/confidence_dashboard_screen.dart';
import 'package:mint_mobile/services/confidence/enhanced_confidence_service.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/screens/document_scan/avs_guide_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: [AnalyticsRouteObserver()],
  initialLocation: '/',
  errorBuilder: (context, state) => _MintErrorScreen(error: state.error),
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
    GoRoute(
      path: '/auth/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/auth/verify-email',
      builder: (context, state) => const VerifyEmailScreen(),
    ),
    // Main Dashboard (Shell with internal tabs)
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigationShell(),
    ),
    // Coach routes (Sprint C10)
    GoRoute(
      path: '/coach/dashboard',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RetirementDashboardScreen(),
    ),
    GoRoute(
      path: '/coach/agir',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CoachAgirScreen(),
    ),
    GoRoute(
      path: '/coach/checkin',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CoachCheckinScreen(),
    ),
    GoRoute(
      path: '/coach/chat',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CoachChatScreen(),
    ),
    GoRoute(
      path: '/coach/refresh',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AnnualRefreshScreen(),
    ),
    // Feature Routes (Full Screen)
    GoRoute(
      path: '/advisor',
      builder: (context, state) => const AdvisorOnboardingScreen(),
      routes: [
        GoRoute(
          path: 'plan-30-days',
          builder: (context, state) {
            final extra = state.extra;
            Map<String, dynamic>? contextData;
            if (extra is Map<String, dynamic>) {
              contextData = extra;
            }
            return Onboarding30DayPlanScreen(
              stressChoice: contextData?['stress_choice'] as String?,
              mainGoal: contextData?['main_goal'] as String?,
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/advisor/wizard',
      builder: (context, state) {
        final extra = state.extra;
        Map<String, dynamic>? contextData;
        if (extra is Map<String, dynamic>) {
          contextData = extra;
        }
        final sectionFromQuery = state.uri.queryParameters['section'];
        final section =
            (contextData?['section'] as String?) ?? sectionFromQuery;
        return AdvisorWizardScreenV2(
          initialSection: section,
        );
      },
    ),
    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
      routes: [
        GoRoute(
          path: 'admin-observability',
          builder: (context, state) => const AdminObservabilityScreen(),
        ),
        GoRoute(
          path: 'admin-analytics',
          builder: (context, state) => const AdminAnalyticsScreen(),
        ),
        GoRoute(
          path: 'consent',
          builder: (context, state) => const ConsentDashboardScreen(),
        ),
        GoRoute(
          path: 'byok',
          builder: (context, state) => const ByokSettingsScreen(),
        ),
        GoRoute(
          path: 'slm',
          builder: (context, state) => const SlmSettingsScreen(),
        ),
        GoRoute(
          path: 'bilan',
          builder: (context, state) => const FinancialSummaryScreen(),
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
    GoRoute(
      path: '/document-scan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DocumentScanScreen(),
    ),
    GoRoute(
      path: '/document-scan/avs-guide',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AvsGuideScreen(),
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
      redirect: (context, state) => '/arbitrage/rente-vs-capital',
      builder: (context, state) => const SizedBox.shrink(),
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
      redirect: (context, state) => '/report/v2',
    ),
    GoRoute(
      path: '/report/v2',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return FinancialReportScreenV2(wizardAnswers: extra);
      },
    ),
    // Score Reveal (Post-Wizard animation)
    GoRoute(
      path: '/score-reveal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        if (extra != null &&
            extra['score'] is FinancialFitnessScore &&
            extra['profile'] is CoachProfile) {
          return ScoreRevealScreen(
            score: extra['score'] as FinancialFitnessScore,
            profile: extra['profile'] as CoachProfile,
            wizardAnswers:
                extra['wizardAnswers'] as Map<String, dynamic>? ?? {},
          );
        }
        // Fallback: navigate home if data is missing
        return const MainNavigationShell();
      },
    ),
    GoRoute(
      path: '/tools',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ToolsLibraryScreen(),
    ),
    // /coaching route removed — CoachingScreen superseded by coach/dashboard + coach/agir
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
    // Assurances
    GoRoute(
      path: '/assurances/lamal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LamalFranchiseScreen(),
    ),
    GoRoute(
      path: '/assurances/coverage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CoverageCheckScreen(),
    ),
    // Open Banking (Sprint S14 — FINMA gate)
    GoRoute(
      path: '/open-banking',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OpenBankingHubScreen(),
    ),
    GoRoute(
      path: '/open-banking/transactions',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TransactionListScreen(),
    ),
    GoRoute(
      path: '/open-banking/consents',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConsentScreen(),
    ),
    // LPP Deep (Sprint S15 — Chantier 4)
    GoRoute(
      path: '/lpp-deep/rachat',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RachatEchelonneScreen(),
    ),
    GoRoute(
      path: '/lpp-deep/libre-passage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LibrePassageScreen(),
    ),
    GoRoute(
      path: '/lpp-deep/epl',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EplScreen(),
    ),
    // Independants complet (Sprint S18)
    GoRoute(
      path: '/independants/avs',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AvsCotisationsScreen(),
    ),
    GoRoute(
      path: '/independants/ijm',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const IjmScreen(),
    ),
    GoRoute(
      path: '/independants/3a',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const Pillar3aIndepScreen(),
    ),
    GoRoute(
      path: '/independants/dividende-salaire',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DividendeVsSalaireScreen(),
    ),
    GoRoute(
      path: '/independants/lpp-volontaire',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LppVolontaireScreen(),
    ),
    // Chomage + Premier emploi (Sprint S19)
    GoRoute(
      path: '/unemployment',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const UnemploymentScreen(),
    ),
    GoRoute(
      path: '/first-job',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FirstJobScreen(),
    ),
    // Fiscalite cantonale (Sprint S20)
    GoRoute(
      path: '/fiscal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FiscalComparatorScreen(),
    ),
    // Retraite complete (Sprint S21)
    GoRoute(
      path: '/retirement',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/coach/dashboard',
      builder: (context, state) => const SizedBox.shrink(),
    ),
    GoRoute(
      path: '/retirement/projection',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/coach/dashboard',
      builder: (context, state) => const SizedBox.shrink(),
    ),
    // Famille & Concubinage (Sprint S22)
    GoRoute(
      path: '/mariage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MariageScreen(),
    ),
    GoRoute(
      path: '/naissance',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NaissanceScreen(),
    ),
    GoRoute(
      path: '/concubinage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConcubinageScreen(),
    ),
    // Expatriation (Sprint S23)
    GoRoute(
      path: '/expatriation',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExpatScreen(),
    ),
    // Housing Sale + Donation (Sprint S24)
    GoRoute(
      path: '/life-event/housing-sale',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const HousingSaleScreen(),
    ),
    GoRoute(
      path: '/life-event/donation',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DonationScreen(),
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
    // Mortgage (Sprint S16)
    GoRoute(
      path: '/mortgage/affordability',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AffordabilityScreen(),
    ),
    GoRoute(
      path: '/mortgage/amortization',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AmortizationScreen(),
    ),
    GoRoute(
      path: '/mortgage/epl-combined',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EplCombinedScreen(),
    ),
    GoRoute(
      path: '/mortgage/imputed-rental',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ImputedRentalScreen(),
    ),
    GoRoute(
      path: '/mortgage/saron-vs-fixed',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SaronVsFixedScreen(),
    ),
    // Pillar 3a Deep (Sprint S17)
    GoRoute(
      path: '/3a-deep/comparator',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProviderComparatorScreen(),
    ),
    GoRoute(
      path: '/3a-deep/real-return',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RealReturnScreen(),
    ),
    GoRoute(
      path: '/3a-deep/staggered-withdrawal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const StaggeredWithdrawalScreen(),
    ),
    // Debt Prevention (Sprint S13)
    GoRoute(
      path: '/debt/ratio',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DebtRatioScreen(),
    ),
    GoRoute(
      path: '/debt/help',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const HelpResourcesScreen(),
    ),
    GoRoute(
      path: '/debt/repayment',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RepaymentScreen(),
    ),
    // === Route Compatibility Layer (migration P0) ===
    // Old routes redirect to new smart onboarding flow.
    // Keep /advisor/plan-30-days as-is (still active).
    GoRoute(
      path: '/onboarding/smart',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SmartOnboardingScreen(),
    ),
    // Onboarding Redesign (Sprint S31)
    GoRoute(
      path: '/onboarding/minimal',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => '/onboarding/smart',
    ),
    GoRoute(
      path: '/onboarding/chiffre-choc',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ChiffreChocScreen(),
    ),
    GoRoute(
      path: '/onboarding/enrichment',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProgressiveEnrichmentScreen(),
    ),
    // Data Block Enrichment (P8 Phase 3)
    GoRoute(
      path: '/data-block/:type',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final type = state.pathParameters['type'] ?? 'revenu';
        return DataBlockEnrichmentScreen(blockType: type);
      },
    ),
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
        return ConfidenceDashboardScreen(result: result);
      },
    ),
    // Timeline
    GoRoute(
      path: '/timeline',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TimelineScreen(),
    ),
    // Arbitrage Phase 1 (Sprint S32)
    GoRoute(
      path: '/arbitrage/rente-vs-capital',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RenteVsCapitalScreen(),
    ),
    GoRoute(
      path: '/arbitrage/allocation-annuelle',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AllocationAnnuelleScreen(),
    ),
    // Arbitrage Phase 2 (Sprint S33)
    GoRoute(
      path: '/arbitrage/location-vs-propriete',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LocationVsProprieteScreen(),
    ),
    GoRoute(
      path: '/arbitrage/rachat-vs-marche',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RachatVsMarcheScreen(),
    ),
    GoRoute(
      path: '/arbitrage/calendrier-retraits',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CalendrierRetraitsScreen(),
    ),
  ],
);

class MintApp extends StatefulWidget {
  const MintApp({super.key});

  @override
  State<MintApp> createState() => _MintAppState();
}

class _MintAppState extends State<MintApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initialize analytics service
    AnalyticsService().init();
    // Initialize local notifications for coaching reminders
    NotificationService().init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      // Release SLM model (~2 GB RAM) when app goes to background.
      // The model will be re-initialized on next use.
      if (SlmEngine.instance.isAvailable) {
        SlmEngine.instance.dispose();
      }
    }
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
        ChangeNotifierProvider(create: (_) => SubscriptionProvider()),
        ChangeNotifierProvider(create: (_) {
          final provider = CoachProfileProvider();
          provider.loadFromWizard();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) {
          final provider = LocaleProvider();
          provider.load();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) {
          final provider = OnboardingProvider();
          provider.init();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) {
          final provider = UserActivityProvider();
          provider.loadAll();
          return provider;
        }),
      ],
      child: Builder(
        builder: (context) {
          final localeProvider = context.watch<LocaleProvider>();
          return MaterialApp.router(
            title: 'Mint',
            debugShowCheckedModeBanner: false,
            theme: _buildPremiumTheme(),
            themeMode: ThemeMode.light,
            routerConfig: _router,
            localizationsDelegates: S.localizationsDelegates,
            supportedLocales: S.supportedLocales,
            locale: localeProvider.locale,
          );
        },
      ),
    );
  }
}

ThemeData _buildPremiumTheme() {
  // Inter for UI, Outfit for Headlines (Premium Modern combination)
  final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

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
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
    ),
    dividerTheme: const DividerThemeData(
      color: MintColors.lightBorder,
      thickness: 1,
    ),
  );
}

class _MintErrorScreen extends StatelessWidget {
  final Exception? error;
  const _MintErrorScreen({this.error});

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
                'Cette page n\'existe pas ou a ete deplacee.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Retour a l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
