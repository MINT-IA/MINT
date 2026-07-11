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
  P0 input proof. The CLI may be at `$HOME/.pub-cache/bin/patrol` even when
  `patrol` is not exported in `PATH`.
- Claude CLI `code <base-ref>` audit for pre-merge implementation review when
  possible.
- Claude CLI `product-domain <base-ref>` audit for every Swiss financial
  journey, data-collection, scenario, PDF/dossier, or compliance-sensitive
  product change. It is the independent product-lead + Swiss domain lens:
  life-event fit, law/tax/insurance/prevention assumptions, no-advice framing,
  missing variables, duplicated ledger facts, specialist handoff, and user
  lucidity.
- Engram memory after merge.

## Current Tool Matrix

Run `python3 tools/checks/mint_os_doctor.py --repo-only` to verify checked-in
MINT OS contracts, and full `python3 tools/checks/mint_os_doctor.py` before any
runtime claim about a local tool.

| Tool | Status in clean checkout | Gate use |
|---|---|---|
| Claude CLI | Available after local login | External audit via `tools/checks/claude_external_audit.sh`; use bounded audits (`opus high`, safe mode, strict empty MCP, `--setting-sources user`) by default |
| Engram MCP | Available | Memory |
| Maestro | Available at `~/.maestro/bin/maestro` | Runtime UI proof |
| Patrol CLI | Installed by Dart global tooling; canonical path is `$HOME/.pub-cache/bin/patrol` when not exported in `PATH` | Real mobile input proof for P0 flows; verify with `python3 tools/checks/patrol_tooling_guard.py` before claiming unavailable |
| Mermaid CLI | Executable through `npx --yes @mermaid-js/mermaid-cli` | Graph render proof via `python3 tools/checks/mermaid_render_guard.py` |
| Beads/bug CLI | Installed as `bd` via Homebrew | Agent issue graph; initialize `.beads/` only in a dedicated PR because `bd init` adds a Dolt-backed repo artifact |
| ARB parity | `tools/checks/arb_parity.py` | i18n key parity |

## Interaction Cartography

Mermaid is an executable map, not a decorative diagram and not one giant
screen-by-screen encyclopedia.

- `docs/codex/WIRING_GRAPH.mmd` owns system wiring: routes, providers, source
  of truth, live gaps, and machine-checkable invariants.
- `.planning/journeys/diagrams/data_quest_loop.mmd` owns the progressive
  collection loop: route contract, ledger freshness, DataQuest asks, write-back,
  recompute, and runtime proof.
- `.planning/journeys/diagrams/independent_protection.mmd` owns the current
  independent-worker protection chain: AVS, IJM, independent 3a,
  dividend-vs-salary, voluntary LPP, and the fact-vs-scenario-lever boundary.
- `.planning/journeys/diagrams/health_disability_protection.mmd` owns the
  current employee/self-employed disability chain: salary, liquid savings,
  self-employed income, missing-data routes, and the remaining `/invalidite`
  migration debt.
- Product journeys own their own Mermaid flow when they become P0/P1: data
  collection, decisions, branches, degraded states, PDF handoff, and runtime
  proof links.
- `SCREEN_CONTRACTS.md` owns per-screen interaction contracts: visible controls,
  CTA routes, known/estimated/missing states, recovery states, and required
  ledger facts.
- Interaction registries own fine-grained control metadata:
  `screen_id -> control_id -> action -> route/data read/write -> Maestro/Patrol
  proof`.

Every important button, click, and navigation edge must be traceable through one
of these layers. Do not stuff every micro-interaction into `WIRING_GRAPH.mmd`;
that makes the graph unreadable and guarantees drift. Use established mobile
flow archetypes before inventing a new flow: progressive data collection,
known-fact review/edit, scenario comparison, document extraction, permission or
consent, dossier export, specialist handoff, error recovery, and return to the
ledger.

`python3 tools/checks/mermaid_render_guard.py` renders the wiring graph and the
canonical journey diagrams above. A new P0/P1 product path should add or update
a focused `.mmd` diagram before changing the screen.
`docs/codex/INTERACTION_REGISTRY.md` is active as a YAML/lint pilot:
`interactions/revenu_to_mortgage.yaml` is validated by
`python3 tools/checks/interaction_registry_lint.py`, which generates
`interactions/INDEX.md` and
`.planning/journeys/diagrams/interaction_graph.mmd`. The executor/codegen
remains Proposed until its own go/no-go threshold is met.
`python3 tools/checks/interaction_coverage_audit.py --write` snapshots literal
Flutter navigation references and compares them with declared Interaction
Registry route nodes in
`.planning/journeys/INTERACTION_COVERAGE_AUDIT.md`. It is intentionally a
coverage backlog, not a product-failure gate: use it to choose the next journey
to migrate, and keep it current whenever screens, CTA routes, or registry YAML
change.

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

`product-domain <base-ref>` is not a replacement for `mint-swiss-brain`; it is
the external adversarial pass. It must reject work that is technically wired but
product-stupid: a screen that asks for already-known facts, a Swiss scenario
that misses mandatory variables, a result that hides legal uncertainty, a
comparison that becomes advice/ranking, or a flow that cannot produce a useful
specialist-ready dossier.
