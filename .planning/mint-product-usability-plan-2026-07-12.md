# MINT Product Usability Plan — 2026-07-12

> Purpose: define the next execution program to make MINT genuinely usable as a
> Swiss financial lucidity product. This is a planning/audit artifact, not a
> shipped product contract.

## North Star

MINT becomes a Swiss financial lucidity system that helps a user understand a
life decision with their own data, see what is known/missing/estimated/stale,
collect only the missing delta, compare compliant scenarios, and leave with a
specialist-ready dossier.

Product spine:

`ledger variable -> DataQuest ask -> Case/scenario -> screen state -> dossier/PDF -> runtime proof`

Non-negotiables:

- One source of truth: screens read user facts from `CoachProfileProvider` /
  `MintStateProvider`, not local sliders or `GoRouter.extra`.
- Data collection is triggered by a decision, never by a generic profile form.
- Swiss metier correctness blocks acceptance even if code/tests pass.
- No advice/ranking/guarantee language; MINT frames decisions and questions.
- Every P0 route has known/missing/estimated/stale states and a return path.
- Every P0 slice gets unit/widget tests, Maestro/Patrol proof, Mermaid map, and
  Claude `code` + `product-domain` audits when financial/law-sensitive.

## Strategic Diagnosis

The repo is rich, but usability is not equal to feature count. MINT currently
has many screens, calculators, services, and docs. The next phase must stop
expanding breadth and instead harden a small number of real user loops until
they work end to end.

The main risk is not "missing screens"; it is product incoherence:

- duplicated user facts,
- local illustrative inputs masquerading as user data,
- screens that compute before required Swiss variables exist,
- routes without degraded states,
- scenario results not feeding a dossier,
- tests proving widgets but not user decisions.

## Program Shape

Use six intermediate goals rather than one endless mega-goal. The sequence
below integrates the 2026-07-12 internal agent reviews and Claude Opus
architecture audit. The most important correction from those audits is this:
DataQuest/Case is not "nearly finished"; it is a real G2 core build.

### G1 — Ledger Reality Baseline

Outcome: MINT knows which facts are canonical, where they are written, and which
screens still bypass or duplicate them.

Deliverables:

- Run/reconcile the five `docs/codex/` specs against live code.
- Produce a `ledger_gap_matrix`: field, source, write path, consumers, freshness,
  confidence, current violations.
- Remove or quarantine high-risk local user-data controls from P0 screens.
- Stabilize provenance: value, source, updatedAt, sourceDate when applicable.
- Add durable `dataSourceDates` / `__provenance` persistence and backend
  `data_sources`, `data_updated`, `data_source_dt` contracts where the current
  write path is incomplete.
- Add a field freshness adapter so DataQuest can distinguish missing, fresh, and
  stale facts deterministically.
- Fix dead keys before building new flows. Example class of bug: a writer stores
  one key while `CoachProfile.fromWizardAnswers` reads another.
- Replace domain data in `GoRouter.extra` with ids/session ids for known
  offenders such as scan review/impact paths.
- Establish the "scenario lever vs user fact" rule per screen.
- Produce a `scenario_lever_matrix` so scenario assumptions never become profile
  facts.

Acceptance:

- No P0 journey uses a local slider for a durable user fact.
- Every P0 field has exactly one canonical key and one legal write path.
- Tests cover at least: explicit zero, missing, stale, estimated, sourced fact.
- `ledger_dead_key_test`, `provenance_on_write_test`,
  `source_crosswalk_test`, and `no_domain_data_in_extra_test` exist or the gap
  is explicitly tracked before any P0 loop implementation.

### G2 — DataQuest Core + CaseRegistry MVP

Outcome: when a user opens a decision and facts are missing/stale, MINT asks the
right next question, not a giant form.

Deliverables:

- Build `DataQuest.planQuest` and `CaseRegistry` as new core product
  infrastructure. Do not treat this as finishing an existing service.
- Define:
  - `DataQuestRequest`: `targetRoute`, `originRoute`, `caseId?`,
    `requiredFields[]`, `usefulFields[]`, `goal?`, `now`.
  - `Ask`: `ledgerKey`, `mode collect|reconfirm`, `blockType`, `inputKey`,
    `priorValue?`, `source?`, `updatedAt?`, `required`, `tone`,
    `benefitText`, `returnUri`.
  - `CaseDefinition`: `id`, `rootRoute`, `guardQuests[]`, `quests[]`,
    `scenarioLevers[]`, `targetScreens[]`, `dossierSections[]`.
- Support `AskMode.collect`, `AskMode.reconfirm`, and partial graceful mode.
- Route `?inputKey=` to exact field collection with return-to-origin.
- Add case-level quests for heavy events.
- Add goal-aware ranking without hiding high-severity mandatory facts.
- Keep scenario levers outside `CoachProfile`; store them in case/session
  assumptions and dossier context only.

Acceptance:

- Opening a P0 route with all facts fresh triggers zero asks.
- Missing facts trigger exactly the missing asks.
- Stale facts use one-tap reconfirm, not blank re-entry.
- GuardQuests run before root scenario results when the case requires them.
- A route target renders immediately in partialState with range + confidence
  rather than blocking behind a wall of questions.
- Maestro proves return-to-origin after collection.
- Patrol proves at least one real input path on iPhone 14+.

### G3 — Five P0 User Loops

Outcome: five complete product loops become genuinely usable and impressive.
Each loop is a separate reviewable slice with design contract, ledger contract,
DataQuest contract, dossier section, and runtime proof in the same slice.

P0 loops:

1. Work / first salary / tax and first 3a orientation.
   - Swiss decision: understand salary, canton, taxes, AVS/LPP basics, first 3a
     tradeoffs without over-complexity.
   - Required facts: gross salary, canton/commune when needed, age/birth year,
     employment rate, 13th salary/bonus if used.

2. Housing affordability / mortgage readiness.
   - Swiss decision: understand affordability, own funds, mortgage burden, EPL
     implications, and what to ask the bank.
   - Required facts: income, liquid cash explicit amount, pension assets if EPL,
     existing debt, housing costs, canton/commune, household status.

3. Disability / income protection.
   - Swiss decision: understand the income gap if illness/accident/disability
     hits, and what is known about AI, LPP invalidity, IJM, LAA, cash runway,
     and private coverage.
   - Required facts: employment status, salary or self-employed income, explicit
     liquid cash, fixed monthly charges, children, LPP certificate facts where
     relevant, IJM current coverage assumptions, accident/private coverage
     flags.

4. Succession / property transmission / donation.
   - Swiss decision: understand the forces involved before transferring or
     donating a home: net estate mass, mortgage, heirs, marital regime, liquidity
     of parents, right of habitation/usufruct as scenario levers, and specialist
     questions.
   - Required facts: age, canton, marital/partner status, children/heirs,
     property value, mortgage balance, broader estate facts when available, 3a/
     LPP beneficiary context, testament/pacte/mandat flags.
   - Blocking guard: run retirement affordability/liquidity guard before any
     gift/transmission result.

5. Cross-border worker / frontalier.
   - Swiss decision: understand why residence country, work canton, permit,
     health-insurance option, tax-source status, telework, family, and pension
     affiliation change the answer.
   - Required facts: residence country, nationality/permit G where relevant,
     work canton/commune, employer, income/currency, telework days, tax-source
     status, LAMal/CMU/right-of-option history, family status, AVS/LPP/3a
     eligibility context.

Recommended implementation order:

1. Work / first salary: lightest proof of DataQuest.
2. Housing / mortgage: first high-value asset loop.
3. Disability / protection: high-stakes protection loop.
4. Succession / transmission: notarial/family guardQuest loop.
5. Frontalier: first-class loop only after Swiss-brain spec and dedicated ledger
   keys exist.

Acceptance:

- Each loop starts from a real entry point (`Aujourd'hui`, `Coach`, or
  `Explorer`), collects missing facts, recomputes, explains the result, and
  ends in a dossier-ready summary.
- Each loop has a Mermaid journey map and interaction registry rows.
- Each loop has at least one "empty ledger", "partial ledger", "complete
  ledger", and "stale fact" test.
- Each loop has a route x state x proof matrix: empty, partial, stale, complete,
  error.
- Each loop has Maestro proof and at least one Patrol real input proof in the
  same slice, not deferred to a later global hardening phase.

### G4 — Lucidity Dossier/PDF MVP

Outcome: MINT produces a usable handoff for a notary, tax specialist, bank,
pension fund, insurance broker, or fiduciary.

Deliverables:

- Dossier schema: facts used, source/freshness/confidence, assumptions, scenario
  levers, open questions, specialist checklist, documents to prepare.
- PDF/export for the five P0 loops.
- Clear "not advice" and "to confirm with specialist" framing.
- No unsupported Swiss-law conclusions.

Acceptance:

- Every P0 loop can generate a dossier section from the same ledger facts.
- PDF contains no hidden raw estimates presented as facts.
- Claude product-domain audit explicitly reviews the dossier as a Swiss metier
  artifact.

### G5 — Runtime Proof and Drift Gates

Outcome: the product is not accepted by explanation; it is accepted by evidence.

Deliverables:

- Maestro flows for every P0 loop.
- Patrol input proof for at least one critical data collection per loop.
- Mermaid render guard for journey diagrams.
- Route/data parity tests for every touched route.
- Beads issue graph only after a dedicated `.beads/` init PR, not as incidental
  product work.

Acceptance:

- Evidence stored under `.planning/runtime-evidence/`.
- `mint_os_doctor.py`, route reconcile, relevant tests, and lefthook pass.
- Claude `code` and `product-domain` audits return PASS or all findings are
  explicitly triaged.
- Existing global analyzer debt is reported honestly. A slice can pass with
  targeted analyze/tests green only if unrelated global warnings are documented
  and not worsened.

### G6 — Product Polish and Beta Usability

Outcome: MINT feels like a coherent product rather than a catalog.

Deliverables:

- Design contracts are not delayed until G6; they are required before each G3
  implementation. G6 is for cross-loop cohesion and final beta polish.
- `Aujourd'hui` shows the next most valuable action based on known ledger facts.
- `Coach` can route to the five P0 loops and back.
- `Explorer` remains secondary: discovery, not the main product spine.
- Dossier tab becomes the durable memory of what MINT has clarified.
- Copy follows MINT identity: calm, direct, non-shaming, no jargon wall.
- Shared mobile patterns are enforced: `RouteStateScaffold`,
  `LedgerFactTile`, `ScenarioLeverPanel`, `DecisionHero`,
  `DataQuestReturn`, `DossierReadySummary`, and one primary CTA per screen.

Acceptance:

- A new user can get value in under 3 minutes with minimal data.
- A returning user sees known facts reused, not re-asked.
- A complex user sees partial truth and open questions, not fake certainty.

## Execution Order

1. G1 Ledger Reality Baseline.
2. G2 DataQuest Core + CaseRegistry MVP.
3. G3 Loop A: work / first salary / tax / first 3a.
4. G3 Loop B: housing affordability / mortgage.
5. G3 Loop C: disability / income protection.
6. G3 Loop D: succession / property transmission / donation.
7. G3 Loop E: frontalier.
8. G4 Dossier/PDF MVP.
9. G5 Runtime proof hardening.
10. G6 Beta usability polish.

## Agent Operating Model

For every slice:

1. `mint-lead` defines the smallest valuable user loop.
2. `mint-swiss-brain` validates Swiss metier, no-advice framing, variables, and
   specialist handoff.
3. `mint-data-ledger-architect` validates keys, provenance, freshness,
   consumers, and no duplication.
4. `mint-data-quest-architect` validates missing/stale/reconfirm sequence.
5. `mint-backend` implements backend/API only when needed.
6. `mint-mobile` implements UI only after ledger/DataQuest contracts are clear.
7. `mint-lucidity-pdf` implements dossier output.
8. `mint-quality-gate` runs tests, Maestro, Patrol, Mermaid, route parity.
9. `mint-external-auditor` runs Claude `code` + `product-domain`.

## Definition of 9.5/10

MINT is 9.5/10 for this phase when:

- Five P0 loops are usable from entry to dossier.
- No P0 loop asks for a fresh known fact twice.
- No P0 loop computes a high-stakes result from illustrative defaults.
- Each financial result shows known/missing/estimated/stale and confidence.
- Each P0 loop has runtime proof on iPhone 14+.
- Each P0 loop passes Swiss metier audit, not just system/code audit.
- The repo has clean commits, clean branch state, and evidence artifacts.

## Explicit Non-Goals

- No production account/login build in this phase beyond what is required for
  local/demo persisted user facts.
- No new broad catalog of Swiss topics.
- No advisor marketplace.
- No real institutional API integration.
- No "perfect" legal/tax engine. The goal is lucidity, assumptions, questions,
  and specialist-ready handoff.
