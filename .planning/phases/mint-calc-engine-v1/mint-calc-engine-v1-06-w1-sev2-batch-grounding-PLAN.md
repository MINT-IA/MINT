---
phase: mint-calc-engine-v1
plan: 06
wave: 1
title: W1 — Remaining sev-3 + sev-2 endpoint grounding (5+23 endpoints in batches of 5-6) + blank-profile 422 contract
type: execute
depends_on: [01, 02, 03]
files_modified:
  - services/backend/app/api/v1/endpoints/family.py
  - services/backend/app/api/v1/endpoints/expat.py
  - services/backend/app/api/v1/endpoints/independants.py
  - services/backend/app/api/v1/endpoints/retirement.py
  - services/backend/app/api/v1/endpoints/unemployment.py
  - services/backend/app/api/v1/endpoints/health.py
  - services/backend/app/api/v1/endpoints/arbitrage.py
  - services/backend/app/api/v1/endpoints/mortgage.py
  - services/backend/app/api/v1/endpoints/debt_prevention.py
  - services/backend/app/schemas/family.py
  - services/backend/app/schemas/expat.py
  - services/backend/app/schemas/independants.py
  - services/backend/app/schemas/retirement.py
  - services/backend/app/schemas/unemployment.py
  - services/backend/app/schemas/health.py
  - services/backend/app/schemas/arbitrage.py
  - services/backend/app/schemas/mortgage.py
  - services/backend/app/schemas/debt_prevention.py
  - services/backend/tests/test_blank_profile_422_contract.py
autonomous: true
requirements: [D-CE-05, D-CE-06, D-CE-07, D-CE-08, D-CE-20]
estimated_duration: 7
must_haves:
  truths:
    - "Remaining 5 sev-3 W0 endpoints (succession_simulator, divorce_simulator, naissance allocations canton-driven, mariage compare, plus 1 from independants/expat) now return 422 with CoachToolIncomplete when profile missing required fields"
    - "≥18 sev-2 W0 endpoints patched with from_profile schema markers (cumulative ≥80% of W0 sev-2 list)"
    - "`client_with_blank_profile()` contract test (W1-06-01) asserts that EVERY W1-patched endpoint returns 422 when profile blank — single parametrized truth source for the whole wave"
    - "After this plan: profile_grounded_calc_rate baseline measurement enabled (W4 will instrument the counter)"
  artifacts:
    - path: services/backend/tests/test_blank_profile_422_contract.py
      provides: "Parametrized contract test covering ALL W1-patched endpoints (~25-30 endpoints)"
      min_lines: 80
  key_links:
    - from: services/backend/app/api/v1/endpoints/*.py
      to: services/backend/app/core/profile_resolver.py
      via: "Depends(get_profile_filled) on every grounded handler"
      pattern: "Depends\\(get_profile_filled\\)"
---

<objective>
Ship the remaining sev-3 + sev-2 endpoint grounding fixes in 4 batches of 5-6 endpoints. After this plan, ALL 12 W0 sev-3 endpoints + the 23 W0 sev-2 endpoints are server-side grounded with the `_resolve_defaults` + `CoachToolIncomplete` 422 pattern (per W0 audit § Recommended Fix Priority Order line 234 « Priority 3 — all other severity 2 calculators batched 5-6 per PR »).

Purpose: D-CE-06 + D-CE-07 + D-CE-08 applied at scale. Close hypothesis C (the 86%-confirmed « hardcoded defaults » bug) on the entire REST surface. Concern D (blank-profile contract test) generalized: one parametrized test asserts every grounded endpoint behaves correctly.

**D-CE-08 strict-mode contract (inherited from Plan 01):** `raise_incomplete_as_422` honors `PROFILE_GROUNDING_STRICT_MODE` env flag — non-strict mode logs + returns `resolved_body` (legacy path continues), strict mode raises HTTPException(422). The parametrized contract test in this plan runs each endpoint twice (strict=true + strict=false) to assert both branches behave correctly. Rollout sequence per CONTEXT D-CE-08 : staging strict=true (initial deploy) → prod strict=false (1 release safety net) → prod strict=true (full enforcement).

Output: ~18-25 endpoint handlers patched + corresponding schema patches + 1 parametrized contract test file driving the whole wave.

**Granularity note:** This plan groups 4-6 batches conceptually but ships them as a single coordinated PR. If pre-flight count shows >25 endpoints (CONTEXT data gap «12 sev-3 may have shifted post-Plan 02/03»), executor MAY split into 2 sequential plans (06a + 06b) and report back to orchestrator.
</objective>

<execution_context>
@/Users/julienbattaglia/Desktop/MINT.nosync/.claude/get-shit-done/workflows/execute-plan.md
</execution_context>

<context>
@.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md
@.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md
@services/backend/app/core/profile_resolver.py
@services/backend/app/api/v1/endpoints/
@services/backend/app/schemas/
</context>

<interfaces>
<!-- W0 audit Priority-3 + remaining sev-3 endpoints. Excludes already-patched in Plans 02+03. -->

**Already patched (Plans 02+03), SKIP:**
- allocation_annuelle, affordability_service, rachat_echelonne_service (Plan 02)
- wealth_tax estimate+compare, succession (concubinage variant), location_vs_propriete (Plan 03)

**Plan 06 targets:**

Sev-3 remaining (5 endpoints):
- `succession_simulator` standalone endpoint (W0 row 26) — if not covered in family/succession of Plan 03
- `divorce_simulator` (W0 row 25, sev-2 but canton-driven)
- `naissance_service` allocations (W0 row 18, sev-2 — canton allocation indexing)

Sev-2 batch (~18-23 endpoints from W0 audit by category):
- **Arbitrage**: `rente_vs_capital`, `rachat_vs_marche`, `calendrier_retraits`
- **Mortgage**: `saron_vs_fixed`, `imputed_rental`, `amortization`, `epl_combined`
- **LPP deep**: `epl_service`, `libre_passage`
- **Family**: `mariage` compare, `mariage` regime
- **Independants**: `avs_cotisations`, `lpp_volontaire`, `pillar_3a_indep`, `ijm`
- **Expat**: `expat_service` (status), `frontalier` (sub-dir variant)
- **Unemployment**: `unemployment_calculator`
- **Health**: `lamal_franchise`
- **Debt-prevention**: `repayment` (snowball/avalanche), `debt_ratio`
- **Retirement**: `avs_estimation`

Some endpoints have output_type !L1 (e.g. `rente_vs_capital` is L2 compare) — for THOSE, executor's schema must call out the lucidity payload type.
</interfaces>

<tasks>

<task id="W1-06-00" type="auto" tdd="false">
  <name>Task 0: Pre-flight categorization (D-CE-20 per-wave deepening)</name>
  <files>(read-only)</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md (all 57 rows)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-02-w1-priority1-endpoints-SUMMARY.md (Plan 02 closure status)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-03-w1-priority2-endpoints-SUMMARY.md (Plan 03 closure status)
    - services/backend/app/api/v1/endpoints/ (every *.py file — count grep targets)
  </read_first>
  <action>
    Pre-flight to confirm scope BEFORE editing. Run:

    1. `grep -l "Depends(get_profile_filled)" services/backend/app/api/v1/endpoints/*.py` — list of already-grounded endpoint files (Plans 01-05 baseline).
    2. `grep -c "def [a-z_]*:" services/backend/app/api/v1/endpoints/*.py | sort -k2 -t: -n -r | head -10` — endpoint count per file (find heavy files).
    3. Build a 3-column table in this plan's SUMMARY:
       | File | sev-3+sev-2 endpoints W0 list | Already patched? |

    If the total NEW endpoints to patch > 25, **STOP and split into 06a + 06b**. Report to orchestrator.

    Per D-CE-20 deepening: spot-check 5 endpoints from the batch to verify W0 audit findings still match production code (no canton-default has been silently fixed between W0 audit and W1 execution).

    Engram: `mem_search "calc_engine:audit_hypothesis_c"` to load all 57 audit obs_ids ; cite the relevant subset as `prior_finding_refs`.
  </action>
  <verify>
    <automated>grep -l "Depends(get_profile_filled)" services/backend/app/api/v1/endpoints/*.py | wc -l</automated>
  </verify>
  <acceptance_criteria>
    - Categorization table built in SUMMARY (or in this plan's task notes)
    - Scope decision documented: « X endpoints in scope, Y already patched, Z to patch in this plan »
    - If Z > 25, plan SPLIT recommendation surfaced to orchestrator BEFORE Task 1 starts
  </acceptance_criteria>
  <done>Scope locked, no surprises during Task 1</done>
</task>

<task id="W1-06-01" type="auto" tdd="true">
  <name>Task 1: Batch grounding patches (4 batches × 5-6 endpoints)</name>
  <files>services/backend/app/api/v1/endpoints/*.py, services/backend/app/schemas/*.py</files>
  <read_first>
    - Plans 02 + 03 PR diffs (pattern precedent for endpoint patching)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md §Q-B endpoint integration pattern
    - W0-AUDIT-MATRIX.md per-row hardcoded_defaults column (use as authoritative list of fields to mark `from_profile`)
  </read_first>
  <action>
    Apply Plan 02 Task 1 step A + step B pattern to each endpoint, batched as 4 commits.

    **Batch A — Arbitrage + Mortgage remainder (5 endpoints)**:
    - `rente_vs_capital` (`canton`, `is_married`, `age_retraite`)
    - `rachat_vs_marche` (`canton`, `taux_rachat_lpp`)
    - `calendrier_retraits` (`canton`, `age`, `wealth_total`)
    - `saron_vs_fixed_service` (`canton`, `current_mortgage_rate`)
    - `amortization_service` (`amortization_method` — profile key if exists)

    **Batch B — LPP/Family/Independants (6 endpoints)**:
    - `epl_service` (`canton`, `age`)
    - `libre_passage` (`canton`, `age_vested`)
    - `mariage` compare (`revenu_1`, `revenu_2`, `canton`)
    - `mariage` regime (no canton-grounding — pure legal formula, SKIP)
    - `divorce_simulator` (`canton`, `duree_mariage`, `regime`)
    - `naissance_service` allocations (`canton`, `age_enfant`, `revenu_parent`)

    **Batch C — Independants/Expat (5 endpoints)**:
    - `avs_cotisations_service` (`revenu_net`, `is_independent`)
    - `pillar_3a_indep_service` (`revenu_net`, `canton`)
    - `lpp_volontaire_service` (`revenu_net`, `age`)
    - `expat_service` status (`country`, `canton`, `years_in_ch`)
    - `frontalier_service` (sub-dir variant, `canton`, `country_residence`)

    **Batch D — Misc (5 endpoints)**:
    - `unemployment_calculator` (`canton`, `age`, `income`)
    - `lamal_franchise_service` (`age`, `canton`)
    - `debt_ratio_service` (`income`, `existing_debt`)
    - `avs_estimation_service` (`birthYear`, `canton`, `contribution_years`)
    - `ijm_service` (`canton`, `revenu_net`, `industry`)

    Per batch, for EACH endpoint:
    1. Open schema file, add `Field(default=None, json_schema_extra={"from_profile": "<canonical_profile_key>"})` marker. Canonical key MUST match `_PROFILE_SAFE_FIELDS` at `coach_chat.py:875` — grep first.
    2. Open endpoint file, wrap handler with `Depends(get_profile_filled)` + `_resolve_defaults` + `_required_profile_fields_missing` + `raise_incomplete_as_422` per Plan 02 pattern.
    3. Hint_fr text: endpoint-specific, LSFin-safe. Template:
       « Pour <action métier>, j'ai besoin de <list of human-readable field names>. Tu peux me les partager ? »
       Example for `divorce_simulator`: « Pour estimer l'impact financier d'un divorce, j'ai besoin de ton canton, de la durée de ton mariage et de ton régime matrimonial. »
    4. Service file in `app/services/` STAYS UNTOUCHED (CLAUDE.md §1 SoT).
    5. Commit each batch separately: `feat(mint-calc-engine-v1/W1): ground batch A — 5 arbitrage+mortgage endpoints (sev-2)` etc.

    **For endpoints producing L2/L3 output (e.g. `rente_vs_capital`, `mariage` compare, `divorce_simulator`)**: the response model will be migrated to emit `LucidityPayload` in W2. For now (W1), only patch the args resolution — DO NOT touch response shape.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - `grep -l "Depends(get_profile_filled)" services/backend/app/api/v1/endpoints/*.py | wc -l` returns ≥7 (after Plans 02+03+06)
    - `grep -c "json_schema_extra={\"from_profile\"" services/backend/app/schemas/*.py | awk -F: '{s+=$2} END {print s}'` returns ≥30 cumulative
    - Full suite still green (no regression in service-layer tests)
    - `git diff services/backend/app/services/ services/backend/app/financial_core/` returns empty (financial_core untouched per Karpathy #3 + CLAUDE.md §1)
    - Lints clean on all touched endpoint + schema files
  </acceptance_criteria>
  <done>~21 endpoints grounded across 4 batches, all suite green</done>
</task>

<task id="W1-06-02" type="auto" tdd="true">
  <name>Task 2: Parametrized blank-profile 422 contract test (W1-06-01 in VALIDATION.md)</name>
  <files>services/backend/tests/test_blank_profile_422_contract.py</files>
  <read_first>
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Concern D
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md W1-06-01 task ID
    - services/backend/tests/test_canton_required_grounding.py (Plan 03 — pattern reuse)
    - services/backend/tests/conftest.py (`client_with_blank_profile` fixture from Plan 01)
  </read_first>
  <behavior>
    - Test 1: Parametrized over EVERY W1-patched endpoint (~21 from Task 1 + 5+5 from Plans 02+03 = ~31 total). For each: POST with empty body → expect 422 + envelope shape.
    - Test 2: Same parametrized, with profile populated with all canonical safe fields → expect 200/201/204 (success), NOT 422.
    - Test 3 (regression guard): `grep -l "Depends(get_profile_filled)" services/backend/app/api/v1/endpoints/*.py` returns ≥7 files (i.e. all 7 endpoint-file types are touched).
  </behavior>
  <action>
    Create `services/backend/tests/test_blank_profile_422_contract.py`:

    ```python
    """Plan 06 W1-06-01 — Concern D parametrized contract.

    Single source of truth for « every W1-patched endpoint returns 422 on blank profile ».
    Lists ALL W1-patched endpoints from Plans 02 + 03 + 06 batches A-D.
    """
    import pytest


    # MUST stay in sync with W1 plans 02/03/06. Update on every plan close-out.
    W1_GROUNDED_ENDPOINTS: list[tuple[str, str, dict, list[str]]] = [
        # (path, method, minimal_body_no_canton, expected_missing_profile_fields)
        ("/api/v1/arbitrage/allocation-annuelle", "POST", {"montant_disponible": 10000}, ["canton"]),
        ("/api/v1/mortgage/affordability", "POST", {"property_price": 800000}, ["canton"]),
        ("/api/v1/lpp-deep/rachat-echelonne", "POST", {"montant_rachat": 50000}, ["canton"]),
        ("/api/v1/fiscal/estimate", "POST", {"wealth_total": 500000}, ["canton"]),
        ("/api/v1/fiscal/compare", "POST", {}, ["canton"]),
        ("/api/v1/family/succession", "POST", {"heritage_value": 200000}, ["canton"]),
        ("/api/v1/family/concubinage/succession", "POST", {"heritage_value": 200000}, ["canton"]),
        ("/api/v1/arbitrage/location-vs-propriete", "POST", {"property_price": 800000}, ["canton"]),
        ("/api/v1/arbitrage/rente-vs-capital", "POST", {}, ["canton"]),
        ("/api/v1/arbitrage/rachat-vs-marche", "POST", {}, ["canton"]),
        # ... 20+ more (one per endpoint Task 1 patched)
    ]


    @pytest.mark.parametrize("path,method,body,expected_missing", W1_GROUNDED_ENDPOINTS)
    def test_blank_profile_yields_422_with_envelope(
        client_with_blank_profile, path, method, body, expected_missing
    ):
        resp = client_with_blank_profile.request(method, path, json=body)
        assert resp.status_code == 422, f"{path}: expected 422, got {resp.status_code}"
        detail = resp.json()["detail"]
        assert detail["status"] == "incomplete", f"{path}: envelope status wrong"
        assert len(detail["missingFields"]) >= 1
        # At least 1 expected_missing field is in missingFields
        assert any(f in detail["missingFields"] for f in expected_missing), (
            f"{path}: expected {expected_missing} in {detail['missingFields']}"
        )


    @pytest.mark.parametrize("path,method,body,_", W1_GROUNDED_ENDPOINTS)
    def test_populated_profile_yields_success(
        client_with_full_profile, path, method, body, _
    ):
        resp = client_with_full_profile.request(method, path, json=body)
        assert resp.status_code in (200, 201, 204), (
            f"{path}: expected success, got {resp.status_code}. Body: {resp.json()}"
        )
    ```

    Add `client_with_full_profile` fixture to `conftest.py` (sister of `client_with_blank_profile` with `data={"canton": "GE", "age": 35, "salary_gross_yearly": 120000, "is_property_owner": False, "mortgage_rate_current": 0.028, ...}` — populate ALL canonical `_PROFILE_SAFE_FIELDS`).

    DO NOT skip endpoints in `W1_GROUNDED_ENDPOINTS` if their dependency setup is complex — that signals the endpoint isn't actually grounded. If a test fails because endpoint X needs additional body fields beyond canton/age/income, document in SUMMARY and add the field to `body` dict.
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/test_blank_profile_422_contract.py -q -x</automated>
  </verify>
  <acceptance_criteria>
    - `services/backend/tests/test_blank_profile_422_contract.py` exists, ≥80 lines
    - `len(W1_GROUNDED_ENDPOINTS) >= 25`
    - `cd services/backend && python3 -m pytest tests/test_blank_profile_422_contract.py -q -x` exits 0
    - Both parametrized tests (blank + populated) pass for every entry
    - `client_with_full_profile` fixture appended to `conftest.py` (grep returns 1)
  </acceptance_criteria>
  <done>Parametrized contract test green for all W1-grounded endpoints</done>
</task>

<task id="W1-06-99" type="auto" tdd="false">
  <name>Task 3: Full suite + W1 wave close-out engram + STATE.md update</name>
  <files>.planning/STATE.md</files>
  <read_first>
    - .planning/STATE.md (current state)
    - .planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md §Memory Contract
  </read_first>
  <action>
    Full suite + lints + Maestro G1 (existing coach-chat flows still pass with new 422 behaviors).

    Engram **wave-close** save (per Concern F hard rule — at least 1 finding per closed sub-area):
    - `topic_key: calc_engine:w1:wave_close_all_grounded`
    - `type: bugfix`
    - `prior_finding_refs: [Plan 01 obs, Plan 02 obs, Plan 03 obs, Plan 04 obs, Plan 05 obs, W0 audit obs (link 4-5 canonical ones), #103 panel synthesis]`
    - Content: « W1 closed. 12 W0 sev-3 endpoints + 23 sev-2 endpoints grounded via `_resolve_defaults`. Total ~31 endpoints now return 422 on blank profile (parametrized contract test green). L1-L4 typed payloads ship at `app.models.lucidity._payload`. L4 wedge endpoint live. Calc registry scaffold ships at `app.calculators._registry`. Ready for W2 ToolRegistryAdapter + bundles. »

    Update `.planning/STATE.md`:
    - `last_activity: "2026-XX-XX — Wave mint-calc-engine-v1 W1 closed (6 plans, ~31 endpoints grounded)"`
    - `stopped_at: "Completed W1 (Plans 01-06). Ready for W2 — ToolRegistryAdapter + 2 new bundles + tool description rewrites + CoachToolResponse V2 latency_tier."`
  </action>
  <verify>
    <automated>cd services/backend && python3 -m pytest tests/ -q 2>&1 | tail -3</automated>
  </verify>
  <acceptance_criteria>
    - Full suite exits 0
    - Pytest passed count ≥ Plan 05 baseline + ~50 new tests (Task 1 batch tests + Task 2 parametrized)
    - W1 wave-close engram observation saved with ≥6 prior_finding_refs
    - STATE.md updated
    - Lints clean
  </acceptance_criteria>
  <done>W1 wave closed. ~31 endpoints grounded. Ready for W2.</done>
</task>

</tasks>

<threat_model>
## Trust Boundaries (W1 wave-level)

| Boundary | Description |
|----------|-------------|
| Client → REST endpoints | All 31 W1-grounded endpoints share the `Depends(get_profile_filled)` + `_resolve_defaults` enforcement layer |
| profile.canton → service-layer dict lookups | All canton-keyed lookups in services/ are now upstream-guarded by `_required_profile_fields_missing` 422 |

## STRIDE Threat Register

| Threat ID | Category | Component | Disposition | Mitigation Plan |
|-----------|----------|-----------|-------------|-----------------|
| T-mint-calc-06-01 | DoS | null canton → 500 KeyError class | mitigate | 12 sev-3 endpoints now structurally closed. Parametrized regression test asserts 422 on every endpoint, not 500. |
| T-mint-calc-06-02 | Tampering | endpoint-level grounding bypass | mitigate | Concern D `client_with_blank_profile` contract test parametrized over ALL W1 endpoints. Any new endpoint added in W2+ without `Depends(get_profile_filled)` will be missing from the test list — surfaces on review. |
| T-mint-calc-06-03 | Information disclosure | hint_fr text | mitigate | All 21 hint_fr fixtures use « pourrait / envisager / partager » vocabulary. `banned_terms_python.py` lint enforces. |
| T-mint-calc-06-04 | LSFin compliance | calc rate baseline | accept | D-CE-17 95% target panel-extrapolated. W4 instruments the counter ; baseline measurement starts after W4 ship. Acknowledged data gap. |
| T-mint-calc-06-05 | Repudiation | per-endpoint provenance | accept | `inputs_provenance` per-calc logging is W4 scope (D-CE-17). W1 only guarantees grounding ; provenance counter ships W4. |
| T-mint-calc-06-06 | Spoofing | service-layer cross-user | accept | `get_profile_filled` filters `ProfileModel.user_id == user.id` once per request. Same auth boundary as Plans 02-03. |
</threat_model>

<verification>
- ~21 NEW endpoints patched (Plans 02+03 already covered ~9-10)
- W1 cumulative: ~31 endpoints grounded
- Parametrized blank-profile contract test green for ≥25 entries
- W0 sev-3 closure complete: 12/12
- W0 sev-2 closure: ≥18 of 23
- Full suite green
</verification>

<success_criteria>
- `grep -lE "Depends\\(get_profile_filled\\)" services/backend/app/api/v1/endpoints/*.py | wc -l >= 7` (all endpoint-file groups touched)
- `len(W1_GROUNDED_ENDPOINTS) >= 25` in `test_blank_profile_422_contract.py`
- All sev-3 W0 audit incidents structurally closed (no 500 on null canton anywhere in W1 scope)
- W1 wave-close engram observation persisted with ≥6 prior_finding_refs (Concern F compounding observable)
- STATE.md reflects W1 wave closure
</success_criteria>

<risks>
- **Scope creep risk.** If pre-flight (Task 0) reveals >25 NEW endpoints to patch, executor MUST split. Surface to orchestrator BEFORE Task 1 starts.
- **Endpoint discovery gap.** Some sev-2 endpoints in W0 audit may not have actually-routed REST handlers (e.g. internal-only). Skip those — track in SUMMARY as « out-of-scope per audit refinement ».
- **`client_with_full_profile` fixture complexity.** Populating ALL canonical `_PROFILE_SAFE_FIELDS` may require ~30 fields. Use the literal canonical list from `coach_chat.py:875`. If list contains nested objects (e.g. `partner_profile`), populate with a minimal valid sub-dict.
- **Parametrized test failure cascade.** If 1 endpoint fails (e.g. body schema requires more fields), the parametrized test report is noisy. Mitigation: each parametrized case prints `path` in assert message. Failures isolate cleanly.
- **L2/L3 endpoints in batch.** Endpoints producing comparison output (`rente_vs_capital`, `mariage compare`, `divorce_simulator`) get args-resolution grounding HERE but response-shape migration to `LucidityPayload` ships in W2. Document in SUMMARY: « L2/L3 lucidity-payload migration is W2 scope, NOT W1. W1 = args resolution only. »
</risks>

<output>
After completion, create `.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-06-w1-sev2-batch-grounding-SUMMARY.md`. Include:
- Engram wave-close obs_id
- Final tally: 12/12 W0 sev-3 + X/23 W0 sev-2 closed
- List of patched endpoints (single source of truth for W2/W3 consumers)
- STATE.md update confirmation
- Remaining-sev-2 list if not 100% closed (carry to W2 as opportunistic adds)
</output>
