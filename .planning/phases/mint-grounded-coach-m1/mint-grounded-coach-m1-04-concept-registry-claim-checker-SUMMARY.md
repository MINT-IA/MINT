---
phase: mint-grounded-coach-m1
plan: 04
subsystem: coach-compliance-guard
tags: [concept-registry, claim-checker, definitional-inversion, compliance-guard, grounding, closed-world, lsfin, tdd]

# Dependency graph
requires:
  - phase: mint-grounded-coach-m1-01-inversion-fixtures-red
    provides: "18 xfail-strict inversion fixtures + guard-neutral hygiene self-test — the RED→GREEN regression anchor this plan flips to GREEN"
  - phase: mint-grounded-coach-m1-02-compliance-blocking-gates
    provides: "ComplianceGuard L1/L2/L3 blocking gates + fallback_reasons attribution + 13-shape probe this plan extends"
provides:
  - "CONCEPT_REGISTRY — curated closed-world Swiss concept registry (18 P0 pages, frozen Mapping, single source of canonical FR definitions)"
  - "claim_checker.check_claims() — deterministic definitional-inversion detector over the registry (no LLM, substring/lexicon)"
  - "ComplianceGuard Layer 6 (semantic) — claim-checker wired as a BLOCKING layer after L2 (use_fallback + 'definition_inversion')"
  - "Plan 01 inversion fixtures flipped to hard GREEN (xfail-strict marker removed, today-tripwire deleted)"
  - "extended fallback_reasons probe (17 shapes) incl. the new definition_inversion reason — plan 07 checkpoint input"
affects: [mint-grounded-coach-m1-06-domain-corrections, mint-grounded-coach-m1-07]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Registry-as-frozen-Mapping (MappingProxyType + frozen dataclass + resolve()) — mirrored from citation_registry.py for the concept registry"
    - "Closed-world definitional-inversion detector: definiendum-lexicon gate + multi-word inversion-marker match (deterministic, CLAUDE.md §9 — no LLM judge)"
    - "Semantic blocking layer (Layer 6) composing after the Plan 02 L1/L2 lexical gates"

key-files:
  created:
    - services/backend/app/services/coach/concept_registry.py
    - services/backend/app/services/coach/claim_checker.py
    - services/backend/tests/test_concept_registry.py
    - services/backend/tests/test_claim_checker.py
  modified:
    - services/backend/app/services/coach/compliance_guard.py
    - services/backend/tests/test_coach_claim_inversions.py

key-decisions:
  - "Definiendum-gate + multi-word inversion marker is the detection rule (not bare single-word markers): bare 'retirer'/'sortir'/'retrait' false-positive on the EPL canonical ('retrait anticipé'); multi-word markers ('sortir ton capital', 'retirer ton capital') give 0 canonical FP / 0 missed inversions across all 18 fixtures"
  - "Registry concept_key set = exactly the 18 Plan 01 fixture keys (superset invariant satisfied; ≥15 met). Curated against Swiss 2026 law (LPP/LIFD/LAVS/AVS21)"
  - "definition_inversion lives in fallback_reasons (internal attribution, like Plan 02's prescriptive_blocked); the user-facing ComplianceResult.violations carries a neutral FR string naming the concept + the inverted marker"
  - "avs_age_femmes page text = '64 ans et demi en 2026' (the conceptual prose); the constants-store VALUE fix (registry.py 65.0→64.5) is Plan 06, not here"

patterns-established:
  - "Concept registry as curated wiki (project_user_profile_wiki), NOT vector-soup — per-page canonical_fr + source + known_inversions + not_this_fr + related links"
  - "Claim-checker = semantic analogue of the numeric hallucination detector — closed-world, deterministic, fails fast, no probabilistic verification of probabilistic output"

requirements-completed: [WS-B, WS-E]

# Metrics
duration: ~35min
completed: 2026-06-12
---

# Phase mint-grounded-coach-m1 Plan 04: Concept Registry + Claim-Checker Summary

**A curated closed-world Swiss concept registry (18 P0 pages, frozen Mapping) + a deterministic definitional-inversion claim-checker wired into ComplianceGuard as a BLOCKING semantic layer (Layer 6) — flipping the Plan 01 inversion fixtures from xfail-strict RED to hard GREEN (18 passed, 0 xfailed) and closing HOLE-1, with the full backend suite green (7784 passed).**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-06-12 (sequential session, main working tree)
- **Completed:** 2026-06-12
- **Tasks:** 4 (3 with commits; Task 4 verification-only)
- **Files modified:** 6 (2 production + 2 test created, 1 production + 1 test modified)

## Accomplishments

- **HOLE-1 closed (audit 04 §P0):** the device-proven « un rachat LPP, c'est sortir ton capital » inversion — which carries no number and no banned term, so it traversed every numeric/lexical gate intact — is now blocked by the claim-checker. The semantic Layer 6 is the analogue of the numeric hallucination detector: a closed-world detector over `CONCEPT_REGISTRY` that catches a definitional inversion the way Layer 3 catches a wrong number.
- **Curated concept registry (WS-B):** `CONCEPT_REGISTRY` is a frozen `Mapping[str, ConceptPage]` (MappingProxyType) of 18 P0 Swiss concepts — the single source of canonical FR definitions, mirroring `citation_registry.py`'s shape. Each page = canonical FR definition + legal source (LPP/LIFD/LAVS art.) + known inversions + inverted-meaning markers + related-concept links. Accent-clean, no banned LSFin term.
- **Deterministic claim-checker (WS-B/E):** `check_claims(text) -> list[ClaimViolation]` is closed-world over the registry, substring/lexicon only — no LLM call (CLAUDE.md §9). It runs over all fixtures in well under 2s.
- **RED→GREEN flip (CONTEXT decision 3):** the Plan 01 `test_inversions_are_blocked` strict-xfail flipped to a hard pass (18 passed, 0 xfailed); the `test_guard_passes_inversion_today` today-tripwire was deleted, exactly as the Plan 01 SUMMARY « Notes for Plan 04 » instructed.
- **No false positives:** every fixture canonical definition and a 6-case neutral-prose set (incl. the « excellent reply1 » conditional and negated-guarantee) pass the guard untouched.

## The RED→GREEN Closure (deterministic citation)

`test_inversions_are_blocked` — the Plan 01 contract test — is now a HARD pass with the xfail marker removed:

```
python3 -m pytest tests/test_coach_claim_inversions.py -q -k "test_inversions_are_blocked"
18 passed, 39 deselected, 1 warning in 0.11s
```

The device-proven rachat case explicitly:

```
tests/test_coach_claim_inversions.py::test_inversions_are_blocked[inv-01-rachat-lpp] PASSED
```

Verification of the flip (no live `@pytest.mark.xfail` decorator, no `test_guard_passes_inversion_today` function remain — only lineage comments):
- `grep -nE "@pytest.mark.xfail" tests/test_coach_claim_inversions.py` → NONE (decorator removed)
- `grep -nE "^def test_guard_passes_inversion_today|    def test_guard_passes_inversion_today"` → NONE (function deleted)

## Task Commits

Each task committed atomically:

1. **Task 1: Curated concept registry (closed-world)** — `247ec0557` (feat) — TDD: test (RED, collection error) → implementation (GREEN, 44 passed) committed as one task unit.
2. **Task 2: Deterministic claim-checker (definitional-inversion detector)** — `266fb5039` (feat) — TDD: test (RED) → implementation; includes the registry marker tweak that satisfies the plan's literal behaviour spec (« un rachat c'est retirer ton capital »).
3. **Task 3: Wire claim-checker into ComplianceGuard + flip Plan 01 xfail** — `fd5c7a359` (feat) — TDD: guard-integration tests (RED, 19 failing) → Layer 6 wiring (GREEN) + xfail flip in the same task unit.
4. **Task 4: Full backend suite — no regression** — verification-only, no file changes, no commit. Suite green, zero stale-test updates needed (see Deviations: none).

## Files Created/Modified

- `services/backend/app/services/coach/concept_registry.py` (created) — `ConceptPage` frozen dataclass + `CONCEPT_REGISTRY` (MappingProxyType, 18 pages) + `resolve()`. Curated against Swiss 2026 law.
- `services/backend/app/services/coach/claim_checker.py` (created) — `check_claims()` + `ClaimViolation`; definiendum-lexicon gate + multi-word inversion-marker match; NFKC-normalised, deterministic.
- `services/backend/app/services/coach/compliance_guard.py` (modified) — import `check_claims`; Layer 6 semantic blocking branch inserted after L2 (sets `use_fallback=True`, appends `definition_inversion` to `fallback_reasons`, emits neutral FR violations); class/module docstrings note the grounding contract.
- `services/backend/tests/test_concept_registry.py` (created) — 44 cases: ≥15 pages, superset of fixture keys, rachat_lpp canonical+inversions, frozen-mutation raises, banned-term scan clean.
- `services/backend/tests/test_claim_checker.py` (created) — fixture-driven: every inversion flagged, every canonical + 6 neutral-prose cases clean, <2s perf, plus ComplianceGuard L6 integration tests.
- `services/backend/tests/test_coach_claim_inversions.py` (modified) — removed the `xfail(strict=True)` marker (hard pass), deleted `test_guard_passes_inversion_today`, updated the module docstring to the GREEN/flip lineage.

## Decisions Made

- **Detection rule = definiendum-gate + multi-word inversion marker.** Empirical pre-implementation simulation (recorded below) showed bare single-word markers (`retirer`/`sortir`/`retrait`) false-positive on the EPL/epl_blocage canonical (« retrait anticipé », « tout retrait en capital »). Filtering to multi-word `not_this_fr` markers gated by the concept's definiendum lexicon yields **0 canonical false positives and 0 missed inversions** across all 18 fixtures, plus 0 FP on the neutral-prose set.
- **Registry = exactly the 18 fixture keys.** The superset invariant (registry ⊇ fixture concept_keys) and the ≥15 floor are both satisfied by curating the 18 concepts the fixtures reference. No speculative extra pages (Karpathy #2 simplicity-first; the « top ~50 » fattening is future work, not needed to close HOLE-1).
- **`definition_inversion` is an internal `fallback_reasons` label** (matching Plan 02's `prescriptive_blocked`/`hallucination_major`). `ComplianceResult` does not expose `fallback_reasons`, so the user-facing `violations` list carries a neutral FR string (« Définition à revoir: '<concept>' (formulation inversée: '<marker>') ») — public-repo neutral design language, no forensic phrasing.

## Deviations from Plan

None — plan executed exactly as written. Two in-flight, pre-commit refinements (not post-commit deviations) were applied during authoring:

1. **Task 2 — registry marker for the plan's literal behaviour spec.** The plan behaviour spec requires « un rachat c'est retirer ton capital » → violation, but the fixture-derived markers only had « sortir ton capital ». Added « retirer ton capital » as a multi-word marker on `rachat_lpp` (verified absent from every canonical → 0 FP) and dropped the bare single-word markers (`retirer`/`sortir`/`retrait`, `exonérée`) that the checker filters out anyway. Applied before the Task 2 commit.
2. **Task 3 — test assertion target.** The guard-integration test initially asserted `definition_inversion` on `result.violations`; that label lives in the (unexposed) `fallback_reasons`. Corrected the assertion to the actual user-facing surface (`violations` naming the concept + « invers… », plus `use_fallback` and empty `sanitized_text`) before the Task 3 commit. The guard behaviour was correct throughout — only the test expectation was adjusted.

**Total deviations:** 0 post-commit. **Task 4 required zero stale-test updates** — the new blocking layer tripped no existing test that fed an inverted/loose definition as acceptable coach output.

## Issues Encountered

None requiring problem-solving beyond the two in-flight refinements above. The TDD RED gates fired as expected at each task (collection error → registry; import error → checker; 19 failing guard-integration tests → wiring; 36 failing Plan 01 tests → the xfail XPASS + today-tripwire, which IS the flip signal).

## fallback_reasons Probe (plan-07 decision input)

Deterministic probe extending Plan 02's 13-shape set with 4 new definitional-inversion shapes (17 shapes total), same style so plan 07 can compare directly. The endpoint substitutes a templated safe reply whenever `use_fallback=True`.

**The 13 Plan 02 shapes reproduce Plan 02's exact distribution** (4 prescriptive_blocked + 1 hallucination_major = 5/13 fallback; the other 8 pass — incl. `clean_definition` = the canonical rachat, `negated_guarantee`, `banned_sanitisable`, `empty_profile_number`). The new Layer 6 adds **zero** fallback to any of those 13 clean/adversarial shapes.

`fallback_reasons` distribution over the 17-shape probe:

| fallback_reason        | count | samples that tripped it                                                            |
|------------------------|-------|------------------------------------------------------------------------------------|
| `prescriptive_blocked` | 4     | prescriptive_single, prescriptive_imperative, prescriptive_multi, social_comparison |
| `hallucination_major`  | 1     | halluc_major_populated (CHF 3'500 vs known 1'820)                                   |
| `definition_inversion` | 4     | inversion_rachat, inversion_pilier3a, inversion_avs_femmes, inversion_fatca         |
| `banned_residual`      | 0     | (sanitiser absorbs banned terms — defense-in-depth only, per Plan 02)              |

**Aggregate on this 17-shape probe: 9/17 = 52.9% fallback.** Pass (8/17): clean_conditional_reply1, clean_definition, clean_scenario, negated_guarantee, banned_sanitisable, banned_single_conseiller, halluc_clean_populated, empty_profile_number.

**Interpretation for plan 07:**
- The new `definition_inversion` reason adds **4 fallbacks on deliberately-inverted definitional shapes** while leaving **every clean/correct definitional shape untouched** — including `clean_definition`, the canonical rachat (« verser dans ta caisse »). The incremental fallback from this plan is bounded by how often the live coach actually emits an *inverted* definition, which the registry + grounding prompt are designed to drive toward zero.
- The 52.9% figure is a worst-case-skewed probe (heavy on adversarial shapes to characterise the gates). Plan 07's checkpoint should weight `definition_inversion` against W1-persona walkthrough output, not this adversarial probe — the same caveat Plan 02 applied to `prescriptive_blocked`.

## Threat Model Coverage

- **T-m1-04-01** (Information disclosure / mis-information — definitional blind spot HOLE-1, disposition `mitigate`): mitigated. Curated registry + deterministic claim-checker wired as a blocking ComplianceGuard layer. `test_claim_checker.py::TestGuard*` + the now-GREEN `test_coach_claim_inversions.py::test_inversions_are_blocked` enforce it.
- **T-m1-04-02** (Spoofing / invented source on a definition, disposition `mitigate`): mitigated at the definition layer. Every registry page resolves to a real legal source (LPP/LIFD/LAVS art.); the claim-checker blocks off-registry inversions. (The `show_fact_card.source` channel remains a separate P1 surface per audit 04 — out of this plan's scope, flagged below.)
- **T-m1-04-SC** (Tampering / pip installs, disposition `accept`): no new packages — stdlib `re`/`unicodedata`/`dataclasses` + existing `pytest` only. No package-legitimacy gate needed.

## Known Stubs

None. The registry is fully populated (18 pages, no placeholder/empty values), the claim-checker is fully wired to the registry and into ComplianceGuard, and the Plan 01 fixtures are hard-GREEN (not a stub — the flip is the intended terminal state).

## Threat Flags

| Flag | File | Description |
|------|------|-------------|
| threat_flag: trust-boundary-note | services/backend/app/services/coach/compliance_guard.py | The claim-checker closes the definitional trust boundary at the ComplianceGuard layer. The `show_fact_card.content`/`source` LLM-generated channel (audit 04 §P1) is a SEPARATE surface NOT gated by this plan — a future plan should route fact-card content/source through CONCEPT_REGISTRY. No new network endpoint, auth path, or schema change introduced here. |

## Next Phase Readiness

- **Plan 06 (domain corrections)** can proceed: the `avs_age_femmes` page text already states « 64 ans et demi en 2026 »; Plan 06 owns the constants-store VALUE fix (registry.py 65.0→64.5) and the EPL/79b prose alignment — the registry is ready to receive value-level corrections.
- **Plan 07 (checkpoint)** has the extended `fallback_reasons` probe above (incl. the new `definition_inversion` reason) as decision input.
- **No blockers.** STATE.md / ROADMAP.md intentionally NOT modified (orchestrator owns those writes).

## Self-Check: PASSED

- FOUND: services/backend/app/services/coach/concept_registry.py
- FOUND: services/backend/app/services/coach/claim_checker.py
- FOUND: services/backend/tests/test_concept_registry.py
- FOUND: services/backend/tests/test_claim_checker.py
- FOUND: services/backend/app/services/coach/compliance_guard.py (modified — Layer 6 wired, check_claims at line 505)
- FOUND: services/backend/tests/test_coach_claim_inversions.py (modified — xfail removed, today-tripwire deleted)
- FOUND commit: 247ec0557 (Task 1 — concept registry)
- FOUND commit: 266fb5039 (Task 2 — claim-checker)
- FOUND commit: fd5c7a359 (Task 3 — wiring + xfail flip)
- VERIFIED: test_inversions_are_blocked → 18 passed, 0 xfailed (RED→GREEN closure)
- VERIFIED: full backend suite → 7784 passed, 116 skipped, 4 xfailed, 0 failed

---
*Phase: mint-grounded-coach-m1*
*Completed: 2026-06-12*
