# Phase 2: Fix Financial Calculations - Context

**Gathered:** 2026-04-10
**Status:** Ready for planning
**Source:** Deep audit (Financial Core) + golden couple test failures

<domain>
## Phase Boundary

Fix the LPP projection bug that causes 3 golden couple tests to fail. The bug is in `lpp_calculator.dart` when `bonificationRateOverride` (certificate-specific rate, e.g., CPE Plan Maxi 24%) is combined with `salaireAssureOverride`.

**Failing tests (3/19):**
- Test 2a: Julien LPP rente — expected 33'892, actual 45'954 (+35.6%)
- Test 2b: Lauren LPP balance @65 — expected 153'000, actual 203'570 (+33.1%)  
- Test 4: Taux remplacement couple — expected 65.5%, actual 44.75% (-31.7%)

**Other failing tests (8 more, total 11):**
- Need to identify which tests beyond golden couple are also failing
- May be cascading from the same LPP bug or unrelated

**What passes (16/19 golden + all AVS + tax):**
- AVS individual, couple, 13th rente, gap impact — all pass
- Capital withdrawal tax, marginal rates — all pass
- FATCA 3a blocking — pass
- Constants sanity check — pass

</domain>

<decisions>
## Implementation Decisions

### Root Cause Investigation
- Read lpp_calculator.dart lines 67-123 (projectToRetirement method) COMPLETELY
- Understand how bonificationRateOverride interacts with salaireAssureOverride
- Trace the calculation path for Julien (CPE Plan Maxi, bonif 24%, salaire assuré 91'967)
- Trace the calculation path for Lauren (HOTELA standard, no override)

### Fix Strategy
- Fix MUST NOT break the 16 passing golden couple tests
- Fix MUST NOT break any other passing test (9256 - 11 = 9245 tests)
- Run full test suite after fix, not just golden couple
- The fix should be in financial_core/ only — no screen-level workarounds

### Verification
- Golden couple test file: test/golden/golden_couple_validation_test.dart
- Expected values from CLAUDE.md §8 (golden couple reference)
- Julien LPP projected @65: 677'847 CHF → rente ~33'892/an at 6.8% conversion
- Lauren LPP projected @65: ~153'000 CHF
- Couple taux remplacement: 65.5%

### Claude's Discretion
- Whether the bug is in bonification rate application, salary growth projection, or conversion
- Whether ForecasterService needs a fix too (cascading) or just LPP calculator
- How to handle the 8 non-golden-couple test failures

</decisions>

<canonical_refs>
## Canonical References

### Financial Core
- `apps/mobile/lib/services/financial_core/lpp_calculator.dart` — THE file to fix
- `apps/mobile/lib/services/financial_core/avs_calculator.dart` — Reference (working correctly)
- `apps/mobile/lib/services/financial_core/tax_calculator.dart` — Reference (working correctly)
- `apps/mobile/lib/services/forecaster_service.dart` — Consumer, may need cascading fix
- `apps/mobile/lib/services/retirement_projection_service.dart` — Consumer

### Constants & Test Data
- `apps/mobile/lib/constants/social_insurance.dart` — LPP constants (verified correct)
- `apps/mobile/test/golden/golden_couple_validation_test.dart` — Golden couple tests
- `CLAUDE.md` §8 — Golden couple reference values

### ADRs
- `decisions/ADR-20260223-unified-financial-engine.md` — Financial core architecture

</canonical_refs>

<specifics>
## Specific Ideas

- Julien: CPE Plan Maxi has bonificationRateOverride=0.24 (24% vieillesse rate) and salaireAssureOverride=91'967
- Standard LPP bonification rates by age: 7% (25-34), 10% (35-44), 15% (45-54), 18% (55-65)
- CPE Plan Maxi uses 24% across all ages (enveloppant plan) — this is the override
- The bug likely applies the 24% override ON TOP of something rather than REPLACING the standard rate
- Or: the override interacts incorrectly with salary growth (compounding the override)

</specifics>

<deferred>
## Deferred Ideas

- Monte Carlo integration into main projections — Phase scope only covers calculation correctness
- Tornado sensitivity UI — not in scope
- Additional golden couple scenarios — only fix existing failures

</deferred>

---

*Phase: 02-fix-financial-calculations*
*Context gathered: 2026-04-10 via deep audit*
