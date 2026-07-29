# Mint Karpathy Rules Infra Plan

## Task 1 — Guard Tests First

- Add tests for `phase_contract_guard.py`.
- Add tests for `mint_rules_guard.py`.
- Run them before implementation and confirm they fail because scripts are
  missing.

## Task 2 — Mechanical Guards

- Implement `tools/checks/phase_contract_guard.py`.
- Implement `tools/checks/mint_rules_guard.py`.
- Keep both guards narrow and deterministic.
- Do not inspect historical phase shape.

## Task 3 — Active Phase Contract

- Create this phase with `CONTEXT.md`, `SPEC.md`, `PLAN.md`, and
  `VERIFICATION.md`.
- Promote this phase in `.planning/ACTIVE_CONTEXT.md`,
  `.planning/ACTIVE_CONTEXT.json`, `.planning/STATE.md`, and
  `.planning/ROADMAP.md`.

## Task 4 — Environment Rules

- Rewrite `rules.md` around `ALWAYS DO`, `ASK FIRST`, `NEVER DO`.
- Update `.claude/AGENT_BOOTSTRAP.md` so it cannot bypass active context.
- Update `AGENTS.md` and `docs/MINT_AGENT_WORKFLOW.md` with the two new guards.

## Task 5 — Hook and CI Wiring

- Add both guards to `lefthook.yml`.
- Add a lightweight CI planning guard job for PRs.
- Regenerate `.planning/INDEX.md`.

## Task 6 — Reviews and Memory

- Ask Claude CLI for a bounded read-only review.
- Use specialist agents for docs, guardrails, and context.
- Save Engram decision/discovery.
- Commit only after fresh verification.
