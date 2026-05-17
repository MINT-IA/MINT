---
phase: mint-calc-engine-v1
plan: 09
wave: 2
title: W2 — Tool description rubric + FR keyword rewrite + Tool Search round-trip fixture (Concern A)
type: execute
depends_on: [07, 08]
files_modified:
  - tools/checks/tool_description_rubric.py
  - services/backend/app/services/coach/coach_tools.py
  - services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py
  - services/backend/tests/test_tool_search_round_trip.py
  - tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml
autonomous: false
requirements: [D-CE-01, Concern-A]
estimated_duration: 6
must_haves:
  truths:
    - "Tool description rubric lint live at `tools/checks/tool_description_rubric.py` (exit 1 if any tool description lacks FR keywords)"
    - "All 5 chip-emitter descriptions rewritten + ≥30 long-tail descriptions rewritten with FR keyword discipline + legal article references"
    - "Round-trip fixture: 30 FR user messages → expected tool in top-3 (mocked Anthropic Tool Search BM25)"
    - "Maestro G1 flow `coach_tool_search_round_trip.yaml` walks 5 representative FR queries on sim — checkpoint for Julien G2 staging pilot"
  artifacts:
    - path: tools/checks/tool_description_rubric.py
      provides: "Lint scanning tool descriptions for FR keyword discipline"
      min_lines: 60
    - path: services/backend/tests/test_tool_search_round_trip.py
      provides: "30 FR fixtures → BM25 top-3 mocked + assertion contract"
      min_lines: 80
  key_links:
    - from: tools/checks/tool_description_rubric.py
      to: services/backend/app/services/coach/coach_tools.py
      via: "AST scan tool descriptions for FR keyword presence"
      pattern: "compile|re.search"
---

<objective>
Concern A — close the « tool descriptions are English-only and terse » gap. Anthropic Tool Search BM25 matches against `name` + `description`. For « si je divorce demain » to surface `divorce_simulator` in top-3, the description MUST contain « divorce, séparation, CC art. 122-124, splitting AVS, pension alimentaire ».

Purpose: D-CE-01 + Concern A. Make the 3-adapter pattern (Plan 07) actually USEFUL on FR user queries.

Output: 1 lint script + ≥35 tool description rewrites + 1 pytest round-trip fixture + 1 Maestro G1 flow + Julien checkpoint for staging pilot rollout.

**Manual checkpoint required:** This plan is `autonomous: false` because (a) tool description copy needs Julien tone review, (b) Maestro G1 needs Julien sim sign-off, and (c) staging pilot flip needs operator GO.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@services/backend/app/services/coach/coach_tools.py
@services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py
@docs/AGENTS/swiss-brain.md
@docs/VOICE_SYSTEM.md
</context>

<interfaces>
<!-- Concern A naming-and-description rubric:
For each tool, description MUST contain:
1. Action verb in French (« simule », « calcule », « compare », « estime », « projette »)
2. Domain keywords (FR) covering the life events the tool serves
3. Legal article references where applicable (CC art. X, LAVS art. Y, LPP art. Z, LIFD art. W)
4. Outcome description (what number it produces)
-->

Example BEFORE (current state, English-only, terse):
```python
"description": "Compute LPP retirement projection"
```

Example AFTER (Concern A rubric):
```python
"description": (
    "Projette la rente LPP à la retraite, basée sur LPP art. 14 (taux de conversion) "
    "+ inputs_hash. Couvre les scénarios retraite ordinaire (65/64 ans), "
    "anticipée (LPP art. 13 + LAVS art. 40), différée. Produit la rente CHF/mois + "
    "le capital cumulé à 65 ans."
)
```

Round-trip fixture pattern (RESEARCH §Q-A lines 218-237):
```python
ROUND_TRIP_FIXTURES = [
    ("si je divorce demain, que se passe-t-il ?", ["divorce_simulator", "succession_simulator", "get_couple_optimization"]),
    ("je veux racheter ma LPP", ["lpp_rachat_echelonne", "get_cross_pillar_analysis", "epl_service"]),
    ("frontalier vaudois, FATCA", ["frontalier_service", "expat_service", "wealth_tax_service"]),
    # ... 27 more
]
```
</interfaces>

<tasks>

<task id="W2-03-01" type="auto" tdd="true">
  <name>Task 1: tool_description_rubric.py lint</name>
  <files>tools/checks/tool_description_rubric.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Concern A
    - tools/checks/banned_terms_python.py (lint pattern precedent)
    - tools/checks/accent_lint_fr.py (lint pattern precedent)
    - services/backend/app/services/coach/coach_tools.py (current descriptions to lint)
  </read_first>
  <behavior>
    - Test 1: Lint passes on a file with FR-keyword-compliant descriptions.
    - Test 2: Lint fails (exit 1) on a file with English-only descriptions.
    - Test 3: Lint reports which tool name is non-compliant + which rubric rule violated.
  </behavior>
  <action>
    Create `tools/checks/tool_description_rubric.py`:
    ```python
    """Phase mint-calc-engine-v1 Concern A — tool description FR rubric lint.

    Scans tool definitions (Python files declaring `description: "..."` for tools)
    and asserts each description meets the Concern A rubric:
      R1: ≥1 French verb (simule/calcule/compare/estime/projette/évalue/analyse)
      R2: ≥3 FR keywords (presence of accented vowels = proxy for FR text)
      R3: legal article ref OR « basé sur » + financial domain keyword
      R4: description length ≥80 chars (templated `<name>` descriptions reject)
    """
    import ast
    import re
    import sys
    from pathlib import Path

    R1_VERBS = re.compile(r"\b(simule|calcule|compare|estime|projette|évalue|analyse)\b", re.IGNORECASE)
    R2_FR = re.compile(r"[éèàùîôûâç]")
    R3_LEGAL_OR_DOMAIN = re.compile(r"(art\. \d+|basé sur|CHF|canton|retraite|impôt|hypothèque|3a|LPP|AVS|LIFD|LCC|LAVS|CC art)")
    R4_MIN_LEN = 80


    def lint_file(path: Path) -> list[tuple[int, str, str]]:
        """Return list of (line_no, rule_violated, description) failures."""
        source = path.read_text()
        tree = ast.parse(source)
        failures = []
        for node in ast.walk(tree):
            # Find dict literals with 'description': '...'
            if isinstance(node, ast.Dict):
                for k, v in zip(node.keys, node.values):
                    if isinstance(k, ast.Constant) and k.value == "description":
                        if isinstance(v, ast.Constant) and isinstance(v.value, str):
                            desc = v.value
                            if not R1_VERBS.search(desc):
                                failures.append((v.lineno, "R1 FR verb", desc[:60]))
                            if not R2_FR.search(desc):
                                failures.append((v.lineno, "R2 FR text", desc[:60]))
                            if not R3_LEGAL_OR_DOMAIN.search(desc):
                                failures.append((v.lineno, "R3 legal/domain", desc[:60]))
                            if len(desc) < R4_MIN_LEN:
                                failures.append((v.lineno, "R4 min length", desc[:60]))
        return failures


    def main(paths: list[str]) -> int:
        total = 0
        for path_str in paths:
            path = Path(path_str)
            if not path.is_file():
                continue
            failures = lint_file(path)
            for lineno, rule, snippet in failures:
                print(f"{path}:{lineno}: {rule} — {snippet}...")
                total += 1
        return 1 if total > 0 else 0


    if __name__ == "__main__":
        sys.exit(main(sys.argv[1:]))
    ```

    Tests in `tools/checks/tests/test_tool_description_rubric.py` (if a `tests/` subdir exists; else `services/backend/tests/test_tool_description_rubric_lint.py`).
  </action>
  <verify>
    <automated>python3 tools/checks/tool_description_rubric.py services/backend/app/services/coach/coach_tools.py 2>&1 | tail -5 ; echo "EXIT=$?"</automated>
  </verify>
  <acceptance_criteria>
    - `tools/checks/tool_description_rubric.py` exists, ≥60 lines, executable
    - 3 lint-internal tests green
    - Lint FAILS (exit 1) on coach_tools.py BEFORE Task 2 (baseline: current descriptions don't meet rubric)
  </acceptance_criteria>
  <done>Lint script live</done>
</task>

<task id="W2-03-02" type="auto" tdd="false">
  <name>Task 2: Rewrite 5 chip-emitter descriptions + ≥30 long-tail descriptions</name>
  <files>services/backend/app/services/coach/coach_tools.py, services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py</files>
  <read_first>
    - services/backend/app/services/coach/coach_tools.py:637-722 (current 5 chip-emitter descriptions)
    - tools/checks/tool_description_rubric.py (rubric from Task 1)
    - docs/AGENTS/swiss-brain.md (LSFin grammar)
    - docs/VOICE_SYSTEM.md (Mint voice register)
    - services/backend/app/calculators/_registry.py (Plan 05 — 52 long-tail tool names + life_events_served)
  </read_first>
  <action>
    **5 chip-emitter rewrites** in `coach_tools.py:637-722`. Pattern:

    ```python
    # BEFORE:
    "description": "Compute retirement projection",

    # AFTER (Concern A rubric):
    "description": (
        "Projette la rente totale à la retraite (AVS LAVS + LPP art. 14 + 3a LIFD art. 82) "
        "basée sur le profil utilisateur (âge, salaire, canton, années cotisations). "
        "Produit la rente CHF/mois projetée à 65 ans + le gap par rapport au revenu actuel."
    ),
    ```

    For each of the 5:
    - `get_budget_status` → « Calcule le bilan budgétaire mensuel (revenus - dépenses) basé sur les transactions et catégories de l'utilisateur. Produit le surplus / déficit mensuel CHF + les mois de liquidité. »
    - `get_retirement_projection` → (above example)
    - `get_cross_pillar_analysis` → « Analyse les 3 piliers (AVS LAVS art. 18 + LPP art. 14 + 3a LIFD art. 82) cumulés. Identifie les gaps de couverture et propose des arbitrages chiffrés entre piliers selon le profil canton/âge. »
    - `get_cap_status` → « Estime la capacité d'emprunt hypothécaire selon LCC art. 28 (plafond 33% revenu brut) + fonds propres disponibles. Produit le prix d'achat plafond + l'écart si propriété visée. »
    - `get_couple_optimization` → « Compare les scénarios fiscaux pour un couple (mariage CC art. 159 vs concubinage) selon les deux cantons + revenus. Produit la différence d'impôt CHF/an + les variations en cas de splitting LPP. »

    **≥30 long-tail rewrites** in `AnthropicDeferLoadingAdapter._description_for(meta)` (Plan 07 Task 2). Replace the templated stub with explicit per-tool description map:

    ```python
    _TOOL_DESCRIPTIONS_FR = {
        "divorce_simulator": (
            "Simule l'impact financier d'un divorce ou d'une séparation : "
            "splitting AVS (LAVS art. 29sexies), partage LPP (CC art. 122-124), "
            "pension alimentaire selon CC art. 125, partage des avoirs et régime matrimonial."
        ),
        "succession_simulator": (
            "Estime les frais de succession cantonaux (CANTON_SUCCESSION_TAX) selon "
            "CC art. 462 (conjoint survivant) + CC art. 467-469 (réserves héréditaires). "
            "Produit l'impôt CHF + la part nette héritier."
        ),
        "lpp_rachat_echelonne": (
            "Calcule un rachat LPP étalé sur N années (LIFD art. 33 al. 1 let. d). "
            "Compare le coût net selon canton (LIFD + canton) + ROI par tranche."
        ),
        "wealth_tax_service": (
            "Estime l'impôt sur la fortune cantonal pour un patrimoine donné. "
            "Compare 26 cantons (Genève, Vaud, Valais, etc.). Produit l'impôt CHF/an + delta cross-canton."
        ),
        "frontalier_service": (
            "Calcule la situation fiscale frontalier (>90% revenu CH, >120K CHF brut). "
            "Compare l'imposition CH source vs domicile pays voisin + sécurité sociale LAMal vs CMU."
        ),
        # ... ≥25 more
    }

    def _description_for(self, meta) -> str:
        return _TOOL_DESCRIPTIONS_FR.get(meta["name"], self._fallback_description(meta))
    ```

    Use legal-article references from `docs/AGENTS/swiss-brain.md`. NEVER « optimal / meilleur / garanti / recommandé ». DO use « pourrait », « envisager », factual numbers.

    All FR text MUST have correct accents (verify with `accent_lint_fr.py`).
  </action>
  <verify>
    <automated>python3 tools/checks/tool_description_rubric.py services/backend/app/services/coach/coach_tools.py services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py 2>&1 | tail -5 ; echo "EXIT=$?"</automated>
  </verify>
  <acceptance_criteria>
    - Lint exit 0 on both files after rewrite
    - `grep -c "art\\. " services/backend/app/services/coach/coach_tools.py` returns ≥10 (legal article refs in chip-emitter descriptions)
    - `grep -c "art\\. " services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` returns ≥30 (long-tail descriptions)
    - `python3 tools/checks/banned_terms_python.py services/backend/app/services/coach/coach_tools.py services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py` exits 0
    - `python3 tools/checks/accent_lint_fr.py --scope backend 2>&1 | grep -E "coach_tools|anthropic_defer_loading" | grep -i error` returns 0 hits
    - Backend test suite still green (descriptions are strings ; no behavior change)
  </acceptance_criteria>
  <done>≥35 descriptions FR-compliant</done>
</task>

<task id="W2-03-03" type="auto" tdd="true">
  <name>Task 3: Round-trip pytest fixture (30 FR messages → top-3 mocked BM25)</name>
  <files>services/backend/tests/test_tool_search_round_trip.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-A lines 218-247
    - services/backend/tests/coach/test_claude_retry.py:30-60 (AsyncMock + patch.object precedent)
    - services/backend/app/services/coach/tool_registry/anthropic_defer_loading_adapter.py
  </read_first>
  <behavior>
    - For each of 30 fixtures `(user_message, expected_top_3_tool_names)`: assert that a BM25-mocked Anthropic response surfaces at least one of `expected_top_3_tool_names` when the adapter sends descriptions to Tool Search.
  </behavior>
  <action>
    ```python
    # services/backend/tests/test_tool_search_round_trip.py
    """Concern A round-trip fixture — verifies FR-rewritten descriptions surface correctly.

    Mocks the Anthropic Tool Search response. The REAL test (vs production Anthropic API)
    is the Maestro G1 flow + staging pilot.
    """
    import pytest
    from unittest.mock import patch, MagicMock

    from app.services.coach.tool_registry.factory import get_tool_registry_adapter


    ROUND_TRIP_FIXTURES: list[tuple[str, list[str]]] = [
        # Family / divorce / succession
        ("si je divorce demain, que se passe-t-il ?", ["divorce_simulator", "get_couple_optimization", "succession_simulator"]),
        ("je veux savoir ce qui se passe en cas de décès", ["succession_simulator", "concubinage_succession"]),
        ("je suis en concubinage à Genève", ["concubinage_compare", "concubinage_succession"]),
        ("naissance de mon premier enfant", ["naissance_service"]),
        ("on va se marier l'année prochaine", ["mariage", "get_couple_optimization"]),
        # Retirement / LPP
        ("je veux racheter ma LPP", ["lpp_rachat_echelonne", "epl_service", "get_cross_pillar_analysis"]),
        ("retraite anticipée à 62 ans", ["rente_vs_capital", "get_retirement_projection"]),
        ("rente LPP à 65 ans", ["get_retirement_projection", "lpp_conversion"]),
        ("retrait capital ou rente", ["rente_vs_capital"]),
        # Mortgage / housing
        ("acheter un appartement à Lausanne", ["affordability", "get_cap_status", "saron_vs_fixed"]),
        ("taux fixe vs SARON 2026", ["saron_vs_fixed"]),
        ("location vs propriété sur 10 ans", ["location_vs_propriete"]),
        ("amortissement direct ou indirect", ["amortization", "epl_combined"]),
        # Fiscal / canton
        ("comparer impôt entre Genève et Zurich", ["fiscal_compare", "wealth_tax"]),
        ("déménagement cantonal pour optimiser fiscalement", ["fiscal_compare", "wealth_tax"]),
        ("frontalier vaudois, FATCA", ["frontalier_service", "expat_service"]),
        ("expat américain, comptes US", ["expat_service"]),
        # Independants / Sàrl
        ("je suis indépendant à 80K", ["avs_cotisations_independants", "pillar_3a_indep"]),
        ("Sàrl ou raison individuelle", ["pillar_3a_indep"]),  # gap — calculator absent
        ("dividende vs salaire indépendant", ["pillar_3a_indep"]),
        # Career / unemployment
        ("je viens de perdre mon emploi", ["unemployment_calculator", "get_budget_status"]),
        ("je change de canton pour mon job", ["fiscal_compare", "wealth_tax"]),
        ("premier emploi à 25 ans", ["pillar_3a_optimizer", "get_retirement_projection"]),
        # Budget / debt
        ("comment réduire mes dettes", ["debt_ratio", "repayment_service"]),
        ("snowball ou avalanche", ["repayment_service"]),
        ("budget mensuel équilibré", ["get_budget_status"]),
        # Edge / ambiguous
        ("3a maximal en 2026", ["pillar_3a_optimizer", "get_cross_pillar_analysis"]),
        ("franchise LAMal optimale", ["lamal_franchise"]),
        ("si je quitte la Suisse l'année prochaine", ["expat_service", "frontalier_service"]),
        ("plafond LCC 33%", ["get_cap_status", "affordability"]),
    ]


    @pytest.mark.parametrize("user_message,expected_top_3", ROUND_TRIP_FIXTURES)
    def test_anthropic_adapter_descriptions_match_fr_queries(user_message, expected_top_3):
        """Concern A — adapter descriptions surface relevant tools for FR queries.

        Pure-Python BM25 approximation : tokenize user_message + each tool description,
        score by Jaccard intersection on stemmed FR tokens. Top-3 by score.
        """
        adapter = get_tool_registry_adapter()
        tools = adapter.register_tools({"user_intents": []})
        # Compute simple FR-keyword overlap score per tool description
        scored = []
        for tool in tools:
            if "description" not in tool:
                continue
            score = _score_overlap(user_message, tool["description"])
            scored.append((score, tool["name"]))
        scored.sort(reverse=True)
        top_3_names = [name for _, name in scored[:3]]
        assert any(name in expected_top_3 for name in top_3_names), (
            f"User message {user_message!r}: expected at least one of {expected_top_3} in top-3, "
            f"got {top_3_names}"
        )


    def _score_overlap(user_msg: str, description: str) -> int:
        """Cheap FR-keyword overlap score (replaces actual Anthropic BM25 for unit test)."""
        import re
        msg_tokens = set(re.findall(r"\w+", user_msg.lower()))
        desc_tokens = set(re.findall(r"\w+", description.lower()))
        return len(msg_tokens & desc_tokens)
    ```

    The Jaccard-overlap scorer is an APPROXIMATION of BM25 for unit testing. Production verification ships via Maestro G1 + staging pilot. Document this in test docstring.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_tool_search_round_trip.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 30 fixtures defined
    - ≥25 of 30 tests pass (allow 5 failures for ambiguous queries — surfaces as TODOs for description polish)
    - If <25 pass, executor surfaces failures in SUMMARY: « N of 30 fixtures need description tuning ; staging pilot will catch additional gaps »
  </acceptance_criteria>
  <done>30-fixture round-trip baseline</done>
</task>

<task id="W2-03-04" type="auto" tdd="false">
  <name>Task 4: Maestro G1 flow (coach_tool_search_round_trip.yaml)</name>
  <files>tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml</files>
  <read_first>
    - tools/simulator/flows/maestro-perfect-set/ (existing flows for pattern)
    - tools/simulator/walker.sh
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md G1 row
  </read_first>
  <action>
    Create Maestro flow walking 5 representative FR queries on sim:
    ```yaml
    # tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml
    appId: io.mint.app
    name: "Tool Search round-trip FR coverage"
    tags: ["calc-engine-v1", "concern-a", "tool-search"]
    ---
    - launchApp
    - tapOn: "Coach"
    - inputText: "si je divorce demain, que se passe-t-il ?"
    - tapOn: "Envoyer"
    - extendedWaitUntil:
        visible:
          text: ".*divorce.*"
        timeout: 20000
    - takeScreenshot: tool_search_divorce
    # ... 4 more queries
    ```

    Cover: divorce / rachat LPP / frontalier / acheter Lausanne / indépendant Sàrl.

    DO NOT execute on sim in this task — Maestro G1 execution is the next task (autonomous=false checkpoint with Julien).
  </action>
  <verify>
    <automated>maestro test tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml --dry-run 2>&1 | tail -5</automated>
  </verify>
  <acceptance_criteria>
    - Flow file exists
    - `maestro test --dry-run` exits 0 (syntax valid)
    - 5 inputText / tapOn / extendedWaitUntil steps
  </acceptance_criteria>
  <done>Maestro G1 flow ready for Julien sim walk</done>
</task>

<task id="W2-03-05" type="checkpoint:human-verify" gate="blocking">
  <name>Task 5: Julien sim G2 — Maestro G1 walkthrough + staging pilot GO</name>
  <what-built>
    - Concern A rubric lint (tools/checks/tool_description_rubric.py)
    - ≥35 tool descriptions rewritten with FR keywords + legal article refs
    - 30-fixture round-trip pytest baseline
    - Maestro flow coach_tool_search_round_trip.yaml
  </what-built>
  <how-to-verify>
    1. Run Maestro: `bash tools/simulator/walker.sh tools/simulator/flows/maestro-perfect-set/coach_tool_search_round_trip.yaml`
    2. Observe: 5 FR queries surface relevant tools. Tap traces in `idb ui describe-all` show tool_call_id citations for the right tool.
    3. Confirm tone: Julien reads 3 randomly-picked tool descriptions from coach_tools.py — do they sound like Mint? Legal article refs accurate? No banned LSFin terms?
    4. Decision: GO for staging pilot (`TOOL_REGISTRY_ADAPTER=anthropic_defer_loading` on Railway staging) or rework (revise specific descriptions).
  </how-to-verify>
  <resume-signal>
    Reply with one of:
    - "approved-staging" → Plan 09 closes, W2-04 (Plan 10) opens
    - "approved-with-edits: <list>" → executor reworks specific descriptions, re-spawns Task 5
    - "blocked: <reason>" → escalate to orchestrator
  </resume-signal>
</task>

<task id="W2-03-99" type="auto" tdd="false">
  <name>Task 6: Engram + STATE update post-checkpoint</name>
  <files>(verification + engram)</files>
  <action>
    On checkpoint resume = approved:
    - Engram save:
      - `topic_key: calc_engine:w2:concern_a_descriptions_shipped`
      - `type: discovery`
      - `prior_finding_refs: [Plan 07 obs (adapters), Plan 08 obs (bundles), #103 panel synthesis Concern A]`
      - Content: « Concern A rubric lint live ; ≥35 tool descriptions FR-rewritten with legal article refs (CC + LAVS + LPP + LIFD + LCC). 30-fixture round-trip baseline green ≥25/30. Maestro G1 PASS + Julien G2 approved. Staging pilot rollout GO. »
    - STATE.md updated.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite green
    - Engram saved
    - STATE.md reflects W2-03 closure
  </acceptance_criteria>
  <done>Concern A closed</done>
</task>

</tasks>

<threat_model>
## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-09-01 | LSFin compliance | tool descriptions emitted to Anthropic API | mitigate | Rubric lint enforces NO banned terms + correct FR + legal article refs. banned_terms_python.py runs in CI. |
| T-mint-calc-09-02 | Information disclosure | tool description reveals internal calc design | accept | Tool descriptions are by design VISIBLE in Anthropic responses + Sentry logs. No PII or secret. FR keyword discipline doesn't change leak surface vs current state. |
| T-mint-calc-09-03 | Tampering | description string modification post-deploy | accept | Operator controls via PR. Test 1 of Task 3 catches regression on top-3 surfacing. |
| T-mint-calc-09-04 | DoS | description length blows prompt budget | mitigate | 35 × ~200 chars = ~7K chars deferred (defer_loading=true means only loaded on-demand). 5 chip-emitters × ~250 chars = 1.25K always-on. Trivial vs ~80K narrator prompt budget. |
| T-mint-calc-09-05 | Spoofing | malicious description injection | accept | Source files are git-controlled. No runtime injection path. |
</threat_model>

<success_criteria>
- ≥35 descriptions rewritten + rubric lint green
- Round-trip pytest ≥25/30 fixtures pass
- Maestro G1 flow + Julien G2 sign-off
- Staging pilot rollout authorized
- Engram observation linking Plan 07 + Plan 08 + #103
</success_criteria>

<risks>
- **5 round-trip failures acceptable.** Cheap Jaccard scorer ≠ Anthropic BM25 — staging pilot is the ground truth. Surface failures as description-polish TODOs, NOT plan blockers.
- **Julien sign-off blocks plan.** Per `autonomous: false` frontmatter. If Julien requests rework, executor iterates Task 2 (description rewrites) + re-runs Task 5.
- **Maestro flakiness.** SpringBoard crashes (per memory `feedback_sim_crash_mitigation`) may cause Task 5 to fail spuriously. Mitigation: reboot sim before flow run.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-09-w2-tool-description-rewrite-SUMMARY.md` including:
- Engram obs_id
- 30-fixture round-trip pass rate (X/30)
- Maestro G1 PASS/FAIL with screenshots
- Julien G2 sign-off statement
- Staging pilot rollout date
- List of description-polish TODOs for staging-based refinement
</output>
