---
phase: mint-calc-engine-v1
plan: 08
wave: 2
title: W2 — 2 new bundles (IndependentTax + SuccessionDivorce) + _INTENT_BUNDLES audit
type: execute
depends_on: [01]
files_modified:
  - services/backend/app/services/coach/bundles/__init__.py
  - services/backend/app/services/coach/bundles/independent_tax_bundle.py
  - services/backend/app/services/coach/bundles/succession_divorce_bundle.py
  - services/backend/app/services/coach/bundle_compiler.py
  - services/backend/tests/bundles/test_independent_tax_bundle.py
  - services/backend/tests/bundles/test_succession_divorce_bundle.py
  - services/backend/tests/bundles/test_bundle_compiler.py
autonomous: true
requirements: [D-CE-03]
estimated_duration: 3
must_haves:
  truths:
    - "9 bundles total = 7 shipped + IndependentTaxBundle + SuccessionDivorceBundle"
    - "IndependentTaxBundle wired in `_INTENT_BUNDLES` for 'taxes' + 'career' intents ; SuccessionDivorceBundle wired in 'family'"
    - "Both new bundles declare allowed_tools + citation_allowlist + prompt_fragment with CC art. 122-124 / LAVS art. 29sexies / LIFD art. 33 references"
    - "`_INTENT_BUNDLES` audit pass complete — RESEARCH §Q-F + CONTEXT data-gap mitigation"
  artifacts:
    - path: services/backend/app/services/coach/bundles/independent_tax_bundle.py
      provides: "IndependentTaxBundle class with prompt_fragment + allowed_tools + citation_allowlist"
      min_lines: 35
    - path: services/backend/app/services/coach/bundles/succession_divorce_bundle.py
      provides: "SuccessionDivorceBundle class with CC art. 122-124 + 462 + 467-469 references"
      min_lines: 35
  key_links:
    - from: services/backend/app/services/coach/bundle_compiler.py
      to: services/backend/app/services/coach/bundles/independent_tax_bundle.py
      via: "import + _INTENT_BUNDLES + _DROP_PRIORITY registration"
      pattern: "IndependentTaxBundle"
---

<objective>
Add 2 evidence-gap bundles per D-CE-03 (Override #2). `IndependentTaxBundle` covers matrix domain 8 (Sàrl-vs-RI + dividende-vs-salaire — scaffolds coaching register even though calcs absent). `SuccessionDivorceBundle` adds CC art. 122-124 / 467-469 / LAVS art. 29sexies citation grammar to the existing succession+divorce calcs (domain 6+7).

Purpose: D-CE-03. Bring bundle count from 7 to 9. Single-iteration audit of `_INTENT_BUNDLES` mapping at bundle_compiler.py:45-52 (CONTEXT data gap).

Output: 2 new bundle modules + bundle_compiler.py patches + 3 test files.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@services/backend/app/services/coach/bundle_compiler.py
@services/backend/app/services/coach/bundles/_base.py
@services/backend/app/services/coach/bundles/tax_explainer.py
@docs/AGENTS/swiss-brain.md
</context>

<interfaces>
<!-- Per RESEARCH §Q-F lines 856-963 — verified pattern in services/backend/app/services/coach/bundles/_base.py -->

```python
# _base.py contract
class BundleBase(BaseModel):
    model_config = ConfigDict(frozen=True, extra="forbid")
    name: str
    prompt_fragment: str
    allowed_tools: list[str]
    citation_allowlist: list[str]
```

bundle_compiler.py current state (verified):
- _INTENT_BUNDLES dict lines 45-52 (6 intents × list[BundleClass])
- _ALWAYS_ON list lines 58-61
- _DROP_PRIORITY list lines 65-70 (right-to-left dropping under _TOKEN_BUDGET = 8000)
- _DROP_PRIORITY ∩ _ALWAYS_ON == set() assert lines 76-78
</interfaces>

<tasks>

<task id="W2-02-00" type="auto" tdd="false">
  <name>Task 0: `_INTENT_BUNDLES` audit pass (CONTEXT data-gap mitigation)</name>
  <files>(read-only)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Data gaps line 39 (« Did NOT audit `bundle_compiler.py:_INTENT_BUNDLES` mapping for current correctness »)
    - services/backend/app/services/coach/bundle_compiler.py:29-92 (current shipped state)
    - services/backend/app/services/coach/bundles/_base.py
    - services/backend/app/services/coach/bundles/*.py (all 7 shipped bundles)
    - services/backend/app/api/v1/endpoints/coach_chat.py:1500-1565 (_INTENT_KEYWORDS for intent classifier reference)
  </read_first>
  <action>
    Audit the current `_INTENT_BUNDLES` mapping. For each of the 6 canonical intents (retirement / taxes / housing / debt / family / career), list:
    1. Which bundles currently mapped (read from bundle_compiler.py:45-52)
    2. Is the mapping coherent given the bundle's `allowed_tools` + `prompt_fragment` content?
    3. Are there gaps (intent X needs bundle Y but Y not mapped)?

    Record findings in this plan's SUMMARY.md as a 6-row table:
    | Intent | Current bundles | Audit verdict | Action |

    If gap found (e.g. 'housing' missing `MortgageStressorBundle`), document in SUMMARY but DO NOT modify mapping in this plan — surfaces as follow-up TODO. Only the 2 NEW bundles (IndependentTax + SuccessionDivorce) get wired here.

    Per D-CE-20 deepening: also spot-check ≥3 bundle classes for `frozen=True + extra="forbid"` invariant (`_base.py` enforces but per-class can override).
  </action>
  <verify>
    <automated>grep -c "_INTENT_BUNDLES" services/backend/app/services/coach/bundle_compiler.py</automated>
  </verify>
  <acceptance_criteria>
    - 6-row audit table in SUMMARY.md
    - 0 invariant violations in spot-check (all bundle classes inherit frozen+extra=forbid from _base)
    - Follow-up gaps surfaced as TODOs (not patched in this plan)
  </acceptance_criteria>
  <done>Audit done, scope locked to 2 new bundles only</done>
</task>

<task id="W2-02-01" type="auto" tdd="true">
  <name>Task 1: IndependentTaxBundle</name>
  <files>services/backend/app/services/coach/bundles/independent_tax_bundle.py, services/backend/app/services/coach/bundles/__init__.py, services/backend/tests/bundles/test_independent_tax_bundle.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-F (lines 876-913 — verbatim shape)
    - services/backend/app/services/coach/bundles/tax_explainer.py (existing similar bundle — pattern precedent)
    - services/backend/app/services/coach/bundles/_base.py
    - docs/AGENTS/swiss-brain.md (LAVS art. 8 + LIFD art. 33 + LPP art. 4 wording)
  </read_first>
  <behavior>
    - Test 1: `IndependentTaxBundle()` constructs (frozen+extra=forbid satisfied).
    - Test 2: `prompt_fragment` contains « indépendant », « Sàrl », « LAVS art. 8 », « LPP art. 4 », « LIFD art. 33 ».
    - Test 3: `allowed_tools` is non-empty list (e.g. `["avs_cotisations_independants", "pillar_3a_indep", "lpp_volontaire", "ijm_service"]`).
    - Test 4: `citation_allowlist` matches `tool_<name>` convention (e.g. `["tool_avs_cotisations_independants", ...]`).
    - Test 5: `prompt_fragment` accent FR clean (« indépendant », « éducatif », « équivalent »).
    - Test 6: No banned LSFin terms.
  </behavior>
  <action>
    Implement per RESEARCH §Q-F lines 876-913. Append to `services/backend/app/services/coach/bundles/__init__.py`:
    ```python
    from app.services.coach.bundles.independent_tax_bundle import IndependentTaxBundle
    ```
    Add to `__all__` list.

    Bundle content (verbatim FR, LSFin-safe):
    ```python
    class IndependentTaxBundle(BundleBase):
        def __init__(self) -> None:
            super().__init__(
                name="independent-tax",
                prompt_fragment=(
                    "## Indépendant / Sàrl\n"
                    "Si l'utilisatrice ou l'utilisateur évoque son statut indépendant, sa Sàrl, "
                    "ou un arbitrage dividende-vs-salaire, garde le registre éducatif. "
                    "Cite LAVS art. 8 (cotisations indépendant), LPP art. 4 (LPP volontaire), "
                    "LIFD art. 33 al. 1 let. d (déductions 3a + LPP rachat).\n\n"
                    "Outils disponibles : `avs_cotisations_independants`, `pillar_3a_indep`, "
                    "`lpp_volontaire`, `ijm_service`.\n"
                ),
                allowed_tools=[
                    "avs_cotisations_independants",
                    "pillar_3a_indep",
                    "lpp_volontaire",
                    "ijm_service",
                ],
                citation_allowlist=[
                    "tool_avs_cotisations_independants",
                    "tool_pillar_3a_indep",
                    "tool_lpp_volontaire",
                    "tool_ijm_service",
                ],
            )
    ```

    6 tests in `test_independent_tax_bundle.py` mirror Concern A criteria.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/bundles/test_independent_tax_bundle.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - File ≥35 lines
    - `grep -c "LAVS art. 8\|LPP art. 4\|LIFD art. 33" services/backend/app/services/coach/bundles/independent_tax_bundle.py` returns ≥3
    - 6 tests green
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/bundles/independent_tax_bundle.py` exits 0
    - `python3 tools/checks/accent_lint_fr.py --scope backend 2>&1 | grep independent_tax | grep -i error` returns 0
  </acceptance_criteria>
  <done>IndependentTaxBundle shipped</done>
</task>

<task id="W2-02-02" type="auto" tdd="true">
  <name>Task 2: SuccessionDivorceBundle</name>
  <files>services/backend/app/services/coach/bundles/succession_divorce_bundle.py, services/backend/app/services/coach/bundles/__init__.py, services/backend/tests/bundles/test_succession_divorce_bundle.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-F line 915-923
    - services/backend/app/services/coach/bundles/_base.py
    - docs/AGENTS/swiss-brain.md (CC art. 122-124, 462, 467-469 + LAVS art. 29sexies wording)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §D-CE-03
  </read_first>
  <behavior>
    - Test 1: `SuccessionDivorceBundle()` constructs.
    - Test 2: `prompt_fragment` contains « divorce », « succession », « CC art. 122-124 », « CC art. 462 », « CC art. 467-469 », « LAVS art. 29sexies ».
    - Test 3: `allowed_tools` includes `["divorce_simulator", "succession_simulator", "concubinage_succession"]`.
    - Test 4: `citation_allowlist` matches convention.
    - Test 5: accent FR clean.
    - Test 6: No banned LSFin terms.
  </behavior>
  <action>
    ```python
    class SuccessionDivorceBundle(BundleBase):
        def __init__(self) -> None:
            super().__init__(
                name="succession-divorce",
                prompt_fragment=(
                    "## Succession et divorce\n"
                    "Si l'utilisatrice ou l'utilisateur évoque un divorce, une séparation, "
                    "un décès ou une succession, garde le registre éducatif et factuel. "
                    "Cite CC art. 122-124 (partage LPP en cas de divorce), "
                    "CC art. 462 (droit du conjoint survivant), "
                    "CC art. 467-469 (réserves héréditaires), "
                    "LAVS art. 29sexies (splitting AVS).\n\n"
                    "Outils disponibles : `divorce_simulator`, `succession_simulator`, "
                    "`concubinage_succession`.\n"
                ),
                allowed_tools=[
                    "divorce_simulator",
                    "succession_simulator",
                    "concubinage_succession",
                ],
                citation_allowlist=[
                    "tool_divorce_simulator",
                    "tool_succession_simulator",
                    "tool_concubinage_succession",
                ],
            )
    ```

    6 tests.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/bundles/test_succession_divorce_bundle.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "CC art." services/backend/app/services/coach/bundles/succession_divorce_bundle.py` returns ≥3
    - `grep -c "LAVS art. 29sexies" services/backend/app/services/coach/bundles/succession_divorce_bundle.py` returns ≥1
    - 6 tests green
    - Lint clean
  </acceptance_criteria>
  <done>SuccessionDivorceBundle shipped</done>
</task>

<task id="W2-02-03" type="auto" tdd="true">
  <name>Task 3: bundle_compiler.py wire 2 new bundles + _DROP_PRIORITY</name>
  <files>services/backend/app/services/coach/bundle_compiler.py, services/backend/tests/bundles/test_bundle_compiler.py</files>
  <read_first>
    - services/backend/app/services/coach/bundle_compiler.py (full file)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-F lines 925-955
  </read_first>
  <behavior>
    - Test 1: `_INTENT_BUNDLES["taxes"]` includes `IndependentTaxBundle` and `TaxExplainerBundle` and `Pillar3aOptimizerBundle`.
    - Test 2: `_INTENT_BUNDLES["family"]` includes `SuccessionDivorceBundle` + `LifeEventRouterBundle` + `ComplianceNarratorBundle`.
    - Test 3: `_INTENT_BUNDLES["career"]` includes `IndependentTaxBundle`.
    - Test 4: `_DROP_PRIORITY` lists IndependentTaxBundle FIRST then SuccessionDivorceBundle SECOND (new bundles drop first).
    - Test 5: `_DROP_PRIORITY ∩ _ALWAYS_ON == set()` (existing invariant preserved at module-import-time).
    - Test 6: `compile_bundles(["family"], ...)` returns a CompiledBundle whose `allowed_tools` contains `divorce_simulator` (proves wire-up works end-to-end).
  </behavior>
  <action>
    Edit `bundle_compiler.py`. Surgical changes:

    1. Add imports at top:
       ```python
       from app.services.coach.bundles import IndependentTaxBundle, SuccessionDivorceBundle
       ```

    2. Update `_INTENT_BUNDLES` (preserve existing entries):
       ```python
       _INTENT_BUNDLES = {
           "retirement": [Pillar3aOptimizerBundle, LppProjectorBundle],
           "taxes":      [TaxExplainerBundle, Pillar3aOptimizerBundle, IndependentTaxBundle],
           "housing":    [MortgageStressorBundle, TaxExplainerBundle],
           "debt":       [MortgageStressorBundle, ComplianceNarratorBundle],
           "family":     [LifeEventRouterBundle, ComplianceNarratorBundle, SuccessionDivorceBundle],
           "career":     [LppProjectorBundle, LifeEventRouterBundle, IndependentTaxBundle],
       }
       ```

    3. Update `_DROP_PRIORITY` (NEW bundles drop first under budget pressure — D-CE-03 + RESEARCH §Q-F line 946-953):
       ```python
       _DROP_PRIORITY = [
           IndependentTaxBundle,       # NEW — drop first
           SuccessionDivorceBundle,    # NEW — drop second
           MortgageStressorBundle,
           TaxExplainerBundle,
           LppProjectorBundle,
           Pillar3aOptimizerBundle,
       ]
       ```

    4. Verify the assert at lines 76-78 still passes (`_DROP_PRIORITY ∩ _ALWAYS_ON == set()`).

    Update test_bundle_compiler.py (extend existing tests, do NOT rewrite). Add 6 tests from `<behavior>`.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/bundles/test_bundle_compiler.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "IndependentTaxBundle" services/backend/app/services/coach/bundle_compiler.py` returns ≥3 (import + _INTENT_BUNDLES + _DROP_PRIORITY)
    - `grep -c "SuccessionDivorceBundle" services/backend/app/services/coach/bundle_compiler.py` returns ≥3
    - 6 tests green
    - `python3 -c "from app.services.coach.bundle_compiler import _DROP_PRIORITY, _ALWAYS_ON; assert set(_DROP_PRIORITY) & set(_ALWAYS_ON) == set()"` exits 0
  </acceptance_criteria>
  <done>9 bundles wired, _INTENT_BUNDLES correct, full suite green</done>
</task>

<task id="W2-02-99" type="auto" tdd="false">
  <name>Task 4: Full suite + engram</name>
  <files>(verification + engram)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Memory Contract
  </read_first>
  <action>
    Full suite + lints. Engram save:
    - `topic_key: calc_engine:w2:bundles_v2_9_total`
    - `type: architecture`
    - `prior_finding_refs: [bundle_compiler.py 7-bundle obs from #103 panel synthesis Override #2, Plan 04 obs (L4 wedge), W2-01 adapter Plan obs]`
    - Content: « 9 bundles total. 2 new : IndependentTaxBundle (LAVS art. 8 + LPP art. 4 + LIFD art. 33) wired in `taxes`+`career` intents ; SuccessionDivorceBundle (CC art. 122-124 + 462 + 467-469 + LAVS art. 29sexies) wired in `family`. New bundles drop first under _TOKEN_BUDGET pressure (right-most in _DROP_PRIORITY). _INTENT_BUNDLES audit done — no current-state gaps to patch in W2 ; follow-up TODOs surfaced in SUMMARY. »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite green
    - Engram observation saved
    - SUMMARY contains _INTENT_BUNDLES audit table + follow-up TODOs
  </acceptance_criteria>
  <done>9-bundle state shipped, ready for W2-03 tool description rewrites</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-08-01 | LSFin compliance | new bundle prompt_fragments | mitigate | Both prompt_fragments use registre éducatif vocabulary. Legal article references are FACTUAL not promissory. banned_terms_python.py lint runs. |
| T-mint-calc-08-02 | Tampering | _DROP_PRIORITY reorder | mitigate | Module-import-time assert at lines 76-78 enforces `∩ _ALWAYS_ON == set()` invariant. Test 5 explicitly. |
| T-mint-calc-08-03 | Information disclosure | citation_allowlist | accept | Lists tool names + tool_<name> citation keys. No user data. |
| T-mint-calc-08-04 | DoS | _TOKEN_BUDGET overflow | mitigate | _DROP_PRIORITY drops NEW bundles first. If both new bundles trim and budget still exceeded, existing drop chain kicks in. Per RESEARCH §Q-F. |
</threat_model>

<success_criteria>
- 9 bundles total (7 shipped + 2 new)
- _INTENT_BUNDLES audit table in SUMMARY
- Legal article references verified (CC + LAVS + LIFD + LPP)
- Full suite green
- Engram observation linking #103 + Plan 04 + Plan 07
</success_criteria>

<risks>
- **Tool name mismatch.** `IndependentTaxBundle.allowed_tools = ["avs_cotisations_independants", ...]` MUST match the names in `services/backend/app/calculators/_registry.py` (Plan 05). If the AST scanner produced different names, update the bundle list. Test 6 catches it.
- **Token budget pressure.** Adding 2 bundles to `_DROP_PRIORITY` may cause earlier drops at TOKEN_BUDGET=8000. Verify existing test `test_bundle_compiler.py::test_compile_under_budget` (if exists) still passes.
- **_INTENT_BUNDLES audit may surface real gaps.** Plan instructions say « document, don't patch ». If audit finds 'housing' missing critical bundle (e.g. life_event_router), surface as P1 follow-up. Do NOT scope-creep this plan.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-08-w2-bundles-SUMMARY.md` including audit table + follow-up TODOs + engram obs_id.
</output>
