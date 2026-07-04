# MINT Active Context

This file is the current session router. If another planning document disagrees
with it, this file and `.planning/ACTIVE_CONTEXT.json` win until the
disagreement is fixed.

## Active Now

- Active milestone: `mint-lucidity-dataquest-clean`
- Active context: `.planning/phases/mint-lucidity-dataquest-clean/CONTEXT.md`
- Active spec: `.planning/phases/mint-lucidity-dataquest-clean/SPEC.md`
- Next product phase: `.planning/phases/mint-lucidity-dataquest-clean/CONTEXT.md`
- Active branch: `codex/mint-dataquest-transmit-property-clean`
- Active operating overlay: `.planning/journeys/` remains the Journey OS board,
  issue registry, evidence map, and priority queue.
- Scope: consolidate Mint OS in the clean branch, then execute the Data
  Ledger/Data Quest P0 product spine with Patrol/Maestro/Claude CLI evidence.

## Required Session Start

Every Mint session must read these files before product or code work:

1. `AGENTS.md`
2. `CLAUDE.md`
3. `docs/MINT_AGENT_WORKFLOW.md`
4. `.agents/skills/mint-operating-gates/SKILL.md`
5. `.planning/ACTIVE_CONTEXT.md`
6. `.planning/ACTIVE_CONTEXT.json`
7. `.planning/STATE.md`

Then run:

```bash
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
python3 tools/checks/journey_os_check.py
python3 tools/checks/workflow_contract_guard.py
git status --short --branch
```

## Phase Contract

The active phase files are:

- `.planning/phases/mint-lucidity-dataquest-clean/CONTEXT.md`
- `.planning/phases/mint-lucidity-dataquest-clean/SPEC.md`
- `.planning/phases/mint-lucidity-dataquest-clean/PLAN.md`
- `.planning/phases/mint-lucidity-dataquest-clean/VERIFICATION.md`

## Not Active

Historical phase directories are receipts. They may be cited as evidence, but
they are not the current router.

## Promotion Rule

When the next successor phase is queued, update these files in the same commit:

- `.planning/ACTIVE_CONTEXT.json`
- `.planning/ACTIVE_CONTEXT.md`
- `.planning/STATE.md`
- `.planning/ROADMAP.md`

Then run `python3 tools/checks/active_context_guard.py`.

