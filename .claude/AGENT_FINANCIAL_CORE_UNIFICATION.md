# AGENT_FINANCIAL_CORE_UNIFICATION.md
# Audit & Cleanup Prompt — Calculation Engine Deduplication
# For Claude Code Opus 4.6 Agent Team
# ⚠️ RUN THIS BEFORE COACH VIVANT SPRINTS (S31+)

---

## MISSION

You are a senior financial engineer performing a **surgical audit and cleanup**
of MINT's calculation layer. Your job:

1. Find EVERY place where AVS, LPP, tax, 3a, or financial calculations are implemented
2. Identify which ones duplicate logic that exists (or should exist) in `financial_core/`
3. Refactor all duplicates to use `financial_core/` as single source of truth
4. Ensure backend and Flutter produce IDENTICAL results
5. Leave zero duplication when you're done

**This is a prerequisite for all future development.** The Coach Vivant roadmap,
the Arbitrage Engine, the FRI — all depend on a clean, unified calculation layer.

---

## BEFORE YOU START

**Read these documents in order:**

```
1. .claude/CLAUDE.md                                        — Constants, anti-patterns, financial core spec
2. decisions/ADR-20260223-unified-financial-engine.md       — Financial core architecture decision
3. decisions/ADR-20260223-archetype-driven-retirement.md    — Archetype system
```

**Key anti-patterns from CLAUDE.md (memorize these):**

```
#12: NEVER create private _calculateTax(), _estimateAvs(), etc. in service files.
     Always use financial_core/ calculators.
     If a method doesn't exist, ADD IT to the appropriate calculator class.

#13: NEVER ignore future AVS contribution years.
     AvsCalculator.computeMonthlyRente() correctly adds future years.
     Don't use raw contributionYears / 44 as reduction factor.

#14: NEVER apply married couple AVS cap to concubins.
     LAVS art. 35 cap (150% = 3780 CHF) applies ONLY to married couples.
```

---

## PHASE 1 — DISCOVERY (Do NOT edit any code yet)

### Step 1.1 — Map the canonical financial_core

Read every file in the financial core:

```
apps/mobile/lib/services/financial_core/
    avs_calculator.dart
    lpp_calculator.dart
    tax_calculator.dart
    three_a_calculator.dart      (if exists)
    confidence_scorer.dart
    financial_core.dart          (barrel export)
```

For each calculator, document:
- Every public method (name, signature, what it computes)
- Every constant used (and verify against CLAUDE.md constants)
- Every legal reference cited

Produce a **CALCULATOR REGISTRY** — a complete inventory of what financial_core offers.

### Step 1.2 — Scan ALL backend services for calculation logic

Search the entire backend for financial calculations:

```bash
# In services/backend/
grep -rn "def.*calc\|def.*compute\|def.*estimate\|def.*project\|def.*simulate" app/services/ --include="*.py"
grep -rn "avs\|lpp\|rente\|bonification\|coordination\|pilier\|3a\|pillar" app/services/ --include="*.py"
grep -rn "22680\|26460\|3780\|6\.8\|7258\|36288\|30240\|10\.6" app/services/ --include="*.py"
grep -rn "taux_marginal\|marginal_rate\|tax_rate\|impot\|imposition" app/services/ --include="*.py"
grep -rn "def _" app/services/ --include="*.py" | grep -i "tax\|avs\|lpp\|rente\|pension\|retire"
```

For each match, record:
- File path
- Method name
- What it calculates
- Whether it duplicates a financial_core method
- Whether it uses hardcoded constants

### Step 1.3 — Scan ALL Flutter services for calculation logic

Same scan on Flutter side:

```bash
# In apps/mobile/
grep -rn "double.*calc\|double.*compute\|double.*estimate\|int.*calc" lib/services/ --include="*.dart"
grep -rn "avs\|lpp\|rente\|bonification\|coordination\|pilier\|3a\|pillar" lib/services/ --include="*.dart"
grep -rn "22680\|26460\|3780\|6\.8\|7258\|36288\|30240\|10\.6" lib/services/ --include="*.dart"
grep -rn "_calculate\|_compute\|_estimate\|_project" lib/services/ --include="*.dart"
```

Pay special attention to:
```
lib/services/retirement_projection_service.dart
lib/services/forecaster_service.dart
lib/services/lpp_deep_service.dart
lib/services/rente_vs_capital_calculator.dart
lib/services/expat_service.dart
lib/services/financial_report_service.dart
lib/services/budget_service.dart          (if contains tax estimates)
lib/services/mortgage_service.dart        (if contains income calculations)
lib/services/independant_service.dart     (if contains AVS/LPP for independants)
lib/services/chomage_service.dart         (if contains AVS calculations)
lib/services/divorce_service.dart         (if contains pension splitting)
lib/services/disability_service.dart      (if contains income projections)
```

### Step 1.4 — Scan screens and widgets for inline calculations

The worst kind of duplication — calculations buried in UI code:

```bash
# In apps/mobile/
grep -rn "22680\|26460\|3780\|6\.8\|7258\|36288\|30240" lib/screens/ --include="*.dart"
grep -rn "22680\|26460\|3780\|6\.8\|7258\|36288\|30240" lib/widgets/ --include="*.dart"
grep -rn "\* 0\.068\|\* 6\.8\|/ 44\|/ 43\|/ 42" lib/ --include="*.dart"
grep -rn "\.07\b.*bonif\|\.10\b.*bonif\|\.15\b.*bonif\|\.18\b.*bonif" lib/ --include="*.dart"
```

### Step 1.5 — Cross-check backend vs Flutter constants

Verify that EVERY constant matches between backend and Flutter:

```
Constant                    CLAUDE.md       Backend         Flutter
─────────────────────────────────────────────────────────────────────
3a plafond salarié          7'258           ?               ?
3a plafond indépendant      36'288          ?               ?
LPP seuil accès             22'680          ?               ?
LPP coordination            26'460          ?               ?
LPP coordonné min           3'780           ?               ?
LPP conversion              6.8%            ?               ?
LPP bonif 25-34             7%              ?               ?
LPP bonif 35-44             10%             ?               ?
LPP bonif 45-54             15%             ?               ?
LPP bonif 55-65             18%             ?               ?
AVS taux total              10.60%          ?               ?
AVS rente max               30'240          ?               ?
AVS cotisation min indép    530             ?               ?
Hypothèque taux théorique   5%              ?               ?
Hypothèque ratio max        1/3             ?               ?
Fonds propres min           20%             ?               ?
EPL minimum                 20'000          ?               ?
EPL blocage rachat          3 ans           ?               ?
Tax brackets capital        see CLAUDE.md   ?               ?
```

Fill in every cell. Flag every mismatch as **CRIT**.

### Step 1.6 — Produce the AUDIT REPORT

Before editing ANY code, produce a structured report:

```markdown
# FINANCIAL CORE AUDIT REPORT
## Date: [date]
## Baseline: [test count] backend tests passing, flutter analyze [status]

### CALCULATOR REGISTRY (what financial_core offers)
[list every method in every calculator]

### DUPLICATES FOUND
| # | File | Method | Duplicates | Severity |
|---|------|--------|-----------|----------|
| 1 | retirement_projection_service.dart | _calculateAvs() | AvsCalculator.computeMonthlyRente() | CRIT |
| 2 | ... | ... | ... | ... |

### CONSTANT MISMATCHES
| # | Constant | CLAUDE.md | Backend | Flutter | Severity |
|---|----------|-----------|---------|---------|----------|
| 1 | LPP coord min | 3'780 | 3'780 | 3'675 | CRIT |
| 2 | ... | ... | ... | ... | ... |

### INLINE CALCULATIONS IN UI CODE
| # | File | Line | What it computes | Should use |
|---|------|------|-----------------|-----------|
| 1 | mortgage_screen.dart:142 | salary * 0.053 | AVS deduction | AvsCalculator |
| 2 | ... | ... | ... | ... |

### MISSING METHODS (needed but not in financial_core)
| # | Calculation needed | Used by | Proposed method |
|---|-------------------|---------|----------------|
| 1 | Net salary from gross | 5+ services | financial_core/salary_calculator.dart |
| 2 | ... | ... | ... |

### BACKEND ↔ FLUTTER DIVERGENCES
| # | Calculation | Backend result | Flutter result | Delta | Root cause |
|---|------------|----------------|----------------|-------|-----------|
| 1 | AVS rente age 65 salary 80k | 2'156.00 | 2'148.50 | 7.50 | Rounding |
| 2 | ... | ... | ... | ... | ... |
```

**STOP HERE. Do not proceed to Phase 2 until the audit report is complete
and you have a clear picture of every duplicate, mismatch, and gap.**

---

## PHASE 2 — PLAN THE CLEANUP (Still no code edits)

Based on the audit report, create a **CLEANUP PLAN** with this structure:

### Priority 1 — CRIT constant mismatches
Fix these first. A wrong constant poisons every calculation downstream.

### Priority 2 — CRIT duplicate methods (different results)
Methods that duplicate financial_core AND produce different numbers.
These are bugs. Fix immediately.

### Priority 3 — Duplicate methods (same results)
Methods that duplicate financial_core but happen to produce correct results.
Refactor to use financial_core. No behavioral change.

### Priority 4 — Missing methods in financial_core
Calculations that SHOULD be in financial_core but don't exist yet.
Add to appropriate calculator class, then refactor consumers.

### Priority 5 — Inline calculations in UI code
Move to services, which in turn use financial_core.

### Priority 6 — Backend ↔ Flutter alignment
Ensure identical results for identical inputs.

**For each cleanup item, specify:**
```
- What file to change
- What to remove (the duplicate)
- What to use instead (the financial_core method)
- What tests to run to verify no regression
- Risk level (high/medium/low)
```

---

## PHASE 3 — EXECUTE THE CLEANUP

### Rules of Engagement

**Rule 1: Run ALL tests before AND after EVERY change.**
```bash
cd services/backend && python3 -m pytest tests/ -q
cd apps/mobile && flutter analyze && flutter test
```
If any test fails after a change, REVERT and investigate.

**Rule 2: One duplicate at a time.**
Do NOT batch 10 refactors into one commit. Each duplicate removal = one commit.
If something breaks, you know exactly which change caused it.

**Rule 3: Backend first, then Flutter.**
Backend = source of truth. Fix backend, verify tests, THEN fix Flutter to match.

**Rule 4: If a calculation doesn't exist in financial_core, ADD IT there first.**
Never "fix" a duplicate by keeping it in the service file.
Always move the correct version INTO financial_core, then point all consumers to it.

**Rule 5: Preserve the method signature when possible.**
If `RetirementProjectionService` has `_calculateAvs(age, salary)`,
and you're replacing it with `AvsCalculator.computeMonthlyRente(...)`,
and the AvsCalculator method has different parameters,
then create a thin wrapper — not a new calculation:

```dart
// GOOD — thin adapter, no calculation logic
double _getAvsRente(int age, double salary) {
  return AvsCalculator.computeMonthlyRente(
    age: age,
    averageSalary: salary,
    contributionYears: _computeContributionYears(age),
    isMarried: false,
  ) * 12;  // convert monthly to annual if needed
}

// BAD — reimplements the calculation
double _getAvsRente(int age, double salary) {
  final years = min(age - 21, 44);
  final scale = years / 44;
  return salary * 0.0125 * scale * 12;  // ← THIS IS THE PROBLEM
}
```

**Rule 6: Update imports, not just method bodies.**
When removing a duplicate, ensure the file now imports `financial_core.dart`.
Remove any now-unused private methods.
Remove any now-unused local constants.

**Rule 7: After removing a duplicate, add a comment preventing re-creation.**

```dart
// ALL AVS calculations MUST use AvsCalculator from financial_core.
// See ADR-20260223-unified-financial-engine.md
// Do NOT create local _calculateAvs() or similar methods.
```

---

## PHASE 4 — GAP ANALYSIS (Methods to ADD to financial_core)

Common calculations that probably exist in multiple services but not in financial_core:

### Likely missing: Net salary calculator

```dart
// Needed by: budget, mortgage, retirement, coaching, disability, chomage
class SalaryCalculator {
  /// Computes net salary from gross, accounting for:
  /// - AVS/AI/APG (5.30%)
  /// - LPP employee contribution (age-dependent)
  /// - AC (chômage) contribution
  /// - AANP (accidents non-professionnels)
  /// - Estimated income tax (canton-dependent)
  static NetSalaryBreakdown computeNet({
    required double grossAnnual,
    required int age,
    required String canton,
    required bool isMarried,
    required int children,
    double? lppEmployeeRate,  // override if known
  });
}
```

If 5+ services independently compute net salary → this MUST be in financial_core.

### Likely missing: Replacement ratio calculator

```dart
// Needed by: retirement, forecaster, coaching, FRI, onboarding
class ReplacementRatioCalculator {
  /// Computes retirement income as % of current income
  /// Combines: AVS + LPP rente + 3a drawdown + other
  static ReplacementResult compute({
    required double currentNetIncome,
    required double projectedAvsMonthly,
    required double projectedLppMonthly,
    required double projected3aCapital,
    required double otherRetirementIncome,
    required int retirementAge,
  });
}
```

### Likely missing: Liquidity months calculator

```dart
// Needed by: coaching, FRI, onboarding, disability, chomage
class LiquidityCalculator {
  /// Months of expenses coverable by liquid assets
  static double monthsCover({
    required double liquidAssets,    // cash + easily accessible savings
    required double monthlyExpenses,
  });
}
```

### Likely missing: LPP buyback potential calculator

```dart
// Needed by: retirement, arbitrage, coaching, tax optimization
class LppBuybackCalculator {
  /// Maximum tax-deductible LPP buyback for this profile
  static BuybackResult computePotential({
    required double currentLppBalance,
    required double projectedMaxLpp,   // at retirement, full bonifications
    required double recentWithdrawals, // EPL etc. — must repay first
    required bool hasWithdrawnLast3Years,
  });
}
```

### For each missing method:

1. Check if the calculation exists somewhere (even duplicated)
2. Find the BEST implementation (most correct, most tested)
3. Move it to the appropriate calculator in financial_core
4. Add proper docstring with legal reference
5. Add tests
6. Refactor all consumers to use the new method

---

## PHASE 5 — BACKEND ↔ FLUTTER PARITY CHECK

After all duplicates are removed:

### Step 5.1 — Create parity test cases

Define 10-15 representative profiles:

```python
PARITY_PROFILES = [
    {"age": 25, "salary": 55000, "canton": "VD", "archetype": "swiss_native"},
    {"age": 35, "salary": 85000, "canton": "ZH", "archetype": "swiss_native", "married": True, "children": 2},
    {"age": 45, "salary": 120000, "canton": "GE", "archetype": "expat_eu", "arrival_age": 30},
    {"age": 55, "salary": 95000, "canton": "BE", "archetype": "independent_no_lpp"},
    {"age": 30, "salary": 75000, "canton": "TI", "archetype": "cross_border"},
    {"age": 62, "salary": 150000, "canton": "ZH", "archetype": "swiss_native", "property": True},
    {"age": 22, "salary": 48000, "canton": "FR", "archetype": "swiss_native"},  # first job
    {"age": 40, "salary": 100000, "canton": "VS", "archetype": "returning_swiss", "years_abroad": 8},
    {"age": 50, "salary": 200000, "canton": "SZ", "archetype": "expat_us"},
    {"age": 35, "salary": 0, "canton": "VD", "archetype": "swiss_native"},  # edge: zero salary
]
```

### Step 5.2 — Run each profile through BOTH backend and Flutter

For each profile, compute:
- AVS monthly rente
- LPP projected capital at 65
- LPP monthly rente (capital × conversion rate)
- Estimated marginal tax rate
- 3a annual tax saving
- Replacement ratio
- Net salary

### Step 5.3 — Compare results

Acceptable tolerance:
- CHF amounts: ±1 CHF (rounding)
- Percentages: ±0.1%
- Ratios: ±0.001

Anything beyond tolerance = **CRIT divergence**.
Backend value wins. Flutter must be fixed to match.

### Step 5.4 — Document results

```markdown
# PARITY CHECK RESULTS
| Profile | Metric | Backend | Flutter | Delta | Status |
|---------|--------|---------|---------|-------|--------|
| 25/VD/55k | AVS monthly | 1'892.00 | 1'892.00 | 0 | ✅ |
| 25/VD/55k | LPP capital | 287'456.80 | 287'456.80 | 0 | ✅ |
| 35/ZH/85k | Tax saving 3a | 2'178.00 | 2'245.00 | 67 | ❌ CRIT |
| ... | ... | ... | ... | ... | ... |
```

---

## PHASE 6 — FINAL VERIFICATION + COMMIT

### Step 6.1 — Run full test suite
```bash
cd services/backend && python3 -m pytest tests/ -q
cd apps/mobile && flutter analyze && flutter test
```

### Step 6.2 — Verify test count

```
Before cleanup: [X] backend tests, [Y] flutter tests
After cleanup:  [X'] backend tests, [Y'] flutter tests
```

Test count should be EQUAL or HIGHER (new parity tests added).
If test count decreased → you deleted tests that covered the duplicates.
Re-add equivalent tests that cover the financial_core methods.

### Step 6.3 — Verify zero remaining duplicates

Re-run the Phase 1 scans. Zero hits should remain outside financial_core for:
- AVS rente calculation
- LPP projection / bonification
- Tax calculation (marginal, capital withdrawal)
- 3a tax saving
- Replacement ratio

### Step 6.4 — Produce CLEANUP COMPLETION REPORT

```markdown
# FINANCIAL CORE UNIFICATION — COMPLETION REPORT

## Summary
- Duplicates found: [N]
- Duplicates removed: [N]
- Constants mismatches fixed: [N]
- Methods added to financial_core: [N]
- Backend ↔ Flutter divergences fixed: [N]
- Tests before: [X] backend / [Y] flutter
- Tests after: [X'] backend / [Y'] flutter

## financial_core/ final inventory
### AvsCalculator
  - computeMonthlyRente(...)
  - renteFromRAMD(...)
  - computeCouple(...)
  - [any new methods added]

### LppCalculator
  - projectToRetirement(...)
  - projectOneMonth(...)
  - blendedMonthly(...)
  - [any new methods added]

### TaxCalculator
  - capitalWithdrawalTax(...)
  - progressiveTax(...)
  - estimateMonthlyIncomeTax(...)
  - [any new methods added]

### [NewCalculator if created]
  - [methods]

## Files modified
[list every file changed with one-line description of change]

## Remaining risks
[any known issues that couldn't be resolved]
```

### Step 6.5 — Commit

```bash
git add [only files from cleanup]
git commit -m "chore: financial_core unification — remove N duplicates, fix M mismatches, add K methods

Audit found N calculation duplicates across M services.
All refactored to use financial_core/ as single source of truth.
Fixed K constant mismatches between backend and Flutter.
Added [methods] to financial_core to cover previously scattered calculations.
Backend ↔ Flutter parity verified on 10 representative profiles.

See FINANCIAL_CORE_AUDIT_REPORT.md for full details.

ADR: decisions/ADR-20260223-unified-financial-engine.md"
```

---

## KNOWN TROUBLE SPOTS (check these first)

Based on CLAUDE.md sprint history and anti-patterns, these are the most likely locations of duplicates:

### High probability duplicates:

```
retirement_projection_service    — likely has its own AVS/LPP calc
forecaster_service               — likely has its own simplified projections
lpp_deep_service                 — might reimplement bonification logic
rente_vs_capital_calculator      — might have its own tax logic
expat_service                    — might have AVS gap calc that differs
financial_report_service         — likely aggregates with its own formulas
disability_service               — might compute income replacement independently
mortgage_service                 — might estimate net salary independently
independant_service              — might have its own AVS/LPP for self-employed
coaching_service                 — might compute simplified metrics
budget_service                   — might estimate taxes independently
```

### High probability constant issues:

```
LPP coordonné minimum: 3'780    — this was specifically fixed in commit 750286b
AVS 2520 alignment               — also fixed in 750286b, verify no regression
Bonification rates by age        — easy to hardcode differently in 2 places
Tax brackets for capital          — the progressive multipliers from CLAUDE.md
3a plafond                       — 7'258 should be identical everywhere
```

### High probability formula issues:

```
AVS contribution years            — anti-pattern #13: must include future years
AVS couple cap                    — anti-pattern #14: only for married, not concubins
LPP projection                    — must use exact bonification rates by age band
Capital withdrawal tax            — progressive brackets must match CLAUDE.md exactly
Replacement ratio                 — must combine AVS + LPP + 3a correctly
```

---

## WHAT TO DO IF YOU FIND A BUG (not just a duplicate)

If a financial_core calculator is WRONG (produces incorrect results):

1. **Do NOT silently fix it.** Document the bug.
2. Check which services use the incorrect method.
3. Check if any service has a "workaround" that compensates for the bug.
4. Fix the financial_core method.
5. Run ALL tests. Some tests might have been written against the buggy behavior.
6. Update affected tests to expect correct results.
7. Document in the audit report: "BUG FOUND: [description]. Impact: [which outputs were wrong]."

If the bug affects user-facing numbers that are currently deployed:
- Flag as **CRIT-DEPLOYED**.
- Document the magnitude of error.
- Lead agent decides whether this needs a user-facing correction notice.

---

## TIMELINE

```
Day 1:     Phase 1 (Discovery) — NO code changes
Day 1-2:   Phase 2 (Plan) — NO code changes
Day 2-4:   Phase 3 (Execute) — one duplicate at a time, test after each
Day 4-5:   Phase 4 (Gap analysis) — add missing methods to financial_core
Day 5:     Phase 5 (Parity check) — backend vs Flutter verification
Day 5:     Phase 6 (Final verification + commit)
```

Estimated: 4-5 working days for a thorough cleanup.

**This must be completed BEFORE S31 (Onboarding) begins.**
The onboarding MinimalProfileService depends on a clean financial_core.

---

## SUCCESS CRITERIA

- [ ] Zero private `_calculate*`, `_compute*`, `_estimate*` methods for financial logic outside financial_core
- [ ] Zero hardcoded financial constants outside financial_core (or a shared constants file)
- [ ] All 10+ CLAUDE.md constants verified identical in backend AND Flutter
- [ ] Parity check: all 10 profiles produce identical results backend vs Flutter (within tolerance)
- [ ] Test count equal or higher than before cleanup
- [ ] All tests passing
- [ ] `flutter analyze` = 0 errors
- [ ] Audit report and completion report produced
- [ ] No remaining `grep` hits for financial constants in screens/ or widgets/

---

*This is Sprint S30.5 — it runs BEFORE the Coach Vivant roadmap begins.
Clean foundation first. Build on top second.*
