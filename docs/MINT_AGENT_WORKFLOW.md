# MINT Agent Workflow

This is the repo-local operating base for building MINT as a Swiss financial
lucidity product. It keeps the permanent MINT roster small, domain-specific,
and accountable.

## G0 Checkout Snapshot

- Active checkout during this base restore: `/Users/julienbattaglia/Desktop/MINT.nosync`.
- `MINT 2` is a Finder symlink to the active checkout, not a second source.
- Archive folders and `.bundle` files are safety artifacts, not workspaces.
- Oversized draft PRs, especially #827, are quarries: inspect and extract
  small PRs; do not merge them directly.

When this repo moves machines or branches, resolve the active checkout from
`git worktree list` and `git status --short --branch`; do not rely on the
absolute path above as product architecture.

## Permanent Roster

The main Codex/Claude session owns agent dispatch. Use this routing order for
product work:

1. `mint-lead` scopes the smallest valuable slice and rejects facade work.
2. `mint-swiss-brain` defines Swiss finance, tax, insurance, inheritance, and
   compliance boundaries.
3. `mint-data-ledger-architect` maps variables, source, freshness, confidence,
   consumers, and dead-key gates.
4. `mint-data-quest-architect` defines the Case, guard questions, and next
   question order.
5. `mint-backend` implements backend services, scenarios, schemas, and API
   payloads.
6. `mint-mobile` implements Flutter UX, providers, routes, and runtime ids.
7. `mint-lucidity-pdf` implements specialist-ready dossier sections.
8. `mint-quality-gate` verifies tests, route/data parity, runtime proof, and
   scorecards.
9. `mint-external-auditor` runs Claude CLI review and records unresolved
   findings.

Generic GSD agents remain available for planning, verification, and codebase
mapping, but they do not replace the MINT roster.

## Standing PR Gates

Every product PR must list:

- Targeted backend/mobile/spec tests.
- `python3 tools/checks/arb_parity.py` when ARB files are touched.
- Accent and banned-term checks when user-facing French copy is touched.
- Range, source, freshness, and confidence evidence for projections.
- Privacy/nLPD review when profile data, prompts, logs, analytics, exports, or
  dossier/PDF artifacts are touched.
- Design review for new or materially changed product screens.
- Maestro runtime proof for touched P0 mobile UI; Patrol is required for real
  P0 input proof once the Patrol CLI is available in the environment.
- Claude CLI audit for architecture, compliance, and pre-merge code review when
  possible.
- Engram memory after merge.

## Current Tool Matrix

| Tool | Status in clean checkout | Gate use |
|---|---|---|
| Claude CLI | Available after local login | External audit via `tools/checks/claude_external_audit.sh`; use bounded audits (`opus high`, safe mode, strict empty MCP, `--setting-sources user`) by default |
| Engram MCP | Available | Memory |
| Maestro | Available at `~/.maestro/bin/maestro` | Runtime UI proof |
| Patrol CLI | Not in PATH at G0 base restore | Required gap before Patrol-only gates |
| Mermaid CLI | Not in PATH at G0 base restore | Optional graph rendering until installed |
| Beads/bug CLI | Not in PATH at G0 base restore | Use checked-in bug ledger fallback |
| ARB parity | `tools/checks/arb_parity.py` | i18n key parity |

## Product Spine

MINT work must converge on this chain:

`ledger variable -> DataQuest ask -> Case/scenario -> screen state -> dossier/PDF -> runtime proof`.

No service without a caller, no route without a degraded state, no projection
without range + confidence + source/freshness, and no data collection that asks
again for a fresh known fact.

Claude CLI audits should be bounded through
`tools/checks/claude_external_audit.sh`: Opus high by default, `--safe-mode`
no-hooks boot, strict empty MCP, no session persistence, and no `--effort max`
except named final-release/P0 disputes. `--safe-mode` is the required latency
guard because it disables hooks, skills, plugins, custom agents, auto memory,
and CLAUDE.md auto-discovery without losing auth/model/permissions. Re-run loops
use Sonnet high first, then one Opus high final; do not use `--bare` without
explicit API-key auth, and do not add unsupported
`--max-turns`. The wrapper also forces `--setting-sources user` by default and
rejects project/local setting sources unless `CLAUDE_AUDIT_ALLOW_PROJECT_SETTINGS=1`
is explicitly set for a named debug run, because project/local settings can
reload repo hooks. Same-gate re-runs use
`CLAUDE_AUDIT_RERUN=1 tools/checks/claude_external_audit.sh ...`; the wrapper
switches the default model to Sonnet and rejects non-Sonnet reruns unless
`CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1` is set for a final confirmation/P0 dispute.
Code audits refuse large diff prompts by default
(`CLAUDE_AUDIT_MAX_DIFF_LINES`, default 2500); split the PR instead of
overriding except for a named final-release/P0 dispute.
No audit carousel: one first pass, one Sonnet rerun, one Opus final confirmation;
if still blocked, fix or triage the findings instead of relaunching the same gate.
