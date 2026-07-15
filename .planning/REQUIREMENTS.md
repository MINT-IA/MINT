# Requirements: v3.0 Product Reality — Six Boucles, Un Dossier

Defined: 2026-07-12

Status legend: `[ ]` pending, `[x]` verified complete. A checked requirement
must cite current-SHA evidence in its phase verification/scorecard.

## Migration and operating authority

- [ ] **MIG-01**: v2.8 remains archived as incomplete; no unfinished legacy
  requirement is silently marked complete or deleted.
- [ ] **MIG-02**: Every v2.8 CTX/TOOL/OBS/MAP/FLAG/GUARD/LOOP/FIX item maps to
  revalidate, implement, transversal, defer-with-gate, or retire-with-proof.
- [ ] **MIG-03**: July 2026 product plan is the sole product authority for G2-G6.
- [ ] **MIG-04**: Historical route and debt counts are remeasured before use.
- [ ] **MIG-05**: Chat Vivant remains after G6 and must converge with the one
  ledger/Case/dossier spine.

## Phase 37 — G1 runtime readiness

Every ticket requirement below resolves the identically named row in
`.planning/goals/G1-blocking-gate-tickets.md`. Checkbox state is fail-closed
and must match `.planning/runtime-evidence/phase-37/ticket-evidence.json`:
only machine-evidence `green` is checked.

- [x] **RDY-SOURCE-01**: Authoritative mobile-to-backend source crosswalk.
- [x] **RDY-LDG-02**: Canonical semantic enum round-trip.
- [x] **RDY-LDG-03**: Every live P0 key writes, reloads, and reaches its consumer.
- [x] **RDY-LDG-04**: Missing/default-sensitive facts remain unknown.
- [x] **RDY-LDG-05**: Direct fields never mutate a different financial meaning.
- [x] **RDY-LDG-06**: AVS gaps are order-independent and status is separate from years.
- [x] **RDY-LDG-06A**: Certificate-backed AVS missingness remains null and self/household/marital-cap readiness stays person-owned.
- [x] **RDY-LDG-07**: Duplicate mortgage keys reconcile deterministically.
- [x] **RDY-PROV-01**: Value and provenance persist atomically on write.
- [x] **RDY-PROV-02**: Certificate facts and provenance survive restart.
  Evidence: [`G1-PROV-02` verification](runtime-evidence/phase-37/prov-02/verification.md).
- [x] **RDY-PROV-03**: Tax facts include typed source date and legal year.
- [ ] **RDY-SCN-01**: Scenario assumptions/results are isolated by scenario ID.
- [ ] **RDY-BND-01**: Legacy profile consumers migrate to canonical semantics.
- [x] **RDY-BND-02**: Partner-owned facts bridge and recompute through a real scoped consumer.
- [x] **RDY-BND-02A**: Partner facts require the named legal/privacy decision, implemented accountability, field scope, notice and revocation.
- [ ] **RDY-BND-03**: Budget facts bridge to CoachProfile and derived state.
- [x] **RDY-BND-04**: CoachProfile mutation recomputes MintUserState exactly once.
- [ ] **RDY-BND-05**: Documents remain references; confirmed facts enter the ledger.
- [ ] **RDY-BND-06**: Financial plan freshness follows the profile input hash.
- [ ] **RDY-COACH-01**: Live salary, LPP and 3a coach amounts write canonical facts with exact units and provenance.
- [ ] **RDY-COACH-02**: Valid route intent remains visible and recoverable when the profile is empty.
- [ ] **RDY-FRONT-01**: Residence country, work country, and work canton are distinct.
- [ ] **RDY-RET-REF-01**: Retirement precision requires specialist-grade references.
- [ ] **RDY-RET-STATE-01**: Unavailable retirement projections offer cause-specific target-date recovery without re-asking ready AVS facts.
- [ ] **RDY-SUCCESSION-01**: Estate output never infers absent regime/instruments.
- [x] **RDY-AVS-01**: Couple AVS law uses person-first, status- and scale-aware semantics.
- [ ] **RDY-AVS-02**: Official 13th-pension evidence survives restart and renders separate monthly, December and annual cash flows.
- [x] **RDY-AVS-03**: Unofficial gap counts remain unpriced until an official scale or amount exists.
- [ ] **RDY-FRESH-01**: Stale values remain visible for reconfirmation.
- [ ] **RDY-RETURN-01**: Collection returns safely to the exact originating case.
- [ ] **RDY-RUNTIME-01**: Maestro and Patrol prove persistence, restart, and recompute.
- [ ] **RDY-GATE-01**: All 31 ticket rows become evidence-backed GREEN; Phase 37
  score >=9.0 and G2 decision explicitly becomes YES.

## Phase 38 — Mint OS operating runway and v2.8 convergence

- [ ] **OS-01**: Repo/full Doctor, Patrol guard, Mermaid guard, routes, interaction
  registry, persistence gates, lefthook, and Claude wrapper form one versioned
  zero-drift phase contract.
- [ ] **OS-02**: Deterministic Swiss constants access uses backend constants as SOT,
  has a real caller, and is covered by parity tests; duplicate MCP proposals are
  retired with evidence.
- [ ] **OS-03**: Route flags redirect before auth, refresh reactively, converge with
  backend state, and prove OFF->ON->OFF.
- [ ] **OS-04**: Default-off kill switches cover every new product path and the old
  P0 paths named by FIX-01..04.
- [ ] **OS-05**: Guardrails are non-vacuous: bare catch, hardcoded FR, accents, ARB
  parity, proof-of-read/bypass policy, route/interaction/persistence drift.
- [ ] **OS-06**: Old FIX-01..04/09 are proved green or repaired TDD-first; current
  counts replace stale debt numbers.
- [ ] **OS-07**: Daily dogfood skeleton runs before G3; full closure is tracked in G5.
- [ ] **OS-08**: Phase 32 AMBER risks are re-proved or explicitly carried with owner,
  predicate, and later closure phase.

## Phase 39 — G2 DataQuest Core and CaseRegistry

- [ ] **DQ-01**: `DataQuestRequest` contract includes target/origin route, case ID,
  required/useful fields, goal, and clock.
- [ ] **DQ-02**: `Ask` contract includes collect/reconfirm mode, ledger/input key,
  prior value/provenance, required flag, benefit text, tone, and return URI.
- [ ] **DQ-03**: `CaseDefinition` includes guards, quests, levers, target screens,
  and dossier sections.
- [ ] **DQ-04**: Fresh complete facts generate zero asks.
- [ ] **DQ-05**: Missing facts generate exactly the missing delta.
- [ ] **DQ-06**: Stale facts use one-tap reconfirm without blank re-entry.
- [ ] **DQ-07**: Guard quests run before high-stakes root results.
- [ ] **DQ-08**: Partial state renders immediately with range and confidence.
- [ ] **DQ-09**: Scenario levers remain outside CoachProfile.
- [ ] **DQ-10**: Maestro proves return-to-origin and Patrol proves real iPhone input.

## Phases 40-45 — six G3 loops

Every loop must meet the shared contract **LOOP-P0-01..08**:

- [ ] **LOOP-P0-01**: Real entry point from Aujourd'hui, Coach, or Explorer.
- [ ] **LOOP-P0-02**: Swiss-brain contract defines variables, law/tax/insurance
  caveats, no-advice language, and specialist handoff before code.
- [ ] **LOOP-P0-03**: Ledger and DataQuest contracts collect only missing/stale data.
- [ ] **LOOP-P0-04**: Empty, partial, stale, complete, and error/recovery states pass.
- [ ] **LOOP-P0-05**: Scenario levers never overwrite durable facts.
- [ ] **LOOP-P0-06**: Dossier-ready summary uses the same sourced ledger facts.
- [ ] **LOOP-P0-07**: Mermaid journey, interaction registry, unit/widget/integration,
  Maestro, and Patrol evidence ship in the same slice.
- [ ] **LOOP-P0-08**: Claude code/product-domain/architecture findings have no open P0/P1.

Loop-specific outcomes:

- [ ] **WORK-01**: First salary/tax/AVS/LPP/first-3a orientation is usable and
  educational from entry to dossier.
- [ ] **HOUSING-01**: Affordability, own funds, mortgage burden, EPL, and bank
  questions use canonical household/property/debt facts.
- [ ] **RETIRE-01**: Age 50-60 retirement case covers AVS timing, rente/capital/mix,
  3a sequencing, liquidity, post-retirement budget/mortgage, tax, and survivor
  tradeoffs without recommendations.
- [ ] **DISABILITY-01**: Illness/accident/disability income gap covers AI, LPP, IJM,
  LAA, cash runway, and private coverage with explicit uncertainty.
- [ ] **SUCCESSION-01**: Transmission/donation case includes retirement-liquidity
  guard, estate facts, heirs/regime/instrument references, and specialist questions.
- [ ] **FRONTIER-01**: Frontalier case distinguishes residence/work jurisdiction,
  permit, insurance option, source tax, telework, family, and pension affiliation.

## Phase 46 — G4 Dossier/PDF

- [ ] **DOS-01**: One dossier schema records facts, source, freshness, confidence,
  assumptions, scenario levers, open questions, checklist, and documents.
- [ ] **DOS-02**: All six P0 loops generate sections from the same ledger facts.
- [ ] **DOS-03**: PDF/export clearly separates facts, estimates, and assumptions.
- [ ] **DOS-04**: Not-advice and specialist-confirmation framing is explicit.
- [ ] **DOS-05**: Privacy/retention and banned-term gates cover exported content.
- [ ] **DOS-06**: PDF visual verification and Claude product-domain audit pass.

## Phase 47 — G5 Runtime proof and drift gates

- [ ] **PROOF-01**: Daily dogfood loop runs deterministically and records reports.
- [ ] **PROOF-02**: Every P0 loop has current-SHA Maestro and Patrol evidence.
- [ ] **PROOF-03**: Every live user-visible route passes or is killed safely with
  degraded/recovery behavior.
- [ ] **PROOF-04**: Sentry pull, thresholds, retention, and no-spam auto-PR policy work.
- [ ] **PROOF-05**: Mermaid, routes, interaction registry, persistence, ARB, accent,
  banned terms, rates, privacy, and lefthook gates pass.
- [ ] **PROOF-06**: Phase 32 AMBER risks and all carried v2.8 runtime items close.
- [ ] **PROOF-07**: Legacy redirects are removed only after 30-day zero-traffic proof.
- [ ] **PROOF-08**: Full targeted/global suites and audits have no open P0/P1.

## Phase 48 — G6 beta cohesion

- [ ] **BETA-01**: Aujourd'hui ranks the next valuable action from ledger facts.
- [ ] **BETA-02**: Coach routes to and back from all six loops.
- [ ] **BETA-03**: Explorer remains discovery, not a parallel product spine.
- [ ] **BETA-04**: Dossier is durable memory of clarified decisions.
- [ ] **BETA-05**: First value is reachable in under three minutes.
- [ ] **BETA-06**: Returning users reuse known fresh facts without re-entry.
- [ ] **BETA-07**: Complex users see partial truth/open questions, not fake certainty.
- [ ] **BETA-08**: Shared patterns, accessibility, i18n, privacy, and calm copy pass.

## Phase 49 — Chat Vivant convergence

- [ ] **CHAT-01**: The planted Chat Vivant specs are reconciled against the proven
  ledger/Case/screen/dossier architecture before implementation.
- [ ] **CHAT-02**: Streaming message/artifact architecture has one source of truth
  and no duplicate calculator or scenario state.
- [ ] **CHAT-03**: Inline insight, interactive scene, and full-screen canvas levels
  are accessible, localized in six languages, kill-switchable, and tested.
- [ ] **CHAT-04**: Coach streaming paths, creator-device runtime, Maestro/Patrol,
  privacy, and external audits pass.

## Phase 50 — final program release

- [ ] **REL-01**: Full backend/mobile/tools/check suites pass with honest skips/debt.
- [ ] **REL-02**: Route-wide inventory has no facade, orphan, unrecovered, or unsafe path.
- [ ] **REL-03**: Six loops work entry-to-dossier on current release SHA.
- [ ] **REL-04**: Mint OS Doctor and every wrapper/gate pass without substitution.
- [ ] **REL-05**: External Opus architecture, code, and product-domain audits pass.
- [ ] **REL-06**: No open P0/P1; lower findings have explicit owner and disposition.
- [ ] **REL-07**: Every phase scorecard is >=9.0 and final score is >=9.5.
- [ ] **REL-08**: Branch is clean with atomic commits and pushed evidence boundaries.

## Traceability

| phase | requirement groups |
|---|---|
| 37 | RDY-* |
| 38 | MIG-*, OS-* |
| 39 | DQ-* |
| 40 | LOOP-P0-*, WORK-01 |
| 41 | LOOP-P0-*, HOUSING-01 |
| 42 | LOOP-P0-*, RETIRE-01 |
| 43 | LOOP-P0-*, DISABILITY-01 |
| 44 | LOOP-P0-*, SUCCESSION-01 |
| 45 | LOOP-P0-*, FRONTIER-01 |
| 46 | DOS-* |
| 47 | PROOF-* |
| 48 | BETA-* |
| 49 | CHAT-* |
| 50 | REL-* |

---
*Last updated: 2026-07-12*
