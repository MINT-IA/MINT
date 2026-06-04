---
description: Row 17 simulator design-system proof for the compound simulator primary input contract.
status: partial-proof
date: 2026-06-04
---

# Row 17 Compound Visible Input Contract

Journey Truth Matrix Row 17 asks whether shipped simulators/widgets meet the
design-system and source rules: no overloaded primary screens, assumptions
editable, source/disclaimer present, and i18n instead of hardcoded copy.

This pass does not close Row 17. It fixes and proves the clearest local
regression found during the top-simulator audit: the compound-interest
simulator exposed four visible primary sliders.

## Finding

`/simulator/compound` initially exposed four visible inputs:

- starting capital;
- monthly contribution;
- annual return;
- time horizon.

That breaks the Row 17 primary-screen contract because the annual return is an
assumption, not a first-order user decision. It should remain editable, but it
does not need to compete with the three primary choices.

## Fix

`apps/mobile/lib/screens/simulator_compound_screen.dart` now keeps the primary
surface to three visible sliders:

- starting capital;
- monthly contribution;
- time horizon.

The annual return slider remains editable in a collapsed Mint-surface
hypothesis panel using the existing localized label
`compoundTauxRendement`. No ARB key was added.

## Proof

Command:

```bash
cd apps/mobile
flutter test test/screens/simulator_screens_smoke_test.dart
```

Result:

```text
52 tests passed
```

The updated compound test asserts:

- initial visible `Slider` count is `3`;
- after opening the `Rendement` assumption panel, visible `Slider` count is
  `4`;
- existing French labels, final value, education, and disclaimer smoke tests
  still pass.

## Static Top-Simulator Inventory Slice

| Route | Screen | Current slice finding |
|---|---|---|
| `/simulator/3a` | `Simulator3aScreen` | Uses modern inputs (chips + text field), localized copy, and disclaimer smoke coverage. |
| `/simulator/leasing` | `SimulatorLeasingScreen` | Three sliders, localized copy, and disclaimer smoke coverage. |
| `/simulator/credit` | `ConsumerCreditSimulatorScreen` | Three sliders and localized/disclaimer implementation visible in source; not covered by this smoke file. |
| `/simulator/compound` | `SimulatorCompoundScreen` | Fixed to three primary visible sliders, with editable annual-return assumption collapsed. |
| `/simulator/rente-capital` | `RenteVsCapitalScreen` | Complex arbitrage surface with source/disclaimer card; still needs a dedicated runtime/design audit rather than being treated as closed by this pass. |

## Row 17 Status

Move Row 17 from `UNPROVEN` to `PARTIAL`.

Reason: one concrete shipped simulator defect is fixed and covered by widget
tests, and the initial top-simulator inventory now identifies which surfaces
already satisfy the visible-input slice and which still need proof. Row 17 is
not `LIVE-PROVEN` until the top shipped simulators have runtime screenshots or
equivalent visual proof, with source/disclaimer and accessibility/i18n checks
for each.
