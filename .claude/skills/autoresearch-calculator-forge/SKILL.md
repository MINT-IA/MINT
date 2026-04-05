---
name: autoresearch-calculator-forge
description: "Autonomous calculator validator. Generates edge-case financial scenarios from Swiss law, tests against official values, fixes calculators if discrepancy. Use with /autoresearch-calculator-forge or /autoresearch-calculator-forge 50."
compatibility: Requires Flutter SDK
metadata:
  author: mint-team
  version: "3.0"
---

# Autoresearch Calculator Forge v3 — Karpathy Calculator Validator

> "Every calculator output must match the official Swiss source. A discrepancy is a bug."

## Constraints (NON-NEGOTIABLE)

- **Single metric**: `calculation_accuracy` = correct / tested × 100 (target: 100%, tolerance ±0.5%).
- **Time budget**: 5 min per scenario. If fix takes > 5 min → revert → log → next scenario.
- **Single target**: ONE calculator file per iteration cycle. Pick scenario → write test → run → fix if needed → next.
- **Guard**: existing `flutter test` must not regress.
- **Constants are SACRED**: never modify constants without human review. If a constant looks wrong → LOG and alert, don't change.

## Context Budget Protocol

Your context window is a finite resource. Quality degrades as it fills.

| Tier | Context Used | Behavior |
|------|-------------|----------|
| PEAK | 0-30% | Full operations. Read freely, explore, try multiple approaches. |
| GOOD | 30-50% | Normal. Prefer targeted reads over exploratory. |
| DEGRADING | 50-70% | Economize. No exploration. Targeted fixes only. Warn in log. |
| POOR | 70%+ | STOP new iterations. Finish current only. Write report. Commit. |

### Degradation Warning Signs — STOP and assess if you notice:

- **Silent partial completion**: Claiming done but skipping verify steps you'd normally follow.
- **Increasing vagueness**: Writing "appropriate handling" instead of specific code references.
- **Skipped steps**: Iteration normally has 6 steps but you only did 4.

If ANY sign is present → treat as POOR tier. Write final report and stop.

### Iteration Budget

Estimate remaining iterations: `(100 - context_used%) / 3`.
At < 10 remaining → plan exit. At < 5 → STOP. Report only.

## Mutable / Immutable

| Mutable (this iteration, pick ONE) | Immutable |
|-------------------------------------|-----------|
| `lib/services/financial_core/avs_calculator.dart` | `constants/social_insurance.dart` (human-only) |
| `lib/services/financial_core/lpp_calculator.dart` | CLAUDE.md § 5 (business rules) |
| `lib/services/financial_core/tax_calculator.dart` | Official Swiss sources (admin.ch, OFAS, AFC) |
| `lib/services/financial_core/confidence_scorer.dart` | Golden couple values (CLAUDE.md § 8) |
| `test/services/financial_core/*_test.dart` | ADR-20260223-unified-financial-engine.md |

## Golden Profiles

| Name | Age | Canton | Salary | Archetype |
|------|-----|--------|--------|-----------|
| Julien | 49 | VS | 122'207 | swiss_native |
| Lauren | 43 | VS | 67'000 | expat_us |
| Marco | 24 | TI | 52'000 | swiss_native |
| Fatima | 38 | GE | indep | independent_no_lpp |
| Hans | 57 | ZH | 180'000 | swiss_native |
| Marie | 72 | VD | veuve | swiss_native |

## Priority Scenarios (pick highest uncovered)

1. 13e rente AVS (base × 1.0833)
2. 3a rétro 10 ans (retroactive contributions)
3. Splitting couple (LAVS art. 29quinquies)
4. Surobligatoire real rates (<6.8% conversion)
5. 26 cantons × 5 situations (capital withdrawal tax matrix)
6. EPL blocking period (3 ans, art. 79b al. 3)
7. Capital tax progressive brackets (edges: 100k, 200k, 500k, 1M)
8. AVS rente max couple (LAVS art. 35, 150% married ONLY)
9. LPP seuil d'accès (22'680, art. 7)
10. Coordination deduction (26'460, min 3'780)

## The Loop

```
┌─ BASELINE: flutter test test/services/financial_core/ 2>&1 | tail -10
│  Count existing test cases: grep -r "test(" test/services/financial_core/ | wc -l
│
├─ SELECT: Highest-priority uncovered scenario. Check existing tests to avoid dupes.
│
├─ WRITE TEST (≤2 min): Expected value from official Swiss source.
│  Every test MUST have:
│  - Source reference in name: test('LAVS art.35 — couple cap at 150%', ...)
│  - Expected value with formula in comment
│  - Tolerance: CHF ±0.01, percentages ±0.001, years ±0
│
├─ EXECUTE (≤1 min): flutter test test/services/financial_core/specific_test.dart
│
├─ EVALUATE:
│  Pass → commit test (coverage+), next scenario.
│  Fail (calculator bug) → read calculator → fix formula → run ALL financial_core tests.
│  Stuck 3x → revert, log, next scenario.
│
├─ LOG: Append to experiment log
│
├─ COMMIT: git add ... && git commit -m "test(financial_core): <scenario> — <law ref>"
│
└─ REPEAT until: budget exhausted | all priority scenarios covered
    Every 5 scenarios → full suite: flutter test 2>&1 | tail -5
```

## Rules

- **NEVER modify constants without human review** — log discrepancy and alert
- **NEVER delete existing tests** — only add
- **NEVER use mocked values** for official constants — test against real Swiss values
- **NEVER invent expected values** — derive from official source + formula shown in comment
- **NEVER test unrealistic profiles** (negative age, salary > 10M)
- If calculator fix **contradicts CLAUDE.md § 5** → STOP, alert human

## Verification Gate (IRON LAW)

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

After EVERY scenario, before reporting it as done:

1. **RUN** `flutter test test/services/financial_core/ 2>&1 | tail -20` fresh.
2. **PASTE** the exact terminal output in your experiment log. "Should pass" is FORBIDDEN.
3. **READ** the output. Confirm: new test appears, all tests green, no regressions.
4. If output contradicts your claim → the claim is wrong. Fix or revert.

| Rationalization | Response |
|----------------|----------|
| "Should work now" | RUN IT. Paste output. |
| "I'm confident it passes" | Confidence is not evidence. Run the test. |
| "I already tested earlier" | Code changed since then. Test AGAIN. |
| "It's a trivial change" | Trivial changes break production. Verify. |
| "The official value must be approximate" | Official values are exact. Your formula is wrong. |
| "It's only off by a few francs" | ±0.5% tolerance is the rule. Measure it, don't eyeball it. |

**If verification FAILS:** Do NOT commit. Revert: `git checkout -- <files>`. Return to the Loop and retry with a different formula. If stuck 3x on same scenario → log as `skip` and move to next target.

Claiming work is complete without verification is dishonesty, not efficiency.

### Common Failures — what your claim REQUIRES (Superpowers)

| Claim | Requires | NOT Sufficient |
|-------|----------|----------------|
| "Tests pass" | Fresh test command output: 0 failures | Previous run, "should pass", partial run |
| "No regressions" | Full suite run: same or fewer failures | Running only the changed test file |
| "Calculator accurate" | Delta within ±0.5%, measured numerically | "Looks right", eyeballed |
| "Iteration complete" | All loop steps executed + output pasted | Steps skipped, partial evidence |
| "Ready to commit" | Verify + analyze both green, this iteration | Green from 3 iterations ago |

### Red Flags — STOP if you catch yourself doing ANY of these:

- Using "should", "probably", "seems to" about test results
- Expressing satisfaction before verification ("Great!", "Perfect!", "Done!")
- About to commit without fresh verification in THIS iteration
- Trusting a previous run's results after code changed
- Relying on partial verification ("I tested the main case")
- Thinking "just this once I can skip verification"
- Feeling rushed and wanting to move to the next iteration
- Using different words to dodge this rule ("appears to work" = "should work")
- Reporting fewer steps than the loop specifies (silent step-skipping)

## Experiment Log (append-only)

```
iteration  scenario                    calculator         tests_added  status     discrepancy
1          13e_rente_avs               avs_calculator     +3           keep       none
2          capital_tax_bracket_500k    tax_calculator     +2           keep+fix   off-by-one at boundary
3          canton_ZH_capital_tax       tax_calculator     0            skip       needs real AFC data
```

Status: `keep` | `keep+fix` (calculator corrected) | `skip` (stuck/missing data) | `flagged` (constant mismatch → human)

## Final Report

```
AUTORESEARCH CALCULATOR FORGE — SESSION REPORT
Date: YYYY-MM-DD | Branch: feature/S{XX}-... | Budget: X/Y
Accuracy: before=N% → after=M% | New scenarios: K

EXPERIMENT LOG:
iter  scenario  calculator  tests  status  discrepancy
1     ...

CALCULATOR FIXES:
  - tax_calculator.dart:142 — bracket boundary exclusive→inclusive

CONSTANTS FLAGGED FOR HUMAN REVIEW:
  - LPP bonif 45-54: code=15%, OFAS 2026=15% — OK
```

## Invocation

- `/autoresearch-calculator-forge` — 20 scenarios (default)
- `/autoresearch-calculator-forge 50` — deep pass
