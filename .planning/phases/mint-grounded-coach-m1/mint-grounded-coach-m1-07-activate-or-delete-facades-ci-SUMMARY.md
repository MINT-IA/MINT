---
phase: mint-grounded-coach-m1
plan: 07
subsystem: coach-grounding
tags: [feature-flags, citation-gate, dual-llm, bundle-compiler, coach-reasoner, facade, ci, eval-harness, dead-code-removal]

# Dependency graph
requires:
  - phase: mint-grounded-coach-m1-02-compliance-blocking-gates
    provides: "fallback_reasons attribution (38.5% adversarial probe, prescriptive_blocked dominant) — citation-gate activation decision input"
  - phase: mint-grounded-coach-m1-04-concept-registry-claim-checker
    provides: "claim-checker + concept registry live as ComplianceGuard Layer 6; zero incremental fallback on clean shapes; the inversion fixtures wired into CI here"
  - phase: mint-grounded-coach-m1-05-explain-concept-forced-tool
    provides: "education-strict forced-tool surface hardened — the live single-LLM narrator path the citation gate now guards"
  - phase: mint-grounded-coach-m1-06-savefact-return-domain-fixes
    provides: "domain corrections landed before the façade resolution"
provides:
  - "COACH_CITATION_GATE_ENABLED ACTIVATED (default True) — closed-world citation gate is the live narrator-stage guard; citation grammar wired into the single-LLM build_system_prompt path"
  - "COACH_DUAL_LLM_ENABLED + COACH_BUNDLE_COMPILER_ENABLED + COACH_NARRATOR_MODEL DELETED from Settings + all production consumer branches collapsed to the legacy single-LLM live path"
  - "CoachReasonerService façade removed (zero production callers, audit 01 HOLE-5) + barrel export + orphan tests"
  - ".github/workflows/coach-eval.yml — CI regression gate running the inversion + claim-checker + concept-registry + façade-resolution suites, fail-fast on any inversion regression"
  - "test_facade_resolution.py — asserts the post-state (no dark flag / no façade remains; gate default-ON with reachable consumer)"
affects: [mint-grounded-coach-m1-08-persona-walkthrough]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Activate-or-delete resolution (NEVER #6): a flag-gated dark path is either flipped-ON-and-wired or its flag + Settings field + consumer branches + dark-only tests are deleted — never left as a flag-OFF façade"
    - "Citation grammar carried forward to the activated live path (Rule 2 critical wiring): activating a closed-world gate REQUIRES instructing the narrator to emit {{cite:...}} placeholders, else the gate REJECTs every uncited number"
    - "CI path-filter blind-spot mitigation: the eval gate fires on generic backend AND on narrow coach-prompt/registry/config edits AND on the fixtures themselves"

key-files:
  created:
    - services/backend/tests/test_facade_resolution.py
    - .github/workflows/coach-eval.yml
  modified:
    - services/backend/app/core/config.py
    - services/backend/app/api/v1/endpoints/coach_chat.py
    - services/backend/app/services/coach/claude_coach_service.py
    - apps/mobile/lib/services/financial_core/financial_core.dart
    - docs/calculator-graph.md

key-decisions:
  - "Citation gate ACTIVATE (default True): weighed Plan 02 (38.5% adversarial-skewed probe, prescriptive_blocked = 4/5 of fallbacks) + Plan 04 (definition_inversion adds 0 fallback on clean definitional shapes) + racheter word-boundary FP fix (6f60acab3) — the numeric citation gate is the smaller remaining surface complementing the live claim-checker + education-strict gates"
  - "Citation grammar wired into the legacy build_system_prompt path (NOT only the deleted dual-LLM narrator builder): the gate would FALLBACK on every numeric reply without it (architectural coupling discovered during execution)"
  - "Dual-LLM + bundle-compiler DELETE (flags + Settings fields + consumer branches + orphan helpers + dark-only tests), leaving the legacy single-LLM live path hardened by Plans 02/04/05"
  - "coach_reasoner DELETE (zero production callers; Plan 03 reframe consciously discarded — git history preserves it for M3)"
  - "Library builders build_narrator_system_prompt / _from_bundles + bundle_compiler.py RETAINED (test-covered, no longer flag-gated façades) — deleting them would break ~10 non-dark tests, exceeding the surgical scope"

patterns-established:
  - "Façade post-state test (test_facade_resolution.py): assert removed flags are absent from Settings.model_fields AND the activated flag's consumer is reachable on the live path (source-grep + in-process prompt assembly)"
  - "Gate-OFF rollback fixtures in tests that pinned pre-activation behavior: monkeypatch.setattr(settings, 'COACH_CITATION_GATE_ENABLED', False) isolates passthrough/wiring/composition contracts from the now-active gating"

requirements-completed: [WS-C, WS-E]

# Metrics
duration: ~75min
completed: 2026-06-12
---

# Phase mint-grounded-coach-m1 Plan 07: Activate-or-Delete Façades + CI Eval Gate Summary

**The three dark coach gates and the unwired coach_reasoner reached a binding wired-or-deleted resolution (no flag-OFF façade remains, NEVER #6): the closed-world citation gate was ACTIVATED by default with its citation grammar wired into the live single-LLM narrator path, while the dual-LLM split, the bundle compiler, their flags/fields/consumers/dark-only tests, and the zero-caller CoachReasonerService were DELETED — and the inversion + claim-checker + concept-registry fixtures are now a fail-fast CI regression gate. Full backend suite green (7792 passed), flutter analyze clean, 548 financial_core tests green.**

## Performance

- **Duration:** ~75 min
- **Started:** 2026-06-12 (sequential session, main working tree)
- **Completed:** 2026-06-12
- **Tasks:** 3 (the checkpoint:decision was pre-taken by the orchestrator under founder-delegated authority)
- **File churn:** 21 files, +498 / -3326 lines (net -2828; ~1500-line dark-guard removal per audit 01 C-5, plus dark-only test deletion)

## Accomplishments

- **Citation gate ACTIVATED (WS-C, audit C-5 / Phase 94 dark gate):** `COACH_CITATION_GATE_ENABLED` flipped from `False` to `True` by default. The gate's wrapper (`_run_narrator_with_gate`) was already live; the decisive missing piece — discovered during execution — was that the citation grammar (the instruction teaching the narrator the `{{cite:<key>}}` syntax) was only ever appended inside the **dual-LLM** narrator builder (`build_narrator_system_prompt`), never the legacy `build_system_prompt` on the single-LLM live path. Activating the gate without it would have REJECTED every uncited number → FALLBACK on virtually all numeric replies. I wired the grammar (intent-scoped when intents present, full 18-key fragment otherwise) into the live `_build_system_prompt_with_memory` path (Rule 2 critical functionality).
- **Dual-LLM split DELETED (WS-C):** removed `COACH_DUAL_LLM_ENABLED` + `COACH_NARRATOR_MODEL` from `Settings`, collapsed the extractor stage to a no-op shim (the regex extractor STAGE 1 remains the deterministic floor), collapsed the narrator-tools/model branches to the legacy `get_llm_tools()` + `effective_model`, and deleted the orphaned helpers (`_merge_extracted`, `_persist_extracted_fact`, `_extractor_cache_{get,set,key}`, `_REGEX_TOPIC_TO_CANONICAL_KEYS`, `_NARRATOR_MODEL_MAP`) and their imports.
- **Bundle compiler DELETED (WS-C):** removed `COACH_BUNDLE_COMPILER_ENABLED` from `Settings`, the `_build_system_prompt_with_memory` bundle routing block, the agent-loop tool-filter branch, the import-time DeprecationWarning, and the `_gate_allowlist` ternary (the gate now unconditionally uses the global `CITATION_REGISTRY`).
- **coach_reasoner façade REMOVED (WS-C, audit 01 HOLE-5):** `CoachReasonerService` was exported via the `financial_core.dart` barrel with zero production callers — a façade. Deleted the service, the barrel export, and `coach_reasoner_test.dart`. `flutter analyze` clean (no dangling imports).
- **CI eval gate LIVE (WS-E):** `.github/workflows/coach-eval.yml` runs `test_coach_claim_inversions.py` + `test_claim_checker.py` + `test_concept_registry.py` + `test_facade_resolution.py` with `-x` fail-fast on every backend-touching PR/push. The path filter fires on generic backend AND narrow coach-prompt/registry/config edits AND the fixtures themselves (CI path-filter blind-spot mitigation per the recorded lesson).

## fallback_reasons Decision Inputs Consulted (mandatory checkpoint input)

The pre-taken ACTIVATE decision for the citation gate weighed the observed `fallback_reasons` attribution from the prior plans, exactly as the plan-check fix mandated:

| Input | Observation | Bearing on activation |
|-------|-------------|------------------------|
| **Plan 02 SUMMARY** (13-shape probe) | 5/13 = **38.5% fallback**, distribution `prescriptive_blocked`=4 + `hallucination_major`=1, `banned_residual`=0. The 38.5% is explicitly *worst-case-skewed* (heavy on adversarial/prescriptive shapes). | The dominant new fallback driver is `prescriptive_blocked` — clean/hedged/conditional/definitional replies are unaffected. The incremental fallback is bounded by the live coach's prescriptive-emission rate, which the system prompt already discourages. |
| **Plan 04 SUMMARY** (17-shape probe) | The new `definition_inversion` layer adds **0 fallback** to the 13 Plan-02 clean/adversarial shapes; +4 only on deliberately-inverted definitional shapes. | The claim-checker complements, not competes with, a numeric citation gate. Activation adds a guard on a *different* surface (numeric grounding) than the claim-checker (definitional). |
| **Gap-closure fix** (commit 6f60acab3) | The dominant realistic false positive — `racheter` matched as `achete` inside `racheter` — was fixed with a word-boundary correction. | The most likely real-world over-block of the prescriptive layer is closed, lowering the realistic incremental fallback the citation gate stacks on top of. |

**Conclusion:** the 38.5% figure is adversarial-probe-skewed, not a production rate; the dominant fallback driver (`prescriptive_blocked`) is concentrated on genuinely prescriptive output (the education-strict target); and the claim-checker adds zero fallback on clean shapes. The numeric citation gate is therefore the smaller remaining surface — activation (with the OFF env rollback retained) was selected over REMOVE. Plan 08's persona walkthrough is the live-rate check that the plan flagged as the real gate (vs. the adversarial probe).

## Task Commits

Each unit committed atomically:

1. **Task 1: Resolve the 3 dark gates** — `39c70e7da` (feat) — citation gate activated + grammar wired to live path; dual-LLM + bundle-compiler + narrator-model flags/fields/consumers/helpers/dark-only-tests deleted; `test_facade_resolution.py` created; stale endpoint/bundle tests corrected.
2. **Task 2: Resolve the coach_reasoner façade** — `a7dccd26b` (refactor) — `coach_reasoner.dart` + barrel export + `coach_reasoner_test.dart` removed; followed by `81e73c88b` (docs) correcting the `calculator-graph.md` map (CoachReasoner row was itself façade-documentation drift).
3. **Task 3: Wire the inversion fixtures into CI** — `92906bd8d` (ci) — `.github/workflows/coach-eval.yml` created.

## Files Created/Modified

- `services/backend/app/core/config.py` — citation gate default `False→True` (with activation/rollback doc); `COACH_DUAL_LLM_ENABLED`, `COACH_BUNDLE_COMPILER_ENABLED`, `COACH_NARRATOR_MODEL` removed; unused `Field` import dropped.
- `services/backend/app/api/v1/endpoints/coach_chat.py` — `_build_system_prompt_with_memory` collapsed to legacy + citation grammar append when gate ON; extractor stage → no-op shim; narrator tools/model branches collapsed; `_gate_allowlist=None`; orphan extractor helpers + dead imports removed (net −564 lines).
- `services/backend/app/services/coach/claude_coach_service.py` — removed the bundle-compiler import-time DeprecationWarning + unused `warnings` import; doc note that `_from_bundles` has no production caller.
- `apps/mobile/lib/services/financial_core/financial_core.dart` — removed the `coach_reasoner.dart` barrel export.
- `docs/calculator-graph.md` — removed the CoachReasoner row; corrected BayesianEnricher's consumer to ConfidenceScorer.
- `services/backend/tests/test_facade_resolution.py` (created) — 10 tests: removed flags absent from `Settings.model_fields`; gate default-ON; rollback env binds; consumer reachable on live path; live prompt carries grammar when ON and omits it when rolled back; `_gate_allowlist=None`.
- `.github/workflows/coach-eval.yml` (created) — the WS-E CI regression gate.
- Test deletions (5 dark-only files): `test_coach_chat_dual_llm.py`, `test_narrator_model_flag.py`, `test_coach_chat_bundles.py`, `test_config.py` (dual-LLM scaffolding), `test_citation_gate/test_bundle_intersect.py`, `tests/integration/test_dual_llm_cost.py`. Test corrections: `test_byte_identity_flag_off.py`, `test_citation_gate/test_config.py`, `test_global_registry_fallback.py`, `test_coach_chat_endpoint.py`, `test_llm_extractor.py`, `tests/bundles/test_bundle_compiler.py`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Critical functionality] Wired the citation grammar into the live single-LLM path**
- **Found during:** Task 1 (citation-gate activation)
- **Issue:** The citation-grammar instruction was only appended inside `build_narrator_system_prompt` (the dual-LLM narrator builder being deleted), never the legacy `build_system_prompt` on the single-LLM live path. Activating the gate on the legacy path without it would REJECT every uncited number → FALLBACK on ~all numeric replies (the exact fallback-rate spike threat T-m1-07-03 warned about).
- **Fix:** Appended the closed-world citation grammar (intent-scoped or full fragment) to `_build_system_prompt_with_memory`'s output when `COACH_CITATION_GATE_ENABLED` is ON.
- **Files modified:** `services/backend/app/api/v1/endpoints/coach_chat.py`
- **Commit:** `39c70e7da`

**2. [Rule 1 - Stale tests] Corrected tests encoding pre-activation behavior**
- **Found during:** Task 1 (full backend suite)
- **Issue:** 7 test failures across 3 files: 3 in `test_coach_chat_endpoint.py` (the now-active gate gates the mocked orchestrator's uncited-number answer → fallback + a gated retry, breaking passthrough/`assert_called_once` assertions); 4 in `tests/bundles/test_bundle_compiler.py` (the bundle compiler now always includes the `citation-grammar` bundle when the gate flag is ON-by-default); 1 byte-identity test asserted the flag *defaults* False.
- **Fix:** Added `monkeypatch.setattr(settings, "COACH_CITATION_GATE_ENABLED", False)` to the 3 passthrough/wiring endpoint tests + a gate-OFF autouse fixture in the bundle-composition test module (these pin base composition independent of the grammar), and changed the byte-identity test to force the flag OFF explicitly (preserving the rollback byte-identity property while dropping the now-wrong default assertion).
- **Files modified:** `test_coach_chat_endpoint.py`, `tests/bundles/test_bundle_compiler.py`, `test_citation_gate/test_byte_identity_flag_off.py`, `test_citation_gate/test_config.py`, `test_global_registry_fallback.py`, `test_llm_extractor.py`
- **Commit:** `39c70e7da`

**3. [Rule 1 - Documented-invariant drift] Removed CoachReasoner from calculator-graph.md**
- **Found during:** Task 2 (lefthook map-freshness hint)
- **Issue:** `docs/calculator-graph.md` listed `CoachReasoner` as a wired calculator consumed by "CoachNarrativeService advanced narratives" — but it had zero production callers (HOLE-5), so that doc row was itself façade-documentation drift; BayesianEnricher's consumer column also wrongly pointed at CoachReasoner.
- **Fix:** Removed the CoachReasoner row; corrected BayesianEnricher's consumer to ConfidenceScorer (its real consumer).
- **Files modified:** `docs/calculator-graph.md`
- **Commit:** `81e73c88b`

**Scope decision (not a deviation):** the library builders `build_narrator_system_prompt` / `build_narrator_system_prompt_from_bundles` and `bundle_compiler.py` were RETAINED. They have live test coverage (~10 non-dark test files import them) and, after flag removal, are no longer flag-gated production façades. Deleting them would break those tests and exceed the surgical scope (Karpathy #3). The binding "no flag-OFF dead guard" requirement is satisfied by removing the flags + their production consumers; the test-covered builders are not dark guards.

**Total deviations:** 3 auto-fixed (1 Rule 2 critical wiring, 2 Rule 1 — stale-test + doc-drift corrections). No Rule 4 escalation: the architectural coupling (grammar on dual-LLM path) was resolved by carrying the critical functionality forward to the live path, honoring the founder-delegated ACTIVATE decision rather than re-opening it.

## Threat Model Coverage

- **T-m1-07-01** (Repudiation / false confidence — 3 dark gates + unwired reasoner, `mitigate`): mitigated. Each gate activated-or-deleted; `test_facade_resolution.py` asserts no dark/unwired surface remains (removed flags absent from `Settings`, gate default-ON with reachable consumer, reasoner refs zero).
- **T-m1-07-02** (Information disclosure / inversion regression, `mitigate`): mitigated. `coach-eval.yml` fails the build on any inversion-fixture regression, with a blind-spot-resistant path filter.
- **T-m1-07-03** (Denial of service / over-blocking — 3 stacked fail-closed layers, `mitigate`): mitigated. The citation-gate activation decision was grounded in the Plan 02/04 fallback_reasons counts (above); the discovered grammar-coupling fix prevents a degenerate ~100% fallback; the OFF env rollback is retained and tested. Plan 08's persona walkthrough is the live-rate check.
- **T-m1-07-SC** (Tampering / pip-pub installs, `accept`): no new packages — CI uses existing runners + `pip install ".[dev]"`; no new Dart/Python dependency. No package-legitimacy gate needed.

## Known Stubs

None. The extractor-stage shim is an intentional no-op (the dual-LLM path is deleted, not stubbed; the regex extractor STAGE 1 is the live floor) — documented in code, not a placeholder. No hardcoded empty UI values, no TODO/FIXME introduced. The activated citation gate is fully wired (grammar on the live path + reachable wrapper consumer).

## Threat Flags

None — no new network endpoint, auth path, file-access pattern, or schema change introduced. Changes are flag/dead-code removal + an additive prompt-fragment append on an existing in-process trust boundary + a CI workflow (no runtime surface).

## Verification (deterministic citations)

- **Full backend suite:** `cd services/backend && python3 -m pytest tests/ -q` → `7792 passed, 116 skipped, 3 xfailed` (0 failed).
- **flutter analyze:** `cd apps/mobile && flutter analyze` → `No issues found!`
- **financial_core tests:** `flutter test test/services/financial_core/` → `All tests passed!` (548).
- **config.py flag state:** `grep -nE "COACH_DUAL_LLM_ENABLED|COACH_BUNDLE_COMPILER_ENABLED|COACH_CITATION_GATE_ENABLED" app/core/config.py` → only `COACH_CITATION_GATE_ENABLED: bool = True` (the two delete-flags absent).
- **reasoner removed:** `grep -rn "CoachReasonerService" apps/mobile/lib` → only the removal-note comment (zero functional refs).
- **CI workflow:** `python3 -c "import yaml; ..."` → jobs `['changes','coach-eval','coach-eval-gate']`; references `test_coach_claim_inversions.py`; `grep -c -E "inversion|claim_checker|concept_registry"` → 16.
- **eval suite (the exact CI command):** `pytest tests/test_coach_claim_inversions.py tests/test_claim_checker.py tests/test_concept_registry.py tests/test_facade_resolution.py -q -x` → `200 passed`.

## Next Phase Readiness

- **Plan 08 (persona walkthrough)** can proceed: the citation gate is now live on the single-LLM narrator path with the grammar wired — Plan 08's W1-style persona walkthrough is the founder-mandated gate to measure the *real* fallback rate (vs. the adversarial probe) and confirm legitimate replies are not over-blocked by the now-three-layer fail-closed stack.
- **No blockers.** STATE.md / ROADMAP.md intentionally NOT modified (orchestrator owns those writes, per the objective).

## Self-Check: PASSED

- FOUND: .planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-07-activate-or-delete-facades-ci-SUMMARY.md
- FOUND: services/backend/tests/test_facade_resolution.py (created)
- FOUND: .github/workflows/coach-eval.yml (created)
- REMOVED: apps/mobile/lib/services/financial_core/coach_reasoner.dart (façade deleted)
- REMOVED: services/backend/tests/test_coach_chat_dual_llm.py (dark-only test deleted)
- FOUND commit: 39c70e7da (Task 1 — resolve 3 dark gates)
- FOUND commit: a7dccd26b (Task 2 — remove coach_reasoner façade)
- FOUND commit: 81e73c88b (Task 2 doc — calculator-graph correction)
- FOUND commit: 92906bd8d (Task 3 — coach-eval CI gate)
- VERIFIED: full backend suite 7792 passed, 0 failed; flutter analyze clean; 548 financial_core tests green

---
*Phase: mint-grounded-coach-m1*
*Completed: 2026-06-12*
