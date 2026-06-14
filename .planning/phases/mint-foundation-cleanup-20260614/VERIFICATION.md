# Mint Foundation Cleanup — Verification

## Status

FOUNDATION_COMMITTED_LOCAL.

## Verified So Far

- Clean worktree created from `origin/dev`.
- Only foundation docs copied or added.
- Original dirty tree not reverted or staged.
- Claude CLI foundation review returned `PASS_WITH_FIXES`.
- Claude P1 fixes applied in `.planning/STATE.md` and the Mint 2.0 context.
- Claude P2 fixes applied in `AGENTS.md`.
- `AGENTS.md` normalized to LF to match repository `eol=lf`.
- `git diff --check` passes after normalization.
- Public-doc legal-admission lint passes on the foundation docs.
- French accent lint passes on `docs/MINT_AGENT_WORKFLOW.md`.
- `python3 tools/checks/cjt_context_guard.py` passes by explicit skip when the
  active milestone is not CJT.
- `python3 -m pytest tools/checks/tests/test_cjt_context_guard.py -q` passes.
- Final Claude CLI targeted follow-up returned `PASS`.
- `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json` define the
  single current session router.
- `python3 tools/checks/active_context_guard.py` passes.
- `python3 -m pytest tools/checks/tests/test_active_context_guard.py -q` passes.

## Open

- Optional push after user approval.
