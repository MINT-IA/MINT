# Mint Foundation Cleanup — Context

## Problem

Mint has accumulated product, workflow, planning, auth, reset, restore, l10n, backend, and generated changes in one dirty working tree. That state is not a safe foundation for Mint 2.0.

The symptom is visible in `AGENTS.md`: the session entrypoint became dirty at the same time as product and planning experiments. If the workflow file itself is mixed with unrelated changes, future agents can start from contradictory context.

## Decision

Do not continue Mint 2.0 product work from the dirty worktree.

Create a clean foundation worktree from `origin/dev`, then reintroduce only accepted foundation artifacts:

- `docs/MINT_AGENT_WORKFLOW.md`;
- a minimal `AGENTS.md` pointer to that workflow;
- `.planning/phases/mint-2-0-first-experience-rente-capital/`;
- this cleanup phase.

Everything else in the original dirty tree is quarantined until classified and intentionally cherry-picked, discarded, or rebuilt.

## Non-Goals

- Do not revert user work in the original dirty tree.
- Do not stage the original dirty tree wholesale.
- Do not use old untracked onboarding/auth phases as active authority.
- Do not start product Slice 2 before this foundation is committed and reviewed.

## Clean Worktree

Path:

`/Users/julienbattaglia/Desktop/MINT.foundation-clean.nosync`

Branch:

`codex/mint-foundation-cleanup-20260614`

Base:

`origin/dev` at `9f15eedd2cda953adb1fd0ec9b48b5933b17080a`

## Quarantine Source

Path:

`/Users/julienbattaglia/Desktop/MINT.nosync`

Branch:

`qa/runtime-navigation-spine-20260602`

Status:

Dirty, mixed scope. Treat as read-only quarantine until each change is classified.
