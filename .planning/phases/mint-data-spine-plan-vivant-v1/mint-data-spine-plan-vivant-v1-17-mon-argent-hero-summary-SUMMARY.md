Plan 17 added a first visual data-spine summary on Mon argent.

## Outcome

- Added a top `MintSurface` for monthly free cash, confidence, and net patrimoine.
- Reused existing localized labels instead of adding new copy.
- Kept the legacy budget and patrimoine cards visible below as detail entry points.
- Extended the Mon argent widget regression test to assert the new summary.

## Verification

The targeted test first failed on the missing summary, then passed after wiring. The broader Mon argent + state engine + data spine test set passed. Targeted Flutter analyze and the five design lints passed.
