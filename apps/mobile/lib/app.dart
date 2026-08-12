import 'dart:async' show unawaited;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/services/preview_shell_policy.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/widgets/auth/migration_notice_listener.dart';
import 'package:mint_mobile/widgets/auth/account_handoff_choice_panel.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/router/archetype_route_gate.dart';
import 'package:mint_mobile/routes/coach_chat_entry_payload.dart';
import 'package:mint_mobile/router/route_scope.dart';
import 'package:mint_mobile/router/scoped_go_route.dart';
import 'package:mint_mobile/widgets/mint_shell.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:mint_mobile/providers/budget/budget_provider.dart';
import 'package:mint_mobile/providers/auth_provider.dart';
import 'package:mint_mobile/models/auth_lifecycle_state.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/screens/landing_screen.dart';
import 'package:mint_mobile/screens/coach/chat_as_verb_demo_screen.dart';
import 'package:mint_mobile/screens/debug/debug_budget_bootstrap_screen.dart';
import 'package:mint_mobile/screens/debug/debug_mint2_account_claim_screen.dart';
import 'package:mint_mobile/screens/debug/debug_profile_bootstrap_screen.dart';
import 'package:mint_mobile/screens/auth/login_screen.dart';
import 'package:mint_mobile/screens/auth/auth_redirect.dart';
import 'package:mint_mobile/services/debug_profile_bootstrap_service.dart';
import 'package:mint_mobile/screens/auth/register_screen.dart';
import 'package:mint_mobile/screens/auth/forgot_password_screen.dart';
import 'package:mint_mobile/screens/auth/verify_email_screen.dart';
import 'package:mint_mobile/services/account_handoff_service.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:mint_mobile/screens/simulator_compound_screen.dart';
import 'package:mint_mobile/screens/simulator_leasing_screen.dart';
import 'package:mint_mobile/screens/simulator_3a_screen.dart';
import 'package:mint_mobile/screens/consumer_credit_screen.dart';
import 'package:mint_mobile/screens/debt_risk_check_screen.dart';
// consent_dashboard_screen.dart DELETED (KILL-03, Phase 2)
// portfolio_screen.dart DELETED (deep-audit 2026-04-17) — route /portfolio still redirects to /home
// profile_screen.dart DELETED (KILL-04, Phase 2)
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/screens/profile/financial_summary_screen.dart';
import 'package:mint_mobile/screens/profile/privacy_control_screen.dart';
import 'package:mint_mobile/screens/profile/privacy_center_screen.dart';
// main_navigation_shell.dart DELETED (KILL-07, Phase 2)
import 'package:mint_mobile/screens/budget/budget_container_screen.dart';
import 'package:mint_mobile/screens/budget/budget_setup_screen.dart';
import 'package:mint_mobile/screens/education/comprendre_hub_screen.dart';
import 'package:mint_mobile/screens/education/theme_detail_screen.dart';
import 'package:mint_mobile/screens/disability/disability_gap_screen.dart';
import 'package:mint_mobile/screens/disability/disability_insurance_screen.dart';
import 'package:mint_mobile/screens/disability/disability_self_employed_screen.dart';
import 'package:mint_mobile/screens/job_comparison_screen.dart';
import 'package:mint_mobile/screens/divorce_simulator_screen.dart';
import 'package:mint_mobile/screens/byok_settings_screen.dart';
import 'package:mint_mobile/screens/slm_settings_screen.dart';
import 'package:mint_mobile/screens/settings/confidentialite_settings_screen.dart';
import 'package:mint_mobile/screens/settings/langue_settings_screen.dart';
import 'package:mint_mobile/screens/about_screen.dart';
// ask_mint_screen.dart DELETED (deep-audit 2026-04-17) — route /ask-mint redirects to /coach/chat
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/screens/documents_screen.dart';
import 'package:mint_mobile/screens/document_detail_screen.dart';
import 'package:mint_mobile/screens/bank_import_screen.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/analytics_observer.dart';
import 'package:mint_mobile/services/observability/private_route_telemetry.dart';
import 'package:mint_mobile/services/notification_service.dart';
import 'package:mint_mobile/services/notifications_wiring_service.dart';
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
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
// score_reveal_screen.dart DELETED (deep-audit 2026-04-17) — route /score-reveal redirects to /home
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
// annual_refresh_screen.dart + cockpit_detail_screen.dart DELETED (deep-audit 2026-04-17)
import 'package:mint_mobile/screens/waitlist/waitlist_args.dart';
import 'package:mint_mobile/screens/waitlist/waitlist_screen.dart';
import 'package:mint_mobile/providers/waitlist_provider.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/locale_provider.dart';
import 'package:mint_mobile/screens/onboarding/data_block_enrichment_screen.dart';
import 'package:mint_mobile/screens/onboarding/mvp_wedge/onboarding_shell_screen.dart';
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
import 'package:mint_mobile/providers/household_provider.dart';
import 'package:mint_mobile/providers/biography_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/screens/aujourdhui/aujourdhui_screen.dart';
import 'package:mint_mobile/routes/mint_next_3a_route_gate.dart';
import 'package:mint_mobile/screens/mint_next_3a/mint_next_3a_handoff_screen.dart';
import 'package:mint_mobile/screens/mint_next_domicile/mint_next_domicile_screen.dart';
import 'package:mint_mobile/screens/mint_next_etat_civil/mint_next_etat_civil_screen.dart';
import 'package:mint_mobile/screens/mint_next_lpp_affiliation/mint_next_lpp_affiliation_screen.dart';
import 'package:mint_mobile/screens/mint_next_revenu/mint_next_revenu_screen.dart';
import 'package:mint_mobile/screens/mint_next_versements_3a/mint_next_versements_3a_screen.dart';
import 'package:mint_mobile/screens/mint_next_vertical_3a/mint_next_vertical_3a_screen.dart';
import 'package:mint_mobile/screens/mint_next_housing/mint_next_housing_screen.dart';
import 'package:mint_mobile/screens/mon_argent/mon_argent_screen.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/providers/financial_plan_provider.dart';
import 'package:mint_mobile/providers/slm_provider.dart';
import 'package:mint_mobile/screens/household/household_screen.dart';
import 'package:mint_mobile/screens/household/accept_invitation_screen.dart';
// achievements_screen.dart DELETED (deep-audit 2026-04-17) — route /achievements redirects to /home
import 'package:mint_mobile/screens/cantonal_benchmark_screen.dart';
// KILL-07: Explorer hub screen imports removed (Phase 2).
// Hub screen FILES preserved for Phase 3 chat-summoned drawers.
import 'package:mint_mobile/screens/explore/explorer_screen.dart';
import 'package:mint_mobile/screens/explore/explore_hub_screen.dart';
// Phase 32 MAP-02b — dev-only admin schema viewer (tree-shaken when ENABLE_ADMIN=0).
import 'package:mint_mobile/screens/admin/admin_gate.dart';
import 'package:mint_mobile/screens/admin/admin_shell.dart';
import 'package:mint_mobile/screens/admin/mint_debug_spine_screen.dart';
import 'package:mint_mobile/screens/admin/mint_debug_tools_gate.dart';
import 'package:mint_mobile/screens/admin/routes_registry_screen.dart';
// Phase 32 MAP-05 — legacy redirect hit breadcrumb (wired at 43 call-sites below).
import 'package:mint_mobile/services/sentry_breadcrumbs.dart';
// Sub-phase 01.5 W02-T05 — R7 legacy-user flag-based grandfather migration.
import 'package:mint_mobile/services/profile_migration_service.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();
final _shellNavigatorKeyHome =
    GlobalKey<NavigatorState>(debugLabel: 'shellHome');
final _shellNavigatorKeyMonArgent =
    GlobalKey<NavigatorState>(debugLabel: 'shellMonArgent');
final _shellNavigatorKeyCoach =
    GlobalKey<NavigatorState>(debugLabel: 'shellCoach');
final _shellNavigatorKeyExplorer =
    GlobalKey<NavigatorState>(debugLabel: 'shellExplorer');

// ════════════════════════════════════════════════════════════
//  ROUTER — S49 Phase 2: Simplified navigation
// ════════════════════════════════════════════════════════════
//
//  Target: ~50 canonical routes + legacy redirects
//  Feature flags removed for production-ready screens.
//  OpenBanking + Admin flags preserved (post-V1 / dev-only).
//
//  Route naming convention:
//    /retraite, /retraite/rente-vs-capital, /rachat-lpp, /epl, /pilier-3a,
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

// OBS-05 (Phase 31-01) — SentryNavigatorObserver sits BESIDE the
// existing AnalyticsRouteObserver (not instead of it). Analytics
// pipeline keeps owning product events; SentryNavigatorObserver
// auto-emits `navigation` breadcrumbs (push/pop/replace) so every
// Sentry event gets a replay-independent route trail even when
// sessionSampleRate=0.0 in prod (D-01 Option C).
// Kept as a top-level `final` so `test/app_router_observers_test.dart`
// can assert the list contents via `testOnlyRootRouterObservers`
// without relying on @visibleForTesting getters on go_router
// internals.
//
// Phase 32 J0 Task 2 retroactive hotfix (2026-04-20):
// `setRouteNameAsTransaction: true` binds `scope.transaction` = current
// route path on every didPush/didPop/didReplace. Without this flag the
// SDK default is false (sentry_flutter 9.14.0
// sentry_navigator_observer.dart:82) and Sentry issues report
// `transaction = <file.dart in FunctionName>` instead of the route
// path. This broke Phase 32 CLI `./tools/mint-routes health` which
// queries `transaction:<path>` (D-07 contract) — empirically verified:
// mint-mobile project had 2 issues in 90d, neither with route-path
// transaction. Flipping the flag lets GoRouter's RouteSettings.name
// flow into scope.transaction via _setCurrentRouteNameAsTransaction.
// See .planning/phases/32-cartographier/32-VALIDATION.md §Risks Risk 1.
final List<NavigatorObserver> _routerObservers = [
  AnalyticsRouteObserver(),
  MintPrivateRouteSentryObserver(),
];

@visibleForTesting
String? accountLifecyclePublicEntryRedirect({
  required AuthLifecycleState lifecycle,
  required String path,
}) {
  if (!lifecycle.hasAccountSession) return null;
  if (!lifecycle.allowsMainNavigation) return null;
  if (path == '/' ||
      path == '/start' ||
      path == '/anonymous/chat' ||
      path == '/onboarding/quick' ||
      path == '/onboarding/quick-start' ||
      path == '/onboarding/premier-eclairage' ||
      path == '/onboarding/intent' ||
      path == '/onboarding/promise' ||
      path == '/onboarding/plan' ||
      path == '/onboarding/smart' ||
      path == '/onboarding/minimal' ||
      path == '/auth/login' ||
      path == '/auth/register') {
    return '/home';
  }
  return null;
}

@visibleForTesting
String? accountLifecycleAuthenticatedRedirect({
  required AuthLifecycleState lifecycle,
  required String path,
}) {
  if (lifecycle.allowsMainNavigation) return null;
  if (lifecycle.state == AuthLifecycleKind.signedInProfileMissing ||
      lifecycle.state == AuthLifecycleKind.signedInIncomplete) {
    return '/onb';
  }
  final encodedPath = Uri.encodeComponent(path);
  if (lifecycle.state == AuthLifecycleKind.sessionExpired ||
      lifecycle.state == AuthLifecycleKind.credentialRevoked) {
    return '/auth/login?redirect=$encodedPath';
  }
  return '/auth/register?redirect=$encodedPath';
}

bool _isMainShellPath(String path) {
  return path == '/home' ||
      path == '/mon-argent' ||
      path == '/coach' ||
      path.startsWith('/coach/') ||
      path == '/explore' ||
      path.startsWith('/explore/') ||
      path == '/profile' ||
      path.startsWith('/profile/');
}

bool _isProfileCorrectionPath(String path) {
  return path == '/onb' ||
      path.startsWith('/onb/') ||
      path.startsWith('/__e2e/') ||
      path == '/waitlist' ||
      path.startsWith('/waitlist/') ||
      path == '/auth/login' ||
      path == '/auth/register' ||
      path.startsWith('/auth/');
}

bool _allowsProfilelessProfileSurface({
  required AuthLifecycleState lifecycle,
  required String path,
}) {
  final isAllowedProfileSurface = path == '/profile/bilan' ||
      path == '/profile/privacy' ||
      path == '/profile/privacy-control';
  if (!isAllowedProfileSurface) return false;
  return (lifecycle.accessMode == AuthAccessMode.guestLocal &&
          lifecycle.allowsMainNavigation) ||
      lifecycle.state == AuthLifecycleKind.signedInProfileMissing;
}

bool _allowsProfilelessCoachSurface({
  required AuthLifecycleState lifecycle,
  required String path,
}) {
  if (path != '/coach/chat') return false;
  return lifecycle.accessMode == AuthAccessMode.guestLocal &&
      lifecycle.allowsMainNavigation;
}

String? _profileRequiredEntryRedirect({
  required AuthLifecycleState lifecycle,
  required String path,
  required CoachProfile? profile,
  required bool profileSettled,
}) {
  if (profile != null) return null;
  if (_isProfileCorrectionPath(path)) return null;
  if (_allowsProfilelessCoachSurface(lifecycle: lifecycle, path: path)) {
    return null;
  }
  if (_allowsProfilelessProfileSurface(lifecycle: lifecycle, path: path)) {
    return null;
  }

  final profileRequired = _isMainShellPath(path) ||
      lifecycle.state == AuthLifecycleKind.signedInProfileMissing ||
      lifecycle.state == AuthLifecycleKind.signedInIncomplete ||
      (path == '/' &&
          lifecycle.hasAccountSession &&
          lifecycle.allowsMainNavigation);
  if (!profileRequired) return null;

  if (!profileSettled) return path == '/' ? null : '/';
  return '/onb';
}

const Set<String> _publicRoutePathFallbacks = {
  '/',
  '/start',
  '/onb',
  '/auth/login',
  '/auth/register',
  '/auth/forgot-password',
  '/auth/verify-email',
  '/auth/verify',
  '/anonymous/chat',
  '/waitlist',
  '/legal/terms',
};

@visibleForTesting
RouteScope routeScopeForRedirect({
  required String path,
  required RouteBase? topRoute,
}) {
  if (topRoute is ScopedGoRoute) return topRoute.scope;
  if (_publicRoutePathFallbacks.contains(path)) return RouteScope.public;
  return RouteScope.authenticated;
}

@visibleForTesting
String? accountLifecycleAndArchetypeRedirect({
  required AuthLifecycleState lifecycle,
  required String location,
  required String path,
  required RouteBase? topRoute,
  required CoachProfile? profile,
  bool profileSettled = true,
}) {
  final archetypeRedirect = archetypeRedirectTarget(
    profile: profile,
    path: path,
  );
  if (archetypeRedirect != null) return archetypeRedirect;

  final profileRedirect = _profileRequiredEntryRedirect(
    lifecycle: lifecycle,
    path: path,
    profile: profile,
    profileSettled: profileSettled,
  );
  if (profileRedirect != null) return profileRedirect;

  final scope = routeScopeForRedirect(
    path: path,
    topRoute: topRoute,
  );

  switch (scope) {
    case RouteScope.public:
      // A restored account must not see the signed-out landing/auth funnel
      // on cold relaunch. Guest-local public entry remains allowed.
      if (profile == null) return null;
      return accountLifecyclePublicEntryRedirect(
        lifecycle: lifecycle,
        path: path,
      );

    case RouteScope.onboarding:
      // Onboarding routes are accessible without full auth; completion
      // is handled by the individual screens.
      return null;

    case RouteScope.authenticated:
      if (_allowsProfilelessProfileSurface(lifecycle: lifecycle, path: path)) {
        return null;
      }
      return accountLifecycleAuthenticatedRedirect(
        lifecycle: lifecycle,
        path: location,
      );
  }
}

final _router = GoRouter(
  navigatorKey: _rootNavigatorKey,
  observers: _routerObservers,
  initialLocation: '/',
  refreshListenable: _authNotifier,
  errorBuilder: (context, state) => _MintErrorScreen(error: state.error),
  redirect: (context, state) {
    // ── Scope-based auth guard ───────────────────────────────
    // Reads RouteScope from the matched ScopedGoRoute instead of
    // maintaining a manual prefix whitelist. Fail-closed: unknown
    // routes default to authenticated.
    final auth = context.read<AuthProvider>();
    final path = state.uri.path;

    // Gate 0 #2 (splash gate): while checkAuth() is still resolving
    // the JWT from SecureStorage, suppress ALL redirects. Each route
    // builder handles isLoading individually (CircularProgressIndicator).
    // Without this guard, the first redirect cycle sees isLoggedIn=false
    // and bounces to /auth/register — then checkAuth completes, fires
    // refreshListenable, and the user sees a flash of the auth screen.
    if (auth.isLoading) return null;

    // ── Coque préversion (bascule 1) : enforcement AU POINT DE
    // DESTINATION — toute route possédée par le coach ou l'explorer est
    // fail-closed ; les alias owner:system qui y redirigent héritent du
    // blocage via cette garde. Les params de coque interdits
    // (/home?screen=coach|explore) sont neutralisés au même point.
    final previewPolicy = PreviewShellPolicy.instance;
    if (previewPolicy.blocksRoute(path)) {
      return previewPolicy.forbiddenRouteRedirect;
    }
    final paramRedirect =
        previewPolicy.redirectForShellParams(state.uri.queryParameters);
    if (paramRedirect != null) return paramRedirect;

    // ── Parse /home?tab=N&intent=X&screen=S query params ────
    // Notifications emit /home?screen=coach&intent=monthlyCheckIn etc. The
    // `screen=` param (new 2026-04-17) is the forward-compatible semantic
    // discriminator and always wins over `tab=`, so re-indexing the shell
    // won't silently misroute future links.
    //
    // V11 shell indexing:
    //   0 = Aujourd'hui | 1 = Mon argent | 2 = Coach | 3 = Explorer
    //
    // Backward-compat matrix (tab=):
    //   V1 (pre-2026-03) was a 3-tab shell (0=Home, 1=Coach, 2=Dossier).
    //   V1 notifications always carried `intent=` → caught first.
    //   V1 shortcuts without intent are rare enough to accept the V11
    //   mapping (tab=1 → /mon-argent); users will simply land one tap
    //   away from their old target rather than on a crash.
    if (path == '/home') {
      final screen = state.uri.queryParameters['screen'];
      final tab = state.uri.queryParameters['tab'];
      final intent = state.uri.queryParameters['intent'];
      // Semantic routing wins over positional indexing.
      switch (screen) {
        case 'coach':
          final query = intent != null ? '?topic=$intent' : '';
          return '/coach/chat$query';
        case 'mon-argent':
        case 'money':
          return '/mon-argent';
        case 'explore':
          return '/explore';
        case 'dossier':
        case 'profile':
          return '/profile/bilan';
      }
      if (intent != null || tab == '2') {
        final query = intent != null ? '?topic=$intent' : '';
        return '/coach/chat$query';
      }
      if (tab == '1') return '/mon-argent';
      if (tab == '3') return '/explore';
      // tab=0 or no tab → stay on /home (Aujourd'hui)
    }

    final profileProvider = context.read<CoachProfileProvider>();
    return accountLifecycleAndArchetypeRedirect(
      lifecycle: auth.authLifecycle,
      location: state.uri.toString(),
      path: path,
      topRoute: state.topRoute,
      profile: profileProvider.profile,
      profileSettled: profileProvider.isLoaded &&
          !profileProvider.isLoading &&
          !profileProvider.isHydrating,
    );
  },
  routes: [
    // ── Landing + Auth (public — no auth required) ─────────────
    ScopedGoRoute(
      path: '/',
      scope: RouteScope.public,
      builder: (context, state) => const LandingScreen(),
    ),
    // Landing CTA target: chat-first anonymous cold-open is retired.
    // Keep /start as a public alias for old links, but route users into
    // the explicit first-experience onboarding flow instead.
    ScopedGoRoute(
      path: '/start',
      scope: RouteScope.public,
      redirect: (_, __) => '/onb',
    ),
    // MVP Wedge onboarding — storyboard v2 (2026-04-22). 9-step flow
    // with 4 intents + dossier densification + 3 N2 scenes + magic link.
    // Doctrine: .planning/mvp-wedge-onboarding-2026-04-21/STORYBOARD-FINAL-LOCKED.md
    ScopedGoRoute(
      path: '/onb',
      scope: RouteScope.public,
      builder: (context, state) => const OnboardingShellScreen(),
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

    // ── Retired anonymous chat entry (public alias) ─────────────
    // The old cold-open chat prompt is no longer a product surface. Keep
    // the path as a compatibility alias so deep links do not 404.
    ScopedGoRoute(
      path: '/anonymous/chat',
      scope: RouteScope.public,
      redirect: (_, __) => '/onb',
    ),
    // ── Sub-phase 01.5 W02-T03 — Hard-gate waitlist destination ──
    // Public scope: unauthenticated users coming through the onboarding
    // US-tax-person Q (Yes) or any non-calibrated archetype hit /waitlist
    // BEFORE any coach context is built (per coach_chat_screen gate at
    // Task 4). WaitlistArgs carries the archetype slug for the consent
    // payload (or null when archetype is unknown/not yet computable).
    //
    // Task 6 — onGateSuccess invokes CoachProfileProvider.clearAll()
    // AFTER waitlist submit succeeds (nLPD art. 6 minimization,
    // Security §6 Q5). The callback is read off the route's BuildContext
    // (rather than the WaitlistProvider's own context) so the provider
    // does NOT depend directly on CoachProfileProvider (no cyclic
    // import) and remains test-instantiable in isolation.
    ScopedGoRoute(
      path: '/waitlist',
      scope: RouteScope.public,
      builder: (context, state) {
        final args = state.extra is WaitlistArgs
            ? state.extra as WaitlistArgs
            : const WaitlistArgs();
        return ChangeNotifierProvider<WaitlistProvider>(
          create: (ctx) => WaitlistProvider(
            onGateSuccess: () => ctx.read<CoachProfileProvider>().clearAll(),
          ),
          child: WaitlistScreen(
            args: args,
            onCorrectProfile: () {
              final profileProvider = context.read<CoachProfileProvider>();
              unawaited(profileProvider.clearAll().then((_) {
                if (context.mounted) context.go('/onb');
              }));
            },
          ),
        );
      },
    ),
    // ── Chat-as-verb demo (Phase 96 W1 T4 wired surface) ─────────
    // Plan 96-01 T4 wired MintCardActionBar onto two example cards
    // (« Marge fiscale 2026 », « Coût hypothèque mensuel ») in
    // `chat_as_verb_demo_screen.dart`. Route registration was missed
    // in T4 (W14-pattern wiring gap surfaced during G2 sim walkthrough
    // 2026-05-11). Keep this surface available to debug/simulator
    // workflows, but never register it in release builds.
    if (!kReleaseMode)
      ScopedGoRoute(
        path: '/debug/chat-as-verb',
        scope: RouteScope.public,
        builder: (context, state) => const ChatAsVerbDemoScreen(),
      ),
    if (!kReleaseMode)
      ScopedGoRoute(
        path: '/__e2e/row23-independent-no-lpp-profile',
        scope: RouteScope.public,
        builder: (context, state) {
          final query = state.uri.queryParameters;
          if (query['scenario'] == 'mint2-axis-account-claim') {
            return DebugMint2AccountClaimScreen(
              key: ValueKey(state.uri.toString()),
              mode: query['claim'] ?? 'keep',
            );
          }
          final mode = query['mode'] == 'update-income'
              ? DebugProfileBootstrapMode.updateIncome
              : DebugProfileBootstrapMode.establish;
          return DebugProfileBootstrapScreen(
            key: ValueKey(state.uri.toString()),
            slug: query['slug'] ?? 'independent_no_lpp_income_reality',
            mode: mode,
            selfEmployedNetIncomeAnnual: double.tryParse(query['annual'] ?? ''),
            annual3aContribution: double.tryParse(query['planned3a'] ?? ''),
          );
        },
      ),
    if (!kReleaseMode)
      ScopedGoRoute(
        path: '/__e2e/budget-direct-inputs',
        scope: RouteScope.public,
        builder: (context, state) {
          final query = state.uri.queryParameters;
          return DebugBudgetBootstrapScreen(
            key: ValueKey(state.uri.toString()),
            netIncome: double.tryParse(query['net'] ?? '') ?? 0,
            housingCost: double.tryParse(query['housing'] ?? '') ?? 0,
            healthInsurance: double.tryParse(query['lamal'] ?? '') ?? 0,
            taxProvision: double.tryParse(query['tax'] ?? '') ?? 0,
            otherFixedCosts: double.tryParse(query['other'] ?? '') ?? 0,
            renderBudget: query['render'] == 'budget',
          );
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
                // Account lifecycle is the product gate: fresh visitors stay
                // on the landing/start flow, explicit guest mode and restored
                // accounts can enter the tab shell.
                return auth.authLifecycle.allowsMainNavigation
                    ? const AujourdhuiScreen()
                    : const LandingScreen();
              },
            ),
          ],
        ),
        // Tab 1: Mon argent — dashboard with 2 cards (budget + patrimoine).
        // Architecture A→B: PatrimoineAggregator + CoachWhisperService are
        // pure reads from CoachProfileProvider. Phase B will add a spending
        // synthesis card when Open Banking data lands.
        StatefulShellBranch(
          navigatorKey: _shellNavigatorKeyMonArgent,
          routes: [
            GoRoute(
              path: '/mon-argent',
              builder: (context, state) => MonArgentScreen(
                initialSection: state.uri.queryParameters['section'],
              ),
            ),
          ],
        ),
        // Tab 2: Coach
        StatefulShellBranch(
          navigatorKey: _shellNavigatorKeyCoach,
          routes: [
            ScopedGoRoute(
              path: '/coach/chat',
              scope: RouteScope.public,
              builder: (context, state) {
                final conversationId =
                    state.uri.queryParameters['conversationId'];
                final entryPayload = coachChatEntryPayloadFromQuery(
                  state.uri.queryParameters,
                );
                return CoachChatScreen(
                  key: ValueKey(state.uri.toString()),
                  entryPayload: entryPayload,
                  conversationId: conversationId,
                  isEmbeddedInTab: true,
                );
              },
            ),
          ],
        ),
        // Tab 3: Explorer
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
        title: 'Retraite & Prévoyance',
        entries: [
          HubEntry(
              icon: Icons.timeline,
              label: 'Projection retraite',
              route: '/retraite'),
          HubEntry(
              icon: Icons.compare_arrows,
              label: 'Rente vs Capital',
              route: '/retraite/rente-vs-capital'),
          HubEntry(
              icon: Icons.add_card, label: 'Rachat LPP', route: '/rachat-lpp'),
          HubEntry(
              icon: Icons.home_work,
              label: 'EPL (retrait pour logement)',
              route: '/epl'),
          HubEntry(
              icon: Icons.calendar_month,
              label: 'Séquence de décaissement',
              route: '/decaissement'),
          HubEntry(
              icon: Icons.account_balance_wallet,
              label: 'Libre passage',
              route: '/libre-passage'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/mint-next/housing',
      scope: RouteScope.public,
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (_, __) => FeatureFlags.enableMintNextHousing ? null : '/home',
      builder: (context, state) => const MintNextHousingScreen(),
    ),
    ScopedGoRoute(
      path: '/mint-next/3a',
      scope: RouteScope.public,
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (_, state) => mintNext3aRouteRedirect(
        flagEnabled: FeatureFlags.enableMintNext3aProductHandoff,
        extra: state.extra,
      ),
      builder: (context, state) => const MintNext3aHandoffScreen(),
    ),
    ScopedGoRoute(
      path: '/mint-next/domicile',
      scope: RouteScope.public,
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (_, __) => FeatureFlags.enableMintNextDomicile ? null : '/home',
      builder: (context, state) => const MintNextDomicileScreen(),
    ),
    ScopedGoRoute(
      path: '/mint-next/etat-civil',
      scope: RouteScope.public,
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (_, __) =>
          FeatureFlags.enableMintNextEtatCivil ? null : '/home',
      builder: (context, state) => const MintNextEtatCivilScreen(),
    ),
    ScopedGoRoute(
      path: '/mint-next/revenu',
      scope: RouteScope.public,
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (_, __) => FeatureFlags.enableMintNextRevenu ? null : '/home',
      builder: (context, state) => const MintNextRevenuScreen(),
    ),
    ScopedGoRoute(
      path: '/mint-next/lpp-affiliation',
      scope: RouteScope.public,
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (_, __) =>
          FeatureFlags.enableMintNextLppAffiliation ? null : '/home',
      builder: (context, state) => const MintNextLppAffiliationScreen(),
    ),
    ScopedGoRoute(
      path: '/mint-next/versements-3a',
      scope: RouteScope.public,
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (_, __) =>
          FeatureFlags.enableMintNextVersements3a ? null : '/home',
      builder: (context, state) => const MintNextVersements3aScreen(),
    ),
    ScopedGoRoute(
      path: '/mint-next/vertical-3a',
      scope: RouteScope.public,
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (_, __) =>
          FeatureFlags.enableMintNextVertical3a ? null : '/home',
      builder: (context, state) => const MintNextVertical3aScreen(),
    ),
    ScopedGoRoute(
      path: '/explore/famille',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Famille',
        entries: [
          HubEntry(
              icon: Icons.favorite,
              label: 'Mariage',
              subtitle: 'AVS, LPP, fiscalité couple',
              route: '/mariage'),
          HubEntry(
              icon: Icons.child_friendly,
              label: 'Naissance',
              subtitle: 'Allocations, congé, budget',
              route: '/naissance'),
          HubEntry(
              icon: Icons.people,
              label: 'Concubinage',
              subtitle: 'Risques vs mariage',
              route: '/concubinage'),
          HubEntry(
              icon: Icons.heart_broken,
              label: 'Divorce',
              subtitle: 'Partage LPP, AVS, pension',
              route: '/divorce'),
          HubEntry(
              icon: Icons.account_balance,
              label: 'Succession',
              subtitle: 'Droits, réserves, planning',
              route: '/succession'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/explore/travail',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Travail & Statut',
        entries: [
          HubEntry(
              icon: Icons.school, label: 'Premier emploi', route: '/first-job'),
          HubEntry(
              icon: Icons.work_off, label: 'Chômage', route: '/unemployment'),
          HubEntry(
              icon: Icons.compare,
              label: 'Comparateur d\'emplois',
              route: '/simulator/job-comparison'),
          HubEntry(
              icon: Icons.business_center,
              label: 'Indépendant',
              route: '/segments/independant'),
          HubEntry(
              icon: Icons.flight_takeoff,
              label: 'Expatriation',
              route: '/expatriation'),
          HubEntry(
              icon: Icons.badge,
              label: 'Frontalier',
              route: '/segments/frontalier'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/explore/logement',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Logement',
        entries: [
          HubEntry(
              icon: Icons.house,
              label: 'Capacité hypothécaire',
              route: '/hypotheque'),
          HubEntry(
              icon: Icons.payments,
              label: 'Amortissement',
              route: '/mortgage/amortization'),
          HubEntry(
              icon: Icons.account_balance_wallet,
              label: 'EPL combiné',
              route: '/mortgage/epl-combined'),
          HubEntry(
              icon: Icons.receipt,
              label: 'Valeur locative',
              route: '/mortgage/imputed-rental'),
          HubEntry(
              icon: Icons.swap_horiz,
              label: 'SARON vs fixe',
              route: '/mortgage/saron-vs-fixed'),
          HubEntry(
              icon: Icons.sell,
              label: 'Vente immobilière',
              route: '/life-event/housing-sale'),
          HubEntry(
              icon: Icons.compare_arrows,
              label: 'Location vs propriété',
              route: '/arbitrage/location-vs-propriete'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/explore/fiscalite',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Fiscalité',
        entries: [
          HubEntry(
              icon: Icons.savings, label: 'Pilier 3a', route: '/pilier-3a'),
          HubEntry(
              icon: Icons.history,
              label: '3a rétroactif',
              route: '/3a-retroactif'),
          HubEntry(
              icon: Icons.compare,
              label: 'Comparateur 3a',
              route: '/3a-deep/comparator'),
          HubEntry(
              icon: Icons.trending_up,
              label: 'Rendement réel 3a',
              route: '/3a-deep/real-return'),
          HubEntry(
              icon: Icons.view_timeline,
              label: 'Retrait échelonné 3a',
              route: '/3a-deep/staggered-withdrawal'),
          HubEntry(
              icon: Icons.map, label: 'Comparateur cantonal', route: '/fiscal'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/explore/patrimoine',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Patrimoine & Succession',
        entries: [
          HubEntry(
              icon: Icons.assessment,
              label: 'Bilan arbitrage',
              route: '/arbitrage/bilan'),
          HubEntry(
              icon: Icons.pie_chart,
              label: 'Allocation annuelle',
              route: '/arbitrage/allocation-annuelle'),
          HubEntry(
              icon: Icons.card_giftcard,
              label: 'Donation',
              route: '/life-event/donation'),
          HubEntry(
              icon: Icons.people,
              label: 'Décès d\'un proche',
              route: '/life-event/deces-proche'),
          HubEntry(
              icon: Icons.swap_vert,
              label: 'Déménagement cantonal',
              route: '/life-event/demenagement-cantonal'),
        ],
      ),
    ),
    ScopedGoRoute(
      path: '/explore/sante',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ExploreHubScreen(
        title: 'Santé & Protection',
        entries: [
          HubEntry(
              icon: Icons.accessibility,
              label: 'Lacune invalidité',
              route: '/invalidite'),
          HubEntry(
              icon: Icons.shield,
              label: 'Assurance invalidité',
              route: '/disability/insurance'),
          HubEntry(
              icon: Icons.business,
              label: 'Invalidité indépendant',
              route: '/disability/self-employed'),
          HubEntry(
              icon: Icons.local_hospital,
              label: 'Franchise LAMal',
              route: '/assurances/lamal'),
          HubEntry(
              icon: Icons.verified_user,
              label: 'Check couverture',
              route: '/assurances/coverage'),
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
    ScopedGoRoute(
        path: '/coach/dashboard',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/retraite');
          return '/retraite';
        }),
    ScopedGoRoute(
        path: '/retirement',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/retraite');
          return '/retraite';
        }),
    ScopedGoRoute(
        path: '/retirement/projection',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/retraite');
          return '/retraite';
        }),

    ScopedGoRoute(
      path: '/retraite/rente-vs-capital',
      scope: RouteScope.onboarding,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RenteVsCapitalScreen(),
    ),
    ScopedGoRoute(
      path: '/rente-vs-capital',
      scope: RouteScope.onboarding,
      redirect: (_, state) {
        MintBreadcrumbs.legacyRedirectHit(
            from: state.uri.path, to: '/retraite/rente-vs-capital');
        return '/retraite/rente-vs-capital';
      },
    ),
    ScopedGoRoute(
      path: '/arbitrage/rente-vs-capital',
      scope: RouteScope.onboarding,
      redirect: (_, state) {
        MintBreadcrumbs.legacyRedirectHit(
            from: state.uri.path, to: '/retraite/rente-vs-capital');
        return '/retraite/rente-vs-capital';
      },
    ),
    ScopedGoRoute(
      path: '/simulator/rente-capital',
      scope: RouteScope.onboarding,
      redirect: (_, state) {
        MintBreadcrumbs.legacyRedirectHit(
            from: state.uri.path, to: '/retraite/rente-vs-capital');
        return '/retraite/rente-vs-capital';
      },
    ),

    ScopedGoRoute(
      path: '/rachat-lpp',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const RachatEchelonneScreen(),
    ),
    ScopedGoRoute(
        path: '/lpp-deep/rachat',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/rachat-lpp');
          return '/rachat-lpp';
        }),
    ScopedGoRoute(
        path: '/arbitrage/rachat-vs-marche',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/rachat-lpp');
          return '/rachat-lpp';
        }),

    ScopedGoRoute(
      path: '/epl',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const EplScreen(),
    ),
    ScopedGoRoute(
        path: '/lpp-deep/epl',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/epl');
          return '/epl';
        }),

    ScopedGoRoute(
      path: '/decaissement',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const OptimisationDecaissementScreen(),
    ),
    ScopedGoRoute(
        path: '/coach/decaissement',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/decaissement');
          return '/decaissement';
        }),
    ScopedGoRoute(
        path: '/arbitrage/calendrier-retraits',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/decaissement');
          return '/decaissement';
        }),

    // ── ZOMBIE REDIRECTS (301-style, keep for 2 releases) ──
    ScopedGoRoute(
        path: '/coach/cockpit',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/retraite');
          return '/retraite';
        }),
    // STAB-14 (07-04): Wire Spec V2 P4 archived. Redirect to coach chat.
    ScopedGoRoute(
        path: '/coach/checkin',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/coach/chat');
          return '/coach/chat';
        }),
    ScopedGoRoute(
        path: '/coach/refresh',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/home');
          return '/home';
        }),
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
    ScopedGoRoute(
        path: '/coach/succession',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/succession');
          return '/succession';
        }),
    ScopedGoRoute(
        path: '/life-event/succession',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/succession');
          return '/succession';
        }),

    ScopedGoRoute(
      path: '/libre-passage',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const LibrePassageScreen(),
    ),
    ScopedGoRoute(
        path: '/lpp-deep/libre-passage',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/libre-passage');
          return '/libre-passage';
        }),

    // ── FISCALITE ────────────────────────────────────────────
    ScopedGoRoute(
      path: '/pilier-3a',
      scope: RouteScope.onboarding,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const Simulator3aScreen(),
    ),
    ScopedGoRoute(
        path: '/simulator/3a',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/pilier-3a');
          return '/pilier-3a';
        }),

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
      scope: RouteScope.onboarding,
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AffordabilityScreen(),
    ),
    ScopedGoRoute(
        path: '/mortgage/affordability',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/hypotheque');
          return '/hypotheque';
        }),

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
      builder: (context, state) => BudgetContainerScreen(
        routeExtra: state.extra,
      ),
    ),
    ScopedGoRoute(
      path: '/budget/setup',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const BudgetSetupScreen(),
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
    ScopedGoRoute(
        path: '/life-event/divorce',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/divorce');
          return '/divorce';
        }),

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
    ScopedGoRoute(
        path: '/disability/gap',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/invalidite');
          return '/invalidite';
        }),
    ScopedGoRoute(
        path: '/simulator/disability-gap',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/invalidite');
          return '/invalidite';
        }),

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
    ScopedGoRoute(
        path: '/document-scan',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/scan');
          return '/scan';
        }),

    ScopedGoRoute(
      path: '/scan/avs-guide',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AvsGuideScreen(),
    ),
    ScopedGoRoute(
        path: '/document-scan/avs-guide',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/scan/avs-guide');
          return '/scan/avs-guide';
        }),
    ScopedGoRoute(
      path: '/scan/review',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final result = state.extra as ExtractionResult?;
        if (result == null) {
          return Scaffold(
            body: Center(child: Text(S.of(context)!.documentNonDisponible)),
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
          return Scaffold(
            body: Center(child: Text(S.of(context)!.documentNonDisponible)),
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
    ScopedGoRoute(
        path: '/household',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/couple');
          return '/couple';
        }),

    ScopedGoRoute(
      path: '/couple/accept',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) {
        final code = state.uri.queryParameters['code'];
        return AcceptInvitationScreen(initialCode: code);
      },
    ),
    ScopedGoRoute(
        path: '/household/accept',
        redirect: (context, state) {
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
            final persistedAnswers = snapshot.data ?? {};
            final fallbackAnswers = persistedAnswers.isNotEmpty
                ? persistedAnswers
                : (CoachProfileSeeds.activeSeed?.toWizardAnswers() ?? {});
            return FinancialReportScreenV2(
              wizardAnswers: fallbackAnswers,
            );
          },
        );
      },
    ),
    ScopedGoRoute(
        path: '/report',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/rapport');
          return '/rapport';
        }),
    ScopedGoRoute(
        path: '/report/v2',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/rapport');
          return '/rapport';
        }),

    // KILL-04: ProfileScreen deleted (Phase 2). /profile redirects to /profile/bilan.
    // Sub-routes (byok, slm, bilan, privacy-control, admin) preserved.
    // Sentry MINT-MOBILE-6 (2026-05-20): without a parent builder, go_router 14+ crashes
    // sub-routes that touch GoRouterState (e.g. byok's context.push('/ask-mint')) with
    // "The parent route must be a page route". The SizedBox.shrink() below is the
    // page-route anchor — never actually rendered because the redirect above always fires
    // on exact /profile match.
    ScopedGoRoute(
      path: '/profile',
      redirect: (_, state) {
        // Only redirect if exact /profile match; sub-routes pass through
        if (state.uri.path == '/profile') return '/profile/bilan';
        return null;
      },
      builder: (_, __) => const SizedBox.shrink(),
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

    ScopedGoRoute(
        path: '/achievements',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/home');
          return '/home';
        }),

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
    ScopedGoRoute(
      path: '/settings/confidentialite',
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const ConfidentialiteSettingsScreen(),
    ),

    // ── ABOUT (public) ─────────────────────────────────────────
    ScopedGoRoute(
      path: '/about',
      scope: RouteScope.public, // Legal/info page
      parentNavigatorKey: _rootNavigatorKey,
      builder: (context, state) => const AboutScreen(),
    ),

    // ─────────── Phase 32 MAP-02b — /admin/routes (dev-only, tree-shaken) ───────────
    // Compile-time ENABLE_ADMIN=0 default -> Dart dead-code eliminates this branch
    // entirely (D-11 Task 1 empirically verifies via `strings Runner | grep`).
    if (AdminGate.isAvailable) ...[
      ScopedGoRoute(
        path: '/admin/routes',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminShell(
          child: RoutesRegistryScreen(),
        ),
      ),
      // Phase 33 adds /admin/flags here using the same AdminShell.
    ],
    if (MintDebugToolsGate.isAvailable) ...[
      ScopedGoRoute(
        path: '/admin/debug-spine',
        parentNavigatorKey: _rootNavigatorKey,
        builder: (context, state) => const AdminShell(
          child: MintDebugSpineScreen(),
        ),
      ),
    ],

    // ── OUTILS & DIVERS ─────────────────────────────────────
    ScopedGoRoute(
        path: '/ask-mint',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/coach/chat');
          return '/coach/chat';
        }),
    // STAB-14 (07-04): Wire Spec V2 P4 archived. Redirect to coach chat.
    ScopedGoRoute(
        path: '/tools',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/coach/chat');
          return '/coach/chat';
        }),
    ScopedGoRoute(
        path: '/portfolio',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/home');
          return '/home';
        }),
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
    ScopedGoRoute(
        path: '/score-reveal',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/home');
          return '/home';
        }),

    // ── ONBOARDING ───────────────────────────────────────────
    // P10-02b: legacy onboarding screens removed. Keep the routes as
    // compatibility shims, but route them back to the canonical first-entry
    // spine. A deleted onboarding deep link must not cold-open the Coach.
    ScopedGoRoute(
      path: '/onboarding/quick',
      scope:
          RouteScope.onboarding, // Redirect shim — scope consistent with path
      redirect: (_, state) {
        MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/onb');
        return '/onb';
      },
    ),
    ScopedGoRoute(
      path: '/onboarding/quick-start',
      scope:
          RouteScope.onboarding, // Redirect shim — scope consistent with path
      redirect: (_, state) {
        MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/onb');
        return '/onb';
      },
    ),
    ScopedGoRoute(
      path: '/onboarding/premier-eclairage',
      scope:
          RouteScope.onboarding, // Redirect shim — scope consistent with path
      redirect: (_, state) {
        MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/onb');
        return '/onb';
      },
    ),
    // KILL-01: intent_screen deleted. Redirect shim for deep links.
    ScopedGoRoute(
      path: '/onboarding/intent',
      scope: RouteScope.onboarding,
      redirect: (_, state) {
        MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/onb');
        return '/onb';
      },
    ),
    ScopedGoRoute(
      path: '/onboarding/promise',
      scope:
          RouteScope.onboarding, // Redirect shim — scope consistent with path
      redirect: (_, state) {
        MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/onb');
        return '/onb';
      },
    ),
    ScopedGoRoute(
      path: '/onboarding/plan',
      scope:
          RouteScope.onboarding, // Redirect shim — scope consistent with path
      redirect: (_, state) {
        MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/onb');
        return '/onb';
      },
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
      redirect: (context, state) => FeatureFlags.enableOpenBanking ? null : '/',
      builder: (context, state) => const OpenBankingHubScreen(),
    ),
    ScopedGoRoute(
      path: '/open-banking/transactions',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => FeatureFlags.enableOpenBanking ? null : '/',
      builder: (context, state) => const TransactionListScreen(),
    ),
    ScopedGoRoute(
      path: '/open-banking/consents',
      parentNavigatorKey: _rootNavigatorKey,
      redirect: (context, state) => FeatureFlags.enableOpenBanking ? null : '/',
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
    ScopedGoRoute(
        path: '/advisor',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/coach/chat');
          return '/coach/chat';
        }),
    ScopedGoRoute(
        path: '/advisor/plan-30-days',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/coach/chat');
          return '/coach/chat';
        }),
    ScopedGoRoute(
        path: '/advisor/wizard',
        redirect: (context, state) {
          final section = state.uri.queryParameters['section'];
          if (section == null || section.isEmpty) return '/coach/chat';
          return '/coach/chat?topic=$section';
        }),
    ScopedGoRoute(
        path: '/coach/agir',
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/coach/chat');
          return '/coach/chat';
        }),
    ScopedGoRoute(
        path: '/onboarding/smart',
        scope: RouteScope.onboarding,
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/onb');
          return '/onb';
        }),
    ScopedGoRoute(
        path: '/onboarding/minimal',
        scope: RouteScope.onboarding,
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/onb');
          return '/onb';
        }),
    ScopedGoRoute(
        path: '/onboarding/enrichment',
        scope: RouteScope.onboarding,
        redirect: (_, state) {
          MintBreadcrumbs.legacyRedirectHit(
              from: state.uri.path, to: '/profile/bilan');
          return '/profile/bilan';
        }),
  ],
);

/// Test-only accessor for the root GoRouter. Used by
/// `test/app_router_observers_test.dart` (Phase 31-01 OBS-05) to assert
/// that both AnalyticsRouteObserver and SentryNavigatorObserver are
/// wired to the observers: list. Do NOT use in production code.
@visibleForTesting
GoRouter get testOnlyRootRouter => _router;

@visibleForTesting
Widget testOnlyMagicLinkVerifyScreen({String? token}) =>
    _MagicLinkVerifyScreen(token: token);

/// Test-only accessor for the root GoRouter observers list. Used by
/// `test/app_router_observers_test.dart` (Phase 31-01 OBS-05).
@visibleForTesting
List<NavigatorObserver> get testOnlyRootRouterObservers => _routerObservers;

// ════════════════════════════════════════════════════════════
//  APP
// ════════════════════════════════════════════════════════════

class MintApp extends StatefulWidget {
  const MintApp({super.key});

  @override
  State<MintApp> createState() => _MintAppState();
}

Future<void> _refreshFeatureFlagsOnResume() =>
    FeatureFlags.refreshFromBackend();

@visibleForTesting
Future<void> debugRefreshFeatureFlagsOnResume() =>
    _refreshFeatureFlagsOnResume();

void handleMintAppResume(VoidCallback consumeNotificationRoute) {
  // refreshFromBackend closes the gate before returning its Future, so this
  // single production operation makes the navigation ordering indivisible.
  unawaited(_refreshFeatureFlagsOnResume());
  consumeNotificationRoute();
}

class MintNext3aLifecycleGate extends StatefulWidget {
  const MintNext3aLifecycleGate({required this.builder, super.key});

  final WidgetBuilder builder;

  @override
  State<MintNext3aLifecycleGate> createState() =>
      _MintNext3aLifecycleGateState();
}

class _MintNext3aLifecycleGateState extends State<MintNext3aLifecycleGate> {
  void _rebuildAfterMintNext3aGateChange() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    FeatureFlags.mintNext3aProductHandoffListenable
        .addListener(_rebuildAfterMintNext3aGateChange);
  }

  @override
  void dispose() {
    FeatureFlags.mintNext3aProductHandoffListenable
        .removeListener(_rebuildAfterMintNext3aGateChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
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
      handleMintAppResume(_consumeNotificationRoute);
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
    return MintNext3aLifecycleGate(builder: _buildApp);
  }

  Widget _buildApp(BuildContext context) {
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
        ChangeNotifierProxyProvider<AuthProvider, CoachProfileProvider>(
          lazy: false,
          create: (_) {
            final provider = CoachProfileProvider();
            // Sub-phase 01.5 W02-T05 Task 1 (R7) — flag-based legacy
            // grandfather migration. Chains the one-shot, idempotent
            // SharedPreferences write AFTER loadFromWizard so the
            // archetype-getter null-fallback (plan 02-01) does NOT
            // mass-evict cached users to /waitlist. Fire-and-forget:
            // failures are tolerated (the orchestrator's pre-archetype
            // guard re-reads the flag each session). Codex C1 HIGH
            // (REVIEWS.md 2026-05-22): the migration is flag-only —
            // it NEVER writes any value to `nationality`. See
            // profile_migration_service.dart class doc + the
            // `legacy_grandfathered_profile_nationality_remains_null`
            // regression test.
            provider.loadFromWizard().then((_) {
              ProfileMigrationService().grandfatherLegacyProfile(
                provider: provider,
              );
            });
            return provider;
          },
          update: (_, auth, provider) {
            final coachProvider = provider ?? CoachProfileProvider();
            if (auth.isLoggedIn && !auth.isLoading) {
              unawaited(coachProvider.reloadAfterAuthBackendHydration());
            }
            return coachProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) {
          final provider = LocaleProvider();
          provider.load();
          return provider;
        }),
        // Wave E-PRIME (2026-04-18): UserActivityProvider deleted — its 13
        // public methods (markSimulatorExplored, dismissTip, etc.) had 0
        // consumer. All call-sites use ReportPersistenceService directly.
        // Panel A P0-1.
        ChangeNotifierProvider(create: (_) {
          final provider = SlmProvider();
          provider.init();
          return provider;
        }),
        ChangeNotifierProvider(create: (_) => BiographyProvider()),
        // Wave E-PRIME (2026-04-18): AnticipationProvider + ContextualCardProvider
        // deleted — neither had a Consumer/context.watch/read. Panel A P0-2/P0-3.
        // Cascade: services/anticipation/ + widgets/alert/MintAlertHost also deleted.
        // STAB-13 ROOT-B: 4 providers previously consumed by production
        // screens but registered only in test helpers (ProviderNotFoundException
        // masked by silent try/catch at consumer sites).
        //
        // Wave B-minimal A2 (2026-04-18): convert MintStateProvider to a
        // ChangeNotifierProxyProvider<CoachProfileProvider, _>. The plain
        // ChangeNotifierProvider shipped before A2 never had a caller
        // invoking `.recompute(profile)`, so `state` stayed null in
        // production and every consumer (BudgetScreen line 107,
        // AujourdhuiScreen cap banner in B1) read null. The proxy
        // guarantees recompute fires on every CoachProfileProvider
        // notifyListeners (save_fact, scan enrichment, wizard load). The
        // recompute call itself is idempotent (guarded by `_lastProfile`
        // equality in mint_state_provider.dart:72).
        // Ref: panel archi review 2026-04-18 R1.
        ChangeNotifierProxyProvider<CoachProfileProvider, MintStateProvider>(
          create: (_) => MintStateProvider(),
          update: (_, profileProvider, mintState) {
            final provider = mintState ?? MintStateProvider();
            final profile = profileProvider.profile;
            if (profile != null) {
              // Fire-and-forget; recompute is guarded against concurrent
              // calls and no-ops when the profile is unchanged.
              provider.recompute(profile);
            } else {
              provider.clearIfProfileUnavailable();
            }
            return provider;
          },
        ),
        // Walker 2026-05-08 / Aujourdhui-wire fix: convert plain
        // ChangeNotifierProvider to ChangeNotifierProxyProvider so the
        // provider's lifecycle (loadFromPersistence + attachProfileProvider)
        // actually fires. The plain registration left both methods
        // permanently uncalled — the canonical façade-sans-câblage pattern
        // (CLAUDE.md NEVER #6). `lazy: false` is mandatory: nothing else
        // currently watches FinancialPlanProvider eagerly, so without it
        // create+update never run on cold start. Mirrors the
        // NotificationsWiringService pattern at line 1533.
        ChangeNotifierProxyProvider<CoachProfileProvider,
            FinancialPlanProvider>(
          lazy: false,
          create: (_) {
            final fpp = FinancialPlanProvider();
            // Fire-and-forget: hydrate any persisted plan from
            // SharedPreferences. Failures are tolerated — `currentPlan`
            // stays null and the home card is hidden until the user
            // generates a plan via coach.
            fpp.loadFromPersistence();
            return fpp;
          },
          update: (_, profileProvider, fpp) {
            final provider = fpp ?? FinancialPlanProvider();
            // attachProfileProvider is idempotent (guarded by
            // `_profileAttached` inside the provider) so calling it on
            // every update is safe and cheap.
            provider.attachProfileProvider(profileProvider);
            return provider;
          },
        ),
        // Wave E-PRIME (2026-04-18): CoachEntryPayloadProvider deleted —
        // setPayload/consumePayload had 0 caller in prod (docstring claimed
        // MintHomeScreen sets + MintCoachTab reads; neither exists).
        // Panel A P0-5.
        ChangeNotifierProvider<TimelineProvider>(
            create: (_) => TimelineProvider()),
        // Wave A-MINIMAL A2 (2026-04-18): notifications wiring listens
        // to CoachProfileProvider and reschedules coaching reminders
        // when the triad (birthYear + canton + salaireBrutMensuel)
        // transitions incomplete→complete or changes signature. The
        // previous wiring (`_markOnboardingCompletedIfNeeded` only)
        // fired once at onboarding intent and never re-fired when a
        // user completed the triad mid-conversation via save_fact.
        // Panel adversaire 2026-04-18 BUG 2+3 mitigation.
        //
        // A2-fix (2026-04-18): `lazy: false` is MANDATORY. Without it,
        // ChangeNotifierProxyProvider defers `create`/`update` until a
        // widget downstream calls `context.watch<NotificationsWiringService>()`.
        // No screen does — the service is purely reactive plumbing,
        // not a UI dependency. The 3-panel post-exec audit unanimously
        // flagged this as a P0 "façade sans câblage" that would ship
        // 100% dead code while all 7 unit tests passed. The `lazy: false`
        // flag materialises the service at MultiProvider mount time so
        // its `update` actually fires on every CoachProfileProvider
        // notifyListeners.
        ChangeNotifierProxyProvider<CoachProfileProvider,
            NotificationsWiringService>(
          lazy: false,
          create: (_) => NotificationsWiringService(),
          update: (_, profileProvider, wiring) {
            final service = wiring ?? NotificationsWiringService();
            service.onProfileChanged(profileProvider.profile);
            return service;
          },
        ),
      ],
      child: _AuthRouterBridge(
        child: MigrationNoticeListener(
          getMessenger: () => _scaffoldMessengerKey.currentState,
          getNavContext: () => _rootNavigatorKey.currentContext,
          onCtaTap: () => _router.go('/settings/confidentialite'),
          child: Builder(
            builder: (context) {
              final localeProvider = context.watch<LocaleProvider>();
              return MaterialApp.router(
                title: 'Mint',
                debugShowCheckedModeBanner: false,
                theme: _buildPremiumTheme(),
                darkTheme: buildDarkTheme(),
                themeMode: ThemeMode.light,
                routerConfig: _router,
                scaffoldMessengerKey: _scaffoldMessengerKey,
                localizationsDelegates: S.localizationsDelegates,
                supportedLocales: S.supportedLocales,
                locale: localeProvider.locale,
              );
            },
          ),
        ),
      ),
    );
  }
}

ThemeData _buildPremiumTheme() {
  // MVP-GOOGLEFONTS-PURGE-V1 (2026-05-10): swapped GoogleFonts.interTextTheme
  // + GoogleFonts.montserrat to bundled Supreme. Supreme is the MINT v2
  // canonical sans (declared in pubspec.yaml flutter.fonts). The base text
  // theme now applies fontFamily: 'Supreme' to all roles, and the override
  // helpers (displayLarge / headlineLarge / headlineMedium) reuse the same
  // bundled family.
  final baseLight = ThemeData.light().textTheme;
  final textTheme =
      baseLight.apply(fontFamily: 'Supreme'); // lint-ignore: prefer_mint_fonts

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
      displayLarge: textTheme.displayLarge?.copyWith(
        fontFamily: 'Supreme', // lint-ignore: prefer_mint_fonts
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        color: MintColors.textPrimary,
      ),
      headlineLarge: textTheme.headlineLarge?.copyWith(
        fontFamily: 'Supreme', // lint-ignore: prefer_mint_fonts
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        color: MintColors.textPrimary,
      ),
      headlineMedium: textTheme.headlineMedium?.copyWith(
        fontFamily: 'Supreme', // lint-ignore: prefer_mint_fonts
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        color: MintColors.textPrimary,
      ),
      titleLarge: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: MintColors.textPrimary,
      ),
      bodyLarge: textTheme.bodyLarge?.copyWith(
        color: MintColors.textPrimary,
        height: 1.5,
        fontSize: MintTextStyles.bodyLarge().fontSize,
      ),
      bodyMedium: textTheme.bodyMedium?.copyWith(
        color: MintColors.textSecondary,
        height: 1.4,
        fontSize: MintTextStyles.bodyMedium().fontSize,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: MintColors.card,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontWeight: FontWeight.w700,
        fontFamily: 'Supreme', // lint-ignore: prefer_mint_fonts
        color: MintColors.textPrimary,
        fontSize: MintTextStyles.headlineSmall().fontSize,
        letterSpacing: -0.5,
      ),
      iconTheme: const IconThemeData(color: MintColors.textPrimary, size: 22),
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
        textStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: MintTextStyles.bodyLarge().fontSize,
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
        textStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: MintTextStyles.bodyLarge().fontSize,
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

/// MINT v2 dark theme factory (Phase 92 FONT-04).
///
/// Token drop only — per-screen dark adoption deferred to MVP-DARK-MODE-V1.
/// Wired as `darkTheme:` on MaterialApp.router so the system dark mode
/// fallback path exists. Active rendering still gated by `themeMode:`
/// (currently ThemeMode.light — no behavior change in this phase per D-92.B).
ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: MintColors.darkBg,
    colorScheme: const ColorScheme.dark(
      primary: MintColors.darkMentheVive,
      onPrimary: MintColors.darkBg,
      secondary: MintColors.mentheVive,
      onSecondary: MintColors.darkBg,
      surface: MintColors.darkBg,
      onSurface: MintColors.darkInk,
      error: MintColors.error,
      outline: MintColors.darkBorderSubtle,
    ),
    dividerTheme: const DividerThemeData(
      color: MintColors.darkBorderSubtle,
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
  bool _requiresHandoffChoice = false;
  bool _didStartVerification = false;
  bool _verificationInFlight = false;
  String? _errorMessage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStartVerification) return;
    _didStartVerification = true;
    _verifyToken();
  }

  Future<void> _verifyToken() async {
    if (_verificationInFlight) return;
    _verificationInFlight = true;
    try {
      final l10n = S.of(context)!;
      if (!_isVerifying || _errorMessage != null || _requiresHandoffChoice) {
        setState(() {
          _isVerifying = true;
          _requiresHandoffChoice = false;
          _errorMessage = null;
        });
      }

      if (widget.token == null || widget.token!.isEmpty) {
        setState(() {
          _isVerifying = false;
          _requiresHandoffChoice = false;
          _errorMessage = l10n.authMagicLinkExpired;
        });
        return;
      }

      final authProvider = context.read<AuthProvider>();

      if (FeatureFlags.enableMvpWedgeOnboarding) {
        final hasSessionProfile =
            context.read<CoachProfileProvider>().hasProfile;
        final requiresChoice =
            await AccountHandoffService.requiresExplicitChoice(
          handoffEnabled: true,
          hasSessionProfile: hasSessionProfile,
        );
        if (requiresChoice) {
          if (!mounted) return;
          setState(() {
            _isVerifying = false;
            _requiresHandoffChoice = true;
            _errorMessage = l10n.authMagicLinkHandoffChoiceRequired;
          });
          return;
        }
      }

      final success = await authProvider.verifyMagicLink(widget.token!);

      if (!mounted) return;

      if (success) {
        // Post-auth routing: check onboarding status
        final localDateOfBirth =
            context.read<CoachProfileProvider>().profile?.dateOfBirth;
        final currentUri = GoRouterState.of(context).uri;
        final completed =
            await ReportPersistenceService.isMiniOnboardingCompleted();
        final hasDossierIdentity = await hasPostAuthDossierIdentity(
          localDateOfBirth: localDateOfBirth,
        );
        if (!mounted) return;
        context.go(resolvePostAuthDestination(
          currentUri: currentUri,
          hasDossierIdentity: hasDossierIdentity,
          fallback: completed ? '/coach/chat' : '/onb',
        ));
      } else {
        setState(() {
          _isVerifying = false;
          _requiresHandoffChoice = false;
          _errorMessage = l10n.authMagicLinkExpired;
        });
      }
    } finally {
      _verificationInFlight = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final body = _isVerifying
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Vérification en cours...',
                style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
              ),
            ],
          )
        : _requiresHandoffChoice
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.storage_outlined,
                    size: 64,
                    color: MintColors.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage ?? l10n.authMagicLinkHandoffChoiceRequired,
                    textAlign: TextAlign.center,
                    style:
                        MintTextStyles.bodyLarge(color: MintColors.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  AccountHandoffChoicePanel(
                    lockAfterChoice: true,
                    onChoiceChanged: _verifyToken,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    // lint-ignore: prefer_mint_cta
                    onPressed: () => context.go('/auth/login'),
                    child: Text(l10n.authBack),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 64,
                    color: MintColors.error,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _errorMessage ?? l10n.authMagicLinkExpired,
                    textAlign: TextAlign.center,
                    style:
                        MintTextStyles.bodyLarge(color: MintColors.textPrimary),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    // lint-ignore: prefer_mint_cta
                    onPressed: () => _verifyToken(),
                    child: Text(l10n.commonRetry),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    // lint-ignore: prefer_mint_cta
                    onPressed: () => context.go('/auth/login'),
                    child: Text(l10n.authBack),
                  ),
                ],
              );
    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: body,
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
        backgroundColor: MintColors.card,
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
                  size: 64, color: MintColors.textMuted),
              const SizedBox(height: 24),
              Text(
                'Cette page n\'existe pas ou a été déplacée.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: MintTextStyles.bodyLarge().fontSize,
                    color: Colors.black87),
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

/// Bridge that subscribes to AuthProvider AND CoachProfileProvider once and
/// forwards every tick to the router-bound `_authNotifier`. Without the
/// AuthProvider bridge, GoRouter's `refreshListenable` never rebuilds redirect
/// after login/logout (Gate 0 P0-1). Without the CoachProfileProvider bridge,
/// the GLOBAL archetype/FATCA gate (plan 08) added to `redirect` reads
/// `CoachProfileProvider.profile` but the router only refreshes on auth events
/// — so a persisted `expatUs` profile that hydrates asynchronously AFTER the
/// first route resolution (loadFromWizard → notifyListeners) lands on /home
/// (fail-open: profile==null at boot) and is NEVER redirected to /waitlist
/// until the next auth event or manual navigation (Codex P1, gap closure).
class _AuthRouterBridge extends StatefulWidget {
  const _AuthRouterBridge({required this.child});
  final Widget child;

  @override
  State<_AuthRouterBridge> createState() => _AuthRouterBridgeState();
}

class _AuthRouterBridgeState extends State<_AuthRouterBridge> {
  AuthProvider? _boundAuth;
  CoachProfileProvider? _boundProfile;

  void _onTick() {
    // Forward provider state changes to the router's listener so it re-runs
    // `redirect`. notifyListeners is safe here — we are not in the middle of a
    // build phase (the call originates from a provider's own notifyListeners
    // which is fired post-state-change).
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    _authNotifier.notifyListeners();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthProvider>();
    if (!identical(_boundAuth, auth)) {
      _boundAuth?.removeListener(_onTick);
      auth.addListener(_onTick);
      _boundAuth = auth;
      // Tick once on bind so the router evaluates the initial auth state
      // (e.g. token already loaded from secure storage on cold start).
      _onTick();
    }
    // Profile hydrates asynchronously after boot; the global FATCA gate in
    // `redirect` depends on it, so forward its ticks too (Codex P1).
    final profile = context.read<CoachProfileProvider>();
    if (!identical(_boundProfile, profile)) {
      _boundProfile?.removeListener(_onTick);
      profile.addListener(_onTick);
      _boundProfile = profile;
      _onTick();
    }
  }

  @override
  void dispose() {
    _boundAuth?.removeListener(_onTick);
    _boundProfile?.removeListener(_onTick);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// _MigrationNoticeListener (Phase 52 T-52-04) — extracted to
// `apps/mobile/lib/widgets/auth/migration_notice_listener.dart`
// for testability. The wrapper used at line ~1554 imports it.
