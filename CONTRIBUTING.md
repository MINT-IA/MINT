# Contributing to MINT

Short-form conventions for anyone (human or agent) editing this repo.
Complete playbook lives in `CLAUDE.md`, `docs/AGENTS/*.md`, and
`.claude/skills/*/SKILL.md`.

## Pre-commit hooks (lefthook)

MINT uses lefthook 2.1.5+ for pre-commit gates (<5s budget). Install
with `brew install lefthook && lefthook install`. Current gates scan
staged diffs for banned terms, ASCII-flattened FR accents, hardcoded
French strings, bare catches, and ARB key-set parity. See `lefthook.yml`
and `tools/checks/*.py`.

## Agent commits (proof-of-read — GUARD-06)

Commits carrying `Co-Authored-By: Claude` MUST include a `Read:`
trailer pointing to a `.planning/phases/<phase>/<padded>-READ.md`
file that lists the files the agent actually consulted (one `- <path>
- <why>` bullet per file, per D-18). The commit-msg hook
(`tools/checks/proof_of_read.py`) enforces this. Human commits (no
Claude trailer) bypass automatically. `Read:` paths MUST start with
`.planning/phases/` (T-34-SPOOF-01 mitigation).

Example trailer block:

```
Read: .planning/phases/34-agent-guardrails-m-caniques/34-05-READ.md
Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
```
