---
name: autoresearch-calculator-forge
description: "Autonomous calculator validator. Generates edge-case financial scenarios, tests against official Swiss values, fixes calculators if discrepancy found. Use with /autoresearch-calculator-forge or /autoresearch-calculator-forge 50."
compatibility: Requires Flutter SDK
allowed-tools: Bash(flutter:*) Bash(dart:*) Bash(git:*) Read Edit Write Glob Grep
metadata:
  author: mint-team
  version: "1.0"
---

# Autoresearch Calculator Forge v1 — Autonomous Calculator Validator

## Philosophy

> "Every calculator output must match the official Swiss source. A discrepancy is a bug."

Karpathy-style loop: generate financial scenario from official source → write test with expected value → run → if fail, fix calculator → re-run → repeat.

**Primary metric**: `calculation_accuracy` = correct results / scenarios tested x 100 (target: 100%, tolerance +/-0.5%)
**Guard metric**: existing `flutter test` must not regress

## Mutable Target

- `lib/services/financial_core/*.dart` — calculators (AVS, LPP, tax, confidence)
- `test/services/financial_core/*_test.dart` — test files for calculators

## Immutable Harness

- Official Swiss sources: admin.ch, OFAS (Office federal des assurances sociales), AFC (Administration federale des contributions)
- Golden couple: Julien (49, CH, 122K, VS) + Lauren (43, US/FATCA, 67K, VS)
- CLAUDE.md section 5 (Business Rules) — key constants 2025/2026
- `decisions/ADR-20260223-unified-financial-engine.md`

## Golden Profiles

| Name | Age | Canton | Salary | Archetype | Use for |
|------|-----|--------|--------|-----------|---------|
| Julien | 49 | VS | 122'207 | swiss_native | LPP projection, AVS couple, tax |
| Lauren | 43 | VS | 67'000 | expat_us | FATCA, partial AVS, LPP |
| Marco | 24 | TI | 52'000 | swiss_native | Young worker, minimal LPP |
| Fatima | 38 | GE | indep | independent_no_lpp | 3a max 36'288, no LPP |
| Hans | 57 | ZH | 180'000 | swiss_native | Near-retirement, high salary |
| Marie | 72 | VD | veuve | swiss_native | Survivor rente, post-retirement |

## Priority Scenarios

1. **13e rente AVS** — base rente x 1.0833 (monthly = annual / 12 with 13th)
2. **3a retro 10 ans** — retroactive contributions (max 10 years, annual cap)
3. **Splitting couple** — AVS income splitting for married couples (LAVS art. 29quinquies)
4. **Surobligatoire real rates** — LPP surobligatoire at <6.8% conversion rate
5. **26 cantons x 5 situations familiales** — capital withdrawal tax matrix
6. **EPL blocking period** — 3-year block after LPP buyback (art. 79b al. 3)
7. **Capital withdrawal progressive tax** — edge cases at bracket boundaries (100k, 200k, 500k, 1M)
8. **AVS rente max couple** — LAVS art. 35 cap at 150% (married only, NOT concubins)
9. **LPP seuil d'acces** — 22'680 threshold (art. 7)
10. **Coordination deduction** — 26'460 (art. 8), min coordonne 3'780

## Loop Structure

### Phase 0 — BASELINE

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
flutter test test/services/financial_core/ 2>&1 | tail -10
```

Record:
```
BASELINE: YYYY-MM-DD HH:MM
  tests_pass: N
  tests_fail: F
  scenarios_covered: (count existing test cases)
  budget: B (from arg, default 20)
```

### Phase 1 — SCENARIO SELECT

Pick the highest-priority uncovered scenario from the priority list above.

Check what is already tested:
```bash
grep -r "test(" test/services/financial_core/ | wc -l
```

Review existing tests to avoid duplicates.

### Phase 2 — CODE TEST

Write a test with expected values derived from official Swiss sources.

Every test MUST include:
- **Source reference** in the test name: `test('LAVS art.35 — couple cap at 150%', () { ... })`
- **Expected value** with calculation shown in comment
- **Tolerance** where applicable: `closeTo(expected, 0.01)` for CHF amounts

Example pattern:
```dart
test('LPP art.14 — conversion rate 6.8% on 500k capital (LAVS art.35)', () {
  // Source: LPP art. 14 al. 1 — taux de conversion minimal = 6.8%
  // 500'000 * 0.068 = 34'000 CHF/an = 2'833.33 CHF/mois
  final result = lppCalculator.blendedMonthly(capital: 500000, rate: 0.068);
  expect(result, closeTo(2833.33, 0.01));
});
```

### Phase 3 — EXECUTE

```bash
flutter test test/services/financial_core/specific_test.dart 2>&1 | tail -10
```

### Phase 4 — EVALUATE

| Result | Action |
|--------|--------|
| Test passes | Commit test (coverage+), move to next scenario |
| Test fails — calculator bug | Fix the calculator, re-run |
| Fix works | Commit fix + test together |
| Stuck after 3 attempts | Revert changes, log the issue, move to next |

When fixing a calculator:
1. Read the calculator source code
2. Identify the formula discrepancy
3. Fix with reference to Swiss law article
4. Run ALL financial_core tests (not just the new one)

### Phase 5 — COMMIT

After each successful scenario:
```bash
git add <specific test and/or calculator files>
git commit -m "test(financial_core): <scenario description> — <law reference>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Phase 6 — REPEAT or STOP

Continue until:
- **Budget exhausted** (scenarios_tested >= budget)
- **All priority scenarios covered**
- **Stuck** — same scenario fails after 3 fix attempts, skip and move on

Every 5 scenarios, run the FULL test suite:
```bash
flutter test 2>&1 | tail -5
```

## Strict Rules

1. **NEVER modify constants without human review** — if a constant seems wrong vs official source, LOG it and ask human
2. **NEVER delete existing tests** — only add new ones or fix calculator code
3. **Always include source law reference** in test name (e.g., "LAVS art. 35", "LPP art. 14")
4. **NEVER use mocked values for official constants** — test against real Swiss values
5. **Verify full suite every 5 scenarios** — guard against regressions
6. **If a calculator fix contradicts CLAUDE.md section 5** — STOP and alert human
7. **Tolerance**: CHF amounts +/-0.01, percentages +/-0.001, years +/-0

## Anti-patterns (never do)

- **NEVER** invent expected values — always derive from official source + formula
- **NEVER** modify `constants/` files without explicit human approval
- **NEVER** test with unrealistic profiles (negative age, salary > 10M, etc.)
- **NEVER** skip the full suite verification every 5 scenarios
- **NEVER** commit a calculator fix without running ALL financial_core tests

## Final Output

```
AUTORESEARCH CALCULATOR FORGE — SESSION REPORT
================================================
Date: YYYY-MM-DD
Branch: feature/S{XX}-...
Budget: X/Y scenarios used
Duration: ~Nm

RESULTS:
  Accuracy: before=N% → after=M%
  Tests:    before=+A -B → after=+C -D
  New scenarios covered: K

SCENARIOS TESTED:
  1. [PASS] 13e rente AVS — LAVS art. 34bis — base x 1.0833
  2. [PASS+FIX] Capital tax bracket 500k edge — LIFD art. 38
     Bug: off-by-one at bracket boundary, fixed in tax_calculator.dart:142
  3. [SKIP] Canton ZH capital tax — stuck, needs real AFC data
  ...

CALCULATOR FIXES:
  - tax_calculator.dart:142 — bracket boundary was exclusive, should be inclusive
  - avs_calculator.dart:89 — couple cap was applying to concubins (LAVS art.35)

CONSTANTS FLAGGED FOR HUMAN REVIEW:
  - LPP bonification 45-54: code says 15%, OFAS 2026 says 15% — OK
  - EPL min amount: code says 20'000, OPP2 art. 5 says 20'000 — OK
```

## Invocation

- `/autoresearch-calculator-forge` — default budget 20 scenarios
- `/autoresearch-calculator-forge 50` — deep pass, 50 scenarios max
