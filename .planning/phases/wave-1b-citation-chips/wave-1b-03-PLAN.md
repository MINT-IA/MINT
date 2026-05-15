---
phase: wave-1b
plan: 03
type: execute
wave: 1
depends_on: [wave-1b-01]
files_modified:
  - services/backend/app/services/coach/citation_grammar.py
  - services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py
  - services/backend/tests/test_citation_gate/test_narrator_grammar_fragment.py
autonomous: true
requirements: [WAVE1B-02, WAVE1B-07]
must_haves:
  truths:
    - "CITATION_GRAMMAR_FRAGMENT contains a paragraph explaining tool_call_id semantics (single-segment {{cite:tool_<name>}} grammar)"
    - "CITATION_GRAMMAR_FRAGMENT contains the 6 new tool_<name> bullet rows (auto-generated from CITATION_REGISTRY after Plan 02 adds them)"
    - "CITATION_GRAMMAR_FRAGMENT contains one accepted EXAMPLE block teaching the tool_call_id citation flow"
    - "_INTENT_TO_CITATION_KEYS frozensets include all 6 tool_<name> keys in EVERY intent bucket (always-on per RESEARCH §4.4)"
    - "Existing test_grammar_fragment_lists_all_18_registry_keys is renamed/updated to expect 24 keys"
    - "Plan 01's grammar stub tests are unskipped and pass"
    - "Q5 DEVIATION block visible at top of plan: 1-segment grammar adopted instead of 2-segment {{cite:tool_call_id:<inputs_hash>}} (CONTEXT line 36 deviation) — Julien confirm before exec"
  artifacts:
    - path: "services/backend/app/services/coach/citation_grammar.py"
      provides: "Updated grammar header + tool_call_id paragraph + accepted example + intent mapping with always-on tool keys"
      contains: "tool_call_id|tool_budget_snapshot"
    - path: "services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py"
      provides: "Plan 01 stubs unskipped + passing"
      contains: "def test_grammar_fragment_lists_all_tool_keys|def test_intent_scoped_grammar_includes_tools"
    - path: "services/backend/tests/test_citation_gate/test_narrator_grammar_fragment.py"
      provides: "Bumped 18 → 24 keys assertion"
      contains: "24\\|tool_"
  key_links:
    - from: "services/backend/app/services/coach/citation_grammar.py"
      to: "services/backend/app/services/coach/citation_registry.py"
      via: "_build_citation_grammar_fragment iterates CITATION_REGISTRY.keys()"
      pattern: "from app.services.coach.citation_registry import CITATION_REGISTRY"
---

# Q5_DECISION — 1-segment vs 2-segment grammar (RESEARCH §4.3 deviation)

**CONTEXT.md line 36 prescribes:** `{{cite:tool_call_id:<inputs_hash>}}` (2-segment grammar).

**RESEARCH §4.3 recommends:** `{{cite:tool_<name>}}` (1-segment grammar, e.g. `{{cite:tool_budget_snapshot}}`).

**Rationale for 1-segment (RESEARCH-recommended):**
1. **Respects CONTEXT hard constraint #4** — no change to `_RE_CURRENCY` / `_RE_PERCENT` regexes in `citation_parser.py`. The existing `_RE_CITE_PLACEHOLDER = r"\{\{cite:[A-Za-z0-9_\-]+\}\}"` already matches `tool_budget_snapshot`.
2. **Functionally equivalent** — per CONTEXT open Q1 plan default (a), one chip per tool call attached to the response container; per-number `inputs_hash` granularity isn't needed. The actual `inputs_hash` travels via the tool response object surfaced to Flutter in `RagToolCall` / `CoachResponse.toolCalls`.
3. **Karpathy #2 simplicity** — 1-segment requires zero code change in the gate. 2-segment requires modifying `_RE_CITE_PLACEHOLDER`, `_has_adjacent_cite`, and `_substitute_placeholders` — all in `citation_parser.py` which CONTEXT hard constraint #4 forbids touching.

**Plan adopts 1-segment.** If Julien rejects this deviation, the alternative is to (a) revisit CONTEXT hard constraint #4, (b) extend the 3 regex sites in `citation_parser.py`, (c) update 213 byte-identity tests in `test_citation_gate/`. Estimated additional cost: 2-3 plans.

---

<objective>
Extend `services/backend/app/services/coach/citation_grammar.py`:
1. Add a paragraph explaining `tool_call_id` semantics in the doctrine header (one sentence after the closed-world paragraph).
2. Add one accepted-example block teaching the `{{cite:tool_<name>}}` placement.
3. Update `_INTENT_TO_CITATION_KEYS` to include the 6 `tool_<name>` keys in every intent bucket (always-on per RESEARCH §4.4).
4. Bump the existing `test_grammar_fragment_lists_all_18_registry_keys` test to expect 24 keys.
5. Unskip Plan 01's grammar tests.

The vocabulary-bullet list rebuilds automatically from `CITATION_REGISTRY` at module-import time (per `citation_grammar.py:97`), so adding 6 keys in Plan 02 auto-includes them in the fragment text. This plan only adds the explanatory paragraph + example block + intent mapping.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/wave-1b-citation-chips/wave-1b-CONTEXT.md
@.planning/phases/wave-1b-citation-chips/wave-1b-RESEARCH.md
@services/backend/app/services/coach/citation_grammar.py
@services/backend/app/services/coach/citation_registry.py

<interfaces>
Existing `_build_citation_grammar_fragment()` at citation_grammar.py:61-177 — pure function, sorts `CITATION_REGISTRY.keys()` alphabetically, emits one bullet per key.

Existing intent mapping at `citation_grammar.py:209-276` — `_INTENT_TO_CITATION_KEYS: Mapping[str, frozenset[str]]` with 6-7 buckets (debt / housing / family / career / retirement / taxes plus possibly default).

Verbatim insertion text (RESEARCH §4.4) — to append IMMEDIATELY AFTER the existing closed-world paragraph:
```
Certaines clés (`tool_*`) marquent un chiffre calculé côté serveur — son `inputs_hash` voyage avec la réponse, tu n'as pas besoin de le citer dans le texte. Place simplement la clé `{{cite:tool_<nom>}}` après le chiffre, comme pour les autres clés du vocabulaire fermé.
```

Verbatim example block (RESEARCH §4.4):
```
**ACCEPTÉ — chiffre calculé côté serveur** :
L'outil `get_budget_status` renvoie un surplus mensuel de 1'234 CHF. Tu peux répondre : « Selon ton dernier instantané, ton surplus mensuel pourrait être autour de 1'234 CHF {{cite:tool_budget_snapshot}}. La garde reconnaît la clé `tool_*` et lie automatiquement le chiffre à l'`inputs_hash` du calcul. »
```

Banned terms verification on both blocks:
- "calculé", "voyage", "place", "vocabulaire", "tu n'as pas besoin" — all OK
- "garantit", "optimal", "meilleur", "certain", "assuré", "parfait" — NONE present
- "pourrait" — used (LSFin-safe modal verb per CLAUDE.md TOP rule #1)

Accent verification:
- "côté", "calculé", "voyage", "réponse", "vocabulaire fermé", "Sélectionner" (none in text) — all 100% FR
- "ACCEPTÉ" — capital with accent OK in markdown header

Existing test name `test_grammar_fragment_lists_all_18_registry_keys` at citation_grammar.py:39 reference — concrete file location is `services/backend/tests/test_citation_gate/test_narrator_grammar_fragment.py` (per Phase 94.1 Plan 01 plan).
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Extend citation_grammar.py with tool_call_id paragraph + example + intent mapping</name>
  <read_first>
    - services/backend/app/services/coach/citation_grammar.py (FULL — read all 399 lines to understand existing structure, especially _build_citation_grammar_fragment, _INTENT_TO_CITATION_KEYS, build_intent_scoped_citation_grammar)
    - services/backend/tests/test_citation_gate/test_narrator_grammar_fragment.py (FULL — find test_grammar_fragment_lists_all_18_registry_keys)
    - services/backend/app/services/coach/citation_registry.py (CONFIRM the 6 tool_* keys are present after Plan 02 lands)
  </read_first>
  <files>
    - services/backend/app/services/coach/citation_grammar.py (modify)
    - services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py (modify — unskip)
    - services/backend/tests/test_citation_gate/test_narrator_grammar_fragment.py (modify — bump 18 → 24)
  </files>
  <behavior>
    After this plan:
    - `CITATION_GRAMMAR_FRAGMENT` contains "tool_*" + "inputs_hash" + "voyage avec la réponse" in the explanatory paragraph.
    - `CITATION_GRAMMAR_FRAGMENT` contains "ACCEPTÉ" + "tool_budget_snapshot" in the example block.
    - `CITATION_GRAMMAR_FRAGMENT` lists 24 bullets (auto-derived from CITATION_REGISTRY after Plan 02).
    - `build_intent_scoped_citation_grammar(("retirement",))` includes `tool_budget_snapshot` AND all 5 other tool_* keys (always-on).
    - `build_intent_scoped_citation_grammar(("taxes",))` includes the same 6 tool_* keys.
    - All Plan 01 stub tests in `test_tool_call_id_grammar.py` pass (skip markers removed).
  </behavior>
  <action>
    Step A — Edit `services/backend/app/services/coach/citation_grammar.py` `_build_citation_grammar_fragment()`. Locate the header text block (around lines 77-90 — the verbatim closed-world paragraph). IMMEDIATELY AFTER the closing `\n` of that header (so the new paragraph appears as a second header sub-section), insert the verbatim text from `<interfaces>`:

    Implementation pattern — add a `tool_paragraph` string concatenation to the function's header build:
    ```python
    tool_paragraph = (
        "\n"
        "Certaines clés (`tool_*`) marquent un chiffre calculé côté serveur "
        "— son `inputs_hash` voyage avec la réponse, tu n'as pas besoin de "
        "le citer dans le texte. Place simplement la clé "
        "`{{cite:tool_<nom>}}` après le chiffre, comme pour les autres clés "
        "du vocabulaire fermé.\n"
    )
    ```
    Concatenate `header + tool_paragraph + keys_section + ...` per existing build flow.

    Step B — In the same `_build_citation_grammar_fragment` function, find where examples are emitted (look for `**ACCEPTÉ**` or `**REJETÉ**` blocks if present, or the end of the function). Add ONE new accepted example block:
    ```python
    tool_example = (
        "\n"
        "**ACCEPTÉ — chiffre calculé côté serveur** :\n"
        "L'outil `get_budget_status` renvoie un surplus mensuel de "
        "1'234 CHF. Tu peux répondre : « Selon ton dernier instantané, "
        "ton surplus mensuel pourrait être autour de 1'234 CHF "
        "{{cite:tool_budget_snapshot}}. La garde reconnaît la clé "
        "`tool_*` et lie automatiquement le chiffre à l'`inputs_hash` "
        "du calcul. »\n"
    )
    ```
    Append to fragment after the existing example blocks (if any) or before return.

    Step C — Locate `_INTENT_TO_CITATION_KEYS` at `citation_grammar.py:209-276`. Add the 6 tool_* keys to EVERY intent bucket. Concrete diff pattern (apply to each frozenset):
    ```python
    _WAVE_1B_TOOL_KEYS_ALWAYS_ON = frozenset({
        "tool_budget_snapshot",
        "tool_retirement_projection",
        "tool_cross_pillar_analysis",
        "tool_couple_optimization",
        "tool_cap_status",
        "tool_retrieve_memories",
    })

    _INTENT_TO_CITATION_KEYS: Mapping[str, frozenset[str]] = MappingProxyType({
        "debt": frozenset({...existing debt keys...}) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
        "housing": frozenset({...existing housing keys...}) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
        "family": frozenset({...existing family keys...}) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
        "career": frozenset({...existing career keys...}) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
        "retirement": frozenset({...existing retirement keys...}) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
        "taxes": frozenset({...existing taxes keys...}) | _WAVE_1B_TOOL_KEYS_ALWAYS_ON,
        # If a "default" or "_ALWAYS_ON" bucket exists, also union with tool keys
    })
    ```

    Step D — Edit `services/backend/tests/test_citation_gate/test_narrator_grammar_fragment.py`. Find `test_grammar_fragment_lists_all_18_registry_keys`. Rename to `test_grammar_fragment_lists_all_24_registry_keys` (or keep the name but bump the magic number — pick what minimizes git noise — preferably bump the magic, update the docstring). Update assertion:
    ```python
    def test_grammar_fragment_lists_all_24_registry_keys():
        # Phase 94.1 baseline 18 keys; Wave 1b adds 6 tool_call_id keys = 24.
        assert len(CITATION_REGISTRY) == 24
        for key in CITATION_REGISTRY.keys():
            assert f"{{{{cite:{key}}}}}" in CITATION_GRAMMAR_FRAGMENT
    ```

    Step E — Remove skip markers from `services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py` (Plan 01's stubs). Verify the assertions are correct against the new fragment.

    Step F — Run `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py` — MUST exit 0.

    Step G — Run `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py` — MUST exit 0.

    Step H — Run `cd services/backend && python3 -m pytest tests/test_coach_citation/test_tool_call_id_grammar.py tests/test_citation_gate/test_narrator_grammar_fragment.py -q`. MUST exit 0.
  </action>
  <verify>
    <automated>cd services/backend &amp;&amp; python3 -m pytest tests/test_coach_citation/test_tool_call_id_grammar.py tests/test_citation_gate/test_narrator_grammar_fragment.py -q</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "tool_\\*\\|tool_<nom>\\|ACCEPTÉ — chiffre calculé côté serveur" services/backend/app/services/coach/citation_grammar.py` returns ≥2.
    - `grep -c "tool_budget_snapshot\\|tool_retirement_projection\\|tool_cross_pillar_analysis\\|tool_couple_optimization\\|tool_cap_status\\|tool_retrieve_memories" services/backend/app/services/coach/citation_grammar.py` returns ≥6 (all 6 tool keys present, at minimum in the always-on frozenset).
    - `grep -c "_WAVE_1B_TOOL_KEYS_ALWAYS_ON\\|WAVE_1B_TOOL_KEYS" services/backend/app/services/coach/citation_grammar.py` returns ≥1 (the always-on frozenset is defined).
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/citation_grammar.py` exits 0.
    - `python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/citation_grammar.py` exits 0.
    - `cd services/backend && python3 -c "from app.services.coach.citation_grammar import CITATION_GRAMMAR_FRAGMENT; print('tool_budget_snapshot' in CITATION_GRAMMAR_FRAGMENT)"` prints `True`.
    - `cd services/backend && python3 -c "from app.services.coach.citation_grammar import build_intent_scoped_citation_grammar; frag = build_intent_scoped_citation_grammar(('retirement',)); print('tool_cap_status' in frag)"` prints `True`.
    - `grep -c "@pytest.mark.skip" services/backend/tests/test_coach_citation/test_tool_call_id_grammar.py` returns 0 (Plan 03 unskips).
    - `cd services/backend && python3 -m pytest tests/test_coach_citation/test_tool_call_id_grammar.py -q` exits 0 with ≥3 PASSED.
    - `cd services/backend && python3 -m pytest tests/test_citation_gate/ -q | tail -1` confirms zero regressions.
  </acceptance_criteria>
  <done>
    Narrator grammar fragment teaches tool_call_id semantics; intent mapping is always-on for tool keys; 24-key assertion holds; Plan 01 stubs green.
  </done>
</task>

</tasks>

<threat_model>
| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-WAVE1B-03-01 | I | Grammar paragraph contains LSFin banned terms | mitigate | Step F runs `banned_terms_python.py`; verbatim text in `<interfaces>` was hand-verified in RESEARCH §4.4. |
| T-WAVE1B-03-02 | I | Grammar example uses "garanti" / "optimal" / "meilleur" — banned modal verbs | mitigate | Verbatim text uses "pourrait" (CLAUDE.md TOP rule #1 compliant). Lint enforces. |
| T-WAVE1B-03-03 | T | Intent-scoped grammar bloats narrator prompt past Sonnet context budget | accept | Per RESEARCH §A4: 6 keys × ~80 chars × 7 buckets = ~3.5 kB added to ~80 kB prompt = <5%. Negligible. |
| T-WAVE1B-03-04 | T | Test rename breaks downstream snapshot test | mitigate | Strategy: keep old test name (bump magic number 18 → 24 with updated docstring) to minimize Phase 94.1 byte-identity disruption. Acceptance criteria validates Phase 94 / 94.1 tests remain green. |
| T-WAVE1B-03-05 | T | 2-segment grammar deviation (Q5_DECISION) — Julien expected literal CONTEXT line 36 syntax | mitigate | Q5_DECISION block at top of plan surfaces deviation explicitly. Plan ships only if Julien doesn't object during exec start. |
</threat_model>

<verification>
- `cd services/backend && python3 -m pytest tests/test_coach_citation/test_tool_call_id_grammar.py tests/test_citation_gate/test_narrator_grammar_fragment.py -q` exits 0.
- `cd services/backend && python3 -m pytest tests/ -q | tail -3` confirms full pytest delta ≥ +3 vs Plan 02 baseline.
- Phase 94 byte-identity preserved: `pytest tests/test_citation_gate/ -q | tail -1` exits 0.
- Banned-terms + accent lints on `citation_grammar.py` exit 0.
</verification>

<success_criteria>
- Grammar fragment teaches `tool_<name>` 1-segment placement.
- Intent mapping is always-on for the 6 tool keys.
- Plan 01 grammar stubs (3+ tests) green.
- 18 → 24 key assertion holds at the test level.
- No regression in Phase 94 / 94.1 grammar tests.
- Q5_DECISION block surfaces the 1-segment grammar deviation.
</success_criteria>

<output>
After completion create `.planning/phases/wave-1b-citation-chips/wave-1b-03-SUMMARY.md` with:
- Diff size on `citation_grammar.py`
- Token count delta on the rendered grammar fragment (before vs after)
- Q5_DECISION outcome (whether Julien confirmed during exec or shipped as recommended)
- 0-trust self-check citing pytest output verbatim
</output>
