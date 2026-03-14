---
name: autoresearch-i18n
description: Autonomous autoresearch loop for i18n migration. Scan once, batch extract hardcoded FR strings to ARB + AppLocalizations, verify periodically. Invoke with /autoresearch-i18n or /autoresearch-i18n 40.
compatibility: Requires Flutter SDK, git. Works in apps/mobile/.
metadata:
  author: mint-team
  version: "2.0"
---

# Autoresearch i18n v2 — Karpathy-style string extraction loop

## Philosophy

> Scan once, work the queue, verify periodically.

1. **Inventory first** — find ALL hardcoded strings upfront, build a ranked work queue
2. **Batch by file** — extract all strings from ONE file before moving to the next (fewer context switches)
3. **Verify every 3 extractions** — `flutter analyze` after 3 commits, not after every one
4. **Skip early, don't waste time** — if a string has no `BuildContext` in scope, skip immediately and move on

## Primary Metric

**Hardcoded FR strings count** — this is the loss function.

```bash
# Primary scan (Text widgets with FR strings)
grep -rn "Text(\s*'" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v "AppLocalizations" | grep -v _test | grep -v "// " | grep -v "Text('\$" | grep -E "'[A-ZÀÂÉÈÊËÏÎÔÙÛÜŸÇ]" | wc -l

# Broader scan (any FR string in code)
grep -rn "'[A-ZÀÂÉÈÊËÏÎÔÙÛÜŸÇ][a-zàâéèêëïîôùûüÿç]" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v AppLocalizations | grep -v import | grep -v "// " | grep -v _test | grep -v "key:" | grep -v "route" | grep -v "assets/" | wc -l
```

## Loop Structure

### Phase 0: INVENTORY (run ONCE)

```bash
# List all files with hardcoded strings, sorted by count (most first)
grep -rn "'[A-ZÀÂÉÈÊËÏÎÔÙÛÜŸÇ][a-zàâéèêëïîôùûüÿç]" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v AppLocalizations | grep -v import | grep -v "// " | grep -v _test | grep -v "key:" | grep -v "route" | grep -v "assets/" | cut -d: -f1 | sort | uniq -c | sort -rn
```

Build work queue: `[(file, count), ...]` sorted by count descending.

For each file, pre-check:
- Does the file have `BuildContext` available? (screens/widgets = yes, services = skip)
- Load existing ARB keys: `grep -c "\"" apps/mobile/lib/l10n/app_fr.arb` to know current key count

### Phase 1: BASELINE
Count total hardcoded strings. Create `autoresearch-i18n-results.tsv`:
```
iteration	timestamp	commit	file	arb_key	original_string	status	remaining
```

### Phase 2: EXTRACT BATCH (per file)

For each file in the work queue:
1. Read the file, identify ALL hardcoded FR strings
2. For each string:
   a. Check for existing duplicate key: `grep <keyword> apps/mobile/lib/l10n/app_fr.arb`
   b. If duplicate exists → reuse the key, don't create new one
   c. Choose a camelCase ARB key (e.g., `budgetScreenTitle`)
   d. Add to `app_fr.arb` (at END, before `}`)
   e. Replace with `AppLocalizations.of(context)!.keyName`
   f. Ensure import exists
3. After all strings in one file: `git add <file> apps/mobile/lib/l10n/app_fr.arb && git commit -m "autoresearch-i18n: extract N strings from <file>"`

**One commit per file** (not per string) — faster, still revertable per file.

### Phase 3: VERIFY (every 3 files)

```bash
cd apps/mobile && flutter analyze 2>&1 | tail -3
```

- Clean → **KEEP ALL**
- Errors → **bisect**: revert last file commit, re-check. Isolate the problem file.

### Phase 4: LOG
After each verify, append batch summary to TSV.

### Phase 5: REPEAT or STOP

Stop when:
- **Time limit**: 20 minutes
- **Iteration limit**: max reached (default 80)
- **No more strings**: all files processed
- **Only service files remain**: no `BuildContext` available → stop and report

## Strict Rules

- **French accents mandatory**: é, è, ê, ô, ù, ç, à
- **Non-breaking spaces** before `!`, `?`, `:`, `;`, `%` (`\u00a0`)
- **DO NOT** touch technical strings (routes, asset paths, keys, enum values)
- **DO NOT** touch test files
- **DO NOT** create duplicate ARB keys — always check first
- **SKIP** files where `BuildContext` is unavailable (services, models, utils)
- **One commit per file** (batch all string extractions from the same file)
- All git commands from project root

## Invocation

`/autoresearch-i18n` — default 80 iterations, 20 min
`/autoresearch-i18n 40` — limit to 40

## Final Output

```
AUTORESEARCH-I18N SESSION SUMMARY
===================================
Files processed: X
Strings extracted: Y
Keys reused: R (existing ARB keys)
Skipped: Z (no context / service files)
Discarded: W (analyze failed)
Duration: Xm Ys
Throughput: Z strings/min

BEFORE: N hardcoded strings
AFTER:  M hardcoded strings
DELTA:  -(N-M)

FILES MODIFIED:
  - screens/budget/budget_screen.dart (3 strings)
  - widgets/educational_insert.dart (2 strings)
  - ...

REMAINING (no BuildContext — manual migration needed):
  - services/xyz_service.dart (5 strings)
  - ...
```
