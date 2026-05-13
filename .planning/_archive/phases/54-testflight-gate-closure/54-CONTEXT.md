# Phase 54 — TestFlight Gate Closure (CONTEXT)

**Status:** Drafting
**Origin:** 5-expert MINT panel synthesis at `.planning/decisions/2026-05-04-phase-54-target.md`. Expert 5 (Production Readiness / TestFlight Auditor) verdict: « no primary-surface tap-to-render walkthrough has ever been signed against dev tip — `AUDIT_TAP_RENDER.md` still has 100% TODO rows, and GATE-01/GATE-02 (v2.7 device gate) remain unresolved despite testflight.yml being live ».

**Goal (one sentence):** ship MINT to TestFlight staging — autonomous walker walkthrough across all primary-depth interactive surfaces (3 tabs + drawer = 56 rows of `AUDIT_TAP_RENDER.md`), wire intentTag → tappable chip on every coach opener so the walker has something to tap, triage all FAILs, bump version, push staging, watch testflight.yml succeed, confirm Apple build processes.

## Why now

All other infra blockers are CLOSED:
- ✅ `.github/workflows/testflight.yml` LIVE — auto-triggers on push to staging
- ✅ App Store Connect secrets wired, Match certs configured
- ✅ `apps/mobile/ios/Runner/PrivacyInfo.xcprivacy` filled (12 data types declared)
- ✅ Account-deletion endpoint (`services/backend/app/api/v1/endpoints/auth.py:993` — `DELETE /auth/account`) wired in mobile (`apps/mobile/lib/services/api_service.dart:586`)
- ✅ Sentry initialized both sides, release tagging in place
- ✅ Phase 52.x privacy gating + Phase 52.3/52.4 truth-in-crypto + Phase 53.x architecture parity + sequence wiring + commitments visibility all merged

**Single missing artifact:** the actual walk. Per `feedback_device_gates.md`: « sim + idb are wired so Claude does device walkthroughs autonomously, don't defer to Julien ». The tooling exists at `tools/simulator/walker.sh` + `test_walker_archetype.sh` (Phase 53-01's PR #443 dependency).

Per 3 independent sources: this is the **literal TestFlight blocker**:
- `.planning/MILESTONES.md:109` — « Explicitly carried into v2.2 as a Phase 0 manual gate blocking TestFlight »
- `.planning/backlog/STAB-carryover.md:38` — « BLOCKING TestFlight … Don't ship TestFlight without it »
- `.planning/research/_pre-v2.2-archive/PITFALLS.md:191` — « STAB-17 walkthrough (blocks TestFlight) »

## Scope (locked)

Three sub-plans, executed sequentially:

### Plan 54-01 — Autonomous walker walkthrough across `AUDIT_TAP_RENDER.md`

**Target:** every primary-depth onTap/onPressed/onChanged/onSubmit element across Aujourd'hui / Coach / Explorer / ProfileDrawer (≥56 rows per the existing scaffold).

**Deliverables:**
1. New `tools/simulator/walker_audit_tap_render.sh` — reads `.planning/milestones/v2.1-phases/07-stabilisation-v2-0/AUDIT_TAP_RENDER.md` row list, drives sim taps via cliclick + idb (using the helpers from Plan 53-01's `walker.sh`), captures screenshot per row, asserts non-blank render via sha256 distinctness + Sentry breadcrumb match.
2. Each row's PASS/FAIL/skipped verdict written back to a generated `.planning/phases/54-testflight-gate-closure/AUDIT_TAP_RENDER_RESULTS.md` (don't mutate the scaffold itself — scaffold stays as the contract).
3. FAILs filed as `.planning/phases/54-testflight-gate-closure/triage/F-XX-<surface>.md` for triage in Plan 54-03.
4. Acceptance: walker reaches the « completion » breadcrumb at end of each row's tap sequence; no SimulatorCrash / FlutterError / AssertionError / scroll-stuck-on-loading.

**Hard exclusions:**
- No code fixes here — walker is read-only on the app.
- No new screens.
- Skipped rows (« opens external URL », « device-only feature », etc.) are explicitly classified, not silently dropped.

### Plan 54-02 — `intentTag` → tappable chip wiring (Expert 4 pivot)

**Target:** every coach opener that today emits a plain text bubble must offer the user a tap-to-act chip when an `intentTag` is available. Without this, Plan 54-01's walker has nothing to tap on the proactive openers.

**Deliverables:**
1. Refactor `coach_chat_screen._addCoachOpenerMessage(String)` → `_addCoachOpenerMessage({required String content, String? intentTag, List<ResponseCard>? cards})` (`apps/mobile/lib/screens/coach/coach_chat_screen.dart:502-514`).
2. Patch 3 callers:
   - `_maybeShowProactiveTrigger` — pass `trigger.intentTag` (`proactive_trigger_service.dart:75-98` populates it, but the field was dropped on the floor at `_resolveProactiveOpener` `:521`).
   - `_injectSequencePrompt` (post-Plan 53-02 wiring) — already passes the next step's intentTag; verify the chip renders.
   - New 4th caller reading `PrecomputedInsightsService.getCachedInsight(prefs:)` on chat-open and surfacing it as the opener with its `intentTag` chip (Expert 4 evidence: « 0 UI consumers in `lib/screens/` »).
3. Render the chip via existing `RouteSuggestionCard` (now Plan 53-02-aware: passing `intentTag` also fires `SequenceChatHandler.startSequence`). Single navigation lock to avoid duplicate pushes against the LLM-emitted `route_to_screen` path.
4. Walker harness extension: `walker_audit_tap_render.sh` includes one row per coach-opener type (proactive trigger, precomputed insight, sequence-step) to verify chips render + tap.

**Hard exclusions:**
- No new ChatMessage types.
- No new backend tools.
- No design panel needed if reusing `RouteSuggestionCard` shell unchanged.

### Plan 54-03 — FAIL triage + ship to TestFlight

**Target:** triage every Plan 54-01 FAIL, ship fixes, walker re-runs to PASS, ship to TestFlight staging.

**Deliverables:**
1. For each `triage/F-XX-<surface>.md`: root-cause analysis, fix in a focused PR, walker re-runs row to PASS.
2. Bump `apps/mobile/pubspec.yaml` from `2.2.0+1` to `2.9.0+N` (matches the `phase-40-marge-fiscale` historical numbering even though that branch was deleted; `.planning/MILESTONES.md` had v2.9 reserved).
3. Push to staging branch → testflight.yml triggers → assert build success in Apple Connect.
4. Sign off `docs/DEVICE_GATE_V27_CHECKLIST.md` GATE-01 (iPhone, 18 checks) + GATE-02 (Android — defer if Android build is not yet wired).
5. Phase 54 close-out audit re-spawns the 4-expert post-merge panel: load-bearing question « is MINT shippable to TestFlight today? »

**Hard exclusions:**
- No new feature work — all PRs are FAIL fixes only.
- No backend changes unless a FAIL traces to a backend bug.
- No production push to App Store proper — staging only (TestFlight beta).

## Locked decisions

### D-01 — Walker is read-only
Plan 54-01's walker only OBSERVES + screenshots. It does NOT mutate state, persist data, write SharedPreferences, or call backend. This keeps walker runs safely re-entrant and reproducible across CI / dev / staging.

### D-02 — Chip wiring (Plan 54-02) before walker run (Plan 54-01)
Plan 54-02 must land BEFORE Plan 54-01 executes against dev tip, or the walker has no chips to tap on the proactive openers. Sequencing reflected in PLAN.md task ordering.

### D-03 — Sub-plan PR strategy
Each sub-plan ships as 1-2 PRs. Plan 54-03's per-FAIL fixes ship as separate small PRs (one per surface) for clean review + bisectable fixes.

### D-04 — Android explicitly deferred to Phase 55+
Android build pipeline + GATE-02 sign-off is OUT OF SCOPE for Phase 54. iOS-only TestFlight is the goal. Android added as Phase 55 candidate.

### D-05 — Feature-flag gate for any in-progress UI surfaces
If walker hits a screen that's behind a feature flag (e.g. partial v2.10 work), check the flag is OFF in the staging build. If ON but incomplete, file as FAIL in 54-01 and gate the flag OFF in 54-03.

## Acceptance criteria (Phase 54 close-out)

1. `AUDIT_TAP_RENDER_RESULTS.md` produced; every row classified PASS / SKIP / FAIL with screenshot evidence.
2. Plan 54-02 chip wiring landed; Plan 53-02's `_injectSequencePrompt` and `_maybeShowProactiveTrigger` both render chips; PrecomputedInsight surfaces on chat-open.
3. All FAILs from Plan 54-01 resolved (or explicitly punted to Phase 55+ with documented rationale per surface).
4. `pubspec.yaml` bumped, staging push succeeds, testflight.yml green.
5. Apple Connect shows the new build processing without errors.
6. `docs/DEVICE_GATE_V27_CHECKLIST.md` GATE-01 signed.
7. Post-Phase-54 4-expert close-out panel returns « MINT shippable to TestFlight today: PASS ».
8. HTML evidence: `.planning/phases/54-testflight-gate-closure/54-VERIFICATION-REPORT.html` updated on every PR landing.

## Out of scope (deferred)

- Chat Vivant scene injection (Expert 1 + Phase 55 candidate)
- Activate the 9 unactivated SequenceTemplates beyond `retirement_prep` (Phase 55+)
- Android build pipeline + GATE-02 (Phase 55+)
- Production App Store submission (post-TestFlight beta validation)
- Performance / cold-start budget tuning (separate phase if FAILs surface latency issues)

## Risks + mitigations

| Risk | Mitigation |
|---|---|
| Walker FAIL count exceeds 10 (Expert 5's « expect 5-10 FAILs at minimum given v2.8/v2.9 churn ») | Triage in priority order: SimulatorCrash > FlutterError > nav-dead-end > visual-regression. Punt visual regressions to Phase 55+ if they don't block TestFlight processing. |
| Walker can't reach a row because of pre-existing nav bug (e.g. cap_du_jour_banner blocks bottom-tab access in some states) | File as FAIL with screenshot; root-cause analysis in 54-03 may reveal a pre-Plan 53-02 bug that should be fixed in this phase regardless. |
| Apple Connect rejects the build (missing entitlement, missing privacy declaration update) | testflight.yml dry-run on a sandbox profile first. The PrivacyInfo.xcprivacy is already filled per Expert 5 evidence; Phase 53.x privacy work added new data flows that may need a manifest update. |
| Plan 53-02's `_injectSequencePrompt` content « Étape suivante : ${action.progressLabel} » is hardcoded French (caught by Adversarial reviewer in panel) | Plan 54-02 includes ARB-routing the new copy + adding a regression test asserting the string is not hardcoded. |
| Walker captures screenshots that include sensitive seed data (PII from archetype seeds) | Walker uses fixture archetype data only (`MINT_E2E_ARCHETYPE`); never seeds real user data. Evidence dir `.gitignore`-d for screenshot images, with PASS/FAIL row map committed as text only. |

## References

- Decision artifact: `.planning/decisions/2026-05-04-phase-54-target.md`
- Expert 5 evidence: `.planning/MILESTONES.md:109`, `.planning/backlog/STAB-carryover.md:38`, `.planning/research/_pre-v2.2-archive/PITFALLS.md:191`
- Walker tooling: `tools/simulator/walker.sh` + `tools/simulator/test_walker_archetype.sh` (PR #443)
- AUDIT_TAP_RENDER scaffold: `.planning/milestones/v2.1-phases/07-stabilisation-v2-0/AUDIT_TAP_RENDER.md` (56 rows, 100% TODO)
- Device gate matrix: `docs/DEVICE_GATE_V27_CHECKLIST.md`
- TestFlight pipeline: `.github/workflows/testflight.yml`
- Coach opener wiring targets: `apps/mobile/lib/screens/coach/coach_chat_screen.dart:502-562` + `services/coach/proactive_trigger_service.dart:75-98` + `services/coach/precomputed_insights_service.dart:275-292`
