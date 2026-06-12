---
phase: mint-grounded-coach-m1
plan: 06
subsystem: coach
tags: [save_fact, split-brain, coach_profile, regulatory-registry, avs, fact_saved, flutter, fastapi]

# Dependency graph
requires:
  - phase: mint-grounded-coach-m1-05-explain-concept-forced-tool
    provides: explain_concept backend-handled tool + INTERNAL_TOOL_NAMES discipline (the filter that hides save_fact from flutter_tool_calls)
provides:
  - "save_fact value echoed to mobile via an additive forward-safe fact_saved tool_call ({key, value}), gated by the persist whitelist"
  - "mobile apply path: CoachProfileProvider.applyFactSavedEcho routes the echo through the existing write path (no parallel mapping, no new store, no build-method write)"
  - "AVS women reference age corrected to 64.5 for the 2026 AVS 21 transition (registry + regenerated Dart snapshot + consumer tests)"
affects: [mint-event-log-cutover-m2, coach-profile-hydration, regulatory-constants]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Additive forward-safe echo: an internal tool stays internal; a separate confirmation entry carries the value to the client (no un-internalising)"
    - "Echo mirrors persistence: only persisted (whitelisted + coercible + consented) values cross to the client"
    - "Reuse the canonical key correspondence (provider _mapFactKeyToAnswers) instead of inventing a parallel mapping in the apply layer"

key-files:
  created:
    - services/backend/tests/test_registry_avs_age.py
    - services/backend/tests/test_coach_chat_savefact_return.py
    - apps/mobile/test/services/coach/savefact_echo_test.dart
  modified:
    - services/backend/app/services/regulatory/registry.py
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - apps/mobile/lib/providers/coach_profile_provider.dart
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart
    - apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart
    - services/backend/tests/test_regulatory_registry.py
    - services/backend/tests/test_constants.py

key-decisions:
  - "Apply the echo in the chat tool_calls processing layer (coach_chat_screen, same layer as onInputSubmitted), never inside widget_renderer's build switch"
  - "Gate the echo on actual persistence: emit only when the save_fact result starts with 'Fait ' (DB or hors-DB success) AND the key is whitelisted AND the value coerces"
  - "AVS women 64.5 in the registry; int() derivation yields FEMME=64 — already anticipated by minimal_profile_service ('64 AVS21 transitional')"

patterns-established:
  - "fact_saved echo entry — a confirmation tool_call name that renders nothing on mobile (widget_renderer default → null) and carries {key, value} for the local store"

requirements-completed: [WS-D]

# Metrics
duration: ~50min
completed: 2026-06-12
---

# Phase mint-grounded-coach-m1 Plan 06: save_fact return + domain fixes Summary

**The chat-stated fact now reaches the profile the screens read — backend echoes a forward-safe `fact_saved` {key,value} on the HTTP response, mobile applies it through the existing CoachProfileProvider write path; plus AVS women reference age corrected to 64.5 for the 2026 transition.**

## Performance

- **Duration:** ~50 min
- **Started:** 2026-06-12T14:13:32+02:00 (first task commit)
- **Completed:** 2026-06-12T12:22:58Z
- **Tasks:** 4 (3 code + 1 verification)
- **Files modified:** 12 (7 modified, 3 created tests, +2 consumer tests updated)

## Accomplishments
- Closed the minimal chat→profile split-brain (CONTEXT WS-D, audit 04 §1.3 P0-bis, W1 WTF-W1-04): a fact said in chat (« j'ai 50 ans ») now lands in the local `CoachProfile` the simulators read — proven end-to-end (`profile.age == 50` from a `birthYear` echo).
- Backend emits an additive `fact_saved` echo only when `save_fact` actually persisted, gated by the persist whitelist (`_SAVE_FACT_ALLOWED_KEYS`) + `_coerce_fact_value`; non-whitelisted/uncoercible/non-consented facts are NOT echoed (privacy T-m1-06-01). `save_fact` stays internal — persistence unchanged.
- Mobile apply leg routes the echo through `CoachProfileProvider.applyFactSavedEcho` → existing `applySaveFact` → `_mapFactKeyToAnswers` → `mergeAnswers` (canonical key correspondence reused; no parallel mapping, no new store, no write inside any widget build method).
- AVS women reference age 65.0 → 64.5 (2026 AVS 21 transition, cohorte 1962); registry description updated, Dart snapshot regenerated, consumer tests realigned off the old 65-endpoint premise.
- Full backend suite (7853 passed / 116 skipped / 4 xfailed) + `flutter analyze` (No issues found) green.

## Task Commits

Each task was committed atomically (TDD: test + impl folded per commit):

1. **Task 1: AVS women reference-age domain fix (2026)** — `fe0dd8a12` (fix)
2. **Task 2: Echo save_fact value back to mobile (backend)** — `402b1f200` (feat)
3. **Task 3: Apply the echo via the CoachProfileProvider write path (mobile)** — `ebae9b1fe` (feat)
4. **Task 4: Suites + analyze + ARB parity** — verification-only, no code change (no commit)

_TDD note: each TDD task wrote the failing test then the implementation; both were committed together in the task commit (RED proven inline before GREEN)._

## Files Created/Modified
- `services/backend/app/services/regulatory/registry.py` — `avs.reference_age_women` 65.0 → 64.5, description notes the 2026 transition (64→65 for 1961-1963, 65 in 2028); source fields preserved.
- `services/backend/app/api/v1/endpoints/coach_chat.py` — new `_build_fact_saved_echo(call)` (whitelist + coercion gate); agent loop appends the echo to `flutter_tool_calls` on a persisted `save_fact`.
- `apps/mobile/lib/providers/coach_profile_provider.dart` — new `applyFactSavedEcho(input)` dispatching to the existing `applySaveFact` write path.
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` — tool_calls processing layer handles `fact_saved` (ServerKey path) alongside raw `save_fact` (BYOK path).
- `apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart` — regenerated Dart snapshot carrying 64.5 (D-16 codegen hook).
- `services/backend/tests/test_registry_avs_age.py` — new: pins 64.5/2026, men=65, transition inequality, description.
- `services/backend/tests/test_coach_chat_savefact_return.py` — new: echo builder unit + agent-loop integration (whitelisted echoed, non-whitelisted dropped, consent-gated, raw save_fact never forwarded).
- `apps/mobile/test/services/coach/savefact_echo_test.dart` — new: age echo → profile.age 50, canton echo, unknown/missing/null no-ops, low-confidence skip.
- `services/backend/tests/test_regulatory_registry.py`, `services/backend/tests/test_constants.py` — consumer tests realigned to the 2026 transition values.

## Decisions Made
- **Echo placement** in the agent loop's internal-tool dispatch (right after `_execute_internal_tool`), gated on `result_text.startswith("Fait ")` — the precise persist-success signal common to the DB (`Fait enregistré : …`) and hors-DB (`Fait noté (hors DB) : …`) paths, excluding failures (`[save_fact ÉCHEC …]`) and low-confidence skips.
- **Echo value is the canonical coerced form** (re-runs `_coerce_fact_value`), so the mobile applies the same value the backend persisted, and out-of-bounds values (e.g. `birthYear=2099`) are dropped from the echo exactly as they are from persistence.
- **AVS int() derivation** left unchanged (`int(64.5)=64`) — `minimal_profile_service.py:163` already comments “64 (AVS21 transitional)”, so the consumer was pre-written for this; only the three tests that encoded the wrong 65 premise were updated (surgical, Karpathy #3).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Regenerated the Dart regulatory constants snapshot**
- **Found during:** Task 1 (AVS age fix commit)
- **Issue:** The `regulatory-codegen-check` pre-commit hook (D-16) blocked the commit because the registry value change drifted `regulatory_constants.g.dart` from the in-process registry.
- **Fix:** Ran `python3 tools/codegen/regulatory_constants_to_dart.py --source local --write` (the sanctioned remediation the hook itself prints). The Dart snapshot now carries 64.5; `--check` passes. The codegen also bumped `effective_on` 2026-05-18 → 2026-06-12 (inherent to running the regen today via `date.today()`) and recomputed the version/integrity hashes — expected, not a hand-edit.
- **Files modified:** apps/mobile/lib/services/financial_core/generated/regulatory_constants.g.dart
- **Verification:** `--check OK` (matches registry version_hash); no Dart mirror test asserts the women age (the 4 Dart tests matching `64.5`/`reference` are unrelated tax/budget amounts).
- **Committed in:** fe0dd8a12 (Task 1 commit)

**2. [Rule 1 - Bug] Updated three consumer tests encoding the pre-2026 premise**
- **Found during:** Task 1 (AVS age fix)
- **Issue:** `test_regulatory_registry.py::TestAvsReferenceAges::{test_women_reference_age_65, test_gender_equality_post_reform}` and `test_constants.py::TestAVSConsistency::test_ages_reference_equal` asserted women=65 / H==F==65 — a premise the registry fix invalidates for 2026.
- **Fix:** Realigned the assertions to the 2026 transition (women 64.5 in registry → FEMME=64 constant; H/F differ during transition); the equality at 65 is only reached in 2028.
- **Files modified:** services/backend/tests/test_regulatory_registry.py, services/backend/tests/test_constants.py
- **Verification:** Both files green (135 passed in the combined run).
- **Committed in:** fe0dd8a12 (Task 1 commit)

**3. [Rule 1 - Bug] Test harness consent flag for the echo integration tests**
- **Found during:** Task 2 (backend echo)
- **Issue:** `save_fact` is a WRITE-tier tool gated by `persistence_consent`; the first draft of the integration tests didn't pass it, so the handler returned `_PERSISTENCE_OFF_MARKER` (no persist → no echo) and the tests failed.
- **Fix:** Pass `persistence_consent=True` in the base kwargs (the echo correctly mirrors persistence) and added an explicit `test_no_persistence_consent_no_echo` proving the gate.
- **Files modified:** services/backend/tests/test_coach_chat_savefact_return.py
- **Verification:** 8 passed.
- **Committed in:** 402b1f200 (Task 2 commit)

---

**Total deviations:** 3 auto-fixed (1 blocking codegen, 2 bug/test-realignment)
**Impact on plan:** All three were necessary to keep the change consistent (codegen parity) and to make the new tests assert the correct post-2026 reality. No scope creep — no event-log cutover, no dual-write flag, no new write endpoint (M2 scope preserved).

## Issues Encountered
- The Dart codegen snapshot diff is large (~127KB) because the embedded JSON is a single minified line; the only semantic value change is `avs.reference_age_women` → 64.5 (plus the expected `effective_on`/hash metadata bump). Confirmed via `--check OK`.
- The mobile persistence test initially read the raw prefs key (`__secure__` sentinel) — `q_birth_year` is a sensitive key sealed into secure storage; switched the assertion to the restore path (`ReportPersistenceService.loadAnswers()`) and the profile accessors.

## Known Stubs
None — the echo flows end-to-end (backend append → mobile apply → profile write → screens read), proven by `profile.age == 50` and `profile.canton == 'VD'` tests. No hardcoded/empty/placeholder values introduced.

## Threat Flags
None — the only new surface (save_fact echo → mobile local store) is the boundary already enumerated in the plan's `<threat_model>` (T-m1-06-01), and is mitigated as planned (whitelist + coercion + persistence-consent gate).

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- WS-D minimal split-brain bridge is in place; the M2 event-log cutover (canonical write endpoint, confirmation-UX card audit 04 §3.d, dated event-log) remains the planned successor and is explicitly NOT done here.
- AVS women reference age is correct for 2026; revisit in 2028 when the transition reaches 65 (the description documents the schedule).
- Note: end-to-end was proven by unit/integration tests + analyze; a device/sim walkthrough of the chat→profile flow on staging was NOT run in this plan (0-TRUST: « tests green, on-device end-to-end UNKNOWN »).

## Self-Check: PASSED

- Created files verified on disk: `test_registry_avs_age.py`, `test_coach_chat_savefact_return.py`, `savefact_echo_test.dart`, this SUMMARY.
- Task commits verified in git log: `fe0dd8a12`, `402b1f200`, `ebae9b1fe`.

---
*Phase: mint-grounded-coach-m1*
*Completed: 2026-06-12*
