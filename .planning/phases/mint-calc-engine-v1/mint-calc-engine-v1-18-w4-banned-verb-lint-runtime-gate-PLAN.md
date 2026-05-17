---
phase: mint-calc-engine-v1
plan: 18
wave: 4
title: W4 — Banned-verb lint extension + runtime gate (D-CE-16 triple defense layers b+c)
type: execute
depends_on: [01, 04]
files_modified:
  - tools/checks/banned_terms_python.py
  - services/backend/app/services/coach/runtime_verb_gate.py
  - services/backend/app/api/v1/endpoints/coach_chat.py
  - services/backend/tests/test_runtime_banned_verb_gate.py
  - tools/checks/tests/test_paraphrase_verbs.py
autonomous: false
requirements: [D-CE-16]
estimated_duration: 4
must_haves:
  truths:
    - "banned_terms_python.py extended with 11 paraphrase verbs (D-CE-16(b))"
    - "Runtime verb gate at `services/backend/app/services/coach/runtime_verb_gate.py` (D-CE-16(c))"
    - "Gate runs NFKC normalization + zero-width-char strip BEFORE regex match"
    - "Gate placed BEFORE Phase 94 citation gate (per Q5 resolution: catch ranking words before citation substitution)"
    - "Match → template fallback (« je n'ai pas cette donnée pour l'instant »)"
  artifacts:
    - path: tools/checks/banned_terms_python.py
      provides: "Extended BANNED_TERMS list with 11 paraphrase verbs"
      contains: "le plus pertinent\\|plus avantageux\\|nettement plus\\|clairement supérieur\\|mon conseil"
    - path: services/backend/app/services/coach/runtime_verb_gate.py
      provides: "gate(text) -> tuple[bool, str] — returns (passed, sanitized_or_fallback)"
      min_lines: 60
  key_links:
    - from: services/backend/app/services/coach/runtime_verb_gate.py
      to: services/backend/app/api/v1/endpoints/coach_chat.py
      via: "narrator post-processing — runs gate BEFORE citation parser"
      pattern: "runtime_verb_gate"
---

<objective>
Ship D-CE-16 triple-defense layers (b) lint-time and (c) runtime fail-closed. Together with D-CE-15 schema-impossibility (Plan 04 layer a), the 3-defense system structurally prevents ranking creep at narrator output.

Purpose: D-CE-16. Lexical guardrails alone have 40-80% false-negative on paraphrase (arXiv 2504.11168, RESEARCH cited). Schema + lint + runtime = redundant defense.

**Q5 resolution**: gate runs BEFORE Phase 94 citation gate. Rationale: catch ranking words before citation substitution to avoid double-template fallback chains.

Output: lint extension + runtime gate + 2 test files. **Requires Julien GO on Q5 placement (default Q5 fallback: BEFORE).**
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md
@tools/checks/banned_terms_python.py
@services/backend/app/services/coach/citation_parser.py
@services/backend/app/api/v1/endpoints/coach_chat.py
@docs/AGENTS/swiss-brain.md
</context>

<interfaces>
<!-- 11 paraphrase verbs per D-CE-16(b) verbatim from CONTEXT.md §decisions D-CE-16: -->

```python
BANNED_PARAPHRASE_VERBS = [
    "le choix le plus avisé",
    "le plus pertinent",
    "plus avantageux que",
    "nettement plus",
    "clairement supérieur",
    "à mon avis",
    "je pense que tu",
    "mon conseil serait",
    "tu devrais",
    "il faut",
    "recommandé",
]
```

Existing BANNED_TERMS (CLAUDE.md §1) — base list:
```
garanti, optimal, meilleur, certain, assuré, sans risque, parfait
```

Runtime gate (D-CE-16(c)) — RESEARCH §Q-C reference:
```python
def gate(text: str) -> tuple[bool, str]:
    # NFKC normalize + strip zero-width chars
    normalized = unicodedata.normalize("NFKC", text)
    cleaned = "".join(c for c in normalized if not _is_zero_width(c))
    for verb in ALL_BANNED:
        if re.search(rf"\b{re.escape(verb)}\b", cleaned, re.IGNORECASE):
            return False, "Je n'ai pas cette donnée pour l'instant."
    return True, text
```
</interfaces>

<tasks>

<task id="W4-02-00" type="checkpoint:decision" gate="blocking">
  <decision>Q5: Runtime banned-verb gate placement (BEFORE vs AFTER Phase 94 citation gate)</decision>
  <context>
    VALIDATION.md default: BEFORE (catch ranking words BEFORE citation substitution to avoid double-template fallback).

    BEFORE pros: catches « le plus pertinent » BEFORE Phase 94 substitutes `{{cite:tool_X}}` placeholders. AFTER would let phase 94 substitute first, then re-run gate on substituted text.
    AFTER pros: works on the FINAL emitted text (post-citation). May catch banned verbs in citation key names (unlikely).
  </context>
  <options>
    <option id="before">
      <name>BEFORE Phase 94 citation gate (VALIDATION.md default)</name>
      <pros>Catches paraphrase BEFORE retry chain ; simpler fallback path</pros>
      <cons>None significant</cons>
    </option>
    <option id="after">
      <name>AFTER Phase 94 citation gate</name>
      <pros>Works on final substituted text</pros>
      <cons>Double-fallback risk: gate fails → templated fallback ≠ Phase 94's templated fallback. Confusing UX.</cons>
    </option>
  </options>
  <resume-signal>Reply with: "before" or "after"</resume-signal>
</task>

<task id="W4-02-01" type="auto" tdd="true">
  <name>Task 1: banned_terms_python.py extension (D-CE-16 layer b)</name>
  <files>tools/checks/banned_terms_python.py, tools/checks/tests/test_paraphrase_verbs.py</files>
  <read_first>
    - tools/checks/banned_terms_python.py (current state — base 7 banned terms)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §D-CE-16
    - docs/AGENTS/swiss-brain.md (LSFin grammar)
  </read_first>
  <behavior>
    - Test 1: After extension, `BANNED_TERMS` contains 11 new paraphrase verbs.
    - Test 2: Lint a sample Python file containing « le plus pertinent » → exit 1 with file:line match.
    - Test 3: Lint a sample file containing « pourrait » / « envisager » → exit 0 (those are SAFE).
    - Test 4: Original 7 terms still flagged.
    - Test 5: NFKC normalization applied to lint input (the « lint » side ; runtime gate is Task 2).
  </behavior>
  <action>
    EXTEND (append, do NOT replace) `tools/checks/banned_terms_python.py` BANNED_TERMS:

    ```python
    # tools/checks/banned_terms_python.py — EXTEND with D-CE-16(b) paraphrase verbs
    BANNED_PARAPHRASE_VERBS = [
        "le choix le plus avisé",
        "le plus pertinent",
        "plus avantageux que",
        "nettement plus",
        "clairement supérieur",
        "à mon avis",
        "je pense que tu",
        "mon conseil serait",
        "tu devrais",
        "il faut",
        "recommandé",
    ]

    BANNED_TERMS = [
        # CLAUDE.md §1 base list
        "garanti", "optimal", "meilleur", "certain", "assuré", "sans risque", "parfait",
        # D-CE-16(b) paraphrase verbs (Phase mint-calc-engine-v1 W4)
        *BANNED_PARAPHRASE_VERBS,
    ]
    ```

    5 tests in `tools/checks/tests/test_paraphrase_verbs.py`.
  </action>
  <verify>
    <automated>python3 tools/checks/tests/test_paraphrase_verbs.py 2>&1 | tail -5 ; python3 -c "from tools.checks.banned_terms_python import BANNED_TERMS; assert 'le plus pertinent' in BANNED_TERMS; print('OK')"</automated>
  </verify>
  <acceptance_criteria>
    - `python3 -c "from tools.checks.banned_terms_python import BANNED_TERMS; print(len(BANNED_TERMS))"` returns ≥18 (7 base + 11 paraphrase)
    - 5 tests green
    - `grep -c "le plus pertinent\|plus avantageux\|nettement plus\|clairement supérieur\|mon conseil" tools/checks/banned_terms_python.py` returns ≥5
    - Existing lint usage (pre-commit, CI) still works on existing files
  </acceptance_criteria>
  <done>Lint extended</done>
</task>

<task id="W4-02-02" type="auto" tdd="true">
  <name>Task 2: runtime_verb_gate.py (D-CE-16 layer c)</name>
  <files>services/backend/app/services/coach/runtime_verb_gate.py, services/backend/tests/test_runtime_banned_verb_gate.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §D-CE-16(c)
    - tools/checks/banned_terms_python.py (just extended)
    - services/backend/app/services/coach/citation_parser.py (Phase 94 pattern — fallback template precedent)
  </read_first>
  <behavior>
    - Test 1: `gate("Tu pourrais envisager X CHF")` returns `(True, "Tu pourrais envisager X CHF")`.
    - Test 2: `gate("Tu devrais investir 7000 CHF")` returns `(False, "Je n'ai pas cette donnée pour l'instant.")`.
    - Test 3: `gate("Le scénario optimal est A")` returns `(False, fallback)`.
    - Test 4 (NFKC normalization): `gate("Le scénario °optimal° est A")` (degree signs) — banned verb detected after NFKC normalize.
    - Test 5 (zero-width evasion attempt): `gate("opti​mal")` — zero-width space stripped, « optimal » detected.
    - Test 6 (case insensitive): `gate("OPTIMAL")` returns `(False, ...)`.
    - Test 7: Returns SAME template fallback string ALWAYS (consistent UX with Phase 94 fallback).
  </behavior>
  <action>
    ```python
    # services/backend/app/services/coach/runtime_verb_gate.py
    """Phase mint-calc-engine-v1 W4 — D-CE-16(c) runtime banned-verb gate.

    Fail-closed gate: NFKC normalize + strip zero-width chars + regex match.
    Per RESEARCH cited Palo Alto Unit 42 + arXiv 2504.11168 + 2512.01353 :
      - Lexical guardrails have 40-80% false-negative on paraphrase
      - 100% evasion via character injection
    Schema-impossibility (D-CE-15) closes structural ranking ; this gate closes free-text emission.
    """
    import re
    import unicodedata

    from tools.checks.banned_terms_python import BANNED_TERMS

    _FALLBACK_FR = "Je n'ai pas cette donnée pour l'instant."

    _ZERO_WIDTH_CHARS = {
        "​",   # ZERO WIDTH SPACE
        "‌",   # ZERO WIDTH NON-JOINER
        "‍",   # ZERO WIDTH JOINER
        "﻿",   # ZERO WIDTH NO-BREAK SPACE
        "⁠",   # WORD JOINER
    }


    def _strip_zero_width(s: str) -> str:
        return "".join(c for c in s if c not in _ZERO_WIDTH_CHARS)


    def gate(text: str) -> tuple[bool, str]:
        """D-CE-16(c) fail-closed gate.

        Returns (passed: bool, sanitized_or_fallback: str).
        - passed=True : original text returned unchanged
        - passed=False : templated fallback returned (LSFin-safe, sibling to Phase 94)
        """
        # NFKC normalize + strip zero-width
        normalized = unicodedata.normalize("NFKC", text)
        cleaned = _strip_zero_width(normalized)

        for term in BANNED_TERMS:
            # Word-boundary match, case-insensitive
            pattern = rf"\b{re.escape(term)}\b"
            if re.search(pattern, cleaned, re.IGNORECASE):
                return (False, _FALLBACK_FR)
        return (True, text)
    ```

    7 tests including NFKC + zero-width.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_runtime_banned_verb_gate.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 7 tests green
    - `grep -c "unicodedata.normalize" services/backend/app/services/coach/runtime_verb_gate.py` returns ≥1
    - `grep -c "_ZERO_WIDTH_CHARS\|_strip_zero_width" services/backend/app/services/coach/runtime_verb_gate.py` returns ≥2
    - Lint clean: `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/runtime_verb_gate.py` exits 0 (gate's _FALLBACK_FR is safe wording)
  </acceptance_criteria>
  <done>Runtime gate live</done>
</task>

<task id="W4-02-03" type="auto" tdd="true">
  <name>Task 3: Wire gate into coach_chat.py BEFORE/AFTER citation gate (per Q5 resolution)</name>
  <files>services/backend/app/api/v1/endpoints/coach_chat.py</files>
  <read_first>
    - services/backend/app/api/v1/endpoints/coach_chat.py (find `_run_narrator_with_gate` ~line 4173)
    - services/backend/app/services/coach/citation_parser.py
    - services/backend/app/services/coach/runtime_verb_gate.py
  </read_first>
  <behavior>
    - Test 1: Narrator emits « tu devrais investir 7000 CHF » → gate fails → fallback template returned.
    - Test 2: Narrator emits « tu pourrais envisager 7000 CHF avec {{cite:tool_pillar3a}} » → gate passes → Phase 94 substitution proceeds.
    - Test 3 (Q5 placement = before): gate runs first; if pass, citation gate runs. Sentry breadcrumb emitted on gate failure with `verb_gate.fired=true`.
  </behavior>
  <action>
    In `coach_chat.py` (`_run_narrator_with_gate` wrapper), insert verb gate call:

    **If Q5 = before:**
    ```python
    # Existing flow (Phase 94):
    #   narrator_output -> citation_parser.gate(...) -> retry-or-fallback

    # NEW (W4-02, per Q5=before):
    from app.services.coach.runtime_verb_gate import gate as runtime_verb_gate

    def _run_narrator_with_gate(...) -> ...:
        # ... existing narrator call ...
        narrator_text = narrator_output["content"]

        # NEW — D-CE-16(c) runtime gate BEFORE citation gate
        passed, gated_text = runtime_verb_gate(narrator_text)
        if not passed:
            emit_coach_breadcrumb(category="coach.verb_gate.fired", ...)
            return {"content": gated_text, ...}  # short-circuit, skip citation gate

        # Continue to existing Phase 94 citation gate
        citation_verdict, citation_text = citation_parser_gate(gated_text)
        ...
    ```

    **If Q5 = after:** invert ordering (gate runs on citation-substituted text).

    Surgical addition — preserve all existing logic. Phase 94 byte-identity tests must STILL pass (verify with `pytest tests/test_citation_gate/ -q`).
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_runtime_banned_verb_gate.py tests/test_citation_gate/ -q 2>&1 | tail -5</automated>
  </verify>
  <acceptance_criteria>
    - 3 integration tests green
    - Phase 94 byte-identity tests STILL green (no regression)
    - `grep -c "runtime_verb_gate" services/backend/app/api/v1/endpoints/coach_chat.py` returns ≥1
  </acceptance_criteria>
  <done>Gate wired</done>
</task>

<task id="W4-02-99" type="auto" tdd="false">
  <name>Task 4: Full suite + engram + Q5 resolution</name>
  <files>(verification + engram)</files>
  <action>
    Engram save:
    - `topic_key: calc_engine:w4:banned_verb_triple_defense`
    - `type: bugfix`
    - `prior_finding_refs: [Plan 04 obs (schema impossibility), #103 panel synthesis D-CE-16, Phase 94 citation gate Plan obs]`
    - Content: « D-CE-16 triple-defense complete: (a) schema-impossibility (Plan 04), (b) lint extension (this plan, +11 paraphrase verbs), (c) runtime gate with NFKC + zero-width stripping. Q5 resolved: gate placement = <before|after>. Sentry breadcrumb on fire. _FALLBACK_FR consistent with Phase 94. »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite green
    - Engram saved
  </acceptance_criteria>
  <done>W4-02 closed</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-18-01 | LSFin compliance | banned verb leak via paraphrase | mitigate | 11-verb extension + NFKC + zero-width strip + word-boundary regex closes all known evasion vectors per cited research. |
| T-mint-calc-18-02 | DoS | regex pathological input | mitigate | All regexes use `\b` + `re.escape` → linear time. No nested groups, no backtracking traps. |
| T-mint-calc-18-03 | Tampering | NFKC bypass | mitigate | NFKC normalize before match. Test 4 explicit. |
| T-mint-calc-18-04 | Information disclosure | gate firing reveals model output | accept | Sentry breadcrumb logs `verb_gate.fired` flag only ; no narrator text in breadcrumb (PII-safe). |
| T-mint-calc-18-05 | Repudiation | gate fired audit trail | mitigate | Sentry breadcrumb records every fire ; queryable by category=`coach.verb_gate.fired`. |
</threat_model>

<success_criteria>
- 11 paraphrase verbs added to BANNED_TERMS
- runtime_verb_gate with NFKC + zero-width strip
- Wired into coach_chat.py with Q5 resolution
- ≥15 tests green
- Phase 94 byte-identity preserved
- Engram observation persisted
</success_criteria>

<risks>
- **Q5 decision blocks plan.** `autonomous: false` per gate placement requiring operator review.
- **False positives on legitimate FR.** « il faut » is in the banned list but very common in FR. May fire on legitimate narrator output. Document follow-up: « monitor `coach.verb_gate.fired` over 1 week ; if firing rate > 5%, tune list or add context-aware exceptions. »
- **NFKC may not catch all character injection.** arXiv 2512.01353 lists 100% evasion vectors. Triple defense (schema + lint + runtime) mitigates ; no single layer is perfect.
- **Phase 94 byte-identity tests.** ANY regression in `tests/test_citation_gate/` BLOCKS this plan ship. Verify with explicit test run.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-18-w4-banned-verb-lint-runtime-gate-SUMMARY.md` including Q5 resolution + monitoring TODO.
</output>
