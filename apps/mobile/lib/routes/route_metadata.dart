// ────────────────────────────────────────────────────────────
//  RouteMeta + kRouteRegistry — Phase 32 MAP-01 (D-01 locked v4)
// ────────────────────────────────────────────────────────────
//
// Source of truth for the 147 mobile routes declared in
// `apps/mobile/lib/app.dart`. Consumed by:
//
//   - `tools/mint-routes` CLI (Python, Plan 32-02 Wave 2)
//   - `/admin/routes` Flutter schema viewer (Plan 32-03 Wave 3)
//   - `tools/checks/route_registry_parity.py` (Plan 32-04 Wave 4)
//
// Tree-shake contract (D-11 Task 1, validated in Plan 32-05 Wave 4 J0):
//   When `--dart-define=ENABLE_ADMIN=0` (prod default), the only runtime
//   consumer (`AdminShell`) is compile-time eliminated, detaching
//   `kRouteRegistry`. Empirical gate: `strings Runner | grep -c
//   kRouteRegistry` MUST return 0.
//
// Owner ambiguity rule (D-01 v4): first path segment wins. See
// `route_owner.dart` header for worked examples.

import 'route_category.dart';
import 'route_owner.dart';

/// Declarative metadata for a single GoRoute-matched path.
///
/// One `RouteMeta` per entry in [kRouteRegistry]. All fields are `final`
/// so instances are `const`-constructible (tree-shake precondition).
class RouteMeta {
  /// The GoRoute path string. MUST match the `path:` literal in
  /// `apps/mobile/lib/app.dart`. Nested child routes are stored as
  /// fully-composed paths (e.g. `/profile/bilan` — not just `bilan`).
  final String path;

  /// Taxonomy slot. See [RouteCategory].
  final RouteCategory category;

  /// Ownership bucket. See [RouteOwner] and the first-segment-wins rule.
  final RouteOwner owner;

  /// Whether navigating here requires a logged-in session. Mirrors the
  /// route's `RouteScope` in `app.dart`:
  ///   `RouteScope.public` / `RouteScope.onboarding` -> `false`
  ///   `RouteScope.authenticated` (default)          -> `true`
  ///
  /// Anonymous-local-mode users are handled orthogonally by
  /// `AuthProvider.isLocalMode`; this flag is the declarative baseline.
  final bool requiresAuth;

  /// Optional kill-flag name. When non-null, references a
  /// `FeatureFlags.<name>` field consumed by Phase 33 FLAG-01
  /// `requireFlag()` middleware to gate access at runtime.
  final String? killFlag;

  /// Optional dev-only description. Tree-shake contract (D-11 Task 1)
  /// requires this string to NOT ship to production binaries — never
  /// read from non-admin code paths.
  final String? description;

  /// Optional Sentry `transaction.name` override. When null, CLI
  /// queries (`tools/mint-routes`) use [path] verbatim — the Sentry
  /// Flutter SDK auto-sets `transaction.name` to the route path via
  /// `SentryNavigatorObserver` (Phase 31, `app.dart:184`).
  final String? sentryTag;

  const RouteMeta({
    required this.path,
    required this.category,
    required this.owner,
    required this.requiresAuth,
    this.killFlag,
    this.description,
    this.sentryTag,
  });
}

/// Source-of-truth map: one entry per `GoRoute`/`ScopedGoRoute` declared
/// in `apps/mobile/lib/app.dart`. Exactly **147 entries** as of Wave 0
/// reconciliation (app.dart SHA b7a88cc8, see
/// `.planning/phases/32-cartographier/32-00-RECONCILE-REPORT.md`).
///
/// **Maintenance contract (D-04, D-12):** adding or removing a `GoRoute`
/// / `ScopedGoRoute` in `app.dart` MUST be mirrored here. Parity lint
/// `tools/checks/route_registry_parity.py` fails CI on drift.
///
/// **Kill-flag contract (Phase 33 FLAG-05):** 11 flag-group owners map
/// 1:1 onto forward-referenced `FeatureFlags.<name>` fields Phase 33
/// will land. Names used here as strings (no symbol imports):
///
/// | owner      | killFlag                  |
/// |------------|---------------------------|
/// | coach      | enableCoachChat           |
/// | scan       | enableScan                |
/// | budget     | enableBudget              |
/// | anonymous  | enableAnonymousFlow       |
/// | retraite   | enableExplorerRetraite    |
/// | famille    | enableExplorerFamille     |
/// | travail    | enableExplorerTravail     |
/// | logement   | enableExplorerLogement    |
/// | fiscalite  | enableExplorerFiscalite   |
/// | patrimoine | enableExplorerPatrimoine  |
/// | sante      | enableExplorerSante       |
///
/// Infra owners (`auth`, `admin`, `system`, `explore`) carry no kill-flag
/// — they are always reachable. Owners whose first path segment is not
/// a locked enum value (e.g. `/debt/*`, `/mortgage/*`, `/arbitrage/*`)
/// fall back to `RouteOwner.system` per Task 2 action block.
///
/// **Owner ambiguity rule (D-01 v4):** first path segment wins.
///   `/explore/retraite` -> `explore`  (NOT `retraite`)
///   `/retraite`         -> `retraite` (standalone hub)
///   `/coach/...`        -> `coach`    (including `/coach/chat`, redirects)
const Map<String, RouteMeta> kRouteRegistry = <String, RouteMeta>{
  // ── Root / landing (public) ────────────────────────────────────
  '/': RouteMeta(
    path: '/',
    category: RouteCategory.destination,
    owner: RouteOwner.anonymous,
    requiresAuth: false,
    killFlag: 'enableAnonymousFlow',
    description: 'LandingScreen — first-run entry',
  ),
  '/onb': RouteMeta(
    path: '/onb',
    category: RouteCategory.destination,
    owner: RouteOwner.anonymous,
    requiresAuth: false,
    killFlag: 'enableMvpWedgeOnboarding',
    description: 'MVP wedge onboarding — 7-screen dossier-densification flow',
  ),

  // ── Auth flows (public) ────────────────────────────────────────
  '/auth/login': RouteMeta(
    path: '/auth/login',
    category: RouteCategory.flow,
    owner: RouteOwner.auth,
    requiresAuth: false,
  ),
  '/auth/register': RouteMeta(
    path: '/auth/register',
    category: RouteCategory.flow,
    owner: RouteOwner.auth,
    requiresAuth: false,
  ),
  '/auth/forgot-password': RouteMeta(
    path: '/auth/forgot-password',
    category: RouteCategory.flow,
    owner: RouteOwner.auth,
    requiresAuth: false,
  ),
  '/auth/verify-email': RouteMeta(
    path: '/auth/verify-email',
    category: RouteCategory.flow,
    owner: RouteOwner.auth,
    requiresAuth: false,
  ),
  '/auth/verify': RouteMeta(
    path: '/auth/verify',
    category: RouteCategory.flow,
    owner: RouteOwner.auth,
    requiresAuth: false,
    description: 'Magic-link verification landing',
  ),

  // ── Anonymous chat (public, outside shell) ─────────────────────
  '/anonymous/chat': RouteMeta(
    path: '/anonymous/chat',
    category: RouteCategory.destination,
    owner: RouteOwner.anonymous,
    requiresAuth: false,
    killFlag: 'enableAnonymousFlow',
  ),

  // ── Shell tabs ─────────────────────────────────────────────────
  '/home': RouteMeta(
    path: '/home',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: "Tab 0 — Aujourd'hui",
  ),
  '/mon-argent': RouteMeta(
    path: '/mon-argent',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Tab 1 — Mon argent dashboard',
  ),
  '/coach/chat': RouteMeta(
    path: '/coach/chat',
    category: RouteCategory.destination,
    owner: RouteOwner.coach,
    requiresAuth: false,
    killFlag: 'enableCoachChat',
    description: 'Tab 2 — Coach chat (public, shell-embedded)',
  ),
  '/explore': RouteMeta(
    path: '/explore',
    category: RouteCategory.destination,
    owner: RouteOwner.explore,
    requiresAuth: true,
    description: 'Tab 3 — Explorer root',
  ),

  // ── Explorer hubs (D-01 v4: first-segment wins, owner=explore) ─
  '/explore/retraite': RouteMeta(
    path: '/explore/retraite',
    category: RouteCategory.destination,
    owner: RouteOwner.explore,
    requiresAuth: true,
    killFlag: 'enableExplorerRetraite',
    description: 'Retirement domain hub under Explorer',
  ),
  '/explore/famille': RouteMeta(
    path: '/explore/famille',
    category: RouteCategory.destination,
    owner: RouteOwner.explore,
    requiresAuth: true,
    killFlag: 'enableExplorerFamille',
  ),
  '/explore/travail': RouteMeta(
    path: '/explore/travail',
    category: RouteCategory.destination,
    owner: RouteOwner.explore,
    requiresAuth: true,
    killFlag: 'enableExplorerTravail',
  ),
  '/explore/logement': RouteMeta(
    path: '/explore/logement',
    category: RouteCategory.destination,
    owner: RouteOwner.explore,
    requiresAuth: true,
    killFlag: 'enableExplorerLogement',
  ),
  '/explore/fiscalite': RouteMeta(
    path: '/explore/fiscalite',
    category: RouteCategory.destination,
    owner: RouteOwner.explore,
    requiresAuth: true,
    killFlag: 'enableExplorerFiscalite',
  ),
  '/explore/patrimoine': RouteMeta(
    path: '/explore/patrimoine',
    category: RouteCategory.destination,
    owner: RouteOwner.explore,
    requiresAuth: true,
    killFlag: 'enableExplorerPatrimoine',
  ),
  '/explore/sante': RouteMeta(
    path: '/explore/sante',
    category: RouteCategory.destination,
    owner: RouteOwner.explore,
    requiresAuth: true,
    killFlag: 'enableExplorerSante',
  ),

  // ── Retraite & prevoyance (standalone hubs + legacy aliases) ───
  '/retraite': RouteMeta(
    path: '/retraite',
    category: RouteCategory.destination,
    owner: RouteOwner.retraite,
    requiresAuth: true,
    killFlag: 'enableExplorerRetraite',
    description: 'Retirement scenarios standalone hub',
  ),
  '/coach/dashboard': RouteMeta(
    path: '/coach/dashboard',
    category: RouteCategory.alias,
    owner: RouteOwner.coach,
    requiresAuth: true,
    description: 'Legacy redirect -> /retraite',
  ),
  '/retirement': RouteMeta(
    path: '/retirement',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /retraite',
  ),
  '/retirement/projection': RouteMeta(
    path: '/retirement/projection',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /retraite',
  ),
  '/rente-vs-capital': RouteMeta(
    path: '/rente-vs-capital',
    category: RouteCategory.destination,
    owner: RouteOwner.retraite,
    requiresAuth: true,
    killFlag: 'enableExplorerRetraite',
  ),
  '/arbitrage/rente-vs-capital': RouteMeta(
    path: '/arbitrage/rente-vs-capital',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /rente-vs-capital',
  ),
  '/simulator/rente-capital': RouteMeta(
    path: '/simulator/rente-capital',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /rente-vs-capital',
  ),
  '/rachat-lpp': RouteMeta(
    path: '/rachat-lpp',
    category: RouteCategory.destination,
    owner: RouteOwner.retraite,
    requiresAuth: true,
    killFlag: 'enableExplorerRetraite',
  ),
  '/lpp-deep/rachat': RouteMeta(
    path: '/lpp-deep/rachat',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /rachat-lpp',
  ),
  '/arbitrage/rachat-vs-marche': RouteMeta(
    path: '/arbitrage/rachat-vs-marche',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /rachat-lpp',
  ),
  '/epl': RouteMeta(
    path: '/epl',
    category: RouteCategory.destination,
    owner: RouteOwner.retraite,
    requiresAuth: true,
    killFlag: 'enableExplorerRetraite',
  ),
  '/lpp-deep/epl': RouteMeta(
    path: '/lpp-deep/epl',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /epl',
  ),
  '/decaissement': RouteMeta(
    path: '/decaissement',
    category: RouteCategory.destination,
    owner: RouteOwner.retraite,
    requiresAuth: true,
    killFlag: 'enableExplorerRetraite',
  ),
  '/coach/decaissement': RouteMeta(
    path: '/coach/decaissement',
    category: RouteCategory.alias,
    owner: RouteOwner.coach,
    requiresAuth: true,
    description: 'Legacy redirect -> /decaissement',
  ),
  '/arbitrage/calendrier-retraits': RouteMeta(
    path: '/arbitrage/calendrier-retraits',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /decaissement',
  ),
  '/coach/cockpit': RouteMeta(
    path: '/coach/cockpit',
    category: RouteCategory.alias,
    owner: RouteOwner.coach,
    requiresAuth: true,
    description: 'Zombie redirect -> /retraite',
  ),
  '/coach/checkin': RouteMeta(
    path: '/coach/checkin',
    category: RouteCategory.alias,
    owner: RouteOwner.coach,
    requiresAuth: true,
    description: 'Zombie redirect -> /coach/chat',
  ),
  '/coach/refresh': RouteMeta(
    path: '/coach/refresh',
    category: RouteCategory.alias,
    owner: RouteOwner.coach,
    requiresAuth: true,
    description: 'Zombie redirect -> /home',
  ),
  '/coach/history': RouteMeta(
    path: '/coach/history',
    category: RouteCategory.destination,
    owner: RouteOwner.coach,
    requiresAuth: true,
    killFlag: 'enableCoachChat',
  ),
  '/succession': RouteMeta(
    path: '/succession',
    category: RouteCategory.destination,
    owner: RouteOwner.patrimoine,
    requiresAuth: true,
    killFlag: 'enableExplorerPatrimoine',
  ),
  '/coach/succession': RouteMeta(
    path: '/coach/succession',
    category: RouteCategory.alias,
    owner: RouteOwner.coach,
    requiresAuth: true,
    description: 'Legacy redirect -> /succession',
  ),
  '/life-event/succession': RouteMeta(
    path: '/life-event/succession',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /succession',
  ),
  '/libre-passage': RouteMeta(
    path: '/libre-passage',
    category: RouteCategory.destination,
    owner: RouteOwner.retraite,
    requiresAuth: true,
    killFlag: 'enableExplorerRetraite',
  ),
  '/lpp-deep/libre-passage': RouteMeta(
    path: '/lpp-deep/libre-passage',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /libre-passage',
  ),

  // ── Fiscalite ──────────────────────────────────────────────────
  '/pilier-3a': RouteMeta(
    path: '/pilier-3a',
    category: RouteCategory.destination,
    owner: RouteOwner.fiscalite,
    requiresAuth: true,
    killFlag: 'enableExplorerFiscalite',
  ),
  '/simulator/3a': RouteMeta(
    path: '/simulator/3a',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /pilier-3a',
  ),
  '/3a-deep/comparator': RouteMeta(
    path: '/3a-deep/comparator',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: '3a provider comparator (falls under system per D-01)',
  ),
  '/3a-deep/real-return': RouteMeta(
    path: '/3a-deep/real-return',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/3a-deep/staggered-withdrawal': RouteMeta(
    path: '/3a-deep/staggered-withdrawal',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/3a-retroactif': RouteMeta(
    path: '/3a-retroactif',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/fiscal': RouteMeta(
    path: '/fiscal',
    category: RouteCategory.destination,
    owner: RouteOwner.fiscalite,
    requiresAuth: true,
    killFlag: 'enableExplorerFiscalite',
    description: 'Cantonal tax comparator',
  ),

  // ── Immobilier ─────────────────────────────────────────────────
  '/hypotheque': RouteMeta(
    path: '/hypotheque',
    category: RouteCategory.destination,
    owner: RouteOwner.logement,
    requiresAuth: true,
    killFlag: 'enableExplorerLogement',
  ),
  '/mortgage/affordability': RouteMeta(
    path: '/mortgage/affordability',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /hypotheque',
  ),
  '/mortgage/amortization': RouteMeta(
    path: '/mortgage/amortization',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/mortgage/epl-combined': RouteMeta(
    path: '/mortgage/epl-combined',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/mortgage/imputed-rental': RouteMeta(
    path: '/mortgage/imputed-rental',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/mortgage/saron-vs-fixed': RouteMeta(
    path: '/mortgage/saron-vs-fixed',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── Budget & dette ─────────────────────────────────────────────
  '/budget': RouteMeta(
    path: '/budget',
    category: RouteCategory.destination,
    owner: RouteOwner.budget,
    requiresAuth: true,
    killFlag: 'enableBudget',
  ),
  '/budget/setup': RouteMeta(
    path: '/budget/setup',
    category: RouteCategory.destination,
    owner: RouteOwner.budget,
    requiresAuth: true,
    killFlag: 'enableBudget',
    description: 'Structured fixed-charges setup form — MVP P0-MVP-3',
  ),
  '/check/debt': RouteMeta(
    path: '/check/debt',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Debt risk check — owner=system (first segment /check)',
  ),
  '/debt/ratio': RouteMeta(
    path: '/debt/ratio',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/debt/help': RouteMeta(
    path: '/debt/help',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/debt/repayment': RouteMeta(
    path: '/debt/repayment',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── Famille ────────────────────────────────────────────────────
  '/divorce': RouteMeta(
    path: '/divorce',
    category: RouteCategory.destination,
    owner: RouteOwner.famille,
    requiresAuth: true,
    killFlag: 'enableExplorerFamille',
  ),
  '/life-event/divorce': RouteMeta(
    path: '/life-event/divorce',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /divorce',
  ),
  '/mariage': RouteMeta(
    path: '/mariage',
    category: RouteCategory.destination,
    owner: RouteOwner.famille,
    requiresAuth: true,
    killFlag: 'enableExplorerFamille',
  ),
  '/naissance': RouteMeta(
    path: '/naissance',
    category: RouteCategory.destination,
    owner: RouteOwner.famille,
    requiresAuth: true,
    killFlag: 'enableExplorerFamille',
  ),
  '/concubinage': RouteMeta(
    path: '/concubinage',
    category: RouteCategory.destination,
    owner: RouteOwner.famille,
    requiresAuth: true,
    killFlag: 'enableExplorerFamille',
  ),

  // ── Emploi & statut ────────────────────────────────────────────
  '/unemployment': RouteMeta(
    path: '/unemployment',
    category: RouteCategory.destination,
    owner: RouteOwner.travail,
    requiresAuth: true,
    killFlag: 'enableExplorerTravail',
  ),
  '/first-job': RouteMeta(
    path: '/first-job',
    category: RouteCategory.destination,
    owner: RouteOwner.travail,
    requiresAuth: true,
    killFlag: 'enableExplorerTravail',
  ),
  '/expatriation': RouteMeta(
    path: '/expatriation',
    category: RouteCategory.destination,
    owner: RouteOwner.travail,
    requiresAuth: true,
    killFlag: 'enableExplorerTravail',
  ),
  '/simulator/job-comparison': RouteMeta(
    path: '/simulator/job-comparison',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── Independants ──────────────────────────────────────────────
  '/segments/independant': RouteMeta(
    path: '/segments/independant',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/independants/avs': RouteMeta(
    path: '/independants/avs',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/independants/ijm': RouteMeta(
    path: '/independants/ijm',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/independants/3a': RouteMeta(
    path: '/independants/3a',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/independants/dividende-salaire': RouteMeta(
    path: '/independants/dividende-salaire',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/independants/lpp-volontaire': RouteMeta(
    path: '/independants/lpp-volontaire',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── Assurance & sante ─────────────────────────────────────────
  '/invalidite': RouteMeta(
    path: '/invalidite',
    category: RouteCategory.destination,
    owner: RouteOwner.sante,
    requiresAuth: true,
    killFlag: 'enableExplorerSante',
  ),
  '/disability/gap': RouteMeta(
    path: '/disability/gap',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /invalidite',
  ),
  '/simulator/disability-gap': RouteMeta(
    path: '/simulator/disability-gap',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /invalidite',
  ),
  '/disability/insurance': RouteMeta(
    path: '/disability/insurance',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/disability/self-employed': RouteMeta(
    path: '/disability/self-employed',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/assurances/lamal': RouteMeta(
    path: '/assurances/lamal',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/assurances/coverage': RouteMeta(
    path: '/assurances/coverage',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── Documents & scan ──────────────────────────────────────────
  '/scan': RouteMeta(
    path: '/scan',
    category: RouteCategory.flow,
    owner: RouteOwner.scan,
    requiresAuth: true,
    killFlag: 'enableScan',
  ),
  '/document-scan': RouteMeta(
    path: '/document-scan',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /scan',
  ),
  '/scan/avs-guide': RouteMeta(
    path: '/scan/avs-guide',
    category: RouteCategory.flow,
    owner: RouteOwner.scan,
    requiresAuth: true,
    killFlag: 'enableScan',
  ),
  '/document-scan/avs-guide': RouteMeta(
    path: '/document-scan/avs-guide',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /scan/avs-guide',
  ),
  '/scan/review': RouteMeta(
    path: '/scan/review',
    category: RouteCategory.flow,
    owner: RouteOwner.scan,
    requiresAuth: true,
    killFlag: 'enableScan',
  ),
  '/scan/impact': RouteMeta(
    path: '/scan/impact',
    category: RouteCategory.flow,
    owner: RouteOwner.scan,
    requiresAuth: true,
    killFlag: 'enableScan',
  ),
  '/documents': RouteMeta(
    path: '/documents',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/documents/:id': RouteMeta(
    path: '/documents/:id',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Single-document detail (dynamic :id)',
  ),

  // ── Couple ─────────────────────────────────────────────────────
  '/couple': RouteMeta(
    path: '/couple',
    category: RouteCategory.destination,
    owner: RouteOwner.famille,
    requiresAuth: true,
    killFlag: 'enableExplorerFamille',
  ),
  '/household': RouteMeta(
    path: '/household',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /couple',
  ),
  '/couple/accept': RouteMeta(
    path: '/couple/accept',
    category: RouteCategory.flow,
    owner: RouteOwner.famille,
    requiresAuth: true,
    killFlag: 'enableExplorerFamille',
    description: 'Partner invitation accept flow',
  ),
  '/household/accept': RouteMeta(
    path: '/household/accept',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect (param-passing) -> /couple/accept',
  ),

  // ── Rapport & profil ───────────────────────────────────────────
  '/rapport': RouteMeta(
    path: '/rapport',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Financial report v2 — owner=system (no first-segment match)',
  ),
  '/report': RouteMeta(
    path: '/report',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /rapport',
  ),
  '/report/v2': RouteMeta(
    path: '/report/v2',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /rapport',
  ),
  '/profile': RouteMeta(
    path: '/profile',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Exact-match redirect -> /profile/bilan (sub-routes pass through)',
  ),
  // Nested profile children (composed paths per CONTEXT v4 D-04)
  '/profile/admin-observability': RouteMeta(
    path: '/profile/admin-observability',
    category: RouteCategory.tool,
    owner: RouteOwner.admin,
    requiresAuth: true,
    description: 'Admin observability screen (FeatureFlags.enableAdminScreens gate)',
  ),
  '/profile/admin-analytics': RouteMeta(
    path: '/profile/admin-analytics',
    category: RouteCategory.tool,
    owner: RouteOwner.admin,
    requiresAuth: true,
    description: 'Admin analytics screen (FeatureFlags.enableAdminScreens gate)',
  ),
  '/profile/byok': RouteMeta(
    path: '/profile/byok',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Bring-your-own-key settings',
  ),
  '/profile/slm': RouteMeta(
    path: '/profile/slm',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'SLM settings',
  ),
  '/profile/bilan': RouteMeta(
    path: '/profile/bilan',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Financial summary bilan',
  ),
  '/profile/privacy-control': RouteMeta(
    path: '/profile/privacy-control',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/profile/privacy': RouteMeta(
    path: '/profile/privacy',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Granular consent receipts hub (PRIV-01)',
  ),

  // ── Segments ───────────────────────────────────────────────────
  '/segments/gender-gap': RouteMeta(
    path: '/segments/gender-gap',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/segments/frontalier': RouteMeta(
    path: '/segments/frontalier',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── Life events ────────────────────────────────────────────────
  '/life-event/housing-sale': RouteMeta(
    path: '/life-event/housing-sale',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/life-event/donation': RouteMeta(
    path: '/life-event/donation',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/life-event/deces-proche': RouteMeta(
    path: '/life-event/deces-proche',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/life-event/demenagement-cantonal': RouteMeta(
    path: '/life-event/demenagement-cantonal',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── Education ──────────────────────────────────────────────────
  '/education/hub': RouteMeta(
    path: '/education/hub',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/education/theme/:id': RouteMeta(
    path: '/education/theme/:id',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Theme detail (dynamic :id)',
  ),

  // ── Simulateurs (directs) ──────────────────────────────────────
  '/simulator/compound': RouteMeta(
    path: '/simulator/compound',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/simulator/leasing': RouteMeta(
    path: '/simulator/leasing',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/simulator/credit': RouteMeta(
    path: '/simulator/credit',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── Arbitrage (restants) ───────────────────────────────────────
  '/arbitrage/bilan': RouteMeta(
    path: '/arbitrage/bilan',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/arbitrage/allocation-annuelle': RouteMeta(
    path: '/arbitrage/allocation-annuelle',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/arbitrage/location-vs-propriete': RouteMeta(
    path: '/arbitrage/location-vs-propriete',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── Achievements (zombie redirect) ─────────────────────────────
  '/achievements': RouteMeta(
    path: '/achievements',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Zombie redirect -> /home',
  ),

  // ── Cantonal benchmark ─────────────────────────────────────────
  '/cantonal-benchmark': RouteMeta(
    path: '/cantonal-benchmark',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── Settings ───────────────────────────────────────────────────
  '/settings/langue': RouteMeta(
    path: '/settings/langue',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── About (public) ─────────────────────────────────────────────
  '/about': RouteMeta(
    path: '/about',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: false,
    description: 'Legal/info page — public',
  ),

  // ── Outils & divers ────────────────────────────────────────────
  '/ask-mint': RouteMeta(
    path: '/ask-mint',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /coach/chat',
  ),
  '/tools': RouteMeta(
    path: '/tools',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /coach/chat',
  ),
  '/portfolio': RouteMeta(
    path: '/portfolio',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Zombie redirect -> /home',
  ),
  '/timeline': RouteMeta(
    path: '/timeline',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/confidence': RouteMeta(
    path: '/confidence',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/score-reveal': RouteMeta(
    path: '/score-reveal',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Zombie redirect -> /home',
  ),

  // ── Onboarding (redirect shims, scope=onboarding) ──────────────
  '/onboarding/quick': RouteMeta(
    path: '/onboarding/quick',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: false,
    description: 'Onboarding shim -> /coach/chat',
  ),
  '/onboarding/quick-start': RouteMeta(
    path: '/onboarding/quick-start',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: false,
    description: 'Onboarding shim -> /coach/chat',
  ),
  '/onboarding/premier-eclairage': RouteMeta(
    path: '/onboarding/premier-eclairage',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: false,
    description: 'Onboarding shim -> /coach/chat',
  ),
  '/onboarding/intent': RouteMeta(
    path: '/onboarding/intent',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: false,
    description: 'Onboarding shim -> /coach/chat (KILL-01)',
  ),
  '/onboarding/promise': RouteMeta(
    path: '/onboarding/promise',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: false,
    description: 'Onboarding shim -> /coach/chat',
  ),
  '/onboarding/plan': RouteMeta(
    path: '/onboarding/plan',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: false,
    description: 'Onboarding shim -> /coach/chat',
  ),
  '/data-block/:type': RouteMeta(
    path: '/data-block/:type',
    category: RouteCategory.flow,
    owner: RouteOwner.system,
    requiresAuth: false,
    description: 'Onboarding enrichment flow (dynamic :type)',
  ),

  // ── Open banking (FINMA gate) ──────────────────────────────────
  '/open-banking': RouteMeta(
    path: '/open-banking',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'FeatureFlags.enableOpenBanking gate',
  ),
  '/open-banking/transactions': RouteMeta(
    path: '/open-banking/transactions',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/open-banking/consents': RouteMeta(
    path: '/open-banking/consents',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),
  '/bank-import': RouteMeta(
    path: '/bank-import',
    category: RouteCategory.destination,
    owner: RouteOwner.system,
    requiresAuth: true,
  ),

  // ── Legacy redirects (backwards compat) ────────────────────────
  '/advisor': RouteMeta(
    path: '/advisor',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /coach/chat',
  ),
  '/advisor/plan-30-days': RouteMeta(
    path: '/advisor/plan-30-days',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect -> /coach/chat',
  ),
  '/advisor/wizard': RouteMeta(
    path: '/advisor/wizard',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: true,
    description: 'Legacy redirect (param-passing) -> /coach/chat?topic=',
  ),
  '/coach/agir': RouteMeta(
    path: '/coach/agir',
    category: RouteCategory.alias,
    owner: RouteOwner.coach,
    requiresAuth: true,
    description: 'Legacy redirect -> /coach/chat',
  ),
  '/onboarding/smart': RouteMeta(
    path: '/onboarding/smart',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: false,
    description: 'Onboarding shim -> /coach/chat',
  ),
  '/onboarding/minimal': RouteMeta(
    path: '/onboarding/minimal',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: false,
    description: 'Onboarding shim -> /coach/chat',
  ),
  '/onboarding/enrichment': RouteMeta(
    path: '/onboarding/enrichment',
    category: RouteCategory.alias,
    owner: RouteOwner.system,
    requiresAuth: false,
    description: 'Onboarding shim -> /profile/bilan',
  ),
};
