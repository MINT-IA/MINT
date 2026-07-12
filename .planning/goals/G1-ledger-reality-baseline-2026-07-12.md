# Goal G1 — Ledger Reality Baseline

> Status: ready to implement G1 only after Opus + roster audit.
> Parent plan: `.planning/mint-product-usability-plan-2026-07-12.md`.
> Purpose: make the MINT data spine mechanically reliable before any new P0
> user loop is implemented.

## Objective

Implement the minimum mechanical baseline that lets MINT ask only for missing
or stale facts, reuse existing user history, distinguish user facts from
scenario assumptions, and prevent high-stakes Swiss decisions from reading
duplicated, stale, estimated, or local UI data as if it were canonical.

This goal deliberately does not implement the six P0 loops. It makes those
loops safe to build. G2/G3 cannot start until G1's matrices, executable hard
floor gates, and explicit blockers are checked in.

## Product Invariant

For every future MINT Case, including the 50-60 Retirement Case:

`existing ledger facts -> missing/stale delta -> scenario levers -> result state -> dossier facts`

The Retirement Case is not a "retirement plan" module. A 50-60 user asks
natural questions about AVS, LPP, 3a, rente vs capital, decumulation, housing,
tax, survivor risk, and succession. MINT reuses facts already collected over the
user's life, collects only the missing delta, and produces a dossier that can be
consulted/exported/printed or brought to a specialist.

## G1 Scope

### Must Ship

1. **Ledger gap matrix**
   - Output: `.planning/goals/G1-ledger-gap-matrix.md`.
   - Columns: canonical key, wizard/storage key, `CoachProfile` field path,
     type/unit, allowed sources, freshness tier, confidence weight, write path,
     consumers, P0 loop consumers, current violation, fix ticket/commit.
   - Include the six P0 loops:
     work/first salary, housing/mortgage, retirement/rente-capital, disability,
     succession/transmission, frontalier.

2. **Provider boundary decision**
   - Output: `.planning/goals/G1-provider-boundary.md`.
   - Define the boundary:
     - `CoachProfileProvider`: durable user facts and the only profile write
       spine.
     - `MintStateProvider`: derived read model only.
     - legacy `ProfileProvider`: migrate consumers or ticket each remaining
       consumer before P0 loop work.
     - provider islands: bridge into recompute or classify as non-financial
       cache/reference store.

3. **Scenario lever matrix**
   - Output: `.planning/goals/G1-scenario-lever-matrix.md`.
   - For each P0 loop, classify every local input as either:
     - durable user fact: must be ledger/DataQuest write,
     - scenario lever: local/session/case assumption, never persisted as a fact,
     - derived output: recomputed, never stored as a user fact.

4. **Route state matrix**
   - Output: `.planning/goals/G1-route-state-matrix.md`.
   - For each P0 route/candidate route, define empty, partial, stale, error,
     complete, and return-to-origin behavior.
   - Include current wiring/provenance classification for each route:
     `real-wired`, `local-slider`, `state.extra-domain-payload`,
     `provider-island`, `stub/facade`, or `unknown`.
   - Include required CTA, i18n key placeholder, expected route out, and
     Maestro/Patrol proof target.
   - Exact live candidate routes for G1, reconciled against
     `apps/mobile/lib/routes/route_metadata.dart` on 2026-07-12:
     - Work / first salary: `/first-job`, `/simulator/job-comparison`.
     - Housing / mortgage: `/hypotheque`, `/mortgage/amortization`,
       `/mortgage/epl-combined`, `/epl`.
     - Retirement Case: `/rente-vs-capital`, `/decaissement`,
       `/3a-deep/staggered-withdrawal`, `/succession`.
     - Disability / protection: `/invalidite`, `/disability/insurance`,
       `/disability/self-employed`, `/independants/ijm`.
     - Succession / transmission: `/succession`, `/life-event/donation`.
     - Frontalier: `/segments/frontalier`.
   - Known live domain-data-in-`GoRouter.extra` offenders that must be covered
     by `no_domain_data_in_extra_test` regardless of P0 loop membership:
     `/scan/review`, `/scan/impact`, `/rapport`, `/confidence`.

5. **Mechanical tests/tickets for gates**
   - Hard floor, must be executable and green before G1 is complete:
     - `no_domain_data_in_extra_test` for the documented offender set
       (`/scan/review`, `/scan/impact`, `/rapport`, `/confidence`) plus any G1
       candidate route that passes domain objects through `state.extra`.
     - `ledger_dead_key_test` for P0-loop canonical keys.
   - These tests are expected to be created or extended during G1. Their absence
     at G1 preflight is not a tool failure; G1 completion is blocked until they
     exist, fail on a seeded violation, and pass after the fix.
   - Empty/stub passing tests are invalid. Each hard-floor gate needs either a
     committed negative fixture or documented red -> green evidence in the G1
     scorecard.
   - `ledger_dead_key_test` must load its key set from the ledger gap matrix or
     another checked-in canonical registry produced by G1. It must not duplicate
     a hand-written key list inside the test.
   - May be ticketed only if the ticket uses the blocking template below:
     - `provenance_on_write_test`,
     - `source_crosswalk_test`,
     - `provider_bridge_recompute_test`.
   - Blocking ticket template:
     - id,
     - owner agent,
     - target file(s),
     - expected failing predicate,
     - fixture/input,
     - command that must fail before fix,
     - command that must pass after fix,
     - blocks G2? yes/no,
     - blocks which P0 loop(s),
     - planned implementation slice.

6. **Retirement Case data contract**
   - Output section inside the ledger gap matrix and scenario lever matrix.
   - Required fact groups:
     - minimum facts: age/birth year, canton/commune, civil/partner status,
       target retirement age, AVS years/gaps or expected estimate, LPP balance,
       3a balances, annual expenses/budget floor, explicit liquid cash.
     - useful facts: children/dependants, property/mortgage/debt, other assets,
       other debts, planned large expenses/gifts, spouse/partner pension context.
     - specialist-only or source-sensitive facts: LPP regulation, capital
       withdrawal deadlines, exact conversion/reglement terms, 3a beneficiary
       clauses, testament/pacte/mandat, matrimonial regime, latest tax decision.
   - Current-law/source-date requirement:
     - AVS/LPP/3a/tax constants must carry source, source date, and legal year.
     - If a current-law-sensitive constant lacks a source, the Retirement Case
       renders partial state and open questions, not a confident result.
   - Scenario levers:
     - retirement age,
     - rente/capital/mixed withdrawal ratio,
     - 3a stagger order,
     - budget floor,
     - investment/withdrawal assumptions,
     - planned gifts/advances.
   - Minimum fact gate:
     - If minimum facts are absent or stale, MINT must render the Retirement Case
       partial state plus DataQuest asks. It must not compute rente/capital,
       decumulation, tax, housing, or succession-sensitive conclusions from
       illustrative defaults.

7. **G1 scorecard/evidence**
   - Output:
     `.planning/runtime-evidence/g1-ledger-reality-baseline-20260712/SCORECARD.md`.
   - Must list:
     - commands run,
     - matrices created,
     - hard floor gates status,
     - tickets created,
     - Claude/agent verdicts,
     - unresolved P1/P2,
     - whether G2 is allowed to start.

### May Ship If Low Risk

- A tiny executable test that verifies one concrete dead-key class.
- A tiny static grep script if it is simple, deterministic, and covered by a
  fixture.

### Non-Goals

- No new user-facing P0 loop implementation.
- No broad retirement-planning product.
- No real PDF implementation.
- No account/login work.
- No `.beads/` initialization unless done in its own dedicated PR.

## Execution Sequence

1. Run preflight:
   - `git status --short --branch`
   - `python3 tools/checks/mint_os_doctor.py --repo-only`
   - read `CLAUDE.md`, `AGENTS.md`, `docs/MINT_AGENT_WORKFLOW.md`,
     `.claude/skills/mint-operating-gates/SKILL.md`.

2. Reconcile the five executable specs:
   - `docs/codex/DATA_LEDGER.md`
   - `docs/codex/SCREEN_CONTRACTS.md`
   - `docs/codex/WIRING_GRAPH.mmd`
   - `docs/codex/DATA_QUEST.md`
   - `docs/codex/MAESTRO_FLOWS.md`

3. Reality scan:
   - grep current `ProfileProvider` consumers,
   - grep domain reads from `GoRouter.extra`,
   - grep `wizard_answers_v2` writers,
   - grep `_mapFactKeyToAnswers` and `CoachProfile.fromWizardAnswers` key
     mismatches,
   - grep P0 route candidates and their current state/degraded behavior.

4. Produce the four matrices:
   - ledger gap,
   - provider boundary,
   - scenario lever,
   - route state.

5. Implement the two hard-floor gates and add blocking tickets for the
   remaining gate gaps.

6. Run deterministic repo checks:
   - `python3 tools/checks/mint_os_doctor.py --repo-only`
   - `python3 -m pytest tools/checks/tests/test_codex_spec_reality_contract.py -q`
   - `python3 -m pytest tools/checks/tests/test_ledger_parity.py tools/checks/tests/test_no_bypass_persistence.py -q`
   - `python3 -m pytest tools/checks/tests/test_data_quest_goal_aware_ranking_contract.py tools/checks/tests/test_screen_contracts_route_contract.py -q`
   - `python3 tools/checks/mermaid_render_guard.py --root .`
   - `./tools/mint-routes reconcile`
   - `lefthook run pre-commit`

7. Run external Claude audits:
   - `CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh architecture`
   - `CLAUDE_AUDIT_MODEL=opus CLAUDE_AUDIT_EFFORT=high tools/checks/claude_external_audit.sh product-domain <base-ref>`
   - If code is touched: `tools/checks/claude_external_audit.sh code <base-ref>`

8. Commit/push only after:
   - diff is reviewed,
   - worktree is clean except intended files,
   - all P0/P1 audit findings are fixed or explicitly triaged.

## Agent Roster

- `mint-lead`: owns scope and no-merge if G1 drifts into P0 loop implementation.
- `mint-swiss-brain`: validates retirement, succession, mortgage, disability,
  frontalier, and no-advice boundaries.
- `mint-data-ledger-architect`: owns ledger gap matrix, provenance, source,
  freshness, dead keys, and provider boundary.
- `mint-data-quest-architect`: owns missing/stale/reconfirm prerequisites and
  route-state matrix.
- `mint-mobile`: checks that route states and scenario levers can be implemented
  without local user-fact sliders.
- `mint-quality-gate`: validates commands, evidence, and unimplemented gate
  tickets.
- `mint-external-auditor`: Claude Opus wrapper audit.

## Acceptance Criteria

G1 is complete only when:

- The four planning matrices exist and are specific enough to drive code.
- `no_domain_data_in_extra_test` is executable and green for G1 route candidates.
- `ledger_dead_key_test` is executable and green for P0-loop canonical keys.
- The remaining mechanical gates exist or have checked-in blocking tickets with
  exact failure predicate and acceptance command.
- The Retirement Case is represented as a data/case contract, not a standalone
  retirement product.
- Provider boundary is explicit; `ProfileProvider` and provider islands have
  migration/ticket status.
- No future P0 loop can start without referencing the G1 matrices.
- Mint OS doctor and deterministic contract checks are green.
- Claude Opus architecture and product-domain audits are PASS, or all P0/P1
  findings are fixed.

## Definition Of Done

- Branch contains only G1 docs/tests/scripts needed by this goal.
- Commits are atomic and pushed.
- Final response reports:
  - files changed,
  - commands run,
  - Claude/agent verdicts,
  - unresolved risks,
  - next executable goal.
