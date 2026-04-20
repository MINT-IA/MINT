# Phase 32: Cartographier — Research

**Researched:** 2026-04-20
**Domain:** Route registry-as-code + dual-affordance (CLI + Flutter schema viewer) + parity lint + nLPD controls + CI jobs
**Confidence:** HIGH (stack entirely in-house; 12 decisions locked; panel-validated architecture)

---

## Executive Summary

Phase 32 ships a machine-readable source of truth for the 147 GoRoute/ScopedGoRoute entries in `apps/mobile/lib/app.dart` (reconciled 2026-04-20), with a dual-affordance surface: CLI `./tools/mint-routes` for live health via Sentry Issues API, Flutter `/admin/routes` as a pure schema viewer (iOS sandbox makes cross-filesystem snapshot reads impossible — v4 simplification). Parity lint prevents code↔registry drift. 43 legacy redirects gain analytics breadcrumbs for 30-day zero-traffic validation before v2.9 sunset.

**Top findings:**
1. **GoRouter auto-sets transaction.name = route path [VERIFIED: Sentry Flutter SDK docs]** — `SentryNavigatorObserver` at `app.dart:184` already wires this. D-07 query pattern `transaction:<path>` works out-of-the-box; J0 smoke test in D-11 validates empirically.
2. **Sentry search list-syntax `transaction:[foo, bar]` = equivalent to `transaction:foo OR transaction:bar` [VERIFIED: Sentry search docs]** — simpler to build, avoids ambiguous precedence. Exact term limit per query not documented; D-11 J0 empirically determines (target ≥30).
3. **`_routerObservers` is a top-level `final List<NavigatorObserver>` in `app.dart`** — ready for testOnly inspection, no modification needed for Phase 32.
4. **No `AdminScaffold` exists today** — 2 admin screens (`admin_observability_screen.dart`, `admin_analytics_screen.dart`) exist as profile sub-routes at `app.dart:905-921` without a shared shell. Phase 32 ships the shared shell; Phase 33 reuses it.
5. **No `/admin/me` backend endpoint exists** — only `endpoints/auth.py` contains "/admin" mentions (grep confirmed). D-10 local-FF-only strategy is forced, not preferred.
6. **Prod build workflows (`testflight.yml`, `play-store.yml`) do NOT pass `--dart-define=ENABLE_ADMIN`** — tree-shake works by default; the `admin-build-sanity` CI job (D-12) is defensive against future drift.
7. **`sentry-cli 3.3.5` already installed; Keychain pattern already proven in `tools/simulator/sentry_quota_smoke.sh`** — `./tools/mint-routes` inherits verbatim (same service key `SENTRY_AUTH_TOKEN`, same `security find-generic-password -s ... -w` call).

**Primary recommendation:** Plan Wave 0 as reconciliation gate (147/43 grep + KNOWN-MISSES.md extraction) + tree-shake J0 gate (empirical proof before writing the registry). Every subsequent wave consumes the reconciled counts; if Wave 0 finds drift, STOP and amend CONTEXT before writing code.

---

<user_constraints>
## User Constraints (from CONTEXT.md v4)

### Locked Decisions (D-01..D-12)

**D-01 — RouteMeta schema (UNCHANGED v1-v4)**
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
**Owner ambiguity rule (v4 locks)**: for routes spanning multiple domains (e.g., `/coach/chat/from-budget`), **first path segment wins** — i.e., owner = `coach`. Cross-domain context = metadata only, not ownership.

**D-02 — CLI reads Sentry via Keychain, transaction-based query, batch optimization**
- `./tools/mint-routes` (Python 3.10+, argparse stdlib).
- Keychain: `security find-generic-password -s mint-sentry-auth -w`. **Token scope locked D-09**. Validation before any API call: empty token → exit 71 EX_OSERR with setup instruction pointing to `docs/SETUP-MINT-ROUTES.md`.
- **Query pattern**: `transaction:<path>` (SDK `SentryNavigatorObserver` auto-sets `transaction.name` per Phase 31 `app.dart:184` wiring). Gap for async-errors-hors-transaction documented, acceptable.
- **Batch OR-query (v4 J0 validation)**: up to ~200 terms per query. CLI J0 smoke test empirically validates → if yes, 147 routes ÷ 30 per batch = 5 requests = ~15 sec full scan. Fallback: 1 req/sec = 3 min. Both safe; batch optimal for Phase 35 dogfood.
- **Exit codes** sysexits.h: `0 OK`, `2 EX_USAGE`, `71 EX_OSERR` (Keychain), `75 EX_TEMPFAIL` (429/timeout), `78 EX_CONFIG` (401/403).
- **Error differentiation**: 401 → "token invalid/expired" exit 78; 403 + "scope" → "missing event:read scope" exit 78; 429 → exponential backoff 1s/2s/4s → exit 75; network timeout → exit 75.
- **Output modes**: ANSI colors default; `--no-color` flag + `NO_COLOR` env var; `--json` newline-delimited per D-12 schema.
- **DRY_RUN**: `MINT_ROUTES_DRY_RUN=1` reads `tests/tools/fixtures/sentry_health_response.json`.

**D-03 — AdminScaffold Phase 32, reused by Phase 33**
- `lib/screens/admin/admin_shell.dart` — AdminScaffold (appBar + children).
- Compile-time gate: `--dart-define=ENABLE_ADMIN=0` default, `1` for dev. Tree-shaken prod per D-11.
- Runtime gate: **`FeatureFlags.isAdmin` local check (per D-10)** — PAS de backend call.
- Phase 32 ships child 1: `/admin/routes`. Phase 33 adds child 2: `/admin/flags`.

**D-04 — Parity lint regex + KNOWN-MISSES.md + standalone script**
- `tools/checks/route_registry_parity.py` — standalone Python executable, argparse stdlib.
- Compares `app.dart` `GoRoute|ScopedGoRoute(path:...)` extractions vs `kRouteRegistry` keys.
- Ships with `tools/checks/route_registry_parity-KNOWN-MISSES.md` documenting multi-line / ternary / dynamic / conditional patterns regex skips.
- Wave 0 action: extract all `app.dart` patterns matching known-miss categories, populate `KNOWN-MISSES.md` with real examples BEFORE registry write.
- CI integration wired in D-12. Lefthook wiring = Phase 34 scope.

**D-05 — Redirect legacy analytics via Sentry breadcrumb, count corrected**
- 43 redirects emit `mint.routing.legacy_redirect.hit` breadcrumb with `data: {from, to}` before redirect.
- Math: 43 × 10 hits/day × 30 = 12'900 events/mo = **0.258% Sentry Business 50k/mo**. At 5k DAU real scale = ~1-2% quota (still safely under $160 ceiling). Revisit at 10k DAU for Enterprise.
- Breadcrumb data redacted per D-09 (from/to paths only, no query params, no user context).

**D-06 — Dual affordance, Flutter UI = pure schema viewer**
- **CLI** (MAP-02a): full live health via Sentry, `--json`, quality bar per D-02 + D-12.
- **Flutter UI `/admin/routes`** (MAP-02b): **REGISTRY SCHEMA VIEWER ONLY**.
  - Columns: `path | category | owner | requiresAuth | killFlag | FeatureFlags enabled (local) | description`
  - Grouped by owner (15 buckets collapsible).
  - Source: `kRouteRegistry` (static const) + `FeatureFlags` (runtime local).
  - **PAS de Sentry health data, PAS de snapshot JSON read, PAS de backend call.**
  - Footer: "use `./tools/mint-routes health` terminal" for live health.

**D-07 — Route-tag query pattern (UNCHANGED v3)**
CLI queries `transaction:<path>` using SDK's built-in `transaction.name = routePath` auto-setting. **J0 smoke test in D-11 validates empirically.**

**D-08 — CLI + Flutter UI quality bar**
- **CLI**: sysexits.h exit codes, `--json` mode, `--no-color` + `NO_COLOR`, `MINT_ROUTES_DRY_RUN=1` fixture, pytest unit tests.
- **Flutter UI**: tree-shake VALIDATION per D-11, `Semantics(label: ...)`, empty-state "Registry not generated", FF `select` memoization.

**D-09 — nLPD compliance controls (SHIP WITH PHASE 32)**
1. **Token scope minimization**: `SENTRY_AUTH_TOKEN` MUST have only `project:read` + `event:read`. Optional `--verify-token` one-shot check.
2. **Event redaction layer**: CLI strips `user.*` (id/email/ip/username), `breadcrumb.data.user_*`, CHF >100 → `CHF [REDACTED]`, IBAN → `CH[REDACTED]`, email → `[EMAIL]`. JSON output metadata: `{_redaction_applied: true, _redaction_version: 1}`.
3. **Snapshot retention** (if Phase 35 writes `.cache/route-health.json`): 7-day auto-delete on CLI startup. `./tools/mint-routes purge-cache` emergency command. `.cache/` in `.gitignore` (CI gate verifies).
4. **Admin access log**: Flutter UI `/admin/routes` mount emits breadcrumb `mint.admin.routes.viewed` with `data: {route_count, feature_flags_enabled_count, snapshot_age_minutes}` — zero PII, aggregates only.
5. **Keychain hardening**: `security add-generic-password -a $USER -s mint-sentry-auth -w $TOKEN -U -A` (single user, this device only).

**nLPD Art. mapping**: Art. 5 accuracy (D-07 gap doc'd), Art. 6 minimization (token scope + redaction), Art. 9 storage limitation (7d retention), Art. 12 processing record (admin breadcrumb), Art. 7 security (Keychain hardening).

**D-10 — AdminProvider.isAllowed via FeatureFlags.isAdmin local**
- `AdminProvider.isAllowed` returns `FeatureFlags.isAdmin` — NO backend call.
- Trade-off: compile-time gate `ENABLE_ADMIN=1` + runtime `FeatureFlags.isAdmin` = two gates but both LOCAL. Adequate for solo dev-only.
- `FeatureFlags.isAdmin` = static getter reading constant/env for Phase 32 (hardcoded `true` when ENABLE_ADMIN=1). Phase 33 may evolve to ChangeNotifier.

**D-11 — 32-VALIDATION.md artefact**
1. Tree-shake gate: `flutter build ios --simulator --release --no-codesign --dart-define=ENABLE_ADMIN=0` → `strings Runner | grep kRouteRegistry` = 0.
2. J0 SentryNavigatorObserver smoke: install staging build, trigger 1 error on 3 test routes (`/coach`, `/budget`, `/scan`), wait 60s, verify `./tools/mint-routes health --json | jq` returns those 3 routes.
3. Batch OR-query validation: curl Sentry API with 30-route OR query, verify 2xx + results.
4. Parity lint local run: clean output + KNOWN-MISSES.md entries match observed patterns.
5. CLI DRY_RUN test: fixture data without network.
6. Flutter UI smoke: walker.sh opens `/admin/routes`, screenshot 147 routes grouped by owner.

**D-12 — CI integration**
1. `route-registry-parity` job in `.github/workflows/ci.yml` — runs `python3 tools/checks/route_registry_parity.py` on every push. Runtime ≤ 30s.
2. `mint-routes-tests` job — runs `pytest tests/tools/test_mint_routes.py -q` with `MINT_ROUTES_DRY_RUN=1`. Fixture committed.
3. `admin-build-sanity` job — scans `testflight.yml` + `play-store.yml` for `--dart-define=ENABLE_ADMIN=1` in prod build. Runtime ≤ 5s.
4. Schema publication: `lib/routes/route_health_schema.dart` committed (`schemaVersion: 1`).
5. Lefthook wiring = Phase 34 scope (Phase 32 ships `.lefthook/route_registry_parity.sh` standalone).
6. `docs/SETUP-MINT-ROUTES.md` ships with Phase 32.

### Claude's Discretion
- Exact `AdminProvider` class shape (ChangeNotifier vs static getter).
- Exact Flutter UI layout (ListView.builder vs CustomScrollView).
- Exact Sentry batch OR-query term limit (30 vs 50 vs 100) — D-11 J0 empirical.
- Exact CLI sub-command surface (`health`, `redirects`, `reconcile` locked; `purge-cache` optional).
- Exact `.cache/` path resolution (`~/.cache/mint/` vs `./.cache/` repo-local) — `.gitignore` entry mandatory.

### Deferred Ideas (OUT OF SCOPE)
- Backend endpoint `/api/v1/admin/*` — v2.9+ if multi-user admin needed.
- Codegen via `build_runner` — v2.9+ if >5 regex false negatives.
- AST-based parity lint — v2.9+.
- Filter/search/export CLI + UI — MVP strict v2.8.
- Backend OpenAPI parity — v2.9+ MAP-06.
- Sunset 43 redirects — v2.9+ after 30-day zero-traffic.
- Per-route flag — v2.9+.
- Phase 31 retroactive `scope.setTag('route')` patch — only if J0 reveals SDK doesn't auto-set.
- Heatmap user paths (DIFF-02) — v2.9+.
- Sentry tier upgrade Enterprise — trigger 5-10k DAU.
</user_constraints>

<phase_requirements>
## Phase Requirements (MAP-01..05 split into a/b)

| ID | Description | Research Support |
|----|-------------|------------------|
| **MAP-01** | Route registry-as-code `lib/routes/route_metadata.dart` — `kRouteRegistry: Map<String, RouteMeta>` with 147 entries (path, category, owner, requiresAuth, killFlag) | §Route registry schema (Dart) — locks exact `RouteMeta` class shape, enum definitions, tree-shake patterns, publication location next to `app.dart`. |
| **MAP-02a** | CLI `./tools/mint-routes {health\|redirects\|reconcile}` (Python argparse stdlib, Keychain auth, transaction:<path> query, sysexits.h, `--json`, `--no-color`, DRY_RUN, PII redaction per D-09) | §CLI `./tools/mint-routes` — locks Python stdlib argparse shape, sentry_quota_smoke.sh reuse pattern (Keychain + stats_v2 via stdin), redaction regex patterns, exit code mapping, DRY_RUN fixture harness. |
| **MAP-02b** | Flutter UI `/admin/routes` pure schema viewer dev-only (compile-time `ENABLE_ADMIN=1` + runtime `FeatureFlags.isAdmin` local — NO backend endpoint) | §Flutter UI `/admin/routes` — locks GoRouter admin shell insertion point (`_rootNavigatorKey` parented), AdminProvider pattern, collapsible owner groups ListView.builder, FF `select` memoization, tree-shake proof flow. |
| **MAP-03** | Route health data join CLI EXCLUSIVE (registry × Sentry Issues API last 24h × FeatureFlags × last-visited breadcrumbs) → vert/jaune/rouge/dead per route in terminal | §CLI health data join — locks Sentry list-syntax `transaction:[/a, /b, ...]` (simpler than explicit OR), 24h window, batch chunking (30-route batches), fallback to sequential on batch failure, status color mapping. |
| **MAP-04** | `tools/checks/route_registry_parity.py` lint standalone + `KNOWN-MISSES.md` + CI job | §Parity lint script — locks regex for `(GoRoute\|ScopedGoRoute)\s*\(` + path string extraction, known-miss categories (multi-line, ternary, dynamic, conditional), Wave 0 extraction flow (populate KNOWN-MISSES before writing registry). |
| **MAP-05** | Analytics hit-counter on 43 redirects via Sentry breadcrumb `mint.routing.legacy_redirect.hit` (paths only, PII redacted) + CLI redirects subcommand | §Redirect analytics breadcrumb — locks breadcrumb category D-03 style `mint.routing.legacy_redirect.hit`, `data: {from, to}` only, reuses `MintBreadcrumbs` pattern. CLI `redirects` subcommand queries breadcrumb over 30d. |
</phase_requirements>

---

## Project Constraints (from CLAUDE.md)

- **Banned LSFin terms** — NEVER `garanti`, `optimal`, `meilleur`, `certain`, `assure`, `sans risque`, `parfait`. CLI and Flutter UI user-facing text respects this. (Phase 32 surfaces are dev-only — low exposure — but doctrine holds.)
- **Accents 100% FR mandatory** — `creer → créer`, `eclairage → éclairage`. Lint via `tools/checks/accent_lint_fr.py`. Flutter UI footer note + CLI `--help` strings respect this.
- **MINT ≠ retirement app** — N/A for Phase 32 (dev-only surfaces). No user-facing copy to audit.
- **Financial_core reuse** — N/A (no financial calculation in Phase 32).
- **i18n required for user-facing strings** — `/admin/routes` is dev-only English-or-bare acceptable (via `--dart-define=ENABLE_ADMIN=1` dev builds), but `Semantics(label:)` values still respect existing conventions. No ARB additions needed.
- **Feature branch discipline** — Phase 32 work on `feature/v2.8-phase-32-cartographier` from `dev`. Never force push. Always `--rebase` on pull.
- **Never commit without audit** — each wave ships via feature branch PR, not direct dev push.
- **Doctrine**: `feedback_facade_sans_cablage` (câbler end-to-end per wave), `feedback_no_shortcuts_ever` (parfait ou P0), `feedback_tests_green_app_broken` (creator-device gate for Flutter UI sub-task), `feedback_audit_methodology` + `feedback_audit_multi_pass` (7-pass audit before ship).

---

## Validation Architecture

**Nyquist validation: ENABLED** (config.json `workflow.nyquist_validation: true`).

### Test Framework

| Property | Value |
|----------|-------|
| Flutter framework | Flutter 3.41.6 (`flutter test`) [VERIFIED: `flutter --version`] |
| Flutter config | `apps/mobile/pubspec.yaml` (test dependencies), test discovery under `apps/mobile/test/` sharded by dir (services/widgets/screens per `.github/workflows/ci.yml:330-365`) |
| Python framework | pytest (already used in `services/backend/tests/` + `tools/` lints) [VERIFIED: `ci.yml:217`] |
| Python quick run | `pytest tests/tools/test_mint_routes.py -q` with `MINT_ROUTES_DRY_RUN=1` |
| Flutter quick run | `cd apps/mobile && flutter test test/routes/route_metadata_test.dart test/screens/admin/routes_registry_screen_test.dart` |
| Full suite | `cd apps/mobile && flutter test` + `cd services/backend && pytest tests/ -q` |
| Parity gate | `python3 tools/checks/route_registry_parity.py` (standalone, ≤30s) |
| Tree-shake gate | Manual CLI — `flutter build ios --simulator --release --no-codesign --dart-define=ENABLE_ADMIN=0` + `strings` check |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MAP-01 | `kRouteRegistry` has exactly 147 entries, all paths match `app.dart` routes, enum values legal | unit | `flutter test test/routes/route_metadata_test.dart` | ❌ Wave 0 |
| MAP-01 | `RouteMeta` enums serialize stable (JSON schema stable across builds) | unit | `flutter test test/routes/route_meta_json_test.dart` | ❌ Wave 0 |
| MAP-01 | Tree-shake removes `kRouteRegistry` from prod IPA when `ENABLE_ADMIN=0` | integration (manual) | `flutter build ios --simulator --release --no-codesign --dart-define=ENABLE_ADMIN=0 && strings build/ios/iphonesimulator/Runner.app/Runner \| grep -c kRouteRegistry` | ❌ D-11 VALIDATION.md (Wave 4) |
| MAP-02a | CLI `health` DRY_RUN returns fixture data with valid JSON schema | unit | `MINT_ROUTES_DRY_RUN=1 pytest tests/tools/test_mint_routes.py::test_health_dry_run -q` | ❌ Wave 0 |
| MAP-02a | CLI exit codes match sysexits.h (0, 2, 71, 75, 78) | unit | `pytest tests/tools/test_mint_routes.py::test_exit_codes -q` | ❌ Wave 0 |
| MAP-02a | CLI redaction layer masks IBAN, CHF>100, email, user fields | unit | `pytest tests/tools/test_mint_routes.py::test_pii_redaction -q` | ❌ Wave 0 |
| MAP-02a | CLI `--no-color` + `NO_COLOR` env var both suppress ANSI | unit | `pytest tests/tools/test_mint_routes.py::test_no_color -q` | ❌ Wave 0 |
| MAP-02a | Keychain fallback path (env var wins, else `security find-generic-password`) | unit (mocked) | `pytest tests/tools/test_mint_routes.py::test_keychain_fallback -q` | ❌ Wave 0 |
| MAP-02a | Batch OR-query chunks 147 routes into ≤ batch_size-sized requests | unit | `pytest tests/tools/test_mint_routes.py::test_batch_chunking -q` | ❌ Wave 0 |
| MAP-02a | Batch OR-query actually returns results against live Sentry (≥30 terms) | J0 empirical | `./tools/mint-routes health --batch-size=30` against staging token | D-11 §J0 Task 3 |
| MAP-02b | `/admin/routes` only accessible with `ENABLE_ADMIN=1` + `FeatureFlags.isAdmin = true` | widget | `flutter test test/screens/admin/admin_shell_gate_test.dart` | ❌ Wave 0 |
| MAP-02b | `/admin/routes` renders 147 routes grouped by 15 owner buckets | widget | `flutter test test/screens/admin/routes_registry_screen_test.dart` | ❌ Wave 0 |
| MAP-02b | `/admin/routes` mount emits `mint.admin.routes.viewed` breadcrumb with aggregates only | widget | `flutter test test/screens/admin/routes_registry_breadcrumb_test.dart` | ❌ Wave 0 |
| MAP-02b | Creator-device smoke on iPhone 17 Pro sim via walker.sh | manual (gated) | `bash tools/simulator/walker.sh --scenario=admin-routes` + screenshot review | D-11 §J0 Task 6 |
| MAP-03 | CLI `health` joins registry × Sentry 24h × FeatureFlags → 4 status buckets (green/yellow/red/dead) | unit | `pytest tests/tools/test_mint_routes.py::test_status_classification -q` | ❌ Wave 0 |
| MAP-03 | CLI `health --json` emits newline-delimited JSON per D-12 `route_health_schema.dart` | unit | `pytest tests/tools/test_mint_routes.py::test_json_output_schema -q` | ❌ Wave 0 |
| MAP-03 | Schema `route_health_schema.dart` matches CLI JSON output byte-exact | contracts (drift) | `pytest tests/tools/test_mint_routes.py::test_schema_contract_parity -q` | ❌ Wave 0 |
| MAP-04 | Parity lint detects `GoRoute\|ScopedGoRoute(path:)` in `app.dart` absent from `kRouteRegistry` and vice-versa | unit | `python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_drift.dart` | ❌ Wave 0 |
| MAP-04 | Parity lint respects `KNOWN-MISSES.md` (multi-line, ternary, dynamic, conditional) | unit | `python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_known_miss.dart` | ❌ Wave 0 |
| MAP-04 | Parity lint clean on pristine Phase 32 checkout | integration | `python3 tools/checks/route_registry_parity.py` exits 0 | D-11 §J0 Task 4 |
| MAP-05 | 43 redirects each emit `mint.routing.legacy_redirect.hit` breadcrumb with `data: {from, to}` (no query params, no user) | widget | `flutter test test/routes/legacy_redirect_breadcrumb_test.dart` | ❌ Wave 0 |
| MAP-05 | CLI `redirects` subcommand aggregates hit-count 30d per legacy path | unit | `pytest tests/tools/test_mint_routes.py::test_redirects_aggregation -q` | ❌ Wave 0 |

### Sampling Rate

- **Per task commit:** `flutter test test/routes/ test/screens/admin/` (≤30s on M-series) + `pytest tests/tools/test_mint_routes.py -q` (≤10s DRY_RUN).
- **Per wave merge:** parity lint (`python3 tools/checks/route_registry_parity.py`) + full Flutter shard touched by wave + full backend tests if any backend file touched.
- **Phase gate (pre-`/gsd-verify-work`):** full suite green + tree-shake manual CLI + walker.sh creator-device smoke + 32-VALIDATION.md fully green (6 tasks).

### Wave 0 Gaps

- [ ] `apps/mobile/test/routes/route_metadata_test.dart` — covers MAP-01 entry count + enum integrity.
- [ ] `apps/mobile/test/routes/route_meta_json_test.dart` — covers MAP-01 JSON stability.
- [ ] `apps/mobile/test/screens/admin/admin_shell_gate_test.dart` — covers MAP-02b compile+runtime gate.
- [ ] `apps/mobile/test/screens/admin/routes_registry_screen_test.dart` — covers MAP-02b rendering.
- [ ] `apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart` — covers D-09 access-log breadcrumb.
- [ ] `apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart` — covers MAP-05 breadcrumb shape.
- [ ] `tests/tools/test_mint_routes.py` — 8+ unit tests per row table above.
- [ ] `tests/tools/fixtures/sentry_health_response.json` — 147-route fixture for DRY_RUN.
- [ ] `tests/checks/fixtures/parity_drift.dart` — fixture for parity lint drift path.
- [ ] `tests/checks/fixtures/parity_known_miss.dart` — fixture for KNOWN-MISSES patterns.
- [ ] `tools/checks/route_registry_parity-KNOWN-MISSES.md` — populated with real `app.dart` patterns discovered during Wave 0 extraction.
- [ ] `.planning/phases/32-cartographier/32-VALIDATION.md` — D-11 artefact with 6 tasks.
- [ ] Framework install: none (Flutter + pytest already in place).

---

## Implementation Findings

### 1. Route registry schema (Dart) — MAP-01

**Location:** `apps/mobile/lib/routes/route_metadata.dart` (new directory; `lib/routes/` does not exist yet [VERIFIED: ls]).

**Exact `RouteMeta` shape (D-01 locked, UNCHANGED v1-v4):**
```dart
// lib/routes/route_metadata.dart
import 'route_category.dart';
import 'route_owner.dart';

class RouteMeta {
  final String path;
  final RouteCategory category;  // {destination, flow, tool, alias}
  final RouteOwner owner;         // 15-value enum
  final bool requiresAuth;
  final String? killFlag;         // references Phase 33 FeatureFlags key
  final String? description;      // optional, dev-only
  final String? sentryTag;        // optional override; null → fall back to `path` at query time

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

/// D-01 v4 owner ambiguity rule: first path segment wins.
enum RouteOwner {
  // 11 flag-group owners (align with Phase 33 FLAG-05)
  retraite, famille, travail, logement, fiscalite, patrimoine, sante,
  coach, scan, budget, anonymous,
  // 4 infra owners
  auth, admin, system, explore,
}

enum RouteCategory { destination, flow, tool, alias }
```

**Registry publication:**
```dart
const Map<String, RouteMeta> kRouteRegistry = {
  '/': RouteMeta(
    path: '/',
    category: RouteCategory.destination,
    owner: RouteOwner.anonymous,
    requiresAuth: false,
  ),
  // ... 146 more
};
```

**Tree-shake mechanics [VERIFIED: existing `--dart-define` pattern in main.dart:119]:**
- `const` top-level `kRouteRegistry` is tree-shake candidate when no runtime reference reaches it.
- Admin shell is the only consumer. Compile-time gate:
  ```dart
  // lib/screens/admin/admin_shell.dart
  const bool kIsAdminEnabled = bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false);
  ```
- In `app.dart`, admin routes declared inside `if (kIsAdminEnabled) ... ` conditional block (or via separate route list merged at compile time). Dart dead-code elimination strips the branch when false, detaching `kRouteRegistry`.
- **Tree-shake proof method:** `flutter build ios --simulator --release --no-codesign --dart-define=ENABLE_ADMIN=0` then `strings build/ios/iphonesimulator/Runner.app/Runner | grep -c kRouteRegistry` expects **0** [CITED: D-11 VALIDATION §task 1].

**Owner ambiguity rule enforcement [VERIFIED: CONTEXT.md v4 D-01]:**
- `/coach/chat/from-budget` → owner = `coach` (first segment wins).
- `/explore/retraite` → owner = `explore` (first segment) — note: despite "retraite" in path, ownership is `explore` because Explorer hub routes root from `/explore/`. [ASSUMED: Julien intent; verify with planner.]
- Actual hub target routes like `/retraite`, `/pilier-3a` → owner = `retraite`, `fiscalite` respectively.

**KnownAsymmetry:** 11 flag-group owners align with Phase 33 FLAG-05 11 groups, NOT 1:1 with 147 routes. Most routes map owner via first segment; ambiguities (e.g., `/retraite` literally owned by retraite flag group vs `/explore/retraite` owned by explore) need explicit RouteMeta declarations — cannot auto-derive.

### 2. CLI `./tools/mint-routes` — MAP-02a + MAP-03

**Location:** `tools/mint-routes` (Python 3.10+ executable, shebang `#!/usr/bin/env python3`). Matches `tools/simulator/sentry_quota_smoke.sh` sibling pattern.

**Package layout (executor discretion):**
```
tools/mint-routes           # entrypoint shim (shebang + import from lib)
tools/mint_routes/__init__.py
tools/mint_routes/cli.py    # argparse + subcommand dispatch
tools/mint_routes/sentry_client.py  # Keychain, Issues API, batching
tools/mint_routes/redaction.py      # PII stripping per D-09
tools/mint_routes/output.py         # ANSI + JSON + NO_COLOR
tools/mint_routes/dry_run.py        # fixture harness
tests/tools/test_mint_routes.py
tests/tools/fixtures/sentry_health_response.json
```

Alternative (simpler for <500 LOC, executor choice): single-file `tools/mint-routes` Python script.

**argparse command surface (D-02 locked):**
```
./tools/mint-routes health     [--json] [--no-color] [--batch-size=N] [--owner=X]
./tools/mint-routes redirects  [--json] [--no-color] [--days=30]
./tools/mint-routes reconcile                # runs parity lint internally
./tools/mint-routes purge-cache              # D-09 §3 emergency cache wipe
./tools/mint-routes --verify-token           # D-09 §1 token-scope sanity
```

**Keychain reuse pattern [VERIFIED: tools/simulator/sentry_quota_smoke.sh:70-84]:**
```python
import os, subprocess

def get_sentry_token() -> str:
    # 1. env var wins (staging/CI)
    tok = os.environ.get("SENTRY_AUTH_TOKEN", "")
    if tok:
        return tok
    # 2. Keychain fallback (dev machine)
    try:
        r = subprocess.run(
            ["security", "find-generic-password", "-s", "SENTRY_AUTH_TOKEN", "-w"],
            capture_output=True, text=True, timeout=5,
        )
        if r.returncode == 0:
            return r.stdout.strip()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    # 3. Fail clearly per D-02 exit 71 EX_OSERR
    sys.stderr.write(
        "[FAIL] SENTRY_AUTH_TOKEN missing — see docs/SETUP-MINT-ROUTES.md\n"
        "       security add-generic-password -a $USER -s SENTRY_AUTH_TOKEN -w <token> -U -A\n"
    )
    sys.exit(71)  # EX_OSERR
```

**CRITICAL NAMING ASYMMETRY:** CONTEXT v4 D-02 says service name is `mint-sentry-auth`; but `sentry_quota_smoke.sh:72` already uses `SENTRY_AUTH_TOKEN` as service name. **Planner must decide:** (a) reuse existing `SENTRY_AUTH_TOKEN` service name (zero onboarding friction, breaks D-02 literal), or (b) introduce `mint-sentry-auth` per D-02 (requires dual-keychain setup or docs to migrate). **Recommendation: reuse `SENTRY_AUTH_TOKEN`** — consistency wins, Phase 31 already installed it. Amend D-02 note in CONTEXT as executor clarification (per-CONTEXT Claude Discretion §1).

**Sentry Issues API query construction [VERIFIED: Sentry search docs]:**
- Endpoint: `/api/0/organizations/{org}/issues/?query=<url-encoded>&statsPeriod=24h&project=<id>`.
- **List syntax**: `query=transaction:[/a, /b, /c]` — equivalent to `transaction:/a OR transaction:/b OR transaction:/c` but cleaner construction. [VERIFIED: docs.sentry.io/concepts/search] — "You can search multiple values for the same key by putting the values in a list."
- **sentry-cli wrapper** (installed 3.3.5 [VERIFIED: `sentry-cli --version`]): same request via `sentry-cli api /organizations/mint/issues/...`. Alternative: `requests` library direct to Sentry API with `Authorization: Bearer <token>` header.
- **Batch chunking**: split 147 routes into chunks of 30 (D-11 J0 target). Pseudocode:
  ```python
  def batch_query(paths: list[str], batch_size: int = 30) -> dict:
      results = {}
      for chunk in chunked(paths, batch_size):
          q = f"transaction:[{', '.join(chunk)}]"
          try:
              r = call_sentry_api(query=q, stats_period="24h")
              results.update(index_by_transaction(r))
          except BatchQueryTooLargeError:
              # Fallback per D-02: 1 req/sec sequential
              for p in chunk:
                  results[p] = call_sentry_api(query=f"transaction:{p}")
                  time.sleep(1.0)
      return results
  ```
- **Empirical limit (D-11 J0 Task 3):** curl 30-term list query, verify 2xx. If 414 URI Too Long or 400, halve batch_size, retry. Lock final value in CLI source + VALIDATION.md.

**sysexits.h exit codes [VERIFIED: POSIX convention]:**
```python
EX_OK       = 0
EX_USAGE    = 2    # argparse default for bad args
EX_DATAERR  = 65   # (unused Phase 32)
EX_CONFIG   = 78   # 401/403 token issues
EX_TEMPFAIL = 75   # 429 rate limit, network timeout (after retry)
EX_OSERR    = 71   # Keychain missing, sentry-cli missing
```

**Output modes [VERIFIED: NO_COLOR standard no-color.org]:**
```python
def should_use_color(args) -> bool:
    if args.no_color: return False
    if os.environ.get("NO_COLOR"):  # any non-empty value disables
        return False
    if not sys.stdout.isatty():  # piped → no color
        return False
    return True
```

**DRY_RUN fixture harness [VERIFIED: sentry_quota_smoke.sh:99-105 pattern]:**
```python
DRY_RUN = os.environ.get("MINT_ROUTES_DRY_RUN") == "1"
if DRY_RUN:
    fixture_path = Path(__file__).parent.parent / "tests/tools/fixtures/sentry_health_response.json"
    raw = fixture_path.read_text()
    sentry_response = json.loads(raw)
else:
    sentry_response = call_sentry_api(...)
# Same code path downstream — this is the pitfall-10 mitigation.
```

**PII redaction regex patterns (D-09 §2) [ASSUMED: patterns below are standard, verify with planner]:**
```python
import re

IBAN_CH = re.compile(r"CH\d{2}[\d\s]{15,30}")
EMAIL = re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b")
CHF_AMOUNT = re.compile(r"\bCHF\s*([\d']+(?:\.\d{2})?)\b", re.IGNORECASE)
USER_ID_KEYS = ("id", "email", "ip_address", "username")  # under event.user.*

def redact(obj):
    """Walk Sentry event JSON, strip PII in place."""
    if isinstance(obj, dict):
        if "user" in obj and isinstance(obj["user"], dict):
            for k in USER_ID_KEYS:
                obj["user"].pop(k, None)
        for k, v in list(obj.items()):
            if k.startswith("user_"):
                obj[k] = "[REDACTED]"
            elif isinstance(v, str):
                obj[k] = _redact_str(v)
            else:
                obj[k] = redact(v)
    elif isinstance(obj, list):
        return [redact(x) for x in obj]
    return obj

def _redact_str(s: str) -> str:
    s = IBAN_CH.sub("CH[REDACTED]", s)
    s = EMAIL.sub("[EMAIL]", s)
    s = CHF_AMOUNT.sub(lambda m: f"CHF [REDACTED]" if _extract_chf(m.group(1)) > 100 else m.group(0), s)
    return s
```

**Known redaction false-negative risks (planner to flag):**
- CHF amounts without explicit "CHF" prefix (e.g., "1'500.–") — won't match.
- Non-Swiss IBAN (DE, FR) — not redacted. **Decide in planning: redact all IBANs or CH only?**
- User ID embedded in URL query params — redact URL query params entirely (safer).
- Email without TLD (intranet form) — won't match.

**Status classification (MAP-03):**
```python
def classify(route: str, sentry_24h: int, ff_state: bool, last_visit: Optional[datetime]) -> str:
    if not ff_state:
        return "dead"    # killed via flag
    if sentry_24h >= 10:
        return "red"     # high error rate
    if sentry_24h >= 1:
        return "yellow"  # some errors
    if last_visit is None or (datetime.utcnow() - last_visit).days > 30:
        return "dead"    # no traffic 30d → candidate for sunset
    return "green"       # healthy
```

### 3. Flutter UI `/admin/routes` — MAP-02b

**Location:** `apps/mobile/lib/screens/admin/admin_shell.dart` + `routes_registry_screen.dart` + `route_health_schema.dart`.

**Gate chain (D-03 + D-10):**
```dart
// lib/screens/admin/admin_gate.dart
class AdminGate {
  static const bool _compileTimeEnabled =
      bool.fromEnvironment('ENABLE_ADMIN', defaultValue: false);

  /// Two LOCAL gates — NO backend call (D-10 v4).
  static bool get isAvailable =>
      _compileTimeEnabled && FeatureFlags.isAdmin;
}
```

**FeatureFlags.isAdmin addition [VERIFIED: feature_flags.dart has no `isAdmin` field yet]:**
```dart
// Addition to lib/services/feature_flags.dart
class FeatureFlags {
  /// D-10: local runtime gate for /admin/*. Combined with compile-time
  /// ENABLE_ADMIN=1 via AdminGate. NO backend call.
  ///
  /// Phase 32: hardcoded true when ENABLE_ADMIN=1 (dev-only tool).
  /// Phase 33: may evolve to ChangeNotifier for /admin/flags live toggle.
  static bool get isAdmin => AdminGate._compileTimeEnabled;  // equivalent to _compileTimeEnabled in Phase 32
}
```

**GoRouter insertion point in `app.dart` [VERIFIED: `_rootNavigatorKey` exists at line 143, redirect callback at 194]:**
```dart
// After existing /explore/* routes, before redirects block:
if (AdminGate.isAvailable) ...[
  ScopedGoRoute(
    path: '/admin/routes',
    parentNavigatorKey: _rootNavigatorKey,
    scope: RouteScope.authenticated,  // extra safety
    builder: (context, state) => const AdminShell(
      child: RoutesRegistryScreen(),
    ),
  ),
  // Phase 33 will add /admin/flags here (D-03 shell reuse)
],
```

**AdminShell pattern (D-03):**
```dart
// lib/screens/admin/admin_shell.dart
class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      appBar: AppBar(
        title: const Text('MINT Admin'),  // dev-only, no i18n per CLAUDE.md carve-out
        backgroundColor: MintColors.surface,
      ),
      body: child,
    );
  }
}
```

**Registry screen structure (D-06 + D-08):**
```dart
class RoutesRegistryScreen extends StatefulWidget {
  const RoutesRegistryScreen({super.key});

  @override
  void initState() {
    super.initState();
    // D-09 §4: admin access log breadcrumb (aggregates only)
    MintBreadcrumbs.adminRoutesViewed(
      routeCount: kRouteRegistry.length,
      featureFlagsEnabledCount: _countEnabledFlags(),
      snapshotAgeMinutes: null,  // N/A — no snapshot in UI per D-06
    );
  }

  @override
  Widget build(BuildContext context) {
    // D-08 perf: `select` on FeatureFlags.changes (Phase 33 will supply
    // ChangeNotifier; Phase 32 reads static fields — no listener needed).
    final grouped = _groupByOwner(kRouteRegistry);
    return ListView.builder(
      itemCount: RouteOwner.values.length,
      itemBuilder: (ctx, i) {
        final owner = RouteOwner.values[i];
        final routes = grouped[owner] ?? const [];
        return ExpansionTile(
          title: Semantics(
            label: 'Routes owned by ${owner.name}, ${routes.length} entries',
            child: Text('${owner.name} (${routes.length})'),
          ),
          children: routes.map(_buildRow).toList(),
        );
      },
    );
  }
}
```

**Empty-state handling (D-08):**
```dart
if (kRouteRegistry.isEmpty) {
  return const Center(
    child: Text('Registry not generated. Run tools/mint-routes reconcile.'),
  );
}
```

**Footer note (D-06):**
```dart
// At bottom of RoutesRegistryScreen:
Padding(
  padding: const EdgeInsets.all(16),
  child: Text(
    'Live health status: use `./tools/mint-routes health` terminal.\n'
    'This screen shows static schema + local FeatureFlags state only.',
    style: MintTextStyles.bodySmall(color: MintColors.textMuted),
  ),
)
```

**MintBreadcrumbs extension (D-09 §4):**
```dart
// Addition to lib/services/sentry_breadcrumbs.dart
static void adminRoutesViewed({
  required int routeCount,
  required int featureFlagsEnabledCount,
  int? snapshotAgeMinutes,
}) {
  Sentry.addBreadcrumb(Breadcrumb(
    category: 'mint.admin.routes.viewed',
    level: SentryLevel.info,
    data: {
      'route_count': routeCount,
      'feature_flags_enabled_count': featureFlagsEnabledCount,
      if (snapshotAgeMinutes != null) 'snapshot_age_minutes': snapshotAgeMinutes,
    },
  ));
}
```

### 4. Parity lint `tools/checks/route_registry_parity.py` — MAP-04

**Location:** `tools/checks/route_registry_parity.py` (standalone, stdlib only, per existing pattern `accent_lint_fr.py` / `no_hardcoded_fr.py` [VERIFIED: ls tools/checks]).

**Extraction regex (D-04 locked):**
```python
# Matches both GoRoute and ScopedGoRoute path declarations.
# Requires the literal `path:` kwarg on the same logical construct.
# Captures the path string (accepts single or double quotes).
_GOROUTE_RE = re.compile(
    r"""(GoRoute|ScopedGoRoute)\s*\(\s*
        (?:.*?,\s*)?           # any preceding kwargs (scope:, name:, etc.)
        path\s*:\s*            # the path kwarg
        (['"])([^'"]+?)\2      # captured path string
    """,
    re.VERBOSE | re.DOTALL,
)
```

**Known miss categories (D-04 ships with examples):**
1. **Multi-line constructor bodies** — the `.DOTALL` flag handles simple cases, but deeply nested builders with comments between `(` and `path:` may slip.
2. **Ternary path** — `path: isNew ? '/v2' : '/legacy'` — neither captured. Rare, but grep-audit Wave 0.
3. **Dynamic path builder** — `path: _buildPath(segment)` — regex can't trace. Declare as known-miss.
4. **Conditional route list** — `if (flag) GoRoute(...)` — the route itself is captured, but the conditional context is lost. Parity lint treats as "exists". Acceptable.

**Wave 0 extraction flow [CRITICAL]:**
```bash
# Dry-run extraction vs current app.dart
python3 tools/checks/route_registry_parity.py --extract-only apps/mobile/lib/app.dart \
  | sort -u > /tmp/extracted_routes.txt
wc -l /tmp/extracted_routes.txt  # Expect 147 (or document drift in KNOWN-MISSES)
grep -cE "ScopedGoRoute\(|GoRoute\(" apps/mobile/lib/app.dart  # Expect 150 (147 + 3 bare GoRoute)
```

Populate `KNOWN-MISSES.md` BEFORE writing `kRouteRegistry` — otherwise regex will miss paths and parity lint will false-positive during registry construction.

**`kRouteRegistry` keys extraction:**
```python
_REGISTRY_KEY_RE = re.compile(r"""^\s*(['"])([^'"]+?)\1\s*:\s*RouteMeta\(""", re.MULTILINE)
```

**CI wiring (D-12 §1) — add to `.github/workflows/ci.yml`:**
```yaml
  route-registry-parity:
    name: Route registry parity
    needs: [changes]
    if: needs.changes.outputs.flutter == 'true' || github.event_name == 'push'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - name: Run parity lint
        run: python3 tools/checks/route_registry_parity.py
```

### 5. SentryNavigatorObserver J0 smoke test — D-07 + D-11 §J0 Task 2

**Known-good foundation [VERIFIED: `apps/mobile/lib/app.dart:182-185`]:**
```dart
final List<NavigatorObserver> _routerObservers = [
  AnalyticsRouteObserver(),
  SentryNavigatorObserver(),  // Phase 31 OBS-05 wired
];
```

**Sentry SDK auto-behavior [CITED: docs.sentry.io/platforms/flutter/performance/instrumentation/automatic-instrumentation/]:**
- "GoRouter automatically uses the route path as the name."
- The instrumentation sets span operation to `ui.load` and span name to the route name.
- `setRouteNameAsTransaction` option (when enabled) "overrides the current Scope.transaction which will also override the name of the current Scope.span."

**J0 empirical validation flow (D-11 §Task 2):**
```bash
# 1. Install staging build with error injection capability
flutter build ios --simulator --release \
  --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1 \
  --dart-define=SENTRY_DSN=$SENTRY_DSN_MOBILE_STAGING
xcrun simctl install booted build/ios/iphonesimulator/Runner.app

# 2. Trigger errors on 3 test routes via walker.sh:
bash tools/simulator/walker.sh --scenario=inject-error-on-routes \
  --routes=/coach,/budget,/scan

# 3. Wait 60s for events to reach Sentry
sleep 60

# 4. Query Sentry for transaction matches
./tools/mint-routes health --json | jq '.[] | select(.sentry_count_24h > 0)'
# EXPECT: 3 routes listed (/coach, /budget, /scan)
# IF FAIL → transaction.name NOT auto-set → trigger Phase 31 retroactive patch
```

**Retroactive patch if J0 fails (hors scope Phase 32, DEFERRED):**
Add `scope.setTag('route', state.uri.path)` in a `GoRouterRedirectCallback` or in an overridden `SentryNavigatorObserver.didPush`. Budget: 2-4h per CONTEXT.md v4 deferred §. **Phase 32 does NOT ship this patch speculatively — only if J0 empirically fails.**

### 6. nLPD D-09 controls summary (ship WITH Phase 32, not deferred)

| Control | Location | Implementation |
|---------|----------|----------------|
| Token scope lock `project:read + event:read` | `docs/SETUP-MINT-ROUTES.md` + CLI `--verify-token` subcommand | Docs-first; optional CLI call queries `/api/0/auth/` for granted scopes, exits 78 if extra scopes present. |
| Event redaction layer | `tools/mint_routes/redaction.py` | Regex patterns: IBAN_CH, EMAIL, CHF>100, user field strip. JSON output metadata `{_redaction_applied: true, _redaction_version: 1}`. |
| Snapshot retention 7d | `tools/mint_routes/cli.py` startup check | `os.stat(snapshot_path).st_mtime` vs `time.time() - 7*86400` → unlink. `purge-cache` subcommand wipes immediately. |
| Admin access breadcrumb | `lib/services/sentry_breadcrumbs.dart::adminRoutesViewed` | Aggregates only `{route_count, feature_flags_enabled_count}`. Zero PII. |
| Keychain hardening | `docs/SETUP-MINT-ROUTES.md` | `security add-generic-password -a $USER -s SENTRY_AUTH_TOKEN -w <token> -U -A` (access control: single user, this device). |
| `.cache/` gitignore | `.gitignore` + CI check | `.cache/` entry; CI grep verifies `.gitignore` contains it. |

**`.gitignore` CI check (D-09 §3 + D-12 §3):**
```yaml
  cache-gitignore-check:
    name: .cache/ in .gitignore
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: grep -qE "^\.cache/" .gitignore || (echo "::error::.cache/ must be gitignored per D-09 §3"; exit 1)
```

### 7. CI D-12 jobs — full spec

**Job 1: `route-registry-parity`** (already shown §4 above).

**Job 2: `mint-routes-tests` (pytest DRY_RUN harness):**
```yaml
  mint-routes-tests:
    name: mint-routes pytest (DRY_RUN)
    needs: [changes]
    if: github.event_name == 'push' || contains(github.event.pull_request.changed_files, 'tools/mint-routes') || contains(github.event.pull_request.changed_files, 'tests/tools/')
    runs-on: ubuntu-latest
    env:
      MINT_ROUTES_DRY_RUN: "1"
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.11"
      - run: pip install pytest
      - run: pytest tests/tools/test_mint_routes.py -q --tb=short
```

**Job 3: `admin-build-sanity` (defensive YAML scanner):**
```yaml
  admin-build-sanity:
    name: Admin build sanity (ENABLE_ADMIN not in prod)
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Scan prod workflows for ENABLE_ADMIN=1
        run: |
          if grep -nE "dart-define=ENABLE_ADMIN=1" .github/workflows/testflight.yml .github/workflows/play-store.yml; then
            echo "::error::ENABLE_ADMIN=1 detected in prod build workflow — D-03 tree-shake violated"
            exit 1
          fi
          echo "OK: no ENABLE_ADMIN=1 in prod build workflows"
```

**Schema publication (D-12 §4) — `apps/mobile/lib/routes/route_health_schema.dart`:**
```dart
/// Phase 32 MAP-03 schema — Phase 35 dogfood CONSUMES this contract.
/// Bump schemaVersion on breaking changes; Phase 35 tests drift.
library;

const int kRouteHealthSchemaVersion = 1;

/// Exact JSON shape emitted by `./tools/mint-routes health --json`.
/// Newline-delimited JSON: one object per line, shape per this doc.
///
/// Example:
/// {"path": "/coach", "category": "destination", "owner": "coach",
///  "requires_auth": true, "kill_flag": "enableCoachChat", "status": "green",
///  "sentry_count_24h": 3, "ff_enabled": true,
///  "last_visit_iso": "2026-04-20T03:14:00Z",
///  "_redaction_applied": true, "_redaction_version": 1}
class RouteHealthJsonContract {
  // Intentionally empty — contract lives in Dartdoc above + schema version.
  // Any breaking change bumps kRouteHealthSchemaVersion and flags Phase 35
  // dogfood regression via pytest contract test.
}
```

---

## Dependencies & Integration Points

### What Phase 32 reads from Phase 31 (upstream)

| Phase 31 Asset | Phase 32 Usage |
|----------------|----------------|
| `apps/mobile/lib/app.dart:184` — `SentryNavigatorObserver()` wired | D-07 foundation — auto-sets `transaction.name` per GoRoute path. NO modification. [VERIFIED: code inspection] |
| `apps/mobile/lib/services/sentry_breadcrumbs.dart` — `MintBreadcrumbs` 4-level D-03 API | D-05 redirect breadcrumb + D-09 §4 admin-access breadcrumb reuse same pattern. EXTEND, don't fork. [VERIFIED: code inspection] |
| `tools/simulator/sentry_quota_smoke.sh` — Keychain + Sentry API pattern | CLI inherits verbatim (service name, subprocess call, JSON stdin pattern to avoid token in argv). [VERIFIED: code inspection] |
| `tools/simulator/walker.sh` — simctl iPhone 17 Pro J0 driver | D-11 §Task 6 creator-device smoke + D-11 §Task 2 error-injection flow. [VERIFIED: exists per 31-00 handoff]. |
| Sentry token in Keychain (service `SENTRY_AUTH_TOKEN`) | CLI `./tools/mint-routes` reads same token. [VERIFIED: Phase 31 handoff §SENTRY_AUTH_TOKEN operator setup deferred] — Julien provisions Keychain entry before Phase 32 execution. |
| Phase 31 OBS-05 breadcrumb helper `MintBreadcrumbs.featureFlagsRefresh` | Pattern template for `MintBreadcrumbs.adminRoutesViewed` + `legacyRedirectHit`. [VERIFIED: sentry_breadcrumbs.dart:110-128]. |

### What Phase 33 consumes from Phase 32 (downstream)

| Phase 32 Asset | Phase 33 Usage |
|----------------|----------------|
| `RouteMeta.killFlag` field | GoRouter `requireFlag()` middleware redirect: reads `killFlag` from registry per path, checks FF, redirects to `/flag-disabled?path=X&flag=Y` if off. [per FLAG-01] |
| `lib/screens/admin/admin_shell.dart` — AdminScaffold | Phase 33 adds child 2 `/admin/flags` to same shell. NO refactor. [per D-03 v4]. |
| `FeatureFlags.isAdmin` static gate | Phase 33 reuses for `/admin/flags`. May evolve `FeatureFlags` to ChangeNotifier (FLAG-02) — `isAdmin` becomes a getter on instance. |

### What Phase 34 consumes from Phase 32

| Phase 32 Asset | Phase 34 Usage |
|----------------|----------------|
| `.lefthook/route_registry_parity.sh` script | Phase 34 `lefthook.yml` wires `pre-commit.parallel.route-registry-parity` entry calling this script. No script change. [per D-12 §5]. |

### What Phase 35 consumes from Phase 32

| Phase 32 Asset | Phase 35 Usage |
|----------------|----------------|
| `./tools/mint-routes health --json` | `mint-dogfood.sh` pulls this nightly, grep for `"status":"red"\|"dead"` → adds to report. [per LOOP-03 + CONTEXT §v4 deferred Phase 35]. |
| `apps/mobile/lib/routes/route_health_schema.dart` | Phase 35 contract test: assert schema version stable across phases. Drift → regenerate schema + flag Phase 35 plan. |
| CLI `--json` newline-delimited output | Phase 35 `render_report.py` parses line-by-line — no full-file JSON parse dependency. |

### What Phase 36 consumes from Phase 32

| Phase 32 Asset | Phase 36 Usage |
|----------------|----------------|
| CLI `./tools/mint-routes health` | Julien uses terminal for P0 prioritization — "which route is most broken per Sentry 24h?" → FIX-01..09 ranking. [per FIX category]. |
| `kRouteRegistry` killFlag assignments | Phase 36 FIX-01..04 kill-switch verification — cross-reference 4 P0 flags (`enableProfileLoad`, `enableAnonymousFlow`, `enableSaveFactSync`, `enableCoachTab`) against registry. If any P0 flag's kill-flag assignment is missing → gate fails. |

---

## Risks & Open Questions (RESOLVED)

**RESOLVED:** all 7 risks below were closed during CONTEXT v4 lock and the 3-panel review pass. Entries retained for provenance; no open questions remain.


### 1. Sentry batch OR-query term limit unknown [MEDIUM risk]
- **What we know:** Sentry supports `transaction:[a, b, c]` list syntax equivalent to OR [VERIFIED: docs]. Public docs don't specify max list length. D-02 hypothesizes ~200 terms per query, D-11 targets ≥30 empirically.
- **Mitigation:** D-11 §Task 3 J0 empirical test: curl with 30-term list. If 414 URI Too Long or 400 Bad Request → halve batch size, document in VALIDATION.md + CLI source comment.
- **Fallback:** 1 req/sec sequential = ~3 min full scan (147 routes × 1s + overhead). Still safe for nightly dogfood.
- **Planner action:** include J0 task in Wave 1 gate before shipping CLI.

### 2. SentryNavigatorObserver `transaction.name` auto-set — UNVERIFIED END-TO-END [MEDIUM risk]
- **What we know:** Sentry docs [CITED: docs.sentry.io/platforms/flutter/performance/instrumentation/automatic-instrumentation/] explicitly state "GoRouter automatically uses the route path as the name." `SentryNavigatorObserver` is wired at `app.dart:184` [VERIFIED].
- **What's unverified:** actual Sentry UI events from staging show `transaction.name = "/coach"` (not `null` or internal span name).
- **Mitigation:** D-11 §Task 2 empirical smoke. If fails, Phase 31 retroactive patch documented as deferred (2-4h scope).
- **Planner action:** treat J0 smoke as Wave 1 gate. Do NOT build Phase 35 dogfood dependency on CLI health until this J0 passes.

### 3. CLI redaction false-negative risk [MEDIUM risk]
- **What we know:** regex patterns for IBAN_CH, EMAIL, CHF>100 are standard but not exhaustive.
- **Gaps identified:**
  - Non-Swiss IBAN (DE, FR, IT) not redacted — **planner: should we redact all IBAN patterns or CH only?**
  - CHF amounts without prefix (e.g., "1'500.–") bypass regex.
  - Email without TLD (intranet forms) bypasses.
  - User ID embedded in URL query string not stripped.
- **Mitigation:** (a) redact URL query params entirely (conservative); (b) extend IBAN regex to `[A-Z]{2}\d{2}\d{15,30}` for all countries; (c) document known gaps in SETUP docs.
- **Planner action:** lock redaction spec in Wave 1 plan, run redaction unit tests against known PII samples (from MINT Phase 29 privacy tests if they exist).

### 4. Keychain service name inconsistency [LOW risk — needs planner resolution]
- **What we know:** CONTEXT v4 D-02 says service name = `mint-sentry-auth`. `sentry_quota_smoke.sh:72` already uses `SENTRY_AUTH_TOKEN`. Phase 31 handoff STATE.md§Phase 31-00 confirms Keychain setup uses `SENTRY_AUTH_TOKEN`.
- **Recommendation:** reuse `SENTRY_AUTH_TOKEN` (consistency, zero onboarding friction). Amend CLI docs but not Keychain entry.
- **Planner action:** decide in Wave 0 spec; document resolution in 32-VALIDATION.md.

### 5. Wave 0 reconciliation 147/43 may drift during Phase 32 [LOW risk]
- **What we know:** counts reconciled 2026-04-20. Parallel Phase 33 branch may add/remove routes.
- **Mitigation:** Wave 0 first atomic commit = `extract-routes.sh` output snapshot + parity lint pass. Any subsequent route change in Phase 33 must regenerate `kRouteRegistry` and pass parity lint.
- **Planner action:** Wave 0 ships BEFORE Phase 33 starts. Phase 33 `feature/v2.8-phase-33` rebases on Phase 32 dev merge to inherit registry.

### 6. `isAdmin` gate is placeholder in Phase 32 — verify no consumer bug [LOW risk]
- **What we know:** D-10 says `FeatureFlags.isAdmin` returns `true` when `ENABLE_ADMIN=1`. Phase 33 may refactor to ChangeNotifier.
- **Risk:** if a consumer checks `FeatureFlags.isAdmin` as Provider-listenable in Phase 32 (which is static), rebuild won't trigger.
- **Mitigation:** document as `/// Phase 32: static getter. Phase 33 may become instance-level.` in dartdoc. Admin screen's `initState` reads once — no issue.

### 7. Tree-shake false negative (strings keyword in prod binary) [LOW risk]
- **What we know:** `strings` binary grep for `kRouteRegistry` = 0 is the D-11 Task 1 proof. But `strings` may detect the symbol name in Dart metadata even when the data is tree-shaken.
- **Mitigation:** also grep for one specific route path string known only to kRouteRegistry (e.g., a unique description). Zero match there = real data tree-shaken.
- **Planner action:** dual-grep in 32-VALIDATION.md Task 1.

---

## Must-knows for planner

### Exact shape to implement

**1. Dart classes (3 new files under `apps/mobile/lib/routes/`):**
```
route_metadata.dart    — RouteMeta class + kRouteRegistry const Map
route_category.dart    — enum {destination, flow, tool, alias}
route_owner.dart       — enum of 15 values
route_health_schema.dart — schema version constant + Dartdoc contract
```

**2. Flutter admin (new directory `apps/mobile/lib/screens/admin/`):**
```
admin_gate.dart         — AdminGate.isAvailable (compile-time + FF)
admin_shell.dart        — AdminShell wrapper (appBar + child)
routes_registry_screen.dart — ListView.builder grouped by owner
```

**3. Python CLI (new directory `tools/`):**
```
tools/mint-routes         — executable entrypoint (shebang)
tools/mint_routes/        — package (cli.py, sentry_client.py, redaction.py, output.py)
tests/tools/test_mint_routes.py
tests/tools/fixtures/sentry_health_response.json
```

**4. Parity lint (new file):**
```
tools/checks/route_registry_parity.py
tools/checks/route_registry_parity-KNOWN-MISSES.md
.lefthook/route_registry_parity.sh   (standalone, Phase 34 wires)
```

**5. Docs + artefacts:**
```
docs/SETUP-MINT-ROUTES.md                             — Keychain + Sentry scopes + troubleshooting
.planning/phases/32-cartographier/32-VALIDATION.md    — D-11 6 J0 tasks
README.md link to SETUP-MINT-ROUTES.md                — index entry
```

**6. CI additions to `.github/workflows/ci.yml`:**
```
route-registry-parity       (job, ≤30s)
mint-routes-tests           (job, ≤60s with DRY_RUN)
admin-build-sanity          (job, ≤5s defensive YAML scan)
cache-gitignore-check       (job, ≤5s D-09 §3 enforcement)
```

**7. Breadcrumb additions to `apps/mobile/lib/services/sentry_breadcrumbs.dart`:**
```
MintBreadcrumbs.legacyRedirectHit(from: String, to: String) — MAP-05
MintBreadcrumbs.adminRoutesViewed({routeCount, featureFlagsEnabledCount, snapshotAgeMinutes}) — D-09 §4
```

**8. 43 redirect call-site modifications in `app.dart`:**
Each `redirect: (_, __) => '/target'` becomes:
```dart
redirect: (ctx, state) {
  MintBreadcrumbs.legacyRedirectHit(from: state.uri.path, to: '/target');
  return '/target';
}
```
Or a helper: `ScopedGoRoute.redirect(from: '/legacy', to: '/target')` that wraps the breadcrumb. Executor discretion.

### Exact Python CLI command surface (copy-paste into plan)

```
./tools/mint-routes health     [--json] [--no-color] [--batch-size=N] [--owner=X]
./tools/mint-routes redirects  [--json] [--no-color] [--days=30]
./tools/mint-routes reconcile                # runs parity lint + prints diff
./tools/mint-routes purge-cache              # D-09 §3 emergency cache wipe
./tools/mint-routes --verify-token           # D-09 §1 optional scope check
./tools/mint-routes --help                   # argparse default
# Env: MINT_ROUTES_DRY_RUN=1 (fixture mode), NO_COLOR=1 (ANSI off)
```

### Exact CI job names (copy-paste into plan)

```
route-registry-parity         # D-12 §1
mint-routes-tests             # D-12 §2
admin-build-sanity            # D-12 §3
cache-gitignore-check         # D-09 §3 (could merge into admin-build-sanity)
```

### Wave ordering recommendation (for planner)

Given 5.5j budget and kill-policy discipline (never overrun >1.5j without descope), suggested waves:

**Wave 0 (0.5j) — Reconciliation + scaffolding (non-negotiable first commit):**
- Extract routes from `app.dart` via temporary extraction script.
- Verify 147 + 43 counts (or amend CONTEXT if drift).
- Populate `KNOWN-MISSES.md` with real patterns discovered.
- Create empty test files + fixtures.
- Create 32-VALIDATION.md skeleton.

**Wave 1 (1.5j) — Dart registry + parity lint + CI job 1:**
- MAP-01: `route_metadata.dart` + enum files + `kRouteRegistry` populated.
- MAP-04: `route_registry_parity.py` + KNOWN-MISSES.md finalized.
- CI job: `route-registry-parity`.
- 32-VALIDATION.md §Task 4 green.

**Wave 2 (1.5j) — CLI `./tools/mint-routes`:**
- MAP-02a + MAP-03: full Python package with Keychain, batch, redaction, DRY_RUN.
- `route_health_schema.dart` publication.
- pytest suite + fixture.
- CI job: `mint-routes-tests`.
- 32-VALIDATION.md §Task 3 (batch OR-query J0) + §Task 5 (DRY_RUN) green.

**Wave 3 (1.5j) — Flutter UI + breadcrumb analytics:**
- MAP-02b: admin shell + routes registry screen + AdminGate.
- MAP-05: 43 redirect call-sites gain `legacyRedirectHit` breadcrumb.
- D-09 §4: `adminRoutesViewed` breadcrumb.
- CI jobs: `admin-build-sanity` + `cache-gitignore-check`.
- 32-VALIDATION.md §Task 1 (tree-shake) + §Task 2 (SentryNavigatorObserver smoke) + §Task 6 (walker.sh) green.
- **Creator-device gate here** per `feedback_tests_green_app_broken`.

**Wave 4 (0.5j) — Docs + SETUP + final gates:**
- `docs/SETUP-MINT-ROUTES.md` finalized.
- README link.
- 32-VALIDATION.md fully green (all 6 tasks).
- Phase ship via `/gsd-verify-work`.

**Total: 5.5j** (matches CONTEXT budget). If Wave 3 overruns by >0.5j, descope either (a) 43 redirect breadcrumb analytics (ship in Phase 35 instead) OR (b) D-09 §4 admin-access breadcrumb (simpler scope).

---

## Assumptions Log

| # | Claim | Section | Risk if Wrong |
|---|-------|---------|---------------|
| A1 | `/explore/retraite` owner = `explore` (first segment wins per D-01 v4) — despite route being functionally retirement-themed | §Route registry schema | Minor — cosmetic mis-grouping in Flutter UI owner buckets. No functional impact. Planner/Julien confirm in Wave 0 during registry population. |
| A2 | PII redaction regex covers IBAN_CH, EMAIL, CHF>100, user fields. All other PII patterns (AVS number, phone number, postal address) NOT redacted by Phase 32. | §CLI PII redaction | MEDIUM — if Sentry event data contains AVS/phone/address in error messages, they leak to CLI output. Planner should decide if Phase 32 scope extends to these. **Recommendation: add AVS `\b756\.\d{4}\.\d{4}\.\d{2}\b` regex as defensive default.** |
| A3 | 30-term batch OR-query will succeed against Sentry Issues API | §CLI Sentry Issues API | MEDIUM — if fails, CLI falls back to sequential (15s → 3min per full scan). Phase 35 nightly dogfood still viable. D-11 Task 3 empirical validates. |
| A4 | Sentry SDK auto-sets `transaction.name = GoRoute.path` and this survives to the Issues API query surface (not only spans) | §SentryNavigatorObserver J0 | HIGH if wrong — D-07 entire query pattern fails, Phase 31 retroactive patch needed (deferred 2-4h). D-11 Task 2 empirical validates. |
| A5 | Existing `SENTRY_AUTH_TOKEN` Keychain service name should be reused (not `mint-sentry-auth` as CONTEXT literal says) | §CLI Keychain reuse | LOW — naming choice, not functional. Planner decides; doc resolution in 32-VALIDATION.md. |
| A6 | Tree-shake via `bool.fromEnvironment('ENABLE_ADMIN')` effectively detaches `kRouteRegistry` from prod IPA when `ENABLE_ADMIN=0` | §Tree-shake mechanics | MEDIUM — if Dart compiler doesn't fully dead-code-eliminate, 147 route entries persist in prod binary (bloat + leak of dev-only `description` field strings). D-11 Task 1 empirical validates (`strings Runner \| grep kRouteRegistry = 0`). |
| A7 | `43 legacy redirects` is accurate count as of 2026-04-20 reconciliation (ROADMAP stated 23, was wrong) | §Redirect analytics | LOW — Wave 0 re-counts; any drift flags amendment to CONTEXT before Wave 3. |
| A8 | `MINT_ROUTES_DRY_RUN=1` fixture can fully exercise CLI code paths without a real Sentry token — matches `sentry_quota_smoke.sh:99-147` precedent | §CLI DRY_RUN harness | LOW — if there's a code path only reachable via live API (e.g., 429 backoff), pytest coverage may have holes. Mitigation: mock `call_sentry_api()` for error-path tests. |

---

## Environment Availability

| Dependency | Required By | Available | Version | Fallback |
|------------|------------|-----------|---------|----------|
| Python 3.10+ | CLI, parity lint | ✓ | 3.9.6 [VERIFIED: `python3 --version`] | **Upgrade path needed** — 3.9.6 < 3.10 requirement. Use 3.9-compatible syntax (no `match` statement, no `dict\|dict` merge) OR install Python 3.11 via brew. CI uses 3.11 already. |
| Flutter SDK 3.41+ | Dart registry, admin shell | ✓ | 3.41.6 | — |
| sentry-cli | CLI Keychain + API calls | ✓ | 3.3.5 [VERIFIED: `sentry-cli --version`] | Direct `requests` HTTP to Sentry API (fallback if needed). |
| `security` (macOS Keychain) | CLI Keychain token | ✓ | macOS built-in | Env var `SENTRY_AUTH_TOKEN` override (already supported). |
| xcrun simctl + `walker.sh` | D-11 Task 2 + Task 6 empirical gates | ✓ | Phase 31-00 installed `tools/simulator/walker.sh` | — |
| `jq` | CLI `--json` piping in docs/examples | Likely ✓ | N/A | Python `json.tool` alternative; pure Dart parse on Flutter side. |
| `gtimeout` (coreutils) | walker.sh portable `to()` wrapper | ✓ (installed Phase 31) | Phase 31-00 handoff | Bare `timeout` or unbounded (Phase 31 walker has fallback). |

**Missing with fallback:**
- Python 3.10+ required feature surface → downscope CLI to Python 3.9-compatible syntax. [Planner action: lock syntax rules in Wave 2 plan.]

**Missing blocking:**
- None.

---

## Security Domain (nLPD / Swiss)

### Applicable ASVS Categories

| ASVS Category | Applies | Standard Control |
|---------------|---------|-----------------|
| V2 Authentication | yes (CLI → Sentry API) | macOS Keychain + scope-locked `SENTRY_AUTH_TOKEN` (D-09 §1) |
| V3 Session Management | no | — (CLI has no session; one-shot calls) |
| V4 Access Control | yes (Flutter admin route) | Compile-time `ENABLE_ADMIN=1` + runtime `FeatureFlags.isAdmin` (D-03 + D-10) |
| V5 Input Validation | partial | CLI argparse stdlib validates `--batch-size`, `--days`, `--owner`; Sentry response fields validated by redaction layer |
| V6 Cryptography | no | — (no crypto ops in Phase 32; delegates to Keychain + HTTPS to Sentry) |

### Known Threat Patterns for {CLI + dev-only Flutter admin}

| Pattern | STRIDE | Standard Mitigation |
|---------|--------|---------------------|
| Token leak via argv (`ps auxf`) | Information Disclosure | Pass token to python subprocess via stdin, never argv (per `sentry_quota_smoke.sh:119` pattern) |
| Token leak via error message | Information Disclosure | Never print `SENTRY_AUTH_TOKEN` value — only length (`[DEBUG] token length=64`) |
| Scope escalation (token has write/admin) | Elevation of Privilege | `--verify-token` subcommand queries `/api/0/auth/` and exits 78 if scopes > project:read + event:read |
| Cached Sentry events leak PII | Information Disclosure | Redaction layer BEFORE write to `.cache/`. 7-day auto-delete. `.cache/` gitignored. |
| Admin screen ships in prod IPA | Information Disclosure | Tree-shake via `bool.fromEnvironment`. D-11 §Task 1 empirical gate. CI `admin-build-sanity` defensive scan. |
| Admin screen PII leak via breadcrumb | Information Disclosure | `MintBreadcrumbs.adminRoutesViewed` emits aggregates only — no user context, no route-specific data. |
| Parity lint false positive blocks CI | Denial of Service | `KNOWN-MISSES.md` documents exceptions. Script has `--dry-run-fixture` for local debug. |

### nLPD Art. Mapping (D-09)

| Art. | Requirement | Phase 32 Control |
|------|-------------|------------------|
| Art. 5 (accuracy) | Data must be accurate | D-07 async-error-hors-transaction gap documented (acknowledged limit, not regression) |
| Art. 6 (minimization) | Collect only necessary data | Token scope locked `project:read + event:read` + CLI redaction layer |
| Art. 7 (security) | Appropriate security measures | Keychain hardening `-U -A` + HTTPS to Sentry + tree-shake admin from prod |
| Art. 9 (storage limitation) | Delete when no longer needed | 7-day auto-delete `.cache/route-health.json` + `purge-cache` command |
| Art. 12 (processing record) | Record processing activities | `mint.admin.routes.viewed` breadcrumb (aggregates only) logs admin tool usage |

---

## Sources

### Primary (HIGH confidence)
- [Sentry Flutter Automatic Instrumentation](https://docs.sentry.io/platforms/flutter/performance/instrumentation/automatic-instrumentation/) — "GoRouter automatically uses the route path as the name" (confirms D-07 query pattern).
- [Sentry Search concepts](https://docs.sentry.io/concepts/search/) — List syntax `key:[a, b]` = `key:a OR key:b` (locks CLI batch query construction).
- [Sentry Routing Instrumentation for Flutter](https://docs.sentry.io/platforms/dart/guides/flutter/integrations/routing-instrumentation/) — SentryNavigatorObserver API surface.
- [Sentry List an Organization's Issues API](https://docs.sentry.io/api/events/list-an-organizations-issues/) — query parameter contract (batch limit NOT documented; D-11 J0 empirically determines).
- `apps/mobile/lib/app.dart:182-185` — `_routerObservers` with `SentryNavigatorObserver` wired [VERIFIED: direct read].
- `apps/mobile/lib/services/sentry_breadcrumbs.dart` — `MintBreadcrumbs` 4-level D-03 template [VERIFIED: direct read].
- `tools/simulator/sentry_quota_smoke.sh` — Keychain + sentry-cli + stdin-JSON-parse pattern [VERIFIED: direct read].
- `apps/mobile/lib/services/feature_flags.dart` — FeatureFlags surface (no `isAdmin` yet) [VERIFIED: direct read].
- `.github/workflows/testflight.yml:206-215` + `play-store.yml:127-130` — prod build steps, no `ENABLE_ADMIN` currently [VERIFIED: grep].
- `.planning/phases/32-cartographier/32-CONTEXT.md` v4 — 12 locked decisions [VERIFIED: direct read].
- `.planning/phases/31-instrumenter/31-CONTEXT.md` — D-03/D-05/D-06 inheritance [VERIFIED: direct read].
- `.planning/REQUIREMENTS.md` §MAP — MAP-01..05 split a/b [VERIFIED: direct read].
- `.planning/ROADMAP.md:180-193` — Phase 32 success criteria [VERIFIED: direct read].
- `decisions/ADR-20260419-v2.8-kill-policy.md` — scope discipline [VERIFIED: direct read].

### Secondary (MEDIUM confidence)
- [Sentry blog — Avoid rate limiting with query batching](https://blog.sentry.io/avoid-rate-limiting-with-query-batching/) — general batching guidance (not Phase-32-specific).
- [NO_COLOR standard](https://no-color.org) — env var convention for ANSI disable [CITED: D-02].
- sysexits.h POSIX convention — exit code map [CITED: D-02, standard].

### Tertiary (LOW confidence — flagged for validation)
- Sentry batch OR-query exact term limit — public docs do not state. D-11 Task 3 J0 empirical required.
- PII redaction regex coverage — A2 assumption; requires Phase 29 PII test corpus cross-check during Wave 2.

---

## Metadata

**Confidence breakdown:**
- Standard Stack: HIGH — all components in-house (Python stdlib, Flutter SDK 3.41, sentry_flutter 9.14.0 pinned, sentry-cli 3.3.5 installed). No new dependencies.
- Architecture: HIGH — 12 decisions locked v4, 3-panel-audited, no ambiguity in extension points (app.dart observer list top-level, MintBreadcrumbs extension pattern, tools/checks/*.py script template).
- Pitfalls: HIGH — each Panel 1/2/3 finding (tree-shake unverified, batch query limit, nLPD redaction, iOS sandbox, admin/me missing) is already closed in CONTEXT v4 or explicitly flagged in §Risks & Open Questions (RESOLVED) above.

**Research date:** 2026-04-20
**Valid until:** 2026-05-20 (30 days — stack stable, no fast-moving deps)

---

## RESEARCH COMPLETE

Phase 32 Cartographier research delivers HIGH-confidence implementation findings for MAP-01..05 (a/b split), mapping 12 locked decisions to exact file paths, class shapes, CLI command surface, CI job YAML, and Wave 0→4 ordering; two MEDIUM-risk J0 empirical gates (batch OR-query limit, SentryNavigatorObserver transaction.name auto-set) are explicitly scoped in 32-VALIDATION.md.
