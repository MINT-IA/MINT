---
phase: mint-calc-engine-v1
plan: 04
wave: 1
title: W1 — Lucidity L1/L2/L3/L4 typed payloads + L4 invariant wedge endpoint (Finding 5)
type: execute
depends_on: [01]
files_modified:
  - services/backend/app/models/lucidity/__init__.py
  - services/backend/app/models/lucidity/_payload.py
  - services/backend/app/api/v1/endpoints/lucidity.py
  - services/backend/app/api/v1/routes.py
  - services/backend/tests/test_lucidity_payloads.py
  - services/backend/tests/test_l4_invariant_endpoint.py
autonomous: true
requirements: [D-CE-15, D-CE-16]
estimated_duration: 5
must_haves:
  truths:
    - "`LucidityLevel` StrEnum + L1/L2/L3/L4 Pydantic v2 discriminated payloads defined and exported from `app.models.lucidity`"
    - "`L2ComparePayload.model_validate({'level': 'L2', 'scenarios': [...], 'recommended_option': 'A'})` raises `ValidationError` (extra=forbid kills the ranking field structurally)"
    - "Narrative-length parity validator on `L2ComparePayload.scenarios` raises if any scenario's `narrative_fr` length deviates more than ±15% from mean"
    - "L4 wedge: GET /api/v1/lucidity/invariants/mortgage-cap returns L4InvariantPayload with `legal_article_ref='LCC art. 28'` and FR condition text (the «33% LCC plafond» invariant)"
  artifacts:
    - path: services/backend/app/models/lucidity/_payload.py
      provides: "LucidityLevel + L1ChiffrePayload + _Scenario + L2ComparePayload + L3EclairePayload + L4InvariantPayload + LucidityPayload RootModel"
      min_lines: 100
    - path: services/backend/app/api/v1/endpoints/lucidity.py
      provides: "GET /api/v1/lucidity/invariants/mortgage-cap (L4 wedge, Finding 5)"
      min_lines: 40
  key_links:
    - from: services/backend/app/api/v1/endpoints/lucidity.py
      to: services/backend/app/models/lucidity/_payload.py
      via: "from app.models.lucidity import L4InvariantPayload"
      pattern: "from app.models.lucidity import"
    - from: services/backend/app/api/v1/routes.py
      to: services/backend/app/api/v1/endpoints/lucidity.py
      via: "router include_router"
      pattern: "lucidity"
---

<objective>
Ship the typed lucidity payload contracts that make L2/L3 ranking-creep STRUCTURALLY impossible (D-CE-15), and surface the first L4 invariant endpoint as the « wedge » per Finding 5 (« L4 is MINT's strongest LSFin moat + highest user-value surface »).

**Finding 6 fix (L2→L3 ranking creep = highest LSFin-finding risk per CONTEXT.md §Counter-arguments + §Finding 6):** the `extra="forbid"` ConfigDict on `L2ComparePayload` + `L3EclairePayload` PLUS the narrative-length-parity validator (±15% char-count budget across scenarios) kill ranking creep AT TYPE LEVEL — paraphrase cannot evade because the field `recommended_option` (and its 5 synonyms) literally cannot exist in the JSON output. This is the structural counterpart to the lint-time + runtime-gate defense (D-CE-16 triple defense, lexical layers shipped in Plan 18).

Purpose: D-CE-15 schema impossibility kills paraphrase ranking creep before payload leaves the calculator. D-CE-16(a) schema layer of triple defense. Finding 5 surfaces « 33% LCC plafond » as the wedge invariant — pure information générale + legal article reference + zero ranking surface.

Output: 1 Pydantic schema module + 1 endpoint module + 2 test files. L4 endpoint becomes the proof-of-concept that L1-L4 contracts work end-to-end before W2 starts emitting L2/L3 from compute services.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md
@services/backend/app/models/coach_tools/_response.py
@services/backend/app/api/v1/routes.py
@docs/AGENTS/swiss-brain.md
</context>

<interfaces>
<!-- D-CE-15 verbatim Pydantic v2 patterns from RESEARCH §Q-C (verified 2026-05-16). -->

```python
# Discriminated union shape (RESEARCH §Q-C lines 474-568):
from enum import StrEnum
from typing import Annotated, Any, Literal, Union
from pydantic import BaseModel, ConfigDict, Field, RootModel, model_validator


class LucidityLevel(StrEnum):
    L1 = "L1"
    L2 = "L2"
    L3 = "L3"
    L4 = "L4"


class _LucidityBase(BaseModel):
    model_config = ConfigDict(extra="forbid", frozen=True)


class L1ChiffrePayload(_LucidityBase):
    level: Literal[LucidityLevel.L1] = LucidityLevel.L1
    value: float
    unit_fr: str
    citation_key: str


class _Scenario(_LucidityBase):
    label_fr: str
    value: float
    narrative_fr: str
    citation_key: str


class L2ComparePayload(_LucidityBase):
    level: Literal[LucidityLevel.L2] = LucidityLevel.L2
    scenarios: list[_Scenario] = Field(..., min_length=2, max_length=4)

    @model_validator(mode="after")
    def _enforce_narrative_length_parity(self) -> "L2ComparePayload":
        lengths = [len(s.narrative_fr) for s in self.scenarios]
        if not lengths:
            return self
        avg = sum(lengths) / len(lengths)
        for i, ln in enumerate(lengths):
            if abs(ln - avg) > 0.15 * avg:
                raise ValueError(...)
        return self


class L3EclairePayload(_LucidityBase):
    level: Literal[LucidityLevel.L3] = LucidityLevel.L3
    primary_choice_fr: str
    cascade_effects: list[dict[str, Any]]
    horizon_years: int


class L4InvariantPayload(_LucidityBase):
    level: Literal[LucidityLevel.L4] = LucidityLevel.L4
    legal_article_ref: str = Field(..., min_length=5)
    condition_text_fr: str = Field(..., min_length=20)


LucidityPayload = RootModel[Annotated[
    Union[L1ChiffrePayload, L2ComparePayload, L3EclairePayload, L4InvariantPayload],
    Field(discriminator="level"),
]]
```

Forbidden field names (D-CE-15 schema-impossibility list — `extra="forbid"` rejects all):
- `recommended_option`
- `best_choice`
- `top_pick`
- `preferred`
- `optimal_choice`
- `winning_scenario`
</interfaces>

<tasks>

<task id="W1-04-01" type="auto" tdd="true">
  <name>Task 1: LucidityLevel + L1/L2/L3/L4 payloads (schema-impossibility tests RED → GREEN)</name>
  <files>services/backend/app/models/lucidity/__init__.py, services/backend/app/models/lucidity/_payload.py, services/backend/tests/test_lucidity_payloads.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-C (Pydantic v2 discriminated union patterns, lines 469-597)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §decisions D-CE-15 + 4-level lucidité framework table
    - services/backend/app/models/coach_tools/_response.py (existing RootModel + ConfigDict pattern precedent)
    - docs/AGENTS/swiss-brain.md (LSFin banned terms full list)
  </read_first>
  <behavior>
    - **Test 1 (D-CE-15 core)**: `L2ComparePayload.model_validate({"level": "L2", "scenarios": [...], "recommended_option": "A"})` raises `pydantic.ValidationError`. Error message must mention "extra" or "Extra inputs are not permitted" (Pydantic v2 standard wording).
    - **Test 2**: Same for `best_choice`, `top_pick`, `preferred`, `optimal_choice`, `winning_scenario` (5 paraphrase variants — parametrize).
    - **Test 3 (D-CE-15 narrative parity)**: 3 scenarios with `narrative_fr` lengths `[200, 50, 50]` chars → ValidationError from `_enforce_narrative_length_parity` (200 - 100 avg = 100 > 15 chars threshold).
    - **Test 4**: 3 scenarios with `narrative_fr` lengths `[100, 105, 95]` → succeeds (within ±15% of avg=100).
    - **Test 5**: `L4InvariantPayload(legal_article_ref="LCC art. 28", condition_text_fr="Quel que soit le scénario, ta capacité d'emprunt est plafonnée à 33% LCC.")` constructs valid.
    - **Test 6**: `L4InvariantPayload(legal_article_ref="", ...)` raises (min_length=5).
    - **Test 7**: `L4InvariantPayload(legal_article_ref="LCC art. 28", condition_text_fr="trop court")` raises (min_length=20).
    - **Test 8 (discriminator)**: `LucidityPayload.model_validate({"level": "L1", "value": 2300, "unit_fr": "CHF/mois", "citation_key": "tool_get_retirement_projection"})` returns an L1 instance. `LucidityPayload.model_validate({"level": "L4", ...})` returns L4. Wrong level keys raise.
    - **Test 9 (frozen)**: `payload = L1ChiffrePayload(...); payload.value = 999` raises (frozen=True).
    - **Test 10 (banned-term in narrative_fr)**: an L2 scenario with `narrative_fr="C'est la meilleure option garantie"` is REJECTED by `tools/checks/banned_terms_python.py` lint on the test file — but the payload itself does NOT enforce banned-term scanning (that's W4's runtime gate D-CE-16(c)). Comment in test: « Schema impossibility kills field names ; runtime gate D-CE-16(c) kills banned verbs in free text. Both required. »
  </behavior>
  <action>
    **Step A**: Create `services/backend/app/models/lucidity/` directory. Create `__init__.py`:
    ```python
    """Phase mint-calc-engine-v1 — D-CE-15 typed lucidity payloads.

    L1-L4 discriminated union. extra=forbid kills paraphrase ranking creep at type level.
    """
    from app.models.lucidity._payload import (
        LucidityLevel,
        L1ChiffrePayload,
        L2ComparePayload,
        L3EclairePayload,
        L4InvariantPayload,
        LucidityPayload,
    )

    __all__ = [
        "LucidityLevel",
        "L1ChiffrePayload",
        "L2ComparePayload",
        "L3EclairePayload",
        "L4InvariantPayload",
        "LucidityPayload",
    ]
    ```

    **Step B**: Create `services/backend/app/models/lucidity/_payload.py` matching RESEARCH §Q-C lines 475-568 VERBATIM. Use exact `model_validator(mode="after")` signature for parity check. Use exact ValueError message format:
    ```
    "L2 narrative length parity violated : scenario[{i}] = {ln} chars, "
    "avg = {avg:.0f}, max delta = {0.15 * avg:.0f}. "
    "All scenarios must be within ±15% of avg character count "
    "(D-CE-15 narrative parity validator)."
    ```

    **Step C**: Write `services/backend/tests/test_lucidity_payloads.py` with the 10 tests from `<behavior>` block. Use `pytest.raises(ValidationError)` from `pydantic`.

    LSFin in test fixtures:
    - L4 valid example: `condition_text_fr="Quel que soit le scénario d'investissement, ta capacité d'emprunt reste plafonnée à 33% du revenu brut selon la LCC art. 28."`
    - L2 valid scenarios: `[{"label_fr": "Scénario A", "narrative_fr": "Tu pourrais envisager d'utiliser X CHF en 3a.", "value": 7000, "citation_key": "tool_pillar3a"}, {"label_fr": "Scénario B", "narrative_fr": "Tu pourrais envisager d'utiliser X CHF en LPP.", "value": 7000, "citation_key": "tool_lpp"}]`
    - NEVER use « optimal / meilleur / garanti / recommandé / certain / assuré / sans risque / parfait » in any test fixture.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_lucidity_payloads.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `services/backend/app/models/lucidity/_payload.py` exists, ≥100 lines
    - `grep -c "class L[1-4].*Payload" services/backend/app/models/lucidity/_payload.py` returns 4
    - `grep -c "extra=\"forbid\"" services/backend/app/models/lucidity/_payload.py` returns ≥1 (in `_LucidityBase.model_config`)
    - `grep -c "_enforce_narrative_length_parity" services/backend/app/models/lucidity/_payload.py` returns ≥1
    - `python3 -c "from app.models.lucidity import L1ChiffrePayload, L2ComparePayload, L3EclairePayload, L4InvariantPayload, LucidityPayload; print('OK')"` exits 0
    - `python3 -c "from app.models.lucidity import L2ComparePayload; from pydantic import ValidationError; import pytest;
      try:
          L2ComparePayload.model_validate({'level': 'L2', 'scenarios': [{'label_fr': 'A', 'value': 1, 'narrative_fr': 'aaaa'*10, 'citation_key': 'k'}, {'label_fr': 'B', 'value': 2, 'narrative_fr': 'bbbb'*10, 'citation_key': 'k'}], 'recommended_option': 'A'})
      except ValidationError as e:
          assert 'extra' in str(e).lower() or 'not permitted' in str(e).lower()
          print('PASS')"` prints `PASS`
    - `cd services/backend && python3 -m pytest tests/test_lucidity_payloads.py -q -x` exits 0 with 10 tests passed
    - `python3 tools/checks/banned_terms_python.py services/backend/app/models/lucidity/_payload.py services/backend/tests/test_lucidity_payloads.py` exits 0
    - `python3 tools/checks/accent_lint_fr.py --scope backend 2>&1 | grep lucidity | grep -i error` returns 0
  </acceptance_criteria>
  <done>L1-L4 payloads + 10 tests green. recommended_option-equivalents structurally impossible.</done>
</task>

<task id="W1-04-04" type="auto" tdd="true">
  <name>Task 2: L4 wedge endpoint (Finding 5: 33% LCC mortgage cap invariant)</name>
  <files>services/backend/app/api/v1/endpoints/lucidity.py, services/backend/app/api/v1/routes.py, services/backend/tests/test_l4_invariant_endpoint.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Finding 5 (L4 wedge rationale)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §4-level lucidité framework table (L4 row)
    - services/backend/app/api/v1/routes.py (router registration pattern)
    - services/backend/app/api/v1/endpoints/coach_chat.py (router precedent — header imports + tag pattern)
    - services/backend/app/models/lucidity/_payload.py (just created)
    - docs/AGENTS/swiss-brain.md (LSFin banned terms + lucidité grammar)
  </read_first>
  <behavior>
    - **Test 1**: `GET /api/v1/lucidity/invariants/mortgage-cap` returns 200 with JSON `{"level": "L4", "legalArticleRef": "LCC art. 28", "conditionTextFr": "..."}`.
    - **Test 2**: Response body validates against `L4InvariantPayload.model_validate(response.json())` — proves schema round-trip.
    - **Test 3**: Response `conditionTextFr` does NOT contain any banned LSFin term (manually grep for « optimal / meilleur / garanti / recommandé / certain / assuré / sans risque / parfait » in test assertion).
    - **Test 4**: Endpoint requires authentication (`Depends(require_current_user)`). Anonymous request returns 401.
    - **Test 5**: Anonymous client without auth header returns 401 (Spoofing guard).
  </behavior>
  <action>
    **Step A**: Create `services/backend/app/api/v1/endpoints/lucidity.py`:
    ```python
    """Phase mint-calc-engine-v1 W1 — Finding 5 L4 invariant wedge endpoint.

    L4 = surfacer les invariants. The « thing nobody tells you ».
    Doctrinally aligned with docs/MINT_IDENTITY.md « Mint te dit ce que personne n'a intérêt à te dire ».
    LSFin-safest layer (pure information générale + legal article ref).
    """
    from fastapi import APIRouter, Depends

    from app.core.auth import require_current_user
    from app.models.lucidity import L4InvariantPayload
    from app.models.user import User


    router = APIRouter(prefix="/lucidity", tags=["lucidity"])


    @router.get("/invariants/mortgage-cap", response_model=L4InvariantPayload)
    def lucidity_invariant_mortgage_cap(
        _user: User = Depends(require_current_user),
    ) -> L4InvariantPayload:
        """L4 wedge: 33% LCC mortgage-cap invariant.

        Returns the canonical FR condition text + LCC art. 28 reference.
        No user-profile input needed — this is information générale.
        """
        return L4InvariantPayload(
            legal_article_ref="LCC art. 28",
            condition_text_fr=(
                "Quel que soit le scénario d'investissement, "
                "ta capacité d'emprunt hypothécaire reste plafonnée à "
                "33% de tes revenus bruts annuels selon la LCC art. 28 "
                "(taux d'intérêt théorique 5% pour le calcul de la charge)."
            ),
        )
    ```

    **Step B**: Register the router in `services/backend/app/api/v1/routes.py`:
    ```python
    from app.api.v1.endpoints import lucidity as lucidity_endpoints
    api_router.include_router(lucidity_endpoints.router)
    ```

    Find the existing `include_router` pattern in routes.py and follow it (surgical change — append one line).

    **Step C**: Write `services/backend/tests/test_l4_invariant_endpoint.py` with the 5 tests from `<behavior>`. Use authenticated TestClient fixture (any existing one, doesn't need blank-profile variant).

    LSFin compliance in the endpoint body text:
    - « Quel que soit » → ok (frame-agnostic across 18 life events, per CLAUDE.md rule 3).
    - « plafonnée à 33% » → ok (regulatory ceiling, factual).
    - « selon la LCC art. 28 » → ok (legal article reference, REQUIRED for L4).
    - « taux théorique 5% » → ok (regulatory constant).
    - NO « optimal / meilleur / garanti / recommandé ».
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_l4_invariant_endpoint.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `services/backend/app/api/v1/endpoints/lucidity.py` exists with `router = APIRouter(prefix="/lucidity", ...)` + `@router.get("/invariants/mortgage-cap")` handler
    - `grep -c "include_router.*lucidity" services/backend/app/api/v1/routes.py` returns ≥1
    - `cd services/backend && python3 -m pytest tests/test_l4_invariant_endpoint.py -q -x` exits 0 with 5 tests passed
    - Manual banned-term scan on endpoint body text: `grep -E "optimal|meilleur|garanti|recommandé|certain|assuré|sans risque|parfait" services/backend/app/api/v1/endpoints/lucidity.py` returns 0 matches
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/lucidity.py services/backend/tests/test_l4_invariant_endpoint.py` exits 0
    - `python3 tools/checks/accent_lint_fr.py --scope backend 2>&1 | grep lucidity` returns 0 errors (« plafonné », « théorique », « scénario », « capacité » all need accents)
  </acceptance_criteria>
  <done>L4 wedge endpoint live. Proof-of-concept that L1-L4 contracts work end-to-end. 5 tests green.</done>
</task>

<task id="W1-04-99" type="auto" tdd="false">
  <name>Task 3: Full suite + manual L4-tone review checkpoint flag</name>
  <files>(verification only)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md § Manual-Only Verifications
  </read_first>
  <action>
    Full suite + lints. Engram save:
    - `topic_key: calc_engine:w1:lucidity_payloads_l4_wedge`
    - `type: architecture`
    - `prior_finding_refs: [Plan 01 obs_id, panel synthesis #103, Finding 5 from CONTEXT.md]`
    - Content: « L1-L4 typed payloads shipped at `app.models.lucidity._payload`. recommended_option-equivalents structurally impossible (extra=forbid + 6 forbidden field names tested). L4 wedge endpoint live at `/api/v1/lucidity/invariants/mortgage-cap` per Finding 5. W2 compute services may now emit `data["lucidity"]: <Payload>.model_dump()` within `CoachToolOk.data`. »

    Flag for human review (VALIDATION.md manual-only verification): « L4 invariant FR tone needs Julien sign-off — does the « 33% LCC plafond » phrasing sound like Mint (legal + plain FR + non-promissory) ? Open a discussion or include in next sim G2 walkthrough. »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite exits 0
    - Pytest passed count ≥ Plan 03 baseline + 15 (10 payload + 5 endpoint)
    - Engram saved with prior_finding_refs
    - Manual-review flag captured in SUMMARY.md
  </acceptance_criteria>
  <done>L4 wedge live + payloads complete + tone review queued for Julien</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Client → /lucidity/invariants/mortgage-cap | Untrusted user; authenticated only |
| Calc service → narrator (W2+) | Lucidity payload emitted with `extra="forbid"` — structural ranking guard |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-04-01 | LSFin compliance | L2/L3 ranking creep | mitigate | `extra="forbid"` + frozen=True on `_LucidityBase`. Forbidden field names structurally rejected at `model_validate` time. D-CE-16(a) schema layer. Test 1-2 of W1-04-01 prove. |
| T-mint-calc-04-02 | LSFin compliance | banned terms in narrative_fr | accept | Schema doesn't enforce banned-term scan on free-text fields. D-CE-16(b)+(c) lint + runtime gate ship in W4 plans 02. Documented in Test 10 comment. |
| T-mint-calc-04-03 | Information disclosure | L4 endpoint | accept | Returns information générale only (LCC art. 28 + 33% plafond). No user-profile data. Spoofing-resistant via `Depends(require_current_user)`. |
| T-mint-calc-04-04 | Spoofing | unauthenticated GET | mitigate | `Depends(require_current_user)` — 401 on missing/invalid JWT. Test 4 of W1-04-04 covers. |
| T-mint-calc-04-05 | Tampering | narrative-length parity bypass | mitigate | `@model_validator(mode="after")` runs after individual field validation. Cannot be skipped by partial payload. ±15% threshold enforced before `data["lucidity"]` leaves calc service. |
| T-mint-calc-04-06 | Repudiation | citation_key | mitigate | All L1/L2 scenarios require `citation_key: str` (closed-world Phase 94 vocabulary). |
</threat_model>

<verification>
- 15 tests green (10 payload schema + 5 L4 endpoint)
- L4 wedge endpoint live and authenticated
- Lints clean on touched files
- Manual-review flag: Julien tone sign-off queued
</verification>

<success_criteria>
- `from app.models.lucidity import L1ChiffrePayload, L2ComparePayload, L3EclairePayload, L4InvariantPayload, LucidityPayload` succeeds
- `L2ComparePayload.model_validate({..., "recommended_option": "A"})` raises ValidationError (schema-impossibility proof)
- `GET /api/v1/lucidity/invariants/mortgage-cap` returns valid L4InvariantPayload with `legalArticleRef="LCC art. 28"`
- Engram observation linking Plan 01 obs + #103 panel synthesis
</success_criteria>

<risks>
- **Narrative-length parity threshold tuning.** ±15% may be too tight or too loose. The threshold ships at 0.15 per CONTEXT.md ; if W2 starts emitting real L2 payloads and the validator throws too often, raise to 0.20 in a follow-up plan. NOT changed in W1.
- **L4 endpoint authentication.** `require_current_user` is mandatory per Threat T-04-04 — but if Julien wants the L4 wedge available pre-onboarding (« public information générale »), revise to optional auth. For now: auth required to keep consistent with the rest of the API surface.
- **Pydantic v2 `extra="forbid"` quirks.** `model_validate` validates extras ; direct kwargs construction (`L2ComparePayload(level="L2", scenarios=[...], recommended_option="A")`) raises a different TypeError (kwargs validation). Tests MUST use `model_validate({...dict...})` to hit the schema-impossibility path. Documented in RESEARCH §Q-C.
- **L4 condition_text_fr length.** `min_length=20` may force overly-verbose text in future invariants. Acceptable for v1 (the « 33% LCC plafond » text is 200+ chars).
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-04-w1-lucidity-payloads-SUMMARY.md`. Include:
- Engram obs_id
- L1-L4 payload shipping confirmation
- L4 wedge endpoint URL + sample response
- Julien manual-review flag for tone (queued, not blocking)
</output>
