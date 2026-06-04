---
id: ROW-23-DYNAMIC-TYPE
date: 2026-06-04
status: partial-proof
area: primary-screen-design
---

# Row 23 — Primary Screen Dynamic Type Smoke

## Scope

Added a widget-level dynamic type guard for representative primary screens at
200% text scale:

- Budget empty state
- Mon Argent missing-data state
- Profile / Dossier empty state
- Document Scan entry state
- Explorer hub grid

This is not a full visual audit and does not close Row 23. It reduces one
release risk: RenderFlex overflow when iOS text size is large.

## Test

```text
cd apps/mobile
flutter test test/accessibility/primary_screen_dynamic_type_test.dart
```

Result on 2026-06-04:

```text
00:00 +0: Row 23 primary screens at 200% text scale Budget empty state does not overflow
00:00 +1: Row 23 primary screens at 200% text scale Mon Argent missing-data state does not overflow
00:00 +2: Row 23 primary screens at 200% text scale Profile dossier empty state does not overflow
00:00 +3: Row 23 primary screens at 200% text scale Document scan entry state does not overflow
00:00 +4: Row 23 primary screens at 200% text scale Explorer hub grid does not overflow
00:00 +5: All tests passed!
```

## Caveat

Keep Row 23 `PARTIAL` until runtime screenshot review and broader
accessibility proof cover the rest of the primary screen set, including Coach
and Rapport/Bilan.
