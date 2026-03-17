---
name: autoresearch-test-generation
description: "Autonomous test factory. Finds untested code → generates edge-case tests → keeps if green, logs bug if red. NEVER modifies source. Use with /autoresearch-test-generation or /autoresearch-test-generation 100."
compatibility: Requires Flutter SDK
metadata:
  author: mint-team
  version: "2.0"
---

# Autoresearch Test Generation v2 — Karpathy Test Factory

> "Untested code is broken code you haven't found yet."

## Constraints (NON-NEGOTIABLE)

- **Single metric**: `test_count_delta` — new passing tests added (higher = better).
- **Guard metric**: `flutter test` must not regress. Zero tolerance.
- **Time budget**: 5 min max per file. If tests won't compile in 5 min → discard → next file.
- **Single target**: ONE file per iteration. Generate 5-10 tests → run → keep/discard → next.
- **NEVER modifies `lib/`**. Tests only. Bug found → log it for `/autoresearch-quality`.

## Mutable / Immutable

| Mutable | Immutable |
|---------|-----------|
| `test/**/*_test.dart` (CREATE only) | `lib/**/*.dart` (read-only reference) |
| | Existing test suite (must not regress) |

## The Loop

```
┌─ INVENTORY: Map testable files → count tests per service
│  for f in lib/services/*.dart; do
│    base=$(basename "$f" .dart)
│    count=$(grep -c "test(" test/services/${base}_test.dart 2>/dev/null || echo 0)
│    echo "$base: $count"
│  done
│  Priority: P0 financial_core/<10 > P1 services/<10 > P2 widgets/0 > P3 screens/0
│
├─ SELECT: Pick least-tested file from highest priority. Read it fully.
│
├─ GENERATE (≤3 min): Write 5-10 tests. Types:
│  - Unit (normal input → expected output)
│  - Golden profile (Julien 122'207 / Lauren 67'000 — exact CLAUDE.md values)
│  - Edge case (0, negative, max, null, empty)
│  - Error path (invalid input → throws)
│  - Regression (known past bugs)
│
├─ EXECUTE (≤2 min): flutter test test/path/to/new_test.dart 2>&1 | tail -10
│
├─ EVALUATE:
│  All pass → commit.
│  Some fail (bad test) → fix test.
│  Some fail (genuine bug) → log bug, remove failing tests, commit passing ones.
│  All fail → discard file, next.
│
├─ LOG: Append to experiment log
│
├─ COMMIT: git add test/... && git commit -m "test: add N tests for ServiceName"
│
└─ REPEAT until: budget exhausted | all P0/P1 have 10+ tests
    Every 3 batches → full suite: flutter test 2>&1 | tail -5
```

## Test Quality Rules

1. **NEVER mock `financial_core/` calculators** — test with real values
2. **NEVER write always-passing tests** — each must test a distinct scenario
3. **Minimum 10 tests per service** — CLAUDE.md requirement
4. **Descriptive names**: `test('LAVS art.35 — couple cap at 150% married only', ...)`
5. **Group by method**: `group('methodName', () { ... })`
6. **No flaky tests**: no timers, no network, no randomness
7. **Golden profiles use exact CLAUDE.md § 8 values**

## Experiment Log (append-only)

```
iteration  file_targeted               tests_before  tests_after  delta  status   bugs_found
1          avs_calculator.dart         3             13           +10    keep     0
2          mortgage_service.dart       0             8            +8     keep     1 (HIGH: ignores EPL limit)
3          coach_llm_service.dart      0             0            0      discard  needs LLM mock infra
```

Status: `keep` | `discard` | `partial` (some tests kept, some removed)

## Final Report

```
AUTORESEARCH TEST GENERATION — SESSION REPORT
Date: YYYY-MM-DD | Branch: feature/S{XX}-... | Budget: X/Y
Tests: N total → P total (+K new in J files)

EXPERIMENT LOG:
iter  file  before  after  delta  status  bugs
1     ...

BUGS FOUND (for /autoresearch-quality):
  1. [HIGH] mortgage_service.dart — affordability ignores EPL limit
  2. [MEDIUM] tax_calculator.dart — bracket boundary off-by-one at 200k

COVERAGE GAPS REMAINING:
  P0: confidence_scorer.dart (3 tests, needs 10+)
  P1: expat_service.dart (0 tests)
```

## Invocation

- `/autoresearch-test-generation` — 30 tests (default)
- `/autoresearch-test-generation 100` — deep pass
