---
phase: mint-calc-engine-v1
plan: 02
wave: 1
title: W1 — Priority-1 sev-3 endpoint grounding fix (allocation_annuelle + affordability + rachat_echelonne)
type: execute
depends_on: [01]
files_modified:
  - services/backend/app/api/v1/endpoints/arbitrage.py
  - services/backend/app/api/v1/endpoints/mortgage.py
  - services/backend/app/api/v1/endpoints/lpp_deep.py
  - services/backend/app/schemas/arbitrage.py
  - services/backend/app/schemas/mortgage.py
  - services/backend/app/schemas/lpp_deep.py
  - services/backend/tests/test_arbitrage_allocation_annuelle_grounding.py
  - services/backend/tests/test_mortgage_affordability_grounding.py
  - services/backend/tests/test_lpp_rachat_echelonne_grounding.py
autonomous: true
requirements: [D-CE-06, D-CE-07, D-CE-08]
estimated_duration: 6
must_haves:
  truths:
    - "POST /api/v1/arbitrage/allocation-annuelle reads `_user.profile` for canton, is_property_owner, taux_hypothecaire, rendement_3a — no more silent hardcoded defaults"
    - "POST /api/v1/mortgage/affordability reads `_user.profile` for canton, current_mortgage_rate, debt_load — explicit-None body override preserved"
    - "POST /api/v1/lpp-deep/rachat-echelonne returns 422 with CoachToolIncomplete envelope when profile canton missing (instead of crashing or silently using VD)"
  artifacts:
    - path: services/backend/app/api/v1/endpoints/arbitrage.py
      provides: "allocation_annuelle endpoint patched with Depends(get_profile_filled) + _resolve_defaults + raise_incomplete_as_422"
      contains: "Depends(get_profile_filled)"
    - path: services/backend/app/schemas/arbitrage.py
      provides: "AllocationAnnuelleRequest schema with json_schema_extra={'from_profile': '...'} markers on canton, is_property_owner, taux_hypothecaire, rendement_3a"
      contains: "from_profile"
    - path: services/backend/app/schemas/lpp_deep.py
      provides: "RachatEchelonneRequest schema with from_profile marker on canton + income_yearly"
      contains: "from_profile"
    - path: services/backend/tests/test_arbitrage_allocation_annuelle_grounding.py
      provides: "Contract test asserting blank-profile yields 422 + asserting profile.canton populates resolved kwargs"
      min_lines: 60
  key_links:
    - from: services/backend/app/api/v1/endpoints/arbitrage.py
      to: services/backend/app/core/profile_resolver.py
      via: "from app.core.profile_resolver import _resolve_defaults, get_profile_filled, raise_incomplete_as_422"
      pattern: "from app.core.profile_resolver import"
    - from: services/backend/app/api/v1/endpoints/arbitrage.py
      to: services/backend/app/services/arbitrage/allocation_annuelle.py
      via: "compute_allocation_annuelle(**resolved) — wraps existing financial_core helper, NEVER re-implements"
      pattern: "compute_allocation_annuelle"
---

<objective>
Ship the W0 Priority-1 sev-3 grounding fixes for the 3 highest-traffic / highest-severity endpoints. These ship FIRST because they are incident-level (per W0-AUDIT-MATRIX.md § Recommended Fix Priority Order line 220-227) — `allocation_annuelle` silently disables amortissement indirect for property owners, `affordability_service` produces wrong debt service against 2.8% fixed mortgages with hardcoded 1.5% SARON, `rachat_echelonne_service` crashes or returns wrong tax brackets for non-VD users.

Purpose: D-CE-06 server-side enforcement + D-CE-07 schema-marker pattern + D-CE-08 422 envelope. Closes the « ~15-30% wrong tax brackets by canton » incident (per CONTEXT counter-argument 1).

Output: 3 patched endpoint handlers + 3 schema updates with `json_schema_extra={"from_profile": ...}` markers + 3 contract tests using `client_with_blank_profile` (Concern D).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md
@.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md

# Existing source-of-truth helpers — financial_core SoT, NEVER re-implement
@services/backend/app/services/arbitrage/allocation_annuelle.py
@services/backend/app/services/mortgage/affordability_service.py
@services/backend/app/services/lpp_deep/rachat_echelonne_service.py
@services/backend/app/core/profile_resolver.py
@services/backend/app/api/v1/endpoints/arbitrage.py
</context>

<interfaces>
<!-- Source-of-truth helpers extracted from RESEARCH §Q-B + W0-AUDIT-MATRIX -->

From services/backend/app/core/profile_resolver.py (Plan 01):
```python
def _resolve_defaults(profile_data: dict[str, Any] | None, body: BaseModel, schema_class: type[BaseModel]) -> dict[str, Any]: ...
def _required_profile_fields_missing(resolved: dict[str, Any], schema_class: type[BaseModel]) -> list[str]: ...
def raise_incomplete_as_422(missing_fields: list[str], hint_fr: str) -> NoReturn: ...
def get_profile_filled(user=Depends(require_current_user), db=Depends(get_db)) -> dict[str, Any]: ...
```

From W0-AUDIT-MATRIX § Recommended Fix Priority Order:
```
Priority 1 — BLOCKING:
  1. allocation_annuelle (sev 2, high traffic) — line 194-227 hardcoded defaults
  2. affordability_service (sev 1, high traffic) — taux_hypothecaire=0.015 SARON hardcoded
  3. rachat_echelonne_service (sev 3, medium traffic) — null canton crash or wrong VD default
```

From services/backend/app/services/arbitrage/allocation_annuelle.py (verified W0 audit line 194-227):
```python
def compute_allocation_annuelle(
    montant_disponible: float,
    canton: str = "VD",                        # ← hardcoded — fix target
    is_property_owner: bool = False,           # ← hardcoded — fix target
    taux_hypothecaire: float = 0.015,          # ← hardcoded — fix target
    rendement_3a: float = 0.02,                # ← hardcoded — fix target
    ...
) -> AllocationResult: ...
```

The endpoint handler MUST wrap this existing helper via `_resolve_defaults` — NEVER re-implement the compute math (CLAUDE.md §1 + Karpathy #3).
</interfaces>

<tasks>

<task id="W1-02-00" type="auto" tdd="false">
  <name>Task 0: Per-wave spot-check (D-CE-20) + read existing endpoint shape</name>
  <files>(read-only)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md § Recommended Fix Priority Order
    - services/backend/app/api/v1/endpoints/arbitrage.py:163-213 (current allocation_annuelle handler)
    - services/backend/app/api/v1/endpoints/mortgage.py (affordability handler)
    - services/backend/app/api/v1/endpoints/lpp_deep.py (rachat-echelonne handler)
    - services/backend/app/services/arbitrage/allocation_annuelle.py:185-230 (defaults)
    - services/backend/app/services/mortgage/affordability_service.py (HYPOTHEQUE_TAUX_THEORIQUE constant location)
    - services/backend/app/services/lpp_deep/rachat_echelonne_service.py:58-65 (canton-dependent tax brackets)
  </read_first>
  <action>
    Per D-CE-20 per-wave deepening: spot-validate 3 things before patching:
    1. **Endpoint signatures are still wired** — `grep -n "allocation-annuelle\|allocation_annuelle" services/backend/app/api/v1/routes.py services/backend/app/api/v1/endpoints/arbitrage.py | head -5` (CONTEXT data gap: verify they aren't deprecated/unrouted).
    2. **Existing schemas have NO `from_profile` markers yet** — `grep -rn "from_profile" services/backend/app/schemas/ | wc -l` should return `0` baseline.
    3. **Current default values match W0 audit** — `grep -A2 "def compute_allocation_annuelle" services/backend/app/services/arbitrage/allocation_annuelle.py | head -10` confirms canton="VD" + is_property_owner=False are still the live defaults (CONTEXT data gap #4).

    Engram check (D-CE-20): `mem_search "calc_engine:audit_hypothesis_c:allocation_annuelle"` — load prior W0 observation, cite `obs_id` in this plan's findings.

    Output: a brief 3-bullet note INLINE in the SUMMARY.md of this plan confirming the spot-check + any drift discovered. If drift > 0 (e.g. endpoint deprecated since W0 audit), raise to orchestrator before patching.
  </action>
  <verify>
    <automated>grep -c "allocation-annuelle" services/backend/app/api/v1/endpoints/arbitrage.py</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "allocation-annuelle" services/backend/app/api/v1/endpoints/arbitrage.py` returns ≥1 (endpoint still routed)
    - `grep -rn "from_profile" services/backend/app/schemas/` returns 0 matches BEFORE this plan (baseline confirmation)
    - Current defaults still match W0 audit: `grep -E 'canton.*=.*"VD"' services/backend/app/services/arbitrage/allocation_annuelle.py` returns ≥1 line
    - Engram `prior_finding_refs` candidate IDs captured: at minimum #104 (W0 audit allocation_annuelle row), #103 (panel synthesis)
  </acceptance_criteria>
  <done>Spot-check complete, no drift surfaced, ready to patch</done>
</task>

<task id="W1-02-01" type="auto" tdd="true">
  <name>Task 1: allocation_annuelle endpoint grounded + contract test</name>
  <files>services/backend/app/api/v1/endpoints/arbitrage.py, services/backend/app/schemas/arbitrage.py, services/backend/tests/test_arbitrage_allocation_annuelle_grounding.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-B Endpoint integration pattern (lines 411-450)
    - services/backend/app/api/v1/endpoints/arbitrage.py (full file — understand existing handlers + router structure)
    - services/backend/app/schemas/arbitrage.py (current AllocationAnnuelleRequest)
    - services/backend/app/core/profile_resolver.py (helpers from Plan 01)
  </read_first>
  <behavior>
    - Test 1 (RED → GREEN): With `client_with_blank_profile`, `POST /api/v1/arbitrage/allocation-annuelle` body `{"montant_disponible": 10000}` returns HTTP 422 with JSON `{"detail": {"status": "incomplete", "missingFields": ["canton", "is_property_owner", ...], "hintFr": "..."}}` (camelCase aliases).
    - Test 2 (RED → GREEN): With profile `{"canton": "GE", "is_property_owner": true, "taux_hypothecaire": 0.028, "rendement_3a": 0.02}` and body `{"montant_disponible": 10000}`, the endpoint returns 200 + the response uses **canton=GE** (NOT hardcoded VD). Assertion: `response.json()["meta"]["canton_used"] == "GE"` OR equivalent surface in the existing response model. If response model doesn't currently expose canton, add a 1-line `meta: {...}` field to the response schema for traceability.
    - Test 3: When body explicitly sends `{"canton": null}`, body wins — endpoint returns 422 (explicit clear) NOT silent fallback to profile canton.
    - Test 4: When body explicitly sends `{"canton": "VD"}` and profile is `{"canton": "GE"}`, body wins — endpoint computes with canton=VD.
  </behavior>
  <action>
    **Step A: Patch schema.** Open `services/backend/app/schemas/arbitrage.py`. Find `AllocationAnnuelleRequest` (or whatever the canonical request schema is named). Add `json_schema_extra` markers per D-CE-07:

    ```python
    from typing import Optional
    from pydantic import BaseModel, Field

    class AllocationAnnuelleRequest(BaseModel):
        montant_disponible: float = Field(..., gt=0)
        canton: Optional[str] = Field(default=None, json_schema_extra={"from_profile": "canton"})
        is_property_owner: Optional[bool] = Field(default=None, json_schema_extra={"from_profile": "is_property_owner"})
        taux_hypothecaire: Optional[float] = Field(default=None, json_schema_extra={"from_profile": "mortgage_rate_current"})
        rendement_3a: Optional[float] = Field(default=None, json_schema_extra={"from_profile": "pillar3a_expected_yield"})
    ```

    Profile-key names (`"canton"`, `"is_property_owner"`, `"mortgage_rate_current"`, `"pillar3a_expected_yield"`) MUST match the canonical `_PROFILE_SAFE_FIELDS` list at `services/backend/app/api/v1/endpoints/coach_chat.py:875`. If the canonical keys differ, USE THE CANONICAL ONES (grep `_PROFILE_SAFE_FIELDS` to verify).

    **Step B: Patch endpoint handler.** Open `services/backend/app/api/v1/endpoints/arbitrage.py`. Find the existing handler for `/allocation-annuelle`. Replace its body with the RESEARCH §Q-B Endpoint integration pattern:

    ```python
    from app.core.profile_resolver import (
        _resolve_defaults,
        _required_profile_fields_missing,
        get_profile_filled,
        raise_incomplete_as_422,
    )
    from app.schemas.arbitrage import AllocationAnnuelleRequest

    @router.post("/allocation-annuelle", response_model=AllocationAnnuelleResponse)
    def arbitrage_allocation_annuelle(
        request: Request,
        body: AllocationAnnuelleRequest,
        _user: User = Depends(require_current_user),
        profile_data: dict = Depends(get_profile_filled),
    ) -> AllocationAnnuelleResponse:
        resolved = _resolve_defaults(profile_data, body, AllocationAnnuelleRequest)
        missing = _required_profile_fields_missing(resolved, AllocationAnnuelleRequest)
        if missing:
            raise_incomplete_as_422(
                missing_fields=missing,
                hint_fr=(
                    "Pour calculer ton allocation annuelle, j'ai besoin de ton canton, "
                    "de savoir si tu es propriétaire et de ton taux hypothécaire actuel. "
                    "Tu peux me les partager ?"
                ),
            )
        result = compute_allocation_annuelle(**resolved)
        return _result_to_response(result, AllocationAnnuelleResponse)
    ```

    PRESERVE existing rate-limiting decorators (`@limiter.limit("X/minute")`), preserve any existing Sentry breadcrumb emission. Surgical change rule (Karpathy #3) — ONLY swap the args-resolution block.

    DO NOT touch `services/backend/app/services/arbitrage/allocation_annuelle.py` — CLAUDE.md §1 financial_core SoT, the compute math stays untouched.

    **Step C: Write contract test.** Create `services/backend/tests/test_arbitrage_allocation_annuelle_grounding.py` with the 4 tests from `<behavior>`. Use `client_with_blank_profile` fixture (Plan 01) + a sister fixture that creates a user with populated profile.

    LSFin: hint_fr uses « pourrait / envisager » vocabulary only, no « optimal / meilleur / garanti / recommandé ».
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_arbitrage_allocation_annuelle_grounding.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "json_schema_extra={\"from_profile\"" services/backend/app/schemas/arbitrage.py` returns ≥4 (one per profile field)
    - `grep -c "Depends(get_profile_filled)" services/backend/app/api/v1/endpoints/arbitrage.py` returns ≥1
    - `grep -c "from app.core.profile_resolver import" services/backend/app/api/v1/endpoints/arbitrage.py` returns 1
    - `cd services/backend && python3 -m pytest tests/test_arbitrage_allocation_annuelle_grounding.py -q -x` exits 0 with 4 tests passed
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/arbitrage.py services/backend/app/schemas/arbitrage.py` exits 0
    - `python3 tools/checks/accent_lint_fr.py --scope backend 2>&1 | grep arbitrage | grep -i error` returns 0 hits
    - No re-implementation of compute math: `git diff services/backend/app/services/arbitrage/allocation_annuelle.py` returns empty (file untouched)
  </acceptance_criteria>
  <done>allocation_annuelle endpoint grounded + 4 contract tests green + financial_core SoT preserved</done>
</task>

<task id="W1-02-02" type="auto" tdd="true">
  <name>Task 2: affordability_service endpoint grounded + contract test</name>
  <files>services/backend/app/api/v1/endpoints/mortgage.py, services/backend/app/schemas/mortgage.py, services/backend/tests/test_mortgage_affordability_grounding.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md row 7 (affordability_service)
    - services/backend/app/api/v1/endpoints/mortgage.py (current handler for /affordability)
    - services/backend/app/schemas/mortgage.py (current AffordabilityRequest)
    - services/backend/app/services/mortgage/affordability_service.py (constants HYPOTHEQUE_TAUX_THEORIQUE + HYPOTHEQUE_RATIO_CHARGES_MAX)
    - services/backend/app/core/profile_resolver.py
  </read_first>
  <behavior>
    - Test 1: `POST /api/v1/mortgage/affordability` with blank profile + body lacking canton + current_mortgage_rate → 422 with CoachToolIncomplete envelope.
    - Test 2: Profile has `{"canton": "GE", "mortgage_rate_current": 0.028}` + body `{"property_price": 800000, "down_payment": 200000}` → 200, response computed with GE rules + 2.8% rate. Assertion: response contains a `_meta.computed_with` field listing `["canton:GE", "rate:0.028"]` (add 1-line meta block if not present).
    - Test 3: HYPOTHEQUE_TAUX_THEORIQUE constant stays untouched in the service file — that's a regulatory constant, NOT a user-profile field.
  </behavior>
  <action>
    Same pattern as Task 1, applied to `affordability_service` endpoint:

    1. Identify the affordability endpoint handler in `services/backend/app/api/v1/endpoints/mortgage.py`.
    2. Add `from_profile` markers to `AffordabilityRequest` in `services/backend/app/schemas/mortgage.py` for: `canton`, `current_mortgage_rate` (profile key: `mortgage_rate_current` — verify against `_PROFILE_SAFE_FIELDS`), `existing_debt` (profile key: `debt_total_outstanding` — verify).
    3. Wrap handler with `Depends(get_profile_filled)` + `_resolve_defaults` + `_required_profile_fields_missing` + `raise_incomplete_as_422`.
    4. Hint FR: « Pour estimer ta capacité d'achat, j'ai besoin de ton canton et de ton taux hypothécaire actuel. Tu peux me les partager ? » (LSFin-safe: no « optimal / meilleur »).
    5. PRESERVE the HYPOTHEQUE_TAUX_THEORIQUE = 0.05 constant in `affordability_service.py` — that's the regulatory theoretical rate (LCC art. 28), NOT a user-overridable field. `taux_theorique` field on the schema is NOT a profile-grounded field; do NOT mark it `from_profile`.
    6. Contract test file as `services/backend/tests/test_mortgage_affordability_grounding.py` with the 3 tests.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_mortgage_affordability_grounding.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "json_schema_extra={\"from_profile\"" services/backend/app/schemas/mortgage.py` returns ≥2 (canton + at least one mortgage-rate field)
    - `grep -c "HYPOTHEQUE_TAUX_THEORIQUE" services/backend/app/services/mortgage/affordability_service.py` returns ≥1 (constant preserved)
    - `cd services/backend && python3 -m pytest tests/test_mortgage_affordability_grounding.py -q -x` exits 0
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/mortgage.py services/backend/app/schemas/mortgage.py` exits 0
  </acceptance_criteria>
  <done>affordability endpoint grounded, regulatory constants preserved, 3 contract tests green</done>
</task>

<task id="W1-02-03" type="auto" tdd="true">
  <name>Task 3: rachat_echelonne_service endpoint grounded + contract test (sev-3)</name>
  <files>services/backend/app/api/v1/endpoints/lpp_deep.py, services/backend/app/schemas/lpp_deep.py, services/backend/tests/test_lpp_rachat_echelonne_grounding.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md row 14 (sev-3 — canton-dependent tax brackets crash or wrong VD)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-B (the rachat_echelonne example, lines 414-450)
    - services/backend/app/api/v1/endpoints/lpp_deep.py
    - services/backend/app/schemas/lpp_deep.py
    - services/backend/app/services/lpp_deep/rachat_echelonne_service.py:58-65 (canton-dependent CANTON_RACHAT_BRACKETS lookup)
  </read_first>
  <behavior>
    - Test 1 (sev-3 incident reproduction): `POST /api/v1/lpp-deep/rachat-echelonne` with blank profile + body `{"montant_rachat": 50000}` → 422 (NOT a 500 crash, NOT a silent VD default).
    - Test 2: Profile `{"canton": "GE", "salary_gross_yearly": 120000, "age": 45}` + body `{"montant_rachat": 50000}` → 200 with response computing GE-specific tax brackets (NOT VD). Verify by asserting response.json contains a citation key referencing GE tax law OR a `_meta.tax_jurisdiction: "GE"` field.
    - Test 3: Profile lacks `salary_gross_yearly` → 422 with `missingFields` listing `salary_gross_yearly` (or whatever the canonical profile key is).
    - Test 4 (regression guard): Profile with `canton: null` + body with `canton: null` → 422, NOT a 500 crash from `CANTON_RACHAT_BRACKETS[None]` KeyError.
  </behavior>
  <action>
    Apply same pattern. Specific notes:

    1. `RachatEchelonneRequest` schema in `services/backend/app/schemas/lpp_deep.py`: add `from_profile` markers for `canton`, `age`, `salary_yearly` (profile key: `salary_gross_yearly` — verify), `marital_status` (if used in tax bracket lookup).
    2. Endpoint handler in `services/backend/app/api/v1/endpoints/lpp_deep.py`: wrap with `Depends(get_profile_filled)`.
    3. Hint FR: « Pour estimer ton rachat LPP étalonné, j'ai besoin de ton canton, ton âge, et ton revenu annuel imposable. » (no banned terms).
    4. The compute helper `compute_rachat_echelonne` (or `simulate_rachat_echelonne` — grep to confirm exact name) stays untouched. The `_resolve_defaults` output dict is splatted into `**resolved`.
    5. Contract test file `services/backend/tests/test_lpp_rachat_echelonne_grounding.py` with the 4 tests.
    6. Test 4 is the **null-canton crash regression guard** — explicitly assert the endpoint returns 422 (not 500). This is the sev-3 incident class.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_lpp_rachat_echelonne_grounding.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `grep -c "json_schema_extra={\"from_profile\"" services/backend/app/schemas/lpp_deep.py` returns ≥2
    - `cd services/backend && python3 -m pytest tests/test_lpp_rachat_echelonne_grounding.py -q -x` exits 0 with 4 tests passed
    - Sev-3 regression guard: `cd services/backend && python3 -m pytest tests/test_lpp_rachat_echelonne_grounding.py::test_null_canton_returns_422_not_500 -q -x` exits 0
    - `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/lpp_deep.py services/backend/app/schemas/lpp_deep.py` exits 0
    - Service file untouched: `git diff services/backend/app/services/lpp_deep/rachat_echelonne_service.py` returns empty
  </acceptance_criteria>
  <done>Sev-3 incident closed: rachat_echelonne returns 422 instead of crash/wrong-VD. 4 tests green.</done>
</task>

<task id="W1-02-99" type="auto" tdd="false">
  <name>Task 4: Full suite + lints + engram save (W1 PR-1 close-out)</name>
  <files>(verification only)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Memory Contract (Concern F)
    - .planning/STATE.md (baseline pytest count)
  </read_first>
  <action>
    Run full suite + lints + Maestro G1 (optional smoke flow for staging-ready PR).

    Engram save:
    - `topic_key: calc_engine:w1:priority1_endpoints_grounded`
    - `type: bugfix`
    - `prior_finding_refs: [#104 W0 audit allocation_annuelle row, W0 audit rachat_echelonne row, #103 panel synthesis, Plan 01 obs_id from W1-01-99]`
    - Content: « 3 Priority-1 sev-3 endpoints grounded via `_resolve_defaults`. sev-3 null-canton crash closed for `rachat_echelonne`. 12 sev-3 endpoints total (per W0 audit) — 3 down, 9 to go (Plans 03 + 06). »

    Update `.planning/STATE.md`'s `last_activity` line to: `2026-XX-XX — Wave mint-calc-engine-v1 Plan 02 PR opened (Priority-1 sev-3 endpoints grounded)`.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite exits 0
    - Pytest passed count ≥ Plan 01 baseline + 11 new (4+3+4)
    - Lints clean: `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/ services/backend/app/schemas/` exits 0
    - Accent FR clean: `python3 tools/checks/accent_lint_fr.py --scope backend 2>&1 | grep -iE "endpoints/(arbitrage|mortgage|lpp_deep)" | grep -i error` returns 0 hits
    - Engram observation saved with prior_finding_refs
  </acceptance_criteria>
  <done>W1 Plan 02 closes with all gates green. Ready for PR open.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Client → REST endpoint body | Body crosses untrusted boundary; explicit-null vs omitted distinction is the security-relevant signal |
| `_resolve_defaults` → service compute fn | Resolved dict splat (`**resolved`) — argument names must match service signature exactly or call fails |
| Profile data → tax bracket lookup | Canton string used as dict key in service-layer constants (e.g. `CANTON_RACHAT_BRACKETS[canton]`) — invalid value = KeyError |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-02-01 | Tampering | body.canton override | mitigate | `_resolve_defaults` honors explicit-None as « clear » — attacker cannot silently force fallback to profile by omitting field. Test 3 of W1-02-01 covers. |
| T-mint-calc-02-02 | Information disclosure | financial calc output | accept | Compute helpers (`compute_allocation_annuelle`, etc.) read ONLY the authenticated user's profile via `get_profile_filled` filter on `user_id`. No cross-user data path. |
| T-mint-calc-02-03 | Denial of service | invalid canton string | mitigate | `_required_profile_fields_missing` catches None canton → 422 BEFORE the service layer's `CANTON_BRACKETS[canton]` lookup. Sev-3 crash class closed. Test 4 of W1-02-03 is the regression guard. |
| T-mint-calc-02-04 | LSFin compliance | hint_fr French text | mitigate | All 3 hint_fr fixtures use « pourrait / envisager / partager » vocabulary. `banned_terms_python.py` lint runs on touched files. |
| T-mint-calc-02-05 | LSFin compliance | ranking creep | accept | This plan only patches endpoint args resolution. L2/L3 ranking-field forbid is W1-04. No new ranking surface introduced. |
| T-mint-calc-02-06 | Repudiation | profile-override traceability | mitigate | Optional `_meta.computed_with` field on response shows resolved canton + rates. Audit trail for « which profile field drove this calc » (informational, no PII). |
| T-mint-calc-02-07 | Elevation of privilege | endpoint auth | accept | `Depends(require_current_user)` already 401's anonymous users. No new auth surface. |
</threat_model>

<verification>
- 3 endpoints patched, 3 schemas extended with `from_profile`, 3 contract tests green
- W0 audit Priority-1 list (allocation_annuelle + affordability + rachat_echelonne) closed
- Sev-3 null-canton crash class closed for rachat_echelonne
- financial_core service files untouched (Karpathy #3 + CLAUDE.md §1)
- Full backend suite green
</verification>

<success_criteria>
- 11 new tests pass (4 + 3 + 4)
- `grep -c "from_profile" services/backend/app/schemas/{arbitrage,mortgage,lpp_deep}.py` returns ≥8 cumulative
- 3 endpoints now return 422 with CoachToolIncomplete when profile blank, NOT silent VD defaults or 500 crashes
- Engram obs saved with prior_finding_refs to #103, #104, Plan 01 obs
</success_criteria>

<risks>
- **Schema name drift.** If `AllocationAnnuelleRequest` is actually named `AllocationRequest` or split across multiple schemas, the grep will fail — task 1 step A acceptance criterion `grep -c "json_schema_extra..from_profile" services/backend/app/schemas/arbitrage.py ≥ 4` is the canonical check. Investigate via `grep -rn "class.*Request" services/backend/app/schemas/arbitrage.py` before editing.
- **`_PROFILE_SAFE_FIELDS` canonical names.** If profile keys like `mortgage_rate_current` don't match the canonical list at `coach_chat.py:875`, the markers will silently fail to populate. Task 1 step A explicitly tells the executor to grep `_PROFILE_SAFE_FIELDS` and use the canonical keys.
- **Response model add `_meta` field.** Tests 2-3 of each task assert on `_meta` fields. If the existing response schemas don't expose this, add a minimal `Optional[dict[str, Any]]` field with `_meta` as the alias. Surgical — single-field addition, NOT a refactor.
- **Hint_fr LSFin compliance.** Default hint_fr text must NEVER contain « optimal / meilleur / garanti / recommandé / certain / assuré / sans risque / parfait ». The `banned_terms_python.py` lint catches this — but planner explicitly enforces via task action wording.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-02-w1-priority1-endpoints-SUMMARY.md`. Include:
- Engram obs_id from Task 4
- Pytest delta (Plan 01 baseline + 11)
- W0 sev-3 closure status: 3 of 12 endpoints closed (allocation_annuelle, affordability, rachat_echelonne)
- Maestro G1 flow status if executed (otherwise note: Maestro G1 covers backend grounding via existing coach-chat flows, no new flow needed for this plan)
</output>
