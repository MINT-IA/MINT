# G1 Provider Boundary Decision

> Status: binding G1 architecture decision.
> Scope: provider ownership and data movement only. No G2/G3 implementation is
> authorized by this document.

## Decision

`CoachProfileProvider` is the only durable user-fact write spine.
`MintStateProvider` is a derived read model. Other providers are either
explicit reference stores, scenario caches, or migration debt. They may not
become parallel sources of financial truth.

The legal chain is:

```text
confirmed fact source
  -> CoachProfileProvider ledger write
  -> wizard_answers_v2 persistence representation
  -> CoachProfile.fromWizardAnswers typed reconstruction
  -> MintStateProvider recompute
  -> screen/dossier consumer
```

`wizard_answers_v2` is not a screen read API. Screens read `CoachProfile` or
`MintUserState`. Raw documents, conversations, household membership, and
scenario artifacts remain outside the fact ledger and are referenced by ID.

## Fact ownership and scenario boundary

Every durable write must resolve this metadata envelope before persistence:

| field | rule |
|---|---|
| `canonical_key` | Must exist in `G1_P0_CANONICAL_KEYS`. |
| `profile_owner_id` | Pseudonymous owner token for `self` or `partner`; never an email, name, or route payload. |
| `value` | Typed according to the registry. |
| `source` | One live `ProfileDataSource` value. |
| `source_date` | Underlying document/feed date; nullable only for manual input or estimate. |
| `updated_at` | When MINT confirmed or reconfirmed the fact. |
| `confidence` | Derived from the actual source and validation state, not a screen default. |
| `scenario_id` | Must be null for durable facts; mandatory for scenario levers and scenario outputs. |

Ownership rules:

- `self`: the authenticated/local profile subject.
- `partner`: a declared pseudonymous partner token or linked partner subject;
  partner data must never be silently reassigned to `self`.
- `household`: derived aggregation only. It is not a writable owner of raw
  salary, pension, cash, or debt facts.
- `document_ref`: reference metadata only. Raw document values become ledger
  facts only after the confirmation path records their owner and provenance.

Scenario rules:

- A simulator input that describes current reality is a fact and must come
  from the ledger or an explicit DataQuest confirmation.
- A user-adjustable alternative is a `scenario_lever`, remains case/session
  scoped, and carries `scenario_id`.
- A computed result is a `derived_output`, is recomputed, and is never stored
  as a user fact.
- A simulation may offer an explicit separate action to update a current fact;
  that action must restate the fact, owner, source, and confirmation. Merely
  moving a slider is not consent to rewrite the ledger.

This forbids the current `/epl` behavior that reduces `avoirLppTotal` using a
hypothetical withdrawal (`apps/mobile/lib/screens/lpp_deep/epl_screen.dart:103`)
and the `/rente-vs-capital` behavior that writes scenario outputs into
certificate-shaped projection fields
(`apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:285`). These
paths are quarantined by `G1-SCN-01` until separated.

## Provider classification

| provider/store | classification | allowed responsibility | forbidden responsibility | required G1 action | ticket | blocks_G2 |
|---|---|---|---|---|---|---|
| `CoachProfileProvider` | authoritative fact spine | merge confirmed facts, persist, reconstruct, notify, sync mirror | accepting unstamped facts, storing scenario levers as facts | Make every write atomic with owner, source, source date, updated_at, confidence; remove contradictory legacy-source comment | G1-PROV-01 | yes |
| `MintStateProvider` | derived read model | recompute from one `CoachProfile` snapshot; expose derived state | durable writes, direct SharedPreferences reads for facts, independent fact defaults | Keep the existing `ChangeNotifierProxyProvider` edge and test recompute after fact writes | G1-BND-04 | yes |
| `ProfileProvider` | legacy migration debt | temporary compatibility for five named consumers only | new consumers, new writes, ownership of backend truth | Freeze, migrate all five consumers with explicit debt semantics, grep zero, then remove provider/model registration | G1-BND-01 | yes |
| `BudgetProvider` and `BudgetLocalStore` | derived scenario/cache island | compute budget plan; cache scenario overrides; hydrate base inputs from `CoachProfile.depenses` | authoritative housing, premium, income, cash, or debt facts | Keep overrides local; bridge confirmed base facts through `CoachProfileProvider`; rehydrate cache from ledger | G1-BND-03 | yes |
| `HouseholdProvider` | membership/reference island | invitations, roles, consent, linked member IDs | authoritative partner salary, AVS, LPP, cash, or civil facts | Bridge confirmed partner facts with partner owner token; keep membership metadata separate | G1-BND-02 | yes |
| `DocumentProvider` | raw reference store | upload state, document ID, parse status, raw document lifecycle | direct financial truth consumed by screens | Confirmed extracted facts write through ledger; navigation passes document ID only | G1-BND-05 | yes |
| `TimelineProvider` | reference/read model | document/conversation references and chronology | separate financial facts or alternate profile | Read financial dimension from ledger; keep timeline object IDs outside ledger | G1-BND-05 | no |
| `FinancialPlanProvider` | derived artifact cache | store a generated plan and its profile hash; mark stale | feeding plan outputs back into facts | Wire staleness to profile changes or convert registration to a proxy; no reverse fact writes | G1-BND-06 | no |
| backend `ProfileModel.data` | remote mirror | authenticated sync of canonical facts and provenance | primary mobile read path, profile-global freshness pretending to be per-field freshness | Add per-field source/update/source-date ownership contract through a reviewed backend slice | G1-PROV-01 | yes |

## Legacy `ProfileProvider` migration set

The deletion precondition is grep zero for all five production consumers:

| consumer | current read | migration decision |
|---|---|---|
| `apps/mobile/lib/screens/simulator_3a_screen.dart:197` | `context.read<ProfileProvider>()` | Read the needed typed fact from `CoachProfileProvider`; do not construct or update the legacy API model. |
| `apps/mobile/lib/screens/simulator_3a_screen.dart:301` | legacy `hasDebt` | Choose explicitly between any-debt `CoachProfile.dettes.hasDette` and protective `CoachProfile.isInDebtCrisis`; add a test for the chosen semantics. |
| `apps/mobile/lib/widgets/simulators/buyback_widget.dart:39` | legacy `hasDebt` | Same explicit debt-semantics decision; do not substitute blindly. |
| `apps/mobile/lib/widgets/recommendation_card.dart:17` | legacy `hasDebt` | Same explicit debt-semantics decision; preserve the intended recommendation gate. |
| `apps/mobile/lib/widgets/comparators/pillar3a_comparator_widget.dart:29` | legacy `hasDebt` | Same explicit debt-semantics decision; test mortgage-only versus consumer-debt cases. |

`ProfileProvider` remains registered at `apps/mobile/lib/app.dart:1523`. Removal
is allowed only after the five migrations, tests, and grep-zero proof land in
one reviewable slice. Until then it is frozen, not considered canonical.

## Islands and bridge behavior

### Budget

`BudgetProvider` persists `BudgetInputs` and overrides in its local store
(`apps/mobile/lib/providers/budget/budget_provider.dart:21`). The boundary is:

- factual income, rent, health premium, and debt payments originate in
  `CoachProfileProvider`;
- `future` and `variables` overrides are scenario levers and stay in the
  budget scenario/cache;
- loading the cache must not overwrite fresher ledger facts;
- a confirmed edit bridges once to the ledger, which triggers
  `MintStateProvider.recompute`; a re-entrancy/idempotency guard prevents
  bridge loops.

### Household

`HouseholdProvider.loadHousehold` currently populates its own maps and notifies
its own listeners (`apps/mobile/lib/providers/household_provider.dart:52`). A
bridge may copy only confirmed, authorized partner facts into the ledger. It
must retain the partner owner token and must not infer missing spouse pension,
income, or legal status from membership alone.

### Documents and timeline

- Routes carry `documentId`, never extracted financial maps.
- Unconfirmed OCR remains `estimated` and cannot unlock a high-stakes result.
- Confirmation writes the fact with `certificate`, document issue date, owner,
  and updated_at.
- Raw files, parse payloads, conversations, and timeline nodes remain reference
  stores and are excluded from profile logs and route extras.

### Financial plans

`FinancialPlanProvider.attachProfileProvider` exists at
`apps/mobile/lib/providers/financial_plan_provider.dart:76`, while `app.dart`
registers a plain provider at `apps/mobile/lib/app.dart:1584`. The plan is a
derived artifact: wire staleness, do not feed plan numbers back into facts.

## Route payload boundary

`GoRouter.extra` may carry only IDs, enums, `runId`, `stepId`, and ephemeral UI
selection. It may not carry salary, pension, cash, tax, wizard-answer maps,
profile objects, or financial `prefill` maps.

Known G1 P0 candidate debt includes domain prefill handling in
`apps/mobile/lib/screens/arbitrage/rente_vs_capital_screen.dart:125` and
`apps/mobile/lib/screens/mortgage/affordability_screen.dart:99`. Sequence IDs
alone, such as those read by `/first-job`, remain allowed.

## Privacy boundary

- `profile_owner_id` is pseudonymous and never displayed or logged with a raw
  financial value.
- Partner facts require explicit consent/authorization; household membership
  is not consent to import all partner data.
- Logs and analytics contain canonical key, status, source class, and error
  code only; financial values, names, emails, document contents, and stable
  cross-user identifiers are redacted.
- Source metadata may be logged only without raw document content.
- Raw documents and specialist instruments remain in their privacy-controlled
  stores; the ledger holds only confirmed facts and opaque references needed
  for freshness or handoff.
- Anonymous/local profiles remain local; backend mirror writes occur only for
  an authenticated owner.

## Acceptance and grep proofs

G2 remains blocked until:

1. `G1_P0_CANONICAL_KEYS` is the only hard-floor registry.
2. Behavioral dead-key fixtures prove write, reload, typed read, and consumer.
3. The five legacy consumers are migrated or have blocking tickets accepted by
   the G1 template; no new consumer exists.
4. Provider islands are classified exactly as above and each required bridge
   has a failure predicate and red-to-green command.
5. Scenario writes cannot mutate durable fact targets.
6. Provenance and ownership gaps are implemented or represented by checked-in
   blocking tickets with explicit P0-loop impact.

Required grep proofs:

```bash
rg -n "(read|watch|of)<ProfileProvider>|Consumer<ProfileProvider>|Provider\.of<ProfileProvider>" apps/mobile/lib
rg -n "GoRouterState\.of\(context\)\.extra|state\.extra" apps/mobile/lib/screens apps/mobile/lib/app.dart
rg -n "ReportPersistenceService\.saveAnswers|wizard_answers_v2" apps/mobile/lib
rg -n "profile_owner_id|scenario_id|dataSourceDates|data_sources|data_updated|data_source_dt" apps/mobile/lib services/backend/app
```

This decision does not authorize the missing bridges or loop implementations;
it defines the boundary they must satisfy.
