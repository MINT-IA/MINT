# Phase 28 — Packet Finite Trust Guard

## Goal

Prevent malformed packet values from overriding backend budget data or rendering as user-facing CHF amounts.

## Audit Finding

The code-review agent found that `NaN` and `inf` values could pass through packet sanitation and activate packet-over-DB precedence.

## Scope

- Require finite numeric values in the shared packet sanitizer.
- Preserve explicitly safe string fact values for `profile.canton` and `trajectory.status`.
- Require usable budget facts for packet precedence:
  - finite numeric value;
  - not `freshness: stale`;
  - not `state: missing`.
- Add regression tests for non-finite and stale/missing packet facts.
