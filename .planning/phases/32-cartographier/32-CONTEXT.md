# Phase 32: Cartographier — Context

**Gathered:** 2026-04-20
**Status:** Ready for planning
**Mode:** expert-lock (6 decisions locked to PM/engineering recommendations — see rationale per D-XX)

<domain>
## Phase Boundary

Route layer observabilité + source-of-truth v2.8. Quatre livrables :

1. **MAP-01** : `lib/routes/route_metadata.dart` expose `kRouteRegistry: Map<String, RouteMeta>` avec ~148-156 entrées (exact count TBD via reconcile étape Wave 0 — `app.dart` a 156 `GoRoute|ScopedGoRoute` at session start, ROADMAP estimation 148). Single source of truth pour `{path, category, owner, requiresAuth, killFlag}`.
2. **MAP-02** : `/admin/routes` dashboard gated par compile-time `--dart-define=ENABLE_ADMIN=1` ET runtime `AdminProvider.isAllowed` via `GET /api/v1/admin/me` allowlist. Tree-shaken prod IPA.
3. **MAP-03** : Route health data join (Sentry Issues API last 24h × FeatureFlags status × last-visited breadcrumbs) → statut 4 couleurs vert/jaune/rouge/dead par route.
4. **MAP-04** : `tools/checks/route_registry_parity.py` lint (CI fail si `GoRoute(path:)` in `app.dart` drift vs `kRouteRegistry`).
5. **MAP-05** : Analytics hit-counter sur 23 redirects legacy — instrumentation seulement, sunset DEFER v2.9+ après 30-day zero-traffic validation.

**Phase 32 déverrouille** : Phase 33 `requireFlag()` middleware consomme `RouteMeta.killFlag` comme contrat. Phase 36 Finissage E2E consomme le dashboard pour prioriser fixes (join route × sentry issues).

**Kill-gate** : aucun — Phase 32 est infra dev-only, 0 surface user-visible prod.

</domain>

<decisions>
## Implementation Decisions (6 locked)

Rationale : chaque décision a été raisonnée avec options/tradeoffs lors de la présentation gray areas. Julien a autorisé expert-lock 2026-04-20 ("b" / expert-lock). Si l'une se révèle wrong en execution → revert + flag dans SUMMARY.md comme Phase 31.

### D-01 — RouteMeta schema = 5 required + 2 optional, owner=enum feature-group
- **Decision**: 
  ```dart
  class RouteMeta {
    final String path;                    // '/coach/chat'
    final RouteCategory category;          // enum {destination, flow, tool, alias}
    final RouteOwner owner;                // enum (see below)
    final bool requiresAuth;
    final String? killFlag;                // nullable, references Phase 33 flag name (e.g., 'enableCoachChat')
    final String? description;             // optional, 1-ligne pour dashboard
    final String? sentryTag;               // optional, override si route tag Sentry != path
  }
  enum RouteCategory { destination, flow, tool, alias }
  enum RouteOwner {
    coach, scan, budget, profile, explorerRetraite, explorerFamille,
    explorerTravail, explorerLogement, explorerFiscalite, explorerPatrimoine,
    explorerSante, anonymous, auth, admin, system
  }
  ```
- **Rationale owner=enum (pas string libre)** : miroir exact des 11 flag-groups Phase 33 + 4 groupes système (anonymous/auth/admin/system) = **15 owners total**. Évite string drift ("coach" vs "Coach" vs "coach-chat"). Enum = compile-time check, IDE autocomplete, lint-friendly. Julien solo mais le owner sert à grouper visuellement le dashboard (156 routes en 15 buckets lisibles).
- **Rationale description + sentryTag optional** : dashboard lisible sans avoir à parser le path ("Premier éclairage coach" > "/coach/onboarding/premier-eclairage"). `sentryTag` pour les cas où la route Sentry capture utilise un tag distinct du path (rare — fallback `path` as tag par défaut).
- **Rationale DROP `lastTouchedSha`** : volatile, dérivable via `git blame`/`git log` si besoin ponctuel. Pas à stocker en registry qui se veut stable.
- **DROP `description` en prod ?** Non — registry entier est tree-shaken via `const` + `kIsAdminEnabled` guard. 148 descriptions = ~8kb texte, négligeable et dev-only.

### D-02 — Sentry Issues API access = backend proxy + mount-only refresh
- **Decision**: 
  - Nouvel endpoint backend `GET /api/v1/admin/route-health` (requireAdmin), retourne `Map<String, RouteHealth>` avec `{status: 'green'|'yellow'|'red'|'dead', sentryIssueCount24h: int, lastVisitedAt: ISO8601?, featureFlagEnabled: bool}`.
  - Backend lit `SENTRY_AUTH_TOKEN` depuis env Railway (pattern établi Phase 31), query `https://sentry.io/api/0/organizations/{org}/issues/?statsPeriod=24h&query=project:mint+event.type:error` filtre par `event.tag:route=<path>`.
  - Mobile appelle depuis `/admin/routes` au mount + bouton refresh manuel. **Pas d'auto-refresh** (Sentry API rate-limited 40 req/min, dashboard solo usage, 40/min dépassable seulement en stress-test).
  - Cache 30s côté backend via FastAPI `@lru_cache(ttl=30)` (évite hammer Sentry si admin rafraîchit).
- **Rationale backend proxy (pas mobile direct)** : `SENTRY_AUTH_TOKEN` exposé dans `--dart-define=` serait baked dans l'IPA — exfiltrable par reverse-engineering. Backend proxy = token reste côté serveur, admin auth via JWT existant.
- **Rationale mount-only + manual button (pas auto 60s)** : Julien va ouvrir le dashboard ponctuellement (pas continuous monitoring). Auto-refresh = Sentry API hammer for no value. Bouton refresh explicite + spinner = attente claire.

### D-03 — /admin shell = scaffold partagé Phase 32 + Phase 33 reuse
- **Decision**: Créer `lib/screens/admin/admin_shell.dart` dès Phase 32 comme AdminScaffold (AppBar + drawer/tabs pour naviguer entre sous-pages admin). Phase 32 ship `/admin/routes` comme child. Phase 33 ajoute `/admin/flags` comme 2e child sans re-scaffold.
- **Gate commun** : `admin_shell.dart` check `ENABLE_ADMIN` compile-time + `AdminProvider.isAllowed` runtime **une seule fois**, les children sont rendus à l'intérieur du shell validé.
- **Rationale** : économie 0.5j en Phase 33 (scaffold non-dupliqué) + UX cohérente (Julien navigue entre routes/flags via la même chrome). Phase 31 a posé Sentry navigator + breadcrumbs sur toutes les routes → admin shell hérite automatiquement de l'observabilité.
- **Gate routing** : `/admin` lui-même redirige vers `/admin/routes` si compile-time et runtime OK, sinon 404-style "Admin disabled" screen (pas de leak qu'un gate admin existe en prod IPA — idéalement tree-shaken mais defense-in-depth via route absent du `kRouteRegistry` en build prod).

### D-04 — Parity lint = mobile-only scope (GoRoute ↔ kRouteRegistry)
- **Decision**: `tools/checks/route_registry_parity.py` compare UNIQUEMENT `app.dart` `GoRoute(path:)` / `ScopedGoRoute(path:)` extractions vs `kRouteRegistry` keys. Backend OpenAPI parity = **hors scope Phase 32**, défer v2.9+ si nécessaire.
- **CI integration** : lint lance sur `apps/mobile/lib/app.dart` + `apps/mobile/lib/routes/route_metadata.dart`, diff set-symmetric, fail avec liste explicite des drifts.
- **Rationale** : le L2 autonomous profile mentionnait "mobile↔backend OpenAPI parity" — c'est une overreach. ROADMAP success criterion 4 est clair : "GoRoute(path:) dans app.dart absent de kRouteRegistry (ou vice-versa)". Mobile-only = scope strict, 1 sem tenable. Backend routes = source of truth différente (FastAPI OpenAPI auto-gen). Si un jour on veut enforcer parity cross-layer, c'est une v2.9+ MAP-06 dédiée.
- **Pre-commit via lefthook** : Phase 34 ajoutera ce lint au pre-commit — Phase 32 livre juste le script + CI integration, Phase 34 wire lefthook.

### D-05 — Redirect legacy analytics storage = Sentry breadcrumb counter
- **Decision**: Chacune des 23 routes legacy (patterns `ScopedGoRoute(path:..., redirect: (_, __) => '/new/path')`) émet un breadcrumb `mint.routing.legacy_redirect.hit` avec `data: {from: '<legacy_path>', to: '<new_path>'}` avant le redirect. Compteur agrégé via Sentry Issues API query `event.category:mint.routing.legacy_redirect.hit GROUP BY data.from`.
- **Dashboard display** : colonne "redirect hits 30d" par legacy path, pulled lors du route-health refresh (D-02).
- **Rationale** :
  - 0 nouvelle infra (pas de table backend, pas de SQLite local)
  - Phase 31 D-03 hierarchical naming convention `mint.<surface>.<action>.<outcome>` déjà établie, ici `mint.routing.legacy_redirect.hit` s'y conforme parfaitement
  - 23 redirects × ~10 hits/jour moyen max = 230 events/jour = 0.005% du quota Sentry Business 50k events/mois → négligeable
  - Évite backend endpoint + migration + maintenance pour un one-shot 30-day validation
- **Sunset condition** : si un redirect legacy a 0 hits sur 30 jours consécutifs (via dashboard column), éligible suppression en v2.9+. Aucune suppression en v2.8 (per ROADMAP MAP-05 + kill-policy).

### D-06 — Dashboard UX = MVP strict (pas de filter/search en Phase 32)
- **Decision**: Dashboard = table scrollable simple, colonnes :
  | Status dot | Path | Category | Owner | killFlag | Sentry 24h | FF enabled | Last visited | Redirect hits 30d (legacy only) |
  
  Group visuel par `owner` (15 buckets collapsible). Pas de search bar, pas de filter chips, pas d'export. Refresh button en AppBar.
- **Rationale** :
  - L2 auto profile = 1 sem, serrée. Filter/search = +0.5j-1j, inutile pour 156 routes en 15 groups (scroll court)
  - `DIFF-02 heatmap user paths` est explicitement listé dans ROADMAP comme "Differentiators (Out of Scope v2.8)" — respect kill-policy
  - MVP strict = code minimum = moins de surface à bug → fiable pour Phase 33+36 qui en dépendent
- **Ship later (v2.9+ potentiel)** : search par path/owner, export CSV pour audits, heatmap visitation (DIFF-02).

### Claude's Discretion
- Exact shape du `AdminProvider.isAllowed` Provider (ChangeNotifier vs StreamProvider) — planner décide selon pattern Flutter établi du projet.
- Exact implémentation du tree-shaking verification pour `/admin/routes` en prod — planner décide (flutter build + grep IPA vs `--split-debug-info` check). Probablement `grep` sur binary post-build, documenté dans VALIDATION.md.
- Exact format du status dot (CSS color circle vs icon) — executor décide selon MintColors existants.
- Exact placement de `lib/routes/` vs `lib/router/` — existing pattern scan avant création (si app.dart sits at root of lib/, adopter le même niveau).
- Exact naming du `/admin/me` endpoint backend vs reuse `/api/v1/auth/me` + claim `is_admin` — backend executor décide.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents (researcher, planner, executor) MUST read these before planning or implementing.**

### Phase scope + success criteria
- `.planning/ROADMAP.md` §"Phase 32: Cartographier" — goal, depends on 31+34, success criteria 5 items, auto profile L2+L3-partial, budget 1 sem
- `.planning/REQUIREMENTS.md` §MAP (MAP-01..05) — exact spec per REQ
- `.planning/STATE.md` — milestone v2.8 status post-31 merge (ref: commit b7a88cc89 PR #367)

### Upstream phase dependencies (must read for inheritance)
- `.planning/phases/31-instrumenter/31-CONTEXT.md` D-03 — hierarchical breadcrumb naming `mint.<surface>.<action>.<outcome>` → Phase 32 adopts `mint.routing.*` + `mint.admin.*` namespaces
- `.planning/phases/31-instrumenter/31-CONTEXT.md` D-05 — sentry-trace + baggage + X-MINT-Trace-Id propagation pattern → `/api/v1/admin/route-health` endpoint inherits this (auth + trace)
- `.planning/phases/31-instrumenter/31-CONTEXT.md` D-06 — default-deny CustomPaint `MintCustomPaintMask` → si dashboard admin affiche des charts, wrap per D-06
- `apps/mobile/lib/services/observability/breadcrumb_helper.dart` (shipped Phase 31) — `MintBreadcrumbs.log()` API à réutiliser pour `mint.routing.legacy_redirect.hit`

### Downstream phase dependencies (provides contracts to)
- `.planning/REQUIREMENTS.md` §FLAG (FLAG-01..05) — Phase 33 consumes `RouteMeta.killFlag` (nullable string) as contract for `requireFlag()` middleware
- `.planning/REQUIREMENTS.md` §FIX (Phase 36) — Phase 36 uses dashboard route-health to prioritize P0 fixes (join route × Sentry issues)

### Related ADRs
- `decisions/ADR-20260419-v2.8-kill-policy.md` — scope discipline v2.8 (pas de feature nouvelle hors roadmap) → DIFF-02 heatmap + filter/search deferred
- `decisions/ADR-20260419-autonomous-profile-tiered.md` — L2 profile definition + `/admin/routes` UI sub-task bascule L3 partial (walker.sh simctl gate sur livrable dashboard)

### External specs (Sentry + GoRouter)
- Sentry Issues API docs https://docs.sentry.io/api/events/list-an-organizations-issues/ — endpoint `GET /api/0/organizations/{org}/issues/` + query param `statsPeriod=24h`
- Sentry rate limits — 40 req/min default (justifies backend cache 30s + mount-only refresh in D-02)
- GoRouter `ScopedGoRoute` / `redirect:` callback semantics — Phase 33 dépendra de la position exacte du `redirect:` hook dans le pipeline

### Codebase maps
- `.planning/codebase/STRUCTURE.md` — existing `apps/mobile/lib/` layout (routes/router location TBD per D-Discretion)
- `.planning/codebase/ARCHITECTURE.md` — Provider pattern (for `AdminProvider.isAllowed`)
- `.planning/codebase/CONVENTIONS.md` — dart-define naming, feature flag patterns

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/mobile/lib/app.dart` — **156 GoRoute|ScopedGoRoute declarations** at session start (2026-04-20). Extraction par regex scriptable. Wave 0 de Phase 32 reconcilie 148 vs 156 (ROADMAP estimation vs actual) et produit `kRouteRegistry` exhaustif.
- `apps/mobile/lib/services/feature_flags.dart` — FeatureFlags service existe. Pattern `FeatureFlags.enableXXX` via bool fields + `applyFromMap()` 6h refresh. Phase 33 refactor en ChangeNotifier ; Phase 32 consomme l'API actuelle read-only (`FeatureFlags.isEnabled(flagName)` style).
- `apps/mobile/lib/services/observability/breadcrumb_helper.dart` (Phase 31 ship) — `MintBreadcrumbs.log('mint.<surface>.<action>.<outcome>', data: {...})` — consommé par D-05 pour `mint.routing.legacy_redirect.hit`.
- `services/backend/app/main.py` — FastAPI app avec auth middleware existant + Phase 31 global exception handler (lines 177-226). Nouvel endpoint `/api/v1/admin/route-health` s'y ajoute avec auth `requireAdmin` pattern existant.

### Established Patterns
- `--dart-define=XXX` compile-time flags → pattern déjà utilisé pour `API_BASE_URL`, `MINT_ENV`, `SENTRY_DSN`. `ENABLE_ADMIN=1` s'y ajoute.
- Dashboard page mount-only fetch (pas realtime) → pattern établi dans `Aujourdhui` screen (calendar fetch on mount).
- Sentry `SENTRY_AUTH_TOKEN` Keychain pattern → Phase 31 Plan 31-04 a posé la pattern pour `sentry_quota_smoke.sh` (bash via `security find-generic-password`). Backend utilise env var Railway directement (pas Keychain).

### Integration Points
- `app.dart` router config : Phase 32 ship le registry SANS modifier le `GoRouter` config (parity lint valide consistency, mais registry est séparé). Phase 33 wire le `redirect:` callback pour `requireFlag()`.
- `/admin` route nouvelle dans `app.dart` : ajouter après les routes auth guards, avec compile-time `if (kIsAdminEnabled)` guard autour de la déclaration (tree-shake prod).
- Backend : nouveau fichier `services/backend/app/routers/admin_route_health.py` (pattern existant si d'autres routers existent, sinon `services/backend/app/main.py` direct).
- Lefthook pre-commit : Phase 34 wire `route_registry_parity.py` ; Phase 32 livre le script exécutable standalone + CI job `.github/workflows/ci.yml` ajout.

</code_context>

<specifics>
## Specific Ideas

- **Dashboard visuel = utility, pas beau** — Julien n'est pas consommateur UX de ce screen, c'est un admin tool. Pas de motion design, pas de MintColors raffinement, pas de transitions. Status dot + text. Priorité fiabilité > esthétique (inverse de Coach/Explorer).
- **15 owners enum NON-exhaustive** — si une route existante n'a pas d'owner naturel (ex: `/legal`, `/privacy`), owner = `system`. Pas de creative "undefined" state.
- **kRouteRegistry count mismatch 148 vs 156** — Wave 0 de Phase 32 doit réconcilier. Probable explication : ROADMAP a compté à l'œil, `app.dart` a eu des ajouts récents (30.5/30.6/31). La reconcile n'est pas un bug, juste un comptage actuel. Le registry enregistre L'ÉTAT ACTUEL, pas l'estimation ROADMAP.
- **Pas de RouteMeta pour les routes dynamiques** (ex: `/coach/chat/:threadId`) — `path` dans registry = le pattern déclaré dans `app.dart` (`/coach/chat/:threadId`), PAS l'URL résolue. 1 entrée registry = 1 `GoRoute` declaration.
- **Redirect legacy = 23 estimé, exact count TBD** — Wave 0 compte aussi les `ScopedGoRoute(..., redirect: ...)` patterns. Si > 23, pas un bug, ROADMAP estimation.

</specifics>

<deferred>
## Deferred Ideas

Hors scope Phase 32 par décision expert-lock + kill-policy v2.8 :

- **Backend OpenAPI parity** — élargir MAP-04 pour comparer mobile routes vs backend endpoints. Défer v2.9+ MAP-06 si besoin (rarement nécessaire en pratique — les 2 layers ont des responsabilités différentes).
- **Filter/search/export dashboard** — `/admin/routes` avec filter par owner, search par path, export CSV. v2.9+ si Julien utilise le dashboard >2×/semaine et ressent la friction.
- **Heatmap user paths (DIFF-02)** — ROADMAP "Out of Scope v2.8" explicit, descopable. Nécessite analytics pipeline dense (pas juste Sentry breadcrumbs). v2.9+ standalone phase.
- **Sunset 23 redirects legacy** — analytics instrumentés Phase 32, suppression EFFECTIVE defer v2.9+ après 30-day zero-traffic validation (par redirect).
- **Mobile ↔ Backend route parity lint** — MAP-04 scoped mobile-only. Cross-layer parity = v2.9+ si tension se manifeste.
- **Per-route flag** (au lieu de 11 flag-groups Phase 33) — FLAG-05 locke 11 groupes, éviter flag rot. Per-route flag = v2.9+ seulement si 1 groupe devient too coarse.

</deferred>

---

*Phase: 32-cartographier*
*Context gathered: 2026-04-20 (expert-lock mode, 6 decisions locked per Julien authorization)*
*Mode: expert-lock — Julien relit avant /gsd-plan-phase 32, override D-XX si désaccord*
