# Phase 23 Summary

## What Changed
- `_format_budget_status` now reads `budget.monthly_net`, `budget.monthly_charges`, and `budget.monthly_free` from `coach_context_packet` first.
- If packet budget facts are present, stale legacy flat values are ignored.
- Missing budget fields from the packet are rendered as `Données budget à confirmer`.
- Added a regression test proving packet values win over contradictory legacy values.

## Why
After Phase 21, the packet became the trust-aware coach evidence contract. This phase makes the internal budget tool fallback honor that contract instead of keeping a parallel legacy truth.

