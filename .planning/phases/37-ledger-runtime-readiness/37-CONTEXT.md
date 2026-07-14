# Phase 37: Ledger Runtime Readiness — Context

**Gathered:** 2026-07-12

**Status:** Ready for planning

**Source:** PRD express path from
`.planning/goals/G1-blocking-gate-tickets.md`, under the active autonomous goal.

<domain>
## Phase Boundary

Implement and prove all 31 tickets currently in the G1 blocking registry. This
phase repairs the canonical ledger, provenance, provider bridges, domain
references, freshness, scenario isolation, return-to-origin, and persistence
proof required for G2 readiness.

G2, CaseRegistry, DataQuest core, and every G3 product loop remain out of scope.
The phase ends only with 31/31 evidence-backed GREEN rows, runtime evidence,
external audits, a score >=9.0, and an explicit `G2 allowed: YES` decision.

</domain>

<decisions>
## Implementation Decisions

### Evidence and TDD

- **D-01:** Every named ticket contract is created before its production change.
  Prefer a genuine semantic RED followed by GREEN. If the checkout already
  satisfies the new contract, record `baseline_green` plus a negative fixture
  or mutation control that makes the same assertion fail for the intended
  business reason. Never weaken working code or fabricate a RED.
- **D-02:** A test written after the implementation, a vacuous gate, an absent
  negative/mutation control for `baseline_green`, or evidence from another SHA
  does not count.
- **D-03:** Store exact commands, evidence mode (`red_green` or
  `baseline_green_controlled`), RED/GREEN or control/GREEN logs, SHA,
  affected-suite output, audit manifests, and scorecard under
  `.planning/runtime-evidence/phase-37/<wave-or-ticket>/`.
- **D-04:** Update a registry row from `ticket_only` only after its GREEN command
  and dependency gates pass. Do not batch-mark unfinished tickets.

### Dependency order

- **D-05:** Wave 1 is foundations: SOURCE-01 may execute independently; all
  CoachProfile model mutations are serialized; BND-04 freezes recompute semantics.
- **D-06:** Wave 2 freezes atomic provenance before restart/tax/umbrella ledger
  tests: PROV-01 -> PROV-02 -> PROV-03 -> LDG-03.
- **D-07:** Wave 3 bridges provider islands only after provenance and recompute
  contracts are stable: BND-02/03 -> BND-05 -> BND-06 -> BND-01.
- **D-08:** Wave 4 Swiss/domain specs may be reviewed in parallel, but
  FRONT-01, RET-REF-01, and SUCCESSION-01 Dart model changes are serialized.
- **D-09:** Wave 5 implements SCN-01 before FRESH-01 and RETURN-01. Wave 6 is
  RUNTIME-01 plus phase-wide audits and score.

### Ownership and architecture

- **D-10:** `mint-data-ledger-architect` owns key/provenance/freshness/scenario
  contracts; `mint-swiss-brain` owns financial/legal meaning;
  `mint-backend` owns backend code; `mint-mobile` owns Dart code;
  `mint-quality-gate` owns evidence; `mint-lead` owns final acceptance.
- **D-11:** `CoachProfileProvider` is the durable fact write boundary and
  `MintStateProvider` is the derived read model. Provider caches do not become
  competing financial sources of truth.
- **D-12:** Scenario assumptions and derived values always carry scenario
  identity and never overwrite shared certified facts.
- **D-13:** Missing/default-sensitive data remains unknown. Display estimates
  are not completion facts.
- **D-14:** Document objects remain references; only confirmed extracted facts
  enter the ledger with provenance.

### Mint OS and acceptance

- **D-15:** Every wave starts with repo Doctor and scope baseline. Runtime work
  runs full Doctor, checked-in Maestro watchdog, Patrol guard/CLI, Mermaid guard,
  route reconcile when touched, relevant persistence/ledger gates, and lefthook.
- **D-16:** External Claude runs only through
  `tools/checks/claude_external_audit.sh`. `code` and `product-domain` are
  required for financial changes; architecture is required for phase closure.
- **D-17:** An external audit quota failure is logged and retried; it is never
  reported as PASS and cannot be carried into final Phase 37 acceptance.
- **D-18:** Any new product path is deferred to Phase 38+ and requires a
  default-off kill switch. Phase 37 repairs existing ledger behavior only.
- **D-19:** Phase score uses the fixed 10-point MINT rubric and must be >=9.0
  with zero open P0/P1. G2 remains NO until that is true.
- **D-20:** Mint OS commands and wrappers checked into this repository remain
  authoritative throughout execution. Generic GSD helpers may sequence work,
  but may not replace Doctor, Maestro watchdog/environment, Patrol guard/CLI,
  Mermaid guard, route reconciliation, lefthook, or the Claude audit wrapper.
- **D-21:** Baselines are task-local and ownership-local. Every mint-mobile
  dispatch touching `coach_profile.dart` or `coach_profile_provider.dart` reads
  the applicable SOTs, runs the mandated live-key grep, then full
  `flutter analyze && flutter test` before RED/code. Every mint-backend dispatch
  runs full `ruff check . && pytest -q` before RED/code. Evidence from another
  task or agent is not reusable as that task's baseline.
- **D-22:** RUNTIME-01 uses a versioned and tested Mint OS orchestrator with two
  separate Patrol processes on one UDID/bundle/SHA, both `--no-uninstall`, and
  an archived successful `simctl terminate` between write and read. Maestro is
  pinned to the same UDID. A single test that kills then continues cannot prove
  process death.
- **D-23:** Audit manifests are fail-closed: top-level `required_modes` plus
  `runs[]`, exactly one accepted unique run per required mode, and complete
  wrapper command/model/base/head/exit-0/non-empty-output/findings/severity
  counts. Every implementation wave requires code + product-domain; final
  closure additionally requires architecture.
- **D-24:** Existing gsd-code-review, gsd-validate-phase, gsd-secure-phase, and
  conditional design-review may supplement execution only after Mint OS is
  GREEN. They cannot replace MINT gates or permanent agents. New MINT skills
  are Phase 38 work and must be versioned, tested, and Doctor-visible.

### the agent's Discretion

- Exact private helper names and fixture builders, provided canonical public
  keys/types and the one-write-boundary rule remain unchanged.
- How RED/GREEN logs are grouped inside the required evidence directory.
- Whether adjacent model tickets share one compilation step, while retaining
  one independently reproducible RED and GREEN command per ticket.

</decisions>

<canonical_refs>
## Canonical References

### Operating contract

- `AGENTS.md` — permanent roster, sequencing, Mint OS, TDD, cross-boundaries.
- `CLAUDE.md` — architecture, financial, compliance, and tool quick reference.
- `.claude/skills/mint-operating-gates/SKILL.md` — mandatory operating gates.
- `docs/MINT_AGENT_WORKFLOW.md` — permanent-agent and audit workflow.

### Phase contracts

- `.planning/goals/G1-blocking-gate-tickets.md` — current 31 predicates and commands.
- `.planning/goals/G1-ledger-gap-matrix.md` — canonical P0 key/write/consumer registry.
- `.planning/goals/G1-provider-boundary.md` — provider ownership and recompute edges.
- `.planning/goals/G1-scenario-lever-matrix.md` — fact versus lever boundary.
- `.planning/goals/G1-route-state-matrix.md` — route/state/recovery expectations.
- `.planning/goals/v3-product-reality-migration-manifest-2026-07-12.md` — waves and gates.

### Data and runtime architecture

- `docs/data-flow.md` — mobile data flow and provider boundaries.
- `docs/codex/DATA_LEDGER.md` — ledger contract and provenance.
- `docs/codex/DATA_QUEST.md` — downstream missing/stale consumer contract.
- `docs/codex/WIRING_GRAPH.mmd` — system wiring SOT.
- `docs/codex/SCREEN_CONTRACTS.md` — downstream state contract.
- `docs/codex/MAESTRO_FLOWS.md` — runtime proof registry.

### Live code entry points

- `apps/mobile/lib/models/coach_profile.dart`
- `apps/mobile/lib/providers/coach_profile_provider.dart`
- `apps/mobile/lib/providers/mint_state_provider.dart`
- `services/backend/app/services/confidence/enhanced_confidence_service.py`
- `services/backend/app/models/profile_model.py`

</canonical_refs>

<specifics>
## Specific Ideas

The smallest coherent implementation slice is `G1-SOURCE-01`: add the missing
backend test first, capture the import/mapping RED, then implement one
authoritative five-source mobile crosswalk whose destinations all exist in
`DATA_SOURCE_ACCURACY`. The three backend-only sources must have no mobile
antecedent. No UI/runtime proof is required for this first slice.

Phase 37 planning must create six executable plan waves, with smaller plans
inside a wave when file ownership or reviewability demands it. No plan may mix
unrelated backend and mobile implementation concerns.

### Business waves mapped to GSD plans

| business dependency wave | GSD plan/wave | scope |
|---|---|---|
| Gate infrastructure | 37-00 / wave 0 | Progressive non-vacuous evidence schema; no RDY requirement closes here. |
| 1A source | 37-01 / wave 1 | SOURCE-01. |
| 1B/1C model foundations | 37-02 / wave 2 | LDG-02/04/05/06/07 and BND-04. |
| 2 provenance | 37-03 / wave 3 | PROV-01/02/03 and LDG-03. |
| 3 provider bridges | 37-04 / wave 4 | BND-02/03/05/06/01. |
| 4 Swiss references | 37-05 / wave 5 | FRONT-01, RET-REF-01, SUCCESSION-01. |
| 5 behavior | 37-06 / wave 6 | SCN-01, FRESH-01, RETURN-01. |
| 6 runtime/acceptance | 37-07 / wave 7 | RUNTIME-01 and RDY-GATE-01; final G2 decision only. |

</specifics>

<deferred>
## Deferred Ideas

- Phase 38: deterministic Mint OS tools, flags, guardrails, old P0 fixes, daily
  loop skeleton.
- Phase 39: G2 DataQuest and CaseRegistry.
- Phases 40-50: all G3-G6, Chat Vivant, and release work.

</deferred>

<scope_fence>
## Scope Fence

No G2/G3 product implementation, no new screen/catalog breadth, no account
expansion, no institutional API, no Beads initialization, no raw audit command,
and no unversioned replacement for a Mint OS tool.

</scope_fence>

---

*Phase: 37-ledger-runtime-readiness*

*Context gathered: 2026-07-12 via PRD express path and permanent-agent convergence*
