# G1 Ledger Reality Baseline — Data Ledger Audit

Date: 2026-07-12

Agent: `mint-data-ledger-architect`

Scope: G1 baseline only; no G2 DataQuest or G3 product-loop implementation.

## Verdict and scores

**Verdict: G1 data contracts are review-ready, but the runtime ledger is not
yet real enough to unlock G2.** The canonical matrix and provider-boundary
decision score **9/10** as contracts. The observed runtime implementation
scores **4/10** because semantic round trips, fact provenance, scenario
isolation, provider convergence, and behavioral hard-floor proof remain
incomplete.

The contract itself makes the phase boundary explicit:

- the registry is G1 data reality and does not implement G2/G3
  (`.planning/goals/G1-ledger-gap-matrix.md:3-5`);
- every `blocks_G2=yes` row remains blocking until implemented or represented
  by a compliant checked-in blocking ticket
  (`.planning/goals/G1-ledger-gap-matrix.md:24-27`);
- the provider decision authorizes no G2/G3 implementation
  (`.planning/goals/G1-provider-boundary.md:3-5`);
- its acceptance section keeps G2 blocked until the hard floor, behavioral
  fixtures, legacy migration, provider bridges, scenario isolation, and
  provenance/ownership conditions pass
  (`.planning/goals/G1-provider-boundary.md:170-182`).

## Contract validation

The canonical registry validation passed with:

- **73 data rows**;
- **73 unique `canonical_key` values**;
- **23 columns in the declared stable order**;
- **36/36 coach `save_fact` keys represented exactly**.

Registry evidence:

- exact parser heading and 23-column schema:
  `.planning/goals/G1-ledger-gap-matrix.md:43-46`;
- backend coach allowlist:
  `services/backend/app/api/v1/endpoints/coach_chat.py:921-947`;
- mobile coach-key mapper entry point and semantic destinations:
  `apps/mobile/lib/providers/coach_profile_provider.dart:570-590`;
- current static gate proves only set equality for 36 keys and explicitly does
  not satisfy the behavioral predicate:
  `.planning/goals/G1-ledger-gap-matrix.md:148-153`.

The required G1 hard floor is behavioral, not merely structural: write through
the provider, persist, reload, assert the typed read, cover every enum and write
ordering, reject defaults as known, require a real consumer, separate scenario
targets, and fail closed when legal provenance is absent
(`.planning/goals/G1-ledger-gap-matrix.md:121-146`).

## P0 — blocks G2

1. **Coach enum round trips are semantically broken.** Backend accepts
   `householdType={single,couple,concubine,family}` and
   `employmentStatus` including `unemployed`, plus goals
   `retire/emergency/optimize_taxes/other`
   (`services/backend/app/api/v1/endpoints/coach_chat.py:966-978`). The mobile
   mapper stores these values directly in wizard keys
   (`apps/mobile/lib/providers/coach_profile_provider.dart:585-590`), but the
   civil parser recognizes neither `couple`, `concubine`, nor `family` and
   defaults to single (`apps/mobile/lib/models/coach_profile.dart:3307-3326`);
   the employment parser does not recognize `unemployed` and defaults to
   salaried (`apps/mobile/lib/models/coach_profile.dart:3330-3353`); unsupported
   goals default to retirement
   (`apps/mobile/lib/models/coach_profile.dart:3379-3442`). Contract rows are
   therefore honestly marked `semantic_mismatch`
   (`.planning/goals/G1-ledger-gap-matrix.md:51-54`).

2. **No committed behavioral dead-key red→green proof exists yet.** Static
   parity does not prove write, restart, typed read, consumer reachability, enum
   semantics, or prerequisite ordering. Required red fixtures are named at
   `.planning/goals/G1-ledger-gap-matrix.md:143-146`; the current conclusion
   still blocks G2 at `.planning/goals/G1-ledger-gap-matrix.md:148-153`.

3. **Defaults and reconstructed values can be stamped fresh without field-level
   knowledge.** `CoachProfile` creates profile timestamps with `DateTime.now()`
   (`apps/mobile/lib/models/coach_profile.dart:1555-1570`), malformed persisted
   timestamps fall back to now
   (`apps/mobile/lib/models/coach_profile.dart:2377-2383`), and reconstruction
   assigns the same current/profile timestamp to salary, age, canton, civil
   status, conversion rate, and cash, including default-backed fields
   (`apps/mobile/lib/models/coach_profile.dart:3085-3106`). This violates the
   hard-floor rule that missing defaults never count as known or fresh
   (`.planning/goals/G1-ledger-gap-matrix.md:134-135`).

4. **Scenario results mutate durable facts.** EPL subtracts a hypothetical
   withdrawal from `prevoyance.avoirLppTotal` and updates the profile
   (`apps/mobile/lib/screens/lpp_deep/epl_screen.dart:94-110`).
   Rente-vs-capital writes computed outputs into certificate-shaped projection
   fields and also rewrites retirement age
   (`apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:274-295`).
   The binding boundary forbids both paths and quarantines them under
   `G1-SCN-01` (`.planning/goals/G1-provider-boundary.md:54-71`).

5. **The durable fact envelope is incomplete.** Runtime has `dataSources` and
   `dataTimestamps` (`apps/mobile/lib/models/coach_profile.dart:1468-1479`), but
   the binding contract additionally requires pseudonymous `profile_owner_id`,
   actual `source_date`, confidence tied to the recorded source, and a null
   `scenario_id` for facts / mandatory `scenario_id` for scenario artifacts
   (`.planning/goals/G1-provider-boundary.md:29-42`). Until writes resolve that
   envelope atomically, provenance, owner separation, and fact/scenario
   isolation are not enforceable.

6. **Frontalier reality is absent from the canonical runtime.** `workCanton`,
   `workCountry`, and `residenceCountry` have no storage, typed profile field,
   or reader and are marked missing/blocking
   (`.planning/goals/G1-ledger-gap-matrix.md:111-113`). A G2 question graph
   cannot repair a ledger that has nowhere canonical to retain its answers.

7. **P0 retirement/succession evidence references are also missing.** LPP
   regulation/deadline, 3a beneficiary, matrimonial regime, estate instruments,
   and latest tax-decision references are explicit missing blockers
   (`.planning/goals/G1-ledger-gap-matrix.md:114-119`). Current-law outputs must
   stay `partial+ask` or `educational_only` until source date/legal year exists
   (`.planning/goals/G1-ledger-gap-matrix.md:138-141`).

## P1 — required convergence after the P0 spine

1. **Retire the legacy `ProfileProvider` truth path.** Five production reads
   remain at `apps/mobile/lib/screens/simulator_3a_screen.dart:197`,
   `apps/mobile/lib/screens/simulator_3a_screen.dart:301`,
   `apps/mobile/lib/widgets/simulators/buyback_widget.dart:39`,
   `apps/mobile/lib/widgets/recommendation_card.dart:17`, and
   `apps/mobile/lib/widgets/comparators/pillar3a_comparator_widget.dart:29`.
   The provider remains registered at `apps/mobile/lib/app.dart:1520`. The
   deletion and debt-semantics acceptance contract is recorded at
   `.planning/goals/G1-provider-boundary.md:87-101`.

2. **Implement and test provider bridges without creating parallel truth.**
   `CoachProfileProvider` is the only durable fact write spine and
   `MintStateProvider` is derived
   (`.planning/goals/G1-provider-boundary.md:7-27`). Budget, household,
   documents, timeline, financial plans, and the backend mirror are classified
   with their allowed/forbidden responsibilities and blocking actions at
   `.planning/goals/G1-provider-boundary.md:73-85`.

3. **Persist extracted typed facts that currently die on restart or remain
   untyped.** LPP projected pension/capital and disability/death coverage lack
   storage keys (`.planning/goals/G1-ledger-gap-matrix.md:103-106`); tax income,
   wealth, marginal rate, and assessed taxes lack typed profile fields or source
   dates (`.planning/goals/G1-ledger-gap-matrix.md:107-110`).

## P2 — cleanup after hard-floor convergence

1. Remove stale ownership comments such as the claim that the legacy backend
   `ProfileProvider` is the persisted source of truth
   (`apps/mobile/lib/providers/coach_profile_provider.dart:25-26`) once the
   actual boundary is enforced.
2. Reconcile shifted/stale documentation references after concurrent G1 edits;
   acceptance must follow live grep evidence, not remembered line numbers.
3. Remove obsolete registrations, adapters, and dead aliases only after their
   consumers and behavioral gates are green; no speculative abstraction is
   authorized.

## G1 baseline versus G2

G1 must first establish one canonical fact spine, typed durable storage,
field-level provenance/freshness/ownership, fact-versus-scenario isolation,
provider convergence, and a committed behavioral red→green hard floor. G2 may
then build progressive DataQuest questions and Case logic **on top of that
verified reality**. G2 must not compensate for missing storage, reinterpret
broken enums, or become another source of truth.

**G2 allowed? NO**
