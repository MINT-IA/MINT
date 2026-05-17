# Phase 32: Cartographier — Context

**Gathered:** 2026-04-20
**Status:** Ready for planning (final)
**Mode:** expert-lock v4 (post-3-panel reviews, structural fix pass)
**Supersedes:** v1 (initial) + v2 (Option C pivot) + v3 (hybrid) — v4 closes Panel 3 structural blockers

<domain>
## Phase Boundary

Route layer observabilité + source-of-truth v2.8, architected for **zero contradiction** :

1. **MAP-01** — Registry `lib/routes/route_metadata.dart` — 147 entries, consumed by CLI + Flutter UI.
2. **MAP-02a** — CLI `./tools/mint-routes` (Python dev-only, Keychain auth, transaction.name query, live health, Phase 35 dogfood integration).
3. **MAP-02b** — Flutter UI `/admin/routes` = **pure registry schema viewer** — static registry data + local FeatureFlags state + `--dart-define=ENABLE_ADMIN=1` + `FeatureFlags.isAdmin` runtime gate. **PAS de snapshot JSON read** (v4 resolves iOS sandbox gap : CLI and Flutter UI don't share a filesystem path across Mac/simulator).
4. **MAP-03** — Route health data join — **CLI EXCLUSIVE**. Flutter UI viewer does not display health status (only schema + FF state). Live health lives only in terminal.
5. **MAP-04** — Parity lint `tools/checks/route_registry_parity.py` + `KNOWN-MISSES.md` + CI job wired.
6. **MAP-05** — Analytics hit-counter on 43 redirects legacy via `mint.routing.legacy_redirect.hit` breadcrumb.

**Kill-gate** : none user-visible. Admin infra, dev-only.

**Phase 32 deliverables unblock** : Phase 33 consumes `RouteMeta.killFlag` contract + reuses AdminScaffold shipped Phase 32. Phase 35 dogfood consumes CLI `--json` output. Phase 36 uses CLI for P0 prioritization.

**Budget** : 5.5j (≈ 1 week) — tenable after v3→v4 simplifications (Flutter UI scope narrowed, no backend endpoint).

</domain>

<decisions>
## Implementation Decisions (12 locked v4)

v1 (6) → v2 Option C pivot (6) → v3 hybrid (8) → **v4 (12)** — v4 adds D-09 (nLPD controls), D-10 (AdminProvider source of truth), D-11 (VALIDATION artefact), D-12 (CI integration spec), and simplifies D-06 to resolve iOS sandbox gap.

### D-01 — RouteMeta schema (UNCHANGED v1-v4)
```dart
class RouteMeta {
  final String path;
  final RouteCategory category;  // enum {destination, flow, tool, alias}
  final RouteOwner owner;         // enum — 15 values (11 flag-groups + anonymous/auth/admin/system)
  final bool requiresAuth;
  final String? killFlag;         // nullable, references Phase 33 flag name
  final String? description;      // optional, dev-only (tree-shaken prod via D-11)
  final String? sentryTag;        // fallback to path at query time
}
```
**Owner ambiguity rule** (v4 locks): for routes spanning multiple domains (e.g., `/coach/chat/from-budget`), **first path segment wins** — i.e., owner = `coach`. Cross-domain context = metadata only, not ownership.

### D-02 — CLI reads Sentry via Keychain, transaction-based query, batch optimization (v4 = v3 + batch J0 + docs refs)
- `./tools/mint-routes` (Python 3.10+, argparse stdlib).
- Keychain : `security find-generic-password -s mint-sentry-auth -w`. **Token scope locked D-09**. Validation before any API call: empty token → exit 71 EX_OSERR with setup instruction pointing to `docs/SETUP-MINT-ROUTES.md`.
- **Query pattern** : `transaction:<path>` (not `event.tag:route:` — SDK SentryNavigatorObserver auto-sets transaction.name per Phase 31 `app.dart:184` wiring). Gap for async-errors-hors-transaction documented, acceptable.
- **Batch OR-query (v4 J0 validation)** : Sentry Issues API supports `query=transaction:/a OR transaction:/b OR …` up to ~200 terms per query. CLI J0 smoke test empirically validates batch works → if yes, 147 routes ÷ 30 per batch = 5 requests = ~15 sec full scan. If Sentry rejects → 1 req/sec fallback = 3 min. Both safe; batch optimal for Phase 35 dogfood.
- **Exit codes** sysexits.h : `0 OK`, `2 EX_USAGE`, `71 EX_OSERR` (Keychain), `75 EX_TEMPFAIL` (429/timeout), `78 EX_CONFIG` (401/403).
- **Error differentiation** : 401 → "token invalid/expired" exit 78; 403 + "scope" → "missing event:read scope" exit 78; 429 → exponential backoff 1s/2s/4s, abort → exit 75; network timeout → exit 75.
- **Output modes** : ANSI colors default; `--no-color` flag + `NO_COLOR` env var (no-color.org standard); `--json` newline-delimited per D-12 schema.
- **DRY_RUN** : `MINT_ROUTES_DRY_RUN=1` reads `tests/tools/fixtures/sentry_health_response.json` (147-route fixture) — unit-testable + CI-friendly.

### D-03 — AdminScaffold Phase 32, reused by Phase 33 (v4 = v3, clearer role split)
- `lib/screens/admin/admin_shell.dart` — AdminScaffold (appBar + children).
- Compile-time gate : `--dart-define=ENABLE_ADMIN=0` par défaut, `1` for dev builds. Tree-shaken prod per D-11.
- Runtime gate : **`FeatureFlags.isAdmin` local check (per D-10)** — PAS de backend call.
- Phase 32 ships child 1 : `/admin/routes` (registry viewer per D-06 v4 spec).
- Phase 33 adds child 2 : `/admin/flags` (same shell, no refactor).

### D-04 — Parity lint regex + KNOWN-MISSES.md + standalone script (UNCHANGED v3)
- `tools/checks/route_registry_parity.py` — standalone Python executable, argparse stdlib.
- Compares `app.dart` `GoRoute|ScopedGoRoute(path:...)` extractions vs `kRouteRegistry` keys.
- Ships with `tools/checks/route_registry_parity-KNOWN-MISSES.md` documenting multi-line / ternary / dynamic / conditional patterns regex skips.
- Wave 0 action : extract all `app.dart` patterns matching known-miss categories, populate `KNOWN-MISSES.md` with real examples BEFORE registry write.
- CI integration wired in D-12. Lefthook wiring = Phase 34 scope (Phase 32 ships script only).

### D-05 — Redirect legacy analytics via Sentry breadcrumb, count corrected (v4 = v3, retention tied to D-09)
- 43 redirects emit `mint.routing.legacy_redirect.hit` breadcrumb with `data: {from, to}` before redirect.
- Math: 43 × 10 hits/day × 30 = 12'900 events/mo = **0.258% Sentry Business 50k/mo** (v3 corrected). At 5k DAU real scale = ~1-2% quota (still safely under $160 ceiling). Revisit at 10k DAU for Enterprise tier upgrade (documented trigger).
- Breadcrumb data redacted per D-09 (from/to paths only, no query params, no user context).

### D-06 — Dual affordance, Flutter UI = pure schema viewer (CHANGED from v3)
- **CLI** (MAP-02a) = full live health via Sentry, `--json` for Phase 35, quality bar per D-02 + D-12.
- **Flutter UI `/admin/routes`** (MAP-02b) = **REGISTRY SCHEMA VIEWER** :
  - Columns : `path | category | owner | requiresAuth | killFlag | FeatureFlags enabled (local) | description`
  - Groupe par owner (15 buckets collapsible)
  - **Source de données : `kRouteRegistry` (static const) + `FeatureFlags` (runtime local)**
  - **PAS de Sentry health data, PAS de snapshot JSON read, PAS de backend call**
  - Use case : dev browse le registry pendant qu'il code, vérifie killFlag assignment, voit l'état local FF
  - Pour live health → "use `./tools/mint-routes health` terminal" note affichée en footer de l'écran
- **Rationale v4 simplification** :
  - Panel 3 executor identifed : iOS simulator sandbox empêche Flutter UI de lire `.cache/route-health.json` écrit par le CLI sur le Mac. Problème architectural réel, pas design préférence.
  - Trois options considerees : (a) backend endpoint (revert v2→v3 pivot), (b) simctl get_app_container write trick (fragile, simulator-only), (c) **simplify UI scope to eliminate dependency** (v4 choice).
  - v4 : Flutter UI utile pour schema exploration (read-only). Live health = CLI job. Single responsibility per surface. No more fake-data risk (UI ne peut plus afficher des zeros trompeurs parce qu'elle n'a pas de health data à afficher).
- **UX panel brand check** : "schema viewer utilitaire" s'inscrit dans DESIGN_SYSTEM.md "Utility Screens" category, même doctrine que PR #366 Aujourd'hui hub. Utility ≠ cliché dashboard.

### D-07 — Route-tag query pattern (UNCHANGED v3)
CLI queries `transaction:<path>` using SentryNavigatorObserver's SDK built-in `transaction.name = routePath` auto-setting (Phase 31 `app.dart:184`). Gap acknowledged : async errors hors transaction context not route-queryable (appearing in "system" bucket). **J0 smoke test in D-11 validates empirically.**

### D-08 — CLI + Flutter UI quality bar (v4 = v3 base, clarified deliverables)
- **CLI quality bar** : sysexits.h exit codes, `--json` mode (Phase 35 hard dep), `--no-color` + `NO_COLOR`, `MINT_ROUTES_DRY_RUN=1` fixture mode, pytest unit tests `tests/tools/test_mint_routes.py`, CI integration per D-12.
- **Flutter UI quality bar** : tree-shake VALIDATION per D-11, `Semantics(label: ...)` sur owner buckets, empty-state "Registry not generated" si `kRouteRegistry.isEmpty`, FeatureFlags `select` memoization pour éviter rebuild full table sur chaque flag change (perf note panel 3).

### D-09 — nLPD compliance controls (NEW v4, post-panel-3)
**Required controls for Swiss deployment** :
1. **Token scope minimization** : `SENTRY_AUTH_TOKEN` MUST have only `project:read` + `event:read` (NO write, NO admin). Documented in `docs/SETUP-MINT-ROUTES.md`, validated by CLI at startup via a `--verify-token` sub-command (optional one-shot check).
2. **Event redaction layer** : CLI strips the following fields from Sentry API responses before display/JSON output :
   - `user.*` (id, email, ip_address, username)
   - `breadcrumb.data.user_*` fields
   - Any CHF amount in error messages > 100 CHF → masked `CHF [REDACTED]`
   - IBAN patterns → `CH[REDACTED]`
   - Email patterns → `[EMAIL]`
   - JSON output metadata : `{_redaction_applied: true, _redaction_version: 1}`
3. **Snapshot JSON retention** (if Phase 35 dogfood writes `.cache/route-health.json` on dev machine) : 7-day auto-delete via `./tools/mint-routes` startup check. Emergency `./tools/mint-routes purge-cache` command. `.cache/` entry in `.gitignore` (CI gate verifies).
4. **Admin access log** : Flutter UI `/admin/routes` mount emits breadcrumb `mint.admin.routes.viewed` with `data: {route_count, feature_flags_enabled_count, snapshot_age_minutes}` — zero PII, aggregates only. nLPD Art. 12 processing record.
5. **Keychain storage hardening** : `security add-generic-password -a $USER -s mint-sentry-auth -w $TOKEN -U -A` (access control : single user, this device only). Documented in SETUP docs.

**nLPD Art. mapping** : Art. 5 (accuracy) = D-07 transaction.name gap doc'd, Art. 6 (minimization) = token scope + redaction, Art. 9 (storage limitation) = 7d retention, Art. 12 (processing record) = admin breadcrumb, Art. 7 (security) = Keychain hardening.

### D-10 — AdminProvider.isAllowed via FeatureFlags.isAdmin local (NEW v4, resolves v3 contradiction)
- **Decision** : `AdminProvider.isAllowed` returns `FeatureFlags.isAdmin` (local FF state) — NO backend call.
- **Rationale** : Panel 3 devops + executor identified v3 contradiction ("no backend endpoint" + "AdminProvider calls `/api/v1/admin/me`"). `/api/v1/admin/me` does not exist in backend. Options: (a) add endpoint (+2h backend scope), (b) use local FF. v4 picks (b) for simplicity + kill-policy (no new features hors roadmap).
- **Trade-off** : compile-time gate `ENABLE_ADMIN=1` + runtime `FeatureFlags.isAdmin` = two gates but both LOCAL. Single-user dev-only tool = adequate for Phase 32 solo usage. If multi-user admin surface ever needed (v2.9+), re-introduce backend endpoint.
- **FF wiring** : `FeatureFlags.isAdmin` = static getter reading a constant/env for Phase 32 (hardcoded `true` when ENABLE_ADMIN=1). Phase 33 ChangeNotifier refactor may evolve this.

### D-11 — 32-VALIDATION.md artefact (NEW v4, post-panel-3 devops + executor)
Ship `.planning/phases/32-cartographier/32-VALIDATION.md` documenting pre-merge gates :
1. **Tree-shake gate** : `flutter build ios --simulator --release --no-codesign --dart-define=ENABLE_ADMIN=0` → `strings build/.../Runner.app/Runner | grep kRouteRegistry` = 0 occurrences. Proves registry absent from prod IPA.
2. **J0 SentryNavigatorObserver smoke test** : install staging build, trigger 1 deliberate error on 3 test routes (`/coach`, `/budget`, `/scan`), wait 60s, verify `./tools/mint-routes health --json | jq '.[] | select(.sentry_count_24h > 0)'` returns those 3 routes. If fails → Phase 31 retroactive `scope.setTag('route', ...)` patch (2-4h).
3. **Batch OR-query validation** : curl Sentry API with 30-route OR query, verify 2xx + results. Determine batch limit empirically (target ≥ 30). Document in CLI code + VALIDATION.
4. **Parity lint local run** : `python3 tools/checks/route_registry_parity.py` on pristine checkout, verify clean output + KNOWN-MISSES.md entries match observed patterns.
5. **CLI DRY_RUN test** : `MINT_ROUTES_DRY_RUN=1 ./tools/mint-routes health` outputs fixture data without network. Verifies offline testability.
6. **Flutter UI smoke test** : boot iPhone 17 Pro sim, `./tools/simulator/walker.sh` script opens `/admin/routes`, screenshot captured, verifies 147 routes rendered grouped by owner.

### D-12 — CI integration spec (NEW v4, post-panel-3 devops)
**CI jobs wired in Phase 32 ship (not Phase 34 deferred)** :
1. **`route-registry-parity` job** in `.github/workflows/ci.yml` — runs `python3 tools/checks/route_registry_parity.py` on every push. Fails PR on drift. Runtime ≤ 30s.
2. **`mint-routes-tests` job** — runs `pytest tests/tools/test_mint_routes.py -q` with `MINT_ROUTES_DRY_RUN=1`. Fails on test failure. Fixture `tests/tools/fixtures/sentry_health_response.json` committed.
3. **`admin-build-sanity` job** (defensive) — scans `.github/workflows/testflight.yml` + `play-store.yml` for `--dart-define=ENABLE_ADMIN=1` in prod build steps. Fails if found. Runtime ≤ 5s.
4. **Schema publication** : `lib/routes/route_health_schema.dart` committed alongside registry — defines JSON shape Phase 35 dogfood consumes. Versioned (`schemaVersion: 1`).
5. **Lefthook wiring** : Phase 32 ships `.lefthook/route_registry_parity.sh` script standalone. **Hook wiring in `lefthook.yml` = Phase 34 scope** (avoids merge conflict with GUARD-02 bare-catch work).
6. **Documentation** : `docs/SETUP-MINT-ROUTES.md` ships with Phase 32 (Keychain setup + Sentry token scopes + troubleshooting) + README link.

### Claude's Discretion
- Exact `AdminProvider` class shape (ChangeNotifier vs static getter) — planner scans existing provider patterns.
- Exact Flutter UI layout (ListView.builder vs CustomScrollView) — executor picks per perf memoization needs.
- Exact Sentry batch OR-query term limit (30 vs 50 vs 100) — D-11 J0 empirical determines.
- Exact CLI sub-command surface (`health`, `redirects`, `reconcile` locked; additional subs like `purge-cache` optional executor choice).
- Exact `.cache/` path resolution (`~/.cache/mint/` vs `./.cache/` repo-local) — executor picks, `.gitignore` entry mandatory either way.

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### Phase scope + success criteria
- `.planning/ROADMAP.md` §"Phase 32: Cartographier" — **AMENDED 2026-04-20** (148→147, 23→43, MAP-02 dual affordance)
- `.planning/REQUIREMENTS.md` §MAP (MAP-01..05) — **AMENDED 2026-04-20** (MAP-02 wording, MAP-05 count corrected)
- `.planning/STATE.md` — v2.8 milestone post-31 (ref commit b7a88cc89 PR #367)

### Upstream phase dependencies
- `.planning/phases/31-instrumenter/31-CONTEXT.md` — D-03 breadcrumb naming, D-05 trace propagation, D-06 CustomPaint masking
- `apps/mobile/lib/app.dart:184` — `SentryNavigatorObserver()` wiring (D-07 foundation)
- `apps/mobile/lib/services/observability/breadcrumb_helper.dart` — `MintBreadcrumbs.log()` API (D-05 consumer)
- `apps/mobile/lib/services/error_boundary.dart:96` — `scope.setTag` pattern (evidence D-07 `route` tag absent)
- `tools/simulator/sentry_quota_smoke.sh` — Keychain pattern inheritance (D-02)

### Downstream phase dependencies
- `.planning/REQUIREMENTS.md` §FLAG (Phase 33) — consumes `RouteMeta.killFlag` + reuses AdminScaffold
- `tools/dogfood/mint-dogfood.sh` (Phase 35) — consumes CLI `--json` + schema per D-12
- `.planning/REQUIREMENTS.md` §FIX (Phase 36) — consumes CLI + registry for P0 prioritization

### Related ADRs
- `decisions/ADR-20260419-v2.8-kill-policy.md` — scope discipline (no new features hors roadmap, respected via v4)
- `decisions/ADR-20260419-autonomous-profile-tiered.md` — L2 profile (this phase) + L3 partial (Flutter UI sub-task)
- `decisions/ADR-20260420-chat-vivant-deferred-v2.9-phase3.md` — deferral discipline pattern

### External specs
- Sentry Issues API — https://docs.sentry.io/api/events/list-an-organizations-issues/
- Sentry Flutter SDK `SentryNavigatorObserver` — SDK 9.14.0 auto-sets `transaction.name` (J0 validates)
- sysexits.h — POSIX exit code convention (D-02)
- NO_COLOR standard — https://no-color.org (D-02)
- nLPD Swiss data protection law — Art. 5, 6, 7, 9, 12 mapping (D-09)

### Panel review audit trail
- `.planning/phases/32-cartographier/32-DISCUSSION-LOG.md` v4 — 3 panel rounds (12 experts total), v1→v4 decision trail

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `apps/mobile/lib/app.dart` — 147 GoRoute/ScopedGoRoute + 43 redirects (reconciled 2026-04-20)
- `apps/mobile/lib/app.dart:184` — `SentryNavigatorObserver()` wired (D-07 foundation, SDK auto-sets transaction.name)
- `apps/mobile/lib/services/feature_flags.dart` — FeatureFlags service, Phase 32 reads only, D-10 adds `isAdmin` getter
- `apps/mobile/lib/services/observability/breadcrumb_helper.dart` — Phase 31 ship, D-05 + D-09 consumer
- `apps/mobile/lib/services/error_boundary.dart:96` — `scope.setTag` pattern (D-07 evidence)
- `tools/simulator/sentry_quota_smoke.sh` — Keychain + Sentry API patterns inherited by `./tools/mint-routes`
- `apps/mobile/lib/theme/colors.dart` — MintColors `success/warning/error/textMuted` for status indicators

### Established Patterns
- `tools/checks/*.py` — shebang, argparse stdlib, sys.exit codes, sys.stderr errors
- Flutter compile-time flags : `--dart-define=API_BASE_URL`, `MINT_ENV`, `SENTRY_DSN`, `ENABLE_ADMIN` adds naturally
- Lefthook : skeletal Phase 30.5, wiring expands Phase 34 (Phase 32 ships script standalone per D-12)
- CI workflow `.github/workflows/ci.yml` — Python lint job slots available, backend pytest job for CLI tests

### Integration Points
- `app.dart` router : Phase 32 ships registry without modifying GoRouter config. Phase 33 wires `requireFlag()` via redirect callback.
- `/admin` route : new declaration in `app.dart` with compile-time `if (kIsAdminEnabled)` guard.
- `lib/screens/admin/` : new directory, admin_shell.dart + routes_registry_screen.dart + route_health_schema.dart.
- `tools/mint-routes` : new Python package (argparse stdlib), inherits Keychain + Sentry API patterns.
- Backend : **zero changes** (v4 kills `/admin/me` endpoint, AdminProvider uses local FF per D-10).

</code_context>

<specifics>
## Specific Ideas

- **v4 philosophical anchor** : "meilleure techno" = architecture sans contradiction, pas architecture maximale. v3 avait Flutter UI lisant un fichier Mac-local → cassé sur simulator. v4 simplifie Flutter UI à pure schema viewer, CLI garde toute la charge live. Single responsibility per surface.
- **nLPD D-09 first-class citizen** : ajouter les controls dans le CONTEXT (pas dans une note à part) = executor voit les controls au même niveau que le schema RouteMeta. Implémentation impossible à oublier.
- **CI integration D-12 first-class** : zero-CI-integration était un devops P0 blocker. Phase 32 ship les jobs explicitement, pas en "Phase 34 problem".
- **D-11 VALIDATION artefact** : J0 gates empiriques lockés = batch OR-query test, SentryNavigatorObserver smoke test, tree-shake binary grep. Factualise ce que v3 avait en prose.
- **147 vs 148, 43 vs 23** : ROADMAP amendment 2026-04-20 documente les reconciled counts. Future ROADMAP drafts incluront Wave 0 grep pre-commit.
- **Panel 3 contrarian honesty** : j'ai reconnu panel-driven-design risk. v4 a ÉTÉ guidé par findings structurels (iOS sandbox = fait, missing endpoint = fait, nLPD = loi) pas par vibes. Self-discipline validation.

</specifics>

<deferred>
## Deferred Ideas

Hors scope Phase 32 par v4 + kill-policy v2.8 :

- **Backend endpoint `/api/v1/admin/*`** — killed cleanly en v4 (AdminProvider uses local FF). Re-introduce v2.9+ if multi-user admin surface needed.
- **Codegen via `build_runner`** — noted v2.9+ MAP-06 if >5 regex false negatives discovered in execution.
- **AST-based parity lint** — v2.9+ if regex fragility becomes blocking.
- **Filter/search/export CLI + UI** — MVP strict v2.8 (CLI `--owner=X` seul, UI schema viewer static). v2.9+ if friction emerges.
- **Backend OpenAPI parity** — v2.9+ MAP-06.
- **Sunset 43 redirects legacy** — analytics Phase 32, suppression EFFECTIVE v2.9+ (30-day zero-traffic per redirect).
- **Mobile ↔ Backend cross-layer parity** — v2.9+.
- **Per-route flag** (au lieu de 11 flag-groups Phase 33) — v2.9+ if coarse-grain becomes limiting.
- **Phase 31 retroactive `scope.setTag('route')` patch** — only if D-11 J0 smoke test reveals `transaction.name` NOT set by SDK.
- **Heatmap user paths (DIFF-02)** — explicit ROADMAP out-of-scope, v2.9+ standalone.
- **Sentry tier upgrade Enterprise** — triggered at 5-10k DAU per D-05 math audit, not Phase 32.

</deferred>

---

*Phase: 32-cartographier*
*Context gathered: 2026-04-20 (v4 post-3-panel-reviews, structural fix pass per Julien "je valide ton call, je te fais confiance")*
*Mode: expert-lock v4 — 12 decisions locked (D-01..D-12)*
*Reconciled: 147 routes / 43 legacy redirects actual*
*Budget: 5.5j (~1 week)*
*Next: amend ROADMAP + REQUIREMENTS, then /gsd-plan-phase 32*
