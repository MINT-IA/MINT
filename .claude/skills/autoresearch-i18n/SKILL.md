---
name: autoresearch-i18n
description: Autonomous autoresearch loop for i18n migration. Extracts hardcoded French strings from widgets/screens and migrates them to ARB files + AppLocalizations. Invoke with /autoresearch-i18n or /autoresearch-i18n 40.
compatibility: Requires Flutter SDK, git. Works in apps/mobile/.
allowed-tools: Bash(flutter:*) Bash(grep:*) Bash(git:*) Bash(wc:*) Bash(cd:*) Bash(tail:*) Bash(date:*) Bash(echo:*) Bash(cat:*)
metadata:
  author: mint-team
  version: "1.0"
---

# Autoresearch i18n — Autonomous string extraction loop

## Purpose

You are an **autonomous i18n migration agent**. You find ONE hardcoded French string, extract it to `app_fr.arb`, replace it with `AppLocalizations.of(context)!.key`, commit, verify, keep or revert. Repeat.

## Metric (single)

**Hardcoded FR strings in `lib/screens/` and `lib/widgets/`**

Primary detection command:
```bash
grep -rn "Text(\s*'" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v "AppLocalizations" | grep -v _test | grep -v "// " | grep -v "Text('\$" | grep -E "'[A-ZÀÂÉÈÊËÏÎÔÙÛÜŸÇ]" | wc -l
```

Broader detection (fallback):
```bash
grep -rn "'[A-ZÀÂÉÈÊËÏÎÔÙÛÜŸÇ][a-zàâéèêëïîôùûüÿç]" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v AppLocalizations | grep -v import | grep -v "// " | grep -v _test | grep -v "key:" | grep -v "route" | grep -v "assets/" | wc -l
```

## Loop (8 phases per iteration)

### Phase 1: BASELINE
Count hardcoded strings. On first iteration, create `autoresearch-i18n-results.tsv` with header:
```
iteration	timestamp	commit	file	arb_key	original_string	status	remaining
```

### Phase 2: FIND
Identify ONE hardcoded string (first match from grep).

### Phase 3: EXTRACT
a. Choose a camelCase ARB key name (e.g., `budgetScreenTitle`, `mortgageDisclaimer`)
b. Check for existing duplicate key: `grep <keyword> apps/mobile/lib/l10n/app_fr.arb`
c. Add key + FR value to `apps/mobile/lib/l10n/app_fr.arb` (at END, before closing `}`)
d. Replace the hardcoded string with `AppLocalizations.of(context)!.keyName`
e. Ensure the file imports `package:flutter_gen/gen_l10n/app_localizations.dart`

### Phase 4: COMMIT
```bash
git add <file.dart> apps/mobile/lib/l10n/app_fr.arb && git commit -m "autoresearch-i18n: extract '<key>' from <file>"
```

### Phase 5: VERIFY
```bash
cd apps/mobile && flutter analyze 2>&1 | tail -3
```
Must be 0 errors. Re-count hardcoded strings (must be baseline - 1 or less).

### Phase 6: DECIDE
- analyze clean AND count reduced → **KEEP**
- otherwise → `git revert HEAD --no-edit` → **DISCARD**

### Phase 7: LOG
Append to `autoresearch-i18n-results.tsv`:
```
iteration	timestamp	commit	file	arb_key	original_string	status	remaining
```

### Phase 8: REPEAT
Next iteration. Stop when max iterations reached or no strings left.

## Strict Rules

- **French accents are mandatory**: é, è, ê, ô, ù, ç, à — never write `impot`, `etre`, `prevoyance`
- **Non-breaking spaces** before `!`, `?`, `:`, `;`, `%` in FR strings (`\u00a0`)
- **DO NOT** touch technical strings (routes, asset paths, keys, enum values, SharedPreferences keys)
- **DO NOT** touch strings in test files
- **DO NOT** create duplicate ARB keys — always check existing keys first
- **ONE** file + `app_fr.arb` per iteration
- If `BuildContext` is not available in scope (e.g., service without context) → **SKIP** and move to next
- **Maximum 80 iterations** per session (override with argument)
- TSV file at project root: `autoresearch-i18n-results.tsv`

## SKIP Handling

Some strings cannot be migrated because `BuildContext` is unavailable (pure services, models, utils). Log these as SKIP:
```
3	2026-03-14T10:02:00	-	avs_service.dart	-	(no context)	SKIP	46
```
Do not attempt to refactor code to pass context — just skip.

## Invocation

The user types `/autoresearch-i18n` or `/autoresearch-i18n 40` (to limit iterations).

## Final Output

```
AUTORESEARCH-I18N SESSION SUMMARY
===================================
Iterations: X
Extracted: Y strings to ARB
Skipped: Z (no context / duplicate key)
Discarded: W (analyze failed)

BEFORE: N hardcoded strings
AFTER:  M hardcoded strings
DELTA:  -(N-M)

FILES MODIFIED:
  - screens/budget/budget_screen.dart (3 strings)
  - widgets/educational_insert.dart (2 strings)
  - ...
```
