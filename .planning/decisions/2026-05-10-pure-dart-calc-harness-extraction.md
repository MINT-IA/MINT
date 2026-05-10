---
description: Concrete closure plan for the Flutter-cascade tech debt in apps/mobile/lib/constants/social_insurance.dart that prevents `dart compile exe` of the calc_harness binary. Surgical extraction (~3-4 h), not a refactor.
date: 2026-05-10
status: Proposed (awaiting Julien scheduling decision)
phase_hint: 92.7 candidate (post-MVP-GOOGLEFONTS-PURGE-V1, pre-Phase-93)
authority: Product Leader Claude (reply to Julien question « qu'est-ce qu'il faut pour la fermer? »)
---

# Pure-Dart calc-harness extraction — closure plan

## Question

Julien 2026-05-10 — « Pour ce qui est de la dette technique ouverte, qu'est-ce qu'il faut pour la fermer? »

The « dette technique ouverte » referenced is the cascade-Flutter limitation documented in :
- [`apps/mobile/tools/calc_harness/main.dart:19`](apps/mobile/tools/calc_harness/main.dart#L19) — `TODO(92.5-04 CI)`
- [`.planning/phases/92.5-mvp-calc-rigor-foundations/92.5-01-SUMMARY.md`](.planning/phases/92.5-mvp-calc-rigor-foundations/92.5-01-SUMMARY.md)
- [`.planning/phases/92.5-mvp-calc-rigor-foundations/92.5-04-G6-CLOSE-OUT.md`](.planning/phases/92.5-mvp-calc-rigor-foundations/92.5-04-G6-CLOSE-OUT.md)

## Current state

`apps/mobile/lib/services/financial_core/` (the canonical Dart calculator suite) imports `apps/mobile/lib/constants/social_insurance.dart` for federal/cantonal constants. That file imports :
- `package:flutter/foundation.dart` (used at lines 13, 33–34, 43 for `kDebugMode`, `debugPrint`, `@visibleForTesting`)
- `package:mint_mobile/services/regulatory_sync_service.dart` (used at line 14, 29 — the `reg(key, fallback)` runtime override that reads from a `SharedPreferences`-backed cache)

`regulatory_sync_service.dart` imports `package:flutter/foundation.dart` + `package:shared_preferences`.

Because of this transitive dependency, `dart compile exe apps/mobile/tools/calc_harness/main.dart -o build/calc_harness_dart` fails at compile-time : the harness pulls in Flutter framework code that isn't available outside the Flutter engine.

The `.github/workflows/calc-rigor.yml` differential-harness job works around this by running `dart run` via the flutter SDK setup, which is an extra ~3 minutes of CI cold-start per job. The pytest test (`services/backend/tests/test_calc_diff_harness.py`) skips cleanly when `CALC_HARNESS_BIN` is absent, so the gate is structurally green but axis-1 (Mobile↔Backend differential) doesn't actually run end-to-end yet.

## Why this is small

The Flutter cascade is **3 lines of code** and **one helper function** :

| Line | Code | Purpose |
|---|---|---|
| 13 | `import 'package:flutter/foundation.dart';` | brings in `kDebugMode`, `debugPrint`, `@visibleForTesting` |
| 14 | `import 'package:mint_mobile/services/regulatory_sync_service.dart';` | brings in `RegulatorySyncService.getCached()` |
| 28-37 | function `double reg(String key, double fallback) { ... }` | runtime cache lookup with fallback warning |
| 43 | `@visibleForTesting void debugResetRegFallbackLog()` | test hook |

The remaining 600+ lines of `social_insurance.dart` are **pure data constants** (LPP bonification rate table, RAMD ceilings, capital tax brackets, AVS rates, canton multipliers). Zero Flutter dependencies. The `reg()` function is the only thing that needs Flutter.

## Closure plan (Path A : two-file split, recommended)

### Step 1 — Create `lib/constants/social_insurance_pure.dart` (new file, pure-Dart, no Flutter imports)

Move all 93 const + Map declarations from `social_insurance.dart` into the new file. Replace the `reg()` function with a pure-Dart no-op variant :

```dart
/// Pure-Dart fallback resolver — no runtime sync, no debug logging.
/// Production callsites use the override in `social_insurance.dart`.
double reg(String key, double fallback) => fallback;
```

Drop `@visibleForTesting` (replace with a doc comment ; it's a marker annotation, non-functional outside Flutter).

### Step 2 — Refactor `lib/constants/social_insurance.dart` to thin wrapper

```dart
library social_insurance;

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';
import 'social_insurance_pure.dart' show reg as _pureReg; // hide pure no-op

// Re-export all constants from the pure module so existing callsites work.
export 'social_insurance_pure.dart' hide reg;

final Set<String> _regFallbackLogged = <String>{};

/// Production `reg()` — runtime cache lookup + dev-mode fallback warning.
/// Shadows the pure-Dart `reg()` from `social_insurance_pure.dart`.
double reg(String key, double fallback) {
  final cached = RegulatorySyncService.getCached(key);
  if (cached != null) return cached;
  if (kDebugMode && _regFallbackLogged.add(key)) {
    debugPrint('reg() FALLBACK: $key → $fallback (cache miss, logged once)');
  }
  return fallback;
}

@visibleForTesting
void debugResetRegFallbackLog() => _regFallbackLogged.clear();
```

The 10 callers under `apps/mobile/lib/services/financial_core/` continue to import `social_insurance.dart` and get the production `reg()` via name resolution.

### Step 3 — Update calc_harness/main.dart import

```dart
// Before (transitive Flutter cascade)
import 'package:mint_mobile/constants/social_insurance.dart';

// After (pure-Dart only)
import 'package:mint_mobile/constants/social_insurance_pure.dart';
```

### Step 4 — Update calc-rigor.yml workflow

Replace the flutter SDK setup + `dart run` with a plain dart SDK + `dart compile exe` :

```yaml
- uses: dart-lang/setup-dart@v1
  with: { sdk: '3.5.x' }
- run: |
    dart compile exe apps/mobile/tools/calc_harness/main.dart -o build/calc_harness_dart
    cd services/backend
    CALC_HARNESS_BIN=$PWD/../../build/calc_harness_dart \
      pytest tests/test_calc_diff_harness.py -v
```

Drop the flutter SDK install step. Differential job goes from ~3 min cold start to ~30 s.

### Step 5 — Verify + close out

- `dart compile exe apps/mobile/tools/calc_harness/main.dart -o /tmp/check && rm /tmp/check` → exit 0
- `cd services/backend && pytest tests/test_calc_diff_harness.py -v` → 4 passed (no longer 4 skipped)
- `flutter test` → no regression in financial_core/ tests (existing callers still resolve `reg()` to production override)
- Update `apps/mobile/tools/calc_harness/main.dart:19` — drop the `TODO(92.5-04 CI)` comment.
- Tick the « cascade Flutter follow-up » row in `.planning/phases/92.5-mvp-calc-rigor-foundations/92.5-04-G6-CLOSE-OUT.md`.

## Effort + risk

- **Estimated effort**: 3-4 hours total. Step 1 = 30 min mechanical move + grep verify zero Flutter imports. Step 2 = 30 min thin wrapper. Step 3 = 5 min import swap. Step 4 = 30 min CI workflow YAML + verify. Step 5 = 15 min cleanup.
- **Risk**: low. The 10 financial_core/ callers continue to use the production `reg()` via name resolution (Dart's lexical scoping picks the un-prefixed `reg` from `social_insurance.dart` not from the re-exported pure file). All 5,500+ Mobile tests continue to exercise the production `reg()` path.
- **Test coverage**: existing tests cover both paths. No new tests needed for this refactor.

## Counter-arguments and data gaps

**Counter-argument** : Path B (pure refactor in-place — drop `@visibleForTesting`, replace `kDebugMode + debugPrint` with `assert(() { print(...); return true; }())`, isolate `regulatory_sync_service.dart` import) is even simpler — single file, ~10 LOC change. Pros : no two-file split, no re-export sleight-of-hand. Cons : production `reg()` loses the « log once per key » dedupe (the `_regFallbackLogged` set is a runtime concern that needs `kDebugMode` gating to not spam release builds).

**Data gap** : the actual visual / semantic difference between « production `reg()` with sync » and « pure `reg()` no-op » in the calc_harness has not been measured. If `RegulatorySyncService` populates non-trivial canton overrides at runtime in production (e.g., 2026 fiscal year tarifs published mid-cycle), the calc_harness with the pure no-op would drift from the live Mobile rendering. Mitigation : the differential test compares Mobile and Backend at the same fixture timestamp ; both use the same fallback constants since the harness can't sync.

## When to schedule

The current state is « calc-rigor.yml works, just slower than ideal ». Not blocking ship. Suggested schedule :

- **Now (today)** : not required. PRs #554 + #555 ship without this fix.
- **Phase 92.7 candidate** : after the 3 v2.12.3 production regressions (coach unavailable, logout-doesn't-reset, onboarding lost) are triaged. The calc-rigor CI runtime cost is small enough that prioritization is « when there's no higher-value work in the queue ».
- **Trigger to elevate priority** : if Phase 94 (CITATION-GATE) starts requiring real-time differential checks against the calc_harness binary in a CI hot-path, OR if the flutter SDK cold start on every PR becomes a bottleneck.

## Disposition

Filed as a Proposed ADR. Awaiting Julien's scheduling decision (now / Phase 92.7 / backlog).
