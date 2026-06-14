# Mint Foundation Cleanup — Plan

## Goal

Create a clean, reviewable foundation before any Mint 2.0 product code.

## Steps

1. Create a worktree from `origin/dev`.
2. Bring in only accepted foundation docs.
3. Keep the previous dirty worktree as quarantine.
4. Run public-doc and markdown checks.
5. Run Claude CLI review on the foundation branch.
6. Commit the foundation in small atomic commits.
7. Start Mint 2.0 Slice 2 only from this clean branch or a branch based on it.
8. Keep `.planning/STATE.md` as the single current phase pointer.

## Commit Plan

1. `docs: add Mint agent workflow`
   - `docs/MINT_AGENT_WORKFLOW.md`
   - minimal `AGENTS.md` pointer

2. `planning: open Mint 2.0 first experience phase`
   - `.planning/phases/mint-2-0-first-experience-rente-capital/`

3. `planning: add foundation cleanup inventory`
   - `.planning/phases/mint-foundation-cleanup-20260614/`
   - `.planning/ROADMAP.md`
   - `.planning/STATE.md`

## Required Checks

```bash
git diff --check
python3 tools/checks/no_legal_admission_in_public_docs.py --paths AGENTS.md docs/MINT_AGENT_WORKFLOW.md .planning/phases/mint-2-0-first-experience-rente-capital .planning/phases/mint-foundation-cleanup-20260614
python3 tools/checks/accent_lint_fr.py --file docs/MINT_AGENT_WORKFLOW.md
```

If product code is touched, this plan is invalid and must be rewritten.

## Exit Criteria

- Clean worktree branch contains only foundation files.
- Original dirty tree remains untouched and quarantined.
- Claude CLI review returns no P1 unresolved finding.
- Engram has a session summary and stable topic keys.
