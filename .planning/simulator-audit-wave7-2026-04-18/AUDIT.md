# Wave 7 — Simulator audit consolidated
*2026-04-18 — 3 parallel expert panels, 8 services, golden couple Julien (swiss_native) + Lauren (expat_us)*

## Summary

| Panel | P0 | P1 | P2 | Scope |
|---|----|----|----|-------|
| Fiscal / Swiss-brain (LSFin, LPP, LIFD, OPP2/3, CC) | 11 | 9 | 7 | forecaster, expat, financial_report, budget |
| Actuarial / mathematical | 13 | 21 | 5 | arbitrage, Monte Carlo, withdrawal seq, tornado |
| Edge-cases / fuzz | 17 | 23 | 9 | all 8 services |
| **Unique (after dedup)** | **~35** | **~45** | **~18** | |

Full per-panel reports in:
- `.planning/simulator-audit-wave7-2026-04-18/AUDIT-fiscal.md`
- `.planning/simulator-audit-wave7-2026-04-18/AUDIT-actuarial.md`
- `.planning/simulator-audit-wave7-2026-04-18/AUDIT-edgecases.md`

## Ship-blocker triage (P0 ordered by blast radius × legal risk × single-file scope)

### Tier A — must fix before any release

**A1. Named products "Zak, Neon" in action recommendations** (financial_report_service.dart:606)
- Panel: fiscal P0-R cross + P0-R5
- Breach: LSFin art. 3 let. c (conseil en placement interdit).
- Fix (trivial): remove "ex: Zak, Neon" → generic "compte épargne sans frais".

**A2. Ranking leak in arbitrage output** (arbitrage_engine.dart:390, 1018, 394-395 + premier éclairage text)
- Panel: actuarial cross-compliance.
- Breach: CLAUDE.md §6 No-Ranking; `betterOption = 'capital' | 'rente'` surfaces in UI.
- Fix: drop `betterOption` string, describe trade-off neutrally in premier éclairage.

**A3. Invented 8 %/5 % capital tax** (financial_report_service.dart:372-378)
- Panel: fiscal P0-R6.
- Breach: LIFD art. 38 inverted; math error `taxMultiple = totalCapital * 0.05` self-cancels.
- Fix: delegate to `RetirementTaxCalculator.capitalWithdrawalTax(capital, canton, isMarried)`.

**A4. Married `×0.85` magic factor** (financial_report_service.dart:636-645)
- Panel: fiscal P0-R3.
- Breach: LIFD art. 36 al. 2bis cantonal splitting varies 8-25 %; hardcoded 0.85 inverts.
- Fix: reuse Wave 3 cantonal matrix (`marriedCapitalTaxDiscountFor`) already on disk.

**A5. Child deduction hardcoded 6 500 CHF** (financial_report_service.dart:237-239)
- Panel: fiscal P0-R4.
- Breach: LIFD art. 35 value is 6 700 CHF (2025); cantonal varies 6 500-12 200.
- Fix: `reg('lifd.child_deduction_federal_2025', 6700)` + cantonal table.

**A6. Partner 3a auto-injected for FATCA Lauren** (forecaster_service.dart:551-568)
- Panel: fiscal P0-F1 + actuarial silent-fallthrough.
- Breach: IRC §1291 PFIC + IRS Notice 2014-7; projection inflates Lauren's capital by ~145k triggering illegal downstream recommendations.
- Fix: archetype check before auto-injecting; default `canContribute3a` to null, surface `archetypeBlocker` when expat_us.

**A7. Rachat+EPL 3-year anti-abuse rule never enforced** (arbitrage_engine.dart:513-535, 1138-1401)
- Panel: actuarial P0-A2.
- Breach: ATF 142 II 399 + 148 II 189 — rachat suivi d'EPL dans les 3 ans = abus, redressement fiscal. MINT is protection-first and this is THE trap.
- Fix: accept `plannedCapitalWithdrawalAge`, surface `alertes` + reverse `taxSavingRachat` when overlap detected.

### Tier B — ship-blocker on next sprint

**B1. LPP Monte Carlo σ=3 % undercalibrated** (monte_carlo_service.dart:187-188) — false certainty, Pictet BVG-25 historical σ ≈ 6.5 %.
**B2. Inflation drawn once per trajectory** (monte_carlo_service.dart:124-125) — kills sequence-of-returns realism.
**B3. Forfait fiscal flat 25 %** (expat_service.dart:526, 530) — LIFD art. 36 progressive inverted.
**B4. `planDeparture` "Impot de sortie reduit"** (expat_service.dart:635-642) — factually false, PFIC exit silent for US persons.
**B5. LPP UE/AELE oblig/surob split missing** (expat_service.dart:644-652) — LFLP art. 25f ignored.
**B6. Withdrawal sequencer schedules largest 3a FIRST** (withdrawal_sequencing_service.dart:390, 407-411) — opposite of tax-optimal.
**B7. Tornado swallows all exceptions → returns 0** (tornado_sensitivity_service.dart:582-594) — crashed variables rank as top drivers.
**B8. Budget service no SafeMode escalation when pct≥70 %** (budget_service.dart:23-32).
**B9. Canton silent fallback to ZH** across 8 files (cross-file C1).
**B10. `CoachProfile.age` returns 0 when birthYear invalid** (coach_profile.dart:1654-1658) — systemic sentinel propagation.

### Tier C — P1 batch

See per-panel reports. Highlights:
- LPP reform 6.8% rejection referendum notes (need ADR).
- ALCP/US totalisation separation.
- Couple LAVS cap extension to `partenariatEnregistre` (LPart art. 13a).
- Cantonal wealth tax 0.3% flat → progressive by canton.
- GE quasi-résident 31.03 deadline.
- AVS volontaire interdit UE/AELE post-2012.

## This-session fix plan

Targeting **5 atomic P0 commits** from Tier A (highest legal risk, single-file scope, minimal cross-dependency):

1. A1 + A2 combined — wording + compliance (smallest diff, biggest legal impact).
2. A3 + A5 combined — tax math delegation + child deduction (use existing `RetirementTaxCalculator`).
3. A4 — married cantonal matrix (reuse Wave 3 map).
4. A6 — partner 3a FATCA blocker.
5. A7 — rachat+EPL 3-year anti-abuse alertes in `arbitrage_engine`.

Deferred to Wave 8:
- Tier B (requires math re-calibration + settings table design).
- Cross-file C1/C2 (systemic refactor — `resolveCanton` helper + `CoachProfile.age` nullable migration; needs its own ADR).

## Test coverage gaps discovered

- No test proves `financial_report_service` never names a product.
- No test proves `arbitrage_engine` never emits a ranking string in premier éclairage.
- No test covers FATCA partner 3a path.
- No test covers rachat+EPL overlap in arbitrage.
- No test covers `taxSingle × 0.08` vs `capitalWithdrawalTax(capital, canton, isMarried)` divergence.

All five go into Wave 7 fix commits alongside the code changes.
