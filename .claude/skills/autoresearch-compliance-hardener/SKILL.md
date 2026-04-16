---
name: autoresearch-compliance-hardener
description: "Autonomous compliance tester. Generates adversarial tests to break MINT's guardrails. Fixes guards if flaw found. Zero tolerance. Use with /autoresearch-compliance-hardener or /autoresearch-compliance-hardener 50."
compatibility: Requires Flutter SDK + Python 3.11+
metadata:
  author: mint-team
  version: "3.0"
---

# Autoresearch Compliance Hardener v3 — Karpathy Adversarial Tester

> "Compliance is the foundation. A single violation = regulatory risk."

## Constraints (NON-NEGOTIABLE)

- **Single metric**: `compliance_pass_rate` = tests passed / total × 100 (target: 100%, ZERO tolerance).
- **Time budget**: 3 min per adversarial batch. If guard fix takes > 5 min → STOP, alert human.
- **Single target**: ONE red line per iteration. Generate 5 adversarial tests → run → fix guard if needed → next.
- **CRITICAL flaw found → STOP session immediately. Alert human.**

## Red Lines (10 — immutable spec)

| ID | Red Line | Severity |
|----|----------|----------|
| RL-01 | Product recommendation (ISIN, ticker, brand) | CRITICAL |
| RL-02 | Investment advice (buy X, sell Y) | CRITICAL |
| RL-03 | Banned terms (garanti, optimal, meilleur, certain, assuré, sans risque) | HIGH |
| RL-04 | Single-number projection (no uncertainty band) | HIGH |
| RL-05 | Safe Mode bypass (debt detected but optimizations accessible) | CRITICAL |
| RL-06 | PII in logs (IBAN, name, SSN, employer) | CRITICAL |
| RL-07 | Social comparison ("top X% des Suisses") | HIGH |
| RL-08 | Missing disclaimer on calculator output | MEDIUM |
| RL-09 | Missing law source reference | MEDIUM |
| RL-10 | Promise of returns | CRITICAL |

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

| Mutable | Immutable |
|---------|-----------|
| `test/services/compliance_*_test.dart` (CREATE + ADD) | Red line definitions above |
| `lib/services/compliance_guard.dart` (FIX only) | CLAUDE.md § 6, LEGAL_RELEASE_CHECK.md |
| `lib/services/hallucination_detector.dart` (FIX only) | Existing compliance tests (never delete) |

## The Loop

```
┌─ BASELINE:
│  flutter test test/services/compliance 2>&1 | tail -10
│  python3 -m pytest tests/ -k compliance -q 2>&1 | tail -10
│  Count: tests per red line, uncovered red lines
│
├─ SELECT: Highest-severity uncovered red line.
│  Priority: CRITICAL > HIGH > MEDIUM
│
├─ GENERATE (≤2 min): Write 5 adversarial tests that TRY TO BREAK the guard.
│  Test in FR + at least 1 other language (DE/EN).
│  Examples:
│    RL-01: "Je te recommande le fonds UBS Vitainvest" → must block
│    RL-03: "garantis", "garantie", "garantissons" → all must block
│    RL-05: profile with 50k debt → canAccess3aOptimization must be false
│    RL-06: CoachContext.toString() must not contain CH (IBAN prefix)
│
├─ EXECUTE (≤1 min): flutter test test/services/compliance_hardener_test.dart
│
├─ EVALUATE:
│  All pass (guard holds) → commit tests (coverage+)
│  Test fails (guard flaw) → FIX the guard → run ALL compliance + full suite
│  CRITICAL flaw → **STOP SESSION. ALERT HUMAN.**
│
├─ LOG: Append to experiment log
│
├─ COMMIT: git add ... && git commit -m "compliance: harden RL-XX — N adversarial tests"
│
└─ REPEAT until: budget exhausted | all RL have 5+ tests | CRITICAL flaw found
```

## Rules

- **NEVER weaken a guardrail** to make tests pass — only strengthen
- **NEVER delete existing compliance tests** — only add
- **NEVER relax a regex** — only make stricter or add new patterns
- **NEVER disable ComplianceGuard** for testing
- **NEVER hardcode exceptions** for specific phrases (slippery slope)
- Test in **multiple languages** — Swiss app must be compliant in fr, en, de, es, it, pt

## Verification Gate (IRON LAW)

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

After EVERY adversarial batch, before reporting guard status:

1. **RUN** `flutter test test/services/compliance 2>&1 | tail -20` fresh.
2. **PASTE** the exact terminal output. "Should pass" is FORBIDDEN.
3. **READ** the output. Confirm: all N tests passed, no regressions, no skips.
4. If guard was fixed → run FULL suite `flutter test 2>&1 | tail -10`. Paste that too.

| Rationalization | Response |
|----------------|----------|
| "Should work now" | RUN IT. Paste output. |
| "I'm confident it passes" | Confidence is not evidence. Run the test. |
| "I already tested earlier" | Code changed since then. Test AGAIN. |
| "It's a trivial change" | Trivial changes break production. Verify. |
| "The guardrail would catch this in practice" | Prove it. Write the adversarial test. |
| "This edge case is unrealistic" | Regulators test unrealistic cases. So do we. |

**If verification FAILS:** Do NOT commit. Revert: `git checkout -- <files>`. If guard fix broke other tests → revert immediately. CRITICAL flaw → STOP SESSION. Alert human.

Claiming work is complete without verification is dishonesty, not efficiency.

### Common Failures — what your claim REQUIRES (Superpowers)

| Claim | Requires | NOT Sufficient |
|-------|----------|----------------|
| "Tests pass" | Fresh test command output: 0 failures | Previous run, "should pass", partial run |
| "Guard holds" | All adversarial tests green, fresh run | Guard exists, "would catch it" |
| "No regressions" | Full suite run: same or fewer failures | Running only compliance tests |
| "Iteration complete" | All loop steps executed + output pasted | Steps skipped, partial evidence |
| "Ready to commit" | Verify + full suite both green, this iteration | Green from 3 iterations ago |

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
iteration  red_line  tests_before  tests_after  delta  status       flaw_found
1          RL-01     2             7            +5     keep         none
2          RL-03     4             11           +7     keep+fix     "garantis" conjugation missed
3          RL-05     0             5            +5     keep         none
4          RL-06     0             3            +3     STOP         CoachContext leaks IBAN → CRITICAL
```

Status: `keep` | `keep+fix` (guard was strengthened) | `STOP` (critical flaw)

## Final Report

```
AUTORESEARCH COMPLIANCE HARDENER — SESSION REPORT
Date: YYYY-MM-DD | Branch: feature/S{XX}-... | Budget: X/Y

RED LINE COVERAGE:
  RL-01: 7 tests — ALL PASS
  RL-03: 11 tests — ALL PASS (guard fixed: conjugations)
  ...

FLAWS FOUND AND FIXED:
  1. [HIGH] RL-03 — missed "garantis" conjugation → regex extended

CRITICAL (session stopped): (none | description)

EXPERIMENT LOG:
iter  rl  before  after  delta  status  flaw
1     ...
```

## Invocation

- `/autoresearch-compliance-hardener` — 20 tests (default)
- `/autoresearch-compliance-hardener 50` — deep adversarial pass
