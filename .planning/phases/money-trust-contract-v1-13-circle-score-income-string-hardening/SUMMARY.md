# Phase 13 Summary — Circle Score Income String Hardening

## Changed

- Circle 1 income scoring now uses `_parseDouble` instead of `as num?`.
- `_parseDouble` accepts values like `"5'000"` and comma decimals.
- Added a regression test proving persisted string income is scored as known
  income and displayed as `CHF 5'000/mois`.

## Product Impact

Health scoring is more consistent with stored Mint answers. A user should not
lose score quality or hit a crash just because a numeric value was hydrated as a
string.
