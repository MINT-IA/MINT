---
name: autoresearch-quality
description: "Autonomous bug hunter. Runs flutter test, reads failures, fixes the CODE (not the test), re-runs to verify. Falls back to flutter analyze when tests are green. GATE for ROADMAP_V2.md Phase 1 Chat AI — quality must be green before proceeding. Use with /autoresearch-quality or /autoresearch-quality 20."
compatibility: Requires Flutter SDK
allowed-tools: Bash(flutter:*) Bash(dart:*) Bash(git:*) Read Edit Write Glob Grep
metadata:
  author: mint-team
  version: "3.1"
---

# Autoresearch Quality v3 — Autonomous Bug Hunter

## Philosophy

> "The test suite is the spec. A failing test is a bug. Fix the code, not the test."

Karpathy-style loop: run tests → read the failure → understand root cause → fix the **source code** → re-run → repeat.

**Primary metric**: `flutter test` failure count.
**Secondary metric**: `flutter analyze` issue count (only when tests are green).

## Critical Rules

1. **Fix the CODE, never the test** — a failing test means the code is wrong, not the test
2. **Exception**: if a test expectation is genuinely outdated (e.g., accented text after i18n migration), fix the test
3. **Read before fix** — always read the failing test AND the source code before editing
4. **One bug at a time** — fix one failure, verify, then next
5. **Never break green tests** — if your fix causes a previously-passing test to fail, revert immediately

## Loop Structure

### Phase 0 — BASELINE

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
flutter test 2>&1 | tail -5
```

Extract: `+N ~M -F` → N passed, M skipped, F failed.

> **GATE**: This skill is a GATE for Phase 1 Chat AI — quality must be green before proceeding with chat implementation. All tests passing + 0 analyze errors = green light.

If F = 0 (all tests pass), fall back to **Phase 0b — Analyze Mode**:
```bash
flutter analyze 2>&1 | tail -3
```

Record baseline:
```
BASELINE: YYYY-MM-DD HH:MM
  test_pass: N
  test_fail: F
  test_skip: M
  analyze_issues: I
  budget: B (from arg, default 20)
```

### Phase 1 — TRIAGE

If tests are failing, get the failure list:

```bash
flutter test 2>&1 | grep "\[E\]" | head -20
```

Group failures by root cause (often multiple tests fail from the same bug). Prioritize:

| Priority | Type | Example |
|----------|------|---------|
| P0 | Compilation error | Missing import, wrong type, missing parameter |
| P1 | Runtime crash | Null pointer, index out of bounds, state error |
| P2 | Logic bug | Wrong calculation result, wrong condition |
| P3 | UI mismatch | Widget not found, wrong text, missing widget |
| P4 | Async issue | Future not awaited, timing problem |

### Phase 2 — DIAGNOSE

For the highest-priority failure:

1. **Read the test file** — understand what the test expects
2. **Read the error message** — understand what actually happened
3. **Read the source code** — find the bug
4. **Identify root cause** — is it a missing parameter? Wrong logic? Stale import?

**Golden test profiles** for validation:
- **Julien** (49 ans, VS, 122K, swiss_native) + **Lauren** (43 ans, VS, 67K, expat_us) — see CLAUDE.md § 8
- **Marco** (24 ans, TI, 52K, apprenti) — young profile for early-career edge cases

Common patterns:
- `missing_required_argument` → service method signature changed, caller not updated
- `type 'Null' is not a subtype of type 'X'` → null safety issue in source
- `Expected: X, Actual: Y` → calculation bug or stale expected value
- `No widget found` → widget not rendered due to state/logic issue
- `RangeError` → array/list bounds issue in source

### Phase 3 — FIX

Apply the minimal fix to the **source code** (not the test):

- If a method signature changed → update the caller
- If a calculation is wrong → fix the formula
- If a null check is missing → add the guard
- If an import is missing → add it
- If a widget isn't rendering → fix the condition

**Exception — fix the test when**:
- Test text expectations changed due to i18n migration (accents added)
- Test was checking implementation details that legitimately changed
- Test has a genuine bug (wrong expected value based on spec)

### Phase 4 — VERIFY

After each fix, re-run the specific failing test:

```bash
flutter test test/path/to/specific_test.dart 2>&1 | tail -5
```

- If it passes → commit and move to next failure
- If it still fails → re-diagnose, try different fix
- If OTHER tests broke → revert immediately, re-think approach

Every 5 fixes, run the full suite:
```bash
flutter test 2>&1 | tail -5
```

### Phase 5 — COMMIT

After each successful fix (or batch of related fixes):

```bash
git add <specific files>
git commit -m "fix: <description of the bug fixed>

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Phase 6 — REPEAT or STOP

Continue until:
- **Budget exhausted** (fixes_applied >= budget)
- **All tests pass** (F = 0)
- **Stuck** — same failure after 3 fix attempts → skip and move to next
- **Analyze mode complete** — all issues fixed or only info-level remain

## Analyze Mode (when all tests pass)

When `flutter test` is green, switch to lint fixes:

1. Run `dart fix --apply` for bulk mechanical fixes (prefer_const, unnecessary_new, etc.) before manual fixes
2. Run `flutter analyze`
3. Fix errors first, then warnings, then infos
4. Verify with `flutter test` after every 5 lint fixes (guard against regressions)
5. Stop when only `avoid_print` in tests + `constant_identifier_names` remain

## Anti-patterns (never do)

- **NEVER** change a test assertion to match buggy code
- **NEVER** delete a failing test to make the suite green
- **NEVER** add `// ignore:` to suppress real warnings
- **NEVER** skip the verify step between fixes
- **NEVER** fix more than one unrelated bug before verifying
- **NEVER** modify `financial_core/` calculators without running the full test suite
- **NEVER** change business constants (LPP rates, AVS thresholds, etc.)

## Final Output

```
AUTORESEARCH QUALITY — SESSION REPORT
=======================================
Date: YYYY-MM-DD
Branch: feature/S{XX}-...
Budget: X/Y fixes used
Duration: ~Nm

RESULTS:
  Tests:   before=+N ~M -F → after=+P ~Q -R
  Analyze: before=I issues → after=J issues

BUGS FIXED:
  1. [fix] missing S parameter in donation_service_test.dart
     Root cause: i18n migration added required param, test not updated
  2. [fix] null pointer in mortgage_service.calculate()
     Root cause: missing null check on optional canton field
  ...

STUCK (skipped after 3 attempts):
  - test/xyz_test.dart: "timeout" — needs async investigation

REMAINING:
  - N test failures still open
  - M analyze issues (info-level only)
```

## Invocation

- `/autoresearch-quality` — default budget 20 fixes
- `/autoresearch-quality 10` — quick pass, 10 fixes max
- `/autoresearch-quality 50` — deep pass, 50 fixes max
