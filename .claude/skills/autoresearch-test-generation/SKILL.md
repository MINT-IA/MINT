---
name: autoresearch-test-generation
description: "Autonomous test factory. Identifies untested services/widgets, generates edge-case tests, keeps if green, discards if red. Use with /autoresearch-test-generation or /autoresearch-test-generation 100."
compatibility: Requires Flutter SDK
allowed-tools: Bash(flutter:*) Bash(dart:*) Bash(git:*) Read Edit Write Glob Grep
metadata:
  author: mint-team
  version: "1.0"
---

# Autoresearch Test Generation v1 — Autonomous Test Factory

## Philosophy

> "Untested code is broken code you haven't found yet. Generate tests relentlessly."

Karpathy-style loop: find untested file → read source → generate tests → run → keep if green, discard if red (or log bug) → repeat.

**Primary metric**: `test_count_delta` — number of new passing tests added this session
**Guard metric**: `flutter test` must not regress (all existing tests must still pass)

## Mutable Target

- `test/**/*_test.dart` — **CREATE only**. Never modify existing source code.

## Immutable Harness

- `lib/**/*.dart` — source code (read-only reference)
- `flutter test` — execution engine
- Existing test suite — must not regress

## Critical Rule

> **This skill creates TESTS only. It NEVER modifies source code.**
> If a generated test reveals a genuine bug, log it to the session report.
> Fixing the bug is the job of `/autoresearch-quality` or `/autoresearch-calculator-forge`.

## Loop Structure

### Phase 0 — INVENTORY

Map all testable files and their current coverage:

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile

# Count tests per service
for f in lib/services/*.dart; do
  base=$(basename "$f" .dart)
  count=$(grep -r "test(" test/services/${base}_test.dart 2>/dev/null | wc -l)
  echo "$base: $count tests"
done
```

Build a priority queue:

| Priority | Category | Threshold |
|----------|----------|-----------|
| P0 CRITICAL | `financial_core/` with < 10 tests | Must have 10+ |
| P1 HIGH | `services/` with < 10 tests | Must have 10+ |
| P2 MEDIUM | `widgets/` with 0 tests | Must have 3+ |
| P3 LOW | `screens/` with 0 widget tests | Should have 2+ |

Record baseline:
```
BASELINE: YYYY-MM-DD HH:MM
  total_test_files: N
  total_test_cases: M
  services_with_0_tests: [list]
  services_with_lt10_tests: [list]
  budget: B (from arg, default 30)
```

### Phase 1 — SELECT

Pick the least-tested file from the highest-priority category.

Read the source file completely — understand:
- Public methods and their signatures
- Edge cases (null, 0, negative, max values)
- Error paths (exceptions, invalid input)
- Dependencies (what it imports, what it calls)

### Phase 2 — GENERATE

Write 5-10 tests per file. Test types:

| Type | Description | Example |
|------|-------------|---------|
| **Unit** | Normal input → expected output | `computeMonthlyRente(44, 88200) → 2520` |
| **Golden profile** | Julien/Lauren known values | `projectToRetirement(julienProfile) → 677847` |
| **Edge case** | Boundary values | `salary = 0`, `age = 65`, `years = 44` |
| **Error path** | Invalid input handling | `negative salary → throws ArgumentError` |
| **Regression** | Known past bugs | `couple cap must not apply to concubins` |

Test file template:
```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/...';

void main() {
  group('ServiceName', () {
    // Setup
    late ServiceName service;

    setUp(() {
      service = ServiceName();
    });

    group('methodName', () {
      test('normal input returns expected result', () {
        // Arrange
        // Act
        // Assert
      });

      test('edge case: zero input', () { ... });
      test('edge case: maximum input', () { ... });
      test('error: negative input throws', () { ... });
    });
  });
}
```

### Phase 3 — EXECUTE

Run only the new test file first:
```bash
flutter test test/path/to/new_test.dart 2>&1 | tail -10
```

### Phase 4 — EVALUATE

| Result | Action |
|--------|--------|
| All pass | Commit the test file |
| Some fail — bad test logic | Fix the test (typo, wrong setup, missing mock) |
| Some fail — genuine bug found | Log bug in session report, remove failing test, commit passing tests |
| All fail — wrong approach | Discard entire file, try different approach |

If a genuine bug is found:
```
BUG FOUND: service_name.dart — method() returns X, expected Y
  Evidence: test case "description"
  Likely cause: [analysis]
  Severity: critical/high/medium/low
```

### Phase 5 — VERIFY

Every 3 batches (every ~20 new tests), run the FULL test suite:
```bash
flutter test 2>&1 | tail -5
```

If any existing test broke → revert the last batch immediately.

### Phase 6 — COMMIT

After each successful batch:
```bash
git add test/path/to/new_test.dart
git commit -m "test: add N tests for ServiceName (edge cases + golden profiles)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Phase 7 — REPEAT or STOP

Continue until:
- **Budget exhausted** (new_tests_added >= budget)
- **All P0/P1 files have 10+ tests**
- **Stuck** — cannot generate valid tests for a file after 2 attempts → skip

## Test Quality Rules

1. **NEVER mock `financial_core/` calculators** — test with real values, these are the source of truth
2. **NEVER modify source code to make tests pass** — that is `/autoresearch-quality`'s job
3. **Minimum 10 tests per service file** — fewer is not acceptable
4. **Every test must have a descriptive name** — `test('description of what is being tested', ...)`
5. **Golden profiles must use exact values from CLAUDE.md section 8** — Julien: 122'207, Lauren: 67'000, etc.
6. **Edge cases must include**: 0, negative, max int, null (where nullable), empty string, empty list
7. **Group tests by method** — use `group('methodName', () { ... })`
8. **No flaky tests** — no timers, no network, no randomness. Deterministic only.

## Anti-patterns (never do)

- **NEVER** write tests that test implementation details (private methods, internal state)
- **NEVER** write tests that always pass regardless of code (`expect(true, isTrue)`)
- **NEVER** copy-paste tests with minimal variation — each test must cover a distinct scenario
- **NEVER** skip the full suite verification every 3 batches
- **NEVER** commit failing tests (remove them, log the bug)
- **NEVER** modify `lib/` files — this skill is test-only

## Final Output

```
AUTORESEARCH TEST GENERATION — SESSION REPORT
===============================================
Date: YYYY-MM-DD
Branch: feature/S{XX}-...
Budget: X/Y tests used
Duration: ~Nm

RESULTS:
  Tests before: N total (M files)
  Tests after:  P total (Q files)
  Delta: +K new passing tests in J new files

NEW TEST FILES:
  1. test/services/financial_core/avs_calculator_edge_test.dart (+12 tests)
  2. test/services/mortgage_service_test.dart (+10 tests)
  3. test/widgets/budget/spending_meter_test.dart (+5 tests)
  ...

BUGS FOUND (not fixed — for /autoresearch-quality):
  1. [HIGH] mortgage_service.dart — affordability check ignores 2nd pillar EPL limit
  2. [MEDIUM] tax_calculator.dart — bracket boundary off-by-one at 200k

SKIPPED (could not generate valid tests):
  - coach_llm_service.dart — requires LLM mock infrastructure

COVERAGE GAPS REMAINING:
  - P0: financial_core/confidence_scorer.dart (3 tests, needs 10+)
  - P1: services/expat_service.dart (0 tests)
  - P2: widgets/coach/early_retirement_slider.dart (0 tests)
```

## Invocation

- `/autoresearch-test-generation` — default budget 30 tests
- `/autoresearch-test-generation 100` — deep pass, 100 tests max
