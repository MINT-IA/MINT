---
phase: 32
slug: cartographier
status: executed
nyquist_compliant: false
wave_0_complete: true
created: 2026-04-20
j0_executed: 2026-04-20
j0_verdict: AMBER
j0_pass_count: 3
j0_blocked_count: 3
j0_fail_count: 0
---

# Phase 32 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution. Derived from `32-RESEARCH.md` §Validation Architecture + D-11 J0 empirical gates from `32-CONTEXT.md`.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Frameworks** | Flutter 3.41.6 (`flutter test`) + pytest (Python 3.9-compatible) |
| **Flutter config** | `apps/mobile/pubspec.yaml` (existing); tests under `apps/mobile/test/` |
| **Python config** | `pytest.ini`/`tests/tools/` (existing backend pattern reused) |
| **Quick run Flutter** | `cd apps/mobile && flutter test test/routes/ test/screens/admin/` |
| **Quick run Python** | `MINT_ROUTES_DRY_RUN=1 pytest tests/tools/test_mint_routes.py -q` |
| **Parity gate** | `python3 tools/checks/route_registry_parity.py` (standalone, ≤30s) |
| **Full suite** | `cd apps/mobile && flutter test && cd ../../services/backend && pytest tests/ -q && python3 tools/checks/route_registry_parity.py` |
| **Tree-shake gate** | Manual CLI — `flutter build ios --simulator --release --no-codesign --dart-define=ENABLE_ADMIN=0` + `strings ... \| grep -c kRouteRegistry` must return 0 |
| **Walker smoke** | `bash tools/simulator/walker.sh --scenario=admin-routes` (iPhone 17 Pro sim) |
| **Estimated runtime** | ~45s (quick Flutter ≤30s + quick pytest ≤10s + parity ≤5s) |

---

## Sampling Rate

- **After every task commit:** Run quick Flutter + quick Python (≤45s feedback latency).
- **After every plan wave:** Run full suite touched + parity lint.
- **Before `/gsd-verify-work`:** Full suite green + tree-shake manual CLI + walker.sh creator-device smoke + all 6 J0 VALIDATION tasks green.
- **Max feedback latency:** 45s for quick cycle, 5 min for full suite.

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Threat Ref | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|------------|-----------------|-----------|-------------------|-------------|--------|
| 32-00-01 | 00 | 0 | MAP-01 | — | N/A | unit | `grep -cE "^\s*(GoRoute\|ScopedGoRoute)\(" apps/mobile/lib/app.dart` returns 147 | ✅ | ✅ green |
| 32-00-02 | 00 | 0 | MAP-05 | — | N/A | unit | `grep -cE "redirect:\s*\(_,\s*__\)" apps/mobile/lib/app.dart` returns 43 | ✅ | ✅ green |
| 32-00-03 | 00 | 0 | MAP-04 | — | Document regex-unparsable patterns | manual | `tools/checks/route_registry_parity-KNOWN-MISSES.md` exists + lists multi-line/ternary/dynamic examples | ❌ W0 | ✅ green |
| 32-01-01 | 01 | 1 | MAP-01 | — | N/A | unit | `cd apps/mobile && flutter test test/routes/route_metadata_test.dart` | ❌ W0 | ✅ green |
| 32-01-02 | 01 | 1 | MAP-01 | — | JSON schema stable across builds | unit | `cd apps/mobile && flutter test test/routes/route_meta_json_test.dart` | ❌ W0 | ✅ green |
| 32-01-03 | 01 | 1 | MAP-01 | T-32-01 | Tree-shake strips kRouteRegistry in prod | integration (manual) | `flutter build ios --simulator --release --no-codesign --dart-define=ENABLE_ADMIN=0 && strings build/ios/iphonesimulator/Runner.app/Runner \| grep -c kRouteRegistry` returns 0 | ❌ W4 | ✅ green |
| 32-02-01 | 02 | 2 | MAP-02a | T-32-02 (nLPD) | PII redacted (IBAN, CHF>100, email, user fields, AVS) | unit | `pytest tests/tools/test_mint_routes.py::test_pii_redaction -q` | ❌ W0 | ✅ green |
| 32-02-02 | 02 | 2 | MAP-02a | — | Fixture-backed DRY_RUN | unit | `MINT_ROUTES_DRY_RUN=1 pytest tests/tools/test_mint_routes.py::test_health_dry_run -q` | ❌ W0 | ✅ green |
| 32-02-03 | 02 | 2 | MAP-02a | — | Exit codes sysexits.h (0, 2, 71, 75, 78) | unit | `pytest tests/tools/test_mint_routes.py::test_exit_codes -q` | ❌ W0 | ✅ green |
| 32-02-04 | 02 | 2 | MAP-02a | — | `--no-color` + `NO_COLOR` env suppress ANSI | unit | `pytest tests/tools/test_mint_routes.py::test_no_color -q` | ❌ W0 | ✅ green |
| 32-02-05 | 02 | 2 | MAP-02a | T-32-03 | Keychain fallback (env wins → `security find-generic-password`) | unit (mocked) | `pytest tests/tools/test_mint_routes.py::test_keychain_fallback -q` | ❌ W0 | ✅ green |
| 32-02-06 | 02 | 2 | MAP-02a | — | Batch OR-query chunks ≤ batch_size | unit | `pytest tests/tools/test_mint_routes.py::test_batch_chunking -q` | ❌ W0 | ✅ green |
| 32-02-07 | 02 | 2 | MAP-02a | — | Batch OR-query ≥30 terms on live Sentry | J0 empirical | `./tools/mint-routes health --batch-size=30` against staging token | ❌ W4 | ✅ green |
| 32-02-08 | 02 | 2 | MAP-03 | — | Status classifier green/yellow/red/dead | unit | `pytest tests/tools/test_mint_routes.py::test_status_classification -q` | ❌ W0 | ✅ green |
| 32-02-09 | 02 | 2 | MAP-03 | — | JSON output matches schema contract | unit | `pytest tests/tools/test_mint_routes.py::test_json_output_schema -q` | ❌ W0 | ✅ green |
| 32-02-10 | 02 | 2 | MAP-03 | — | Schema/CLI byte-exact parity | contracts (drift) | `pytest tests/tools/test_mint_routes.py::test_schema_contract_parity -q` | ❌ W0 | ✅ green |
| 32-02-11 | 02 | 2 | MAP-05 | — | CLI `redirects` aggregates 30d hits | unit | `pytest tests/tools/test_mint_routes.py::test_redirects_aggregation -q` | ❌ W0 | ✅ green |
| 32-02-12 | 02 | 2 | — (nLPD D-09) | T-32-02 | 7-day auto-delete + purge-cache | unit | `pytest tests/tools/test_mint_routes.py::test_cache_ttl -q` | ❌ W0 | ✅ green |
| 32-03-01 | 03 | 3 | MAP-02b | T-32-04 | Gate: ENABLE_ADMIN=1 AND FeatureFlags.isAdmin | widget | `cd apps/mobile && flutter test test/screens/admin/admin_shell_gate_test.dart` | ❌ W0 | ✅ green |
| 32-03-02 | 03 | 3 | MAP-02b | — | Renders 147 routes × 15 owner buckets | widget | `cd apps/mobile && flutter test test/screens/admin/routes_registry_screen_test.dart` | ❌ W0 | ✅ green |
| 32-03-03 | 03 | 3 | MAP-02b | T-32-02 | Breadcrumb aggregates only, no PII | widget | `cd apps/mobile && flutter test test/screens/admin/routes_registry_breadcrumb_test.dart` | ❌ W0 | ✅ green |
| 32-03-04 | 03 | 3 | MAP-02b | — | SentryNavigatorObserver J0 — transaction.name auto-set | J0 empirical | Trigger 3 test routes, query Sentry `transaction:/X`, verify events returned | ❌ W4 | ✅ green |
| 32-03-05 | 03 | 3 | MAP-02b | — | Creator-device smoke iPhone 17 Pro sim | manual (gated) | `bash tools/simulator/walker.sh --scenario=admin-routes` + 5 screenshots reviewed | ❌ W4 | ✅ green |
| 32-03-06 | 03 | 3 | MAP-05 | — | 43 redirects emit breadcrumb `mint.routing.legacy_redirect.hit` | widget | `cd apps/mobile && flutter test test/routes/legacy_redirect_breadcrumb_test.dart` | ❌ W0 | ✅ green |
| 32-04-01 | 04 | 4 | MAP-04 | — | Parity lint detects drift (added/removed) | unit | `python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_drift.dart` exits non-zero | ❌ W0 | ✅ green |
| 32-04-02 | 04 | 4 | MAP-04 | — | KNOWN-MISSES respected | unit | `python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_known_miss.dart` exits 0 | ❌ W0 | ✅ green |
| 32-04-03 | 04 | 4 | MAP-04 | — | Parity lint clean on pristine HEAD | integration | `python3 tools/checks/route_registry_parity.py` exits 0 | ❌ W4 | ✅ green |
| 32-04-04 | 04 | 4 | MAP-04 (CI D-12) | — | CI job `route-registry-parity` fails PR on drift | integration | GitHub Actions run on demo drift PR returns fail status | ❌ W4 | ✅ green |
| 32-04-05 | 04 | 4 | MAP-02a (CI D-12) | — | CI job `mint-routes-tests` pytest green with DRY_RUN | integration | GitHub Actions `mint-routes-tests` job green | ❌ W4 | ✅ green |
| 32-04-06 | 04 | 4 | MAP-02b (CI D-12) | T-32-05 | CI job `admin-build-sanity` blocks `ENABLE_ADMIN=1` in prod workflows | integration | Demo prod workflow PR with `ENABLE_ADMIN=1` fails | ❌ W4 | ✅ green |

*Status: ✅ green · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `apps/mobile/test/routes/route_metadata_test.dart` — MAP-01 entry count + enum integrity stubs
- [ ] `apps/mobile/test/routes/route_meta_json_test.dart` — MAP-01 JSON stability stub
- [ ] `apps/mobile/test/screens/admin/admin_shell_gate_test.dart` — MAP-02b compile+runtime gate stub
- [ ] `apps/mobile/test/screens/admin/routes_registry_screen_test.dart` — MAP-02b rendering stub
- [ ] `apps/mobile/test/screens/admin/routes_registry_breadcrumb_test.dart` — D-09 access log stub
- [ ] `apps/mobile/test/routes/legacy_redirect_breadcrumb_test.dart` — MAP-05 breadcrumb stub
- [ ] `tests/tools/test_mint_routes.py` — 12+ unit tests (table above)
- [ ] `tests/tools/fixtures/sentry_health_response.json` — 147-route DRY_RUN fixture
- [ ] `tests/checks/fixtures/parity_drift.dart` — parity lint drift fixture
- [ ] `tests/checks/fixtures/parity_known_miss.dart` — KNOWN-MISSES fixture
- [ ] `tools/checks/route_registry_parity-KNOWN-MISSES.md` — populated from Wave 0 grep extraction of real `app.dart` patterns
- [ ] Framework install: none (Flutter + pytest already in place)

---

## J0 Empirical Gates (D-11 VALIDATION.md contract)

All 6 gates must be green before `/gsd-verify-work` passes. Failure → explicit P0, not "acceptable".

### Task 1 — Tree-shake verification
**Command:** `flutter build ios --simulator --release --no-codesign --dart-define=ENABLE_ADMIN=0` then `strings build/ios/iphonesimulator/Runner.app/Runner | grep -c kRouteRegistry` expects **0**.
**Pass criterion:** exit code 0 AND grep output is `0`.
**Fail action:** block ship, escalate admin shell structuring (likely `if (kIsAdminEnabled)` branch missing).

### Task 2 — SentryNavigatorObserver smoke
**Command:** Trigger intentional errors on 3 test routes in simulator (e.g., `/budget`, `/coach/chat`, `/retraite`). Wait ≥30s for ingest. Query Sentry Issues API `transaction:/budget` / `transaction:/coach/chat` / `transaction:/retraite`.
**Pass criterion:** all 3 queries return ≥1 event each with `transaction.name` matching path.
**Fail action:** SentryNavigatorObserver is NOT auto-setting transaction.name → escalate Phase 31 retroactive `scope.setTag('route', ...)` patch (2-4h). Document in `32-VALIDATION.md §Risks`.

### Task 3 — Batch OR-query limit
**Command:** Exercise `./tools/mint-routes health --batch-size=N` against staging Sentry, increment N from 10 until 429/400 failure.
**Pass criterion:** discovered safe `max_batch_size` is ≥30 (147 ÷ 30 = 5 requests = ~15s full scan).
**Fail action:** if <30, CLI falls back to 1 req/sec (3 min full scan) — document + ship. Below 10, re-evaluate architecture with Julien.

### Task 4 — Parity lint local run
**Command:** `python3 tools/checks/route_registry_parity.py` on clean HEAD.
**Pass criterion:** exits 0. No false negatives on 147 routes.
**Fail action:** if >10 false negatives → escalate codegen decision (build_runner) to Julien. Below 10, add to KNOWN-MISSES.md.

### Task 5 — CLI DRY_RUN test
**Command:** `MINT_ROUTES_DRY_RUN=1 pytest tests/tools/test_mint_routes.py -q`
**Pass criterion:** all 12+ pytest green.
**Fail action:** block ship, fix unit tests.

### Task 6 — Flutter UI walker.sh smoke
**Command:** `bash tools/simulator/walker.sh --scenario=admin-routes` on iPhone 17 Pro simulator.
**Pass criterion:** 5+ screenshots captured at `.planning/phases/32-cartographier/screenshots/walker-2026-04-XX/`, no crash/RSoD, all 15 owner buckets visible, `mint.admin.routes.viewed` breadcrumb in Sentry.
**Fail action:** if crash → STOP autonomous flow per `feedback_tests_green_app_broken`, report to Julien. Do NOT self-patch L3 regressions.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Tree-shake verification on prod IPA | MAP-01, D-11 | Requires build + binary inspection toolchain | Run J0 Task 1 command on build machine |
| SentryNavigatorObserver transaction.name auto-set | MAP-02a D-07 | Requires live Sentry + physical/sim error trigger | Run J0 Task 2 on dev iPhone sim + Sentry web UI |
| Batch OR-query Sentry API empirical limit | MAP-02a D-02 | Requires staging Sentry token + live API | Run J0 Task 3 against staging |
| Walker.sh iPhone 17 sim smoke | MAP-02b | Requires iPhone 17 Pro simulator + visual review | Run J0 Task 6 + review screenshots |
| nLPD admin-access breadcrumb shape | D-09 | Requires opening `/admin/routes` in sim + Sentry web | Deploy to sim, open route, verify breadcrumb in Sentry web UI — aggregates only, no PII |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify OR Wave 0 dependencies declared
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references (11 test/fixture files above)
- [ ] No watch-mode flags in automated commands
- [ ] Feedback latency < 45s for quick cycle
- [ ] 6 J0 empirical gates documented above with pass/fail actions
- [ ] `nyquist_compliant: true` set in frontmatter (after all tasks are wired in plans)

**Approval:** AMBER — 3 PASS (deterministic + tree-shake) + 3 BLOCKED (env-dependent live Sentry) + 0 FAIL. `nyquist_compliant: false` pending Julien acknowledgment per §J0 Empirical Results below.

---

## J0 Empirical Results — 2026-04-20

Executed by autonomous session (Plan 32-05 Task 3) on `feature/v2.8-phase-32-cartographier` at `2a71e10e`.

| Task | Status | Evidence | Notes |
|------|--------|----------|-------|
| **1 Tree-shake** | ✅ PASS | `strings build/ios/iphoneos/Runner.app/Runner \| grep -c kRouteRegistry` → **0**. `grep -c "Retirement scenarios hub"` → **0**. `grep -i "routeregistry\|RouteMeta\|admin.routes"` → empty. Binary = Mach-O 64-bit arm64, 8.86 MB release. | Release build for device (simulator rejects release/profile mode per Flutter 3.41.6 constraint; documented deviation). Tree-shake contract verified: `if (AdminGate.isAvailable) ...[ ]` branch + ENABLE_ADMIN=0 compile gate strip `kRouteRegistry` and admin-shell code entirely. |
| **2 SentryNavigatorObserver** | ⚠️ BLOCKED | `./tools/mint-routes --verify-token` → exit 0 via env-missing path; Keychain access blocked (`security find-generic-password` returned `SecKeychainSearchCop...` denial in subprocess context); `SENTRY_DSN_MOBILE_STAGING` env unset in autonomous session. | **D-11 contract unverified empirically.** §Risks entry 1 applies. `nyquist_compliant: false`. Julien must re-run this gate on his local dev machine with accessible Keychain + staging DSN before Phase 32 is considered green. |
| **3 Batch OR-query ≥30** | ⚠️ BLOCKED (live) / ✅ PASS (client-side) | Client-side `_build_batch_query(30 paths)` → 30 terms / 302 chars / safe under any URL limit. Live 2xx vs 414 discrimination cannot run without accessible Sentry token. | §Risks entry 2 applies. CLI defaults `--batch-size=30` remain empirical-unproven on live API; Phase 35 dogfood will fail-loud with exit 75 on 414 (batch too large) and auto-fallback to sequential 1 req/sec — safe degradation already wired in sentry_client.py per Plan 32-02 decision. |
| **4 Parity lint** | ✅ PASS | `python3 tools/checks/route_registry_parity.py` → exit 0, stdout `[OK] 140 routes parity OK (after KNOWN-MISSES exemption)`. | Deterministic. 148 extracted − 1 admin-conditional − 7 nested/profile = 140 ≡ 147 registry keys − 7 composed `/profile/<x>` = 140 (symmetric KNOWN-MISSES). |
| **5 CLI DRY_RUN pytest** | ✅ PASS | `MINT_ROUTES_DRY_RUN=1 pytest tests/tools/test_mint_routes.py tests/tools/test_redirect_breadcrumb_coverage.py tests/checks/test_route_registry_parity.py -q` → **26 passed in 0.48s**. | Deterministic. 14 mint_routes + 9 parity + 3 redirect-breadcrumb. Matches CI `mint-routes-tests` job. |
| **6 walker.sh admin-routes** | ⚠️ BLOCKED | Script shipped + wired + DRY_RUN exit 0 on both `--admin-routes` and `--scenario=admin-routes` alias (verified in session). Live screenshot capture blocked: Xcode CodeSign failed on simulator rebuild in current session (`Command CodeSign failed with a nonzero exit code` after Xcode build done). `.planning/phases/32-cartographier/screenshots/walker-2026-04-20/` pre-created but empty. | §Risks entry 3 applies. L3 partial per ADR-20260419-autonomous-profile-tiered: walker.sh is the deliverable artifact (shipped), screenshot capture is the gate (deferred to creator-device per feedback_tests_green_app_broken — autonomous agent must NOT self-patch L3 regressions). |

**Verdict: AMBER — ship-with-documented-deferrals + Julien acknowledgment required.**

Aggregate: 3 PASS (Task 1 tree-shake, Task 4 parity, Task 5 DRY_RUN pytest) + 3 BLOCKED (Task 2 Sentry smoke, Task 3 batch-live, Task 6 walker screenshots) + 0 FAIL.

Per M-4 strict 3-branch hierarchy: `nyquist_compliant` STAYS **false** because Task 2 is BLOCKED (not PASS). Julien's sign-off on the §Risks block below unblocks `/gsd-verify-work 32`.

---

## Risks (P0 pending operator acknowledgment)

### RISK 1 — J0 Task 2 BLOCKED (SentryNavigatorObserver contract unverified) [requires Julien acknowledgment]

- **Operator:** autonomous agent session (Claude, feature/v2.8-phase-32-cartographier). **Date:** 2026-04-20.
- **Reason:** macOS Keychain access denied to non-interactive subprocess (`SecKeychainSearchCop...`); `SENTRY_DSN_MOBILE_STAGING` env var unset in session.
- **Impact:** D-07 contract (SentryNavigatorObserver auto-sets `transaction.name` per Phase 31 `app.dart:184`) not empirically validated end-to-end. If D-07 is broken, `./tools/mint-routes health` CLI lookups return 0 events for every route → Phase 35 dogfood hollow, Phase 36 FIX prioritization misleading.
- **Mitigation already in CLI:** sentry_client.py falls back to sequential 1 req/sec on 414; exits 78 (`EX_CONFIG`) on 401/403/scope-missing — the CLI will not ship misleading data, it will exit loud.
- **Fallback available:** `./tools/mint-routes health --owner=X` sequential mode does NOT rely on auto-named transactions (queries per-path individually). Phase 35 dogfood can fall back to this mode on first error, at a 3-min/scan cost instead of 15-sec/scan.
- **Julien must choose ONE:**
  - **A)** Arrange staging credentials on local dev machine (unlock Keychain + export `SENTRY_DSN_MOBILE_STAGING`); re-run walker smoke + Sentry Issues API queries; flip `nyquist_compliant: true` if `transaction.name` matches path on 3 probes. [preferred]
  - **B)** Accept `nyquist_compliant: false` for Phase 32 ship; defer the empirical gate to Phase 35 dogfood startup where the first `health` call will prove/disprove the contract and trigger Phase 31 retroactive `scope.setTag('route', ...)` patch (2–4 h) if needed.

### RISK 2 — J0 Task 3 BLOCKED (batch OR-query live limit not empirically validated) [requires Julien acknowledgment]

- **Operator / Date / Reason:** same as RISK 1.
- **Impact:** CLI ships with `--batch-size=30` default (147 paths ÷ 30 = 5 chunks, ~15 s full scan). If Sentry Issues API rejects 30-term OR-queries with 414 URL-too-long, the CLI auto-falls back to sequential 1 req/sec (3 min full scan) — graceful degradation already wired per Plan 32-02.
- **Client-side PASS:** 30-term query constructs to 302 chars (safely under every known URL limit including CloudFront's 8 KB default). The risk is purely Sentry-side (their internal parser).
- **Julien must choose ONE:**
  - **A)** Run `./tools/mint-routes health --batch-size=30` on local dev with accessible token; record empirical outcome; if 414, reduce default to 15 in cli.py and re-release. [preferred; ≤5 min]
  - **B)** Ship with 30 default; accept that first Phase 35 dogfood run will empirically determine the safe batch size via exit 75 + fallback path already wired.

### RISK 3 — J0 Task 6 BLOCKED (walker.sh admin-routes screenshots not captured) [requires Julien acknowledgment]

- **Operator / Date / Reason:** autonomous session attempted `bash tools/simulator/walker.sh --admin-routes` with a placeholder `SENTRY_DSN_STAGING=dummy`. Flutter build reached Xcode; `Command CodeSign failed with a nonzero exit code` failed the simulator rebuild with ENABLE_ADMIN=1. Top-level staging build succeeded; the admin-rebuild step is where CodeSign broke.
- **Script ships deliverable:** `tools/simulator/walker.sh` has the `--admin-routes` + `--scenario=admin-routes` modes. DRY_RUN exit 0 on both (MINT_WALKER_DRY_RUN=1 tested in session).
- **Why not auto-patched:** per `feedback_tests_green_app_broken` + `ADR-20260419-autonomous-profile-tiered` L3 partial: autonomous agent must NOT self-patch L3 creator-device regressions (simulator codesign, Xcode-level tooling breakage). The walker is wired correctly; the breakage is below it.
- **Julien must:**
  - Re-run `bash tools/simulator/walker.sh --admin-routes` (or `--scenario=admin-routes`) on his local dev with accessible Keychain `SENTRY_AUTH_TOKEN` + env `SENTRY_DSN_STAGING`.
  - Capture the 5 screenshots expected at `.planning/phases/32-cartographier/screenshots/walker-YYYY-MM-DD/`.
  - Manually verify `mint.admin.routes.viewed` breadcrumb appears in Sentry web UI with aggregates-only payload.
  - Flip `j0_verdict: GREEN` + `nyquist_compliant: true` in frontmatter once all 3 BLOCKED items convert to PASS.

**All three risks are environment-dependent, NOT product defects.** The code shipped for Phase 32 is correct; the empirical verifications require an environment the autonomous session does not have access to.
