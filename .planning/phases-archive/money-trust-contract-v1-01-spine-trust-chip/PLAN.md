description: Plan to surface existing data-spine confidence metadata in Mon Argent.

# Money Trust Contract v1-01 — Spine Trust Chip

## Goal

Show a compact trust chip on the first eligible `Mon argent` data-spine rows
without adding a new money model.

## Implementation

1. Reuse `SpineValue.meta.confidence` and `PillarFact.state`.
2. Keep chips private, read-only, and local to `MonArgentScreen`.
3. Add stable semantics identifiers for known, estimated, and missing states.
4. Add focused widget tests.

## Verification

`dart format`; targeted `flutter analyze`; targeted `flutter test`;
`validate_arb_parity`; iOS simulator + relevant Maestro flow if gates pass.

## Non-Goals

No global `MoneyFigure`, new ARB strings, Coach edits, Budget edits, or
financial formula changes.
