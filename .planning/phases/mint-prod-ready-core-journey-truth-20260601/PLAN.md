---
description: Executable GSD plan for MINT production readiness focused on source-of-truth, human navigation, duplicated surfaces, and Maestro-proofed journeys.
status: active
date: 2026-06-01
autonomous: false
---

# MINT Prod-Ready Core Journey Truth — Plan

## Principle

Slow is fast here. The mission fails if we fix random bugs while preserving an incoherent product. Every task must answer:

1. Which human journey does this protect?
2. Which source of truth is canonical?
3. Which duplicate or contradiction is removed?
4. Which test or Maestro flow proves it?
5. Which roadmap/matrix row moves because of this work?
6. Which debt was introduced, revealed, accepted, or removed?

The plan is intentionally narrower than "fix all of MINT". First target one beta-quality story:

French Swiss supported archetype -> facts captured and persisted -> money truth stable across Budget/Mon Argent/Rapport/Coach -> Coach answer is cited/current -> Rapport is synthesis/proof/next action, not a third dashboard.

## Quality Governance Gates

These gates are part of the plan, not a side process:

1. **Anti-drift gate** — before editing, name the active roadmap, matrix,
   bug tracker, open release gates, and newest commit being audited. Run
   `python3 tools/checks/cjt_context_guard.py` when touching CJT state.
2. **Quality ratchet gate** — every wave must move at least one matrix row,
   bug status, proof level, or debt count in the right direction. A passing
   test without a matrix or tracker update is not enough for wave closure.
3. **No-new-untracked-debt gate** — every commit review must list debt delta:
   `introduced`, `revealed`, `accepted`, `removed`, or `none`. Any accepted
   debt needs an ID, severity, evidence, owner/scope, and next proof.
4. **Two-layer review gate** — code or journey changes need local mechanical
   checks plus at least one independent review layer: specialist subagent,
   Claude CLI review when available, or explicit manual diff audit captured in
   `.planning/`.
5. **Runtime-proof gate** — user-journey status can only advance to
   `LIVE-PROVEN` with fresh Maestro/device/backend runtime evidence for that
   exact scope.

## Wave 0 — Mission Control And Inventory

Goal: stop the chaos and create one operating map.

Tasks:

- Create `CORE-JOURNEY-TRUTH-MAP.md`.
- Create `BUG-TRACKER.md`.
- Fill the first inventory for:
  - Profile facts;
  - Budget / Mon Argent / Rapport / Coach;
  - navigation entrypoints;
  - Maestro coverage.
- Mark every item as P0/P1/P2 and `open / in_progress / verified / deferred / release_blocker`.
- Merge historical bug state from existing salvage/money-trust planning into this tracker instead of creating a second truth.
- Move future QA evidence out of `/tmp` into `.planning/_walker/` or this phase folder.

Verification:

- `git status --short`
- `rg -n "/rapport|financial_report|budget_overview|save_fact|BudgetSnapshot|DataSpineSnapshot" apps/mobile/lib services/backend/app`
- Existing Maestro flow inventory under `tools/simulator/flows/maestro-perfect-set/`.

Exit:

- One current map, one bug tracker, no hidden priority list in chat only.
- Every P0 row has a human journey, proof command, and persistent artifact plan.

## Wave 0.5 — Release Substrate Reality Check

Goal: avoid building product confidence on an undeployed truth substrate.

Scope:

- Phase 02 event-log/fact-current deploy/cutover state.
- Staging/prod migration chain.
- Backfill and projection diff.
- SnapshotModel decommission sequencing.

Tasks:

- Audit whether `fact_event` and `fact_current` exist in staging/prod and whether backfill is idempotent.
- Run or document the exact deploy/cutover commands.
- Run projection diff or mark the missing command as a release blocker.
- Decide whether Phase 02 is closed, deferred, or blocks staging promotion.

Verification:

- Alembic chain audit.
- Backfill x2 idempotence evidence.
- `projection_diff.py` or equivalent diff artifact.
- Final release-gate note in `VERIFICATION.md`.

Exit:

- No one can confuse local code architecture with deployed production readiness.

## Wave 1 — P0 Source-Of-Truth Closure

Goal: a user fact and a money number mean the same thing everywhere.

Scope:

- Profile truth: date of birth, canton, household/civil status, spouse fields, income, LPP, 3a, debt.
- Money truth: net income, fixed charges, available cash, LAMal, housing, taxes, debts, savings.
- Consumers: Profile/Dossier, Budget, Mon Argent, Rapport, Coach context packet.

Tasks:

- Build a source/consumer table for each critical field.
- For each P0 field, choose canonical read/write path.
- Remove or demote stale fallbacks that can override fresh truth.
- Add focused regression tests before fixes.
- Explicitly prove date of birth / birth year policy rather than relying on display age.
- Prove unsupported archetypes/life events are gated, not silently routed through unsupported advice.
- Promote Money Trust into one release gate instead of scattered historical evidence.

Verification:

- Flutter provider/model tests for mobile state.
- Backend tests for `save_fact`, profile, sync, and spouse/single semantics.
- Data spine tests: `flutter test test/services/data_spine_service_test.dart test/services/coach_context_packet_service_test.dart test/services/coach_chat_api_service_packet_contract_test.dart`.
- Backend packet/citation tests: `pytest tests/coach/test_coach_chat_profile_sanitize_context_packet.py tests/test_coach_tools_budget_snapshot.py tests/test_citation_gate/`.
- Maestro profile/money restart flow and money-trust flow.

Exit:

- No P0 field has two active authoritative sources.
- Restart does not change visible truth.
- Budget -> restart -> Budget -> Mon Argent -> Rapport -> Coach agree on monthly free cash, housing, LAMal, and no legacy packet fallback conflict.

## Wave 2 — Core Navigation Contract

Goal: every primary route matches a human intent.

Scope:

- Coach route planner;
- screen registry;
- route metadata;
- main shell tabs;
- deep links and legacy aliases.

Tasks:

- For each core surface, document: entrypoint, human job, owner, fallback route.
- Remove junk-drawer fallbacks.
- Make legacy aliases non-routable from Coach unless they are explicit user destinations.
- Fix back behavior where routes force users to unrelated screens.
- Fix stale route verifier documentation or add aliases so commands are executable as written.

Verification:

- Route planner tests.
- Screen registry parity.
- `./tools/mint-routes reconcile`.
- Explicit note that `./tools/mint-routes check` is stale until fixed.
- Maestro for navigation paths that humans actually use.

Exit:

- Coach opens screens only when the screen can satisfy the intent.
- No core route exists only because no one knew where else to send the user.

## Wave 3 — Duplicate Surface Reduction

Goal: remove repeated information unless each repetition has a different job.

Scope:

- Mon Argent vs Budget;
- Rapport vs Mon Argent/Budget;
- Profile/Dossier vs onboarding;
- Explorer/simulators vs Rapport action cards.

Tasks:

- Audit each repeated KPI/card/CTA.
- Decide one of: canonical owner, supporting proof, link-out, merge, remove.
- Keep copy and hierarchy aligned with that decision.
- Delete dead widgets or routes when they lose ownership.
- Treat Rapport as a consumer of canonical truth, never a third read model.

Verification:

- Widget tests assert absence of duplicate rows where needed.
- Screenshots before/after.
- Maestro asserts key duplicates are absent in real flows.

Exit:

- A user can explain why each surviving screen exists.

## Wave 4 — Storytelling And Decision Design

Goal: surviving screens help the user decide, not just inspect data.

Scope:

- Rapport / Synthese first;
- Mon Argent next;
- Budget setup/readiness;
- Coach route messages and next steps.

Tasks:

- For each screen, define the first-viewport contract:
  - one conclusion;
  - one next action;
  - evidence/confidence;
  - path to correct data.
- Rename inconsistent concepts only with ARB parity across 6 locales.
- Fix design-system debt only when touching a screen for role clarity.
- Close the hero Coach trust failure first: one Swiss finance answer must use current cited data or refuse cleanly.
- Sweep touched French copy for accents and compliance terms.

Verification:

- Screenshot review desktop/mobile simulator sizes where applicable.
- `flutter analyze`.
- ARB parity.
- Accent lint for French copy.
- ComplianceGuard/banned-term check for touched copy.
- Maestro for one full human story.

Exit:

- No screen relies on the user guessing why it exists.

## Wave 5 — Maestro Regression Matrix

Goal: production readiness is measured by journeys.

Required journey flows:

- Profile truth: fact capture -> restart -> Profile/Coach agree.
- Money trust: Budget -> Mon Argent -> Rapport -> Coach agree.
- Rapport synthesis: explicit Coach request -> Rapport opens with persisted truth, no dashboard duplication.
- Scan truth: document extraction -> review -> profile update -> projection impact.
- Navigation sanity: primary shell + deep links + legacy redirects do not trap the user.
- Coach trust: cited/current 3a/tax-style answer or clean refusal, no stale constants.

Verification:

- Existing flow reuse first.
- Add new flow only when no existing flow can prove the journey.
- Store screenshots/log paths under `.planning/_walker/` or this phase folder.
- Ensure Maestro PR/CI path is documented or tracked as open.

Exit:

- Bug tracker rows include a Maestro/test evidence column.

## Wave 6 — Release Readiness Gate

Goal: know honestly whether staging is promotable.

Tasks:

- Run targeted Flutter tests for touched subsystems.
- Run backend tests for touched endpoints.
- Run Maestro journey set.
- Run route and registry parity.
- Run i18n/banned-term/accent checks for touched copy.
- Generate final `VERIFICATION.md`.
- Mark universal links/deep-link signing evidence as release-blocking until proven.

Exit:

- Every P0 is verified or explicitly deferred with rationale.
- Staging push only after clean repo and cited gates.

## Stop-Doing List

- Stop polishing screens before assigning screen jobs.
- Stop using Rapport as a default fallback.
- Stop accepting duplicated cards as harmless.
- Stop trusting generated summaries without diff/test evidence.
- Stop adding abstractions for two call-sites.
- Stop saying "prod ready" for a screen that has not passed a simulator/user-flow proof.
