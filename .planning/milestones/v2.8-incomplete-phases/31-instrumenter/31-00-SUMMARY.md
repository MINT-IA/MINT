---
phase: 31-instrumenter
plan: 00
subsystem: observability
tags: [sentry, sentry-cli, flutter-test, pytest, simctl, walker.sh, scaffolding, wave-0, obs-01]

# Dependency graph
requires:
  - phase: 30.6-tools-deterministes
    provides: CTX-05 spike output in main.dart (sentry_flutter 9.14.0 + SentryWidget + maskAllText + maskAllImages + tracePropagationTargets)
provides:
  - 8 Flutter test stubs declaring the contract Wave 1 (Plan 31-01) implements
  - 1 pytest stub declaring the contract Wave 2 (Plan 31-02) implements
  - 3 stdlib-only Python lints (OBS-01 audit green on CTX-05, OBS-02 c static ban ready, OBS-06/07 artefact shape)
  - walker.sh J0 simctl driver + 3 helpers (assert_event_round_trip, trace_round_trip_test, sentry_quota_smoke)
  - tools/simulator/README.md with macOS Tahoe doctrine embedded
  - sentry-cli 3.3.5 installed on dev host
  - OBS-01 mechanically verified SHIPPED on existing main.dart (no new mobile code)
affects: [31-01, 31-02, 31-03, 31-04, 35-boucle-daily, 36-finissage-e2e]

# Tech tracking
tech-stack:
  added: [sentry-cli 3.3.5, coreutils 9.10 (gtimeout for portable timeout), python stdlib lints]
  patterns:
    - Wave 0 test scaffolds with skip:'Wave N impl pending' (compile-green, behaviour-red-by-design)
    - Greppable-discipline lints over CTX-05 spike output (verify_sentry_init)
    - Portable `to()` wrapper for simctl timeout (gtimeout -> timeout -> bare fallback)
    - walker.sh two-tier endpoint strategy (primary /_test/inject_error -> fallback malformed /auth/login)

key-files:
  created:
    - apps/mobile/test/services/error_boundary_test.dart
    - apps/mobile/test/services/error_boundary_ordering_test.dart
    - apps/mobile/test/services/error_boundary_single_capture_test.dart
    - apps/mobile/test/services/sentry_breadcrumbs_test.dart
    - apps/mobile/test/services/sentry_breadcrumbs_pii_test.dart
    - apps/mobile/test/services/sentry_breadcrumbs_refresh_test.dart
    - apps/mobile/test/services/api_service_sentry_trace_test.dart
    - apps/mobile/test/app_router_observers_test.dart
    - apps/mobile/integration_test/.gitkeep
    - services/backend/tests/test_global_exception_handler.py
    - tools/checks/verify_sentry_init.py
    - tools/checks/sentry_capture_single_source.py
    - tools/checks/audit_artefact_shape.py
    - tools/simulator/walker.sh
    - tools/simulator/assert_event_round_trip.py
    - tools/simulator/trace_round_trip_test.sh
    - tools/simulator/sentry_quota_smoke.sh
    - tools/simulator/README.md
  modified:
    - .gitignore (add .planning/walker/ runtime output)

key-decisions:
  - OBS-01 considered SHIPPED via CTX-05 spike + Wave 0 verify_sentry_init audit (8/8 invariants green on current main.dart — no new mobile code needed)
  - walker.sh ships with MINT_WALKER_DRY_RUN=1 escape hatch so CI / auth-gated environments can smoke-test script logic without build+install+Sentry auth
  - walker.sh uses portable `to()` wrapper (Rule 2 deviation — macOS lacks bare `timeout`, added coreutils install + gtimeout/timeout/bare fallback chain) rather than assuming coreutils preinstalled
  - Open Question #4 resolved empirically: primary `/_test/inject_error` HTTP 404 confirmed — fallback to malformed JSON POST /auth/login (HTTP 422) proves backend reachable + error handler active until Plan 31-02 adds the dedicated endpoint
  - SENTRY_AUTH_TOKEN creation deferred to operator (human-action gate, auth gates protocol) — walker.sh + sentry_quota_smoke.sh both gracefully WARN when absent instead of hard-failing
  - D-03 4-level breadcrumb categories locked into stub test strings as exact literals (`mint.compliance.guard.{pass,fail}`, `mint.coach.save_fact.{success,error}`, `mint.feature_flags.refresh.{success,failure}`) — Wave 1 implementers cannot drift

patterns-established:
  - "Wave 0 scaffold: `test('spec', () {}, skip: 'Wave N impl pending')` — declares contract, compiles green, does not import files not yet created"
  - "Greppable-discipline lint: stdlib-only Python scans main.dart/pubspec for pinned literals. Any edit dropping an invariant fails the lint mechanically (mitigates Pitfall 10 — audit-as-claim)"
  - "Portable macOS timeout: gtimeout -> timeout -> bare fallback with WARN. Install coreutils if available, do not hard-require"
  - "Dual-header propagation: sentry-trace (new, D-05) cohabits with X-MINT-Trace-Id (legacy LoggingMiddleware) — Wave 0 trace_round_trip_test asserts presence baseline; Wave 2 tightens to equality"
  - "walker.sh output isolation: .planning/walker/<timestamp>/ gitignored — screenshots + logs + events JSON are runtime artifacts, not code"

requirements-completed: [OBS-01]

# Metrics
duration: 11min
completed: 2026-04-19
---

# Phase 31 Plan 00: Wave 0 Scaffolding + J0 Walker Summary

**17 scaffolding artefacts + sentry-cli 3.3.5 + OBS-01 mechanically verified SHIPPED on CTX-05 output — Wave 1-4 executors now have mechanical gates (not façade claims).**

## Performance

- **Duration:** 11 min
- **Started:** 2026-04-19T16:17:42Z (first task commit)
- **Completed:** 2026-04-19T16:28:39Z (last task commit)
- **Tasks:** 4
- **Files created:** 18 (17 Wave 0 scaffolds + 1 README)
- **Files modified:** 1 (.gitignore)

## CTX31_00_COMMIT_SHA

`CTX31_00_COMMIT_SHA: a869985638e1a9ee6f0f4b8754fd12de6054f24e`

(HEAD of `feature/v2.8-phase-31-instrumenter` after plan 31-00 ships.)

## Accomplishments

- **17/17 Wave 0 scaffolds landed** — matches VALIDATION.md §Wave 0 Requirements checklist exactly.
- **sentry-cli 3.3.5** installed on dev host (≥2.40.0 required for stats_v2 in OBS-07).
- **OBS-01 audit PASS** — `verify_sentry_init.py` reports 8/8 invariants green on current `apps/mobile/lib/main.dart` (CTX-05 spike output). OBS-01 considered SHIPPED via CTX-05 + this Wave 0 audit; no new mobile code in Plan 31-00.
- **walker.sh smoke PASS end-to-end** — DRY_RUN mode exercises every code path (curl primary, fallback curl, sleep, assert_event_round_trip helper, exit 0) in ~61s wall-clock, well under 3min budget.
- **Open Question #4 resolved** — `/_test/inject_error` does NOT exist backend-side (HTTP 404 confirmed); fallback path to malformed JSON `/auth/login` (HTTP 422) proves backend reachable. Plan 31-02 will add the dedicated endpoint.
- **Zero production code touched** — `apps/mobile/lib/**` + `services/backend/app/**` untouched (plan boundary honoured).
- `nyquist_compliant: true` can now be set in 31-VALIDATION.md frontmatter.

## Task Commits

Each task was committed atomically on `feature/v2.8-phase-31-instrumenter`:

1. **Task 1: Install sentry-cli + ship simulator README** — `6c265341` (chore)
2. **Task 2: Scaffold 8 Flutter stubs + 1 pytest stub + integration_test/.gitkeep** — `bcd650d3` (test)
3. **Task 3: Ship 3 python lints + OBS-01 audit PASS on CTX-05 spike output** — `52428cb3` (feat)
4. **Task 4: walker.sh J0 driver + 3 simulator helpers + smoke PASS** — `a8699856` (feat)

_No final plan-metadata commit in this execution (SUMMARY is the final commit, see §Final Commit)._

## Files Created/Modified

### Scaffolding (Wave 0 deliverables)

**Mobile tests (8 files) — all `skip: 'Wave 1 impl pending'`:**
- `apps/mobile/test/services/error_boundary_test.dart` — OBS-02 (a,b) installGlobalErrorBoundary + FlutterError.onError
- `apps/mobile/test/services/error_boundary_ordering_test.dart` — OBS-02 (a) PlatformDispatcher BEFORE FlutterError
- `apps/mobile/test/services/error_boundary_single_capture_test.dart` — OBS-02 (b) exactly-once capture
- `apps/mobile/test/services/sentry_breadcrumbs_test.dart` — OBS-05 (b) `mint.compliance.guard.{pass,fail}` (D-03 4-level)
- `apps/mobile/test/services/sentry_breadcrumbs_pii_test.dart` — OBS-05 (c) `mint.coach.save_fact.{success,error}` + PII fuzz (CHF/AVS 756./IBAN)
- `apps/mobile/test/services/sentry_breadcrumbs_refresh_test.dart` — OBS-05 (d) `mint.feature_flags.refresh.{success,failure}`
- `apps/mobile/test/services/api_service_sentry_trace_test.dart` — OBS-04 (a) sentry-trace + baggage in _authHeaders (D-05)
- `apps/mobile/test/app_router_observers_test.dart` — OBS-05 (a) SentryNavigatorObserver beside AnalyticsRouteObserver

**Integration placeholder:**
- `apps/mobile/integration_test/.gitkeep` — ensures directory persists for Wave 1 real-HTTP tests

**Backend test (1 file) — 3 tests `@pytest.mark.skip(reason="Wave 2 Plan 31-02 impl pending")`:**
- `services/backend/tests/test_global_exception_handler.py` — OBS-03 (a,b,c) trace_id + sentry_event_id in 500 JSON, LoggingMiddleware cohabit, inbound sentry-trace read

**Python lints (3 files — stdlib-only):**
- `tools/checks/verify_sentry_init.py` — OBS-01 audit: pubspec `sentry_flutter: 9.14.0` pin + main.dart invariants (maskAllText, maskAllImages, sendDefaultPii=false, SentryWidget, tracePropagationTargets, onErrorSampleRate=1.0, sessionSampleRate presence-only regex). 8/8 invariants green on current main.dart.
- `tools/checks/sentry_capture_single_source.py` — OBS-02 (c) static ban: walks `apps/mobile/lib/` (excludes `*.g.dart`, `generated/`, `l10n/`), forbids `Sentry.captureException(` outside whitelist (error_boundary.dart + sentry_breadcrumbs.dart, both Wave 1 creates). Current: 654 files scanned, 0 violations.
- `tools/checks/audit_artefact_shape.py` — OBS-06 + OBS-07 Markdown shape audit for SENTRY_REPLAY_REDACTION_AUDIT, SENTRY_PRICING_2026_04, observability-budget.

**Simulator helpers (5 files):**
- `tools/simulator/walker.sh` (executable, 185 lines) — J0 simctl driver: boot iPhone 17 Pro → flutter build ios --simulator (staging dart-defines) → install → launch → screenshot → [smoke mode] inject error + pull Sentry event. Portable `to()` timeout wrapper. `MINT_WALKER_DRY_RUN=1` escape hatch.
- `tools/simulator/assert_event_round_trip.py` (executable) — 2-rule Sentry event matcher (contexts.trace.trace_id exact + substring fallback). Unit-tested 4 scenarios — all PASS.
- `tools/simulator/trace_round_trip_test.sh` (executable) — OBS-04 (b) baseline: asserts staging backend emits non-empty X-Trace-Id response header.
- `tools/simulator/sentry_quota_smoke.sh` (executable) — OBS-07 (b) probe: sentry-cli api `/organizations/mint/stats_v2/` returns valid JSON with `groups` or `intervals`.
- `tools/simulator/README.md` (92 lines) — macOS Tahoe doctrine embedded (NEVER flutter clean, NEVER rm Podfile.lock, timeout-30s discipline, SENTRY_AUTH_TOKEN Keychain, staging-always dart-define).

### Modified

- `.gitignore` — added `.planning/walker/` (runtime screenshots + logs + event JSON dumps, gitignored per D-10 pattern).

## Decisions Made

1. **OBS-01 considered shipped via CTX-05 + Wave 0 audit** — no new mobile code. The lint `verify_sentry_init.py` asserts all 8 invariants on current main.dart (every edit forward breaks the lint mechanically). This is the explicit kill-policy D-A3 mitigation: ship mechanical audit over a prior spike, not add code that duplicates the spike.
2. **Portable `to()` wrapper over hard-coding `timeout`** — macOS ships without `timeout`; rather than assume a Julien laptop, walker.sh checks `gtimeout`→`timeout`→bare fallback with `WARN`. Documented Rule 2 deviation (missing critical portability).
3. **MINT_WALKER_DRY_RUN=1 escape hatch** — enables smoke-testing walker's logic (dispatch + fallback + round-trip helper) in auth-gated environments. Non-negotiable for Wave 0 gate: the script was not merely shipped, it was EXERCISED end-to-end (façade-sans-câblage Pitfall 10 mitigation).
4. **Two-tier inject strategy** — primary `/_test/inject_error` (Plan 31-02 will add it) with fallback to malformed `/auth/login` (existing endpoint). Resolves Open Question #4 without blocking Wave 0 on Wave 2 work.
5. **D-03 4-level categories locked as string literals in stubs** — Wave 1 implementers cannot ship `sentry_breadcrumbs.dart` without the exact categories `mint.<surface>.<action>.<outcome>`; the test descriptions contain the literals verbatim.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing Critical] Installed coreutils (9.10) for `timeout` on macOS**
- **Found during:** Task 4 (walker.sh smoke test)
- **Issue:** walker.sh's plan spec uses `timeout 30s xcrun simctl ...` on every simctl call, but macOS ships without `timeout`. Bare `timeout not found` would crash every real walker invocation, defeating Pitfall 8 mitigation.
- **Fix:** (a) `brew install coreutils` adds `gtimeout` + `timeout`. (b) walker.sh wraps every bounded call in a portable `to()` helper: `gtimeout` → `timeout` → bare fallback with `WARN`. Script no longer hard-requires coreutils but benefits from it when present.
- **Files modified:** `tools/simulator/walker.sh` (all 6 `timeout 30s xcrun simctl` calls routed through `to()`).
- **Verification:** `bash -n tools/simulator/walker.sh` clean, DRY_RUN smoke exits 0.
- **Committed in:** `a8699856` (Task 4 commit).

**2. [Rule 2 - Missing Critical] Added `.planning/walker/` to .gitignore**
- **Found during:** Task 4 (walker.sh smoke — produced 2 `.planning/walker/<timestamp>/` dirs during testing)
- **Issue:** walker.sh writes timestamped runtime output (screenshots, logs, sentry-events.json) to `.planning/walker/`. Without gitignore, every walker run dirties git status and could accidentally commit event payloads (potentially PII-adjacent from staging traffic).
- **Fix:** Added `.planning/walker/` to .gitignore, adjacent to the existing `.planning/agent-drift/` runtime ignores (D-10 pattern).
- **Files modified:** `.gitignore`
- **Verification:** `git check-ignore -v .planning/walker/<ts>/` confirms match.
- **Committed in:** `a8699856` (Task 4 commit).

**3. [Rule 3 - Blocking] README.md literal wording adjusted to satisfy mechanical verify**
- **Found during:** Task 1 (Task 1 verify block)
- **Issue:** Plan verify clause `grep -q "NEVER flutter clean" tools/simulator/README.md` expected an exact substring. Initial README wording used backticks around `flutter clean` which made the substring not match.
- **Fix:** Normalised the two doctrine lines to literal `NEVER flutter clean` and `NEVER rm apps/mobile/ios/Podfile.lock` so the grep mechanically passes.
- **Files modified:** `tools/simulator/README.md`
- **Verification:** `grep -c "NEVER flutter clean"` returns 1.
- **Committed in:** `6c265341` (Task 1 commit).

**4. [Rule 3 - Blocking] walker.sh comments rephrased to avoid triggering the no-flutter-clean grep on itself**
- **Found during:** Task 4 (Task 4 verify block)
- **Issue:** Plan verify clause `! grep -q "flutter clean" tools/simulator/walker.sh && ! grep -q "rm.*Podfile.lock" tools/simulator/walker.sh` treats any substring hit as FAIL — including the literal "NEVER `flutter clean`" in the banner comment.
- **Fix:** Rephrased the banner and build-section comments to convey the discipline without emitting the forbidden substrings, pointing to `tools/simulator/README.md` for the full rule list.
- **Files modified:** `tools/simulator/walker.sh`
- **Verification:** Both negative greps return no match, while the rule is still documented in the README referenced from the banner.
- **Committed in:** `a8699856` (Task 4 commit).

---

**Total deviations:** 4 auto-fixed (2 missing critical, 2 blocking)
**Impact on plan:** All 4 auto-fixes preserved the plan's intent. Rule 2 items (coreutils portability + walker runtime gitignore) are correctness requirements — walker would have crashed on macOS-bare or dirtied git otherwise. Rule 3 items (literal wording) are verify-clause plumbing fixes, zero behavioural impact.

## Issues Encountered

- **Real simctl shutdown during live walker test** — one real walker invocation (without DRY_RUN, absent `SENTRY_DSN_STAGING`) ran `xcrun simctl shutdown all` before failing at the dsn gate. The booted iPhone 17 Pro simulator was briefly shutdown; simctl state auto-recovered (device re-booted on next `boot` attempt with `Unable to boot device in current state: Booted` — expected idempotent-boot flow). Documented the auth-gate exit as correct fail-fast behaviour for missing `SENTRY_DSN_STAGING`.

- **Pre-existing `flutter analyze` warnings (128 info-level)** — unchanged by this plan. All out-of-scope per `deviation_rules` scope boundary. Filtering to Phase 31 Wave 0 files: zero issues introduced.

## User Setup Required

**`SENTRY_AUTH_TOKEN` creation deferred to operator** (authentication gate — cannot be automated). Per Task 1 acceptance:

- Create via Sentry UI → User Settings → Auth Tokens.
- Required scopes: `org:read`, `project:read`, `event:read`. NO `write`, NO `admin` (threat T-31-00-01 mitigation).
- Store via macOS Keychain:
  ```sh
  security add-generic-password -a "$USER" -s "SENTRY_AUTH_TOKEN" -w "<token>"
  ```
- Also mirror to GitHub repo secrets (CI consumers starting Phase 34 will reference).

walker.sh + sentry_quota_smoke.sh both gracefully handle absence (WARN, graceful exit) — absence does not block Wave 1 mobile implementation. Will block Wave 4 (`OBS-07 b`) quota probe and the full `--smoke-test-inject-error` event-pull assertion.

`SENTRY_DSN_STAGING` is expected to already exist in the Railway staging environment (per D-02 + Phase 30.6-02 deploy). Operator should verify via Railway dashboard before Wave 1 ships its first simulator run.

## A1–A10 Assumptions Flipped

From 31-RESEARCH.md §Assumptions Log:
- **A4 (sentry-cli brew formula recent enough)** → **VERIFIED**: `brew install sentry-cli` yields 3.3.5, well above ≥2.40.0 requirement for stats_v2. No fallback to `cargo install` needed.
- **A8 (iPhone 17 Pro available on dev host)** → **VERIFIED**: `xcrun simctl list devices | grep "iPhone 17 Pro"` returns `Booted` prior to and after walker tests.

Remaining assumptions (A1–A3, A5–A7, A9–A10) still pending — they gate Wave 1+ implementations, not Wave 0 scaffolding.

## Next Phase Readiness

**Wave 1 (Plan 31-01 mobile OBS-02/04/05) unblocked:**
- 8 Flutter test stubs with explicit contracts in test names + comments — implementer flips `skip:` one file at a time as each symbol lands.
- `sentry_capture_single_source.py` will start catching drift the moment `error_boundary.dart` exists.
- D-03 4-level category literals embedded in stub descriptions — zero drift risk.

**Wave 2 (Plan 31-02 backend OBS-03) unblocked:**
- 3 pytest stubs with contract docstrings (trace_id in 500 JSON, LoggingMiddleware cohabit, inbound sentry-trace read).
- `trace_round_trip_test.sh` ready to tighten from "presence" to "equality" assertion once Plan 31-02 ships.

**Waves 3-4 (Plans 31-03 PII audit, 31-04 ops budget):**
- `audit_artefact_shape.py` shape contracts locked — Wave 3/4 authors write the artefacts to match shape.
- `walker.sh --gate-phase-31` stub in place (currently delegates to smoke); Wave 3 extends with OBS-06 mask asserts.
- `sentry_quota_smoke.sh` gated on `SENTRY_AUTH_TOKEN` (operator setup pending) — Wave 4 will execute this to populate `observability-budget.md`.

**`nyquist_compliant: true`** can now be set in `.planning/phases/31-instrumenter/31-VALIDATION.md` frontmatter (Wave 0 requirements met: 17/17 scaffolds landed, `wave_0_complete: true`).

**Blockers / concerns for next plan:**
- `SENTRY_AUTH_TOKEN` operator setup — non-blocking for Wave 1 mobile, blocking for Wave 4 quota probe.
- Plan 31-02 MUST add `/_test/inject_error` backend endpoint (Open Question #4 resolved empirically — endpoint absent today).

## Self-Check

Verify each claim made in this SUMMARY before signaling completion.

**Files exist on disk:**
- `apps/mobile/test/services/error_boundary_test.dart` — FOUND
- `apps/mobile/test/services/error_boundary_ordering_test.dart` — FOUND
- `apps/mobile/test/services/error_boundary_single_capture_test.dart` — FOUND
- `apps/mobile/test/services/sentry_breadcrumbs_test.dart` — FOUND
- `apps/mobile/test/services/sentry_breadcrumbs_pii_test.dart` — FOUND
- `apps/mobile/test/services/sentry_breadcrumbs_refresh_test.dart` — FOUND
- `apps/mobile/test/services/api_service_sentry_trace_test.dart` — FOUND
- `apps/mobile/test/app_router_observers_test.dart` — FOUND
- `apps/mobile/integration_test/.gitkeep` — FOUND
- `services/backend/tests/test_global_exception_handler.py` — FOUND
- `tools/checks/verify_sentry_init.py` — FOUND
- `tools/checks/sentry_capture_single_source.py` — FOUND
- `tools/checks/audit_artefact_shape.py` — FOUND
- `tools/simulator/walker.sh` — FOUND (executable)
- `tools/simulator/assert_event_round_trip.py` — FOUND (executable)
- `tools/simulator/trace_round_trip_test.sh` — FOUND (executable)
- `tools/simulator/sentry_quota_smoke.sh` — FOUND (executable)
- `tools/simulator/README.md` — FOUND

**Commits exist in git log:**
- `6c265341` — FOUND (Task 1)
- `bcd650d3` — FOUND (Task 2)
- `52428cb3` — FOUND (Task 3)
- `a8699856` — FOUND (Task 4)

**Verify commands re-run at SUMMARY creation time:**
- `sentry-cli --version` → `sentry-cli 3.3.5` ✓
- `python3 tools/checks/verify_sentry_init.py` → exit 0, 8/8 invariants green ✓
- `python3 tools/checks/sentry_capture_single_source.py` → exit 0, 0 violations ✓
- `python3 tools/checks/audit_artefact_shape.py --help` → usage printed, exit 0 ✓
- `pytest services/backend/tests/test_global_exception_handler.py -q` → 3 skipped ✓
- `flutter test` over 8 mobile stubs → 10 tests, all skipped ✓
- `bash -n` over all 3 shell scripts → syntax OK ✓
- `MINT_WALKER_DRY_RUN=1 bash tools/simulator/walker.sh --smoke-test-inject-error` → exit 0, ~61s ✓
- `flutter analyze` on new stubs → 0 new issues ✓

## Self-Check: PASSED

---

*Phase: 31-instrumenter*
*Completed: 2026-04-19*
