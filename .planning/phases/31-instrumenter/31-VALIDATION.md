---
phase: 31
slug: instrumenter
status: in_progress
nyquist_compliant: true
wave_0_complete: true
created: 2026-04-19
wave_0_completed: 2026-04-19
---

# Phase 31 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.
> Full Validation Architecture reference: `31-RESEARCH.md` §Validation Architecture.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Flutter `flutter_test` + `integration_test` (SDK) / Backend `pytest` 7.x / Shell `bash` + `tools/simulator/walker.sh` + `sentry-cli api` |
| **Config file** | `apps/mobile/test/` + new `apps/mobile/integration_test/` / `services/backend/pytest.ini` (existing) + new `services/backend/tests/test_global_exception_handler.py` |
| **Quick run command** | `cd apps/mobile && flutter test test/services/error_boundary_test.dart test/services/sentry_breadcrumbs_test.dart test/services/api_service_sentry_trace_test.dart -r compact && cd ../../services/backend && python3 -m pytest tests/test_global_exception_handler.py -q` |
| **Full suite command** | `cd apps/mobile && flutter test && cd ../../services/backend && python3 -m pytest tests/ -q && bash tools/simulator/walker.sh --gate-phase-31` |
| **Estimated runtime** | ~45s mobile + ~30s backend + ~3min walker.sh = ~5 min full |

---

## Sampling Rate

- **Per task commit** (<30s): scoped quick run on changed files
- **Per wave merge** (<5 min): full suite + `walker.sh --gate-phase-31`
- **Phase gate (non-skippable)**: full suite green + walker.sh green + OBS-06 PII audit signed + Julien creator-device walkthrough 10-min manual signed

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Secure Behavior | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------------|-----------|-------------------|-------------|--------|
| 31-00-01 | 00 | 0 | OBS-01..07 | Test scaffolding lands | infra | `ls apps/mobile/test/services/ && ls services/backend/tests/ && ls tools/simulator/` | ✅ shipped | ✅ |
| 31-00-02 | 00 | 0 | J0 gate | walker.sh boot → install → screenshot → pull events <3min | integration | `MINT_WALKER_DRY_RUN=1 bash tools/simulator/walker.sh --smoke-test-inject-error` (~61s) | ✅ shipped | ✅ |
| 31-00-03 | 00 | 0 | Deps | `sentry-cli` installed | env | `which sentry-cli && sentry-cli --version` -> 3.3.5 | ✅ shipped | ✅ |
| 31-01-01 | 01 (mobile) | 1 | OBS-02 (a) | PlatformDispatcher.onError set BEFORE FlutterError.onError | unit | `flutter test test/services/error_boundary_ordering_test.dart -x` | ❌ W0 | ⬜ |
| 31-01-02 | 01 | 1 | OBS-02 (b) | Sentry.captureException called exactly once per error | unit | `flutter test test/services/error_boundary_single_capture_test.dart -x` | ❌ W0 | ⬜ |
| 31-01-03 | 01 | 1 | OBS-02 (c) | Ban direct Sentry.captureException outside error_boundary.dart | static | `python3 tools/checks/sentry_capture_single_source.py` | ❌ W0 | ⬜ |
| 31-01-04 | 01 | 1 | OBS-04 (a) | _authHeaders() returns sentry-trace + baggage when span active | unit | `flutter test test/services/api_service_sentry_trace_test.dart -x` | ❌ W0 | ⬜ |
| 31-01-05 | 01 | 1 | OBS-04 (b) | Real-HTTP staging round-trip mobile→backend trace_id matches | integration | `bash tools/simulator/trace_round_trip_test.sh` | ❌ W0 | ⬜ |
| 31-01-06 | 01 | 1 | OBS-04 (c) | Sentry UI cross-project link visible | manual | See Manual-Only §OBS-04 | n/a | ⬜ |
| 31-01-07 | 01 | 1 | OBS-05 (a) | SentryNavigatorObserver in root GoRouter observers | unit | `flutter test test/app_router_observers_test.dart -x` | ❌ W0 | ⬜ |
| 31-01-08 | 01 | 1 | OBS-05 (b) | MintBreadcrumbs.complianceGuard() category + non-PII data | unit | `flutter test test/services/sentry_breadcrumbs_test.dart -x` | ❌ W0 | ⬜ |
| 31-01-09 | 01 | 1 | OBS-05 (c) | MintBreadcrumbs.saveFact() emits fact_kind enum only (no value) | unit | `flutter test test/services/sentry_breadcrumbs_pii_test.dart -x` | ❌ W0 | ⬜ |
| 31-01-10 | 01 | 1 | OBS-05 (d) | MintBreadcrumbs.featureFlagsRefresh() emits success + failure | unit | `flutter test test/services/sentry_breadcrumbs_refresh_test.dart -x` | ❌ W0 | ⬜ |
| 31-02-01 | 02 (backend) | 2 | OBS-03 (a) | Global handler returns trace_id + sentry_event_id in 500 JSON | unit | `pytest services/backend/tests/test_global_exception_handler.py::test_returns_trace_id -x` | ❌ W0 | ⬜ |
| 31-02-02 | 02 | 2 | OBS-03 (b) | Handler preserves X-Trace-Id from LoggingMiddleware | unit | `pytest .../test_global_exception_handler.py::test_preserves_logging_middleware_trace_id -x` | ❌ W0 | ⬜ |
| 31-02-03 | 02 | 2 | OBS-03 (c) | Handler reads inbound sentry-trace and uses that trace_id | unit | `pytest .../test_global_exception_handler.py::test_reads_inbound_sentry_trace -x` | ❌ W0 | ⬜ |
| 31-03-01 | 03 (PII audit) | 3 | OBS-06 | Redaction artefact committed, 5 screens × masked | artefact | `test -s .planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md && python3 tools/checks/audit_artefact_shape.py SENTRY_REPLAY_REDACTION_AUDIT` | ❌ W0 | ⬜ |
| 31-03-02 | 03 | 3 | OBS-06 walkthrough | Each screen audited on simulator, screenshot + mask state | manual | See Manual-Only §OBS-06 | n/a | ⬜ |
| 31-04-01 | 04 (ops) | 4 | OBS-07 (a) | Budget artefact committed with pricing fetch date + projection | artefact | `test -s .planning/observability-budget.md && test -s .planning/research/SENTRY_PRICING_2026_04.md` | ❌ W0 | ⬜ |
| 31-04-02 | 04 | 4 | OBS-07 (b) | sentry-cli api stats_v2 returns valid usage JSON | integration | `bash tools/simulator/sentry_quota_smoke.sh` | ❌ W0 | ⬜ |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

> Scaffolding that must land BEFORE Wave 1 production code begins.

- [x] `apps/mobile/test/services/error_boundary_test.dart` — stub (OBS-02 a,b)
- [x] `apps/mobile/test/services/error_boundary_ordering_test.dart` — stub (OBS-02 a)
- [x] `apps/mobile/test/services/error_boundary_single_capture_test.dart` — stub (OBS-02 b)
- [x] `apps/mobile/test/services/sentry_breadcrumbs_test.dart` — stub (OBS-05 b)
- [x] `apps/mobile/test/services/sentry_breadcrumbs_pii_test.dart` — stub (OBS-05 c)
- [x] `apps/mobile/test/services/sentry_breadcrumbs_refresh_test.dart` — stub (OBS-05 d)
- [x] `apps/mobile/test/services/api_service_sentry_trace_test.dart` — stub (OBS-04 a)
- [x] `apps/mobile/test/app_router_observers_test.dart` — stub (OBS-05 a)
- [x] `apps/mobile/integration_test/` directory — create if absent (.gitkeep shipped)
- [x] `services/backend/tests/test_global_exception_handler.py` — stub (OBS-03 a,b,c)
- [x] `tools/checks/verify_sentry_init.py` — stub (OBS-01 audit of CTX-05 output) — **8/8 invariants PASS**
- [x] `tools/checks/sentry_capture_single_source.py` — stub (OBS-02 c static ban) — 654 files scanned, 0 violations
- [x] `tools/checks/audit_artefact_shape.py` — stub (OBS-06 + OBS-07 artefact shape)
- [x] `tools/simulator/walker.sh` — **J0 livrable** (simctl driver iPhone 17 Pro + error inject + Sentry pull) — smoke PASS ~61s
- [x] `tools/simulator/assert_event_round_trip.py` — helper for walker smoke
- [x] `tools/simulator/trace_round_trip_test.sh` — OBS-04 (b) integration
- [x] `tools/simulator/sentry_quota_smoke.sh` — OBS-07 (b) integration
- [x] Framework install: `brew install sentry-cli` (blocking dep, run in Plan 31-00) — **3.3.5 installed**

*Wave 0 MUST complete before Wave 1 (mobile OBS-02/04/05 implementation).*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Sentry UI cross-project link visible (mobile → backend in same trace) | OBS-04 (c) | Sentry UI rendering server-side, no API assertion matches UX | 1. Trigger error via walker.sh with known trace_id. 2. Open Sentry UI within 60s. 3. Click event. 4. Verify "Trace" panel shows linked backend transaction. 5. Screenshot + commit in `SENTRY_REPLAY_REDACTION_AUDIT.md` §A4-visual. |
| 5 sensitive screens masked on simulator Replay | OBS-06 walkthrough | Frame-by-frame visual inspection required | 1. Flip `sessionSampleRate=0.05` on staging. 2. Walker.sh record session on 5 screens (CoachChat, DocumentScan, ExtractionReviewSheet, Onboarding, Budget). 3. Open replay in Sentry UI. 4. Pause on frames rendering CHF/IBAN/AVS. 5. Verify black box overlay. Screenshot per screen. |
| creator-device 10-min cold-start walkthrough (Julien iPhone physique) | Phase 31 gate (L3) | simctl ≠ real device (APNs/Face ID/camera must exercise) | 1. Build staging IPA + install iPhone 17 Pro. 2. Kill app. 3. Cold-start timer. 4. Run 5 critical journeys. 5. Inject fake error via dev menu. 6. Within 60s open Sentry UI verify event + replay + cross-project linked. 7. Screenshot + commit `DEVICE_WALKTHROUGH.md`. |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify OR Wave 0 dependency OR Manual-Only entry
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify (Manual-Only per-wave-end)
- [ ] Wave 0 covers all 17 scaffolding items above
- [ ] No watch-mode flags (one-shot tests only)
- [ ] Feedback latency <5 min full suite
- [ ] `nyquist_compliant: true` set in frontmatter after Wave 0 complete

**Approval:** pending
