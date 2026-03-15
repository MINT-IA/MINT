---
name: autoresearch-i18n
description: "Karpathy-style string extraction loop for i18n. Finds hardcoded French strings in screens/widgets, extracts to ARB files, verifies periodically. Use with /autoresearch-i18n or /autoresearch-i18n 40."
compatibility: Requires Flutter SDK
allowed-tools: Bash(flutter:*) Bash(grep:*) Bash(git:*) Read Edit Write Glob Grep
metadata:
  author: mint-team
  version: "2.0"
---

# Autoresearch i18n v2 — Karpathy-Style String Extraction Loop

## Philosophy

Autonomous agent that systematically extracts hardcoded French strings from Flutter screens and widgets into ARB files. Measures, extracts, verifies — repeats until budget is spent or all strings are extracted.

## Primary Metric

**Hardcoded French string count** in `lib/screens/` and `lib/widgets/`.

Detection command:

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile
grep -rn "Text(\s*'" lib/screens/ lib/widgets/ --include="*.dart" \
  | grep -v "Text(S\." \
  | grep -v "Text(widget\." \
  | grep -v "Text(state\." \
  | grep -v "Text(format" \
  | grep -v "Text(style" \
  | grep -v "// " \
  | grep -v "_test.dart" \
  | grep -v "archive/" \
  | wc -l
```

Also check for hardcoded strings in other patterns:

```bash
grep -rn "'[A-ZÀÂÉÈÊËÏÎÔÙÛÜÇ][a-zàâéèêëïîôùûüç]" lib/screens/ lib/widgets/ --include="*.dart" \
  | grep -v "SharedPreferences\|route\|key\|enum\|case\|'\$\|import\|// \|_test.dart\|archive/" \
  | grep -v "S\.of" \
  | head -30
```

### Guard Metrics
| Guard | Command | Threshold |
|-------|---------|-----------|
| Tests | `flutter test` | 0 failures (run every 10 extractions) |
| Analyze | `flutter analyze` | Must not increase errors |
| gen-l10n | `flutter gen-l10n` | Must succeed (no ARB syntax errors) |
| ARB parity | `wc -l lib/l10n/app_*.arb` | All 6 files within 5 lines of each other |

## Loop Structure

### Phase 0 — INVENTORY

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile

# Count hardcoded strings
grep -rn "Text(\s*'" lib/screens/ lib/widgets/ --include="*.dart" \
  | grep -v "Text(S\.\|Text(widget\.\|Text(state\.\|Text(format\|// \|_test.dart\|archive/" \
  | wc -l

# List files with most hardcoded strings
grep -rl "Text(\s*'" lib/screens/ lib/widgets/ --include="*.dart" \
  | grep -v "_test.dart\|archive/" \
  | xargs -I{} sh -c 'echo "$(grep -c "Text('" '"'"'" {} 2>/dev/null) {}"' \
  | sort -rn | head -20
```

### Phase 1 — BASELINE

```
BASELINE: YYYY-MM-DD HH:MM
  hardcoded_strings: N
  arb_keys_fr: M (grep -c '"' lib/l10n/app_fr.arb)
  budget_total: B (from user arg, default 30)
  budget_spent: 0
```

### Phase 2 — EXTRACT BATCH (5 strings per batch)

For each batch, pick one file (the one with the most hardcoded strings). Extract up to 5 strings from that file.

**Extraction steps for each string**:

1. **Read the file** to understand the context
2. **Choose a key name**: `camelCase`, descriptive, prefixed by screen/widget name
   - Example: `budgetScreenTitle`, `retirementProjectionDisclaimer`
3. **Check for existing key** in `app_fr.arb` (avoid duplicates!)
   ```bash
   grep -i "searchTerm" apps/mobile/lib/l10n/app_fr.arb
   ```
4. **Add the key to ALL 6 ARB files** (fr, en, de, es, it, pt):
   - `app_fr.arb`: French text (with proper accents and NBSP)
   - `app_en.arb`: English translation
   - `app_de.arb`: German translation
   - `app_es.arb`: Spanish translation
   - `app_it.arb`: Italian translation
   - `app_pt.arb`: Portuguese translation
   - Add keys at END of each file (before closing `}`)
5. **Handle placeholders** if the string contains variables:
   ```json
   "budgetRemaining": "Il te reste {amount} CHF",
   "@budgetRemaining": {
     "placeholders": {
       "amount": { "type": "String" }
     }
   }
   ```
6. **Replace the hardcoded string** in the Dart file:
   - Add import if missing: `import 'package:mint_mobile/l10n/app_localizations.dart';`
   - Replace `Text('Texte en dur')` with `Text(S.of(context)!.keyName)`

### Phase 3 — VERIFY

After each batch of 5 extractions:

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile

# Verify ARB syntax
flutter gen-l10n 2>&1

# Verify analyze
flutter analyze 2>&1 | tail -5

# Count remaining hardcoded strings
grep -rn "Text(\s*'" lib/screens/ lib/widgets/ --include="*.dart" \
  | grep -v "Text(S\.\|Text(widget\.\|Text(state\.\|Text(format\|// \|_test.dart\|archive/" \
  | wc -l
```

Every 2 batches (10 extractions), also run:

```bash
flutter test 2>&1 | tail -10
```

### Phase 4 — LOG

Track progress in TSV format (see below).

### Phase 5 — REPEAT

Go back to Phase 2 until:
- Budget exhausted
- 0 hardcoded strings remaining
- 3 consecutive batches with 0 new extractions possible (plateau)

## Strict Rules

1. **French accents are MANDATORY.** Never write `impot`, `etre`, `prevoyance`, `retraite` without proper accents (`impot` -> `imp\u00f4t`, `etre` -> `\u00eatre`, etc.). This is a bug, not a style choice.
2. **NBSP before double punctuation.** In French ARB strings, use `\u00a0` before `!`, `?`, `:`, `;`, `%`. Example: `"montant\u00a0: {amount}\u00a0CHF"`.
3. **No duplicate keys.** Always search existing ARB keys before adding a new one. Reuse if the same string already exists.
4. **ALL 6 ARB files must be updated.** Never add a key to just `app_fr.arb`. Add to all 6 languages in the same batch.
5. **Keys at END of file.** Add new keys before the closing `}` to minimize merge conflicts.
6. **Do NOT i18n**: variable names, route paths, enum values, SharedPreferences keys, analytics event names, debug-only strings.
7. **Do NOT extract strings inside `print()` or `debugPrint()`.** Those are dev-only.
8. **Preserve formatting.** If the original uses `\n` or string interpolation, handle it properly in the ARB.
9. **Run `flutter gen-l10n` after every batch.** If it fails, fix the ARB syntax error before continuing.
10. **If tests break, fix immediately** before continuing the extraction loop.

## Key Name Convention

```
{screenOrWidgetName}{ElementDescription}
```

Examples:
- `budgetScreenTitle` — title of budget screen
- `retirementDisclaimer` — disclaimer on retirement screen
- `lppDeepBuybackLabel` — label for buyback in LPP deep screen
- `coachGreetingMorning` — morning greeting in coach
- `wizardStressCheckOption1` — first option in stress check question

For strings with placeholders:
- `budgetRemainingAmount` — "Il te reste {amount} CHF"
- `lppProjectionAt` — "Projection a {age} ans"

## TSV Session Log Format

```
batch	timestamp	strings_before	strings_after	delta	file_processed	keys_added	gen_l10n	tests
1	HH:MM	87	82	-5	budget_screen.dart	5	OK	not_run
2	HH:MM	82	77	-5	retirement_screen.dart	5	OK	PASS
3	HH:MM	77	72	-5	lpp_deep_screen.dart	5	OK	not_run
```

## Final Output

```
## Autoresearch i18n — Session Report

**Date**: YYYY-MM-DD
**Branch**: feature/S{XX}-...
**Budget**: X extractions used / Y total

### Results
| Metric | Before | After | Delta |
|--------|--------|-------|-------|
| Hardcoded FR strings | N | M | -K |
| ARB keys (fr) | A | B | +C |
| Tests | PASS | PASS | 0 |
| gen-l10n | OK | OK | 0 |

### Files Processed
| File | Strings extracted | Keys added |
|------|-------------------|------------|
| budget_screen.dart | 5 | 5 |
| retirement_screen.dart | 5 | 3 (2 reused) |

### Batches
batch	strings_before	strings_after	delta	file
1	...
2	...

### Remaining Hardcoded Strings (budget exhausted)
- N strings remaining in M files
- Top files: file1.dart (X), file2.dart (Y), ...
```

## Invocation

- `/autoresearch-i18n` — run with default budget of 30 extractions
- `/autoresearch-i18n 40` — run with budget of 40 extractions
- `/autoresearch-i18n 100` — run with budget of 100 extractions

The number is the maximum number of individual string extractions. Each batch = 5 extractions. So budget 40 = max 8 batches.
