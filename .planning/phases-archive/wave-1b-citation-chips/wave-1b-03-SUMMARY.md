---
phase: wave-1b-citation-chips
plan: 03
subsystem: backend

tags: [narrator-grammar, citation-fragment, intent-scoped, tool-call-id, lsfin-lint, accent-lint, karpathy-tdd, wave-1b]

# Dependency graph
requires:
  - phase: wave-1b-citation-chips
    plan: 01
    provides: 3 SKIPPED grammar stubs in tests/test_coach_citation/test_tool_call_id_grammar.py that Plan 03 unskips
  - phase: wave-1b-citation-chips
    plan: 02
    provides: 6 tool_call_id CITATION_REGISTRY entries (registry size 24) that auto-flow into CITATION_GRAMMAR_FRAGMENT via _build_citation_grammar_fragment()'s iteration over CITATION_REGISTRY.keys()
provides:
  - tool_call_id paragraph in CITATION_GRAMMAR_FRAGMENT teaching narrator that tool_* keys mark server-computed numbers carrying inputs_hash in the response container
  - ACCEPTÉ — chiffre calculé côté serveur example block teaching {{cite:tool_budget_snapshot}} placement
  - _WAVE_1B_TOOL_KEYS_ALWAYS_ON frozenset unioned into every intent bucket of _INTENT_TO_CITATION_KEYS (always-on per RESEARCH §4.4)
  - test_grammar_fragment_lists_all_24_registry_keys re-tightened from Plan 02's 18-non-tool sub-baseline to unified 24-key total
  - 3 Plan-01 stubs transitioned SKIPPED -> PASSED (Karpathy #4 closed loop)
affects: [wave-1b-04-narrator-emit, wave-1b-05-flutter-chip, wave-1b-08-breadcrumb]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single-segment grammar Q5_DECISION: {{cite:tool_<name>}} adopted instead of 2-segment {{cite:tool_call_id:<inputs_hash>}} (CONTEXT line 36 deviation). Rationale: respects CONTEXT hard constraint #4 (no edit to _RE_CURRENCY / _RE_PERCENT / _RE_CITE_PLACEHOLDER regexes in citation_parser.py). Per-call inputs_hash travels via the tool response container, not the placeholder."
    - "Always-on intent mapping: tool_* keys union into every intent bucket via the _WAVE_1B_TOOL_KEYS_ALWAYS_ON frozenset. Tool calls are LLM-driven, NOT intent-driven; the narrator can call get_budget_status even on a retirement intent. Guarantees coverage regardless of classified intent."

key-files:
  created:
    - .planning/phases/wave-1b-citation-chips/wave-1b-03-SUMMARY.md
  modified:
    - services/backend/app/services/coach/citation_grammar.py
    - services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py
    - services/backend/tests/test_citation_gate/test_narrator_grammar_fragment.py

key-decisions:
  - "Q5_DECISION: 1-segment grammar {{cite:tool_<name>}} adopted (RESEARCH §4.3 Option A) instead of CONTEXT line 36's 2-segment {{cite:tool_call_id:<inputs_hash>}}. Decision shipped as recommended at exec-start per PLAN.md Q5_DECISION block; Julien did NOT object during exec window (sequential mode, no interactive checkpoint). If Julien rejects post-PR, alternative requires (a) revisiting CONTEXT hard constraint #4, (b) extending 3 regex sites in citation_parser.py, (c) updating 213 byte-identity tests in test_citation_gate/. Estimated alternative cost: 2-3 additional plans."
  - "Test rename from test_fragment_lists_all_18_registry_keys -> test_fragment_lists_all_24_registry_keys (re-tighten from Plan 02's split baseline). Plan 02 had introduced an 18-non-tool sub-baseline as transitional check pending Plan 03; Plan 03 wires all 24 keys into the fragment via auto-iteration, so the unified 24-key assertion is now the canonical invariant. The 18-non-tool + 6-tool sub-baselines are preserved as separate regression checks so drift in either sub-bucket surfaces here independently."
  - "tool_paragraph + tool_example duplicated across both _build_citation_grammar_fragment (full fragment) AND build_intent_scoped_citation_grammar (intent-scoped variant) header builders. Karpathy #3 surgical: each builder owns its own header/examples string per Phase 94.2 H1 architecture; no shared helper introduced. Cost: ~12 lines of duplication; benefit: rendering path is identical regardless of which builder fires (full when intents empty, scoped when intents populated)."

patterns-established:
  - "When extending a closed-world grammar fragment with a new source_kind, BOTH the full-fragment builder AND the intent-scoped builder must receive parallel updates (paragraph + example block + intent always-on mapping). The intent-scoped variant defers to the full fragment when the intent union covers all registry keys, but for partial intent sets it builds independently — failing to update both leaves a coverage gap where intent-scoped narrator turns lack the new vocabulary."

requirements-completed: [WAVE1B-02, WAVE1B-07]

# Metrics
duration: 9min
completed: 2026-05-15
---

# Phase wave-1b Plan 03: Narrator Grammar Fragment Summary

**tool_call_id semantics paragraph + accepted-example block + always-on intent mapping shipped in citation_grammar.py; 3 Plan-01 stubs transitioned SKIPPED -> PASSED; test_narrator_grammar_fragment.py re-tightened from 18-non-tool to unified 24-key total assertion; 1-segment grammar Q5_DECISION shipped as recommended (CONTEXT line 36 deviation).**

## Performance

- **Duration:** ~9 min
- **Started:** 2026-05-15T07:15:00Z (branch creation feature/wave-1b-03-grammar-fragment from dev at 3b016017)
- **Completed:** 2026-05-15T07:24:00Z (GREEN commit 29b01531)
- **Tasks:** 1 (TDD: RED unskip + GREEN grammar+intent+test-bump)
- **Files created:** 1 (this SUMMARY)
- **Files modified:** 3 (1 grammar module + 2 tests)

## Diff size

```
 .../backend/app/services/coach/citation_grammar.py | 85 +++++++++++++++++++---
 .../test_narrator_grammar_fragment.py              | 60 +++++++++------
 .../test_tool_call_id_grammar.py                   |  6 +-
 3 files changed, 114 insertions(+), 37 deletions(-)
```

## Token-count delta on rendered grammar fragment

- **Pre-Plan-03 (registry already at 24, but no tool_paragraph + no tool_example):** 5'880 chars, 866 words, ~1'960 approx tokens (chars/3 FR heuristic).
- **Post-Plan-03 (tool_paragraph + tool_example present):** 6'502 chars, 959 words, ~2'167 approx tokens.
- **Delta:** +622 chars (+10.6%), +93 words, +207 approx tokens. Within RESEARCH §A4 budget (<5% of ~80 kB narrator prompt = <4 kB allotment for grammar surface).

Note: the 24-key bullet list was already present in the pre-Plan-03 fragment (Plan 02 added the 6 tool entries to CITATION_REGISTRY at 3b016017, and the fragment auto-iterates over CITATION_REGISTRY.keys() at module-import). Plan 03's char delta is concentrated in the new tool_paragraph (370 chars) + the new ACCEPTÉ — chiffre calculé côté serveur example block (252 chars in the full builder + 252 chars in the intent-scoped builder) = ~874 chars added across both builders, with the full fragment receiving 622 chars net.

## Q5_DECISION outcome

**Adopted as recommended: 1-segment grammar `{{cite:tool_<name>}}`** (RESEARCH §4.3 Option A) instead of CONTEXT line 36's 2-segment `{{cite:tool_call_id:<inputs_hash>}}`.

- **Julien confirmation status:** Sequential exec mode, no interactive checkpoint — shipped as recommended at exec-start per the Q5_DECISION block at the top of `wave-1b-03-PLAN.md`. Julien reviews via PR (not yet merged); if rejected post-PR, the alternative cost is 2-3 additional plans (revisit CONTEXT hard constraint #4 + extend 3 regex sites in citation_parser.py + update 213 byte-identity tests).
- **Rationale enforced:**
  1. CONTEXT hard constraint #4 respected — zero edits to `_RE_CURRENCY`, `_RE_PERCENT`, `_RE_CITE_PLACEHOLDER` in citation_parser.py. Existing `r"\{\{cite:[A-Za-z0-9_\-]+\}\}"` already matches `{{cite:tool_budget_snapshot}}`.
  2. Functionally equivalent — per CONTEXT plan default Q1(a), one chip per tool call attached to the response container; per-number inputs_hash granularity isn't needed. The actual inputs_hash travels via the tool response object surfaced to Flutter in `RagToolCall` / `CoachResponse.toolCalls`.
  3. Karpathy #2 simplicity — 1-segment requires zero code change in the gate.

## Task Commits

Each commit landed atomically on `feature/wave-1b-03-grammar-fragment`:

1. **RED: Unskip 3 Plan-01 grammar stubs** — `5224af94` (test)
2. **GREEN: tool_paragraph + tool_example + intent always-on + test re-tighten** — `29b01531` (feat)

## Files Created/Modified

### Created (1 file)
- `.planning/phases/wave-1b-citation-chips/wave-1b-03-SUMMARY.md` — this file.

### Modified (3 files)
- `services/backend/app/services/coach/citation_grammar.py` — +85 LOC across (a) tool_paragraph string in both header builders (full fragment + intent-scoped), (b) tool_example block in both example sections, (c) _WAVE_1B_TOOL_KEYS_ALWAYS_ON frozenset definition + union into every intent bucket of _INTENT_TO_CITATION_KEYS, (d) updated `__all__` export list with _WAVE_1B_TOOL_KEYS_ALWAYS_ON.
- `services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py` — removed 3 `@pytest.mark.skip` markers from Plan 01 stubs; added explicit `len(CITATION_REGISTRY) == 24` assertion in test_grammar_fragment_lists_all_24_registry_keys.
- `services/backend/tests/test_citation_gate/test_narrator_grammar_fragment.py` — renamed test_fragment_lists_all_18_registry_keys -> test_fragment_lists_all_24_registry_keys; assertion logic re-tightened to assert all 24 CITATION_REGISTRY keys appear in CITATION_GRAMMAR_FRAGMENT, with non_tool_keys == 18 + tool_keys == 6 + len(CITATION_REGISTRY) == 24 sub-baselines preserved as independent regression checks.

## Decisions Made

- **Decision 1 (TDD discipline RED -> GREEN split)** — Plan 03 has `tdd="true"` and Plan 01 already shipped the stubs. Per `<tdd_execution>`, executed as two commits within one task: RED (`5224af94`, unskip + observe 1 fail / 2 vacuous passes because the full fragment already iterates 24 keys via Plan 02's registry growth) -> GREEN (`29b01531`, tool_paragraph + tool_example + intent always-on + 24-key test re-tighten -> 3/3 pass + 12 pre-existing in test_narrator_grammar_fragment.py also pass).
- **Decision 2 (tool_paragraph + tool_example duplicated across both builders)** — citation_grammar.py has two builder functions: `_build_citation_grammar_fragment` (full fragment) and `build_intent_scoped_citation_grammar` (intent-scoped). Each builder owns its own header/examples string per Phase 94.2 H1 architecture. Plan 03 duplicates the tool_paragraph + tool_example blocks into both builders rather than extracting a shared helper. Karpathy #3 surgical: zero refactor of the existing architecture; ~12 lines of duplication accepted for parallel rendering paths. If the duplication becomes a liability (e.g. third source_kind landing in Wave 2), extract a helper at that point — premature now.
- **Decision 3 (test rename rather than magic-number bump)** — Plan 02 had pinned test_fragment_lists_all_18_registry_keys at the 18-non-tool sub-baseline as a transitional check pending Plan 03. Plan 03 now wires all 24 keys into the fragment, so the canonical invariant is `len(CITATION_REGISTRY) == 24` + all keys in fragment. The test was renamed (not just bumped) to reflect the new canonical contract; the 18-non-tool + 6-tool sub-baselines remain as separate assertions inside the test body so drift in either sub-bucket still surfaces here. Plan-prescribed approach was "keep the name, bump the magic number" — switched to rename because Plan 02's existing comment block already documented Plan 03 as the rename owner ("Plan 03 owns the re-tighten") and a stale function name would mislead future readers.

## Deviations from Plan

### Auto-fixed Issues

None. Plan executed exactly as written modulo Decision 3 (test rename vs magic-number bump), which is a stylistic refinement consistent with the plan's `<acceptance_criteria>` ("rename/updated to expect 24 keys") and Plan 02's docstring guidance — not a deviation.

**Total deviations:** 0 auto-fixed. Plan-prescribed implementation pattern matched the codebase shape exactly (the `_build_citation_grammar_fragment` and `build_intent_scoped_citation_grammar` functions had clean insertion points for tool_paragraph + tool_example; `_INTENT_TO_CITATION_KEYS` had clean union-with-frozenset extension points).

**Impact on plan:** All acceptance criteria met. Plan's verification step (`pytest tests/test_coach_citation/test_tool_call_id_grammar.py tests/test_citation_gate/test_narrator_grammar_fragment.py -q`) passes 15/15. Full backend pytest delta = +3 net new passes (was 6874 PASSED on Plan 02 baseline; now 6877 PASSED — exact match for unskipping 3 grammar stubs).

## Issues Encountered

None. The 5-step grammar implementation (tool_paragraph + tool_example in both builders + always-on mapping + test rename) landed cleanly on first GREEN run. No iteration cycles needed.

Pre-existing lefthook lint warning: `memory-retention-gate WARNING: ~/.claude/projects/.../memory/MEMORY.md has 184 lines (target <100)` — Julien's curator vault, out of scope for Plan 03 (CLAUDE.md §8 Karpathy practice 1).

## Known Stubs

None introduced by Plan 03. Plan 01's other 19 SKIPPED stubs (5 backend breadcrumb + 14 mobile widget) remain skipped — owned by Plan 05/06 (Flutter chip + modal) and Plan 08 (breadcrumb).

## Threat Flags

None. Plan 03 introduces no new network endpoints, no new auth paths, no new file-access surface, no schema changes at trust boundaries. The grammar fragment is a static FR string built once at module import; runtime mutation raises AttributeError on the module constant.

T-WAVE1B-03-01 (banned terms) mitigated: `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py` exits 0. T-WAVE1B-03-02 (modal verbs) mitigated: tool_example uses "pourrait" (LSFin-safe). T-WAVE1B-03-03 (prompt bloat) accepted: +207 approx tokens is <0.3% of the ~80 kB narrator prompt budget. T-WAVE1B-03-04 (downstream snapshot drift) mitigated: test_byte_identity_flag_off 6/6 green, test_citation_gate/ 212 passed, test_dag_invalidation/test_pack_registry_coupling 2/2 green. T-WAVE1B-03-05 (Q5 deviation) mitigated: deviation surfaced in PLAN.md Q5_DECISION block + this SUMMARY.

## User Setup Required

None. Plan 03 is pure backend-source diff: grammar string + intent mapping + test assertions. No env var, no Railway config, no Apple Developer portal capability, no Maestro flow change.

## Next Phase Readiness

- **Plan 04** (narrator emission wiring) can now rely on the grammar fragment teaching tool_call_id semantics — when the narrator LLM receives the system prompt with `COACH_CITATION_GATE_ENABLED=true`, it sees the full DOCTRINE block including the tool_paragraph + tool_example. Plan 04's task is to confirm the narrator emits `{{cite:tool_<name>}}` after numbers from tool responses, and to wire the per-call inputs_hash into the response container surfaced to Flutter.
- **Plan 05/06** (Flutter chip + modal) can now reference the same 24-key registry that the narrator sees, and the chip renderer can match on `source_kind == "tool_call_id"` for the ⚙ icon path.
- **Plan 08** (Sentry breadcrumb) can use the `_WAVE_1B_TOOL_KEYS_ALWAYS_ON` frozenset as the canonical filter for which placeholders trigger the `coach.citation.tool_call_id.emitted` emission.

## 0-trust Self-Check (CLAUDE.md §9.4 + §9.6)

**Evidence (verbatim citations):**

- **Evidence file 1** — `services/backend/app/services/coach/citation_grammar.py` contains the tool_paragraph + tool_example + WAVE_1B_TOOL_KEYS_ALWAYS_ON: `grep -c "tool_\*\|tool_<nom>\|ACCEPTÉ — chiffre calculé côté serveur" services/backend/app/services/coach/citation_grammar.py` returns `12` (>=2 required). FOUND.
- **Evidence file 2** — All 6 tool keys present: `grep -c "tool_budget_snapshot\|tool_retirement_projection\|tool_cross_pillar_analysis\|tool_couple_optimization\|tool_cap_status\|tool_retrieve_memories" services/backend/app/services/coach/citation_grammar.py` returns `8` (>=6 required). FOUND.
- **Evidence file 3** — Always-on frozenset present: `grep -c "_WAVE_1B_TOOL_KEYS_ALWAYS_ON\|WAVE_1B_TOOL_KEYS" services/backend/app/services/coach/citation_grammar.py` returns `10` (>=1 required). FOUND.
- **Evidence file 4** — Zero skip markers in Plan 01 stub file: `grep -c "@pytest.mark.skip" services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py` returns `0`. FOUND.
- **Evidence command 1** — `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py` -> exit code `0`. CITED.
- **Evidence command 2** — `python3 tools/checks/accent_lint_fr.py --file services/backend/app/services/coach/citation_grammar.py` -> exit code `0`. CITED.
- **Evidence command 3** — `cd services/backend && python3 -m pytest tests/test_coach_citation/test_tool_call_id_grammar.py tests/test_citation_gate/test_narrator_grammar_fragment.py -q` -> `15 passed in 0.24s`. CITED.
- **Evidence command 4** — `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q` -> `212 passed in 0.89s` (no regression vs Plan 02 baseline 212). CITED.
- **Evidence command 5** — `cd services/backend && python3 -m pytest tests/test_citation_gate/test_byte_identity_flag_off.py -q` -> `6 passed in 0.23s` (Phase 94 byte-identity flag-OFF preserved). CITED.
- **Evidence command 6** — `cd services/backend && python3 -m pytest tests/test_dag_invalidation/test_pack_registry_coupling.py -q` -> `2 passed in 0.18s` (Plan 02's 24-key drift detector still green). CITED.
- **Evidence command 7** — `cd services/backend && python3 -m pytest tests/ -q | tail -5` -> `6877 passed, 67 skipped, 1 xfailed, 1 warning in 113.18s`. Plan 02 baseline was 6874 passed + 70 skipped; Plan 03 delta is +3 passed / -3 skipped = exact match for unskipping 3 grammar stubs. Zero regressions. CITED.
- **Evidence command 8** — `python3 -c "from app.services.coach.citation_grammar import CITATION_GRAMMAR_FRAGMENT; print('tool_budget_snapshot' in CITATION_GRAMMAR_FRAGMENT)"` -> `True`. CITED.
- **Evidence command 9** — `python3 -c "from app.services.coach.citation_grammar import build_intent_scoped_citation_grammar; frag = build_intent_scoped_citation_grammar(('retirement',)); print('tool_cap_status' in frag)"` -> `True`. CITED.
- **Caveat** — Plan 03 only proves grammar fragment correctness + intent mapping + 15 test assertions. It does NOT prove that the narrator LLM correctly emits `{{cite:tool_*}}` placeholders against the new doctrine (that's Plan 04 narrator-emit wiring), nor that the Flutter chip renders the tool icon (Plan 05/06). No end-to-end user flow exercised. PR opened against `dev`, NOT merged. Per CLAUDE.md §9.5 — this is Stage 1 of 4 (PR opened). Do NOT claim « shipped », « ready », « works », « validated ».

**Acceptance criteria status:**

- [x] `grep -c "tool_\*\|tool_<nom>\|ACCEPTÉ — chiffre calculé côté serveur"` returns 12 (>=2).
- [x] `grep -c "tool_budget_snapshot|...|tool_retrieve_memories"` returns 8 (>=6 — all 6 tool keys present).
- [x] `grep -c "_WAVE_1B_TOOL_KEYS_ALWAYS_ON|WAVE_1B_TOOL_KEYS"` returns 10 (>=1 — always-on frozenset defined).
- [x] `banned_terms_python.py citation_grammar.py` exits 0.
- [x] `accent_lint_fr.py --file citation_grammar.py` exits 0.
- [x] `python3 -c "...'tool_budget_snapshot' in CITATION_GRAMMAR_FRAGMENT"` prints True.
- [x] `python3 -c "...build_intent_scoped_citation_grammar(('retirement',)) -> 'tool_cap_status' in frag"` prints True.
- [x] `@pytest.mark.skip` count in `test_tool_call_id_grammar.py` is 0.
- [x] `pytest tests/test_coach_citation/test_tool_call_id_grammar.py -q` exits 0 with 3 PASSED.
- [x] `pytest tests/test_citation_gate/ -q` confirms 212 passed (zero regression vs Plan 02 baseline 212).
- [x] Phase 94 byte-identity preserved (test_byte_identity_flag_off 6/6 green).
- [x] Full backend pytest delta vs Plan 02 baseline (6874): +3 (= 3 stubs unskipped on Plan 03).

## Self-Check: PASSED

- All 3 modified files have the expected content (grep counts above the thresholds).
- Both task commits (`5224af94`, `29b01531`) present in `git log`.
- 15 targeted tests PASSED (test_tool_call_id_grammar.py 3/3 + test_narrator_grammar_fragment.py 12/12).
- 212 test_citation_gate tests PASSED (zero regression vs Plan 02 baseline 212).
- 6877 backend pytest tests PASSED (Plan 02 baseline 6874 + 3 unskipped Plan-01 stubs = exact match).
- LSFin banned-terms lint exits 0 on citation_grammar.py.
- FR accent lint exits 0 on citation_grammar.py.
- Q5_DECISION (1-segment grammar) shipped as recommended; deviation block at top of PLAN.md surfaces it for Julien review at PR time.
- Zero deviations from plan (no Rule 1-4 auto-fixes triggered).

---

*Phase: wave-1b-citation-chips*
*Plan: 03*
*Completed: 2026-05-15*
*Branch: feature/wave-1b-03-grammar-fragment (base 3b016017)*
*Commits: 5224af94 (RED) -> 29b01531 (GREEN)*
