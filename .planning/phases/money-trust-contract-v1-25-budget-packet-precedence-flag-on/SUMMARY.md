# Phase 25 — Summary

## Changed

- Added `_has_packet_budget_facts(ctx)` in `coach_chat.py`.
- `_compute_budget_status` now short-circuits to packet-based formatting when budget facts are present, even with `COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED=True`.
- Added `test_dispatcher_flag_on_prefers_packet_over_stale_db`.
- Preserved safe legacy `months_liquidity` context when the packet contains partial budget facts.
- Added `test_dispatcher_flag_on_preserves_liquidity_with_partial_packet`.

## Why

This directly targets the class of bugs seen in simulator screenshots: enormous or contradictory CHF amounts leaking into user-facing coach/budget output. The packet now has explicit precedence over stale DB rows.

## Result

With packet values `5'379 / 3'140 / 2'239` and DB values `999'999 / 888'888`, the coach output uses the packet values and does not query the DB. With a partial packet containing only monthly free cash flow, safe liquidity context is still shown.
