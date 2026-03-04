---
name: mint-phase-audit
description: Audit a P8 Digital Twin phase after coding. Runs mechanical gate checks from P8_EXECUTION.md and reports PASS/FAIL per gate. Use after a coding agent commits a phase. Invoke with /mint-phase-audit or when asked to audit a P8 phase.
compatibility: Requires Flutter SDK, git. Works in apps/mobile/ and services/backend/.
allowed-tools: Bash(grep:*) Bash(ls:*) Bash(wc:*) Bash(flutter:*) Bash(pytest:*) Bash(git:*) Bash(cat:*) Bash(find:*)
metadata:
  author: mint-team
  version: "1.0"
---

# MINT Phase Audit — P8 Digital Twin

## Purpose

You are a **mechanical auditor**. You run the GATE CHECKLIST from `docs/P8_EXECUTION.md` for a specified phase and report PASS/FAIL per gate.

**You do NOT:**
- Give opinions
- Suggest improvements
- Refactor code
- Add features
- Write prose about what's "nice" or "concerning"

**You DO:**
- Read `docs/P8_EXECUTION.md` § Phase N GATE CHECKLIST
- Execute EACH command listed
- Report the result in the exact format below

## Audit Procedure

### Step 1: Identify the phase
The user will say "audit Phase 1" or "audit P8-1" or similar. Extract the phase number.

### Step 2: Read the gate checklist
```bash
# Read the execution plan
cat docs/P8_EXECUTION.md
```
Find the section `### PHASE {N} — GATE CHECKLIST` and extract all gate commands.

### Step 3: Execute each gate

For each gate in the checklist:

1. Run the exact command listed
2. Compare the output to the expected result
3. Report in this format:

```
GATE X.Y: [PASS|FAIL]
  Command: <the command executed>
  Result: <actual output>
  Expected: <what was expected>
  [If FAIL] Fix required: <exact description of what needs to change>
```

### Step 4: Summary

After all gates:

```
PHASE {N} AUDIT SUMMARY
========================
Total gates: X
PASS: Y
FAIL: Z

[If Z > 0]
BLOCKERS (must fix before merge):
- GATE X.Y: <one-line description of fix>
- GATE X.Z: <one-line description of fix>
```

## Phase-Specific Commands

### Pre-audit (run for ALL phases)
```bash
cd /home/user/MINT
git status
git log --oneline -5
```

### Phase 1 Gates
```bash
# GATE 1.1: Zero * 0.87 in production
grep -rn "0\.87" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | grep -v "//" | grep -v "0\.873" | grep -v "0\.879" | wc -l
# PASS if = 0

# GATE 1.2: NetIncomeBreakdown exists
grep -rn "class NetIncomeBreakdown" apps/mobile/lib/ --include="*.dart" | wc -l
# PASS if = 1

# GATE 1.3: Uses existing constants (zero hardcoding)
grep -n "cotisationsSalarieTotal\|getLppBonificationRate\|lppDeductionCoordination\|lppSeuilEntree\|FiscalService.estimateTax" apps/mobile/lib/services/financial_core/tax_calculator.dart | wc -l
# PASS if >= 5

# GATE 1.4: Zero private _estimateMarginalRate
grep -rn "_estimateMarginalRate" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | wc -l
# PASS if = 0

# GATE 1.5: CoachDashboardScreen archived
ls apps/mobile/lib/screens/coach/coach_dashboard_screen.dart 2>/dev/null | wc -l
# PASS if = 0

# GATE 1.6: No imports of CoachDashboardScreen
grep -rn "coach_dashboard_screen" apps/mobile/lib/ --include="*.dart" | grep -v archive | wc -l
# PASS if = 0

# GATE 1.7: Tests exist
ls apps/mobile/test/financial_core/net_income_breakdown_test.dart 2>/dev/null | wc -l
# PASS if = 1

# GATE 1.8: Tests pass + analyze clean
cd apps/mobile && flutter analyze 2>&1 | tail -5
cd apps/mobile && flutter test 2>&1 | tail -10

# GATE 1.9: No new magic numbers in diff
git diff HEAD~1 -- apps/mobile/lib/ | grep "^+" | grep -E "\b0\.(87|85|13)\b" | grep -v "test\|archive\|//" | wc -l
# PASS if = 0
```

### Phase 2 Gates
```bash
# GATE 2.1: 5 onboarding steps
grep -c "Step" apps/mobile/lib/screens/onboarding/smart_onboarding_screen.dart

# GATE 2.2: filterByStressType exists
grep -rn "filterByStressType" apps/mobile/lib/ --include="*.dart" | wc -l

# GATE 2.3: analytics_events.dart created
ls apps/mobile/lib/services/analytics_events.dart 2>/dev/null | wc -l

# GATE 2.4: initialProjectionSnapshot in CoachProfile
grep -n "initialProjectionSnapshot" apps/mobile/lib/models/coach_profile.dart | wc -l

# GATE 2.5: ProjectionResult.fromJson exists
grep -n "fromJson" apps/mobile/lib/services/forecaster_service.dart | wc -l

# GATE 2.6: No regression
cd apps/mobile && flutter analyze 2>&1 | tail -5
cd apps/mobile && flutter test 2>&1 | tail -10
```

### Phase 3 Gates
```bash
# GATE 3.1: New components in ConfidenceScorer
grep -n "objectifRetraite\|compositionMenage" apps/mobile/lib/services/financial_core/confidence_scorer.dart | wc -l

# GATE 3.2: scoreAsBlocs exists
grep -n "scoreAsBlocs" apps/mobile/lib/services/financial_core/confidence_scorer.dart | wc -l

# GATE 3.3: LPP weight >= 15 (per v5 redistribution)
grep -B2 -A2 "lpp\|LPP" apps/mobile/lib/services/financial_core/confidence_scorer.dart | grep -E "[0-9]+"

# GATE 3.4: Total weights = 100 (check via tests)
# Test must exist for this invariant

# GATE 3.5: data-block routes
grep -c "data-block" apps/mobile/lib/app.dart

# GATE 3.6: No regression
cd apps/mobile && flutter analyze 2>&1 | tail -5
cd apps/mobile && flutter test 2>&1 | tail -10
```

### Phase 4 Gates
```bash
# GATE 4.1: Arbitrage screens accept CoachProfile
for screen in rente_vs_capital_screen allocation_annuelle_screen calendrier_retraits_screen; do
  grep -l "CoachProfile" apps/mobile/lib/screens/*/${screen}.dart 2>/dev/null || echo "MISSING: $screen"
done

# GATE 4.2: Zero hardcoded confidenceScore in arbitrage_engine
grep -n "confidenceScore:" apps/mobile/lib/services/financial_core/arbitrage_engine.dart | grep -E "[0-9]{2}\.[0-9]" | wc -l

# GATE 4.3: _computeArbitrageConfidence exists
grep -n "_computeArbitrageConfidence\|profileConfidenceScore" apps/mobile/lib/services/financial_core/arbitrage_engine.dart | wc -l

# GATE 4.4: SmartDefaultIndicator used in screens
grep -rl "SmartDefaultIndicator" apps/mobile/lib/screens/ --include="*.dart" | wc -l

# GATE 4.5: Indicative banner
grep -rn "indicatif\|Résultat indicatif" apps/mobile/lib/ --include="*.dart" | wc -l

# GATE 4.6: No regression
cd apps/mobile && flutter analyze 2>&1 | tail -5
cd apps/mobile && flutter test 2>&1 | tail -10
```

### Phase 5 Gates
```bash
# GATE 5.1: compoundProjectedImpact exists
grep -n "compoundProjectedImpact" apps/mobile/lib/services/plan_tracking_service.dart | wc -l

# GATE 5.2: compoundProjectedImpact tested
grep -rn "compoundProjectedImpact" apps/mobile/test/ --include="*.dart" | wc -l

# GATE 5.3: identical() replaced
grep -n "identical(_profile" apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart | wc -l

# GATE 5.4: == used instead
grep -n "_profile == newProfile\|_profile != null" apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart | wc -l

# GATE 5.5: 4 new widgets created
ls apps/mobile/lib/widgets/coach/patrimoine_snapshot_card.dart \
   apps/mobile/lib/widgets/coach/fri_radar_chart.dart \
   apps/mobile/lib/widgets/coach/trajectory_comparison_card.dart \
   apps/mobile/lib/widgets/coach/plan_reality_card.dart 2>/dev/null | wc -l

# GATE 5.6: fromJson factories
grep -n "fromJson" apps/mobile/lib/services/forecaster_service.dart | wc -l

# GATE 5.7: Smoke test imports in dashboard
grep -rn "PatrimoineSnapshotCard\|FriRadarChart" apps/mobile/lib/screens/coach/retirement_dashboard_screen.dart | wc -l

# GATE 5.8: No regression
cd apps/mobile && flutter analyze 2>&1 | tail -5
cd apps/mobile && flutter test 2>&1 | tail -10
```

### MEGA Gates (post all phases)
```bash
# MEGA 1: Zero * 0.87
grep -rn "0\.87" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | grep -v "//" | wc -l

# MEGA 2: Zero private _estimateMarginalRate
grep -rn "_estimateMarginalRate" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | wc -l

# MEGA 3: PlanTrackingService has compoundProjectedImpact
grep -rn "compoundProjectedImpact" apps/mobile/lib/ --include="*.dart" | wc -l

# MEGA 4: Dynamic confidence in ArbitrageEngine
grep -n "confidenceScore:" apps/mobile/lib/services/financial_core/arbitrage_engine.dart | grep -E "[0-9]{2}\.[0-9]" | wc -l

# MEGA 5: Flutter analyze
cd apps/mobile && flutter analyze 2>&1 | grep -c "error"

# MEGA 6: Flutter test
cd apps/mobile && flutter test

# MEGA 7: Backend stable
cd services/backend && python3 -m pytest tests/ -q

# MEGA 8: No magic numbers in NetIncomeBreakdown
grep -n "0\.\|= [0-9]" apps/mobile/lib/services/financial_core/tax_calculator.dart | grep -v import | grep -v "bracket\|Multiplier\|0\.0\b\|//" | head -20
```

## Rules

- **NEVER** modify code during an audit
- **NEVER** suggest "nice to have" improvements
- **NEVER** give opinions on code quality
- Report FACTS: command, output, expected, pass/fail
- The FAIL report IS the fix spec — no reformulation needed
- Run ALL gates, even if early ones fail
- Always finish with the summary table
