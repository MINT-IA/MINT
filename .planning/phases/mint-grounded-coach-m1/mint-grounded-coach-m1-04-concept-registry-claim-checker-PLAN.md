---
phase: mint-grounded-coach-m1
plan: 04
type: execute
wave: 3
depends_on:
  - mint-grounded-coach-m1-01-inversion-fixtures-red
  - mint-grounded-coach-m1-02-compliance-blocking-gates
files_modified:
  - services/backend/app/services/coach/concept_registry.py
  - services/backend/app/services/coach/claim_checker.py
  - services/backend/app/services/coach/compliance_guard.py
  - services/backend/tests/test_concept_registry.py
  - services/backend/tests/test_claim_checker.py
  - services/backend/tests/test_coach_claim_inversions.py
autonomous: true
requirements: [WS-B, WS-E]
must_haves:
  truths:
    - "A curated Swiss concept registry exists as the single source of canonical definitions"
    - "A deterministic claim-checker detects definitional inversions of registry concepts"
    - "The claim-checker is wired into ComplianceGuard as a blocking layer"
    - "The Plan 01 inversion fixtures now pass (xfail flips to GREEN)"
  artifacts:
    - path: "services/backend/app/services/coach/concept_registry.py"
      provides: "Curated concept:* pages (canonical FR definition + source + known inversions)"
      contains: "rachat_lpp"
    - path: "services/backend/app/services/coach/claim_checker.py"
      provides: "Deterministic definitional-inversion detector (closed-world over the registry)"
      exports: ["check_claims"]
  key_links:
    - from: "compliance_guard.py"
      to: "claim_checker.check_claims"
      via: "new blocking layer"
      pattern: "claim_checker"
    - from: "claim_checker.py"
      to: "concept_registry"
      via: "registry lookup"
      pattern: "concept_registry|CONCEPT_REGISTRY"
---

<objective>
Build the curated Swiss concept registry and the deterministic claim-checker, and wire the
checker into ComplianceGuard as a blocking layer (CONTEXT WS-B, audit 04 §3). This is the
direct fix for the rachat inversion: a closed-world detector over the registry catches a
definitional inversion ("rachat = retirer") the way the hallucination detector catches a
wrong number. Wiring it in flips the Plan 01 xfail to a hard GREEN.

Purpose: HOLE-1 (definitional claims completely ungated) is the single most important
finding. The registry is a curated wiki (not vector-soup, per project decision
project_user_profile_wiki), the checker is substring/pattern deterministic (not LLM-judge,
per CLAUDE.md §9).
Output: concept_registry + claim_checker + ComplianceGuard layer; Plan 01 fixtures GREEN.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-CONTEXT.md
@.planning/phases/mint-etat-des-lieux-20260612/04-coach-orchestrator.md
@.planning/phases/mint-etat-des-lieux-20260612/01-advice-path-audit.md
@./CLAUDE.md
@services/backend/app/services/coach/compliance_guard.py

<interfaces>
Existing patterns to mirror (read in context — do NOT re-explore):
- citation_registry.py:227-248 — the registry-as-frozen-Mapping pattern (MappingProxyType,
  CitationSource dataclass, resolve()). Mirror this shape for the concept registry: a frozen
  CONCEPT_REGISTRY: Mapping[str, ConceptPage] with a resolve()-style lookup.
- compliance_guard.py validate() at line 355 — the 5-layer pipeline. The claim-checker is a
  NEW layer (call it Layer 6 / semantic) inserted after L2 prescriptive and before/with L3,
  setting use_fallback=True + fallback_reasons.append("definition_inversion ...") on a hit.
- The Plan 01 fixtures (tests/fixtures/inversions_eval.jsonl) carry concept_key,
  canonical_relation_fr, known_inversions, forbidden_substrings — the registry's concept_key
  set MUST be a superset of the fixture concept_keys so every fixture maps to a page.
- test_coach_claim_inversions.py (Plan 01) has test_inversions_are_blocked as xfail-strict.
  After this plan, that xfail must FLIP: it now PASSES because ComplianceGuard blocks the
  inversion. Remove the xfail marker as part of this plan's Task 3 (the file is therefore in
  this plan's files_modified).

Concept set (CONTEXT WS-B "top ~50", start with the P0 closed-world set, ≥15 to cover all
Plan 01 fixtures): rachat_lpp, epl, splitting_avs, bonifications_lpp, pilier_3a, pilier_3b,
taux_conversion, lacunes_prevoyance, rente_vs_capital, coordination_lpp, libre_passage,
frontalier, fatca, retrait_capital_blocage_3ans, avs_age_reference.
Each page: canonical definition FR (correct accents, no banned terms), legal source
(LPP art. X / LIFD art. Y), "ce que ce n'est PAS" (known inversions), related concepts.
</interfaces>
</context>

<tasks>

<task type="auto" tdd="true">
  <name>Task 1: Curated concept registry (closed-world)</name>
  <files>services/backend/app/services/coach/concept_registry.py, services/backend/tests/test_concept_registry.py</files>
  <behavior>
    - CONCEPT_REGISTRY is a frozen Mapping[str, ConceptPage] with ≥15 P0 concepts.
    - rachat_lpp page: canonical_fr asserts "verser dans la caisse / déductible LPP art.
      79b", known_inversions include "retirer", "retrait", "sortir le capital".
    - Every concept_key present in tests/fixtures/inversions_eval.jsonl resolves to a page
      (registry is a superset of fixture keys).
    - resolve(key) returns the page or None; runtime mutation raises (MappingProxyType).
    - All FR strings pass accent lint + carry no banned LSFin term.
  </behavior>
  <action>Mirror citation_registry.py structure: a ConceptPage dataclass (concept_key, canonical_fr, source_title, source_url, known_inversions:list, not_this_fr:list, related:list) + frozen CONCEPT_REGISTRY + resolve(). Curate the ≥15 P0 concepts from the interfaces list with correct Swiss 2026 law. For avs_age_reference, note women=64.5 in 2026 (the registry VALUE fix lands in Plan 06; here it's the conceptual page text). Write test_concept_registry.py: ≥15 pages, rachat_lpp canonical+inversions present, every Plan-01 fixture concept_key resolves, frozen-mutation raises, accent/banned-term scan clean.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_concept_registry.py -q 2>&1 | tail -10 && python3 -m pytest --co -q tests/test_concept_registry.py >/dev/null && python3 tools/checks/accent_lint_fr.py services/backend/app/services/coach/concept_registry.py 2>&1 | tail -3 || true</automated>
  </verify>
  <done>≥15 pages incl. rachat_lpp; all fixture keys resolve; frozen; accent-clean; tests green.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 2: Deterministic claim-checker (definitional inversion detector)</name>
  <files>services/backend/app/services/coach/claim_checker.py, services/backend/tests/test_claim_checker.py</files>
  <behavior>
    - check_claims(text) -> list[ClaimViolation]: closed-world over CONCEPT_REGISTRY. For
      each concept_key whose definiendum appears in the text in a definitional pattern
      ("un X c'est…", "X = …", "X signifie…", "X consiste à…"), check the definiens against
      the page's known_inversions / not_this_fr substrings.
    - Given "un rachat c'est retirer ton capital du 2e pilier" → returns a violation for
      rachat_lpp (definition inversion). Given "un rachat c'est verser dans ta caisse" →
      returns no violation.
    - No LLM call (per CLAUDE.md §9 — deterministic ground truth). Surface-pattern detector,
      not heavy NLP. Runs over all fixtures in <2s.
  </behavior>
  <action>Implement claim_checker.py: a definitional-pattern regex set keyed off the registry definiendum lexicon (closed-world), comparing the asserted definiens to each page's known_inversions / forbidden substrings. Return structured ClaimViolation(concept_key, matched_inversion, snippet). Write test_claim_checker.py driven by tests/fixtures/inversions_eval.jsonl: for each fixture, feed a synthetic inverted definition (using known_inversions) and assert a violation IS returned; feed the canonical definition and assert NO violation. Frame logs in neutral design language (no forensic phrasing).</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_claim_checker.py -q 2>&1 | tail -12</automated>
  </verify>
  <done>Inverted definitions flagged, canonical definitions pass, fixture-driven test green.</done>
</task>

<task type="auto" tdd="true">
  <name>Task 3: Wire claim-checker into ComplianceGuard + flip Plan 01 xfail</name>
  <files>services/backend/app/services/coach/compliance_guard.py, services/backend/tests/test_coach_claim_inversions.py, services/backend/tests/test_claim_checker.py</files>
  <behavior>
    - ComplianceGuard.validate() now runs check_claims as a blocking layer: a definitional
      inversion sets use_fallback=True with fallback_reasons "definition_inversion <key>".
    - A canonical/correct definition passes (no false positive — W1 reply1 standard intact).
    - test_coach_claim_inversions.py::test_inversions_are_blocked (Plan 01 xfail-strict)
      now PASSES — the xfail marker is removed and the assertion is a hard pass.
  </behavior>
  <action>Insert the claim-checker call in compliance_guard.py validate() after L2 (so it composes with the Plan 02 blocking gates). On any ClaimViolation, set use_fallback=True and append a structured neutral-language fallback_reasons entry. Then edit tests/test_coach_claim_inversions.py: remove the pytest.mark.xfail(strict=True) on test_inversions_are_blocked so it is now a hard pass (the RED→GREEN flip CONTEXT decision 3 requires). Keep the original RED-proof note in the SUMMARY lineage.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_coach_claim_inversions.py tests/test_claim_checker.py tests/test_concept_registry.py -q 2>&1 | tail -12</automated>
  </verify>
  <done>Inversion blocked by ComplianceGuard; Plan 01 fixtures now hard-GREEN (xfail removed); canonical defs pass.</done>
</task>

<task type="auto">
  <name>Task 4: Full backend suite — no regression</name>
  <files>services/backend</files>
  <action>Run the full backend suite. The new blocking layer may trip tests that fed inverted/loose definitions as acceptable; update ONLY those to reflect the now-correct blocking, justify each in SUMMARY. Do not weaken the checker.</action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -8</automated>
  </verify>
  <done>Full backend suite green; updated tests justified.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| LLM coach definitional output → user | Unverified meaning of a financial definition crosses into the education surface |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-m1-04-01 | Information disclosure (mis-information) | definitional blind spot HOLE-1 | mitigate | Curated registry + deterministic claim-checker wired as blocking ComplianceGuard layer |
| T-m1-04-02 | Spoofing (invented source) | fabricated legal source on a definition | mitigate | Definitions resolve to registry pages with real source_url; claim-checker blocks off-registry inversions |
| T-m1-04-SC | Tampering | pip installs | accept | No new packages; stdlib re + dataclasses + existing pytest |
</threat_model>

<verification>
- `cd services/backend && python3 -m pytest tests/ -q` exits 0.
- `grep -c '"concept_key"\|concept_key=' services/backend/app/services/coach/concept_registry.py` ≥ 15.
- `grep -n "claim_checker" services/backend/app/services/coach/compliance_guard.py` confirms the wired blocking layer.
- `grep -n "xfail" services/backend/tests/test_coach_claim_inversions.py` no longer marks test_inversions_are_blocked (RED→GREEN flip).
</verification>

<success_criteria>
The concept registry is the single source of canonical Swiss definitions, the deterministic
claim-checker detects definitional inversions over that closed world and is wired into
ComplianceGuard as a blocking layer, the Plan 01 inversion fixtures pass (xfail removed),
and the full backend suite is green.
</success_criteria>

<output>
Create `.planning/phases/mint-grounded-coach-m1/mint-grounded-coach-m1-04-SUMMARY.md` when done.
Cite the GREEN `test_inversions_are_blocked` line as the RED→GREEN closure evidence.
</output>
