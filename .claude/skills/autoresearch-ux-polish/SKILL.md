---
name: autoresearch-ux-polish
description: "Autonomous UX violation fixer. Scans for hardcoded colors, Navigator.push, raw Material colors, missing Semantics. Fixes ONE file per iteration. Use with /autoresearch-ux-polish or /autoresearch-ux-polish 30."
compatibility: Requires Flutter SDK
metadata:
  author: mint-team
  version: "2.0"
---

# Autoresearch UX Polish v2 — Karpathy UX Violation Fixer

> "Every pixel must respect the 7 laws. Violations are bugs."

## Constraints (NON-NEGOTIABLE)

- **Single metric**: `ux_violations_count` (lower = better). Measured by grep.
- **Time budget**: 5 min per file. If fix causes cascading issues → revert → skip file.
- **Single target**: ONE file per iteration. Fix all violations in that file → verify → commit → next.
- **Guard**: `flutter analyze` (0 new errors) + `flutter test` (no regressions).
- **Scope**: visual/structural fixes ONLY. Never change business logic or add features.

## Violation Types (automatable, measured by grep)

| Check | Pattern | Replace with | Severity |
|-------|---------|--------------|----------|
| Hardcoded hex | `Color(0xFF` | `MintColors.*` | HIGH |
| Raw Material colors | `Colors.blue` etc. | `MintColors.*` | HIGH |
| Navigator.push | `Navigator.push(` / `Navigator.of(` | `context.go(` / `context.push(` (GoRouter) | HIGH |
| Missing Semantics | `GestureDetector`/`InkWell` without `Semantics` | Wrap with `Semantics(label:)` | MEDIUM |
| Hardcoded i18n | `Text('French...')` without `S.of(context)!` | Defer to `/autoresearch-i18n` (flag only) | HIGH (flag) |

## Detection Commands

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
grep -rn "Color(0x" lib/widgets/ lib/screens/ | wc -l           # hardcoded hex
grep -rn "Colors\." lib/widgets/ lib/screens/ | grep -v MintColors | wc -l  # raw Material
grep -rn "Navigator.push\|Navigator.of" lib/widgets/ lib/screens/ | wc -l   # Navigator
```

## Mutable / Immutable

| Mutable (ONE file per iteration) | Immutable |
|----------------------------------|-----------|
| `lib/widgets/**/*.dart` | `lib/theme/colors.dart` (read for mapping) |
| `lib/screens/**/*.dart` | GoRouter route definitions (read for paths) |
| | Business logic, test files |

## The Loop

```
┌─ INVENTORY: Run detection commands. List files by violation count (desc).
│
├─ SELECT: File with most violations. Read it fully.
│  Also read lib/theme/colors.dart (color mapping) before replacing colors.
│  Also read GoRouter routes before replacing Navigator.
│
├─ FIX (≤4 min): Fix by severity (HIGH first).
│  Color(0xFF...) → closest MintColors.* match
│  Colors.blue → MintColors.primary (check palette)
│  Navigator.push → context.go('/route') or context.push('/route')
│  Add Semantics(label:) around interactive widgets
│
├─ VERIFY (≤1 min):
│  flutter analyze lib/path/to/fixed_file.dart 2>&1 | tail -5
│  flutter test 2>&1 | tail -5
│  Regression → revert immediately.
│
├─ LOG: Append to experiment log
│
├─ COMMIT: git add ... && git commit -m "ux: fix N violations in <file>"
│
└─ REPEAT until: budget exhausted | all HIGH violations = 0
    Every 5 files → full verification
```

## Rules

- **NEVER change business logic** — only visual/structural
- **NEVER remove functionality** — preserve all behavior
- **NEVER add new features** — fix violations only
- **NEVER guess colors** — always check MintColors palette first
- **NEVER guess routes** — always check GoRouter definitions first
- **Defer bulk i18n** to `/autoresearch-i18n` — only flag, don't fix here
- **NEVER fix >1 file without verifying** between fixes

## Verification Gate (IRON LAW)

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

After EVERY file fix, before reporting it as done:

1. **RUN** `flutter analyze 2>&1 | tail -10` AND `flutter test 2>&1 | tail -10` fresh.
2. **RUN** detection commands on the fixed file. Confirm violation count = 0 for that file.
3. **PASTE** all outputs in your experiment log. "Should pass" is FORBIDDEN.
4. If violations remain in the file → the fix is incomplete. Do not move to next file.

| Rationalization | Response |
|----------------|----------|
| "Should work now" | RUN IT. Paste output. |
| "I'm confident it passes" | Confidence is not evidence. Run the test. |
| "I already tested earlier" | Code changed since then. Test AGAIN. |
| "It's a trivial change" | Trivial changes break production. Verify. |
| "This color is close enough to MintColors" | Close is not correct. Use the exact token from colors.dart. |
| "The old Navigator.push works fine" | Consistency is a feature. GoRouter everywhere (except dialogs). |

**If verification FAILS:** Do NOT commit. Revert: `git checkout -- <files>`. If fix caused cascading issues → revert ALL and skip this file. Return to the Loop.

Claiming work is complete without verification is dishonesty, not efficiency.

## Experiment Log (append-only)

```
iteration  file                        violations_before  violations_after  delta  status
1          spending_meter.dart         5                  0                 -5     keep
2          budget_report_section.dart  3                  0                 -3     keep
3          coach_chat_screen.dart      4                  4                 0      skip (complex callbacks)
```

## Final Report

```
AUTORESEARCH UX POLISH — SESSION REPORT
Date: YYYY-MM-DD | Branch: feature/S{XX}-... | Budget: X/Y files

Violations: V → W (delta: -D)
  Hardcoded colors: N fixed
  Navigator.push: N fixed
  Raw Material: N fixed
  Semantics: N added

EXPERIMENT LOG:
iter  file  before  after  delta  status
1     ...

SKIPPED: [files with cascading issues]
REMAINING: HIGH=N, MEDIUM=M
```

## Invocation

- `/autoresearch-ux-polish` — 15 files (default)
- `/autoresearch-ux-polish 30` — deep pass
