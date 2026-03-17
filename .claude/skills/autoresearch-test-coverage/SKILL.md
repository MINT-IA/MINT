---
name: autoresearch-test-coverage
description: "Test coverage auditor + gap delegator. Maps services to tests, flags under-tested files, outputs test_gaps.json for autoresearch-test-generation to consume. Use with /autoresearch-test-coverage."
compatibility: Requires Flutter SDK and Python 3.10+
allowed-tools: Bash(flutter:*) Bash(pytest:*) Bash(grep:*) Read Edit Write Glob Grep
metadata:
  author: mint-team
  version: "2.0"
---

# Autoresearch Test Coverage — Gap scanner (audit-only)

## Purpose

Identify services, calculators, and screens with missing or insufficient tests. Produces a coverage matrix and generates `test_gaps.json` for downstream consumption by `/autoresearch-test-generation`.

## CLAUDE.md requirements

- **Service files**: minimum 10 unit tests (edge cases + compliance)
- **Screens/widgets**: widget tests (render, empty, error states)
- **Golden couple**: Julien + Lauren tested against known expected values
- **Before merge**: `flutter analyze` (0 issues) + `flutter test` + `pytest tests/ -q`

## Scan phases

### Phase 1: Flutter services inventory

```bash
# List all service files
find apps/mobile/lib/services/ -name "*.dart" -not -name "*_test*" | sort

# List all test files
find apps/mobile/test/services/ -name "*_test.dart" | sort
```

For each service file `foo_service.dart`, check if `foo_service_test.dart` exists.

### Phase 2: Flutter test count per service

For each test file that exists:
```bash
grep -c "test(" apps/mobile/test/services/foo_service_test.dart
```

Flag if count < 10 (CLAUDE.md minimum).

### Phase 3: Financial core (highest priority)

```bash
# These are the most critical — wrong calc = wrong projection
find apps/mobile/lib/services/financial_core/ -name "*.dart" | sort
find apps/mobile/test/services/financial_core/ -name "*_test.dart" | sort
```

Cross-reference and count tests. Financial core services with <10 tests are **CRITICAL**.

### Phase 4: Screen/widget tests

```bash
# List all screens
find apps/mobile/lib/screens/ -name "*.dart" | sort

# List all screen tests
find apps/mobile/test/screens/ -name "*_test.dart" | sort
```

Flag screens with no corresponding test file.

### Phase 5: Backend services

```bash
# List all backend service files
find services/backend/app/services/ -name "*.py" -not -name "__*" | sort

# List all backend tests
find services/backend/tests/ -name "test_*.py" | sort
```

### Phase 6: Golden couple validation

Check that golden test files exist and cover both profiles:
```bash
grep -rn "julien\|lauren\|golden" apps/mobile/test/ --include="*.dart" -l
grep -rn "julien\|lauren\|golden" services/backend/tests/ --include="*.py" -l
```

## Report format

```
TEST COVERAGE AUDIT REPORT
============================
Scan date: YYYY-MM-DD

FLUTTER SERVICES:
  Total service files: N
  With tests: M (X%)
  With ≥10 tests: P (Y%)

COVERAGE MATRIX (sorted by risk):

  CRITICAL (financial_core, no tests):
    ❌ avs_calculator.dart — 0 tests
    ...

  WARNING (<10 tests):
    ⚠️  mortgage_service.dart — 5 tests (need 10+)
    ...

  OK (≥10 tests):
    ✅ coaching_service.dart — 36 tests
    ...

SCREENS:
  Total screens: N
  With widget tests: M (X%)

  MISSING TESTS:
    ❌ screens/budget_screen.dart — no test file
    ...

BACKEND:
  Total service files: N
  With tests: M (X%)

GOLDEN COUPLE:
  ✅ Julien profile tested in: [files]
  ✅ Lauren profile tested in: [files]
  ❌ Missing: [specific gaps]

RECOMMENDATIONS:
  1. Add 10+ tests to avs_calculator.dart (CRITICAL)
  2. Add widget test for budget_screen.dart
  ...
```

## Phase 2 — DELEGATE

After the audit phases complete, generate `test_gaps.json` listing all files with <10 tests. This file is consumed by `/autoresearch-test-generation` for autonomous test creation.

**Output path**: `apps/mobile/test/test_gaps.json`

**Format**:

```json
[
  {"file": "lib/services/xyz_service.dart", "current_tests": 3, "target_tests": 10, "priority": "high"},
  {"file": "lib/services/financial_core/abc_calculator.dart", "current_tests": 0, "target_tests": 10, "priority": "critical"},
  {"file": "lib/screens/budget_screen.dart", "current_tests": 0, "target_tests": 3, "priority": "medium"}
]
```

**Priority mapping**:
- `critical` — `financial_core/` with 0 tests (P0)
- `high` — `financial_core/` with <10 tests OR other services with 0 tests (P1-P2)
- `medium` — screens with no widget test (P3)
- `low` — backend services with <5 tests (P4)

After generating `test_gaps.json`, run `/autoresearch-test-generation` to automatically fill the gaps.

## Priority ranking

| Priority | What | Why |
|----------|------|-----|
| P0 | `financial_core/` with 0 tests | Wrong calc = wrong projection for ALL users |
| P1 | `financial_core/` with <10 tests | Insufficient edge case coverage |
| P2 | Other services with 0 tests | Untested business logic |
| P3 | Screens with no widget test | UI regressions |
| P4 | Backend services with <5 tests | Backend calculation gaps |

## Strict rules

- **NEVER** modify any source code — this skill only creates `test_gaps.json` as output
- **NEVER** create test files (only report gaps — test creation is delegated to `/autoresearch-test-generation`)
- Count `test(` and `testWidgets(` calls (not `group(`)
- Exclude `integration_test/` from the scan
- Report both absolute count and relative to the 10-test minimum

## Invocation

`/autoresearch-test-coverage` — full scan, produces report
