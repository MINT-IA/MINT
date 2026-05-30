---
phase: mon-argent-budget-cleanup-v2
plan: 16
status: planned
created_at: 2026-05-26
branch: codex/mon-argent-budget-cleanup-v2
type: expert-audit-plan
---

# Plan 16 - Expert Audit: Mint Operating Model

## Goal

Define the next operating model for Mint before more UI/code changes: how data,
budget, patrimoine, three Swiss pillars, trajectories, coach memory and
navigation should work together without duplicate read models or untraceable
numbers.

## Inputs Read

- `CLAUDE.md` rules: financial core reuse, no retirement-first framing, i18n,
  no banned terms, deterministic verification.
- `docs/data-flow.md`: `wizard_answers_v2` is local source of truth;
  `CoachProfile.fromWizardAnswers` is the canonical in-memory profile.
- `docs/calculator-graph.md`: financial calculations must live in
  `apps/mobile/lib/services/financial_core/`; UI surfaces should consume
  aggregators/read models.
- `docs/BUDGET_VIVANT_ARCHITECTURE.md`: Budget A, Budget B, gap, cap and
  coach injection are the intended common layer.
- `docs/BUDGET_LIVING_ENGINE_IMPLEMENTATION_SPEC.md`: original spec expected
  `RetirementBudgetService`, `BudgetSnapshot`, `BudgetLivingEngine`, Pulse and
  coach injection.
- `docs/vision/MON_ARGENT-PROPOSAL.md`: previous Mon Argent options, including
  tab dissolution vs patrimoine panel.
- Local Cleo screenshots in `CLEO/`: goals, A-to-B path, proactive nudges,
  simple conversational framing.
- Current code surfaces:
  - `apps/mobile/lib/services/budget_living_engine.dart`
  - `apps/mobile/lib/models/budget_snapshot.dart`
  - `apps/mobile/lib/services/data_spine/data_spine_service.dart`
  - `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart`
  - `apps/mobile/lib/screens/budget/budget_screen.dart`
  - `apps/mobile/lib/services/coach/context_injector_service.dart`
  - `apps/mobile/lib/services/coach/conversation_memory_service.dart`
- Market reference points:
  - Cleo official positioning: spending tracking, goals, conversational money
    coach, memory/patterns.
  - VZ and Swiss Life public retirement/budget material: budget, revenues,
    expenses, assets, pension planning, taxes and retirement trajectory.

Claude CLI note: the attempted read-only Claude panel call hung with no stdout
after more than one minute and had to be killed. Treat Claude review as an
infra follow-up, not a blocker for this plan.

## Expert Panel Synthesis

### 1. Cleo / AI Money Coach Expert

Mint should copy the mechanism, not the US product: a coach that understands
where the user is trying to go, detects drift early, and translates data into
small next steps. Cleo's useful pattern is not "fun chat"; it is:

- remember goals and money patterns;
- precompute insight before the user asks;
- show a visible A-to-B path;
- intervene before the user falls behind;
- make the action feel concrete, not abstract.

For Mint, the Cleo pattern becomes Swiss-specific:

- A = today: monthly free margin, liquidity, debts, pillar facts, data
  confidence.
- B = goal: emergency buffer, home purchase, retirement freedom, debt relief,
  family transition, tax season, career change.
- Path = monthly capacity, required monthly effort, gap, next lever, data
  missing.
- Coach = explanation and navigation layer, not a parallel calculator.

Self-review: Inputs were local Cleo screenshots plus current Mint docs/code.
Output is a product operating principle, not a tested user-flow result.
Accuracy/effectiveness: 8/10. Not 10 because no live Cleo app walkthrough or
5-user Mint test was run. To reach 10: run a side-by-side UX script with Cleo
screens, Mint simulator screenshots and 3 user tasks.

### 2. VZ / Swiss Financial Planning Expert

Mint should be much more useful than a PDF budget sheet or a static planning
conversation by turning the same planning logic into a living mobile model:

- current budget and free margin;
- assets and debts;
- AVS/LPP/3a positions;
- income/expense path before and after a life event;
- assumptions and freshness;
- scenario deltas when the user changes a lever.

The VZ-like strength to keep is seriousness: a plan starts with budget,
revenues, expenses, patrimoine, taxes and pension facts. The Mint difference is
that the plan updates continuously, stays understandable, and can be queried by
chat.

Self-review: Inputs were public VZ/Swiss Life pages plus Mint data-flow docs.
Output is a strategic comparison. Accuracy/effectiveness: 8/10. Not 10 because
there is no competitive teardown of actual VZ advisor deliverables. To reach
10: collect one anonymized real planning output format and map it to Mint's
DataSpine fields.

### 3. Three Swiss Pillars Expert

Mon Argent should not flatten all money into one patrimoine number. It should
separate by usability and legal/economic nature:

- liquid today: cash, emergency fund, monthly free margin;
- budget flow: income, fixed charges, variable/future envelopes;
- free assets: investments, savings, other taxable wealth;
- liabilities: consumer debt, leasing, mortgage, other debt;
- 1st pillar: AVS entitlement signals, gaps, estimated pension, confidence;
- 2nd pillar: LPP balance, insured salary, conversion rate, buyback room,
  withdrawal constraints;
- 3rd pillar: balance, annual contribution, remaining room, provider/account
  count, withdrawal planning;
- trajectory: where those pieces move over time.

The UI should make liquidity obvious. A LPP balance and a cash balance both
belong to the user's financial situation, but they do not mean the same thing.
This is a central trust point.

Self-review: Inputs were `data-flow.md`, `calculator-graph.md`, DataSpine code
and Swiss pillar planning logic. Output is a domain taxonomy. Accuracy/
effectiveness: 8/10. Not 10 because field-level coverage against every
`CoachProfile` key was not yet completed. To reach 10: produce a source-of-
truth matrix mapping every wizard key to one of these buckets and one owner.

### 4. Mobile Architecture Expert

The codebase already contains most intended layers:

- `BudgetLivingEngine` exists.
- `BudgetSnapshot` exists.
- `DataSpineService` exists.
- `MintStateEngine` computes `budgetSnapshot` and `dataSpineSnapshot`.
- `ContextInjectorService` injects a `BUDGET VIVANT` block when
  `MintUserState` is passed.
- `MonArgentScreen` has section tabs and consumes DataSpine/BudgetSnapshot.
- `BudgetScreen` has direct-route guards and a `PresentBudgetBuilder`.

The main risk is not "nothing exists"; it is convergence:

- `docs/BUDGET_LIVING_ENGINE_IMPLEMENTATION_SPEC.md` expected
  `retirement_budget_service.dart`, but that file does not exist.
- `BudgetLivingEngine` directly wraps `RetirementProjectionService` and has
  several local `_compute*` helpers, which may be acceptable short-term but
  should be audited against the financial-core rule.
- `BudgetScreen` still intentionally uses explicit `BudgetInputs` for editor
  semantics, while Mon Argent prefers canonical `BudgetSnapshot`. That split is
  valid only if tested as a contract.
- `ContextInjectorService` only gets budget facts if callers pass
  `mintState`; every coach entry path must be checked.
- There are several legacy/service calculators outside `financial_core/` that
  may be valid feature simulations or may be drift risks. They require triage,
  not blind deletion.

Self-review: Inputs were current code greps and targeted file reads. Output is
a probable architecture audit. Accuracy/effectiveness: 8/10. Not 10 because no
call graph was generated and no tests were run in this planning phase. To reach
10: create a machine-checkable "single source" audit with caller lists and
failing regressions for each P0 mismatch.

## P0 / P1 Findings To Audit Next

P0 candidates:

- Coach path may not always receive `MintUserState`, so the chat can answer
  without the same BudgetSnapshot/DataSpine visible in Mon Argent.
- Missing `RetirementBudgetService` despite the implementation spec means the
  retirement-budget concept may be half-merged into `BudgetLivingEngine`.
- Any user-facing number produced by backend coach tools must be traceable to a
  named packet, input hash or local read model. This matters for 3a, budget and
  retirement gap.
- Budget/Money screens can still show different "available" concepts:
  unclamped monthly free, clamped `BudgetPlan.available`, future envelope,
  monthly savings and fixed charges.

P1 candidates:

- Mon Argent has useful sections now, but it risks becoming a cockpit if every
  section competes for attention.
- Budget detail screen is still dense: 50/30/20, sandwich chart, emergency
  fund, crash test and related sections may be useful, but not all above the
  fold.
- DataSpine has a good shape, but every field's source/freshness/confidence
  must be visible or at least inspectable.
- Legacy calculators outside `financial_core/` need classification: canonical,
  feature-local educational simulator, or cleanup candidate.

Self-review: Inputs were code/docs; outputs are audit candidates, not proven
bugs. Accuracy/effectiveness: 7/10. Not 10 because each item needs file-line
evidence and at least one reproducer or passing/failing test. To reach 10:
turn each P0 into a GSD micro-phase with a failing test or route/coach trace.

## Ideal Mint Operating Model

1. `wizard_answers_v2` remains the durable local fact store.
2. `CoachProfile.fromWizardAnswers` is the canonical in-memory financial
   profile.
3. `DataSpineSnapshot` is the canonical read model for UI/coach/visualization:
   situation, budget, pillars, trajectory.
4. `BudgetSnapshot` is the canonical monthly/future margin object.
5. `BudgetScreen` may use explicit `BudgetInputs` only as an editor bridge; its
   visible result must converge with `BudgetSnapshot` after save/reload.
6. The coach must consume the same DataSpine/BudgetSnapshot as the widgets.
7. Every important number must carry type: known, estimated, missing, stale,
   computed, projected.
8. Every projection must expose assumptions and confidence.
9. Mon Argent should organize by human meaning: today, month, patrimoine,
   pillars, trajectory.
10. The product loop is: capture fact -> recompute spine -> explain delta ->
    propose next step -> track plan -> remeasure.

Self-review: Inputs were all preceding sections. Output is executable product
doctrine. Accuracy/effectiveness: 8/10. Not 10 because it still needs adoption
in docs/CI and route-level tests. To reach 10: promote this into a formal ADR
after Phase 16 audit, with code owners and lints.

## GSD Plan

### Phase 16A - Read-only Source-of-Truth Audit

Deliverable: `.planning/audits/mon-argent-budget-data-spine-audit.md`

Tasks:

- Map every current Mon Argent/Budget/Coach visible number to source, read
  model, fallback and test.
- Produce a table:
  `visible label | screen/tool | source | freshness | confidence | test | risk`.
- Classify calculators outside `financial_core/` as canonical, educational
  local simulator, or drift candidate.
- Verify every coach entry path passes `MintUserState` into
  `ContextInjectorService.buildContext`.

Verification:

- `rg` evidence for every row.
- No code changes.
- Claude review retry with a shorter prompt or `--output-format json` plus
  timeout wrapper after infra fix.

### Phase 16B - Coach Data Injection Contract

Deliverable: failing tests before code.

Tasks:

- Add tests proving coach context includes `BUDGET VIVANT` for each chat entry
  path that has a profile.
- Add tests proving budget values in the context match `MintStateProvider`.
- Add a regression for "coach cannot invent a budget/tax value when snapshot is
  missing".

Verification:

- `flutter test test/services/coach/ test/screens/coach/`
- backend coach packet tests if endpoint serialization is touched.

### Phase 16C - RetirementBudgetService Reconciliation

Deliverable: decision, not automatic implementation.

Tasks:

- Decide whether to create `RetirementBudgetService` as the spec says or update
  the spec to bless `BudgetLivingEngine` as the wrapper.
- If created, move retirement monthly budget wrapping there with tests.
- If not created, update docs and add tests proving the current wrapper is the
  only source.

Verification:

- `flutter test test/services/budget_living_engine_test.dart`
- `flutter analyze lib/services/budget_living_engine.dart`

### Phase 16D - Mon Argent Information Architecture Lock

Deliverable: final section model and above-fold rule.

Recommended target:

- `Aujourd'hui`: 1 hero number, data confidence, one next step.
- `Mois`: explicit budget flow and setup/edit entry.
- `Patrimoine`: liquid/free assets vs liabilities, not mixed with pillars.
- `Piliers`: AVS/LPP/3a map with known/estimated/missing states.
- `Trajectoire`: A-to-B goal map, monthly required, gap, next lever.

Verification:

- Widget tests for direct route sections.
- Maestro screenshots for each section.
- UI review against cognitive load: one primary idea per section.

### Phase 16E - Maestro Product-Logic Flows

Flows:

- Fresh anonymous user, no data.
- Salary + rent + LAMal only.
- Salaried with LPP + partial 3a.
- Independent with no LPP.
- Debt-heavy profile.
- High-rent profile.
- Retired profile.
- Goal profile with target amount/date.

Assertions:

- No absurd amounts.
- No negative value hidden as zero.
- No retirement gap if data confidence is too low.
- Coach and screen numbers match.

Verification:

- Maestro screenshots archived in the phase folder.
- At least one route/UI snapshot per flow.

### Phase 16F - Claude CLI Repair

Deliverable: small infra note and reusable command.

Tasks:

- Reproduce the hang with a 20-second timeout.
- Test `claude -p "..." --output-format json --permission-mode acceptEdits
  --max-turns 1` with a one-line prompt.
- If still hanging, identify auth/session or VS Code extension process
  interaction.
- Save the working invocation in `.planning/infra/claude-cli-codex.md` and
  Engram.

Verification:

- Command exits with stdout JSON.
- No lingering `claude -p` process after the test.

## Recommendation

Do Phase 16A first. It is the highest-leverage move because it prevents us from
adding new UI on top of duplicate or stale read models. Then fix only P0/P1
contracts before visual polish.

Self-review: Inputs were repo docs, code, Cleo screenshots, and public market
references. Output is a phased plan with verification gates. Accuracy/
effectiveness: 8/10. Not 10 because the audit deliverable has not yet been
executed and Claude review failed due CLI hang. To reach 10: execute 16A,
repair Claude CLI, and convert findings into tests before code.

## External References

- Cleo official: https://web.meetcleo.com/
- Cleo 3.0 official blog: https://web.meetcleo.com/blog/introducing-cleo-3-0
- VZ budget retirement page:
  https://www.vermoegenszentrum.ch/fr/landing/planification-du-budget
- VZ retirement planning page:
  https://www.vermoegenszentrum.ch/fr/solution/planification-de-la-retraite
- Swiss Life retirement planning:
  https://www.swisslife.ch/fr/particuliers/prevoyance-patrimoine/planifier-retraite.html
- Swiss Life tools:
  https://www.swisslife.ch/fr/particuliers/prevoyance-patrimoine/calculateurs-outils.html
