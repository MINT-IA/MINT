# Mint Foundation Cleanup — Claude Review

## Review Command

Claude CLI was run from the clean worktree with a bounded, non-interactive
review prompt:

```bash
claude -p "<foundation review prompt>" \
  --model opus \
  --effort high \
  --permission-mode acceptEdits \
  --allowedTools Read,Grep,Glob,Bash \
  --strict-mcp-config \
  --output-format json \
  --add-dir /Users/julienbattaglia/Desktop/MINT.foundation-clean.nosync
```

## Verdict

`PASS_WITH_FIXES`

## Findings Applied

- P1: `.planning/STATE.md` still described old CJT / illogism work as active.
  Fixed by making `mint-foundation-cleanup-20260614` the active state and
  moving older work to historical receipts.
- P1: Mint 2.0 phase context linked to the dirty original checkout with an
  absolute path. Fixed by using a repo-local relative link to
  `docs/MINT_AGENT_WORKFLOW.md`.
- P2: `AGENTS.md` mixed line endings after the workflow pointer edit. Fixed by
  normalizing `AGENTS.md` to LF, matching the repository `eol=lf` attribute.
- P2: `AGENTS.md` referenced the removed `docs/SPRINT_TRACKER.md`. Fixed by
  linking to `.planning/INDEX.md`.

## Open

No unresolved P1 after the fixes above. Product code remains frozen until this
foundation branch is committed and reviewed.

## Follow-Up Review

A second Claude CLI review found one real P1 and one P2:

- P1: `tools/checks/cjt_context_guard.py` was still a hard pre-commit gate
  that forced the retired CJT phase as active. Fixed with a phase-aware skip:
  when `.planning/STATE.md` declares a non-CJT milestone, the guard exits OK
  with a skipped message. Regression test added.
- P2: `docs/MINT_AGENT_WORKFLOW.md` described `.codex/agents/*.toml` as a
  repo roster even though `.codex/agents` is absent in this checkout. Fixed by
  making that path conditional and using session-discovered Codex agents when
  no repo mirror exists.

Final targeted follow-up verdict: `PASS`, with no unresolved findings.
