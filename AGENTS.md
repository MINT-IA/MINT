# AGENTS.md — MINT Agent Team Workflow

> **Start here, every session.** This file tells any agent (human or LLM)
> how to navigate MINT so the rules in `CLAUDE.md` apply to the right code.
> Team structure + spawning recipes live further down.
> Full ruleset: [`CLAUDE.md`](CLAUDE.md) · Sprint history: [`docs/SPRINT_TRACKER.md`](docs/SPRINT_TRACKER.md).

---

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
| A new route | [`apps/mobile/lib/routes/route_metadata.dart`](apps/mobile/lib/routes/route_metadata.dart) (Phase 32 registry) | `./tools/mint-routes check` | `flutter test test/routes/` |
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

## 🛡 MINT drift-catchers (already roadmapped — use them as soon as shipped)

Until v2.8 Phases 33/34/35 land, the docs in `/docs/*.md` are the manual
rampart. After ship:

- **Phase 33 kill-switches** → any path flag-kill-able from `/admin/flags`
- **Phase 34 lefthook** → 5 mechanical lints block regressions at commit
- **Phase 35 Boucle Daily** → morning sim walk + Sentry pull + auto-PR
  on P0/P1. **The mechanism that catches « an agent broke something
  overnight ».** Mandatory for solo-dev + AI workflow.
- **Phase 30.7 MCP tools** → Swiss constants / banned-terms /
  ARB-parity as on-demand tools (stop bloating agent context with rules)

## 🤝 Session handshake — run these in order, every time

1. Read [`MEMORY.md`](memory/MEMORY.md) (auto-loaded).
2. Read [`CLAUDE.md`](CLAUDE.md) (auto-loaded).
3. Read this file.
4. When the user names a subsystem, read the matching `docs/*.md` **before
   the first code change**.
5. Run the grep verification from the table.
6. *Only then* propose code.

If a step was skipped, revert and redo. That's cheaper than debugging
the ghost in prod.

---

## TEAM STRUCTURE

```
┌──────────────────────────────────────────────┐
│              TEAM LEAD (Opus)                │
│     Orchestrate, review, decide, merge       │
│     Doesn't code directly (except urgency)   │
└─────────┬──────────┬──────────┬──────────────┘
          │          │          │
    ┌─────▼──┐ ┌─────▼──┐ ┌────▼─────┐
    │  DART  │ │ PYTHON │ │  SWISS   │
    │ Agent  │ │ Agent  │ │  BRAIN   │
    │Sonnet  │ │Sonnet  │ │  Opus    │
    └────────┘ └────────┘ └──────────┘
```

---

## SPAWNING AGENTS

### Flutter chantier (UI, widgets, screens)
```
Spawn "dart-agent" with model sonnet.
Read: .claude/skills/mint-flutter-dev/SKILL.md, .claude/skills/mint-test-suite/SKILL.md, CLAUDE.md
Scope: apps/mobile/ only. Never touch backend.
Before changes: flutter analyze && flutter test.
```

### Backend chantier (FastAPI, services, tax)
```
Spawn "python-agent" with model sonnet.
Read: .claude/skills/mint-backend-dev/SKILL.md, .claude/skills/mint-test-suite/SKILL.md, CLAUDE.md
Scope: services/backend/ only. Never touch Flutter.
Before changes: ruff check . && pytest -q.
API change → update tools/openapi/ + SOT.md.
```

### Business/compliance chantier (fiscalité, LPP, compliance)
```
Spawn "swiss-brain" with model opus.
Read: .claude/skills/mint-swiss-compliance/SKILL.md, CLAUDE.md, LEGAL_RELEASE_CHECK.md, visions/
Scope: docs/, education/, decisions/, visions/. No code.
Output: specs with legal sources, test cases, educational text, compliance alerts.
```

---

## WORKFLOW PROTOCOL

### Rule 1: Team Lead doesn't code (except urgency)
Orchestrate, review, merge. Create tasks, verify outputs, make decisions.

### Rule 2: Swiss-Brain validates BEFORE devs implement
```
Swiss-Brain (spec + test cases)
  → Python-Agent (backend implementation)
    → Dart-Agent (UI/screen)
      → Team Lead (review + merge)
```

### Rule 3: Cross-modification boundaries
| Agent | Can modify | Cannot modify |
|-------|-----------|---------------|
| dart-agent | `apps/mobile/` | `services/backend/`, `tools/openapi/` |
| python-agent | `services/backend/`, `tools/openapi/`, `SOT.md` | `apps/mobile/` |
| swiss-brain | `docs/`, `education/`, `decisions/`, `visions/` | Code (`*.dart`, `*.py`) |

### Rule 4: Token economy
- Sonnet by default, Opus for complex reasoning
- One agent at a time unless tasks are independent
- Prefer well-defined short tasks over vague prompts

---

## SKILLS INDEX

| Skill | File | Agent |
|-------|------|-------|
| mint-flutter-dev | `.claude/skills/mint-flutter-dev/SKILL.md` | dart-agent |
| mint-backend-dev | `.claude/skills/mint-backend-dev/SKILL.md` | python-agent |
| mint-swiss-compliance | `.claude/skills/mint-swiss-compliance/SKILL.md` | swiss-brain |
| mint-test-suite | `.claude/skills/mint-test-suite/SKILL.md` | all agents |
| mint-commit | `.claude/skills/mint-commit/SKILL.md` | team-lead |

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
