---
name: autoresearch-navigation
description: "Autonomous navigation auditor & fixer. Detects orphan screens, Navigator.push violations, missing life-event routes, route inconsistencies, dead ends, missing guards. Fixes ONE issue per iteration. Use with /autoresearch-navigation or /autoresearch-navigation 30."
compatibility: Requires Flutter SDK + GoRouter
metadata:
  author: mint-team
  version: "1.0"
---

# Autoresearch Navigation v1 — Karpathy Navigation Auditor & Fixer

> "Every screen must be reachable. Every route must lead somewhere. Every life event must have a home."

## Philosophy (Karpathy autoresearch pattern)

Like Karpathy's autoresearch: 1 mutable target, 1 metric, fixed time budget, autonomous loop.
The agent modifies ONE navigation element per iteration, measures the gap count, keeps if improved, discards if regressed.

## Constraints (NON-NEGOTIABLE)

- **Single metric**: `navigation_gap_count` (lower = better). Measured by detection commands.
- **Time budget**: 5 min per issue. If fix causes cascading issues -> revert -> skip.
- **Single target**: ONE issue per iteration. Fix -> verify -> commit -> next.
- **Guard**: `flutter analyze` (0 new errors) + `flutter test` (no regressions).
- **Scope**: navigation structure ONLY. Never change business logic, UI design, or add features.

## Violation Types (7 categories, all automatable)

| # | Check | Detection | Severity | Fix Strategy |
|---|-------|-----------|----------|-------------|
| V1 | **Navigator.push** (screen-to-screen) | `grep -rn "Navigator\.of.*\.push\|Navigator\.push" lib/screens/ lib/widgets/` | HIGH | Add GoRouter route + replace with `context.push('/route', extra: data)` |
| V2 | **Orphan screens** (no GoRouter route) | Script: compare `find lib/screens -name "*_screen.dart"` vs `grep GoRoute lib/app.dart` | HIGH | Either add route in `app.dart` or delete dead screen file |
| V3 | **Missing life-event routes** | Script: compare `LifeEventType` enum values vs GoRouter paths in `app.dart` | CRITICAL | Create screen + route for uncovered life event |
| V4 | **Raw Material colors** (Colors.*) | `grep -rn "Colors\." lib/widgets/ lib/screens/ \| grep -v MintColors` | HIGH | Replace with closest `MintColors.*` from `lib/theme/colors.dart` |
| V5 | **Placeholder/dead-end routes** | `grep -rn "coming soon\|TODO.*route\|Placeholder.*Screen" lib/screens/` | MEDIUM | Implement minimal screen or remove route + add redirect |
| V6 | **Route prefix inconsistency** | Manual: audit route trees for FR/EN mixing within same feature | MEDIUM | Standardize to FR canonical + EN legacy redirect |
| V7 | **Missing feature-flag guards** | `grep -rn "FeatureFlags" lib/app.dart` vs routes that should be gated | LOW | Add `redirect:` guard that returns `/home` when flag is off |

## Detection Commands

```bash
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile

# V1 — Navigator.push (screen-to-screen, TRUE violations)
grep -rn "Navigator\.of.*\.push\|Navigator\.push" lib/screens/ lib/widgets/ | wc -l

# V2 — Orphan screens (no route)
for f in $(find lib/screens -name "*_screen.dart" | sed 's|.*/||' | sed 's/_screen\.dart//' | sort); do
  grep -qi "$f" lib/app.dart 2>/dev/null || echo "ORPHAN: $f"
done

# V3 — Missing life-event routes (enum vs routes)
# LifeEventType enum: marriage, divorce, birth, concubinage, deathOfRelative,
#   firstJob, newJob, selfEmployment, jobLoss, retirement,
#   housingPurchase, housingSale, inheritance, donation,
#   disability, cantonMove, countryMove, debtCrisis
# Expected route mapping:
#   marriage -> /mariage | divorce -> /divorce | birth -> /naissance
#   concubinage -> /concubinage | deathOfRelative -> /life-event/deces-proche
#   firstJob -> /first-job | newJob -> /simulator/job-comparison
#   selfEmployment -> /segments/independant | jobLoss -> /unemployment
#   retirement -> /retraite | housingPurchase -> /hypotheque
#   housingSale -> /life-event/housing-sale | inheritance -> /succession
#   donation -> /life-event/donation | disability -> /invalidite
#   cantonMove -> /life-event/demenagement-cantonal | countryMove -> /expatriation
#   debtCrisis -> /check/debt
# Check each route exists in app.dart

# V4 — Raw Material colors
grep -rn "Colors\." lib/widgets/ lib/screens/ | grep -v MintColors | grep -v "// " | wc -l

# V5 — Placeholder screens
grep -rln "coming soon\|TODO.*implement\|Placeholder.*Screen" lib/screens/

# COMPOSITE METRIC
echo "NAV_GAP_COUNT = V1 + V2 + V3 + V4 + V5"
```

## Life Event -> Route Mapping (REFERENCE — immutable)

This is the CANONICAL mapping. Any life event without a corresponding route is a V3 violation.

```
LifeEventType.marriage         -> /mariage
LifeEventType.divorce          -> /divorce
LifeEventType.birth            -> /naissance
LifeEventType.concubinage      -> /concubinage
LifeEventType.deathOfRelative  -> /life-event/deces-proche        ← MUST EXIST
LifeEventType.firstJob         -> /first-job
LifeEventType.newJob           -> /simulator/job-comparison
LifeEventType.selfEmployment   -> /segments/independant
LifeEventType.jobLoss          -> /unemployment
LifeEventType.retirement       -> /retraite
LifeEventType.housingPurchase  -> /hypotheque
LifeEventType.housingSale      -> /life-event/housing-sale
LifeEventType.inheritance      -> /succession
LifeEventType.donation         -> /life-event/donation
LifeEventType.disability       -> /invalidite
LifeEventType.cantonMove       -> /life-event/demenagement-cantonal  ← MUST EXIST
LifeEventType.countryMove      -> /expatriation
LifeEventType.debtCrisis       -> /check/debt
```

## Mutable / Immutable

| Mutable (ONE per iteration) | Immutable (read-only reference) |
|-----------------------------|--------------------------------|
| `lib/app.dart` (add routes, guards, redirects) | `lib/models/age_band_policy.dart` (LifeEventType enum) |
| `lib/screens/**/*.dart` (fix Navigator.push) | `lib/theme/colors.dart` (read for MintColors mapping) |
| `lib/widgets/**/*.dart` (fix Navigator.push, Colors) | `lib/services/**/*.dart` (business logic) |
| NEW screen files (for missing life events) | `test/**/*_test.dart` (tests = spec) |

## The Loop

```
┌─ INVENTORY: Run ALL detection commands. Compute navigation_gap_count.
│  List violations by severity: CRITICAL > HIGH > MEDIUM > LOW.
│
├─ SELECT: Highest-severity violation. Read relevant files fully.
│  V1: Read source file + app.dart (existing routes)
│  V2: Read orphan screen + app.dart (is it truly unused?)
│  V3: Read life event mapping + app.dart (which events are missing?)
│  V4: Read source file + colors.dart (find closest MintColors match)
│
├─ FIX (<=4 min): Apply minimal fix.
│
│  V1 (Navigator.push):
│    1. Check if target screen has GoRouter route
│    2. If NO route: add GoRoute in app.dart with path + builder
│    3. Replace Navigator.of(context).push(MaterialPageRoute(...))
│       with context.push('/route', extra: data)
│    4. Add go_router import if missing
│    ⚠ NEVER replace Navigator.of(ctx).pop() inside showDialog/showModalBottomSheet
│      — those are LEGITIMATE dialog dismissals
│
│  V2 (Orphan screen):
│    1. Check if screen is imported/used anywhere
│    2. If used via Navigator.push → fix as V1 (add route)
│    3. If truly dead code → delete file
│    4. If replaced by another screen → verify redirect exists
│
│  V3 (Missing life-event route):
│    1. Create minimal screen file in lib/screens/life_events/
│    2. Follow existing life-event screen pattern (e.g., divorce_simulator_screen.dart)
│    3. Add GoRoute in app.dart at the correct location
│    4. Add i18n keys to ALL 6 ARB files
│    5. Wire response card in response_card_service.dart
│    ⚠ Screen must include: disclaimer, sources, chiffre_choc pattern
│    ⚠ NEVER hardcode French strings — use S.of(context)!.key
│
│  V4 (Raw Material colors):
│    1. Read lib/theme/colors.dart for palette
│    2. Map Colors.X to closest MintColors.Y:
│       Colors.white -> MintColors.white | Colors.black -> MintColors.black
│       Colors.transparent -> MintColors.transparent
│       Colors.blue -> MintColors.info | Colors.red -> MintColors.error
│       Colors.green -> MintColors.success | Colors.orange -> MintColors.warning
│       Colors.grey -> MintColors.textMuted | Colors.grey[300] -> MintColors.border
│       Colors.grey[100] -> MintColors.surface
│       Colors.white.withOpacity(0.7) -> MintColors.white70
│       Colors.black.withOpacity(0.54) -> MintColors.black54
│    3. For Colors with opacity (.withOpacity) → check if MintColors has pre-defined variant
│
│  V5 (Placeholder):
│    1. If placeholder has real content elsewhere → redirect route to canonical screen
│    2. If placeholder is future feature → add feature flag guard
│    3. Remove "coming soon" text from any production route
│
├─ VERIFY (<=1 min):
│  flutter analyze 2>&1 | tail -10
│  flutter test 2>&1 | tail -5
│  Re-run detection commands for fixed category → confirm count decreased
│  Regression → revert immediately: git checkout -- <files>
│
├─ LOG: Append to experiment log
│
├─ COMMIT: git add <specific files> && git commit -m "nav: fix <category> — <description>"
│
└─ REPEAT until: budget exhausted | CRITICAL+HIGH violations = 0
    Every 5 fixes → full verification (analyze + test + all detection commands)
```

## Navigator.pop — SAFE LIST (do NOT fix these)

`Navigator.of(ctx).pop()` inside these patterns is CORRECT and must be preserved:

```dart
showDialog(
  builder: (ctx) => ... Navigator.of(ctx).pop() ...  // ← KEEP
)

showModalBottomSheet(
  builder: (ctx) => ... Navigator.of(ctx).pop() ...  // ← KEEP
)

showCupertinoDialog(
  builder: (ctx) => ... Navigator.of(ctx).pop() ...  // ← KEEP
)
```

These dismiss dialogs/modals, NOT navigate between screens. GoRouter does not manage dialogs.

## Route Naming Convention (for new routes)

| Pattern | Example | Rule |
|---------|---------|------|
| Life events | `/life-event/deces-proche` | `/life-event/<slug-fr>` |
| Simulators | `/simulator/compound` | `/simulator/<slug-en>` |
| Feature modules | `/hypotheque`, `/retraite` | French canonical name |
| Sub-features | `/mortgage/amortization` | English sub-path OK |
| Profile sub | `/profile/byok` | `/profile/<slug>` |
| Segments | `/segments/independant` | `/segments/<slug-fr>` |

**New routes**: Always add legacy redirect for old path if one existed.

## Screen Template (for V3 — new life-event screens)

```dart
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/mint_ui_kit.dart';

class NewLifeEventScreen extends StatelessWidget {
  const NewLifeEventScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(s.screenTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero chiffre choc
              // Educational content
              // Action cards
              // Disclaimer
              MintDisclaimer(), // required compliance widget
            ],
          ),
        ),
      ),
    );
  }
}
```

## Rules

- **NEVER change business logic** — only navigation structure
- **NEVER remove functionality** — preserve all behavior
- **NEVER delete a screen** without verifying it's truly unused (grep for imports)
- **NEVER replace Navigator.pop inside dialogs** — see Safe List above
- **NEVER create routes without i18n** — all strings in 6 ARB files
- **NEVER fix >1 issue without verifying** between fixes
- **ALWAYS add legacy redirects** when renaming a route path
- **ALWAYS include disclaimer widget** in new screens (compliance)
- **Defer bulk i18n** to `/autoresearch-i18n` if >10 strings needed
- **Defer bulk Colors fixes** to `/autoresearch-ux-polish` if >5 files affected

## Verification Gate (IRON LAW)

**NO COMPLETION CLAIMS WITHOUT FRESH VERIFICATION EVIDENCE.**

After EVERY navigation fix, before reporting it as done:

1. **RUN** `flutter analyze 2>&1 | tail -10` AND `flutter test 2>&1 | tail -10` fresh.
2. **RUN** the detection command for the fixed category. Confirm count decreased.
3. **PASTE** all three outputs in your experiment log. "Should pass" is FORBIDDEN.
4. If count did NOT decrease → the fix is incomplete or wrong. Investigate.

| Rationalization | Response |
|----------------|----------|
| "Should work now" | RUN IT. Paste output. |
| "I'm confident it passes" | Confidence is not evidence. Run the test. |
| "I already tested earlier" | Code changed since then. Test AGAIN. |
| "It's a trivial change" | Trivial changes break production. Verify. |
| "Navigator.push works fine here" | GoRouter is the rule. No exceptions except dialogs (see Safe List). |
| "This screen is rarely used" | Every screen must be properly routed. Frequency is irrelevant. |

**If verification FAILS:** Do NOT commit. Revert: `git checkout -- <files>`. If fix caused cascading issues → revert ALL and skip this issue. Return to the Loop.

Claiming work is complete without verification is dishonesty, not efficiency.

## Experiment Log (append-only)

```
iteration  category  target                        gaps_before  gaps_after  delta  status
1          V3        deathOfRelative screen         61           60          -1     keep
2          V3        cantonMove screen              60           59          -1     keep
3          V1        document_scan_screen.dart      59           56          -3     keep
4          V2        succession_simulator_screen    56           55          -1     keep (deleted dead file)
5          V4        mentor_fab.dart                55           53          -2     keep
```

## Final Report

```
AUTORESEARCH NAVIGATION — SESSION REPORT
Date: YYYY-MM-DD | Branch: feature/S{XX}-... | Budget: X/Y iterations

Navigation gaps: G1 -> G2 (delta: -D)
  V1 Navigator.push:     N fixed
  V2 Orphan screens:     N fixed
  V3 Missing life events: N created
  V4 Raw Material colors: N fixed (or deferred to ux-polish)
  V5 Placeholders:        N fixed
  V6 Route inconsistency: N fixed
  V7 Missing guards:      N added

EXPERIMENT LOG:
iter  category  target  before  after  delta  status
1     ...

SKIPPED: [issues with cascading risks]
REMAINING: CRITICAL=N, HIGH=N, MEDIUM=M, LOW=L

LIFE EVENT COVERAGE: X/18 events have dedicated routes
ROUTE HEALTH: Y canonical routes, Z legacy redirects, W orphan screens
```

## Invocation

- `/autoresearch-navigation` — 15 iterations (default)
- `/autoresearch-navigation 30` — deep pass
- `/autoresearch-navigation 50` — exhaustive audit + fix
