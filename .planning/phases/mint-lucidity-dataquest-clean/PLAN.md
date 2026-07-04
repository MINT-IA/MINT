# Mint Lucidity DataQuest Clean Plan

## Sequence

1. Consolidate Mint OS in the clean branch.
2. Re-run OS guards and the current lucidity gates.
3. Add failing route/domain-payload tests for WIRING invariants I-1, I-2, I-5,
   and I-8.
4. Fix route wiring and provider usage with the smallest Flutter changes.
5. Re-run targeted Flutter tests, route parity, ARB parity, and lucidity gates.
6. Commit and push the OS tranche.
7. Continue P0 product hardening: first salary, buy property, transmit property,
   dossier/PDF.
8. Run Patrol/Maestro and Claude CLI external audit before acceptance.

## Non-Goals

- No production account creation work in this phase.
- No new broad planning matrix.
- No financial formula rewrite outside `financial_core`.

