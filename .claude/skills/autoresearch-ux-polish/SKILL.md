---
name: autoresearch-ux-polish
description: "Autonomous UX refinement agent. Scans widgets for violations of MINT's 7 UX laws (L1-L7), fixes programmatically. Use with /autoresearch-ux-polish or /autoresearch-ux-polish 30."
compatibility: Requires Flutter SDK
allowed-tools: Bash(flutter:*) Bash(dart:*) Bash(git:*) Read Edit Write Glob Grep
metadata:
  author: mint-team
  version: "1.0"
---

# Autoresearch UX Polish v1 — Autonomous UX Refinement Agent

## Philosophy

> "Every pixel, every word, every interaction must respect the 7 laws. Violations are bugs."

Karpathy-style loop: scan for violations → pick file with most → fix programmatically → verify with `flutter analyze` + `flutter test` → commit if clean, revert if regression → repeat.

**Primary metric**: `ux_violations_count` (target: 0)
**Guard metric**: `flutter analyze` (0 errors) + `flutter test` (no regressions)

## Mutable Target

- `lib/widgets/**/*.dart` — reusable widgets
- `lib/screens/**/*.dart` — screen files

## Immutable Harness

- `docs/UX_WIDGET_REDESIGN_MASTERPLAN.md` — the 7 UX laws (L1-L7)
- `flutter analyze` — static analysis
- `flutter test` — regression guard
- `lib/theme/colors.dart` — MintColors palette (source of truth for colors)

## The 7 UX Laws of MINT

| Law | Name | Rule | Violation signature |
|-----|------|------|---------------------|
| L1 | CHF/mois en premier | Hero number = monthly CHF amount, not abstract concept | Screen with projection but no prominent CHF/mois |
| L2 | Avant/Apres visible | Show impact of action (before vs after) | Simulation without before/after comparison |
| L3 | 3 niveaux max | Never nest deeper than 3 widget levels | Widget tree with >3 levels of custom nesting |
| L4 | Raconte, ne montre pas | Narrative > data table | Raw data table without narrative explanation |
| L5 | Une action | 1 screen = 1 primary CTA | Screen with 2+ equally prominent action buttons |
| L6 | Chiffre-choc | 1 impactful number per screen | Screen without a chiffre-choc highlight |
| L7 | Metaphore > graphique | Use visual metaphors over abstract charts | Complex chart without metaphorical context |

## Programmatic Checks (automatable)

### Check 1: Hardcoded hex colors
```
Pattern: Color(0xFF
Should be: MintColors.*
Severity: HIGH
```

### Check 2: Missing disclaimers
```
Pattern: Screen with projection/calculation output but no DisclaimerWidget or disclaimer text
Severity: MEDIUM
```

### Check 3: Navigator.push usage
```
Pattern: Navigator.push( or Navigator.of(context).push(
Should be: context.go( or context.push( (GoRouter)
Severity: HIGH
```

### Check 4: Missing i18n
```
Pattern: Text('hardcoded French string') without S.of(context)!
Severity: HIGH (but defer to /autoresearch-i18n for bulk migration)
```

### Check 5: Deep nesting
```
Pattern: Widget build() method with >3 levels of custom widget nesting
Severity: MEDIUM — extract sub-widgets
```

### Check 6: Missing Semantics
```
Pattern: Interactive widget (GestureDetector, InkWell, IconButton) without Semantics label
Severity: MEDIUM — accessibility
```

### Check 7: Missing MintColors usage
```
Pattern: Colors.blue, Colors.red, etc. (raw Material colors)
Should be: MintColors.* from theme
Severity: HIGH
```

### Check 8: StatefulWidget for shared state
```
Pattern: StatefulWidget managing data that should be in Provider
Severity: LOW — refactor candidate
```

## Loop Structure

### Phase 0 — INVENTORY

Scan all widgets and screens, count violations per type:

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile

# Check 1: Hardcoded colors
grep -rn "Color(0x" lib/widgets/ lib/screens/ | wc -l

# Check 3: Navigator.push
grep -rn "Navigator.push\|Navigator.of" lib/widgets/ lib/screens/ | wc -l

# Check 7: Raw Material colors
grep -rn "Colors\." lib/widgets/ lib/screens/ | grep -v "MintColors" | wc -l

# Check 6: Missing Semantics on interactive widgets
grep -rn "GestureDetector\|InkWell" lib/widgets/ lib/screens/ | wc -l
# vs
grep -rn "Semantics" lib/widgets/ lib/screens/ | wc -l
```

Build violation inventory:
```
BASELINE: YYYY-MM-DD HH:MM
  hardcoded_colors: N files, M instances
  navigator_push: N files, M instances
  raw_material_colors: N files, M instances
  missing_semantics: ~N (estimated)
  total_violations: V
  budget: B (from arg, default 15)
```

### Phase 1 — SELECT

Pick the file with the most violations. Within a file, fix by severity: HIGH > MEDIUM > LOW.

### Phase 2 — FIX

Apply fixes programmatically:

**Color(0xFF...) → MintColors.***:
1. Read the file
2. Identify each hardcoded color
3. Find the closest MintColors.* match (read `lib/theme/colors.dart`)
4. Replace

**Navigator.push → GoRouter**:
1. Read the file
2. Identify the push call and its route
3. Replace with `context.go('/route')` or `context.push('/route')`
4. Add GoRouter import if missing

**Raw Material Colors → MintColors**:
1. `Colors.blue` → `MintColors.primary` (or closest match)
2. `Colors.red` → `MintColors.error`
3. `Colors.grey` → `MintColors.textSecondary`
4. Always check `lib/theme/colors.dart` for the correct mapping

**Missing Semantics**:
1. Wrap interactive widget with `Semantics(label: '...', child: widget)`
2. Use descriptive label from context

### Phase 3 — VERIFY

After each file fix:
```bash
flutter analyze lib/path/to/fixed_file.dart 2>&1 | tail -5
flutter test 2>&1 | tail -5
```

### Phase 4 — COMMIT or REVERT

| Result | Action |
|--------|--------|
| analyze clean + tests pass | Commit |
| analyze error | Fix the error, re-verify |
| test regression | **Revert immediately**, investigate |
| test unrelated failure | Commit (pre-existing issue) |

```bash
git add lib/path/to/fixed_file.dart
git commit -m "ux: fix N violations in <file> (hardcoded colors, Navigator.push)

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

### Phase 5 — REPEAT or STOP

Continue until:
- **Budget exhausted** (files_fixed >= budget)
- **All HIGH violations fixed** (0 hardcoded colors, 0 Navigator.push, 0 raw Material colors)
- **Stuck** — fix causes cascading issues after 2 attempts → skip file

Every 5 files, run full verification:
```bash
flutter analyze 2>&1 | tail -5
flutter test 2>&1 | tail -5
```

## Strict Rules

1. **NEVER change business logic while fixing UX** — only visual/structural changes
2. **NEVER remove functionality** — a fix must preserve all existing behavior
3. **NEVER add new features** — this skill is about fixing violations, not adding capabilities
4. **Always verify with `flutter analyze` after every fix** — no new analysis issues
5. **Always verify with `flutter test` after every fix** — no regressions
6. **Read `lib/theme/colors.dart` before replacing colors** — use exact MintColors.* names
7. **Read GoRouter routes before replacing Navigator** — use correct route paths
8. **Defer bulk i18n to `/autoresearch-i18n`** — only flag i18n violations, don't fix them here

## Anti-patterns (never do)

- **NEVER** replace a color with a "guess" — always check MintColors palette first
- **NEVER** remove a widget to fix nesting depth — extract to a named sub-widget instead
- **NEVER** add `// ignore:` to suppress real lint warnings
- **NEVER** change text content (that's i18n or content work, not UX polish)
- **NEVER** modify test files — this skill only touches `lib/`
- **NEVER** fix more than one file without verifying between fixes

## Final Output

```
AUTORESEARCH UX POLISH — SESSION REPORT
=========================================
Date: YYYY-MM-DD
Branch: feature/S{XX}-...
Budget: X/Y files fixed
Duration: ~Nm

RESULTS:
  Violations: before=V → after=W (-D fixed)
  flutter analyze: before=I issues → after=J issues
  flutter test: no regressions

VIOLATIONS FIXED:
  By type:
    Hardcoded colors:      N fixed across M files
    Navigator.push:        N fixed across M files
    Raw Material colors:   N fixed across M files
    Missing Semantics:     N added across M files

  By file:
    1. spending_meter.dart — 3 hardcoded colors → MintColors (HIGH)
    2. budget_report_section.dart — 2 Navigator.push → GoRouter (HIGH)
    3. early_retirement_slider.dart — 1 Colors.grey → MintColors.textSecondary (HIGH)
    ...

SKIPPED (could not fix safely):
  - coach_chat_screen.dart — Navigator.push with complex callback, needs manual review

VIOLATIONS REMAINING:
  HIGH: N (list files)
  MEDIUM: M (list files)
  LOW: L (list files)

L1-L7 LAW VIOLATIONS (manual review needed):
  - L5: retirement_dashboard.dart has 3 CTAs (reduce to 1)
  - L6: tax_simulator_screen.dart missing chiffre-choc
```

## Invocation

- `/autoresearch-ux-polish` — default budget 15 files
- `/autoresearch-ux-polish 30` — deep pass, 30 files max
