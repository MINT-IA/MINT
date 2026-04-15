import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/router/route_scope.dart';
import 'package:mint_mobile/router/scoped_go_route.dart';
import 'package:mint_mobile/widgets/mint_shell.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:mint_mobile/screens/anonymous/anonymous_chat_screen.dart';
import 'package:mint_mobile/screens/auth/login_screen.dart';
import 'package:mint_mobile/screens/auth/register_screen.dart';
import 'package:mint_mobile/screens/auth/forgot_password_screen.dart';
import 'package:mint_mobile/screens/auth/verify_email_screen.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/screens/simulator_compound_screen.dart';
import 'package:mint_mobile/screens/simulator_leasing_screen.dart';
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
import 'package:mint_mobile/screens/consumer_credit_screen.dart';
import 'package:mint_mobile/screens/debt_risk_check_screen.dart';
// consent_dashboard_screen.dart DELETED (KILL-03, Phase 2)
import 'package:mint_mobile/theme/colors.dart';
// portfolio_screen.dart — zombie redirect (Plan 11-02)
// profile_screen.dart DELETED (KILL-04, Phase 2)
import 'package:mint_mobile/screens/profile/financial_summary_screen.dart';
import 'package:mint_mobile/screens/profile/privacy_control_screen.dart';
import 'package:mint_mobile/screens/profile/privacy_center_screen.dart';
// main_navigation_shell.dart DELETED (KILL-07, Phase 2)
import 'package:mint_mobile/screens/budget/budget_container_screen.dart';
import 'package:mint_mobile/screens/education/comprendre_hub_screen.dart';
import 'package:mint_mobile/screens/education/theme_detail_screen.dart';
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:mint_mobile/screens/disability/disability_insurance_screen.dart';
import 'package:mint_mobile/screens/disability/disability_self_employed_screen.dart';
import 'package:mint_mobile/screens/job_comparison_screen.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/screens/byok_settings_screen.dart';
import 'package:mint_mobile/screens/slm_settings_screen.dart';
import 'package:mint_mobile/screens/settings/langue_settings_screen.dart';
import 'package:mint_mobile/screens/about_screen.dart';
// ask_mint_screen.dart — zombie redirect (Plan 11-02)
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/screens/documents_screen.dart';
import 'package:mint_mobile/screens/document_detail_screen.dart';
import 'package:mint_mobile/screens/bank_import_screen.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/analytics_observer.dart';
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
// score_reveal_screen.dart — zombie redirect (Plan 11-02)
// coach_profile.dart — unused after score-reveal zombie (Plan 11-02)
// financial_fitness_service.dart — unused after score-reveal zombie (Plan 11-02)
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
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';
import 'package:mint_mobile/screens/coach/conversation_history_screen.dart';
// annual_refresh_screen.dart — zombie redirect (Plan 11-02)
// cockpit_detail_screen.dart — zombie redirect (Plan 11-02)
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
import 'package:mint_mobile/providers/user_activity_provider.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
// intent_screen.dart DELETED (KILL-01, Phase 2)
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
import 'package:mint_mobile/providers/anticipation_provider.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/screens/aujourdhui/aujourdhui_screen.dart';
import 'package:mint_mobile/providers/contextual_card_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/providers/coach_entry_payload_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/household/household_screen.dart';
import 'package:mint_mobile/screens/household/accept_invitation_screen.dart';
// achievements_screen.dart — zombie redirect (Plan 11-02)
import 'package:mint_mobile/screens/cantonal_benchmark_screen.dart';
// KILL-07: Explorer hub screen imports removed (Phase 2).
// Hub screen FILES preserved for Phase 3 chat-summoned drawers.
import 'package:mint_mobile/screens/explore/explorer_screen.dart';
import 'package:mint_mobile/screens/explore/explore_hub_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKeyHome = GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorKeyCoach = GlobalKey<NavigatorState>(debugLabel: 'shellCoach');
final _shellNavigatorKeyExplorer = GlobalKey<NavigatorState>(debugLabel: 'shellExplorer');

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

// Module-level GoRouter. The router rebuilds when `_authNotifier` ticks —
// see `_AuthRefreshNotifier` below. Without this listener, login/logout
// events change AuthProvider state but the router never re-evaluates the
// `redirect` callback, so the user stays stuck on the public scope after
// signing in (Gate 0 P0-1: "logged in but Explorer/Aujourd'hui still show
// 'Crée ton compte'"). The notifier is bridged to AuthProvider once the
// MultiProvider tree is built (see _bindRouterAuthListener below).
final _authNotifier = ChangeNotifier();

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: [AnalyticsRouteObserver()],
  initialLocation: '/',
  refreshListenable: _authNotifier,
  errorBuilder: (context, state) => _MintErrorScreen(error: state.error),
  redirect: (context, state) {
    // ── Scope-based auth guard ───────────────────────────────
    // Reads RouteScope from the matched ScopedGoRoute instead of
    // maintaining a manual prefix whitelist. Fail-closed: unknown
    // routes default to authenticated.
    final auth = context.read<AuthProvider>();
    final isLoggedIn = auth.isLoggedIn;
    final path = state.uri.path;

    // ── Parse /home?tab=N&intent=X query params ─────────────
    // Notifications emit /home?tab=1&intent=monthlyCheckIn etc.
    // Redirect to the correct tab route so the shell navigates properly.
    if (path == '/home') {
      final tab = state.uri.queryParameters['tab'];
      final intent = state.uri.queryParameters['intent'];
      if (tab == '1') {
        // Tab 1 = Coach — redirect to /coach/chat with intent as topic
        final query = intent != null ? '?topic=$intent' : '';
        return '/coach/chat$query';
      }
      if (tab == '2') {
        return '/explorer';
      }
      // tab=0 or no tab → stay on /home (Aujourd'hui)
    }

    // Determine scope from matched route (fail-closed default)
    final topRoute = state.topRoute;
    final scope = topRoute is ScopedGoRoute
        ? topRoute.scope
        : RouteScope.authenticated;

    switch (scope) {
      case RouteScope.public:
        // Always allowed — no auth check
        return null;

      case RouteScope.onboarding:
        // Onboarding routes are accessible without full auth;
        // no redirect needed here (onboarding completion check
        // is handled by individual screens).
        return null;

      case RouteScope.authenticated:
        // Require signed-in user; localAnonymous mode also passes
        // (users who skipped registration still access simulators).
        if (!isLoggedIn) {
          return '/auth/register?redirect=${Uri.encodeComponent(path)}';
        }
        return null;
    }
  },
  routes: [
    // ── Landing + Auth (public — no auth required) ─────────────
    ScopedGoRoute(
      path: '/',
      scope: RouteScope.public,
      builder: (context, state) => const LandingScreen(),
    ),
    ScopedGoRoute(
      path: '/auth/login',
      scope: RouteScope.public, // Auth flow
      builder: (context, state) => const LoginScreen(),
    ),
    ScopedGoRoute(
      path: '/auth/register',
      scope: RouteScope.public, // Auth flow
      builder: (context, state) => const RegisterScreen(),
    ),
    ScopedGoRoute(
      path: '/auth/forgot-password',
      scope: RouteScope.public, // Auth flow
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    ScopedGoRoute(
      path: '/auth/verify-email',
      scope: RouteScope.public, // Auth flow
      builder: (context, state) => const VerifyEmailScreen(),
    ),
    ScopedGoRoute(
      path: '/auth/verify',
      scope: RouteScope.public, // Magic link verification
      builder: (context, state) => _MagicLinkVerifyScreen(
        token: state.uri.queryParameters['token'],
      ),
    ),

    // ── Anonymous chat (public — outside shell, no tabs/drawer) ──
    ScopedGoRoute(
      path: '/anonymous/chat',
      scope: RouteScope.public,
      builder: (context, state) {
        final intent = state.uri.queryParameters['intent'];
        return AnonymousChatScreen(intent: intent);
      },
    ),

    // ── SHELL: 3-tab persistent navigation ───���─────���────────
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) => MintShell(
        navigationShell: navigationShell,
      ),
      branches: [
        // Tab 0: Aujourd'hui
        StatefulShellBranch(
          navigatorKey: _shellNavigatorKeyHome,
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) {
                final auth = context.watch<AuthProvider>();
                // NAV-02: Show loading while auth is resolving to avoid
                // flashing LandingScreen before checkAuth() completes.
                if (auth.isLoading) {
                  return const Scaffold(
                    backgroundColor: MintColors.warmWhite,
                    body: Center(
                      child: CircularProgressIndicator(
                        color: MintColors.success,
                      ),
                    ),
                  );
                }
                return auth.isLoggedIn
                    ? const AujourdhuiScreen()
                    : const LandingScreen();
              },
            ),
          ],
        ),
        // Tab 1: Coach
        StatefulShellBranch(
          navigatorKey: _shellNavigatorKeyCoach,
          routes: [
            ScopedGoRoute(
              path: '/coach/chat',
              scope: RouteScope.public,
              builder: (context, state) {
                final topic = state.uri.queryParameters['topic'];
                final conversationId = state.uri.queryParameters['conversationId'];
                // Build a CoachEntryPayload from the topic query param.
                // This replaces the old ?prompt= pattern with structured data.
                final CoachEntryPayload? entryPayload = topic != null
                    ? CoachEntryPayload(
                        source: CoachEntrySource.direct,
                        topic: topic,
                      )
                    : null;
                return CoachChatScreen(
                  entryPayload: entryPayload,
                  conversationId: conversationId,
                  isEmbeddedInTab: true,
                );
              },
            ),
          ],
        ),
        // Tab 2: Explorer
        StatefulShellBranch(
          navigatorKey: _shellNavigatorKeyExplorer,
          routes: [
            GoRoute(
              path: '/explore',
              builder: (context, state) => const ExplorerScreen(),
            ),
          ],
        ),
      ],
    ),

    // ── EXPLORER HUBS ───────────────────────────────────────
    ScopedGoRoute(
      path: '/explore/retraite',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Retraite & Prevoyance',
        entries: [
          HubEntry(icon: Icons.timeline, label: 'Projection retraite', route: '/retraite'),
          HubEntry(icon: Icons.compare_arrows, label: 'Rente vs Capital', route: '/rente-vs-capital'),
          HubEntry(icon: Icons.add_card, label: 'Rachat LPP', route: '/rachat-lpp'),
          HubEntry(icon: Icons.home_work, label: 'EPL (retrait pour logement)', route: '/epl'),
          HubEntry(icon: Icons.calendar_month, label: 'Sequence de decaissement', route: '/decaissement'),
          HubEntry(icon: Icons.account_balance_wallet, label: 'Libre passage', route: '/libre-passage'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/explore/famille',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Famille',
        entries: [
          HubEntry(icon: Icons.favorite, label: 'Mariage', subtitle: 'AVS, LPP, fiscalite couple', route: '/mariage'),
          HubEntry(icon: Icons.child_friendly, label: 'Naissance', subtitle: 'Allocations, conge, budget', route: '/naissance'),
          HubEntry(icon: Icons.people, label: 'Concubinage', subtitle: 'Risques vs mariage', route: '/concubinage'),
          HubEntry(icon: Icons.heart_broken, label: 'Divorce', subtitle: 'Partage LPP, AVS, pension', route: '/divorce'),
          HubEntry(icon: Icons.account_balance, label: 'Succession', subtitle: 'Droits, reserves, planning', route: '/succession'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/explore/travail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Travail & Statut',
        entries: [
          HubEntry(icon: Icons.school, label: 'Premier emploi', route: '/first-job'),
          HubEntry(icon: Icons.work_off, label: 'Chomage', route: '/unemployment'),
          HubEntry(icon: Icons.compare, label: 'Comparateur d\'emplois', route: '/simulator/job-comparison'),
          HubEntry(icon: Icons.business_center, label: 'Independant', route: '/segments/independant'),
          HubEntry(icon: Icons.flight_takeoff, label: 'Expatriation', route: '/expatriation'),
          HubEntry(icon: Icons.badge, label: 'Frontalier', route: '/segments/frontalier'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/explore/logement',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Logement',
        entries: [
          HubEntry(icon: Icons.house, label: 'Capacite hypothecaire', route: '/hypotheque'),
          HubEntry(icon: Icons.payments, label: 'Amortissement', route: '/mortgage/amortization'),
          HubEntry(icon: Icons.account_balance_wallet, label: 'EPL combine', route: '/mortgage/epl-combined'),
          HubEntry(icon: Icons.receipt, label: 'Valeur locative', route: '/mortgage/imputed-rental'),
          HubEntry(icon: Icons.swap_horiz, label: 'SARON vs fixe', route: '/mortgage/saron-vs-fixed'),
          HubEntry(icon: Icons.sell, label: 'Vente immobiliere', route: '/life-event/housing-sale'),
          HubEntry(icon: Icons.compare_arrows, label: 'Location vs propriete', route: '/arbitrage/location-vs-propriete'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/explore/fiscalite',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Fiscalite',
        entries: [
          HubEntry(icon: Icons.savings, label: 'Pilier 3a', route: '/pilier-3a'),
          HubEntry(icon: Icons.history, label: '3a retroactif', route: '/3a-retroactif'),
          HubEntry(icon: Icons.compare, label: 'Comparateur 3a', route: '/3a-deep/comparator'),
          HubEntry(icon: Icons.trending_up, label: 'Rendement reel 3a', route: '/3a-deep/real-return'),
          HubEntry(icon: Icons.view_timeline, label: 'Retrait echelonne 3a', route: '/3a-deep/staggered-withdrawal'),
          HubEntry(icon: Icons.map, label: 'Comparateur cantonal', route: '/fiscal'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/explore/patrimoine',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Patrimoine & Succession',
        entries: [
          HubEntry(icon: Icons.assessment, label: 'Bilan arbitrage', route: '/arbitrage/bilan'),
          HubEntry(icon: Icons.pie_chart, label: 'Allocation annuelle', route: '/arbitrage/allocation-annuelle'),
          HubEntry(icon: Icons.card_giftcard, label: 'Donation', route: '/life-event/donation'),
          HubEntry(icon: Icons.people, label: 'Deces d\'un proche', route: '/life-event/deces-proche'),
          HubEntry(icon: Icons.swap_vert, label: 'Demenagement cantonal', route: '/life-event/demenagement-cantonal'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/explore/sante',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Sante & Protection',
        entries: [
          HubEntry(icon: Icons.accessibility, label: 'Lacune invalidite', route: '/invalidite'),
          HubEntry(icon: Icons.shield, label: 'Assurance invalidite', route: '/disability/insurance'),
          HubEntry(icon: Icons.business, label: 'Invalidite independant', route: '/disability/self-employed'),
          HubEntry(icon: Icons.local_hospital, label: 'Franchise LAMal', route: '/assurances/lamal'),
          HubEntry(icon: Icons.verified_user, label: 'Check couverture', route: '/assurances/coverage'),
        ],
      ),
    ),

    // ── RETRAITE & PREVOYANCE ────────────────────────────────
    ScopedGoRoute(
      path: '/retraite',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RetirementDashboardScreen(),
    ),
    // Legacy redirects
    ScopedGoRoute(path: '/coach/dashboard', redirect: (_, __) => '/retraite'),
    ScopedGoRoute(path: '/retirement', redirect: (_, __) => '/retraite'),
    ScopedGoRoute(path: '/retirement/projection', redirect: (_, __) => '/retraite'),

    ScopedGoRoute(
      path: '/rente-vs-capital',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RenteVsCapitalScreen(),
    ),
    ScopedGoRoute(path: '/arbitrage/rente-vs-capital', redirect: (_, __) => '/rente-vs-capital'),
    ScopedGoRoute(path: '/simulator/rente-capital', redirect: (_, __) => '/rente-vs-capital'),

    ScopedGoRoute(
      path: '/rachat-lpp',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RachatEchelonneScreen(),
    ),
    ScopedGoRoute(path: '/lpp-deep/rachat', redirect: (_, __) => '/rachat-lpp'),
    ScopedGoRoute(path: '/arbitrage/rachat-vs-marche', redirect: (_, __) => '/rachat-lpp'),

    ScopedGoRoute(
      path: '/epl',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EplScreen(),
    ),
    ScopedGoRoute(path: '/lpp-deep/epl', redirect: (_, __) => '/epl'),

    ScopedGoRoute(
      path: '/decaissement',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OptimisationDecaissementScreen(),
    ),
    ScopedGoRoute(path: '/coach/decaissement', redirect: (_, __) => '/decaissement'),
    ScopedGoRoute(path: '/arbitrage/calendrier-retraits', redirect: (_, __) => '/decaissement'),

    // ── ZOMBIE REDIRECTS (301-style, keep for 2 releases) ──
    ScopedGoRoute(path: '/coach/cockpit', redirect: (_, __) => '/retraite'),
    // STAB-14 (07-04): Wire Spec V2 P4 archived. Redirect to coach chat.
    ScopedGoRoute(path: '/coach/checkin', redirect: (_, __) => '/coach/chat'),
    ScopedGoRoute(path: '/coach/refresh', redirect: (_, __) => '/home'),
    // KILL-05: /coach/chat moved into StatefulShellRoute (Tab 1: Coach)
    ScopedGoRoute(
      path: '/coach/history',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConversationHistoryScreen(),
    ),
    ScopedGoRoute(
      path: '/succession',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SuccessionPatrimoineScreen(),
    ),
    ScopedGoRoute(path: '/coach/succession', redirect: (_, __) => '/succession'),
    ScopedGoRoute(path: '/life-event/succession', redirect: (_, __) => '/succession'),

    ScopedGoRoute(
      path: '/libre-passage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LibrePassageScreen(),
    ),
    ScopedGoRoute(path: '/lpp-deep/libre-passage', redirect: (_, __) => '/libre-passage'),

    // ── FISCALITE ────────────────────────────────────────────
    ScopedGoRoute(
      path: '/pilier-3a',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const Simulator3aScreen(),
    ),
    ScopedGoRoute(path: '/simulator/3a', redirect: (_, __) => '/pilier-3a'),

    ScopedGoRoute(
      path: '/3a-deep/comparator',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ProviderComparatorScreen(),
    ),
    ScopedGoRoute(
      path: '/3a-deep/real-return',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RealReturnScreen(),
    ),
    ScopedGoRoute(
      path: '/3a-deep/staggered-withdrawal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const StaggeredWithdrawalScreen(),
    ),
    ScopedGoRoute(
      path: '/3a-retroactif',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const Retroactive3aScreen(),
    ),
    ScopedGoRoute(
      path: '/fiscal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FiscalComparatorScreen(),
    ),

    // ── IMMOBILIER ───────────────────────────────────────────
    ScopedGoRoute(
      path: '/hypotheque',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AffordabilityScreen(),
    ),
    ScopedGoRoute(path: '/mortgage/affordability', redirect: (_, __) => '/hypotheque'),

    ScopedGoRoute(
      path: '/mortgage/amortization',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AmortizationScreen(),
    ),
    ScopedGoRoute(
      path: '/mortgage/epl-combined',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EplCombinedScreen(),
    ),
    ScopedGoRoute(
      path: '/mortgage/imputed-rental',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ImputedRentalScreen(),
    ),
    ScopedGoRoute(
      path: '/mortgage/saron-vs-fixed',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SaronVsFixedScreen(),
    ),

    // ── BUDGET & DETTE ───────────────────────────────────────
    ScopedGoRoute(
      path: '/budget',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BudgetContainerScreen(),
    ),
    ScopedGoRoute(
      path: '/check/debt',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DebtRiskCheckScreen(),
    ),
    ScopedGoRoute(
      path: '/debt/ratio',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DebtRatioScreen(),
    ),
    ScopedGoRoute(
      path: '/debt/help',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const HelpResourcesScreen(),
    ),
    ScopedGoRoute(
      path: '/debt/repayment',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RepaymentScreen(),
    ),

    // ── FAMILLE ──────────────────────────────────────────────
    ScopedGoRoute(
      path: '/divorce',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DivorceSimulatorScreen(),
    ),
    ScopedGoRoute(path: '/life-event/divorce', redirect: (_, __) => '/divorce'),

    ScopedGoRoute(
      path: '/mariage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const MariageScreen(),
    ),
    ScopedGoRoute(
      path: '/naissance',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const NaissanceScreen(),
    ),
    ScopedGoRoute(
      path: '/concubinage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConcubinageScreen(),
    ),

    // ── EMPLOI & STATUT ──────────────────────────────────────
    ScopedGoRoute(
      path: '/unemployment',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const UnemploymentScreen(),
    ),
    ScopedGoRoute(
      path: '/first-job',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FirstJobScreen(),
    ),
    ScopedGoRoute(
      path: '/expatriation',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExpatScreen(),
    ),
    ScopedGoRoute(
      path: '/simulator/job-comparison',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const JobComparisonScreen(),
    ),

    // ── INDEPENDANTS ─────────────────────────────────────────
    ScopedGoRoute(
      path: '/segments/independant',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const IndependantScreen(),
    ),
    ScopedGoRoute(
      path: '/independants/avs',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AvsCotisationsScreen(),
    ),
    ScopedGoRoute(
      path: '/independants/ijm',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const IjmScreen(),
    ),
    ScopedGoRoute(
      path: '/independants/3a',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const Pillar3aIndepScreen(),
    ),
    ScopedGoRoute(
      path: '/independants/dividende-salaire',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DividendeVsSalaireScreen(),
    ),
    ScopedGoRoute(
      path: '/independants/lpp-volontaire',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LppVolontaireScreen(),
    ),

    // ── ASSURANCE & SANTE ────────────────────────────────────
    ScopedGoRoute(
      path: '/invalidite',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DisabilityGapScreen(),
    ),
    ScopedGoRoute(path: '/disability/gap', redirect: (_, __) => '/invalidite'),
    ScopedGoRoute(path: '/simulator/disability-gap', redirect: (_, __) => '/invalidite'),

    ScopedGoRoute(
      path: '/disability/insurance',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DisabilityInsuranceScreen(),
    ),
    ScopedGoRoute(
      path: '/disability/self-employed',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DisabilitySelfEmployedScreen(),
    ),
    ScopedGoRoute(
      path: '/assurances/lamal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LamalFranchiseScreen(),
    ),
    ScopedGoRoute(
      path: '/assurances/coverage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CoverageCheckScreen(),
    ),

    // ── DOCUMENTS & SCAN ─────────────────────────────────────
    ScopedGoRoute(
      path: '/scan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra;
        final initialType = extra is DocumentType ? extra : null;
        return DocumentScanScreen(initialType: initialType);
      },
    ),
    ScopedGoRoute(path: '/document-scan', redirect: (_, __) => '/scan'),

    ScopedGoRoute(
      path: '/scan/avs-guide',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AvsGuideScreen(),
    ),
    ScopedGoRoute(path: '/document-scan/avs-guide', redirect: (_, __) => '/scan/avs-guide'),
    ScopedGoRoute(
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
    ScopedGoRoute(
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

    ScopedGoRoute(
      path: '/documents',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DocumentsScreen(),
    ),
    ScopedGoRoute(
      path: '/documents/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return DocumentDetailScreen(documentId: id);
      },
    ),

    // ── COUPLE ────────────────────────────────────────────────
    ScopedGoRoute(
      path: '/couple',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const HouseholdScreen(),
    ),
    ScopedGoRoute(path: '/household', redirect: (_, __) => '/couple'),

    ScopedGoRoute(
      path: '/couple/accept',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return AcceptInvitationScreen(initialCode: code);
      },
    ),
    ScopedGoRoute(path: '/household/accept', redirect: (context, state) {
      final code = state.uri.queryParameters['code'];
      return code != null ? '/couple/accept?code=$code' : '/couple/accept';
    }),

    // ── RAPPORT & PROFIL ─────────────────────────────────────
    ScopedGoRoute(
      path: '/rapport',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        if (extra.isNotEmpty) {
          return FinancialReportScreenV2(wizardAnswers: extra);
        }
        // Fallback: load persisted wizard answers when navigating
        // back to /rapport without state.extra (e.g. deep link, back nav).
        return FutureBuilder<Map<String, dynamic>>(
          future: ReportPersistenceService.loadAnswers(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }
            return FinancialReportScreenV2(
              wizardAnswers: snapshot.data ?? {},
            );
          },
        );
      },
    ),
    ScopedGoRoute(path: '/report', redirect: (_, __) => '/rapport'),
    ScopedGoRoute(path: '/report/v2', redirect: (_, __) => '/rapport'),

    // KILL-04: ProfileScreen deleted (Phase 2). /profile redirects to /profile/bilan.
    // Sub-routes (byok, slm, bilan, privacy-control, admin) preserved.
    ScopedGoRoute(
      path: '/profile',
      redirect: (_, state) {
        // Only redirect if exact /profile match; sub-routes pass through
        if (state.uri.path == '/profile') return '/profile/bilan';
        return null;
      },
      routes: [
        ScopedGoRoute(
          path: 'admin-observability',
          redirect: (context, state) =>
              FeatureFlags.enableAdminScreens ? null : '/',
          builder: (context, state) => const AdminObservabilityScreen(),
        ),
        ScopedGoRoute(
          path: 'admin-analytics',
          redirect: (context, state) =>
              FeatureFlags.enableAdminScreens ? null : '/',
          builder: (context, state) => const AdminAnalyticsScreen(),
        ),
        // KILL-03: consent dashboard deleted (Phase 2). Route removed.
        ScopedGoRoute(
          path: 'byok',
          builder: (context, state) => const ByokSettingsScreen(),
        ),
        ScopedGoRoute(
          path: 'slm',
          builder: (context, state) => const SlmSettingsScreen(),
        ),
        ScopedGoRoute(
          path: 'bilan',
          builder: (context, state) => const FinancialSummaryScreen(),
        ),
        ScopedGoRoute(
          path: 'privacy-control',
          builder: (context, state) => const PrivacyControlScreen(),
        ),
        // v2.7 Phase 29 / PRIV-01 — granular consent receipts hub.
        ScopedGoRoute(
          path: 'privacy',
          builder: (context, state) => const PrivacyCenterScreen(),
        ),
      ],
    ),

    // ── SEGMENTS ─────────────────────────────────────────────
    ScopedGoRoute(
      path: '/segments/gender-gap',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const GenderGapScreen(),
    ),
    ScopedGoRoute(
      path: '/segments/frontalier',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const FrontalierScreen(),
    ),
    ScopedGoRoute(
      path: '/life-event/housing-sale',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const HousingSaleScreen(),
    ),
    ScopedGoRoute(
      path: '/life-event/donation',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DonationScreen(),
    ),
    ScopedGoRoute(
      path: '/life-event/deces-proche',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DecesProcheScreen(),
    ),
    ScopedGoRoute(
      path: '/life-event/demenagement-cantonal',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const DemenagementCantonalScreen(),
    ),

    // ── EDUCATION ────────────────────────────────────────────
    ScopedGoRoute(
      path: '/education/hub',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ComprendreHubScreen(),
    ),
    ScopedGoRoute(
      path: '/education/theme/:id',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ThemeDetailScreen(themeId: id);
      },
    ),

    // ── SIMULATEURS (accessibles directement) ────────────────
    ScopedGoRoute(
      path: '/simulator/compound',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SimulatorCompoundScreen(),
    ),
    ScopedGoRoute(
      path: '/simulator/leasing',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const SimulatorLeasingScreen(),
    ),
    ScopedGoRoute(
      path: '/simulator/credit',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConsumerCreditSimulatorScreen(),
    ),

    // ── ARBITRAGE (restants) ─────────────────────────────────
    ScopedGoRoute(
      path: '/arbitrage/bilan',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ArbitrageBilanScreen(),
    ),
    ScopedGoRoute(
      path: '/arbitrage/allocation-annuelle',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AllocationAnnuelleScreen(),
    ),
    ScopedGoRoute(
      path: '/arbitrage/location-vs-propriete',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LocationVsProprieteScreen(),
    ),

    ScopedGoRoute(path: '/achievements', redirect: (_, __) => '/home'),

    // STAB-14 (07-04): /weekly-recap was an orphan redirect-to-/home with zero
    // callers; deleted per AUDIT_ORPHAN_ROUTES row 90.

    // ── CANTONAL BENCHMARKS ──────────────────────────────────
    ScopedGoRoute(
      path: '/cantonal-benchmark',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const CantonalBenchmarkScreen(),
    ),

    // ── SETTINGS ────────────────────────────────────────────
    ScopedGoRoute(
      path: '/settings/langue',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LangueSettingsScreen(),
    ),

    // ── ABOUT (public) ─────────────────────────────────────────
    ScopedGoRoute(
      path: '/about',
      scope: RouteScope.public, // Legal/info page
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AboutScreen(),
    ),

    // ── OUTILS & DIVERS ─────────────────────────────────────
    ScopedGoRoute(path: '/ask-mint', redirect: (_, __) => '/coach/chat'),
    // STAB-14 (07-04): Wire Spec V2 P4 archived. Redirect to coach chat.
    ScopedGoRoute(path: '/tools', redirect: (_, __) => '/coach/chat'),
    ScopedGoRoute(path: '/portfolio', redirect: (_, __) => '/home'),
    ScopedGoRoute(
      path: '/timeline',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const TimelineScreen(),
    ),
    ScopedGoRoute(
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
    ScopedGoRoute(path: '/score-reveal', redirect: (_, __) => '/home'),

    // ── ONBOARDING ───────────────────────────────────────────
    // P10-02b: legacy onboarding screens removed. Routes kept as redirect
    // shims → /coach/chat so existing call sites keep working. The coach
    // chat surface handles missing query params gracefully.
    ScopedGoRoute(
      path: '/onboarding/quick',
      scope: RouteScope.onboarding, // Redirect shim — scope consistent with path
      redirect: (_, __) => '/coach/chat',
    ),
    ScopedGoRoute(
      path: '/onboarding/quick-start',
      scope: RouteScope.onboarding, // Redirect shim — scope consistent with path
      redirect: (_, __) => '/coach/chat',
    ),
    ScopedGoRoute(
      path: '/onboarding/premier-eclairage',
      scope: RouteScope.onboarding, // Redirect shim — scope consistent with path
      redirect: (_, __) => '/coach/chat',
    ),
    // KILL-01: intent_screen deleted. Redirect shim for deep links.
    ScopedGoRoute(
      path: '/onboarding/intent',
      scope: RouteScope.onboarding,
      redirect: (_, __) => '/coach/chat',
    ),
    ScopedGoRoute(
      path: '/onboarding/promise',
      scope: RouteScope.onboarding, // Redirect shim — scope consistent with path
      redirect: (_, __) => '/coach/chat',
    ),
    ScopedGoRoute(
      path: '/onboarding/plan',
      scope: RouteScope.onboarding, // Redirect shim — scope consistent with path
      redirect: (_, __) => '/coach/chat',
    ),
    ScopedGoRoute(
      path: '/data-block/:type',
      scope: RouteScope.onboarding, // Onboarding enrichment flow
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final type = state.pathParameters['type'] ?? 'revenu';
        return DataBlockEnrichmentScreen(blockType: type);
      },
    ),

    // ── OPEN BANKING (post-V1, FINMA gate) ───────────────────
    ScopedGoRoute(
      path: '/open-banking',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) =>
          FeatureFlags.enableOpenBanking ? null : '/',
      builder: (context, state) => const OpenBankingHubScreen(),
    ),
    ScopedGoRoute(
      path: '/open-banking/transactions',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) =>
          FeatureFlags.enableOpenBanking ? null : '/',
      builder: (context, state) => const TransactionListScreen(),
    ),
    ScopedGoRoute(
      path: '/open-banking/consents',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) =>
          FeatureFlags.enableOpenBanking ? null : '/',
      builder: (context, state) => const ConsentScreen(),
    ),
    ScopedGoRoute(
      path: '/bank-import',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BankImportScreen(),
    ),

    // ── LEGACY REDIRECTS (backwards compat) ──────────────────
    // NAV-AUDIT: all legacy routes now redirect directly to /coach/chat
    // (previously multi-hop via /home or /onboarding/quick — params were lost)
    ScopedGoRoute(path: '/advisor', redirect: (_, __) => '/coach/chat'),
    ScopedGoRoute(path: '/advisor/plan-30-days', redirect: (_, __) => '/coach/chat'),
    ScopedGoRoute(path: '/advisor/wizard', redirect: (context, state) {
      final section = state.uri.queryParameters['section'];
      if (section == null || section.isEmpty) return '/coach/chat';
      return '/coach/chat?topic=$section';
    }),
    ScopedGoRoute(path: '/coach/agir', redirect: (_, __) => '/coach/chat'),
    ScopedGoRoute(path: '/onboarding/smart', scope: RouteScope.onboarding, redirect: (_, __) => '/coach/chat'),
    ScopedGoRoute(path: '/onboarding/minimal', scope: RouteScope.onboarding, redirect: (_, __) => '/coach/chat'),
    ScopedGoRoute(path: '/onboarding/enrichment', scope: RouteScope.onboarding, redirect: (_, __) => '/profile/bilan'),
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
    NotificationService().init().then((_) => _consumeNotificationRoute());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Consume any pending notification deep link and navigate.
  ///
  /// Called after NotificationService.init() completes (cold-start tap)
  /// and on app resume (warm-start tap via didChangeAppLifecycleState).
  void _consumeNotificationRoute() {
    final route = NotificationService.consumePendingRoute();
    if (route != null && route.isNotEmpty) {
      // Wait for the first frame so GoRouter is mounted and ready.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _router.go(route);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check for notification taps that arrived while app was in background.
      _consumeNotificationRoute();
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
        ChangeNotifierProvider(create: (_) {
          final auth = AuthProvider();
          auth.checkAuth(); // AUTH-03: Restore JWT from SecureStorage on cold start
          return auth;
        }),
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
        ChangeNotifierProvider(create: (_) => BiographyProvider()),
        ChangeNotifierProvider(create: (_) => AnticipationProvider()),
        ChangeNotifierProvider(create: (_) => ContextualCardProvider()),
        // STAB-13 ROOT-B: 4 providers previously consumed by production
        // screens but registered only in test helpers (ProviderNotFoundException
        // masked by silent try/catch at consumer sites).
        ChangeNotifierProvider(create: (_) => MintStateProvider()),
        ChangeNotifierProvider(create: (_) => FinancialPlanProvider()),
        ChangeNotifierProvider(create: (_) => CoachEntryPayloadProvider()),
        ChangeNotifierProvider<TimelineProvider>(create: (_) => TimelineProvider()),
      ],
      child: _AuthRouterBridge(
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
      onPrimary: Colors.white,
      secondary: MintColors.accent,
      onSecondary: Colors.white,
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
      backgroundColor: Colors.white,
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

/// Deep link handler for magic link authentication.
/// Extracts token from URL, verifies it, and routes to onboarding or home.
class _MagicLinkVerifyScreen extends StatefulWidget {
  final String? token;
  const _MagicLinkVerifyScreen({this.token});

  @override
  State<_MagicLinkVerifyScreen> createState() => _MagicLinkVerifyScreenState();
}

class _MagicLinkVerifyScreenState extends State<_MagicLinkVerifyScreen> {
  bool _isVerifying = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _verifyToken();
  }

  Future<void> _verifyToken() async {
    if (widget.token == null || widget.token!.isEmpty) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Lien invalide';
      });
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.verifyMagicLink(widget.token!);

    if (!mounted) return;

    if (success) {
      // Post-auth routing: check onboarding status
      final completed =
          await ReportPersistenceService.isMiniOnboardingCompleted();
      if (!mounted) return;
      if (completed) {
        context.go('/coach/chat');
      } else {
        // NAV-AUDIT: welcome prompt triggers onboarding flow in coach
        context.go('/coach/chat?topic=onboarding');
      }
    } else {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Ce lien est invalide ou a expiré';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _isVerifying
              ? const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 24),
                    Text(
                      'Vérification en cours...',
                      style: TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 64, color: Colors.red),
                    const SizedBox(height: 24),
                    Text(
                      _errorMessage ?? 'Erreur de vérification',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 16, color: Colors.black87),
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => _verifyToken(),
                      child: const Text('Réessayer'),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/auth/login'),
                      child: const Text('Retour à la connexion'),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
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
                'Cette page n\'existe pas ou a été déplacée.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () => context.go('/coach/chat'),
                icon: const Icon(Icons.chat_outlined),
                label: const Text('Retour à l\'accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Bridge that subscribes to AuthProvider once and forwards every tick
/// to the router-bound `_authNotifier`. Without this, GoRouter's
/// `refreshListenable` never rebuilds redirect after login/logout
/// (Gate 0 P0-1).
class _AuthRouterBridge extends StatefulWidget {
  const _AuthRouterBridge({required this.child});
  final Widget child;

  @override
  State<_AuthRouterBridge> createState() => _AuthRouterBridgeState();
}

class _AuthRouterBridgeState extends State<_AuthRouterBridge> {
  AuthProvider? _bound;

  void _onAuthTick() {
    // Forward AuthProvider state changes to the router's listener so it
    // re-runs `redirect`. notifyListeners is safe here — we are not in
    // the middle of a build phase (the call originates from
    // AuthProvider.notifyListeners which is fired post-state-change).
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    _authNotifier.notifyListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (!identical(_bound, auth)) {
      _bound?.removeListener(_onAuthTick);
      auth.addListener(_onAuthTick);
      _bound = auth;
      // Tick once on bind so the router evaluates the initial auth state
      // (e.g. token already loaded from secure storage on cold start).
      _onAuthTick();
    }
  }

  @override
  void dispose() {
    _bound?.removeListener(_onAuthTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
