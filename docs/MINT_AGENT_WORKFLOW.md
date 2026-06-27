# MINT Agent Workflow

This is the short operating contract. It exists to stop drift, not to create
another planning layer.

## Authority

Order of truth:

1. `rules.md`, when present.
2. `CLAUDE.md`.
3. `AGENTS.md`.
4. `.planning/ACTIVE_CONTEXT.md` and `.planning/ACTIVE_CONTEXT.json`.
5. `.agents/skills/mint-*`.
6. `.planning/journeys/` Journey OS records, issues, board, and evidence.
7. Current code, tests, scripts, CI, runtime evidence.
8. Engram MCP memories for prior root causes and decisions.

Engram helps recall. It never outranks the repo.

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
