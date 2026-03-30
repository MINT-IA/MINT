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
import 'package:mint_mobile/screens/profile_screen.dart';
import 'package:mint_mobile/screens/profile/financial_summary_screen.dart';
import 'package:mint_mobile/screens/main_navigation_shell.dart';
import 'package:mint_mobile/screens/budget/budget_container_screen.dart';
import 'package:mint_mobile/screens/tools_library_screen.dart';
import 'package:mint_mobile/screens/education/comprendre_hub_screen.dart';
import 'package:mint_mobile/screens/education/theme_detail_screen.dart';
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:mint_mobile/screens/disability/disability_insurance_screen.dart';
import 'package:mint_mobile/screens/disability/disability_self_employed_screen.dart';
import 'package:mint_mobile/screens/job_comparison_screen.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
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
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/notification_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';
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
import 'package:mint_mobile/screens/independants/avs_cotisations_screen.dart';
import 'package:mint_mobile/screens/independants/ijm_screen.dart';
import 'package:mint_mobile/screens/independants/pillar_3a_indep_screen.dart';
import 'package:mint_mobile/screens/independants/dividende_vs_salaire_screen.dart';
import 'package:mint_mobile/screens/independants/lpp_volontaire_screen.dart';
import 'package:mint_mobile/screens/unemployment_screen.dart';
import 'package:mint_mobile/screens/first_job_screen.dart';
import 'package:mint_mobile/screens/fiscal_comparator_screen.dart';
import 'package:mint_mobile/screens/mariage_screen.dart';
import 'package:mint_mobile/screens/naissance_screen.dart';
import 'package:mint_mobile/screens/concubinage_screen.dart';
import 'package:mint_mobile/screens/expat_screen.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/screens/advisor/score_reveal_screen.dart';
import 'package:mint_mobile/screens/expert/expert_tier_screen.dart';
import 'package:mint_mobile/screens/coach/weekly_recap_screen.dart';
import 'package:mint_mobile/screens/b2b/b2b_hub_screen.dart';
import 'package:mint_mobile/screens/institutional/pension_fund_connect_screen.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_fitness_service.dart';
import 'package:mint_mobile/screens/housing_sale_screen.dart';
import 'package:mint_mobile/screens/donation_screen.dart';
import 'package:mint_mobile/screens/deces_proche_screen.dart';
import 'package:mint_mobile/screens/demenagement_cantonal_screen.dart';
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';
import 'package:mint_mobile/screens/mortgage/amortization_screen.dart';
import 'package:mint_mobile/screens/mortgage/epl_combined_screen.dart';
import 'package:mint_mobile/screens/mortgage/imputed_rental_screen.dart';
import 'package:mint_mobile/screens/mortgage/saron_vs_fixed_screen.dart';
import 'package:mint_mobile/screens/admin_observability_screen.dart';
import 'package:mint_mobile/screens/admin_analytics_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/provider_comparator_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/real_return_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/staggered_withdrawal_screen.dart';
import 'package:mint_mobile/screens/pillar_3a_deep/retroactive_3a_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/debt_ratio_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/help_resources_screen.dart';
import 'package:mint_mobile/screens/debt_prevention/repayment_screen.dart';
import 'package:mint_mobile/screens/timeline_screen.dart';
import 'package:mint_mobile/screens/coach/retirement_dashboard_screen.dart';
import 'package:mint_mobile/screens/coach/optimisation_decaissement_screen.dart';
import 'package:mint_mobile/screens/coach/succession_patrimoine_screen.dart';
import 'package:mint_mobile/screens/coach/coach_checkin_screen.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:mint_mobile/screens/coach/conversation_history_screen.dart';
import 'package:mint_mobile/screens/coach/annual_refresh_screen.dart';
import 'package:mint_mobile/screens/coach/cockpit_detail_screen.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/onboarding/quick_start_screen.dart';
import 'package:mint_mobile/screens/onboarding/chiffre_choc_screen.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/screens/arbitrage/arbitrage_bilan_screen.dart';
import 'package:mint_mobile/screens/arbitrage/rente_vs_capital_screen.dart';
import 'package:mint_mobile/screens/arbitrage/allocation_annuelle_screen.dart';
import 'package:mint_mobile/screens/arbitrage/location_vs_propriete_screen.dart';
import 'package:mint_mobile/screens/confidence/confidence_dashboard_screen.dart';
import 'package:mint_mobile/services/confidence/enhanced_confidence_service.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/screens/document_scan/document_scan_screen.dart';
import 'package:mint_mobile/screens/document_scan/avs_guide_screen.dart';
import 'package:mint_mobile/screens/document_scan/extraction_review_screen.dart';
import 'package:mint_mobile/screens/document_scan/document_impact_screen.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/providers/household_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/household/household_screen.dart';
import 'package:mint_mobile/screens/household/accept_invitation_screen.dart';
import 'package:mint_mobile/screens/achievements_screen.dart';
import 'package:mint_mobile/screens/cantonal_benchmark_screen.dart';
import 'package:mint_mobile/screens/explore/retraite_hub_screen.dart';
import 'package:mint_mobile/screens/explore/famille_hub_screen.dart';
import 'package:mint_mobile/screens/explore/travail_hub_screen.dart';
import 'package:mint_mobile/screens/explore/logement_hub_screen.dart';
import 'package:mint_mobile/screens/explore/fiscalite_hub_screen.dart';
import 'package:mint_mobile/screens/explore/patrimoine_hub_screen.dart';
import 'package:mint_mobile/screens/explore/sante_hub_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

/// Redirect-loop guard counter (P0-1). Tracks consecutive auth redirects.
int _authRedirectCount = 0;

// ════════════════════════════════════════════════════════════
//  ROUTER — S49 Phase 2: Simplified navigation
// ════════════════════════════════════════════════════════════
//
//  Target: ~50 canonical routes + legacy redirects
//  Feature flags removed for production-ready screens.
//  OpenBanking + Admin flags preserved (post-V1 / dev-only).
//
//  Route naming convention:
//    /retraite, /rente-vs-capital, /rachat-lpp, /epl, /pilier-3a,
//    /hypotheque, /decaissement, /scan, /couple, /rapport,
//    /invalidite, /divorce, /succession
// ════════════════════════════════════════════════════════════

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: [AnalyticsRouteObserver()],
  initialLocation: '/',
  errorBuilder: (context, state) => _MintErrorScreen(error: state.error),
  redirect: (context, state) {
    final path = state.uri.path;

    // ── Redirect-loop guard (P0-1) ──
    // Reset counter when we reach a non-auth destination (loop resolved).
    if (!path.startsWith('/auth/')) {
      _authRedirectCount = 0;
    }

    // Break infinite redirect chains (e.g. /scan→register→verify→login→scan).
    if (_authRedirectCount > 3) {
      _authRedirectCount = 0;
      return '/auth/login';
    }

    // Detect verify-email ↔ login ping-pong cycle.
    if (path == '/auth/verify-email' || path == '/auth/login') {
      final from = state.uri.queryParameters['redirect'] ?? '';
      if ((path == '/auth/verify-email' && from.startsWith('/auth/login')) ||
          (path == '/auth/login' && from.startsWith('/auth/verify-email'))) {
        _authRedirectCount = 0;
        return '/auth/login';
      }
    }

    final auth = context.read<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;

    // Routes that REQUIRE auth (data-writing operations)
    const protectedPrefixes = [
      '/scan',        // document scanning
      '/coach/chat',  // AI coach (token consumption)
      '/couple',      // household/couple features
      '/profile/byok', // API key management
      '/bank-import', // bank statement import
    ];

    // Check if current path is protected
    final isProtected = protectedPrefixes.any((p) => path.startsWith(p));

    // If protected and not logged in, redirect to register with return URL
    if (isProtected && !isLoggedIn) {
      // P0-2: Validate redirect path — must start with / and NOT with //
      // to prevent open-redirect / phishing via crafted URLs.
      final safePath = (path.startsWith('/') && !path.startsWith('//')) ? path : '/';
      _authRedirectCount++;
      return '/auth/register?redirect=${Uri.encodeComponent(safePath)}';
    }

    return null; // No redirect needed
  },
  routes: [
    // ── Landing + Auth ────────────────────────────────────────
    GoRoute(
      path: '/',
      builder: (context, state) => const LandingScreen(),
    ),
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

    // ── Main Shell (4 tabs: Aujourd'hui, Coach, Explorer, Dossier) ──
    GoRoute(
      path: '/home',
      builder: (context, state) => const MainNavigationShell(),
    ),

    // ── EXPLORER HUBS (7 thematic hubs) ──────────────────────
    GoRoute(
      path: '/explore/retraite',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RetraiteHubScreen(),
    ),
    GoRoute(
      path: '/explore/famille',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FamilleHubScreen(),
    ),
    GoRoute(
      path: '/explore/travail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TravailHubScreen(),
    ),
    GoRoute(
      path: '/explore/logement',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LogementHubScreen(),
    ),
    GoRoute(
      path: '/explore/fiscalite',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FiscaliteHubScreen(),
    ),
    GoRoute(
      path: '/explore/patrimoine',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PatrimoineHubScreen(),
    ),
    GoRoute(
      path: '/explore/sante',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SanteHubScreen(),
    ),

    // ── RETRAITE & PREVOYANCE ────────────────────────────────
    GoRoute(
      path: '/retraite',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RetirementDashboardScreen(),
    ),
    // Legacy redirects
    GoRoute(path: '/coach/dashboard', redirect: (_, __) => '/retraite'),
    GoRoute(path: '/retirement', redirect: (_, __) => '/retraite'),
    GoRoute(path: '/retirement/projection', redirect: (_, __) => '/retraite'),

    GoRoute(
      path: '/rente-vs-capital',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RenteVsCapitalScreen(),
    ),
    GoRoute(path: '/arbitrage/rente-vs-capital', redirect: (_, __) => '/rente-vs-capital'),
    GoRoute(path: '/simulator/rente-capital', redirect: (_, __) => '/rente-vs-capital'),

    GoRoute(
      path: '/rachat-lpp',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RachatEchelonneScreen(),
    ),
    GoRoute(path: '/lpp-deep/rachat', redirect: (_, __) => '/rachat-lpp'),
    GoRoute(path: '/arbitrage/rachat-vs-marche', redirect: (_, __) => '/rachat-lpp'),

    GoRoute(
      path: '/epl',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EplScreen(),
    ),
    GoRoute(path: '/lpp-deep/epl', redirect: (_, __) => '/epl'),

    GoRoute(
      path: '/decaissement',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OptimisationDecaissementScreen(),
    ),
    GoRoute(path: '/coach/decaissement', redirect: (_, __) => '/decaissement'),
    GoRoute(path: '/arbitrage/calendrier-retraits', redirect: (_, __) => '/decaissement'),

    GoRoute(
      path: '/coach/cockpit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CockpitDetailScreen(),
    ),
    GoRoute(
      path: '/coach/checkin',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CoachCheckinScreen(),
    ),
    GoRoute(
      path: '/coach/refresh',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AnnualRefreshScreen(),
    ),
    GoRoute(
      path: '/coach/chat',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final prompt = state.uri.queryParameters['prompt'];
        final conversationId = state.uri.queryParameters['conversationId'];
        return CoachChatScreen(
          initialPrompt: prompt,
          conversationId: conversationId,
        );
      },
    ),
    GoRoute(
      path: '/coach/history',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConversationHistoryScreen(),
    ),
    GoRoute(
      path: '/succession',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SuccessionPatrimoineScreen(),
    ),
    GoRoute(path: '/coach/succession', redirect: (_, __) => '/succession'),
    GoRoute(path: '/life-event/succession', redirect: (_, __) => '/succession'),

    GoRoute(
      path: '/libre-passage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LibrePassageScreen(),
    ),
    GoRoute(path: '/lpp-deep/libre-passage', redirect: (_, __) => '/libre-passage'),

    // ── FISCALITE ────────────────────────────────────────────
    GoRoute(
      path: '/pilier-3a',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const Simulator3aScreen(),
    ),
    GoRoute(path: '/simulator/3a', redirect: (_, __) => '/pilier-3a'),

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
    GoRoute(
      path: '/3a-retroactif',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const Retroactive3aScreen(),
    ),
    GoRoute(
      path: '/fiscal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FiscalComparatorScreen(),
    ),

    // ── IMMOBILIER ───────────────────────────────────────────
    GoRoute(
      path: '/hypotheque',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AffordabilityScreen(),
    ),
    GoRoute(path: '/mortgage/affordability', redirect: (_, __) => '/hypotheque'),
    GoRoute(path: '/life-event/housing-purchase', redirect: (_, __) => '/hypotheque'),

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

    // ── BUDGET & DETTE ───────────────────────────────────────
    GoRoute(
      path: '/budget',
      builder: (context, state) => const BudgetContainerScreen(),
    ),
    GoRoute(
      path: '/check/debt',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DebtRiskCheckScreen(),
    ),
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

    // ── FAMILLE ──────────────────────────────────────────────
    GoRoute(
      path: '/divorce',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DivorceSimulatorScreen(),
    ),
    GoRoute(path: '/life-event/divorce', redirect: (_, __) => '/divorce'),

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

    // ── EMPLOI & STATUT ──────────────────────────────────────
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
    GoRoute(
      path: '/expatriation',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExpatScreen(),
    ),
    GoRoute(
      path: '/simulator/job-comparison',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const JobComparisonScreen(),
    ),

    // ── INDEPENDANTS ─────────────────────────────────────────
    GoRoute(
      path: '/segments/independant',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const IndependantScreen(),
    ),
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

    // ── ASSURANCE & SANTE ────────────────────────────────────
    GoRoute(
      path: '/invalidite',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DisabilityGapScreen(),
    ),
    GoRoute(path: '/disability/gap', redirect: (_, __) => '/invalidite'),
    GoRoute(path: '/simulator/disability-gap', redirect: (_, __) => '/invalidite'),

    GoRoute(
      path: '/disability/insurance',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DisabilityInsuranceScreen(),
    ),
    GoRoute(
      path: '/disability/self-employed',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DisabilitySelfEmployedScreen(),
    ),
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

    // ── DOCUMENTS & SCAN ─────────────────────────────────────
    GoRoute(
      path: '/scan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        final initialType = extra is DocumentType ? extra : null;
        return DocumentScanScreen(initialType: initialType);
      },
    ),
    GoRoute(path: '/document-scan', redirect: (_, __) => '/scan'),

    GoRoute(
      path: '/scan/avs-guide',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AvsGuideScreen(),
    ),
    GoRoute(path: '/document-scan/avs-guide', redirect: (_, __) => '/scan/avs-guide'),
    GoRoute(
      path: '/scan/review',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final result = state.extra as ExtractionResult?;
        if (result == null) {
          return const Scaffold(
            body: Center(child: Text('Document non disponible')),
          );
        }
        return ExtractionReviewScreen(result: result);
      },
    ),
    GoRoute(
      path: '/scan/impact',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        if (extra == null ||
            extra['result'] is! ExtractionResult ||
            extra['previousConfidence'] is! int) {
          return const Scaffold(
            body: Center(child: Text('Document non disponible')),
          );
        }
        return DocumentImpactScreen(
          result: extra['result'] as ExtractionResult,
          previousConfidence: extra['previousConfidence'] as int,
        );
      },
    ),

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

    // ── COUPLE ────────────────────────────────────────────────
    GoRoute(
      path: '/couple',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const HouseholdScreen(),
    ),
    GoRoute(path: '/household', redirect: (_, __) => '/couple'),

    GoRoute(
      path: '/couple/accept',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return AcceptInvitationScreen(initialCode: code);
      },
    ),
    GoRoute(path: '/household/accept', redirect: (context, state) {
      final code = state.uri.queryParameters['code'];
      return code != null ? '/couple/accept?code=$code' : '/couple/accept';
    }),

    // ── RAPPORT & PROFIL ─────────────────────────────────────
    GoRoute(
      path: '/rapport',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        return FinancialReportScreenV2(wizardAnswers: extra);
      },
    ),
    GoRoute(path: '/report', redirect: (_, __) => '/rapport'),
    GoRoute(path: '/report/v2', redirect: (_, __) => '/rapport'),

    GoRoute(
      path: '/profile',
      builder: (context, state) => const ProfileScreen(),
      routes: [
        GoRoute(
          path: 'admin-observability',
          redirect: (context, state) =>
              FeatureFlags.enableAdminScreens ? null : '/',
          builder: (context, state) => const AdminObservabilityScreen(),
        ),
        GoRoute(
          path: 'admin-analytics',
          redirect: (context, state) =>
              FeatureFlags.enableAdminScreens ? null : '/',
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

    // ── SEGMENTS ─────────────────────────────────────────────
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
      path: '/life-event/housing-sale',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const HousingSaleScreen(),
    ),
    GoRoute(
      path: '/life-event/donation',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DonationScreen(),
    ),
    GoRoute(
      path: '/life-event/deces-proche',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DecesProcheScreen(),
    ),
    GoRoute(
      path: '/life-event/demenagement-cantonal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DemenagementCantonalScreen(),
    ),

    // ── EDUCATION ────────────────────────────────────────────
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

    // ── SIMULATEURS (accessibles directement) ────────────────
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
      path: '/simulator/credit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConsumerCreditSimulatorScreen(),
    ),

    // ── ARBITRAGE (restants) ─────────────────────────────────
    GoRoute(
      path: '/arbitrage/bilan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArbitrageBilanScreen(),
    ),
    GoRoute(
      path: '/arbitrage/allocation-annuelle',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AllocationAnnuelleScreen(),
    ),
    GoRoute(
      path: '/arbitrage/location-vs-propriete',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LocationVsProprieteScreen(),
    ),

    // ── ACHIEVEMENTS ──────────────────────────────────────────
    GoRoute(
      path: '/achievements',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AchievementsScreen(),
    ),

    // ── WEEKLY RECAP (S52 — redirect until implemented) ─────────
    GoRoute(
      path: '/weekly-recap',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const WeeklyRecapScreen(),
    ),

    // ── CANTONAL BENCHMARKS ──────────────────────────────────
    GoRoute(
      path: '/cantonal-benchmark',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CantonalBenchmarkScreen(),
    ),

    // ── OUTILS & DIVERS ─────────────────────────────────────
    GoRoute(
      path: '/ask-mint',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AskMintScreen(),
    ),
    GoRoute(
      path: '/tools',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ToolsLibraryScreen(),
    ),
    GoRoute(
      path: '/portfolio',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const PortfolioScreen(),
    ),
    GoRoute(
      path: '/timeline',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TimelineScreen(),
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
        return const MainNavigationShell();
      },
    ),

    // ── ONBOARDING ───────────────────────────────────────────
    GoRoute(
      path: '/onboarding/quick',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final section = state.uri.queryParameters['section'];
        return QuickStartScreen(initialSection: section);
      },
    ),
    GoRoute(
      path: '/onboarding/chiffre-choc',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ChiffreChocScreen(),
    ),
    GoRoute(
      path: '/data-block/:type',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final type = state.pathParameters['type'] ?? 'revenu';
        return DataBlockEnrichmentScreen(blockType: type);
      },
    ),

    // ── OPEN BANKING (post-V1, FINMA gate) ───────────────────
    GoRoute(
      path: '/open-banking',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) =>
          FeatureFlags.enableOpenBanking ? null : '/',
      builder: (context, state) => const OpenBankingHubScreen(),
    ),
    GoRoute(
      path: '/open-banking/transactions',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) =>
          FeatureFlags.enableOpenBanking ? null : '/',
      builder: (context, state) => const TransactionListScreen(),
    ),
    GoRoute(
      path: '/open-banking/consents',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) =>
          FeatureFlags.enableOpenBanking ? null : '/',
      builder: (context, state) => const ConsentScreen(),
    ),
    GoRoute(
      path: '/bank-import',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BankImportScreen(),
    ),

    // ── LEGACY REDIRECTS (backwards compat) ──────────────────
    GoRoute(path: '/advisor', redirect: (_, __) => '/onboarding/quick'),
    GoRoute(
      path: '/expert-tier',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) =>
          FeatureFlags.enableExpertTier ? null : '/',
      builder: (context, state) => const ExpertTierScreen(),
    ),
    GoRoute(
      path: '/b2b',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const B2bHubScreen(),
    ),
    GoRoute(
      path: '/pension-fund-connect',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) =>
          FeatureFlags.enablePensionFundConnect ? null : '/',
      builder: (context, state) => const PensionFundConnectScreen(),
    ),
    GoRoute(path: '/advisor/plan-30-days', redirect: (_, __) => '/home'),
    GoRoute(path: '/advisor/wizard', redirect: (context, state) {
      final section = state.uri.queryParameters['section'];
      if (section == null || section.isEmpty) return '/onboarding/quick';
      return '/onboarding/quick?section=$section';
    }),
    GoRoute(path: '/coach/agir', redirect: (_, __) => '/home'),
    GoRoute(path: '/onboarding/smart', redirect: (_, __) => '/onboarding/quick'),
    GoRoute(path: '/onboarding/minimal', redirect: (_, __) => '/onboarding/quick'),
    GoRoute(path: '/onboarding/enrichment', redirect: (_, __) => '/profile/bilan'),
  ],
);

// ════════════════════════════════════════════════════════════
//  APP
// ════════════════════════════════════════════════════════════

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
    AnalyticsService().init();
    NotificationService().init();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // F5: Proactively refresh auth token on app resume to prevent
      // stale-token 401s on the first API call after backgrounding.
      ApiService.refreshTokenIfNeeded();
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
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
        ChangeNotifierProvider(create: (_) => HouseholdProvider()),
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
          final provider = UserActivityProvider();
          provider.loadAll();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) {
          final provider = SlmProvider();
          provider.init();
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
  final textTheme = GoogleFonts.interTextTheme(ThemeData.light().textTheme);

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: MintColors.background,
    colorScheme: const ColorScheme.light(
      primary: MintColors.primary,
      onPrimary: MintColors.white,
      secondary: MintColors.accent,
      onSecondary: MintColors.white,
      surface: MintColors.appleSurface,
      onSurface: MintColors.textPrimary,
      error: MintColors.error,
      outline: MintColors.border,
    ),
    textTheme: textTheme.copyWith(
      displayLarge: GoogleFonts.montserrat(
        textStyle: textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.5,
          color: MintColors.textPrimary,
        ),
      ),
      headlineLarge: GoogleFonts.montserrat(
        textStyle: textTheme.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: -1.0,
          color: MintColors.textPrimary,
        ),
      ),
      headlineMedium: GoogleFonts.montserrat(
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
      backgroundColor: MintColors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontFamily: 'Montserrat',
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
        foregroundColor: MintColors.white,
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

class _MintErrorScreen extends StatelessWidget {
  final Exception? error;
  const _MintErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Page introuvable'),
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.explore_off_outlined,
                  size: 64, color: MintColors.greyApple),
              const SizedBox(height: 24),
              const Text(
                'Cette page n\'existe pas ou a été déplacée.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: MintColors.textPrimary),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/home'),
                icon: const Icon(Icons.home_outlined),
                label: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
