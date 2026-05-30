# Phase 25 — Budget Packet Precedence With Server Flag On

## Goal

Prevent stale backend budget rows from overriding the mobile Data Spine budget facts when `COACH_TOOL_SERVER_SIDE_BUDGET_ENABLED` is enabled.

## Problem

The server-side `get_budget_status` path read `ProfileModel.data` before considering the `coach_context_packet`. If the backend DB held stale or absurd values, the coach could reintroduce misleading budget amounts even though mobile had already produced a trusted packet.

## Scope

- Detect budget facts in `ctx["coach_context_packet"]`.
- When packet budget facts exist, return `_format_budget_status(ctx)` before DB lookup.
- Add a regression test proving stale DB values are not read or emitted.

## Product Invariant

For user-visible budget values, the trust-aware mobile packet wins over stale legacy backend rows.

