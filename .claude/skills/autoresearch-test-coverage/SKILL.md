---
name: autoresearch-test-coverage
description: "Test coverage auditor. Maps services to tests, flags under-tested files, outputs test_gaps.json for autoresearch-test-generation. Use with /autoresearch-test-coverage."
compatibility: Requires Flutter SDK and Python 3.10+
metadata:
  author: mint-team
  version: "3.0"
---

# Autoresearch Test Coverage v3 — Karpathy Gap Auditor

> "You can't improve what you don't measure."

## Constraints (NON-NEGOTIABLE)

- **Single metric**: coverage matrix completeness (files audited / total files).
- **This skill is AUDIT-ONLY**: never modify source code, never create test files.
- **Output**: coverage report + `test_gaps.json` for `/autoresearch-test-generation` to consume.
- **CLAUDE.md requirement**: service files need minimum 10 unit tests.

## Scan Phases

### Phase 1: Flutter services inventory

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile

# All service files
find lib/services/ -name "*.dart" -not -name "*_test*" | sort

# All test files
find test/services/ -name "*_test.dart" 2>/dev/null | sort
```

### Phase 2: Test count per service

```bash
for f in lib/services/*.dart lib/services/**/*.dart; do
  base=$(basename "$f" .dart)
  testfile=$(find test/ -name "${base}_test.dart" 2>/dev/null | head -1)
  if [ -n "$testfile" ]; then
    count=$(grep -c "test(" "$testfile" 2>/dev/null || echo 0)
  else
    count=0
  fi
  echo "$base: $count tests"
done
```

### Phase 3: Financial core (CRITICAL priority)

```bash
find lib/services/financial_core/ -name "*.dart" | sort
find test/services/financial_core/ -name "*_test.dart" 2>/dev/null | sort
```

Cross-reference. Financial core with <10 tests = **CRITICAL**.

### Phase 4: Screens/widgets

```bash
find lib/screens/ -name "*.dart" | sort
find test/screens/ -name "*_test.dart" 2>/dev/null | sort
```

### Phase 5: Backend

```bash
find ../../services/backend/app/services/ -name "*.py" -not -name "__*" | sort
find ../../services/backend/tests/ -name "test_*.py" | sort
```

### Phase 6: Golden couple validation

```bash
grep -rn "julien\|lauren\|golden" test/ --include="*.dart" -l
```

## Priority Mapping

| Priority | What | Threshold |
|----------|------|-----------|
| P0 CRITICAL | `financial_core/` with 0 tests | Must have 10+ |
| P1 HIGH | `financial_core/` with <10 tests OR services with 0 tests | Must have 10+ |
| P2 MEDIUM | Screens with no widget test | Should have 3+ |
| P3 LOW | Backend services with <5 tests | Should have 5+ |

## Output: test_gaps.json

Path: `apps/mobile/test/test_gaps.json`

```json
[
  {"file": "lib/services/financial_core/abc.dart", "current_tests": 0, "target_tests": 10, "priority": "critical"},
  {"file": "lib/services/xyz_service.dart", "current_tests": 3, "target_tests": 10, "priority": "high"},
  {"file": "lib/screens/budget_screen.dart", "current_tests": 0, "target_tests": 3, "priority": "medium"}
]
```

After generating, run `/autoresearch-test-generation` to fill gaps.

## Rules

- **NEVER modify source code** — audit only
- **NEVER create test files** — delegate to `/autoresearch-test-generation`
- Count `test(` and `testWidgets(` calls (not `group(`)
- Exclude `integration_test/`

## Verification Gate (IRON LAW)

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

This skill is audit-only, but audit accuracy is equally critical:

1. **RUN** each count command fresh. Do not estimate or recall from memory.
2. **PASTE** the exact terminal output for every count in your report. "About N tests" is FORBIDDEN.
3. **CROSS-CHECK**: for each file in test_gaps.json, verify the test count by running `grep -c "test(" <file>`.
4. If a count looks wrong → re-run the command. Do not guess.

| Rationalization | Response |
|----------------|----------|
| "Should be about N tests" | RUN the count. Paste exact number. |
| "The file is well-covered by integration tests" | Count UNIT tests. Integration is not unit. |
| "10 tests per service is arbitrary" | 10 is the CLAUDE.md requirement. Not negotiable. |
| "I already counted earlier" | Files may have changed. Count AGAIN. |

**If a count looks wrong:** Re-run the command. If `test_gaps.json` contains a file that no longer exists → remove it. If a test count disagrees between grep and manual read → trust the manual read and investigate.

An inaccurate audit is worse than no audit — it creates false confidence.

## Final Report

```
TEST COVERAGE AUDIT REPORT
Date: YYYY-MM-DD

FLUTTER SERVICES: N total, M with tests (X%), P with >=10 tests (Y%)

CRITICAL: [financial_core with 0 tests]
WARNING:  [services with <10 tests]
OK:       [services with >=10 tests]

SCREENS: N total, M with widget tests (X%)
BACKEND: N total, M with tests (X%)
GOLDEN COUPLE: Julien ✅/❌ | Lauren ✅/❌

test_gaps.json generated: K entries
```

## Invocation

- `/autoresearch-test-coverage` — full scan, produces report + test_gaps.json
