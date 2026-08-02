# MINT Active Context

This file is the session router. If another document disagrees with it, this
file and `.planning/ACTIVE_CONTEXT.json` win until the disagreement is fixed.

## Active Now

<!-- mint-authority: milestone=mint-next-batch4-architecture-promotion-20260802; phase_dir=.planning/phases/mint-next-batch4-architecture-promotion-20260802; context=.planning/phases/mint-next-batch4-architecture-promotion-20260802/CONTEXT.md; spec=.planning/phases/mint-next-batch4-architecture-promotion-20260802/SPEC.md; mode=governance-readiness -->

- Active milestone: `mint-next-batch4-architecture-promotion-20260802`
- Active context: `.planning/phases/mint-next-batch4-architecture-promotion-20260802/CONTEXT.md`
- Active spec: `.planning/phases/mint-next-batch4-architecture-promotion-20260802/SPEC.md`
- Authority mode: **governance-readiness**. This phase inventories promotion prerequisites; it does not promote Batch 4 or change product/runtime behavior.
- Active integration branch: `dev`; this transition branch is review-only until deterministically accepted under the declared trust gate.
- Active operating overlay: `.planning/journeys/` remains the canonical runtime board, issue registry, evidence map, and priority queue.
- Legacy retirement vertical: `.planning/phases/mint-2-0-first-experience-rente-capital/` is preserved as a runtime vertical and historical receipt; it is no longer the global information architecture.
- Batch 4: `product/mint_next/batch4/` remains `draft_unproven`; readiness is `blocked_waiting_cross_provider_review`, `promotion_eligible: false`, with no selected gate, candidate head, or receipt.
- Historical authority receipt: `.planning/phases/mint-next-architecture-authority-20260802/` remains accepted for governance only.
- Next product phase: none queued. The active readiness context self-references only because the router schema requires a context path.
- Journey OS guard: `python3 tools/checks/journey_os_check.py`.
- Workflow contract guard: `python3 tools/checks/workflow_contract_guard.py`.

## Required Session Start

Every Mint session must read these files before product or code work:

1. `AGENTS.md`
2. `CLAUDE.md`
3. `docs/MINT_AGENT_WORKFLOW.md`
4. `.planning/ACTIVE_CONTEXT.md`
5. `.planning/STATE.md`

Then run:

```bash
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
python3 tools/checks/journey_os_check.py
python3 tools/checks/workflow_contract_guard.py
git status --short --branch
```

## Not Active

These phase directories are historical receipts or quarantine references. They
may be cited as evidence, but they are not active routing authority:

- `mint-prod-ready-core-journey-truth-20260601`
- `mint-illogism-fixes`
- `mint-grounded-coach-m1`
- `mint-onboarding-auth-reset-restore-integration`
- `mint-diagnostic-onboarding-v1`
- `mint-profile-clear-conversation-purge`
- `mint-anonymous-chat-restore-control`
- `mint-account-entry-apple-primary`
- `mint-onboarding-lifecycle-reset`
- `money-trust-contract-v1-03-onboarding-3a-number-gate`
- `money-trust-contract-v1-33-3a-onboarding-tax-copy-guard`
- `mint-karpathy-rules-infra-20260614`
- `mint-2-0-first-experience-rente-capital` — preserved runtime vertical; not global architecture authority
- `mint-next-architecture-authority-20260802` — accepted historical governance-only authority receipt; not Batch 4 promotion

The canonical checkout is `/Users/julienbattaglia/Desktop/MINT.nosync` on
`dev`. Historical local copies and deleted worktrees were moved into
`/Users/julienbattaglia/Desktop/MINT-cleanup-archive-20260624T074611Z`.

## Archive Policy

Do not move dozens of old phase directories as part of feature work. That would
create a large mechanical diff and break historical references without improving
the user experience.

Instead:

- keep old phases visible as receipts;
- forbid them from becoming active via `tools/checks/active_context_guard.py`;
- archive later only through a dedicated cleanup dry-run, with a reviewable PR
  and redirect/index updates.

Applied 2026-07-29 (réconciliation plans, PR dédiée) : 57 répertoires de
phases morts + `PERIMETERS.md` déplacés vers `.planning/phases-archive/`,
structure préservée. `mint-prod-ready-core-journey-truth-20260601` reste en
place : des records Journey OS citent ses artefacts d'évidence par chemin.

## Promotion Rule

When the next successor phase is queued, update these files in the same commit:

- `.planning/ACTIVE_CONTEXT.json`
- `.planning/ACTIVE_CONTEXT.md`
- `.planning/STATE.md`
- `.planning/ROADMAP.md`

Then run `python3 tools/checks/active_context_guard.py`.

## Spec -> Verifier -> Environment

Mint uses this operating model for AI-assisted work:

- **Spec:** the active phase contract lives in `SPEC.md`.
- **Verifier:** `VERIFICATION.md` lists exact commands and evidence before any
  completion claim.
- **Environment:** `rules.md`, `AGENTS.md`, `docs/MINT_AGENT_WORKFLOW.md`,
  hooks, CI, and Engram define the workspace boundaries.

Run these guards before phase execution:

```bash
python3 tools/checks/active_context_guard.py
python3 tools/checks/phase_contract_guard.py
python3 tools/checks/mint_rules_guard.py
python3 tools/checks/journey_os_check.py
python3 tools/checks/agent_reference_guard.py
python3 tools/checks/claude_hooks_guard.py
```
