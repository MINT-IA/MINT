---
name: autoresearch-i18n
description: "Karpathy-style string extraction loop. Finds hardcoded French strings → extracts to ALL 6 ARB files → verifies with gen-l10n + tests → repeats. Use with /autoresearch-i18n or /autoresearch-i18n 40."
compatibility: Requires Flutter SDK
metadata:
  author: mint-team
  version: "3.0"
---

# Autoresearch i18n v3 — Karpathy String Extraction Loop

> Measure → extract → verify → repeat. Until zero hardcoded strings remain.

## Constraints (NON-NEGOTIABLE)

- **Single metric**: hardcoded French string count in `lib/screens/` + `lib/widgets/` (lower = better).
- **Time budget**: 5 min per batch (5 strings). If gen-l10n fails → revert batch → fix ARB → retry.
- **Single target**: ONE file per batch. The file with the most hardcoded strings.
- **Guard metrics**: `flutter gen-l10n` (must succeed) | `flutter test` every 10 extractions (0 regressions) | ARB parity (6 files within 5 lines)

## Detection Commands

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile

# Count hardcoded strings (PRIMARY METRIC)
grep -rn "Text(\s*'" lib/screens/ lib/widgets/ --include="*.dart" \
  | grep -v "Text(S\.\|Text(widget\.\|Text(state\.\|Text(format\|// \|_test.dart\|archive/" \
  | wc -l

# NBSP violations (SECONDARY)
grep -Pn '[^\u00a0][!?:;%]' lib/l10n/app_fr.arb | grep -v '"@\|//\|http\|mailto' | wc -l
```

## The Loop

```
┌─ INVENTORY: Run detection command. List top-20 files by hardcoded count.
│
├─ SELECT: File with most hardcoded strings. Skip archive/.
│
├─ EXTRACT BATCH (≤5 strings, ≤3 min):
│  For each string:
│  1. Read file, understand context
│  2. Choose key: camelCase, {screenOrWidget}{Description} (e.g., budgetScreenTitle)
│  3. Check for duplicate: grep -i "term" lib/l10n/app_fr.arb
│  4. Add key to ALL 6 ARB files (fr, en, de, es, it, pt) — keys at END before }
│  5. Handle placeholders: "Il te reste {amount} CHF" + @key metadata
│  6. Replace: Text('...') → Text(S.of(context)!.keyName)
│  7. Add import if missing: import 'package:mint_mobile/l10n/app_localizations.dart';
│
├─ VERIFY (≤2 min):
│  flutter gen-l10n 2>&1  — if FAILS → git checkout -- lib/l10n/app_*.arb → fix → retry
│  flutter analyze 2>&1 | tail -5
│  Recount hardcoded strings (must decrease)
│  Every 2 batches: flutter test 2>&1 | tail -10
│
├─ LOG: Append to experiment log
│
├─ COMMIT: git add ... && git commit -m "i18n: extract N strings from <file>"
│
└─ REPEAT until: budget exhausted | 0 hardcoded strings | 3 consecutive batches with 0 extractions
```

## Extraction Rules

1. **French accents MANDATORY**: impôt, être, prévoyance, retraite — ASCII = bug
2. **NBSP before double punctuation**: `\u00a0` before `!`, `?`, `:`, `;`, `%`
3. **No duplicate keys**: always search first, reuse if exists
4. **ALL 6 ARB files**: never add to just app_fr.arb
5. **Keys at END**: minimize merge conflicts
6. **Do NOT i18n**: variable names, routes, enums, SharedPreferences keys, analytics, debug strings
7. **Preserve formatting**: handle `\n`, interpolation properly

## Experiment Log (append-only)

```
batch  file_processed           strings_before  strings_after  delta  keys_added  gen_l10n  tests
1      budget_screen.dart       87              82             -5     5           OK        not_run
2      retirement_screen.dart   82              77             -5     3(+2reuse)  OK        PASS
3      lpp_deep_screen.dart     77              72             -5     5           OK        not_run
```

## Final Report

```
AUTORESEARCH I18N — SESSION REPORT
Date: YYYY-MM-DD | Branch: feature/S{XX}-... | Budget: X/Y extractions

Hardcoded strings: N → M (delta: -K)
ARB keys (fr): A → B (+C)
Tests: PASS | gen-l10n: OK

EXPERIMENT LOG:
batch  file  before  after  delta  keys  gen_l10n  tests
1      ...

REMAINING: N strings in M files
Top: file1.dart (X), file2.dart (Y), ...
```

## Invocation

- `/autoresearch-i18n` — 30 extractions (default, 6 batches)
- `/autoresearch-i18n 40` — 8 batches
- `/autoresearch-i18n 100` — deep pass, 20 batches
