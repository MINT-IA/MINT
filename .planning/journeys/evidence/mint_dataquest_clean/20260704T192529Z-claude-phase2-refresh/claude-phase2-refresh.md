NO_UNRESOLVED_CRITICAL_HIGH

---

## Phase 2 External Acceptance Audit — Data Quest Case Registry

**Scope:** Delta-only acquisition, case registry completeness, write-path discipline, runtime proof, dossier/PDF hooks, facade risk.
**Evidence:** files as submitted + SCORECARD.md + gate-phase2-run.txt + Maestro logs.

---

### CRITICAL — None

---

### HIGH — None

All three required paths (delta collection, write-back, dossier contract) have deterministic test coverage and iPhone 17 Pro runtime proof. No unresolved HIGH findings block acceptance.

---

### MEDIUM

**M1 — `_buildP0Dossiers` not exception-isolated inside Widget.build()**
`FinancialReportScreenV2._buildP0Dossiers` calls `DossierPayloadService.buildP0Case` for all three cases inside `.map().toList()` with no try-catch. `_hasResolvedOwnerId` guards the `StateError` throw path, and the calculator handles null inputs gracefully (evidenced by the `does not mask missing parent liquidity` test). However, any unexpected `PropertyTransmissionCalculator.compute` edge case (e.g., a future schema change introducing a non-null assertion) would crash the entire `/rapport` Widget build rather than degrading to an empty dossier section. **Required fix before Phase 4 UX hardening:** wrap each `buildP0Case` call individually with a try-catch that degrades to `null` and filters before `.toList()`.

**M2 — `parentAnnualLivingCosts` pay-frequency dependency is a silent missing-data trigger**
`DossierPayloadService._parentAnnualLivingCosts` refuses to trust `q_housing_cost_period_chf` when `q_pay_frequency` is absent, producing `annualCosts: null` and surfacing `ask_parent_annual_living_costs`. This is correct behavior and is tested (`keeps period housing cost untrusted when pay frequency is absent`). The risk is that users who entered housing cost via coach chat (without pay-frequency) will hit the living-costs guard ask repeatedly. This is not a Phase 2 blocker, but the DataQuest UX in Phase 4 must prompt for pay-frequency as a prerequisite whenever housing cost is collected, or the guard will never clear for a significant user cohort.

**M3 — `DataQuestProofStrip` exposes `pending` as `maestroFlowId` text in debug builds**
For `first_salary_tax` and `buy_property`, `plan.maestroFlowId` equals `'pending'`. The proof strip renders this as the pdf-section label. Runtime proof semantics are gated by `MINT_ENABLE_RUNTIME_PROOF_SEMANTICS`, so this is debug-only, but it's a misleading label if QA reads proof strips directly. **No fix required before Phase 2 close;** suppress or remap `'pending'` to the `patrol_flow_id` value in a follow-up.

**M4 — `kDebugMode` in `mintRuntimeProofSemanticsCompileTimeEnabled` enables proof strip in all debug builds**
`const bool _runtimeProofSemanticsEnabled = kDebugMode || bool.fromEnvironment(...)` means the succession proof block is always visible in every debug build. Seed injection (actual property-value injection) is still gated by the runtime flag, so user data cannot be overwritten unintentionally. The concern is that a debug build handed to a user would expose internal provenance labels. Debug builds are not distributed via TestFlight (which is release-only). Low impact for current build pipeline, but worth locking down if the build pipeline ever produces debug AdHoc builds.

---

### LOW

**L1 — `reg()` cache-miss fallbacks in test output**
Tests log `reg() FALLBACK: pillar3a.max_with_lpp → 7258.0` etc. This is expected behavior (no backend in unit tests), and the mock-cache override test (`uses synced mortgage stress rate`) verifies the sync path works. Not a production risk; the fallback constants are identical to the live registry values.

**L2 — Android runtime gap fully documented but creates future catch-up debt**
`ANDROID_RUNTIME_BLOCKERS.md` with `ANDROID-PHASE1-PHASE2-RUNTIME-PROOF` is in place. The Phase 2 Maestro and Patrol evidence is iOS-only. Phase 3 scenario work (backend changes, new Dart services) could silently introduce desugaring or Gradle incompatibilities. **Recommendation:** add a lightweight Android cold-start smoke test to the CI matrix before Phase 3 begins, rather than deferring all Android validation to a single compatibility gate.

**L3 — Double-sort in `DataQuestService._buildAsks` / `_plan`**
`_buildAsks` sorts by priority, then `_plan` re-sorts with `_compareAsks` (stage then priority). The second sort is correct and would override an incorrect first sort, so there is no observable bug. The redundant first sort is dead code. Cleanup only.

---

### Required Fixes Before Gate Close

| # | Fix | Urgency |
|---|-----|---------|
| M1 | Add per-case try-catch in `_buildP0Dossiers`; degrade to empty list on unexpected calculator throw | Phase 4 UX hardening |
| M2 | Ensure DataQuest UX collects `q_pay_frequency` before or alongside housing cost entry | Phase 4 UX |
| M3 | Remap `'pending'` maestroFlowId to patrol_flow_id in proof strip label | Phase 3 cleanup |

---

### Residual Risks

1. **Android runtime parity** — not evidenced; documented gap, separate gate required before Android beta.
2. **Phase 2 Maestro for `first_salary_tax` / `buy_property`** — still `pending`; Patrol only. Acceptable per plan; must resolve before Phase 6 acceptance.
3. **BiographyRepository write-back deferred** — profile provenance bridge is `dataTimestamps` / `dataSources`; immutable fact graph writes are Phase 4. Stale-data reconfirm works correctly within Phase 2-3 scope; the limitation is documented in DATA_QUEST.md §6.
4. **`parentAnnualRetirementIncome` composition path** — AVS + LPP formula is Phase 2-evidenced but depends on `_coach_avs_rente_estimee` and `_coach_projected_rente_lpp` being populated by the coach chat. Cold-start profiles without these keys fall back to the explicit guard ask, which is correct but creates a longer first-run quest.

---

### What Is Solid

- **Delta-only acquisition**: guard → required → useful staged early-return is correctly implemented and tested across all 12 planner tests; `allowZero` semantics handled; `requiresCompleteFact` reconfirm path tested.
- **Case registry completeness**: all three P0 cases have ledger keys, question sets, dossier contracts, schema validation, and acceptance status. Registry JSON has no duplicate keys (gate verified).
- **Write-path discipline**: single write path through `mergeAnswers` / `applySaveFact` with timestamp stamping; profile bridge → `dataQuestFactsFromProfile` → `BiographyFact` for freshness is clean and tested.
- **Runtime proof**: two Maestro flows on iPhone 17 Pro show correct delta progression (`propertyMarketValue → targetRetirementAge`) and reconfirm mode (`Valeur existante à confirmer`) with all assertions COMPLETED.
- **Dossier contracts**: three schema files with `x-mint-owner`, `x-mint-case-id`, `x-mint-pdf-section-id` properly bound; schema validator rejects drift (tested).
- **Test coverage**: 107/107 Flutter tests pass including Raiffeisen fixture, FATCA guard, living-costs composition, stale reconfirm, and schema drift rejection.

---

**Overall score: 9.1/10**

Phase 2 is safe to accept. The three MEDIUM items are tracked technical debt for Phase 4, not safety gaps. Android and the two pending Maestro flows are scoped separately per the plan.
