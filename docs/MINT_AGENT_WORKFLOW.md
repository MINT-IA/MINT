# MINT Agent Workflow

This is the short operating contract. It exists to stop drift, not to create
another planning layer.

## Authority

Order of truth:

1. `rules.md`, when present.
2. `CLAUDE.md`.
3. `AGENTS.md`.
4. `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json`.
5. `.planning/journeys/` Journey OS records, issues, generated views, and
   evidence.
6. `.agents/skills/mint-*`.
7. Current code, tests, scripts, CI, runtime evidence.
8. Engram MCP memories for prior root causes and decisions.

Engram helps recall. It never outranks the repo.

## Journey OS Views

`.planning/journeys/` is the product operating overlay:

- `TODAY.md` is the generated one-screen cockpit for the next vertical.
- `BOARD.md` is the generated priority queue.
- `JOURNEYS.md` is the generated portfolio map.
- `diagrams/system_map.mmd` is the generated Mermaid map of journeys, shared
  routes, surfaces, and issue state.
- `records/*.json` and `issues/*.json` are the editable source of truth.

Generated Journey OS views are never edited by hand. Update the JSON source,
run `python3 tools/checks/journey_os_generate.py`, then verify with
`python3 tools/checks/journey_os_check.py`.

## Default Roster

Permanent Mint agents:

- `mint-lead`: scope, sequencing, merge/no-merge.
- `mint-quality-gate`: auth, privacy, onboarding, runtime proof.
- `mint-mobile`: Flutter only.
- `mint-backend`: FastAPI/backend only.
- `mint-swiss-brain`: Swiss finance and compliance meaning.

No vendor catalog is checked into `.claude/agents/`. External specialists are
allowed only for a specific named gap after the Mint roster has scoped it.

## Canonical Skills

Canonical cross-tool skills live under `.agents/skills/`:

- `mint-operating-gates`
- `mint-flutter-dev`
- `mint-backend-dev`
- `mint-swiss-compliance`

`.claude/skills/mint-*` mirrors are compatibility shims. If they diverge from
`.agents/skills/mint-*`, the `.agents` version wins.

## No-Regression Gate

Before any user-facing auth, onboarding, privacy, navigation, or financial
surface change:

1. Name the concrete user flow.
2. Name the seeded persona if needed.
3. Link or create the Journey OS issue/record when the surface is part of a
   T0/T1 vertical.
4. Run or create the smallest failing contract.
5. Fix the root cause.
6. Run the local tests.
7. Run the simulator/runtime proof.
8. Update the Journey OS evidence/status when the proof changes.
9. Only then open or merge.

TestFlight is distribution evidence, not a debugging harness.

## Runtime Persona

The default critical Mint 2.0 persona is:

`cadre_salarie_lpp_suisse_ready`

Minimum data:

- resident in Switzerland with canton;
- salaried employment;
- monthly or annual income;
- LPP affiliation;
- insured salary or explicit unknown;
- LPP balance or explicit unknown;
- age or birth year;
- civil status;
- 3a status;
- housing, LAMal, and base monthly costs;
- cash/savings status.

This persona must be rich enough for `Aujourd'hui`, `Mon argent`, `Coach`, and
`Explorer` to agree on profile readiness. Empty-profile tests are separate.

## Worktree Discipline

Normal maximum:

- primary checkout;
- clean staging/integration checkout;
- one active feature worktree;
- one urgent hotfix/QA worktree.

Clean merged worktrees should be removed immediately. Dirty worktrees are
classified and preserved until reviewed.

## Branch Inventory Checkpoint - 2026-07-03

`origin/dev` is the current integration base for Mint product work.

Audit evidence from 2026-07-03:

- Remote refs after `git fetch --all --prune`: `origin/dev`,
  `origin/staging`, `origin/main`, `origin/claude/mint-swiss-coach-eu33i7`,
  and `origin/codex/mint-dataquest-transmit-property-clean`.
- `origin/dev` at `4d040cef1` contains the tracked operating system:
  this workflow doc, `.planning/ACTIVE_CONTEXT.*`, Mint agents, Mint skills,
  and active context / phase / rules guards.
- `origin/claude/mint-swiss-coach-eu33i7` at `b11052b61` contains the 5 Codex
  specs but not the tracked operating system. It is `1562` commits behind
  `origin/dev` and `9` ahead.
- `codex/mint-dataquest-transmit-property-clean` at `bc53aedc3` contains a
  DataQuest/property-transmission slice, but it is also based on the old spec
  branch. It is `1562` commits behind `origin/dev` and `10` ahead.
- GitHub had no open PRs, and no PR for either the spec branch or the DataQuest
  branch.
- The main checkout on `claude/mint-swiss-coach-eu33i7` is quarantine material:
  it had `98` unstaged files, `59` staged files, and `2521` untracked files.
- `/private/tmp/mint-dataquest-clean` is clean except `.hypothesis/` and is a
  source for selective porting, not a merge base.
- The clean worktree formerly named `feature-SXX-ui-test-batch` is the safe
  `origin/dev`-based integration surface.
- Dirty worktrees `dev-preflight-20260701` and `mint-journey-os-20260625`
  contain uncommitted deltas and must be audited before any salvage.

Consolidation rule:

- Do not merge old-base branches directly.
- Port useful deltas onto a fresh `origin/dev` branch in small commits.
- Import only Mint-specific local additions after review. Do not import the
  whole untracked vendor skill catalog from `.agents/skills`.
- Treat local dirty checkouts as reference/quarantine until each delta is
  committed, ported, or explicitly dropped.

## Merge Discipline

Allowed:

- feature branches;
- normal PRs;
- merge only after fresh green CI and cited runtime evidence.

Forbidden:

- force push to shared branches;
- merge with missing/red gates;
- direct product fix without a failing test or failing runtime contract;
- large planning artifacts unless the user explicitly asks for one.

## Claude Opus Reviews

Use `tools/claude_review.sh` for external Claude/Opus diff review. Do not run
raw `claude -p --model opus` for repo diffs: Opus can spend thousands of hidden
thinking tokens before printing a normal result, which looks like a hang and can
waste the review window.

The wrapper is intentionally boring:

- stream JSON by default, so thinking-token progress is visible;
- `--safe-mode`, no Claude tools, no session persistence;
- `permission-mode=dontAsk`, not permission bypass;
- hard timeout and budget cap;
- failure if Claude exits without answer text;
- non-zero exit if Claude returns only a partial review after a CLI error.

Typical usage:

```bash
MINT_CLAUDE_MODEL=opus tools/claude_review.sh --cached
MINT_CLAUDE_MODEL=opus tools/claude_review.sh -- apps/mobile/lib/services/coach/
```

## External Standards Baseline

As of 2026-06, Mint mobile work uses:

- OWASP MASVS / MASTG for mobile security verification;
- OWASP Mobile Top 10 2024 for mobile risk classes;
- Apple HIG + App Store account deletion/privacy guidance for iOS UX/compliance;
- Flutter official unit/widget/integration testing docs for the test pyramid;
- Patrol for native mobile E2E where Flutter widget tests cannot prove the path;
- Maestro as smoke/runtime harness where it is already wired;
- NIST SSDF and DORA principles for secure software and operational resilience.

These standards inform gates. They do not justify broad rewrites.
