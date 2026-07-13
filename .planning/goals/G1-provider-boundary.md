# G1 Provider Boundary Decision

> Status: binding G1 architecture decision.
> Scope: provider ownership and data movement only. No G2/G3 implementation is
> authorized by this document.
> Evidence snapshot: code and gates rechecked at immutable commit
> `e2cfef057c197b3b8ac122d9a9aa3ca645c85696` on 2026-07-13.

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
| `ProfileProvider` | legacy migration debt | temporary compatibility for three named `hasDebt` consumers only | current-fact hydration, new consumers, new writes, ownership of backend truth | Freeze, choose explicit debt semantics for the three remaining consumers, migrate them, prove grep zero, then remove provider/model registration | G1-BND-01 | yes |
| `BudgetProvider` and `BudgetLocalStore` | derived scenario/cache island | compute budget plan; cache scenario overrides; hydrate base inputs from `CoachProfile.depenses` | authoritative housing, premium, income, cash, or debt facts | Keep overrides local; bridge confirmed base facts through `CoachProfileProvider`; rehydrate cache from ledger | G1-BND-03 | yes |
| `HouseholdProvider` | membership/reference island | invitations, roles, consent, linked member IDs | authoritative partner salary, AVS, LPP, cash, or civil facts | Bridge confirmed partner facts with partner owner token; keep membership metadata separate | G1-BND-02 | yes |
| `DocumentProvider` | raw reference store | upload state, document ID, parse status, raw document lifecycle | direct financial truth consumed by screens | Confirmed extracted facts write through ledger; navigation passes document ID only | G1-BND-05 | yes |
| `TimelineProvider` | reference/read model | document/conversation references and chronology | separate financial facts or alternate profile | Read financial dimension from ledger; keep timeline object IDs outside ledger | G1-BND-05 | no |
| `FinancialPlanProvider` | derived artifact cache | store a generated plan and its profile hash; mark stale | feeding plan outputs back into facts | Wire staleness to profile changes or convert registration to a proxy; no reverse fact writes | G1-BND-06 | no |
| backend `ProfileModel.data` | remote mirror | authenticated sync of canonical facts and provenance | primary mobile read path, profile-global freshness pretending to be per-field freshness | Add per-field source/update/source-date ownership contract through a reviewed backend slice | G1-PROV-01 | yes |

## Legacy `ProfileProvider` migration set

The 2026-07-13 slice removed the `/pilier-3a` legacy fact-hydration fallback.
Its simulator inputs now hydrate from `CoachProfileProvider`
(`simulator_3a_screen.dart:114-153`); this is not a claim that every fact is
canonical because the protective debt gate still reads the legacy provider.
The previously listed comparator path did
not exist in the production tree and is removed from this inventory rather than
kept as fictive debt.

This does not make every 3a field live: the P1 `has3a` ledger row is separately
`quarantined` because its former model-adapter anchor was an unqualified read,
not an independent production consumer. That semantic gap is distinct from the
three remaining legacy `hasDebt` provider consumers below.

The deletion precondition is now grep zero for the three remaining production
consumers, all of which read `hasDebt` for protective gating:

| consumer | current read | migration decision |
|---|---|---|
| `apps/mobile/lib/screens/simulator_3a_screen.dart:182` | legacy `hasDebt` | Choose explicitly between any-debt `CoachProfile.dettes.hasDette` and protective `CoachProfile.isInDebtCrisis`; add a test for the chosen semantics. Simulator input hydration is already on `CoachProfileProvider`. |
| `apps/mobile/lib/widgets/simulators/buyback_widget.dart:39` | legacy `hasDebt` | Same explicit debt-semantics decision; do not substitute blindly. |
| `apps/mobile/lib/widgets/recommendation_card.dart:17` | legacy `hasDebt` | Same explicit debt-semantics decision; preserve the intended recommendation gate. |

`ProfileProvider` remains registered at `apps/mobile/lib/app.dart:1521`. Removal
is allowed only after the three migrations, tests, and grep-zero proof land in
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

`FinancialPlanProvider.attachProfileProvider` exists at
`apps/mobile/lib/providers/financial_plan_provider.dart:76`, while `app.dart`
registers a plain provider at `apps/mobile/lib/app.dart:1584`. The plan is a
derived artifact: wire staleness, do not feed plan numbers back into facts.

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
3. The three remaining legacy `hasDebt` consumers are migrated or have
   blocking tickets accepted by the G1 template; no new consumer exists.
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
