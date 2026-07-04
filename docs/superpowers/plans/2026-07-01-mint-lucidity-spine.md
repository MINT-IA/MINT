# MINT Lucidity Spine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: use `subagent-driven-development`
> when spawning specialists, or `executing-plans` when executing a single-thread
> implementation phase. Track work with checkbox (`- [ ]`) syntax.

**Goal:** Make MINT usable as a Swiss financial lucidity product with progressive
variable acquisition, life-event scenarios, runtime evidence, and specialist
handoff dossiers.

**Architecture:** The product is built around a living variable library. Life
event cases declare the variables they need. Data Quest asks the next useful
question. Scenarios compute educational outputs. Screens render known,
estimated, stale, and missing states. PDFs package the result for a Swiss
specialist. The five `docs/codex/` specs are executable contracts and must be
corrected when code proves they are stale.

**Tech Stack:** Flutter, FastAPI, Python pytest, Dart tests, Maestro, Mermaid
CLI, Claude CLI ultrareview, MINT MCP Swiss constants/compliance tools.

**Timestamp Convention:** Runtime evidence folders use `YYYYMMDDTHHMMSS`
local time, for example `.planning/runtime-evidence/mint-lucidity-phase1-20260701T181500/`.

---

## Product Stance

MINT should not postpone the ownership model. It should postpone only the
production login UX.

For P0, every variable belongs to a local scenario identity:

- `profile_owner_id`: stable owner key, initially generated locally.
- `scenario_id`: stable scenario/case key.
- `source`: user input, fixture, document extraction, backend inference, or
  scenario assumption.
- `confidence`: known, estimated, stale, missing, or contradicted.
- `freshness`: timestamp plus optional expiry rule.

Later account creation claims or migrates the same owner key. P0 must not
require email/password to explore the product, but it must behave as if user
data is owned, versioned, and portable from day one.

## P0 Acceptance Definition

MINT is "usable" for this goal when these paths are green:

1. **First salary / tax / 3a**: user starts with age, canton, salary; MINT
   explains tax/3a levers and asks only the next useful question.
2. **Household / property / mortgage**: user adds household, budget, property
   or purchase intent; MINT explains affordability and missing data.
3. **Transmit property complex-case proof**: user adds property value,
   mortgage, children/heirs, retained habitation/usufruct; MINT ranks parent
   retirement affordability, family equalization, cantonal tax review, and
   formalities. Full notarial/tax optimization is P1; P0 proves the dynamic
   data-acquisition and dossier pattern.

Every path must produce:

- live variables in `DATA_LEDGER`
- Data Quest case entry
- backend scenario or mobile `financial_core` calculation
- cross-stack golden fixture when a calculation exists in both stacks
- screen state with known/estimated/stale/missing affordances
- PDF/dossier payload
- automated tests
- Mermaid graph compile
- Maestro runtime proof at the phase where the UI exists
- Claude CLI external audit triage

## Canonical Agent Roster

The permanent Mint roster is canonical in `AGENTS.md` under "Permanent MINT
Lucidity Roster". This plan names roles, but `AGENTS.md` is the source of truth
for agent files and routing. If a Mint agent file is unavailable, fall back to
the existing GSD agent with the closest ownership and record the fallback in the
phase evidence.

Phase 1 Data Ledger gates are defined in
`docs/codex/DATA_LEDGER_GATE_SPEC.md`.

Each Mint agent must run the repository handshake before acting:

- read `CLAUDE.md`
- read `AGENTS.md`
- read this plan when working on the lucidity spine
- run `git status --short`
- run the relevant grep/test row from `AGENTS.md`

## Phase Gate Protocol

No phase may be accepted with unresolved critical or high findings.

Each phase produces:

- `SCORECARD.md` in a timestamped runtime-evidence folder
- `cli_exception_consumed: true/false` in that scorecard
- cumulative CLI exception state in `.planning/runtime-evidence/cli_exception_ledger.json`
- `mint-quality-gate` co-signature and `mint-lead` countersignature
- tests actually run, with command and result
- spec/code/doc files touched
- unresolved findings grouped CRITICAL/HIGH/MEDIUM/LOW
- `mint-quality-gate` score out of 10
- Claude CLI audit output or an explicit blocker if the CLI is unavailable

Minimum phase score:

- Phase 0: `>= 8.0/10` because it bootstraps gates, then blocks Phase 1 until
  all critical/high findings are resolved.
- Phases 1-6: `>= 9.0/10`.

`mint-external-auditor` is a hard gate: unresolved critical/high findings block
acceptance. Claude CLI unavailability must be validated by `mint-lead` in the
scorecard with the exact command, failure mode, and retry plan. That exception
can defer one phase gate at most and cannot be used for final acceptance.

Maestro gates are incremental:

- Phase 0: tool availability, `MAESTRO_FLOWS.md` presence, and explicit
  executable Maestro YAML count. Current minimum is 0 because no flow YAML is
  versioned yet.
- Phase 2: case registry can name or generate the expected flows.
- Phase 4: partial UI flow proof for at least one P0 case.
- Phase 6: full P0 runtime proof.

Compliance wording gates:

- run banned-term check on French user-facing outputs
- run accent-pattern check on French generated/static text
- assert no personalized financial/legal advice wording
- include assumptions, missing data, and specialist handoff language

## Phase 0: Agent And Gate Bootstrap

**Acceptance:** score `>= 8.0/10`, no unresolved critical/high finding, scorecard
filed, `cli_exception_consumed` recorded.

- [x] Create permanent Mint agent files under `.claude/agents/`.
- [x] Update `AGENTS.md` so future agents start from the Mint roster.
- [x] Add `tools/checks/claude_external_audit.sh`.
- [x] Add `tools/checks/mint_lucidity_gate.sh`.
- [x] Verify `claude --help`, `claude ultrareview --help`, `maestro --version`,
  and Mermaid compile.
- [x] Run Claude CLI bootstrap architecture audit and resolve all
  critical/high findings before Phase 1.
- [x] Produce Phase 0 scorecard.

Phase 0 audit is allowed to use a gate script that is created in Phase 0. That
audit gates Phase 1; it is not evidence that the gate existed before bootstrap.

## Phase 1: Variable Library Contract

**Acceptance:** score `>= 9.0/10`, no unresolved critical/high finding, Claude
CLI output filed, `cli_exception_consumed` recorded, and `tools/checks/mint_lucidity_gate.sh phase1`
passes with a real Maestro YAML. The phase gate must fail while
`DATA_LEDGER_BASELINE_AUDIT.md` has `status: baseline-audit-open` or any
unresolved CRITICAL/HIGH heading.

- [ ] Convert `DATA_LEDGER` into a typed variable registry contract.
- [ ] Produce the Phase 1 Task 0 baseline audit required by
  `docs/codex/DATA_LEDGER_GATE_SPEC.md`.
- [ ] Add scenario-owner persistence contract:
  `profile_owner_id`, `scenario_id`, source, confidence, freshness, updated_at.
- [ ] Enforce `mint-data-ledger-architect` as tie-break authority for cross-stack
  ownership schema conflicts.
- [ ] If schema ownership and Swiss numerical authority conflict in the same
  decision, `mint-lead` convenes `mint-data-ledger-architect` and
  `mint-swiss-brain`; the resolution must be recorded in the scorecard.
- [ ] If those agents still cannot converge after convening, `mint-lead` casts
  the deciding vote and records the rationale in the scorecard.
- [ ] Add gates for backend allowlist, mobile answer switch, model reads, and
  screen consumers.
- [ ] Add provenance/freshness/confidence requirements for variables used by
  P0 cases.
- [ ] Add cross-stack fixture format for variables shared by backend scenarios
  and Flutter `financial_core`.
- [ ] Document that when cross-stack numerical fixtures diverge,
  `mint-swiss-brain` supplies the canonical Swiss value and both stacks adapt.
- [ ] Implement the minimum cross-stack fixture schema from
  `docs/codex/DATA_LEDGER_GATE_SPEC.md`.
- [ ] Run compliance lint for any French user-facing label introduced by the
  variable registry.
- [ ] Add and execute a Phase 1 Maestro YAML that hits Data Ledger ownership
  state and asserts a non-null confidence field.
- [ ] Verify with pytest plus targeted Flutter provider/model tests.
- [ ] Run Phase 1 Claude CLI audit and scorecard.

## Phase 2: Data Quest Case Registry

**Acceptance:** score `>= 9.0/10`, no unresolved critical/high finding, Claude
CLI output filed, at least one runnable P0 Maestro YAML created or executed.

- [ ] Create case specs for `first_salary_tax`, `buy_property`, and bounded
  `transmit_property`.
- [ ] For each case, define minimum variables, useful variables, blocking guard
  questions, enrichment questions, target screen, PDF section, and Maestro flow
  id.
- [ ] Add a stub dossier payload contract per P0 case owned by
  `mint-lucidity-pdf`.
- [ ] Add tests that assert next-question priority changes when a variable is
  answered.
- [ ] Add a Phase 2 gate proving every P0 case references existing ledger keys.
- [ ] Run at least one executable Maestro YAML for a P0 flow before Phase 2
  closes.
- [ ] Before any Android acceptance claim for a feature built on Phase 1
  contracts, re-run the Phase 1 runtime contract on an Android emulator.
  If no Android SDK/emulator is available, record that as a blocking
  infrastructure gap in the Phase 2 scorecard; iOS-only Phase 1 evidence is
  not Android acceptance.
- [ ] Run Phase 2 Claude CLI audit and scorecard.

## Phase 3: Scenario Outputs

**Acceptance:** score `>= 9.0/10`, no unresolved critical/high finding, Claude
CLI output filed, deterministic scenario fixtures green.

- [ ] Ensure `/api/v1/scenarios` produces substantive outputs for all P0 cases.
- [ ] Reuse existing pure services and `financial_core` concepts; backend and
  mobile do not share code, so parity is enforced by golden fixtures and schema
  tests, not by informal formula duplication.
- [ ] Treat these Flutter `financial_core` entry points as the initial canonical
  grep list before adding any parallel formula: `AvsCalculator.computeMonthlyRente`,
  `AvsCalculator.computeCouple`, `LppCalculator.projectToRetirement`,
  `LppCalculator.computeSalaireCoordonne`,
  `HousingCostCalculator.compute`, `HousingCostCalculator.estimateRetirementExpenses`,
  `NetIncomeBreakdown.compute`, `RetirementTaxCalculator.estimate3aTaxSaving`,
  `RetirementTaxCalculator.estimateMarginalRate`.
- [ ] Add deterministic backend tests and cross-stack fixture tests.
- [ ] Run Swiss constants and compliance/banned-term checks for user-facing
  output.
- [ ] Run Phase 3 Claude CLI audit and scorecard.

## Phase 4: Mobile Lucidity UX

**Acceptance:** score `>= 9.0/10`, no unresolved critical/high finding, Claude
CLI output filed, partial P0 Maestro proof filed.

- [ ] Wire P0 cases into mobile screens with local/scenario-first flow.
- [ ] Render known, estimated, stale, missing, and next-question states.
- [ ] Preserve optional auth; no account creation gate in P0.
- [ ] Add widget/provider/route tests.
- [ ] Run at least one partial P0 Maestro runtime proof.
- [ ] Run Phase 4 Claude CLI audit and scorecard.

## Phase 5: Specialist Dossier

**Acceptance:** score `>= 9.0/10`, no unresolved critical/high finding, Claude
CLI output filed, dossier payload contract green for all P0 cases.

- [ ] Build PDF/dossier payload for each P0 case.
- [ ] Include variables, sources, assumptions, confidence, missing data, risks,
  specialist questions, and documents to prepare.
- [ ] Add tests for payload shape, regulatory disclaimers, banned terms, and
  accent quality.
- [ ] Run Phase 5 Claude CLI audit and scorecard.

## Phase 6: Full Acceptance

**Acceptance:** score `>= 9.0/10`, no unresolved critical/high finding, Claude
CLI code audit filed, full P0 Maestro/runtime proof filed.

- [ ] Run targeted backend/mobile/spec tests.
- [ ] Build iOS simulator.
- [ ] Run all P0 Maestro flows.
- [ ] Compile `docs/codex/WIRING_GRAPH.mmd`.
- [ ] Run `tools/checks/claude_external_audit.sh code dev`.
- [ ] Produce `.planning/runtime-evidence/mint-lucidity-spine-<timestamp>/SCORECARD.md`.
- [ ] `mint-lead` may accept only with score `>= 9.0/10` and no unresolved
  critical/high audit finding.
