---
name: autoresearch-quality
description: "Autonomous bug hunter. Runs flutter test → reads failure → fixes CODE (not test) → re-runs → repeat. GATE for Phase 1 Chat AI. Use with /autoresearch-quality or /autoresearch-quality 20."
compatibility: Requires Flutter SDK
metadata:
  author: mint-team
  version: "6.0"
---

# Autoresearch Quality v6 — Karpathy Bug Hunter

> "The test suite is the spec. A failing test is a bug. Fix the code, not the test."

## Constraints (NON-NEGOTIABLE)

- **Single metric**: `flutter test` failure count (lower = better). Secondary: `flutter analyze` issue count.
- **Time budget**: 5 min max per fix attempt. If stuck > 5 min → revert → next bug.
- **Single target**: ONE bug per iteration. Fix → verify → commit → next.
- **Gate**: Phase 1 Chat AI blocked until tests green + analyze clean.

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
| `lib/**/*.dart` (source code) | `test/**/*_test.dart` (tests = spec) |
| Exception: test with genuinely outdated expectation | `financial_core/` constants |

## The Loop

```
┌─ BASELINE: flutter test 2>&1 | tail -5 → extract +N ~M -F
│  If F=0 → jump to ANALYZE MODE
│
├─ TRIAGE: flutter test 2>&1 | grep "\[E\]" | head -20
│  Priority: P0 compile > P1 crash > P2 logic > P3 UI > P4 async
│
├─ DIAGNOSE (≤2 min): Read failing test + source. Identify root cause.
│
├─ FIX (≤3 min): Minimal fix to SOURCE code. One bug only.
│  Exception: fix test if expectation genuinely outdated (i18n accent change)
│
├─ VERIFY: flutter test test/path/to/specific_test.dart 2>&1 | tail -5
│  Pass → commit. Fail → retry (max 3). Other tests broke → revert immediately.
│
├─ LOG: Append to experiment log (see below)
│
├─ COMMIT: git add <files> && git commit -m "fix: <description>"
│
└─ REPEAT until: budget exhausted | F=0 | stuck 3x on same bug (skip it)
    Every 5 fixes → full suite: flutter test 2>&1 | tail -5
```

### Analyze Mode (F=0)

```
flutter analyze 2>&1 | tail -5
dart fix --apply  (bulk mechanical fixes first)
Fix: errors > warnings > infos
Guard: flutter test every 5 lint fixes
Stop: only avoid_print + constant_identifier_names remain
```

### Deep Audit Mode (F=0 + analyze clean)

When all tests pass and analyze is clean, switch to **runtime path tracing**.
The most frequent MINT bugs are invisible to `flutter test`:

**The 7-axis audit (per MINT_FINAL_EXECUTION_SYSTEM.md §14):**

1. **Source of truth**: For each file touched, identify THE source of truth.
   Is there a second source? If yes → bug. Check: `financial_core/` vs service, profile vs state.

2. **Callsites**: Before fixing anything, list ALL consumers of the function/class.
   A fix that works for one callsite but breaks another = regression.

3. **Canonical path**: Trace the REAL runtime path:
   `UI → navigation → GoRouter.extra → screen → ScreenReturn → handler → store`
   Every link must be verified. A test that only covers the service misses the joint.

4. **Fallbacks**: Search for legacy fallback code still alive in parallel.
   `grep -rn "_handleRouteReturn\|fallback\|legacy" lib/screens/coach/`
   If both canonical and fallback fire → double processing bug.

5. **Side effects**: When fixing a handler, check: does fixing it trigger
   unexpected CapMemory writes, CoachInsight saves, or milestone pulses?

6. **Runtime joint**: The joint between two systems is where bugs live.
   Screen → ScreenReturn → CoachChatScreen → SequenceChatHandler → SequenceStore.
   Read BOTH sides of each joint. Check types match, keys match, routes match.

7. **Auto-audit before commit**: List explicitly:
   - the bug most likely still present
   - the joint least proven
   - the riskiest fallback
   - any undemonstrated assumption

**Concrete checks (read files, don't just grep):**

- Route consistency: does every screen's `ScreenReturn.route` match its `GoRoute.path`?
- Interaction tracking: does every `onChanged` callback set `_hasUserInteracted = true`?
- PopScope timing: can `_emitFinalReturn` fire before `_readSequenceContext` has run?
- Output mapping: do `stepOutputs` keys match `SequenceTemplate.outputMapping` keys?
- Financial values: are gross/net/annual/monthly units consistent across the chain?
- Flag reset: is every boolean guard (`_isNavigating`, `_finalReturnEmitted`) reset in ALL paths (success + error + unmount)?

Severity: CRITICAL (wrong calc, runtime path) → fix now. HIGH (race, joint) → fix if budget. MEDIUM+ → log only.

## Verification Gate (IRON LAW)

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

After EVERY fix, before reporting it as done:

1. **RUN** the verification command fresh. Not from memory. Not from earlier.
2. **PASTE** the exact terminal output in your experiment log. "Should pass" is FORBIDDEN.
3. **READ** the output yourself. Confirm it proves your claim (fewer failures, no regressions).
4. If output contradicts your claim → the claim is wrong. Fix or revert.

| Rationalization | Response |
|----------------|----------|
| "Should work now" | RUN IT. Paste output. |
| "I'm confident it passes" | Confidence is not evidence. Run the test. |
| "I already tested earlier" | Code changed since then. Test AGAIN. |
| "It's a trivial change" | Trivial changes break production. Verify. |
| "The test was wrong" | Tests are spec. Fix the code, not the test (unless genuinely outdated). |
| "It only fails intermittently" | Flaky = broken. Find the race condition. |

**If verification FAILS:** Do NOT commit. Revert: `git checkout -- <files>`. Return to the Loop and retry with a different approach. If stuck 3x on same bug → log as `skip` and move to next target.

Claiming work is complete without verification is dishonesty, not efficiency.

### Common Failures — what your claim REQUIRES (Superpowers)

| Claim | Requires | NOT Sufficient |
|-------|----------|----------------|
| "Tests pass" | Fresh test command output: 0 failures | Previous run, "should pass", partial run |
| "No regressions" | Full suite run: same or fewer failures | Running only the changed test file |
| "Bug fixed" | Original symptom verified gone in fresh run | "Code looks right", assumed fixed |
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

After EACH iteration, report in this format:

```
iteration  metric_before  metric_after  delta  status   file:line  description
1          -5             -4            +1     keep     mortgage_service.dart:142  null check on canton
2          -4             -4            0      discard  tax_calculator.dart:89     wrong approach, reverted
3          -4             -3            +1     keep     avs_calculator.dart:55     couple cap condition
```

Status: `keep` (committed) | `discard` (reverted) | `crash` (build broke) | `skip` (stuck 3x)

## Rules

- **NEVER** change test assertion to match buggy code
- **NEVER** delete a failing test
- **NEVER** add `// ignore:` to suppress real warnings
- **NEVER** fix >1 unrelated bug before verifying
- **NEVER** modify `financial_core/` constants without human approval
- **NEVER** spend >5 min on one fix — revert and try simpler approach

## Final Report

```
AUTORESEARCH QUALITY — SESSION REPORT
Date: YYYY-MM-DD | Branch: feature/S{XX}-... | Budget: X/Y
Tests:   -F → -R (delta: +D fixed)
Analyze: I → J issues

EXPERIMENT LOG:
iter  before  after  delta  status   description
1     ...

STUCK (skipped): [list]
REMAINING: N failures, M analyze issues
```

## Invocation

- `/autoresearch-quality` — 20 fixes (default)
- `/autoresearch-quality 10` — quick pass
- `/autoresearch-quality 50` — deep pass
