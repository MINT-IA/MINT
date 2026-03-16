---
name: autoresearch-test-coverage
description: "Audit-only scan for test coverage gaps. Maps services to tests, flags under-tested or untested files. Reports without modifying code. Use with /autoresearch-test-coverage."
compatibility: Requires Flutter SDK and Python 3.10+
allowed-tools: Bash(flutter:*) Bash(pytest:*) Bash(grep:*) Read Glob Grep
metadata:
  author: mint-team
  version: "1.0"
---

# Autoresearch Test Coverage — Gap scanner (audit-only)

## Purpose

Identify services, calculators, and screens with missing or insufficient tests. This skill is **read-only** — it produces a coverage matrix but never modifies code.

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

## Priority ranking

| Priority | What | Why |
|----------|------|-----|
| P0 | `financial_core/` with 0 tests | Wrong calc = wrong projection for ALL users |
| P1 | `financial_core/` with <10 tests | Insufficient edge case coverage |
| P2 | Other services with 0 tests | Untested business logic |
| P3 | Screens with no widget test | UI regressions |
| P4 | Backend services with <5 tests | Backend calculation gaps |

## Strict rules

- **NEVER** modify any code — this is an audit-only skill
- **NEVER** create test files (only report gaps)
- Count `test(` and `testWidgets(` calls (not `group(`)
- Exclude `integration_test/` from the scan
- Report both absolute count and relative to the 10-test minimum

## Invocation

`/autoresearch-test-coverage` — full scan, produces report
