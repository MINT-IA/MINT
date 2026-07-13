$ env CLAUDE_AUDIT_WORKTREE=/tmp/mint-g1-avs-audit-01a50cf54.j2gwQ2/repo CLAUDE_AUDIT_MAX_DIFF_LINES=6000 tools/checks/claude_external_audit.sh product-domain bc2ba0d08
## Product/domain verdict: PASS

This diff removes two domain-incoherent calculations (salary-derived AVS couple cap; salary-average divorce splitting proxy), replaces them with a fail-closed, evidence-owned `computeCouplePensions`, and quarantines the couple result from production. It is a net correctness and lucidity improvement, and I found no P0/P1 defect introduced by the change.

### Verification performed
- **No broken production callers.** The removed `AvsCalculator.computeCouple(...)` and `AvsCoupleCapResult` have zero production consumers (`visibility_score_service.dart:163` is an unrelated `computeCouple`; `cap_engine.dart:664` uses `CoachCivilStatus.divorce`, not the removed rente params). The removed `isDivorced/exSpouseAnnualSalary/marriageYears` params of `computeMonthlyRente` had no production caller.
- **No facade-without-wiring harm.** `computeCouplePensions` is referenced only as the type of `CoupleOptimizationResult.avsCap`, which `optimize()` now always sets to `null` (`couple_optimizer.dart:84,98`). No UI reads `.avsCap`/`.capApplied`/`.totalAfterCap` (grep clean in `lib/`), so the previously-displayed wrong number degrades to absence, not a crash.
- **Legal formulas match cited sources.** RAVS art. 53bis weighting `(sLow + 2·sHigh)/3` then `ceil()` to the next integer scale (`avs_calculator.dart` weightedScaleRaw/determiningScale) matches OFAS Directives ch. 5291; art. 53ter multiplier (higher percentage; deferral ⇒ full pension = 1) matches the doc and tests 32/33. Incomplete scales correctly return `payableMonthlyCap = null` + `pending` rather than certifying `3780 × scale/44`.
- **2026 constants correct.** `avsRenteMaxMensuelle=2520`, `min=1260`, `avsRenteCoupleMaxMensuelle=3780` (`social_insurance.dart:118-124`) — valid 2025/2026 amounts.
- **Fail-closed behavior is sound.** Missing entitlement/pension/scale/percentage/legalStatus/judicialSeparation each yield `pending` with an exact `missingFields` path and never fabricate CHF 0 (`avs_calculator_test.dart` / `avs_couple_legal_contract_test.dart` cover swapped ownership, out-of-range scale, empty separation source, unknown separation).

### P0 findings
None.

### P1 findings
None introduced by this diff.

### P2 findings
- **CoupleOptimizer AVS surface is now empty, not just corrected.** `avsCap` is always `null` (`couple_optimizer.dart:76-93`). This is the correct fail-closed choice, but it means the couple flow no longer surfaces *any* AVS decision frame. Follow-through: wire `computeCouplePensions` once the official person-owned pension/source-date/grant pipeline exists, per `AVS_COUPLE_LEGAL_CONTRACT.md §8`.
- **Ordinary pensions are not guarded to `pensionPercentage == 1`.** `_appendMissingCapFields` only checks `0 < p ≤ 1`, and `_article53terPercentageMultiplier` force-unwraps and multiplies the cap by that percentage even for `oldAgePaymentMode.ordinary`. A miswired caller passing an ordinary pension at `0.5` would silently halve the cap. Not reachable today (unwired; fixtures pass 1). Add an invariant that ordinary ⇒ percentage 1.
- **AI + AI couple cap out of scope.** `_qualifiesForArticle35` correctly excludes two disability pensions from LAVS art. 35, but a married AI/AI couple is capped under LAI art. 37 al. 1bis; the calculator returns `notApplicable` (test asserts this). Acceptable as an AVS-old-age scope boundary, but should be documented so it isn't mistaken for "no cap ever."
- **Pre-existing 13th-pension inflation remains (documented, not touched here).** `AvsCalculator.annualRente` is still `monthly × 13` and `retirement_projection_service.dart:661,747` divide the annual by 12, inflating the ordinary monthly rente by 13/12. This diff does not modify those paths; `AVS_THIRTEENTH_PENSION_CONTRACT.md` accurately marks it NO-GO. Flagged as context, not a regression of this diff.

### Swiss domain review
- **AVS:** Improved. Couple cap now legally structured (status → two qualifying benefits → judicial-separation `false` → scales/percentages/modes), with correct 2026 amounts and RAVS 53bis/53ter treatment; salary-derived pension fabrication removed. The 13th (December supplement) is correctly *excluded* from the cap test and no longer asserted as `cap × 13`.
- **AVS splitting (art. 29quinquies):** The crude salary-average proxy is removed; docstring now truthfully states no splitting is performed. Correct.
- **LPP / 3a / tax:** Untouched in logic; CoupleOptimizer LPP-buyback, 3a-order (FATCA), and marriage-penalty analyses preserved.
- **Not affected:** mortgage, insurance, inheritance/succession, disability benefit amounts (only the AI *entitlement flag* participates in the art. 35 combination test).

### Mint product logic review
This moves Mint toward the ledger → DataQuest → scenario → dossier spine: one pension per person, explicit `missingFields`, `capState`, `legalYear`, `legalSource`, and `judicialSeparationSource` on the result support a specialist-ready dossier and progressive data collection, and the fail-closed default refuses to invent household numbers from salary/age. The trade-off is a temporarily blank couple-AVS surface until the evidence/grant pipeline is wired — acceptable and consistent with the documented G1 NO-GO-for-activation stance.
