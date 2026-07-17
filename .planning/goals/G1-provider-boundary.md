# G1 Provider Boundary Decision

> Status: binding G1 architecture decision.
> Scope: provider ownership and data movement only. No G2/G3 implementation is
> authorized by this document.
> Evidence snapshot: code and gates rechecked at immutable commit
> `e2cfef057c197b3b8ac122d9a9aa3ca645c85696` on 2026-07-13.
> Focused BND-06 technical GREEN: semantic RED `9e86539d2`; the bounded
> contract is accepted at exact pushed SHA
> `28d0097f65b2f0a88d3ae6610614d912d0ba943a` on 2026-07-17. Writer -> real
> process death -> cold reader, exact physical production-entrypoint
> build/sign/install and Maestro passed. The product-domain Sonnet rerun and
> final Opus code confirmation both passed with zero P0/P1. The feature remains
> a test-only compile-time opt-in that defaults false: activation and G1 stay
> NO-GO, and G2/G3 remain unauthorized.
> Focused BND-01 implementation reality is rechecked at exact pushed SHA
> `ed5f2db13112f76753bc9e3abc23ff51d44b0ae3` on 2026-07-17: the legacy
> provider and registration are absent, the historical reader inventory
> reconciles to one production surface, and that surface reads the canonical
> protective state. This bounded closure does not close G1 or authorize G2/G3.

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

The G1 mobile hard floor checks this boundary on the exact route set
`/epl`, `/rente-vs-capital`, `/hypotheque`, `/rachat-lpp`,
`/3a-retroactif`, and `/pilier-3a`. Its matcher classifies method invocations
by durable sink verb plus subject (`updateProfile`, `mergeAnswers`,
`applySaveFact`, `setProfile`, `updateFromAnswers`, and equivalents), proves
seeded write-backs red, then asserts that the six production sources contain no
such sink call
(`apps/mobile/test/routing/no_scenario_writeback_to_profile_test.dart:5-46,48-90,92-159`).
This is a semantic source gate over six named files, not proof of a Case store or
of every future screen. Focused provider-recorder tests separately prove zero
updates and unchanged LPP facts for staged buy-back and retroactive 3a controls
(`rachat_echelonne_screen_test.dart:63-113`,
`retroactive_3a_screen_test.dart:63-91`). The Case-local scenario store remains
unimplemented and therefore blocks G2; the audited screens must not regress to
profile writeback while that store is absent.

## Provider classification

| provider/store | classification | allowed responsibility | forbidden responsibility | required G1 action | ticket | blocks_G2 |
|---|---|---|---|---|---|---|
| `CoachProfileProvider` | authoritative fact spine | merge confirmed facts, persist, reconstruct, notify, sync mirror | accepting unstamped facts, storing scenario levers as facts | Make every write atomic with owner, source, source date, updated_at, confidence; remove contradictory legacy-source comment | G1-PROV-01 | yes |
| `MintStateProvider` | derived read model | recompute from one `CoachProfile` snapshot; expose derived state | durable writes, direct SharedPreferences reads for facts, independent fact defaults | Keep the existing `ChangeNotifierProxyProvider` edge and test recompute after fact writes | G1-BND-04 | yes |
| `ProfileProvider` (removed) | retired legacy boundary | none | reintroduction, compatibility facade, current-fact hydration, new readers or writes | Keep the provider file and app registration absent; the smaller `Profile` model remains only as the API/Wizard DTO and has no provider or screen ownership | G1-BND-01 | no |
| `BudgetProvider` and `BudgetLocalStore` | derived scenario/cache island | compute budget plan; cache scenario overrides; hydrate base inputs from `CoachProfile.depenses` | authoritative housing, premium, income, cash, or debt facts | Keep overrides local; bridge confirmed base facts through `CoachProfileProvider`; rehydrate cache from ledger | G1-BND-03 | yes |
| `HouseholdProvider` | membership/reference island | invitations, roles, consent, linked member IDs | authoritative partner salary, AVS, LPP, cash, or civil facts | Bridge confirmed partner facts with partner owner token; keep membership metadata separate | G1-BND-02 | yes |
| `DocumentProvider` | raw reference store | upload state, document ID, parse status, raw document lifecycle | direct financial truth consumed by screens | Confirmed extracted facts write through ledger; navigation passes document ID only | G1-BND-05 | yes |
| `TimelineProvider` | reference/read model | document/conversation references and chronology | separate financial facts or alternate profile | Read financial dimension from ledger; keep timeline object IDs outside ledger | G1-BND-05 | no |
| `FinancialPlanProvider` | ledger-bound derived artifact cache | store a generated plan and its branch-scoped v3 dependency envelope; fail stale until the ledger is loaded and whenever a consumed dependency, owner or validity boundary changes | feeding plan outputs back into facts; rendering stale plan figures or LLM-supplied amounts | Technical GREEN at exact pushed SHA `28d0097f65b2f0a88d3ae6610614d912d0ba943a`: eager profile proxy, cold reconciliation, fail-closed Coach/Aujourd'hui consumers and current-ledger regeneration; compile-time test flag remains default-off and activation remains NO-GO | G1-BND-06 | no |
| backend `ProfileModel.data` | remote mirror | authenticated sync of canonical facts and provenance | primary mobile read path, profile-global freshness pretending to be per-field freshness | Add per-field source/update/source-date ownership contract through a reviewed backend slice | G1-PROV-01 | yes |

## Retired `ProfileProvider` boundary

At exact SHA `ed5f2db13112f76753bc9e3abc23ff51d44b0ae3`, the historical five
matches reconcile to one production debt-protection reader:

| historical match | verified production reality | closure |
|---|---|---|
| `apps/mobile/lib/screens/simulator_3a_screen.dart:182` | sole live reader | Reads `CoachProfileProvider.profile?.isInDebtCrisis`. A null profile never becomes `false`: loading remains loading and a loaded provider without a profile renders an empty state with a diagnostic CTA to `/coach/chat`. |
| `apps/mobile/lib/widgets/simulators/buyback_widget.dart` | no production caller | Deleted rather than preserving a facade without wiring. |
| `apps/mobile/lib/widgets/recommendation_card.dart` | no production caller | Deleted rather than preserving a facade without wiring. |
| `apps/mobile/lib/widgets/comparators/pillar3a_comparator_widget.dart` | absent from the production tree | Removed from the live inventory; it was not a reader to migrate. |
| former simulator fallback/read duplication | same `/pilier-3a` surface, not a separate consumer | Input hydration and protection both use the canonical provider. |

The canonical protection meaning is `CoachProfile.isInDebtCrisis`, not the
any-debt alias `CoachProfile.dettes.hasDette`. The predicate can be true solely
because liquid savings cover fewer than three months of declared/derived
expenses. Therefore the locked title and strategy copy stay generic to
financial stabilization and must not assert that the user has debt.

`apps/mobile/lib/providers/profile_provider.dart` and its `MintApp`
registration are deleted, and production grep for `ProfileProvider` is zero.
The smaller `apps/mobile/lib/models/profile.dart` is intentionally retained:
`ApiService.createProfile` and `WizardService.getQuestionsForUser` still use it
as an API/Wizard DTO. It has no mobile provider, screen reader, or independent
persistence ownership and is not part of the fact ledger.

This closure does not make every 3a field live: the P1 `has3a` ledger row
remains separately `quarantined` because its former model-adapter anchor was an
unqualified read, not an independent production consumer.

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

`spouseIncomeNetMonthly` is therefore `quarantined` under `G1-BND-02`. The
current rebuild path converts `q_partner_net_income_chf` into
`conjoint.salaireBrutMensuel` with a fixed net-to-gross factor; that does not
preserve or expose a typed partner-net fact. The bridge must add an explicit net
field and semantic round-trip before any budget/mortgage consumer may claim the
net amount is live.

### Documents and timeline

- Routes carry `documentId`, never extracted financial maps.
- Unconfirmed OCR remains `estimated` and cannot unlock a high-stakes result.
- Confirmation writes the fact with `certificate`, document issue date, owner,
  and updated_at.
- Raw files, parse payloads, conversations, and timeline nodes remain reference
  stores and are excluded from profile logs and route extras.

### Financial plans

At `28d0097f65b2f0a88d3ae6610614d912d0ba943a`, `app.dart` registers an eager
`ChangeNotifierProxyProvider<CoachProfileProvider, FinancialPlanProvider>`.
Creation starts plan hydration and every proxy update idempotently attaches the
current ledger provider. A non-null plan is stale while that provider is
unbound, unloaded or has no profile; after load, staleness is the inequality
between its persisted `mint-plan-dependency:v3:sha256:<digest>` and the
branch-scoped dependency fingerprint
of the current ledger snapshot.

The v3 envelope always binds the canonical owner, user-owned goal amount,
category and target date, the selected branch and capital basis, and the
calculator-contract version. Its fact set is deliberately branch-scoped:
`general` consumes no unrelated ledger facts; `retirementNoLpp` consumes only
the owned pension-fund affiliation and exact birth fact; `retirementLpp`
additionally consumes owned gender, current salary, strict self-LPP capital
facts and the current legal/regulatory schedule. A salary change therefore
does not falsely invalidate `retirementNoLpp`, while a birth-fact change does.
Null and zero remain distinct, non-finite input is rejected, instants are UTC,
and business/source dates are calendar dates. Versioning deliberately makes
an older or structurally incomplete envelope fail closed.

Both live consumers obey the same boundary. `WidgetRenderer` in Coach and
`FinancialPlanCard` on Aujourd'hui hide every stale figure and narrative, use
the stable semantics `financial_plan_stale_state` and
`financial_plan_stale_recalculate`, and regenerate from the loaded ledger only.
Recovery preserves only the prior goal description, category, target date and
final milestone target; it never turns the old monthly plan output or an LLM
tool amount into a fact or calculator input. Aujourd'hui renders this recovery
surface for both empty and populated timelines, so cold recovery does not
depend on non-persisted rich coach tool calls.

The exact-SHA acceptance proof is complete: the writer persisted a synthetic
`retirementNoLpp` plan, a real process death separated the cold reader, the
recovery recalculated from a consumed birth-fact mutation without reverse
writing ledger facts, and the exact physical production entrypoint was built,
signed, installed and traversed by Maestro. The startup barrier distinguishes
`landing_route` from the production `/home` readiness id `home_route`. The
product-domain Sonnet rerun and final Opus code confirmation both passed with
zero P0/P1. This promotes BND-06 to technical GREEN only. The compile-time
feature remains test-only and defaults false; activation and G1 remain NO-GO,
and G2/G3 stay unauthorized.

## Route payload boundary

The production `GoRouter.extra` contract is an explicit allowlist, not a
permission for arbitrary strings or enums: the named `DocumentType` scan
values, the opaque `scanSessionId`, or the exact two-key sequence map
`{'runId': ..., 'stepId': ...}`. Salary, pension, cash, tax, wizard-answer
maps, profile objects, callbacks, streams, and financial prefill are forbidden.
The executable gate defines the allowlist/inventory, parses every writer, and
validates every raw reader recursively across `lib/**/*.dart`
(`apps/mobile/test/routing/no_domain_data_in_extra_test.dart:5-20,32-37,143-225,256-355,357-467`).
Its coach-specific assertions prove both `context.push(route)` without `extra`
and the absence of a prefill facade in the renderer/planner/card sources
(`no_domain_data_in_extra_test.dart:448-467`).

`COACH-PREFILL-RISK` is closed by `e1d42191a`, not an open ticket. At the
snapshot above, `WidgetRenderer` ignores legacy `route`, `is_partial`, and
`prefill` tool inputs, derives the canonical route/readiness from
`RoutePlanner` plus `CoachProfile`, and builds a card with no payload
(`widget_renderer.dart:96-132`). The ready-path fixture marks canton known only
with a `userProvidedFields` canton marker plus `dataTimestamps['canton']`, then
proves `/rachat-lpp`, no warning, and null destination extra
(`widget_renderer_test.dart:25-44,99-132`).

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
3. `ProfileProvider`, its import and its app registration remain absent; the
   sole production protection reader uses `CoachProfile.isInDebtCrisis`, fails
   closed when no profile exists, and no compatibility facade is reintroduced.
4. Provider islands are classified exactly as above and each required bridge
   has a failure predicate and red-to-green command.
5. Scenario writes cannot mutate durable fact targets.
6. Provenance and ownership gaps are implemented or represented by checked-in
   blocking tickets with explicit P0-loop impact.

Required grep proofs:

```bash
rg -n "\bProfileProvider\b|providers/profile_provider\.dart" apps/mobile/lib
rg -n "models/profile\.dart" apps/mobile/lib/services/api_service.dart apps/mobile/lib/services/wizard_service.dart
rg -n "GoRouterState\.of\(context\)\.extra|state\.extra" apps/mobile/lib/screens apps/mobile/lib/app.dart
rg -n "ReportPersistenceService\.saveAnswers|wizard_answers_v2" apps/mobile/lib
rg -n "profile_owner_id|scenario_id|dataSourceDates|data_sources|data_updated|data_source_dt" apps/mobile/lib services/backend/app
```

This decision does not authorize the missing bridges or loop implementations;
it defines the boundary they must satisfy.
