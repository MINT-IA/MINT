# Phase 09 Summary — Claude Review Harness

## Completed

- Added `tools/claude_review.sh`, a scoped Claude review helper.
- The helper uses normal Claude auth, not `--bare`.
- The helper disables Claude tool use and session persistence for review calls.
- The helper defaults to Sonnet for fast review and allows Opus through
  `MINT_CLAUDE_MODEL=opus`.
- `tools/agent-drift/golden/run.py` now disables Claude tools/session persistence
  and reads `CLAUDE_GOLDEN_TIMEOUT`, defaulting to 600 seconds.
- Local GSD review docs now show explicit Claude timeout handling and write
  stderr to `/tmp/gsd-review-claude-{phase}.err`.
- Hardened the wrapper against the `exit 0 + empty stdout` Claude CLI failure
  mode by:
  - keeping JSON output as the default;
  - using `--permission-mode bypassPermissions`;
  - setting bounded `--max-turns`;
  - disallowing Engram MCP, Write, Edit, and Bash tools for review runs;
  - failing hard when JSON `.result` is empty instead of treating a silent run
    as a valid review.

## Claude Findings Applied

- `BudgetInputs.fromMap` could crash on numeric strings persisted from JSON or
  form flows. Fixed with `_parseDouble`.
- Legacy `q_net_income_monthly: 0.0` could shadow valid
  `q_net_income_period_chf`. Fixed by trusting legacy income only when positive.
- Dual-key profiles could keep stale `q_net_income_monthly` over canonical
  `q_net_income_period_chf`. Fixed by making the canonical period income win in
  both `BudgetInputs.fromMap` and `WizardService.getMonthlyIncome`.
- Swiss apostrophe-formatted numeric strings such as `5'379` are now covered by
  budget domain tests.
- Explicit zero canonical income now overrides stale legacy income in both
  `BudgetInputs.fromMap` and `WizardService.getMonthlyIncome`.
- Housing and debt budget amounts are documented and tested as monthly values,
  despite historical `period_chf` key names.

## Operating Rule

Use `tools/claude_review.sh path...` for scoped code review. Use Opus only for
intentional deeper reviews with a larger timeout. Use native agents/GSD for
multi-file architecture review.

If Claude exits 0 with no textual review, treat it as failed. In this repo the
most likely cause is a print-mode turn ending on hook/MCP/tool activity instead
of a final message.
