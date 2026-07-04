# Mint Lucidity DataQuest Clean Context

## Goal

Make MINT usable as a Swiss financial lucidity product, not as a planning
archive. The current branch must consolidate the Mint OS, then stabilize the
P0 product spine:

- first salary and tax lucidity;
- property purchase capacity;
- property transmission and succession preparation;
- Data Ledger/Data Quest collection without duplicated facts;
- specialist dossier/PDF output with sources, assumptions, confidence, and
  missing-data questions.

## Operating Rules

- Treat `docs/codex/` as executable specs to challenge against code.
- Start with the 9 invariants in `docs/codex/WIRING_GRAPH.mmd`.
- Fix code only after listing spec/code gaps.
- Use the permanent Mint roster in `.claude/agents/` and canonical skills in
  `.agents/skills/mint-*`.
- Use Patrol for P0 mobile runtime gates and Maestro for flow syntax/runtime
  evidence where applicable.
- Preserve chronological data collection: ask only for a missing or stale fact
  required by the active life event, and write one canonical key for the
  concept.
- Keep commits atomic, pushed regularly, and backed by deterministic evidence.

## Current Known Critical Gaps

- `state.extra` still carries domain data on scan and report routes.
- legacy `ProfileProvider` is still mounted and consumed by production widgets.
- redirect routes drop query context.
- the clean branch had only a partial Mint OS import; guards and active context
  must be made executable before more product code.
- Data Ledger docs are incomplete for wealth, mortgage, and debt variables.

