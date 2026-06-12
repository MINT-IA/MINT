---
phase: mint-grounded-coach-m1
plan: 02
subsystem: coach-compliance-guard
tags: [compliance-guard, lsfin, fallback, prescriptive, banned-terms, hallucination, education-strict, tdd]

# Dependency graph
requires:
  - phase: mint-grounded-coach-m1-01-inversion-fixtures-red
    provides: "18 xfail-strict inversion fixtures + guard-neutral hygiene self-test (must NOT flip to XPASS under L1/L2 hardening)"
provides:
  - "ComplianceGuard L2 prescriptive layer is BLOCKING (use_fallback=True + fallback_reasons 'prescriptive_blocked') — no longer log-only"
  - "ComplianceGuard L1 banned layer blocks any term that SURVIVES sanitisation (residual re-scan); >5 count tolerance removed"
  - "ComplianceGuard L3 hallucination detection runs for empty/anonymous profiles (escape hatch at line 494 removed)"
  - "test_compliance_guard_blocking.py — regression tests for the three hardened gates"
  - "fallback_reasons attribution data for plan 07's checkpoint decision"
affects: [mint-grounded-coach-m1-04-claim-checker, mint-grounded-coach-m1-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Garde bloquante (education-strict perimeter): code matches the perimeter, not just the prompt (CONTEXT decision 1)"
    - "Sanitise-then-re-scan residual gate for banned terms (defense-in-depth over count tolerance)"
    - "Structured fallback_reasons attribution per blocking layer (plan-07 telemetry input)"

key-files:
  created:
    - services/backend/tests/test_compliance_guard_blocking.py
  modified:
    - services/backend/app/services/coach/compliance_guard.py
    - services/backend/tests/test_compliance_guard.py

key-decisions:
  - "L1 banned gate = residual-after-sanitisation block (sanitiser is comprehensive → no residual on current inputs; gate is defense-in-depth for future bypass), replacing the >5 count branch — honours must_have 'single banned term that survives sanitisation blocks'"
  - "L2 prescriptive gate = block on ANY prescriptive hit (use_fallback=True), the real behavioural change"
  - "L3 escape hatch = 'if context is not None' (detector no-ops on empty dict per hallucination_detector.py:183), so empty/anonymous profiles reach the detector"

patterns-established:
  - "Education-strict garde bloquante with neutral design language (no forensic/legal phrasing — public-repo discipline)"
  - "fallback_reasons label per gate: 'prescriptive_blocked', 'banned_residual', 'hallucination_major', 'hallucination_cumulative'"

requirements-completed: [WS-A]

# Metrics
duration: ~20min
completed: 2026-06-12
---

# Phase mint-grounded-coach-m1 Plan 02: Compliance Blocking Gates Summary

**ComplianceGuard hardened to the education-strict perimeter: prescriptive language now blocks (was log-only), residual banned terms block (the >5 count tolerance is gone), and numeric hallucination detection runs for empty/anonymous profiles (the `known_values` escape hatch is removed) — while clean conditional French and in-doctrine negated-guarantee phrasing still pass, full backend suite green (7654 passed).**

## Performance

- **Duration:** ~20 min
- **Started:** 2026-06-12 (sequential session)
- **Completed:** 2026-06-12
- **Tasks:** 3
- **Files modified:** 2 (1 production, 1 test) + 1 test created

## Accomplishments

- **L2 prescriptive → BLOCKING (audit 01 HOLE-4):** a single prescriptive financial instruction ("tu devrais racheter ta LPP maintenant", "fais un rachat") now sets `use_fallback=True` and appends `prescriptive_blocked` to `fallback_reasons`, returning empty text so the endpoint substitutes a templated safe reply. The prior log-only posture delegated the perimeter entirely to the prompt.
- **L1 banned → residual block (audit 01 HOLE-4):** the `>5` distinct-term count tolerance (compliance_guard.py:442) is removed. The guard now sanitises, then re-scans; any banned term that *survives* sanitisation triggers fallback (`banned_residual`). The negated-guarantee whitelist is re-applied to the post-sanitisation scan so in-doctrine phrasing does not trip.
- **L3 escape hatch removed (audit 01 HOLE-3):** `if context and context.known_values:` (compliance_guard.py:494) → `if context is not None:`. Empty/onboarding/anonymous profiles — the highest trust-formation stakes — now reach the numeric detector instead of being silently skipped. The detector no-ops gracefully on an empty dict (`hallucination_detector.py:183`), so thresholds and the cumulative limit are unchanged.
- **No false-positive regression:** clean conditional French ("tu pourrais envisager un rachat ; l'effet dépend de ta tranche") and negated-guarantee phrasing ("rien n'est garanti") still pass — the W1 "excellent reply1" standard survives.
- **Plan-01 fixtures untouched:** all 18 inversion fixtures remain xfailed (no XPASS) — the L1/L2 hardening did not flip any fixture, confirming the plan-01 hygiene self-test held.

## Task Commits

Each task committed atomically:

1. **Task 1: Make prescriptive + banned layers blocking (education-strict)** — `be0fb88b1` (feat) — TDD: test (RED, 4 failing) + implementation (GREEN) committed together as one task unit
2. **Task 2: Remove the empty-profile hallucination escape hatch** — `a7dbc0e36` (feat)
3. **Task 3: Full backend suite — update stale tests** — `3bc742dec` (test)

_TDD note: Task 1's 4 RED failures (3 prescriptive + 1 residual-banned) flipped to GREEN after the L1/L2 edits; Task 2's 4 hallucination tests passed in RED already (the escape-hatch change is behaviour-preserving for those cases) and remained green after the code change._

## Files Created/Modified

- `services/backend/app/services/coach/compliance_guard.py` — L1 banned residual block (removed `>5` branch), L2 prescriptive blocking branch, L3 escape-hatch removal, education-strict docstring note.
- `services/backend/tests/test_compliance_guard_blocking.py` (created, 181 lines) — regression tests for the three hardened gates: prescriptive→fallback, residual banned→fallback (monkeypatched no-op sanitiser to simulate a surviving residual), clean conditional→pass, negated-guarantee→pass, None-context no-crash, empty-known_values path reached, populated-profile major hallucination still blocks.
- `services/backend/tests/test_compliance_guard.py` — surgically updated the 4 stale tests (see Deviations).

## Decisions Made

- **L1 residual interpretation.** Empirical probe (recorded below) showed `_sanitize_banned_terms` is comprehensive: after sanitisation, **no residual banned term remains** for any current test input (single conseiller, 3-banned, 6+-banned all sanitise clean). So the residual-block gate is defense-in-depth — it fires only when a banned term survives sanitisation (a future bypass), satisfying the must_have "a single banned term that survives sanitisation triggers blocking, not the >5 tolerance" without killing legitimate sanitisable French. The behavioural teeth of WS-A are in the **L2 prescriptive** gate.
- **L2 covers the social-comparison patterns.** "top 10%", "meilleur que X%", "devant X%" live in `PRESCRIPTIVE_PATTERNS`, so they now block via L2. The existing `TestSocialComparisonPatterns` tests only asserted `is_compliant=False`/violations (never `not use_fallback`), so they survived unchanged — but their runtime disposition tightened from log-only to blocking, which is the intended education-strict effect.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug / Task 3] Updated 4 stale tests that encoded the removed log-only / count-tolerance behaviour**
- **Found during:** Task 3 (full backend suite)
- **Issue:** Four tests in `test_compliance_guard.py` asserted the now-wrong "ships to user" behaviour:
  - `test_fallback_on_egregious_banned_terms` (was line 116) — asserted `use_fallback` on 6+ banned terms (the removed `>5` count branch). Those 7 terms sanitise clean → no residual → preserved.
  - `test_single_match_detected_but_no_fallback` (was line 166) — asserted `not use_fallback` on one prescriptive hit.
  - `test_two_matches_no_fallback` (was line 171) — asserted `not use_fallback` on two prescriptive hits.
  - `test_three_plus_matches_logged_not_fallback` (was line 176) — asserted `not use_fallback` ("Prescriptive language never triggers fallback").
- **Fix:** Renamed `test_fallback_on_egregious_banned_terms` → `test_egregious_banned_terms_sanitised_no_residual` (asserts no residual after sanitisation, response preserved). Flipped the three prescriptive tests' `assert not result.use_fallback` → `assert result.use_fallback` and renamed them (`_blocks`). Updated the `TestPrescriptiveLanguage` class docstring to document the garde-bloquante doctrine. No other test touched (Karpathy #3 surgical).
- **Files modified:** `services/backend/tests/test_compliance_guard.py`
- **Verification:** `python3 -m pytest tests/test_compliance_guard.py -q` → 56 passed; full suite green.
- **Committed in:** `3bc742dec` (Task 3 commit)

---

**Total deviations:** 1 auto-fixed (1 Rule 1 — stale-test correction, the planned Task 3 work).
**Impact on plan:** The stale-test update was explicitly anticipated by the plan ("Update ONLY tests that encoded the now-wrong 'ships to user' behaviour"). No scope creep — production logic changes are confined to the three planned gate edits.

## fallback_reasons Observations (plan-07 decision input)

Deterministic probe of the hardened guard across **13 representative coach-output shapes** (clean conditional / definition / scenario, negated-guarantee, prescriptive single/imperative/multi, banned sanitisable, banned single, hallucination major/clean on a populated profile, empty-profile number, social comparison). The endpoint substitutes a templated safe reply whenever `use_fallback=True`.

**Aggregate fallback rate on this representative set: 5/13 = 38.5%.**

`fallback_reasons` distribution (by dominant gate):

| fallback_reason     | count | samples that tripped it                                          |
|---------------------|-------|------------------------------------------------------------------|
| `prescriptive_blocked` | 4  | prescriptive_single ("tu devrais racheter…" — caught via `achete` in "racheter"), prescriptive_imperative ("fais un rachat"), prescriptive_multi (4 instructions), social_comparison ("top 10%") |
| `hallucination_major`  | 1  | halluc_major_populated (CHF 3'500 vs known 1'820 → 92.3% dev)   |
| `banned_residual`      | 0  | (no residual survives sanitisation on these inputs — gate is defense-in-depth) |

**Samples that correctly PASS (8/13):** clean_conditional_reply1, clean_definition, clean_scenario, negated_guarantee, banned_sanitisable (3 banned terms → sanitised, no residual), banned_single_conseiller (→ "spécialiste"), halluc_clean_populated, empty_profile_number (empty-profile path reached, no regulatory anchor → no flag).

**Interpretation for plan 07:**
- The dominant new fallback driver is **`prescriptive_blocked`** (4/5 of the new fallbacks). The fallback-rate impact is concentrated on genuinely prescriptive / social-comparison output — exactly the education-strict perimeter target. Clean, hedged, conditional, definitional, and scenario replies are **unaffected**.
- `banned_residual` did **not** fire on any representative input — the sanitiser absorbs banned terms, so the L1 hardening adds **zero** fallback-rate cost in practice (it only guards a future bypass).
- The 38.5% figure is a *worst-case-skewed* probe set (deliberately heavy on adversarial/prescriptive shapes to characterise the gates). The real production fallback rate depends on how often the LLM emits prescriptive language — which the system prompt already discourages — so the *incremental* fallback from this plan is bounded by the prescriptive-emission rate of the live coach. Plan 07's checkpoint should weight the `prescriptive_blocked` rate against W1-persona walkthrough output rather than this adversarial probe.

_Note: `_check_prescriptive` returns raw pattern hits (e.g. "Achète" and "Achète un" both match the multi sample), so a single prescriptive instruction can yield multiple violation entries; the fallback decision is binary (any hit → block)._

## Deterministic Green Citation

Task 3 verify (`cd services/backend && python3 -m pytest tests/ -q`):

```
7654 passed, 116 skipped, 22 xfailed, 6 warnings in 92.07s (0:01:32)
```

- **22 xfailed** = 18 plan-01 inversion fixtures (still xfailed, **no XPASS** — the L1/L2 hardening did not flip any fixture) + 4 pre-existing.
- Suite grew from plan-01's 7643 by the 11 new `test_compliance_guard_blocking.py` cases (7643 + 11 = 7654), 0 failed.

Blocking-tests citation (`pytest tests/test_compliance_guard_blocking.py -q`): `11 passed`.
Compliance-file citation (`pytest tests/test_compliance_guard.py -q`): `56 passed`.

## Verification Criteria (plan)

- `grep -n "use_fallback = True"` → line 458 (L1 banned-residual) and line 481 (L2 prescriptive) — new blocking assignments present.
- `grep -n "if context is not None"` → line 526 — escape hatch confirmed gone (the only remaining `if context and context.known_values` match is the explanatory comment at line 519).

## Threat Model Coverage

- **T-m1-02-01** (Elevation — L2 prescriptive log-only, disposition `mitigate`): mitigated. L2 flipped to blocking fallback; `test_compliance_guard_blocking.py::TestPrescriptiveBlocking` + updated `TestPrescriptiveLanguage` enforce it.
- **T-m1-02-02** (Information disclosure — L3 empty-profile skip, disposition `mitigate`): mitigated. Escape hatch removed; anonymous/onboarding users now reach the numeric detector.
- **T-m1-02-SC** (Tampering — pip installs, disposition `accept`): no new packages — stdlib `re`/`unicodedata` + existing `pytest` only. No package-legitimacy gate needed.

## Known Stubs

None. The L1 residual gate is intentionally defense-in-depth (fires on a surviving residual, which the comprehensive sanitiser currently prevents) — documented above, not a stub. No placeholder/empty values, no TODO/FIXME introduced.

## Threat Flags

None — no new network endpoint, auth path, file-access pattern, or schema change introduced. Changes are confined to in-process compliance-guard logic on an existing trust boundary already covered by the plan's threat model.

## Next Phase Readiness

- **Plan 04 (claim-checker wiring)** can proceed: the L1/L2 hardening did not flip the plan-01 inversion fixtures, so plan 04 still owns the RED→GREEN flip (delete the xfail marker + the `test_guard_passes_inversion_today` tripwire) when the semantic claim-checker lands as a new blocking layer.
- **Plan 07 (checkpoint)** has the `fallback_reasons` / fallback-rate data above as decision input.
- **No blockers.** STATE.md / ROADMAP.md intentionally NOT modified (orchestrator owns those writes).

## Self-Check: PASSED

- FOUND: services/backend/app/services/coach/compliance_guard.py (modified)
- FOUND: services/backend/tests/test_compliance_guard_blocking.py (created)
- FOUND: services/backend/tests/test_compliance_guard.py (modified)
- FOUND commit: be0fb88b1 (Task 1 — blocking L1/L2 + tests)
- FOUND commit: a7dbc0e36 (Task 2 — escape-hatch removal)
- FOUND commit: 3bc742dec (Task 3 — stale-test updates)

---
*Phase: mint-grounded-coach-m1*
*Completed: 2026-06-12*
