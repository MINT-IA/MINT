# Row 21 — Cap acknowledgement and priority rotation contract — 2026-06-05

## Status

`PARTIAL`.

This proof closes a local acknowledgement bug on the visible `Aujourd'hui` Cap
du jour surface. It intentionally does **not** claim that the underlying
financial action is completed. True completion still requires a target-flow
return/profile-change proof.

## Bug

The Row 21 runtime proof already showed that `Simule` routes to Explorer. The
remaining product problem was that selecting a visible Cap du jour action did
not mutate any daily-return state:

- `CapDuJourBanner` exposed `Simule`, but did not write `CapMemoryStore`.
- `MintStateProvider.forceRecompute(profile)` already existed for non-profile
  state changes, but the visible banner did not call it.
- The existing `CapEngine` recency modifier could reduce a recently served cap,
  but the visible banner never marked the cap as recently served.

A first attempted implementation used `CapMemoryStore.markCompleted(...)`.
Review caught that as too strong: `completedActions` drives real sequence
progress and lightning-menu filtering, so a mere tap must not mark a financial
task complete.

## Change

- `CapDuJourBanner` now records `Simule` and the primary card CTA through
  `CapMemoryStore.markServed(...)`.
- The memory stamp uses `lastCapServed` / `lastCapDate`.
- `completedActions` remains untouched.
- After persistence, the banner calls `MintStateProvider.forceRecompute(profile)`.
- `CapEngine` remains on the existing recency model: recently served caps are
  penalized for up to 24 hours, but critical incomplete work is not globally
  suppressed.

## Deterministic Proof

```bash
cd apps/mobile
flutter test \
  test/widgets/aujourdhui/cap_du_jour_banner_test.dart \
  test/services/cap_engine_test.dart
```

Result: `73` tests passed.

New contracts:

- Widget: tapping `Simule` persists `pillar_3a` as `lastCapServed`, writes
  `lastCapDate`, leaves `completedActions` empty, leaves completed headline/CTA
  fields null, and calls `forceRecompute(profile)` once.
- Engine: a recently served winner can rotate when another candidate outranks
  the penalized cap, without relying on `completedActions`.

Broader action-bar regression proof:

```bash
cd apps/mobile
flutter test \
  test/widgets/mint_card_action_bar_test.dart \
  test/widgets/mint_card_action_bar_routing_test.dart \
  test/widgets/aujourdhui/cap_du_jour_banner_test.dart \
  test/widgets/confidence_score_card_actionbar_test.dart
```

Result: `29` tests passed.

## Static Verification

```bash
cd apps/mobile
flutter analyze \
  lib/widgets/aujourdhui/cap_du_jour_banner.dart \
  lib/services/cap_engine.dart \
  test/widgets/aujourdhui/cap_du_jour_banner_test.dart \
  test/services/cap_engine_test.dart
```

Result: no issues found.

## Runtime Guidance Quality Review

- `mechanical proof`: local widget and engine tests prove acknowledgement,
  recompute, and recency-based rotation.
- `user-visible outcome`: an explicit user action now affects the daily state
  instead of being treated as a no-op.
- `guidance quality`: the screen is closer to a useful daily guidance loop:
  action acknowledgement -> state recompute -> reduced repetition.
- `non-absurd`: avoids immediate repetition pressure without pretending a
  financial task was completed.
- `inclusive`: no new salary-only, employee-only, or unsupported-archetype copy
  was introduced.
- `financial trust`: preserves `completedActions` for actual completed actions;
  no financial calculation or progress state is overstated.
- `remaining qualitative gaps`: runtime proof still needs to show the user
  returning to `Aujourd'hui` and seeing the next correct visible priority.
  Target-flow completion still needs separate proof before writing
  `completedActions`.

## Next Proof

Keep Row 21 at `PARTIAL` until a Maestro/runtime flow proves:

- start on `/home` with a real current cap,
- tap a visible action,
- return to `/home` after acknowledgement/recompute,
- assert either the previous cap is temporarily deprioritized or a different
  correct priority is visible,
- capture screenshots before and after.

Separately, true completion proof should follow the safer existing `CapCard`
pattern: mark `completedActions` only after the target flow returns with a
meaningful profile/state change.
