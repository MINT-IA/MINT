# Phase 09 — Claude Review Harness

## Goal

Make Claude CLI useful again for Mint reviews without relying on brittle `--bare`
or large unbounded prompts.

## Diagnosis

- Local Claude auth is valid through `claude.ai` / first-party Max login.
- `--bare` intentionally bypasses keychain/OAuth and therefore fails unless an
  API key or `apiKeyHelper` is configured.
- Large diff reviews were timing out because the previous workflow fed broad
  prompts through Claude Code with no scoped timeout, hidden stderr, and optional
  repo/MCP overhead.

## Scope

- Add/repair a bounded `tools/claude_review.sh` helper.
- Make the agent-drift golden runner timeout configurable and disable tool use.
- Update local GSD review snippets to preserve Claude stderr and use explicit
  timeouts.
- Use the repaired Claude review on the current budget read-model diff.

## Non-Goals

- Do not replace native GSD code-review agents.
- Do not use `--bare` with the current Max/keychain setup.
- Do not feed full-repo diffs to Opus as a normal gate.
