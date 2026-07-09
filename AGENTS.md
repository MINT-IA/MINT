# AGENTS.md — MINT Agent Team Workflow

> **Start here, every session.** This file tells any agent (human or LLM)
> how to navigate MINT so the rules in `CLAUDE.md` apply to the right code.
> Team structure + spawning recipes live further down.
> Full ruleset: [`CLAUDE.md`](CLAUDE.md) · Roadmap: [`docs/ROADMAP_V2.md`](docs/ROADMAP_V2.md).
> Agent/Codex/Claude workflow: [`docs/MINT_AGENT_WORKFLOW.md`](docs/MINT_AGENT_WORKFLOW.md).

---

## Operating Mode - Clean Mint Base

At G0, MINT is rebuilt from the checkout currently mounted at
`/Users/julienbattaglia/Desktop/MINT.nosync`. `MINT 2` is only a Finder symlink
to that checkout. Archive folders and safety bundles are not active workspaces.
Always verify the active branch and cleanliness with `git status --short
--branch`; do not infer state from Finder folder names.

Default rule: one real user flow, one clean worktree, one short PR, one
runtime proof when UI is touched. Do not merge oversized draft PRs directly;
extract reviewable slices.

Permanent MINT roster:

| Agent | File | Owns |
|---|---|---|
| `mint-lead` | `.claude/agents/mint-lead.md` | Scope, sequencing, merge/no-merge |
| `mint-quality-gate` | `.claude/agents/mint-quality-gate.md` | Tests, runtime evidence, scorecards |
| `mint-mobile` | `.claude/agents/mint-mobile.md` | Flutter app changes |
| `mint-backend` | `.claude/agents/mint-backend.md` | FastAPI/backend/data changes |
| `mint-swiss-brain` | `.claude/agents/mint-swiss-brain.md` | Swiss finance/compliance meaning |
| `mint-data-ledger-architect` | `.claude/agents/mint-data-ledger-architect.md` | Variable ledger, provenance, freshness |
| `mint-data-quest-architect` | `.claude/agents/mint-data-quest-architect.md` | Progressive questions and Case registry |
| `mint-lucidity-pdf` | `.claude/agents/mint-lucidity-pdf.md` | Specialist-ready dossier/PDF |
| `mint-external-auditor` | `.claude/agents/mint-external-auditor.md` | Claude CLI review loop |

Canonical skills live in `.claude/skills/mint-*`:

| Skill | Use |
|---|---|
| `mint-operating-gates` | Mandatory before user-facing/auth/privacy/runtime/financial work |
| `mint-flutter-dev` | Flutter implementation in `apps/mobile/` |
| `mint-backend-dev` | Backend implementation in `services/backend/` |
| `mint-swiss-compliance` | Swiss regulatory/compliance review |

External or generic specialists are not active by default. Use them only for a
named gap after the MINT roster scopes the work.

### External Claude Audit

Run external reviews through `tools/checks/claude_external_audit.sh`, never raw
`claude -p`. The wrapper is the operating contract: Opus high for first-pass
bounded reviews, Sonnet high for same-gate reruns with `CLAUDE_AUDIT_RERUN=1`,
strict empty MCP, `--setting-sources user`, no session persistence, and a code
diff budget via `CLAUDE_AUDIT_MAX_DIFF_LINES`. Use `--effort max` only for a
named final-release/P0 dispute with `CLAUDE_AUDIT_ALLOW_MAX=1`.

If a rerun needs Opus for final confirmation or a P0 dispute, set
`CLAUDE_AUDIT_ALLOW_NON_SONNET_RERUN=1`. If a named debug run must load
project/local settings, set `CLAUDE_AUDIT_ALLOW_PROJECT_SETTINGS=1`. Do not add
a max-turn cap; this Claude CLI does not expose `--max-turns`, and the wrapper
rejects `CLAUDE_AUDIT_MAX_TURNS` so agents cannot rely on a fake safety knob.

## 🗺 Before you edit X, read Y, grep Z

Pre-flight for any code change. If the agent can't state which row applies
after reading the diff plan, **stop and ask** — coding blind costs 10× the
time of looking at the map.

| You're touching… | Read first | Verify with grep | Run tests |
|---|---|---|---|
| `apps/mobile/lib/screens/coach/**` or `services/backend/app/api/v1/endpoints/coach_chat.py` | [`docs/coach-tool-routing.md`](docs/coach-tool-routing.md) | `grep INTERNAL_TOOL_NAMES services/backend/app/services/coach/coach_tools.py` | `flutter test test/services/coach/ test/widgets/coach/` |
| `apps/mobile/lib/providers/coach_profile_provider.dart` or `models/coach_profile.dart` | [`docs/data-flow.md`](docs/data-flow.md) | `grep "answers\[" apps/mobile/lib/models/coach_profile.dart \| sort -u` | `flutter test test/providers/` |
| `apps/mobile/lib/services/financial_core/**` | [`docs/calculator-graph.md`](docs/calculator-graph.md) | `grep -rn "YourCalculator\." apps/mobile/lib` | `flutter test test/services/financial_core/` |
| `apps/mobile/lib/screens/document_scan/**` | [`docs/data-flow.md`](docs/data-flow.md) §Scan pipeline | `grep "updateFrom.*Extraction" apps/mobile/lib/providers/coach_profile_provider.dart` | `flutter test test/services/document_parser/ test/providers/` |
| `apps/mobile/lib/screens/budget/**` | [`docs/data-flow.md`](docs/data-flow.md) §Budget flow | `grep "q_housing_cost\|q_lamal_premium\|_coach_depenses" apps/mobile/lib` | `flutter test test/screens/budget/` |
| A new route | [`apps/mobile/lib/routes/route_metadata.dart`](apps/mobile/lib/routes/route_metadata.dart) (Phase 32 registry) | `./tools/mint-routes reconcile` | `flutter test test/routes/` |
| `apps/mobile/lib/l10n/app_*.arb` | ARB parity across 6 langs | verify same keys in fr/en/de/es/it/pt | `flutter gen-l10n && flutter test` |
| Any financial calculation | [`CLAUDE.md`](CLAUDE.md) §4 + [`docs/calculator-graph.md`](docs/calculator-graph.md) | `grep -rn "_calculate\|_compute" apps/mobile/lib/services/ \| grep -v financial_core/` | `flutter test test/services/financial_core/` |

---

## ⚡ Vibe-coding discipline (7 rules, non-negotiable)

These are the rules that separate shipping fintech teams (Stripe, Wise,
Revolut) from ones that turn in circles. Apply religiously.

1. **TDD first.** Write the failing test (or contract shape) before the
   code. Agents fill specs well; they *design* them poorly. The failing
   test is the ground truth for « done ».
2. **< 300 lines per PR.** Beyond that, you and the agent lose the plot.
   Run `git diff --shortstat origin/dev...HEAD` before pushing. Split if
   over.
3. **Atomic, revertable commits.** One concern per commit. If `git revert
   <sha>` would break something orthogonal, split.
4. **Grep before assume.** If you name a symbol (method, var, tool, ARB
   key, endpoint), you must have grepped it **in this session**. No
   memory-based coding. Memory lies.
5. **Verify the diff, not the explanation.** Agents routinely claim they
   did X when they did Y. `git diff --stat` + read the diff before every
   commit. Don't trust LLM summaries of their own work.
6. **Evals for LLM paths.** Any code depending on Claude / SLM / RAG
   needs golden I/O pairs that fail loudly on regression. Pattern in
   `.claude/skills/autoresearch-prompt-lab/`. Extend to coach narrative,
   extraction, fallback templates.
7. **Feature flag + kill switch for every new path.** Default `FeatureFlags.xxx
   = false` until ready. Phase 33 mechanizes this — until shipped,
   manual flag.

## ❌ Anti-patterns to REFUSE (even when an agent suggests them)

- An abstraction for 2 duplicates — three similar lines beat a
  prematurely-extracted helper. See [`CLAUDE.md`](CLAUDE.md) « Don't add
  features beyond what the task requires ».
- A `try/catch` fallback « au cas où » for a case that can't happen —
  trust invariants. Don't mask drift with silent catches.
- A service with no caller, a widget with no consumer, a route with no
  renderer — **façade sans câblage**, #1 MINT bug-driver (cf
  `memory/topics/feedback_facade_sans_cablage_absolu.md`). If shipped,
  the next audit kills it anyway.
- Comments that restate *what* the code does. Comments explain *why* —
  hidden constraints, invariants, workarounds.
- Tests that assert LLM mock output (testing the mock, not the code).

## 🛡 MINT drift-catchers (use checked-in gates first)

The repo currently has a small checked-in gate set plus a broader roadmap.
Use what exists, and record missing tools instead of pretending they ran.

- **Feature flags / kill switches** → every new product path must be disableable
- **Lefthook** → memory retention, map freshness hints, ARB parity
- **Daily loop roadmap** → morning sim walk + Sentry pull + auto-PR
  on P0/P1. **The mechanism that catches « an agent broke something
  overnight ».** Mandatory for solo-dev + AI workflow.
- **Future MCP/tools** → Swiss constants / banned-terms / Patrol / Beads /
  Mermaid gates once installed and wired in this checkout

## 🤝 Session handshake — run these in order, every time

1. Read curator memory when present; otherwise use Engram context plus checked-in docs.
2. Read [`CLAUDE.md`](CLAUDE.md) (auto-loaded).
3. Read this file.
4. Read [`docs/MINT_AGENT_WORKFLOW.md`](docs/MINT_AGENT_WORKFLOW.md).
5. Read [`.claude/skills/mint-operating-gates/SKILL.md`](.claude/skills/mint-operating-gates/SKILL.md).
6. When the user names a subsystem, read the matching `docs/*.md` **before
   the first code change**.
7. Run the grep verification from the table.
8. *Only then* propose code.

If a step was skipped, revert and redo. That's cheaper than debugging
the ghost in prod.

---

## TEAM STRUCTURE

```
mint-lead
  ├─ mint-swiss-brain
  ├─ mint-data-ledger-architect
  ├─ mint-data-quest-architect
  ├─ mint-backend
  ├─ mint-mobile
  ├─ mint-lucidity-pdf
  ├─ mint-quality-gate
  └─ mint-external-auditor
```

---

## SPAWNING AGENTS

### Flutter chantier (UI, widgets, screens)
```
Spawn "mint-mobile" with model sonnet.
Read: .claude/agents/mint-mobile.md, .claude/skills/mint-flutter-dev/SKILL.md, .claude/skills/mint-operating-gates/SKILL.md, CLAUDE.md
Scope: apps/mobile/ only. Never touch backend.
Before changes: flutter analyze && flutter test.
```

### Backend chantier (FastAPI, services, tax)
```
Spawn "mint-backend" with model sonnet.
Read: .claude/agents/mint-backend.md, .claude/skills/mint-backend-dev/SKILL.md, .claude/skills/mint-operating-gates/SKILL.md, CLAUDE.md
Scope: services/backend/ only. Never touch Flutter.
Before changes: ruff check . && pytest -q.
API change → update tools/openapi/ + SOT.md.
```

### Business/compliance chantier (fiscalité, LPP, compliance)
```
Spawn "mint-swiss-brain" with model opus.
Read: .claude/agents/mint-swiss-brain.md, .claude/skills/mint-swiss-compliance/SKILL.md, CLAUDE.md, LEGAL_RELEASE_CHECK.md, visions/
Scope: docs/, education/, decisions/, visions/. No code.
Output: specs with legal sources, test cases, educational text, compliance alerts.
```

---

## WORKFLOW PROTOCOL

### Rule 1: Team Lead doesn't code (except urgency)
Orchestrate, review, merge. Create tasks, verify outputs, make decisions.

### Rule 2: Swiss meaning validates BEFORE devs implement
```
mint-swiss-brain (spec + test cases)
  → mint-data-ledger-architect / mint-data-quest-architect (variables + asks)
    → mint-backend (backend implementation)
      → mint-mobile (UI/screen)
        → mint-quality-gate + mint-external-auditor (review)
          → mint-lead (merge/no-merge)
```

### Rule 3: Cross-modification boundaries
| Agent | Can modify | Cannot modify |
|-------|-----------|---------------|
| mint-mobile | `apps/mobile/` | `services/backend/`, `tools/openapi/` |
| mint-backend | `services/backend/`, `tools/openapi/`, `SOT.md` | `apps/mobile/` |
| mint-swiss-brain | `docs/`, `education/`, `decisions/`, `visions/` | Code (`*.dart`, `*.py`) |
| mint-data-ledger-architect | `docs/codex/`, ledger schemas/tests | Product UI without a caller |
| mint-data-quest-architect | `docs/codex/`, question plans/tests | Duplicate variable aliases |
| mint-lucidity-pdf | PDF/dossier contracts and surfaces | Financial law constants |
| mint-quality-gate | Evidence, tests, scorecards | Feature code outside fixes for gates |
| mint-external-auditor | Audit prompts/evidence | Product implementation |

### Rule 4: Token economy
- Sonnet by default, Opus for complex reasoning
- One agent at a time unless tasks are independent
- Prefer well-defined short tasks over vague prompts

---

## SKILLS INDEX

| Skill | File | Agent |
|-------|------|-------|
| mint-operating-gates | `.claude/skills/mint-operating-gates/SKILL.md` | all agents |
| mint-flutter-dev | `.claude/skills/mint-flutter-dev/SKILL.md` | mint-mobile |
| mint-backend-dev | `.claude/skills/mint-backend-dev/SKILL.md` | mint-backend |
| mint-swiss-compliance | `.claude/skills/mint-swiss-compliance/SKILL.md` | mint-swiss-brain |

---

## DREAM TEAM (extended agents)

Launchable in parallel for specialized tasks:

| Agent | Mission | When |
|-------|---------|------|
| QA Agent | Test coverage, edge case fuzzing | After each sprint |
| i18n Agent | ARB file completion (6 languages) | Parallel to sprints |
| Accessibility Agent | WCAG 2.1 AA audit | Before beta |
| Compliance Guard Agent | ComplianceGuard + HallucinationDetector | S34 (completed) |
| OCR Agent | Document parsing pipeline | S42-S45 (completed) |
| ASO Agent | App Store/Play Store listings | 4 weeks before launch |
| Legal Agent | nLPD/CGU/Privacy audit | Before launch |

Each agent reads `CLAUDE.md` first. Team Lead reviews all output before merge.
