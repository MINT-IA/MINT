# Phase 28 — Summary

## Changed

- `context_packet_sanitizer._number` now rejects non-finite values.
- `context_packet_sanitizer` now keeps safe string values for `profile.canton` and `trajectory.status`.
- `coach_chat._has_packet_budget_facts` now only trusts usable packet budget facts.
- Added tests for:
  - `NaN` / `inf` packet values;
  - stale/missing packet budget facts;
  - actual `profile.canton` fixture value surviving sanitation.

## Result

Malformed packet numbers no longer bypass DB fallback or render as `CHF nan` / `CHF inf`.
