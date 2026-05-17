---
phase: mint-calc-engine-v1
plan: 03
wave: 1
title: W1 — Priority-2 sev-3 endpoint grounding fix (wealth_tax + succession + concubinage + location_vs_propriete)
type: execute
depends_on: [01, 02]
files_modified:
  - services/backend/app/api/v1/endpoints/fiscal.py
  - services/backend/app/api/v1/endpoints/family.py
  - services/backend/app/api/v1/endpoints/arbitrage.py
  - services/backend/app/schemas/fiscal.py
  - services/backend/app/schemas/family.py
  - services/backend/app/schemas/arbitrage.py
  - services/backend/tests/test_canton_required_grounding.py
  - services/backend/tests/test_succession_grounding.py
  - services/backend/tests/test_location_vs_propriete_grounding.py
autonomous: true
requirements: [D-CE-06, D-CE-07, D-CE-08]
estimated_duration: 5
must_haves:
  truths:
    - "POST /api/v1/fiscal/estimate + /fiscal/compare return 422 with CoachToolIncomplete when profile.canton missing (instead of crashing on `CANTON_WEALTH_TAX[None]`)"
    - "POST /api/v1/family/succession returns 422 with CoachToolIncomplete when profile.canton missing (CANTON_SUCCESSION_TAX KeyError closed)"
    - "POST /api/v1/family/concubinage/succession 422 on null canton (sev-3 crash class closed)"
    - "POST /api/v1/arbitrage/location-vs-propriete returns 422 when profile.canton missing"
  artifacts:
    - path: services/backend/tests/test_canton_required_grounding.py
      provides: "Parametrized test covering 4 endpoints × 3 cases each = 12 tests"
      min_lines: 100
  key_links:
    - from: services/backend/app/api/v1/endpoints/fiscal.py
      to: services/backend/app/core/profile_resolver.py
      via: "from app.core.profile_resolver import _resolve_defaults, get_profile_filled, raise_incomplete_as_422"
      pattern: "from app.core.profile_resolver import"
    - from: services/backend/app/api/v1/endpoints/family.py
      to: services/backend/app/core/profile_resolver.py
      via: "Depends(get_profile_filled) on succession + concubinage handlers"
      pattern: "Depends\\(get_profile_filled\\)"
---

<objective>
Ship the W0 Priority-2 sev-3 grounding fixes. Closes 4 more sev-3 endpoints (wealth_tax + succession + concubinage-succession + location_vs_propriete) — all share the « null canton → KeyError or wrong-default » incident pattern. After this plan, 7 of 12 sev-3 endpoints from W0 audit are closed (3 from Plan 02 + 4 here). Remaining 5 sev-3 + 23 sev-2 ship in Plan 06.

Purpose: D-CE-06 + D-CE-07 + D-CE-08 applied to the second-priority batch per W0 audit § Recommended Fix Priority Order line 229-233.

**D-CE-08 strict-mode contract (inherited from Plan 01):** `raise_incomplete_as_422` branches on `PROFILE_GROUNDING_STRICT_MODE` env flag. In non-strict mode (initial prod rollout) the helper logs a warning + returns `resolved_body` so legacy hardcoded-defaults computation continues ; in strict mode (staging always, prod after 1-release gradual rollout) it raises HTTPException(422). The 4 endpoints in this plan honor the same dual-path pattern — the test fixtures parametrize over `PROFILE_GROUNDING_STRICT_MODE=true/false` to verify both branches.

Output: 4 patched endpoint handlers + 4 schema updates + 1 parametrized test file (12 tests total ; 6 strict + 6 non-strict).
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md
@services/backend/app/core/profile_resolver.py
@services/backend/app/services/fiscal/wealth_tax_service.py
@services/backend/app/services/succession_simulator.py
@services/backend/app/services/family/concubinage_service.py
@services/backend/app/services/arbitrage/location_vs_propriete.py
@services/backend/app/api/v1/endpoints/fiscal.py
@services/backend/app/api/v1/endpoints/family.py
</context>

<interfaces>
<!-- W0 audit rows 23, 24, 26 (concubinage succession, wealth tax, succession simulator) all share null-canton KeyError class. -->

From services/backend/app/services/fiscal/wealth_tax_service.py (W0 audit row 24, sev-3):
- Uses canton-keyed lookup table (e.g. `CANTON_WEALTH_TAX_BRACKETS[canton]`) — KeyError on None.

From services/backend/app/services/succession_simulator.py (W0 audit row 26, sev-3):
- `CANTON_SUCCESSION_TAX[canton]` lookup — crashes if null.

From services/backend/app/services/family/concubinage_service.py (W0 audit row 23, sev-3):
- Succession variant: same `CANTON_SUCCESSION_TAX[canton]` pattern.

From services/backend/app/services/arbitrage/location_vs_propriete.py (W0 audit row 3, sev-2):
- Defaults `canton="VD"` — wrong rent vs property economic comparison for non-VD users.
</interfaces>

<tasks>

<task id="W1-03-00" type="auto" tdd="false">
  <name>Task 0: Per-wave spot-check (D-CE-20) — 4 endpoints still routed</name>
  <files>(read-only)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md rows 3, 23, 24, 26
    - services/backend/app/api/v1/routes.py (router registration)
    - services/backend/app/api/v1/endpoints/fiscal.py (wealth_tax handlers)
    - services/backend/app/api/v1/endpoints/family.py (succession + concubinage handlers)
    - services/backend/app/api/v1/endpoints/arbitrage.py (location_vs_propriete handler)
  </read_first>
  <action>
    Per D-CE-20 deepening: confirm all 4 endpoints are still wired and the W0-audited lookup patterns are still live.

    1. `grep -nE "fiscal/(estimate|compare|wealth)" services/backend/app/api/v1/endpoints/fiscal.py` — confirm wealth_tax endpoints routed.
    2. `grep -nE "family/(succession|concubinage)" services/backend/app/api/v1/endpoints/family.py`
    3. `grep -nE "location-vs-propriete" services/backend/app/api/v1/endpoints/arbitrage.py`
    4. `grep -A3 "CANTON_SUCCESSION_TAX\b" services/backend/app/services/{succession_simulator.py,family/concubinage_service.py} | head -20` — confirm dict-key crash class still live.

    Engram check: `mem_search "calc_engine:audit_hypothesis_c:succession_simulator"` + same for `wealth_tax_service`, `concubinage_service`, `location_vs_propriete`. Capture all 4 obs_ids as `prior_finding_refs` for this plan's findings.
  </action>
  <verify>
    <automated>grep -cE "fiscal/(estimate|compare)" services/backend/app/api/v1/endpoints/fiscal.py</automated>
  </verify>
  <acceptance_criteria>
    - 4 endpoints still routed (grep returns ≥1 per endpoint family)
    - W0 sev-3 pattern still live: `grep -cE "CANTON_SUCCESSION_TAX\[" services/backend/app/services/` returns ≥1
    - 4 W0 audit obs_ids captured for prior_finding_refs
  </acceptance_criteria>
  <done>Spot-check done, ready to patch 4 endpoints in parallel</done>
</task>

<task id="W1-03-01" type="auto" tdd="true">
  <name>Task 1: 4 endpoints grounded + parametrized contract tests</name>
  <files>services/backend/app/api/v1/endpoints/fiscal.py, services/backend/app/api/v1/endpoints/family.py, services/backend/app/api/v1/endpoints/arbitrage.py, services/backend/app/schemas/fiscal.py, services/backend/app/schemas/family.py, services/backend/app/schemas/arbitrage.py, services/backend/tests/test_canton_required_grounding.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-B Endpoint integration pattern
    - .planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md rows 3, 23, 24, 26
    - services/backend/app/api/v1/endpoints/fiscal.py (full file)
    - services/backend/app/api/v1/endpoints/family.py (full file)
    - services/backend/app/api/v1/endpoints/arbitrage.py (already touched in Plan 02 — pattern reuse)
    - Plan 02's test_arbitrage_allocation_annuelle_grounding.py (pattern precedent)
  </read_first>
  <behavior>
    Parametrized test pattern (12 tests, 1 file):
    - For each of 4 endpoints `[wealth_tax_estimate, wealth_tax_compare, succession, concubinage_succession, location_vs_propriete]` (5 endpoints, picking compare+estimate as separate handlers in fiscal):
      - Test A: blank profile + body missing canton → 422 with CoachToolIncomplete envelope. `response.json()["detail"]["status"] == "incomplete"`, `"canton" in response.json()["detail"]["missingFields"]`.
      - Test B: profile `{"canton": "GE"}` + canton-less body → 200 (or appropriate success), canton=GE used in compute.
      - Test C (sev-3 regression guard): body explicit `{"canton": null}` + blank profile → 422 (NOT a 500 from `CANTON_TAX_LOOKUP[None]` KeyError).
  </behavior>
  <action>
    **One coordinated patch across 4 endpoint files + 3 schema files + 1 test file.**

    **Schema patches (apply pattern from Plan 02 Task 1 step A):**
    1. `services/backend/app/schemas/fiscal.py` — `WealthTaxRequest` (or whatever the canonical name): add `canton: Optional[str] = Field(default=None, json_schema_extra={"from_profile": "canton"})` + `wealth_total: Optional[float] = Field(default=None, json_schema_extra={"from_profile": "net_worth_total"})` (verify canonical profile key).
    2. `services/backend/app/schemas/family.py` — `SuccessionRequest` + `ConcubinageSuccessionRequest` (or canonical names): same canton marker + heir relationship fields if profile-driven.
    3. `services/backend/app/schemas/arbitrage.py` — `LocationVsProprieteRequest` (or canonical): canton marker + `taux_hypothecaire` if relevant (from_profile: `mortgage_rate_current`).

    **Endpoint patches:**
    For each of the 4-5 handlers in `fiscal.py` + `family.py` + `arbitrage.py`, wrap with:
    ```python
    @router.post("/<path>", response_model=<Resp>)
    def <name>(
        request: Request,
        body: <Req>,
        _user: User = Depends(require_current_user),
        profile_data: dict = Depends(get_profile_filled),
    ) -> <Resp>:
        resolved = _resolve_defaults(profile_data, body, <Req>)
        missing = _required_profile_fields_missing(resolved, <Req>)
        if missing:
            raise_incomplete_as_422(
                missing_fields=missing,
                hint_fr=<endpoint-specific hint, LSFin-safe>,
            )
        result = <existing_compute_fn>(**resolved)
        return _result_to_response(result, <Resp>)
    ```

    Hint_fr per endpoint (verbatim, LSFin-safe, full FR accents):
    - **fiscal estimate**: « Pour estimer ton impôt sur la fortune, j'ai besoin de ton canton et de ton patrimoine net. »
    - **fiscal compare**: « Pour comparer les impôts entre cantons, j'ai besoin de tes deux cantons cibles et de ton patrimoine. »
    - **succession**: « Pour estimer les frais de succession, j'ai besoin de ton canton et de la relation de l'héritier au défunt. »
    - **concubinage succession**: « Pour estimer la succession en concubinage, j'ai besoin de ton canton — les règles varient considérablement. »
    - **location_vs_propriete**: « Pour comparer location et propriété, j'ai besoin de ton canton et de ton taux hypothécaire actuel. »

    **Test file** `services/backend/tests/test_canton_required_grounding.py`:
    ```python
    import pytest

    @pytest.mark.parametrize("endpoint,body_template,expected_missing_field", [
        ("/api/v1/fiscal/estimate", {"wealth_total": 500000}, "canton"),
        ("/api/v1/fiscal/compare", {"wealth_total": 500000, "canton_target": "GE"}, "canton"),
        ("/api/v1/family/succession", {"heritage_value": 200000}, "canton"),
        ("/api/v1/family/concubinage/succession", {"heritage_value": 200000}, "canton"),
        ("/api/v1/arbitrage/location-vs-propriete", {"property_price": 800000, "monthly_rent": 2500}, "canton"),
    ])
    def test_blank_profile_yields_422(client_with_blank_profile, endpoint, body_template, expected_missing_field):
        resp = client_with_blank_profile.post(endpoint, json=body_template)
        assert resp.status_code == 422
        detail = resp.json()["detail"]
        assert detail["status"] == "incomplete"
        assert expected_missing_field in detail["missingFields"]

    @pytest.mark.parametrize("endpoint,body_template,profile_data", [...])
    def test_profile_canton_fills_resolved(client_with_geneva_profile, endpoint, body_template, profile_data):
        ...

    @pytest.mark.parametrize("endpoint,body_template", [...])
    def test_explicit_null_canton_returns_422_not_500(client_with_blank_profile, endpoint, body_template):
        body = {**body_template, "canton": None}
        resp = client_with_blank_profile.post(endpoint, json=body)
        assert resp.status_code == 422, f"sev-3 regression: got {resp.status_code}, expected 422"
    ```

    Define `client_with_geneva_profile` as a sister fixture in `conftest.py` (similar pattern to `client_with_blank_profile` from Plan 01 but with `data={"canton": "GE", "wealth_total": 500000, ...}`).

    DO NOT touch any file in `services/backend/app/services/` — CLAUDE.md §1 SoT preservation.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_canton_required_grounding.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - 4-5 endpoint handlers in `fiscal.py` + `family.py` + `arbitrage.py` now contain `Depends(get_profile_filled)` (grep ≥4 hits total across the 3 files)
    - 3 schema files patched: `grep -c "from_profile" services/backend/app/schemas/{fiscal,family,arbitrage}.py | awk -F: '{s+=$2} END {print s}'` returns ≥7 cumulative (across all 3, including Plan 02's arbitrage additions)
    - `cd services/backend && python3 -m pytest tests/test_canton_required_grounding.py -q -x` exits 0 with ≥12 tests passed
    - Sev-3 regression guards green: 5 sub-cases of `test_explicit_null_canton_returns_422_not_500` all pass
    - Service files untouched: `git diff services/backend/app/services/fiscal/ services/backend/app/services/succession_simulator.py services/backend/app/services/family/concubinage_service.py services/backend/app/services/arbitrage/location_vs_propriete.py` returns empty
    - Banned-terms lint clean: `python3 tools/checks/banned_terms_python.py services/backend/app/api/v1/endpoints/{fiscal,family,arbitrage}.py services/backend/app/schemas/{fiscal,family,arbitrage}.py` exits 0
    - Accent lint clean on touched files
  </acceptance_criteria>
  <done>4-5 endpoints grounded, 12+ tests green, 5 sev-3 incidents closed (cumulative: 7 of 12 sev-3 endpoints from W0)</done>
</task>

<task id="W1-03-99" type="auto" tdd="false">
  <name>Task 2: Full suite + engram save (W1 PR-2 close-out)</name>
  <files>(verification only)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Memory Contract
  </read_first>
  <action>
    Full suite + lints. Engram save:
    - `topic_key: calc_engine:w1:priority2_endpoints_grounded`
    - `type: bugfix`
    - `prior_finding_refs: [W0 obs row 24 wealth_tax, row 26 succession, row 23 concubinage, row 3 location_vs_propriete, Plan 02 obs_id]`
    - Content: « Priority-2 sev-3 endpoints grounded: wealth_tax + succession + concubinage_succession + location_vs_propriete. 7 of 12 sev-3 W0 endpoints closed (3 Plan 02 + 4 here). Remaining 5 sev-3 + 23 sev-2 in Plan 06. »
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite exits 0
    - Pytest passed count ≥ Plan 02 baseline + ≥12 new tests
    - Engram saved with prior_finding_refs
  </acceptance_criteria>
  <done>W1 Plan 03 close-out gates green</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries

| Boundary | Description |
|----------|-------------|
| Client body canton field | Untrusted; explicit-null must NOT trigger silent fallback |
| profile.canton → `CANTON_*_TAX[canton]` lookup | dict-key crash class on None |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-03-01 | DoS | null canton → 500 KeyError | mitigate | `_required_profile_fields_missing` catches None canton → 422 BEFORE service lookup. 5 explicit regression-guard tests (`test_explicit_null_canton_returns_422_not_500`) close the sev-3 crash class structurally. |
| T-mint-calc-03-02 | Tampering | body canton override | mitigate | `model_fields_set` semantics: explicit-null = clear, omission = profile fallback. Per Plan 01 W1-01-01 Test 2. |
| T-mint-calc-03-03 | LSFin | hint_fr text | mitigate | 5 hint_fr fixtures use « pourrait / envisager / partager » only. Banned-terms lint runs on touched files. |
| T-mint-calc-03-04 | Information disclosure | profile-grounded compute output | accept | Same as Plan 02 — user reads only their own profile via `user_id` filter in `get_profile_filled`. |
| T-mint-calc-03-05 | Repudiation | profile-source traceability | accept | No new audit-log requirement; Plan 02 _meta pattern extends naturally if needed in W4. |
</threat_model>

<verification>
- 4-5 endpoints patched, 3 schemas updated
- 12+ contract tests green
- 5 sev-3 incidents closed structurally (null-canton KeyError class)
- W0 sev-3 closure cumulative: 7 of 12
- All lints clean, full suite green
</verification>

<success_criteria>
- 7/12 W0 sev-3 endpoints closed by end of Plan 03 (3 from Plan 02 + 4 here)
- Sev-3 null-canton crash class structurally closed: 5 explicit regression-guard tests pass
- Engram observation persisted linking 4 W0 audit obs_ids
</success_criteria>

<risks>
- **Schema name inconsistency.** Backend schemas may not be uniformly named — `WealthTaxRequest` vs `FiscalEstimateRequest` etc. Executor MUST grep `class.*Request` in each schema file before editing.
- **Multiple succession endpoints.** `services/backend/app/api/v1/endpoints/family.py` may have multiple succession handlers (regime, survivant, compare). Plan 03 ONLY patches the canton-driven ones (W0 audit rows 23, 26). Non-canton-driven endpoints (regime LAVS art. 24 80%-survivant) stay untouched.
- **`client_with_geneva_profile` fixture missing.** Plan 01 only ships `client_with_blank_profile`. Executor adds the sister fixture in this plan's `conftest.py` patch — surgical append, NOT a refactor.
- **5 endpoints not 4.** Task 1 catches that `fiscal.py` may have both `/estimate` AND `/compare` handlers — both need patching, treat as 5 endpoints total.
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-03-w1-priority2-endpoints-SUMMARY.md`. Include:
- Engram obs_id
- W0 sev-3 closure: 7/12 cumulative
- Service-layer files unchanged (financial_core SoT preserved)
</output>
