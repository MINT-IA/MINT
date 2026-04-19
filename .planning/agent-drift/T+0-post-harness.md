# Agent drift report — 2026-04-19

Source: `.planning/agent-drift/drift.db` (CTX-02). Window: last 7 days.

## Metrics

### (a) Drift rate — metric a
- **Value:** 81.6%
- **Definition:** % commits by `Co-Authored-By: Claude` with >=1 lint violation
- **Source:** `git log --author='Co-Authored-By: Claude'` × `tools/checks/{accent_lint_fr,no_hardcoded_fr}.py`

### (b) Context hit rate — metric b
- **Value:** 9.3%
- **Definition:** % sessions where `gsd-prompt-guard.js` detected >=1 rule violation at first tool_use
- **Source:** `.claude/hooks/gsd-prompt-guard.js` -> `.planning/agent-drift/context_hits.jsonl`

### (c) Token cost per session — metric c
- **Value:** 63712248 tokens (avg input + output + cache)
- **Definition:** mean total tokens per session from Claude Code JSONL transcripts
- **Source:** `~/.claude/projects/-Users-julienbattaglia-Desktop-MINT/*.jsonl` usage sums

### (d) Time-to-first-correct-output — metric d
- **Value:** 1.0 turns avg (latest golden run)
- **Definition:** # turns to produce lint-clean output on 20 golden prompts
- **Source:** `tools/agent-drift/golden/run.sh` -> `golden_runs` table

