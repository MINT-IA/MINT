# Claude external audit rerun — AVS G1 fixes — product/domain — `c31921a6a`

## Immutable scope

- Global G1 status: **NO-GO**. This bounded rerun does not authorize G2/G3.
- Exact rerun range: `06115ed38...c31921a6a` (`06115ed388c4a1b30abf24314efc83893fb75eca` → `c31921a6a859f4225c2bea963bc78933916b6ce9`).
- This is the **single Sonnet product/domain rerun** allowed after the Opus first pass; it was launched only after the code rerun completed.
- Command:

```sh
env CLAUDE_AUDIT_RERUN=1 CLAUDE_AUDIT_EFFORT=high CLAUDE_AUDIT_WORKTREE=/tmp/mint-g1-avs-sonnet-c31921a6a.sUWIlf/repo CLAUDE_AUDIT_MAX_DIFF_LINES=7000 tools/checks/claude_external_audit.sh product-domain 06115ed38
```

- Wrapper: `tools/checks/claude_external_audit.sh` exclusively; no raw Claude invocation.
- Model / effort: **Sonnet / high**, selected by the wrapper; no non-Sonnet rerun, max effort, max-turn setting, large-diff bypass, or project settings.
- Started UTC: `2026-07-13T16:56:21Z`; ended UTC: `2026-07-13T17:00:25Z`.
- Exit code: **0**; stdout: **83 lines**; stderr: **0 lines**.

## Clean detached-clone and budget proof

- Detached clone: `/tmp/mint-g1-avs-sonnet-c31921a6a.sUWIlf/repo`.
- HEAD: `c31921a6a859f4225c2bea963bc78933916b6ce9`; base: `06115ed388c4a1b30abf24314efc83893fb75eca`.
- `git status --short --branch`: `## HEAD (no branch)` before and after both sequential audits.
- Unified prompt diff: **6,521 lines**, within the explicit **7,000-line** budget; no bypass.
- Short stat: **21 files changed, 768 insertions(+), 330 deletions(-)**.

## External verdict and MINT triage

- Claude product/domain verdict: **PASS** for this rerun range.
- **P0: none.**
- **P1: none.** The cross-tier ×13 contradiction, fabricated overview pension, partner fabrication risk, AI+AI semantic state, legal-zero precedence and sub-centime crash are all closed or correctly quarantined.
- **P2 still open:**
  1. **Generic owner** — dormant independent scenario uses `independant-self-scenario` instead of an authenticated person-scoped identity.
  2. **No dedicated December renderer** — the dormant supplement is fused into aggregate bars and has no distinct screen/PDF cashflow line.
  3. **Legal-source label precision before rendering** — the Dart result says `OFAS C 13 RV, version 01.01.2026`, while the checked-in primary-source table distinguishes *valid from 01.01.2026* from *state 17.06.2026*. The legal sources are now present and authoritative (Fedlex LAVS art. 34ter; RAVS 52ater–52aquinquies; OFAS C 13 RV), so the prior unsupported-source P1 is closed, but the dormant display label should be reconciled before dossier/UI exposure.
  4. **Stale overview next-step copy for complete users** — after quarantining the invalid AVS estimate, `_premier_eclairage` always asks users with age+canton to enter LPP and 3a even when those facts are already present. This is honest about amounts but fails progressive DataQuest/user-value logic; route the copy to the next actually missing fact before claiming the overview journey complete.

The first two are pre-existing and protected by the default-off flag. The last is a newly surfaced non-blocking product follow-up. None is P0/P1, but G1's global NO-GO remains unchanged.

## Swiss-domain confirmation

- **Ordinary AVS vs annual supplement:** twelve ordinary monthly payments are the recurring annual amount; the 13th old-age-pension supplement is a separate December cashflow and is explicitly excluded from backend annual/cumulative figures.
- **Owner-scoped couple logic:** civil status alone cannot produce a couple pension. `renteCoupleMensuelle=None` is the correct fail-closed backend response without two person-owned pension inputs, splitting and cap facts.
- **AI+AI:** married/registered AI+AI cap readiness is `pending` without the LAI art. 37 al. 1bis provider; no total is fabricated.
- **Legal zero:** an official December `notEntitled` fact correctly produces a certified zero before missing historical source metadata, while unknown entitlement still withholds the paid base.
- **Exact money:** a sub-centime regulatory override becomes `providerCorrectionRequired`, never a crash or silent rounding.
- **AVS gaps:** a declared `hasAvsGaps` status is not treated as a certificate-owned gap number; the dead fact is honestly quarantined.
- **Legal sources:** the checked-in contract maps the implementation to current primary material: Fedlex LAVS art. 34ter, Fedlex RAVS arts. 52ater–52aquinquies/53 al. 2, OFAS C 13 RV valid 01.01.2026 and state 17.06.2026, plus the OFAS implementation page. No unsupported legal conclusion reaches an active renderer.
- **LPP/3a/tax/mortgage/insurance/succession:** not materially changed by this rerun range.

## MINT product-logic confirmation

- Removing AVS values from `/overview/me` is an honest quarantine: contribution years alone do not establish pension amount, and missing never becomes zero.
- The backend AVS estimator is still a live educational endpoint, but its ordinary payment semantics, OpenAPI descriptions, SOT contract and tests now agree.
- Partner facts remain optional and person-owned; household status does not synthesize a second person.
- `hasAvsGaps` is not presented as live solely to satisfy a matrix; the forged-reader negative fixture protects the no-facade rule.
- The default-off mobile supplement path is a real caller, not dead code, but it is not activation-ready until the owner and dedicated-renderer P2s close.
- The overview copy P2 must be resolved through progressive missing-fact selection so a complete user is not asked again for fresh known LPP/3a facts.

## Captured stdout (verbatim)

~~~text
Product/domain verdict: PASS

---

## Summary

The diff resolves the sole P1 from the prior code audit (backend AVS annualization ×13 vs. mobile ×12), closes three pre-existing P2s, and introduces no new P0 or P1 finding. G1 overall remains NO-GO for activation because three dormant P2s are still open, but this change set is clean from a product and Swiss-domain standpoint.

---

## P0 findings

None.

---

## P1 findings

None. Previous P1 is confirmed resolved:

**RESOLVED — Backend AVS annualization drift (×13 → ×12)**
- `services/backend/app/services/retirement/avs_estimation_service.py`: `nb_rentes = AVS_ORDINARY_PAYMENTS_PER_YEAR` (always 12); `rente_annuelle = round(rente_mensuelle * 12, 2)`.
- `services/backend/app/constants/social_insurance.py`: `AVS_NOMBRE_RENTES_PAR_AN`, `AVS_13EME_RENTE_FACTOR`, `AVS_13EME_RENTE_ACTIVE` deleted.
- `services/backend/app/services/regulatory/registry.py`: `avs.13th_pension_factor` entry removed; remaining activation keys (`avs.13th_pension_active`, `avs.13th_pension_start_year`) retain their informational role only.
- Tests: `test_rente_annuelle_contains_only_twelve_ordinary_payments` asserts `renteAnnuelle == 30240.0` and `nombre_rentes_par_an == 12`; endpoint test asserts `data["renteAnnuelle"] == data["renteMensuelle"] * 12` and `data["totalCumule"] == data["renteAnnuelle"] * (87 - 65)`.

---

## P2 findings

### Closed in this diff

**P2-A — `bothDisability + married/registered` cap state mislabeled `notApplicable` → FIXED**
`apps/mobile/lib/services/financial_core/avs_calculator.dart:350-370`: The new `marriageEquivalent && bothDisability` guard returns `AvsCoupleCapState.pending` when the LAI art. 37 al. 1bis cap provider is missing, rather than the semantically incorrect `notApplicable`. LAVS art. 35 al. 1 does apply a household cap to two AI pensions for married and registered-partnership couples; `notApplicable` was wrong even though no amount reached users. Test updated: `avs_couple_legal_contract_test.dart:449` now asserts `pending`.

**P2-B — `ChfAmount.fromLegacyDouble` throws on sub-centime registry override → FIXED**
`apps/mobile/lib/services/financial_core/avs_thirteenth_pension_calculator.dart:10-30`: `tryFromLegacyDouble` returns `null` for non-exact-centime values; `fromLegacyDouble` delegates to it. `apps/mobile/lib/services/independants_service.dart:629-646`: uses `tryFromLegacyDouble`, stores failure as `avsThirteenthScenarioFailureReadiness = providerCorrectionRequired`. New test `independants_avs_thirteenth_scenario_test.dart` proves the graceful path with `avs.max_monthly_pension: 2520.123`.

**P2-C — Legal-zero precedence over absent monthly source → FIXED**
`apps/mobile/lib/services/financial_core/avs_thirteenth_pension_calculator.dart:465-480`: `missingMonthlyEvidenceField` now accumulates as a deferred variable; the official `notEntitled` precedence check runs before the deferred evidence check. New test `avs_thirteenth_pension_calculator_test.dart`: `official not-entitled legal zero ignores an absent prior source` proves that official December `notEntitled` produces `explicitlyNotEntitled` + CHF 0 even when a prior month has no `sourceDate`.

### Remaining open (pre-existing, all behind default-off flag)

**P2-1 — Generic `independant-self-scenario` owner ID**
`apps/mobile/lib/services/independants_service.dart:648`: `ownerId: 'independant-self-scenario'` is a literal, not the authenticated pseudonymous owner. Dormant behind `enableAvsThirteenthScenarioCashflow = false`. Must be replaced with the real person-scoped identity before activation.

**P2-2 — December supplement fused into projection bars, no separate renderer**
`apps/mobile/lib/services/independants_service.dart:661-675`: When the flag is on, `eligibleOldAgeCashflowWithSupplementChf` is still folded into `projectionSansLpp`/`projectionAvecLpp`. No screen or PDF line renders the supplement as a distinct December cash-flow event. Must be split before activation per contract section 7.

**P2-3 — Dormant calculator `_legalSources` strings not visible in diff**
The prior product-domain audit noted `avs_thirteenth_pension_calculator.dart:284-290` embeds `_legalSources` strings. The contract doc now correctly cites `LAVS art. 34ter` and `RAVS arts. 52ater-52aquinquies`, but whether the Dart constant was updated is not visible in the diff. P2 because the calculator is dormant; verify before surfacing in any dossier/PDF.

**P2-4 — `premier_eclairage` in overview does not advance for fully-complete users**
`services/backend/app/api/v1/endpoints/overview.py:_premier_eclairage`: For a user who has already provided LPP + 3a (like Julien at completeness ≥ 0.75), the function still says "prochaine étape : renseigner ton LPP et ton 3a." This is a UX regression compared to the prior version, which at least attempted a combined pension figure (albeit incorrectly). The wrong number was worse, but the current CTA is stale for complete users. Requires a follow-up branch that detects LPP presence and advances the prompt to the next missing decision (e.g., target retirement age, budget, or dossier).

---

## Swiss domain review

**AVS (1er pilier) — directly affected**
- `renteAnnuelle = renteMensuelle × 12` is now correct for the ordinary recurring flow. The December supplement is a separate annual cash-flow under LAVS art. 34ter; absorbing it into a "×13" annual figure was legally incoherent. ✓
- `rente_couple_mensuelle = None` is correct: civil status (`is_couple: bool`) is not evidence of a partner's pension amount, contribution history, splitting (LAVS art. 29quinquies), or the couple cap (LAVS art. 35). ✓
- `bothDisability + married → pending` is correct: LAVS art. 35 al. 1 applies a joint cap to two disability pensions for married couples, referencing LAI art. 37 al. 1bis; the cap cannot be resolved without the provider's table. ✓
- `hasAvsGaps` quarantine is correct: `FinancialFitnessService` consumes `AvsGapEvidence.selfCertifiedYears` (certificate-owned), not the declared `avsGapStatus` flag. Marking `reader_evidence = NONE` and enforcing it in the gate test is honest. ✓
- Overview no longer derives a pension from `avsContributionYears` alone. Contribution history is not a pension amount under LAVS art. 34 (RAMD-based formula requires salary). SOT.md section 7 codifies this as a permanent invariant. ✓
- Legal citations corrected: LAVS art. 34ter (not "34 nouveau"), RAVS arts. 52ater–52aquinquies (implementation of the per-twelfth rounding algorithm), C 13 RV state 17.06.2026. ✓
- December supplement disclosure in `premier_eclairage`: "Le supplément annuel AVS reste séparé, versé en décembre, non inclus dans ces montants ordinaires et à confirmer auprès de ta caisse AVS." This is appropriate educational language, not advice or a guarantee. ✓

**LPP, 3a, tax, mortgage, insurance, succession** — not materially affected by this diff.

---

## MINT product logic review

This diff moves MINT further along the ledger → DataQuest → scenario → dossier spine in three ways:

1. **Honest gap over fabricated confidence**: Removing AVS estimation from the overview (`_build_prevoyance` no longer calls `AvsEstimationService`) means the product no longer tells a user their AVS pension based on a contribution-year proxy that cannot produce a reliable number. Missing stays missing. This is the lucidity model working correctly.

2. **Ledger integrity enforced by gate**: The `hasAvsGaps` quarantine is now machine-verified by `test_g1_p0_ledger_dead_keys.py`. The negative fixture (`forged_reader` test) proves the gate catches any attempt to falsely claim a production consumer. The ledger cannot silently absorb a dead key.

3. **Specialist handoff language**: Every AVS `premier_eclairage` path now terminates with an explicit instruction to confirm with the competent AVS caisse. This is the correct handoff for a calculation that MINT cannot certify without the fund's monthly data.

The remaining gap is user-value delivery for complete users: when a user has provided LPP + 3a + income, the overview primer still says "fill in your LPP," which is stale. A follow-up should advance the CTA to the next decision frame (retirement age scenario, budget floor, or specialist dossier trigger). This does not block the current diff.
~~~

## Captured stderr (verbatim)

~~~text

~~~

## Gate disposition

**PASS for the bounded product/domain AVS fix slice.** No P0/P1 remains. The activation and progressive-copy P2s are explicitly recorded, and **G1 globally remains NO-GO**; G2/G3 stay forbidden.
