# Claude external audit rerun — AVS G1 fixes — code — `c31921a6a`

## Immutable scope

- Global G1 status: **NO-GO**. This bounded rerun does not authorize G2/G3.
- Exact rerun range: `06115ed38...c31921a6a` (`06115ed388c4a1b30abf24314efc83893fb75eca` → `c31921a6a859f4225c2bea963bc78933916b6ce9`).
- This is the **single Sonnet rerun** allowed after the Opus first pass; no audit carousel and no Opus confirmation was launched.
- Command, launched first and awaited to completion before the product/domain lens:

```sh
env CLAUDE_AUDIT_RERUN=1 CLAUDE_AUDIT_EFFORT=high CLAUDE_AUDIT_WORKTREE=/tmp/mint-g1-avs-sonnet-c31921a6a.sUWIlf/repo CLAUDE_AUDIT_MAX_DIFF_LINES=7000 tools/checks/claude_external_audit.sh code 06115ed38
```

- Wrapper: `tools/checks/claude_external_audit.sh` exclusively; no raw Claude invocation.
- Model / effort: **Sonnet / high**, selected by the wrapper from `CLAUDE_AUDIT_RERUN=1`; no model override, max effort, max-turn setting, large-diff bypass, project settings, or non-Sonnet rerun override.
- Started UTC: `2026-07-13T16:50:03Z`; ended UTC: `2026-07-13T16:56:10Z`.
- Exit code: **0**; stdout: **79 lines**; stderr: **0 lines**.

## Clean detached-clone and budget proof

- Detached clone: `/tmp/mint-g1-avs-sonnet-c31921a6a.sUWIlf/repo`.
- `git rev-parse HEAD`: `c31921a6a859f4225c2bea963bc78933916b6ce9`.
- `git rev-parse 06115ed38`: `06115ed388c4a1b30abf24314efc83893fb75eca`.
- `git status --short --branch`: `## HEAD (no branch)` before the code audit, between the two audits, and after the product/domain audit.
- Unified prompt diff: **6,521 lines**, below `CLAUDE_AUDIT_MAX_DIFF_LINES=7000`; no `CLAUDE_AUDIT_ALLOW_LARGE_DIFF` bypass.
- Short stat: **21 files changed, 768 insertions(+), 330 deletions(-)**.
- The dirty files in the primary checkout were absent from the prompt.

## External verdict and MINT triage

- Claude code verdict: **PASS** for this rerun range.
- **P0: none.**
- **P1: none.** The prior backend/mobile annualization contradiction is closed: the backend now exposes twelve ordinary payments only, the December supplement remains separate, and `/overview/me` no longer fabricates an AVS amount from contribution years.
- **P2 open, pre-existing and activation-blocking:**
  1. `apps/mobile/lib/services/independants_service.dart` still uses the literal owner `independant-self-scenario` on the dormant supplement scenario.
  2. The same dormant path folds the December supplement into aggregate projection bars without a dedicated screen/PDF renderer.
- The external code pass found no new P2.

## Requested confirmation matrix

| Contract | Result | Evidence / interpretation |
|---|---|---|
| Backend ordinary annual AVS is ×12 | **PASS** | `avs_estimation_service.py` uses `AVS_ORDINARY_PAYMENTS_PER_YEAR = 12` for annual, cumulative, anticipation/deferral and breakeven values; legacy ×13 constants are removed. |
| December supplement stays separate | **PASS, dormant activation debt remains** | Backend copy and schema explicitly exclude the December supplement from ordinary annual/cumulative values. Mobile's default-off scenario still lacks a dedicated renderer, recorded above as P2. |
| Overview does not infer pension from contribution years | **PASS** | `overview.py` no longer imports/calls `AvsEstimationService`; tests cover absent/zero/44 years and couple status. |
| Couple/partner amount is never fabricated | **PASS** | Backend `rente_couple_mensuelle` stays `None`; civil status is documented as context only and tests cover married/registered-equivalent behavior. |
| Married/registered AI+AI without provider | **PASS** | Mobile cap readiness is `pending`, never `notApplicable` or a fabricated sum. |
| Official legal zero vs absent monthly source | **PASS** | Official December `notEntitled` is resolved before deferred missing-source failure; dedicated regression test is present. |
| Sub-centime registry override | **PASS** | Exact-cent conversion returns no scenario plus `providerCorrectionRequired`; it neither throws nor rounds silently. |
| `hasAvsGaps` | **PASS as honest quarantine** | Matrix has `reader_evidence=NONE`, `consumers=NONE`, `status=quarantined`; positive and forged-reader negative fixtures enforce it. |
| API / OpenAPI / SOT | **PASS** | API field shapes remain compatible; nullable couple value remains nullable. OpenAPI descriptions now state ×12/separate December and no fabricated couple. SOT section 7 records the invariant. The unrelated `PremierEclairageResponse` hash rename is description-only. |
| Facade / no-caller | **PASS with declared P2** | Live backend endpoints are exercised by endpoint/E2E tests. The mobile supplement calculator has a real default-off caller but no renderer; this is explicitly quarantined and cannot be activated until owner and renderer P2s close. |

## Captured stdout (verbatim)

~~~text
Flag default is `false` — the dormant path is confirmed off in production.

---

## MINT External Audit — Code — `06115ed38` → `c31921a6a`

**Audit mode:** code · **Base ref:** `06115ed38` · **HEAD:** `c31921a6a` · **Diff:** 21 files / ~768 lines (within 7 000-line budget)

---

## Verdict: **PASS**

---

### What was audited

5 commits squashed into this range:
- `fix(g1): quarantine uncertified backend AVS totals`
- `fix(g1): quarantine dead AVS status fact`
- `fix(g1): close AVS typed-contract audit gaps`
- `docs(g1): record AVS Opus audit evidence`
- `docs(g1): align AVS thirteenth-pension contract`

---

### P0 — none

---

### P1 — none (previous P1 resolved)

**Prior P1 closed — cross-tier AVS annualization drift.**

`services/backend/app/services/retirement/avs_estimation_service.py:160`: `nb_rentes = AVS_ORDINARY_PAYMENTS_PER_YEAR` (constant = 12, always). The constants `AVS_13EME_RENTE_ACTIVE`, `AVS_NOMBRE_RENTES_PAR_AN`, and `AVS_13EME_RENTE_FACTOR` are deleted from `constants/social_insurance.py`. A grep for all ×13 symbols across the backend returns zero hits. Backend `rente_annuelle` is now `rente_mensuelle × 12`, matching the mobile contract.

The fabricated `avsRenteMensuelle` / `avsRenteAnnuelle` output in `GET /overview/me` is removed (`overview.py:201–203`): contribution-year history is correctly not treated as a pension amount. Five new unit tests in `test_overview_me.py:35–87` pin that no AVS field appears in `prevoyance.values` regardless of `avsContributionYears` value or `householdType`. The steady-state E2E tests (`test_steady_state_e2e.py:167–169`) confirm `renteCoupleMensuelle is None` and `renteAnnuelle == renteMensuelle × 12` for all three user personas (Julien, Marc, Sophie).

---

### P2 — two pre-existing, documented, dormant

**P2-A — Generic `independant-self-scenario` owner ID** (`independants_service.dart:648`, behind `enableAvsThirteenthScenarioCashflow = false`). Not introduced by this diff; confirmed still open.

**P2-B — Supplement fused into projection bars without a dedicated renderer** (`independants_service.dart:651–665`, behind same flag). Not introduced by this diff; confirmed still open.

Both are unreachable in production. No new P2 introduced.

---

### Confirmed correct

**1. `officialDecemberNotEntitled` short-circuits before evidence weakness (`avs_thirteenth_pension_calculator.dart:443–456, 668–689`).**
`sourceDate == null` and `documentOrProviderRef == null` now accumulate into `missingMonthlyEvidenceField` (deferred), not an immediate return. The `officialDecemberNotEntitled` branch at line 668 fires before the deferred check at line 683. New test `official not-entitled legal zero ignores an absent prior source` (`avs_thirteenth_pension_calculator_test.dart:1285`) proves that an official December `notEntitled` yields `explicitlyNotEntitled + certified=0` even when month 1 has no sourceDate or reference. The `unknown` state's `missingMonthlyHistoryField` (line 537) independently gates `eligibleOldAgePensionsPaidChf` to null in the same branch. All three precedence layers are exercised.

**2. `bothDisability` + married/registered → `AvsCoupleCapState.pending` (`avs_calculator.dart:355–362`).**
New priority check `marriageEquivalent && bothDisability` fires before the `cohabiting → notApplicable` branch. LAVS art. 35 al. 1 does cap AI+AI for married couples via LAI art. 37 al. 1bis. Test `avs_couple_legal_contract_test.dart:449` now asserts `pending` for both `married` and `registeredPartnership` status. Correct semantic.

**3. `ChfAmount.tryFromLegacyDouble` (`avs_thirteenth_pension_calculator.dart:17–27`, `independants_service.dart:640–647`).**
Sub-centime registry overrides no longer throw inside `calculateLppVolontaire`. New service test `independants_avs_thirteenth_scenario_test.dart:18` injects `avs.max_monthly_pension = 2520.123`, asserts `avsThirteenthScenario is null`, `avsThirteenthScenarioFailureReadiness = providerCorrectionRequired`, and `projectionSansLpp == 30240` (falls back to `recurringAvsAnnualMax`).

**4. `hasAvsGaps` dead reader quarantined (`G1-ledger-gap-matrix.md:97`, `test_g1_p0_ledger_dead_keys.py:1378–1409`).**
Financial Fitness consumes `AvsGapEvidence.selfCertifiedYears` (certificate-owned), not the declared `avsGapStatus` typed fact. `reader_evidence` and `consumers` are now `NONE`. The gate adds a positive lock (`hasAvsGaps` quarantine contract check) and a negative fixture that asserts a forged reader would be caught. `import copy` is present at line 3 of the gate file — `copy.deepcopy` call is safe.

**5. `rente_couple_mensuelle` always null; schema and tests aligned.**
`AvsEstimationRequest.is_couple` is now documented as civil context only. `rente_couple_mensuelle: Optional[float]` was always nullable per the schema; returning `None` is a valid, backward-compatible value. `test_retirement.py:test_couple_status_does_not_fabricate_partner_pension` and `test_avs_estimate_camelcase_aliases` both assert `None`. E2E steady-state tests updated identically.

**6. No dangling ×13 symbols in the backend.**
Grep across `services/backend` for `AVS_13EME_RENTE_ACTIVE`, `AVS_NOMBRE_RENTES_PAR_AN`, `AVS_13EME_RENTE_FACTOR`, `annualRente` returns zero hits.

**7. OpenAPI schema hash rename (`h_38b5376f952f` → `h_2185b7eb6cdc`) for `PremierEclairageResponse`.**
Purely cosmetic — driven by description-string change. The schema structure is identical. API paths unchanged. No client impact.

---

### G1 gate status

The baseline audit rated `06115ed38` at **8.2/10 NO-GO** with one confirmed P1 (cross-tier drift). This diff closes that P1. The two open P2s (generic owner, separate renderer) are dormant behind a disabled flag and were pre-existing. No new findings. G2 remains blocked by the still-open matrix gaps and tracking tickets, not by this diff.

**PASS** for this change set. G1 score improves; G2 blocking state is unchanged by this audit.
~~~

## Captured stderr (verbatim)

~~~text

~~~

## Gate disposition

**PASS for the bounded AVS fix slice.** No P0/P1 remains in this rerun. The two mobile activation P2s remain open, and **G1 globally remains NO-GO** for its other hard-floor gaps; this report does not permit G2/G3.
