# Phase mint-data-spine-plan-vivant-v1: Context

> **Statut : CLOS 2026-07-29** — supersedé par la décision spine 2026-07-21 (dev = spine produit) : `data_spine_snapshot.dart` tourne sur dev. Réconciliation plans 2026-07-29.

**Gathered:** 2026-05-23
**Status:** Ready for planning and execution

<domain>
## Phase Boundary

This phase creates the first typed data spine for Mint's mobile app. It does not replace `wizard_answers_v2`, `CoachProfile`, or backend mirrors. It derives typed, testable objects from the existing path and proves one end-to-end budget/situation slice.

The phase delivers:

- typed data spine models and derivation service;
- budget and pillar summaries derived from `CoachProfile`;
- structured coach context generated from the spine;
- one UI proof surface;
- one Maestro proof flow covering persistence, relaunch, display, and coach explanation.

</domain>

<decisions>
## Implementation Decisions

### Source of truth
- **D-01:** `wizard_answers_v2` remains the local source of truth.
- **D-02:** `CoachProfile` remains the hydration layer.
- **D-03:** The new spine is a typed derivation layer, not a second persistence system.

### Domain model
- **D-04:** Budget is monthly cashflow, not a Swiss-pillar structure.
- **D-05:** Swiss pillars live in `PillarPosition`: AVS, LPP, and 3a.
- **D-06:** Projections are derived outputs with confidence/uncertainty, not user-entered facts.
- **D-07:** Plans and trajectories are derived from current situation, budget, projections, and goals.

### LLM contract
- **D-08:** The LLM receives structured summaries and missing-field lists.
- **D-09:** The LLM may explain and ask for missing data, but must not invent missing fields or own financial truth.

### Verification
- **D-10:** Every plan uses TDD first.
- **D-11:** The first user-visible proof is a Maestro vertical slice, not a broad navigation rewrite.

### Claude's discretion
- Exact Dart file split is flexible as long as models stay small, immutable, and derived from `CoachProfile`.
- UI surface choice is flexible, but must reuse an existing surface before adding a new route.

</decisions>

<specifics>
## Specific Ideas

The product direction is "Cleo-like trajectory, Mint-like Swiss precision":

- A to B trajectory: current path vs plan path.
- Budget shows breathing room: income -> fixed charges -> debt -> planned savings -> free.
- Pillars show Swiss long-term position: known, missing, estimated, next useful data action.
- The coach explains with cited structured facts, not free-floating LLM memory.

</specifics>

<canonical_refs>
## Canonical References

### Phase spec
- `docs/superpowers/specs/2026-05-23-mint-data-spine-plan-vivant-v1-design.md` — phase design, objects, non-goals, proof flow.

### Existing data architecture
- `docs/data-flow.md` — storage invariant and legal writers/readers of `wizard_answers_v2`.
- `docs/calculator-graph.md` — calculator ownership and no duplicate financial calculations.
- `docs/coach-tool-routing.md` — LLM tool routing and anonymous `save_fact` caveat.

### Budget and plan direction
- `docs/BUDGET_VIVANT_ARCHITECTURE.md` — Budget A/B/gap/cap doctrine.
- `docs/BUDGET_LIVING_ENGINE_IMPLEMENTATION_SPEC.md` — existing BudgetSnapshot/BudgetLivingEngine design.
- `docs/MINT_UX_GRAAL_MASTERPLAN.md` — product loop and plan-first doctrine.

### Existing code
- `apps/mobile/lib/models/coach_profile.dart` — source profile model and `fromWizardAnswers`.
- `apps/mobile/lib/models/budget_snapshot.dart` — current living budget model.
- `apps/mobile/lib/services/budget_living_engine.dart` — current budget derivation.
- `apps/mobile/lib/domain/budget/budget_inputs.dart` — budget inputs from profile.
- `apps/mobile/lib/domain/budget/budget_service.dart` — budget cashflow calculation.
- `apps/mobile/lib/models/mint_user_state.dart` — existing app state carrier.
- `apps/mobile/lib/services/mint_state_engine.dart` — existing snapshot/state computation.
- `apps/mobile/lib/services/coach_llm_service.dart` — current mobile coach context area.
- `apps/mobile/lib/services/api_service.dart` — backend chat request payload surface.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `BudgetLivingEngine.compute(profile)` already produces a budget snapshot and is used by `MintStateEngine` tests.
- `BudgetSnapshot` already exists and should be reused or extended conservatively.
- `CoachProfile.dataSources` and `dataTimestamps` provide part of the needed provenance/freshness model.
- `FinancialPlan`, `PlanTrackingService`, and trajectory widgets already exist and should not be duplicated in v1.

### Established Patterns
- New profile-derived behavior should be tested in `apps/mobile/test/services/`.
- Any budget screen change must read `docs/data-flow.md` budget flow first.
- Any coach context change must read `docs/coach-tool-routing.md`.
- Any calculation must use `apps/mobile/lib/services/financial_core/` or existing aggregators.

### Integration Points
- `DataSpineSnapshot` should be computed from `CoachProfile`.
- `BudgetSnapshot` should either be embedded in or referenced by `DataSpineSnapshot`.
- Coach context should be serialized into `ApiService` request payloads without exposing PII beyond existing rules.
- Maestro flow should live under `tools/simulator/flows/maestro-perfect-set/`.

</code_context>

<deferred>
## Deferred Ideas

- Bank aggregation and transaction categorization.
- Full Chat Vivant scene/canvas.
- Broad navigation redesign.
- Backend event-log cutover; this remains in `mint-data-architecture-v1-02-deploy`.
- Autonomous advice/action execution.
</deferred>

---

*Phase: mint-data-spine-plan-vivant-v1*
*Context gathered: 2026-05-23*
