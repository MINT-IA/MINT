# AGENTS.md — MINT Agent Team Workflow

> **Start here, every session.** This file tells any agent (human or LLM)
> how to navigate MINT so the rules in `CLAUDE.md` apply to the right code.
> Team structure + spawning recipes live further down.
> Full ruleset: [`CLAUDE.md`](CLAUDE.md) · Planning index: [`.planning/INDEX.md`](.planning/INDEX.md).
> Agent/Codex/Claude/GSD workflow: [`docs/MINT_AGENT_WORKFLOW.md`](docs/MINT_AGENT_WORKFLOW.md).

---

## Operating Mode — Stop The Bleeding

MINT is in stabilization mode. Do not start new product work until the active
runtime gate for the touched surface exists and can be run by an agent.

Default rule: **one real user flow, one clean worktree, one short PR, one
runtime proof**. No new planning matrix, no speculative roadmap file, no
TestFlight-as-debugging.

Canonical iOS runtime proof device: **iPhone 17 Pro** on the local Mac Mini
simulator stack. If that simulator is unavailable, use an iPhone 15/14-class
fallback and record the reason in the evidence. Compact legacy iPhone targets
are not accepted for canonical Mint runtime evidence or new Maestro, Patrol,
`flutter run`, walker, screenshot, or dogfood proof. Android runtime stays a
compatibility gate, not the active iOS product proof.

The default permanent roster is:

| Agent | File | Owns |
|---|---|---|
| `mint-lead` | `.claude/agents/mint-lead.md` | Scope, sequencing, merge/no-merge |
| `mint-quality-gate` | `.claude/agents/mint-quality-gate.md` | Auth/privacy/onboarding/runtime gates |
| `mint-mobile` | `.claude/agents/mint-mobile.md` | Flutter app changes |
| `mint-backend` | `.claude/agents/mint-backend.md` | FastAPI/backend/data changes |
| `mint-swiss-brain` | `.claude/agents/mint-swiss-brain.md` | Swiss finance/compliance meaning |

No imported vendor agent catalog is active by default. External specialists may
be used only for an explicit, named gap after the Mint roster has scoped it.

Canonical skills live in `.agents/skills/mint-*`:

| Skill | Use |
|---|---|
| `mint-operating-gates` | Mandatory before user-facing/auth/privacy/runtime work |
| `mint-flutter-dev` | Flutter implementation in `apps/mobile/` |
| `mint-backend-dev` | Backend implementation in `services/backend/` |
| `mint-swiss-compliance` | Swiss regulatory/compliance review |

`.claude/skills/mint-*` entries are thin compatibility mirrors. If mirror and
canonical content diverge, `.agents/skills/mint-*` wins.

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
2. **Dynamic PR-size budget, not a hard cap.** Always run
   `git diff --shortstat origin/dev...HEAD` before pushing. For routine
   bugfix/doc/guard work, use ~300 changed lines as the default review budget.
   For one coherent vertical, runtime proof, generated view, or evidence update,
   exceeding that budget is allowed when splitting would make review, rollback,
   or verification worse. In that case, isolate generated/evidence files and
   write the reason in the PR body. If non-generated product changes span
   multiple surfaces, split unless `mint-lead` or Julien explicitly accepts the
   larger unit.
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

1. Read curator memory from `$HOME/.claude/projects/-Users-julienbattaglia-Desktop-MINT-nosync/memory/MEMORY.md` when present. If missing, report it, recover with Engram MCP (`mem_context` / `mem_search`) plus checked-in docs, and continue unless the task explicitly depends on that private memory.
2. Read [`CLAUDE.md`](CLAUDE.md) (auto-loaded).
3. Read this file.
4. Read [`docs/MINT_AGENT_WORKFLOW.md`](docs/MINT_AGENT_WORKFLOW.md).
5. Read `.agents/skills/mint-operating-gates/SKILL.md`.
6. Read [`.planning/ACTIVE_CONTEXT.md`](.planning/ACTIVE_CONTEXT.md) and [`.planning/ACTIVE_CONTEXT.json`](.planning/ACTIVE_CONTEXT.json) when present; they are the current session router.
7. Run `python3 tools/checks/active_context_guard.py`.
8. Run `python3 tools/checks/phase_contract_guard.py`.
9. Run `python3 tools/checks/mint_rules_guard.py`.
10. Run `python3 tools/checks/journey_os_check.py`; `.planning/journeys/`
   is the canonical Journey OS board, issue registry, evidence map, and
   priority queue for vertical work.
11. Run `python3 tools/checks/workflow_contract_guard.py`.
12. Run `python3 tools/checks/verify_phase_acceptance.py` when an active
   `SPEC.md` has a `verify` block.
13. When the user names a subsystem, read the matching `docs/*.md` **before
   the first code change**.
14. Run the grep verification from the table.
15. *Only then* change code.

If a step was skipped, revert and redo. That's cheaper than debugging
the ghost in prod.

## Routing

Default sequence:

`mint-lead` -> `mint-quality-gate` -> `mint-mobile` / `mint-backend` /
`mint-swiss-brain` -> `mint-quality-gate`.

Use external specialists only for a named gap. Do not start multiple agents
unless tasks have disjoint files or disjoint read-only questions.

## Worktree Limit

Maximum normal state:
- primary dirty checkout;
- one clean staging/integration checkout;
- one active feature checkout;
- one urgent hotfix/QA checkout.

Everything else must be removed once clean and merged. Dirty worktrees are
classified, not deleted.
