---
name: autoresearch-quality
description: "Karpathy-style edit->verify loop for Flutter code quality. Runs flutter analyze, prioritizes issues, fixes in batches of 5, verifies periodically. Use with /autoresearch-quality or /autoresearch-quality 50."
compatibility: Requires Flutter SDK
allowed-tools: Bash(flutter:*) Bash(dart:*) Bash(git:*) Read Edit Write Glob Grep
metadata:
  author: mint-team
  version: "2.0"
---

# Autoresearch Quality v2 — Karpathy-Style Edit-Verify Loop

## Philosophy

Inspired by Andrej Karpathy's "autoresearch" principle: an autonomous agent that iteratively improves a codebase by measuring, fixing, and verifying — with no human in the loop until the budget is exhausted.

**Core idea**: Pick a metric. Fix things that move the metric. Verify after each batch. Stop when budget is spent or metric hits zero.

## Metrics

### Primary Metric
`flutter analyze` issue count (errors + warnings + infos).

**Goal**: Reduce to 0 (or as low as possible within budget).

### Guard Metrics (must not regress)
| Guard | Command | Threshold |
|-------|---------|-----------|
| Tests | `flutter test` | 0 failures (run every 15 fixes) |
| Hardcoded strings | `grep -rn "Text('" lib/screens/ lib/widgets/ --include="*.dart"` | Must not increase |
| Banned terms | `grep -rn "garanti\|sans risque\|optimal\|meilleur\|parfait\|conseiller" lib/screens/ lib/widgets/ --include="*.dart"` | Must stay 0 |

## Loop Structure

### Phase 0 — INVENTORY

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
flutter analyze 2>&1 | tee /tmp/mint_analyze_baseline.txt
```

Parse the output. Count total issues. Classify by type.

### Phase 1 — BASELINE

Record the starting state:

```
BASELINE: YYYY-MM-DD HH:MM
  analyze_issues: N
  test_failures: M (run flutter test)
  budget_total: B (from user arg, default 30)
  budget_spent: 0
```

### Phase 2 — FIX BATCH (5 issues per batch)

Pick the top 5 issues by priority (see Priority Table below). Fix them.

**Rules for fixing**:
- Read the file BEFORE editing (mandatory)
- Fix the root cause, not the symptom
- If a fix requires importing a new package, check it exists first
- If a fix changes behavior (not just types/lint), flag it
- One fix = one `Edit` call. Never batch multiple fixes in one Edit.

### Phase 3 — VERIFY

After each batch of 5 fixes:

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
flutter analyze 2>&1 | tail -5
```

Record new issue count. If it went UP, revert the last batch and investigate.

Every 3 batches (15 fixes), also run:

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
flutter test 2>&1 | tail -10
```

If tests break, fix the test regression BEFORE continuing.

### Phase 4 — LOG

After each batch, append to the session log (TSV format, see below).

### Phase 5 — REPEAT

Go back to Phase 2 until:
- Budget exhausted (budget_spent >= budget_total)
- Metric hits 0 (no more issues)
- 3 consecutive batches with 0 improvement (plateau)

## Priority Table

| Priority | Category | Example | Fix complexity |
|----------|----------|---------|----------------|
| P0 | Errors | Compilation errors, missing imports | Usually simple |
| P1 | Warnings — unused imports | `Unused import` | Trivial (delete line) |
| P2 | Warnings — unused variables | `The value of the local variable 'x' isn't used` | Simple (delete or use) |
| P3 | Warnings — deprecated API | `'oldMethod' is deprecated` | Medium (find replacement) |
| P4 | Infos — style | `Prefer const constructors` | Simple but numerous |
| P5 | Infos — documentation | `Missing documentation` | Skip unless budget allows |

**Always fix P0 first. Then P1. Then P2. Etc.**

Within the same priority, fix by file — all issues in one file before moving to the next. This minimizes file reads.

## Strict Rules

1. **NEVER skip the verify step.** Every batch of 5 must be verified.
2. **NEVER fix more than 5 issues between verify steps.** This keeps the feedback loop tight.
3. **NEVER modify test files to make analyze pass** (unless the test itself has a genuine lint issue).
4. **NEVER add `// ignore:` comments** to suppress warnings. Fix the root cause.
5. **NEVER change business logic** to fix a lint warning. If a fix would change behavior, skip it and log it.
6. **ALWAYS read the file before editing.** The Edit tool requires it.
7. **ALWAYS use absolute paths** (`/Users/julienbattaglia/Desktop/MINT/apps/mobile/...`).
8. **ALWAYS preserve existing functionality.** This is a quality pass, not a refactor.
9. **If tests break, fix the regression IMMEDIATELY** before continuing the loop.
10. **If budget is specified** (e.g., `/autoresearch-quality 50`), that number is the max fixes. Default = 30.

## TSV Session Log Format

After each batch, mentally track (or print) progress in this format:

```
batch	timestamp	issues_before	issues_after	delta	fixes_applied	files_touched	tests_status
1	HH:MM	42	37	-5	5	3	not_run
2	HH:MM	37	32	-5	5	4	not_run
3	HH:MM	32	27	-5	5	2	PASS (114/114)
```

## Final Output

When the loop ends, produce this summary:

```
## Autoresearch Quality — Session Report

**Date**: YYYY-MM-DD
**Branch**: feature/S{XX}-...
**Budget**: X fixes used / Y total

### Results
| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| analyze issues | N | M | -K |
| test failures | 0 | 0 | 0 |

### Batches
batch	issues_before	issues_after	delta	files_touched
1	...
2	...

### Skipped Issues (would change behavior)
- file.dart:42 — reason

### Remaining Issues (budget exhausted)
- N issues remaining (list top 5 by priority)
```

## Invocation

- `/autoresearch-quality` — run with default budget of 30 fixes
- `/autoresearch-quality 50` — run with budget of 50 fixes
- `/autoresearch-quality 100` — run with budget of 100 fixes

The number is the maximum number of individual fixes to apply. Each batch = 5 fixes. So budget 30 = max 6 batches.
