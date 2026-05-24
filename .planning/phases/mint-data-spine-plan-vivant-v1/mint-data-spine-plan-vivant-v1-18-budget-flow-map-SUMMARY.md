Plan 18 added a monthly flow map to Budget.

## Outcome

- Added a compact visual split: revenu net, charges, future allocation, available cash.
- Reused existing ARB labels and Mint design tokens.
- Wired Budget to prefer the data spine budget snapshot when present.
- Added a widget regression test that proves central state drives the flow.

## Verification

The targeted widget test failed before the map existed, then passed after wiring. The broader focused test set, targeted analyze, `git diff --check`, and all five design lints passed locally.
