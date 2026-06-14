# Mint Karpathy Rules Infra Context

## TLDR

Mint must stop relying on agent memory or motivational prompts. The operating
system for AI work is now three layers: a precise spec, a verifier with external
signals, and an environment with mechanical guardrails.

## Problem

Mint has accumulated strong rules across `CLAUDE.md`, `AGENTS.md`, GSD phases,
Engram, hooks, and planning docs. The failure mode is not lack of doctrine. The
failure mode is that some rules are still only instructions to an agent.

For the highest-risk areas, a prompt is not enough:

- a phase can start without a spec;
- a future bootstrap can skip `.planning/ACTIVE_CONTEXT.md`;
- rules can drift back into prose without `ALWAYS DO`, `ASK FIRST`, `NEVER DO`;
- a model can claim completion without fresh verifier output;
- historical phase docs can visually compete with the active router.

## Decision

Adopt the Spec -> Verifier -> Environment workflow as Mint infrastructure:

- **Spec:** every active phase has `CONTEXT.md`, `SPEC.md`, `PLAN.md`, and
  `VERIFICATION.md`.
- **Verifier:** phase work defines acceptance criteria and fresh commands before
  implementation claims.
- **Environment:** `rules.md`, Claude bootstrap, GSD pointers, hooks, CI, and
  Engram conventions are the workshop. Critical rules are enforced by scripts,
  not by trust in a model.

## Scope

This phase is infra-only. It may edit:

- `rules.md`
- `.claude/AGENT_BOOTSTRAP.md`
- `AGENTS.md`
- `docs/MINT_AGENT_WORKFLOW.md`
- `.planning/ACTIVE_CONTEXT.md`
- `.planning/ACTIVE_CONTEXT.json`
- `.planning/STATE.md`
- `.planning/ROADMAP.md`
- `.planning/INDEX.md`
- `.planning/templates/MINT_PHASE_SPEC.md`
- `tools/checks/*rules*`, `tools/checks/*contract*`
- `lefthook.yml`
- `.github/workflows/ci.yml`

It must not edit product code.

## Non-Goals

- No onboarding or UI fix.
- No simulator claim.
- No physical archive of old phase directories.
- No rewrite of all Claude agents.
- No merge to `dev`, `staging`, or `main`.

## Success

The branch is acceptable only if:

- `active_context_guard.py` passes;
- `phase_contract_guard.py` passes on the real repo;
- `mint_rules_guard.py` passes on the real repo;
- tests for the new guards pass;
- `rules.md` has `ALWAYS DO`, `ASK FIRST`, `NEVER DO`;
- Claude bootstrap requires the active context router;
- Claude CLI or specialist agents have reviewed the result;
- Engram records the decision.

