# SCREEN_CONTRACTS.md — Per-Route Wiring Contracts (MINT)

> **G1 reality audit:** the route-payload/scenario addendum was re-checked at immutable commit `e2cfef057c197b3b8ac122d9a9aa3ca645c85696` on 2026-07-13. Older `file:line` references remain evidence snapshots, not evergreen truth. Rerun `tools/checks/tests/test_codex_spec_reality_contract.py` after changing this spec or the cited code.

> Source of truth for target route wiring. Audited against `apps/mobile/lib/app.dart`, `apps/mobile/lib/routes/route_metadata.dart`, `apps/mobile/lib/models/coach_profile.dart`, `apps/mobile/lib/models/mint_user_state.dart`, `apps/mobile/lib/providers/mint_state_provider.dart`, `apps/mobile/lib/providers/coach_profile_provider.dart`, `apps/mobile/lib/services/confidence/enhanced_confidence_service.dart`, `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart` at commit `095eeaa32`.
> Focused BND-02/BND-02A reality baseline: technical GREEN at exact SHA
> `1d022c508` (2026-07-16) with identical-command, Patrol, Maestro and bounded
> Claude-wrapper proof. The progressive caller and visible consumer remain
> default-off; eight external facts keep activation and G1 NO-GO.
> Focused BND-06 technical GREEN: semantic RED `9e86539d2`; the bounded
> contract is accepted at exact pushed SHA
> `28d0097f65b2f0a88d3ae6610614d912d0ba943a` (2026-07-17). Writer -> real
> process death -> cold reader, the exact physical production-entrypoint
> build/sign/install and Maestro passed; the product-domain Sonnet rerun and
> final Opus code confirmation passed with zero P0/P1. The compile-time path
> remains test-only and defaults false. Activation and G1 remain NO-GO; G2/G3
> stay forbidden.
> Focused FRONT-01 implementation snapshot: `/segments/frontalier` is
> provider-backed and code-GREEN at pushed SHA `733571002` (2026-07-17).
> Runtime Patrol/Maestro evidence and both Claude-wrapper audit lenses remain
> pending; this is not ticket promotion, G1 closure, or G2/G3 authorization.
> Every field named in reads[]/writes[] resolves to a documented entry in `DATA_LEDGER.md` (ledger names: `confidenceScore`, `dataSources`, `dataTimestamps`, `dataSourceDates`, `budgetGap`, `currentCap`, `friScore`, `lifecyclePhase`, `archetype`, `financialLiteracyLevel`, `profile.*`).
> A coding agent (Codex) implements these contracts directly. Every row is mechanical and test-verifiable. Violations are bugs, not style notes.

---

## 0. HARD RULE — stated up front, applies to EVERY route

**Domain data NEVER travels via `GoRouter.extra`.**

The checked-in `GoRouter.extra` allowlist is exact: the named
`DocumentType` scan values, opaque `scanSessionId`, or an exact two-key
`Map<String, dynamic>` containing `runId` plus `stepId`. It does **not** allow
an arbitrary `String`, arbitrary enum, callback, stream, or map. Path/query
parameters separately carry route identifiers, invitation codes, magic-link
tokens, and ephemeral UI selection. Neither transport may carry
`CoachProfile`, `MintUserState`, `ExtractionResult`, `wizardAnswers`,
`ConfidenceResult`, budget snapshots, or any object a screen needs to render
its financial content.

Every screen resolves the domain data it renders from the **ledger**:
- Profile / computed state → `context.watch<MintStateProvider>().state` (`MintUserState`) and `context.read<CoachProfileProvider>().profile` (`CoachProfile`).
- Scan extraction in-flight → live volatile `ScanSessionProvider` (§5.0), keyed by the opaque `scanSessionId`; review/impact routes pass it as a query identifier, not a financial payload.
- Documents → `DocumentsProvider` / `BiographyRepository` by `id`.
- Confidence → read `MintUserState.confidenceScore` (ledger field; upgraded to the 4-axis result per §8.0), never passed in.

**Test that enforces this rule (must exist):** `test/routing/no_domain_data_in_extra_test.dart` — see §10.1 for the exact matcher and harness.

**G1 live status at 2026-07-13: mechanical hard floor green.** The checked-in
gate recursively scans production `lib/**/*.dart`, parses writers, validates
raw readers against the exact allowlist, carries seeded negative fixtures, and
proves coach route suggestions expose neither prefill nor payload extra
(`apps/mobile/test/routing/no_domain_data_in_extra_test.dart:5-20,32-37,143-225,256-355,357-467`).
Empty/partial/stale/error/return-to-origin behavior remains governed by the
route-state matrix and its blocking tickets; a green payload gate does not
claim those user states are complete.

---

### 0.1 Known / estimated / missing model contract (Phase 37 Wave 1)

Screens must not infer knowledge from a non-null display fallback. A field is:

- **known** only when its canonical storage key produced the matching
  `userProvidedFields` marker and `dataTimestamps` entry;
- **estimated** when a display fallback is available without that marker; it
  remains visibly labelled and cannot unlock a complete/high-stakes result;
- **missing** when neither a known marker nor an admissible display estimate
  exists; the screen renders the exact DIFF question or recovery CTA.

The direct fields `pillar3aAnnualContribution`,
`monthlySavingsContribution`, and `hasPillar3a` are independent current facts.
Consumers may not infer one from another or from `q_savings_allocation`. A
current-fact screen uses `typedFact ?? legacyValue`, never a sum. The legacy
value is migration fallback only; `plannedContributions` remains an independent
plan/scenario lever and must not be rewritten by a direct-fact `copyWith`.

AVS consumers read the declared `avsGapStatus` separately from the nullable
certified count in `prevoyance.lacunesAVS`. `q_avs_years_abroad`, an arrival
interval, or `no_gaps` never becomes a certified year count and never receives
`certificate` provenance. The declared status is `userInput` with its own
timestamp. `q_avs_contribution_years` is also `userInput` unless its persisted
write carries `_coach_avs_source=document_scan`; its source and timestamp remain
separate from the declared status. Missing/stale source or freshness, an unknown
status, or a status/year contradiction renders a visibly incomplete state with
the reconfirmation CTA; it cannot earn a confirmed no-gap state. Mortgage
consumers likewise receive either the chronology-reconciled canonical balance or an
unknown value when legacy/canonical timestamps cannot establish a winner.

For a couple, `q_spouse_avs_lacunes_status`,
`q_spouse_avs_arrival_year`, and `q_spouse_avs_years_abroad` remain declared
chronology only; none fills `conjoint.prevoyance.lacunesAVS`. That numeric field
requires the spouse's CI/certificate. `q_spouse_avs_contribution_years` remains
a separate contribution-history fact. A couple AVS score is incomplete when
either numeric gap count is missing; when both are confirmed, each person is
scored independently and the worse score is retained. Screens never sum the two
people's gap years into a household total.

`CoachProfileProvider -> MintStateProvider` has one proxy edge. A new canonical
snapshot (including a provenance-bearing snapshot) recomputes once; an
identical snapshot is a no-op. This exact behavior is guarded by
`test/providers/mint_state_proxy_recompute_test.dart`. It does not imply that
the other provider islands are already bridged.

---

## 1. Column semantics

| Column | Meaning |
|---|---|
| **route** | Path as registered in `app.dart`. |
| **shell** | `shell:<branchIndex>` if the route lives inside the `StatefulShellRoute.indexedStack` (app.dart:345); `root` if registered on `_rootNavigatorKey`; `redirect` if it is a redirect-only entry. See §1.1. |
| **reads[]** | Ledger fields/providers the screen reads. `∅` = none. Every name resolves in `DATA_LEDGER.md`. |
| **writes[]** | Ledger fields written, ALWAYS via `CoachProfileProvider.mergeAnswers()/applySaveFact()/updateProfile()`. `∅` = read-only. |
| **entryConditions** | Guard before render. `none` = always enterable. Guards are `ReadinessGate` REDIRECTS; in-screen mode switches are NOT entry conditions (see §1.2). |
| **emptyState** | REQUIRED. Shown when ledger has no data for this screen. Recovery CTA + i18n key. |
| **partialState** | REQUIRED where `reads[]` has ≥1 field. Shown when ledger has *some* but not all needed fields. Drives DIFF collection, not a form. Enforced by §10 test 4. |
| **errorState** | REQUIRED. Shown on resolution/compute failure (incl. timeout). Recovery CTA + i18n key. |
| **routesOut[]** | Reachable destinations (CTAs / navigation). Every target exists in `app.dart`. |
| **killFlag** | The exact `RouteMeta.killFlag` value (`FeatureFlags.<name>`) or `null`. See §1.3 — these are the REAL values; do not write `live`. |

All `i18n key` values below are keys the agent MUST add to all 6 ARB files (`lib/l10n/app_{fr,en,de,es,it,pt}.arb`) and resolve via `AppLocalizations.of(context)!`. Accents 100% FR in the FR ARB.

### 1.1 Shell vs root registration (do not misregister)

`/home`, `/mon-argent`, `/coach/chat`, `/explore` are the four branches of the `StatefulShellRoute.indexedStack` in `app.dart:345`. The agent MUST register them as `StatefulShellBranch`es (they already are) and MUST NOT flatten them into top-level `GoRoute`s. Their contracts below are the per-branch root screen contracts; the shell wrapper (bottom nav) is unchanged.

**Navigating INTO a shell branch with query params** (e.g. the `/tools` repair targeting `/coach/chat?topic=…`): use `context.go('/coach/chat?topic=investment')`. `GoRouter` resolves the URI to the coach branch and rebuilds the branch root with `state.uri.queryParameters` available. Do NOT use `StatefulNavigationShell.goBranch(index)` for this — `goBranch` cannot carry query params. The coach branch root screen reads `topic` from `GoRouterState.of(context).uri.queryParameters`.

### 1.2 entryConditions vs in-screen mode (mechanical rule for guarded simulators)

Two distinct compile targets. Pick ONE per route, never both:
- **Entry guard (redirect):** implemented in the route's `redirect:` via `ReadinessGate`. Used ONLY when the screen is meaningless below a threshold. Redirects to the stated fallback route.
- **In-screen mode switch:** implemented inside the screen `build()`. Used when the screen renders in *illustrative/general-population* mode below threshold and *personalised* mode above. This is NOT an entryCondition; it is a `partialState`/render-mode branch.

For every simulator in §4 the rule is fixed: **simulators use the in-screen mode switch, NEVER an entry-guard redirect.** Their `entryConditions` is therefore `none`; the confidence threshold selects render mode inside the screen (illustrative ↔ personalised), which is asserted by `test/routing/simulator_mode_switch_test.dart` (below-threshold profile → illustrative-mode marker widget present, no redirect fired).

### 1.3 killFlag reference (verified from route_metadata.dart)

- Shell/destination/system routes (`/home`, `/mon-argent`, `/explore`, `/rapport`, `/confidence`, `/timeline`, `/documents`, `/couple`, `/portfolio` target) → `killFlag: null`.
- Redirect aliases (`/tools`, `/portfolio`, `/score-reveal`, `/document-scan`, `/report`, onboarding shims) → `killFlag: null` (category `alias`).
- `/coach/chat` and its content routes → `enableCoachChat`.
- `/scan`, `/scan/*` → `enableScan`.
- `/mon-argent` budget content, `/budget`, `/budget/setup` → `enableBudget`.
- Explorer hubs + their domain simulators → `enableExplorer{Retraite|Famille|Travail|Logement|Fiscalite|Patrimoine|Sante}` matching the domain (see per-row values in §3/§4).
- Admin routes (`/profile/admin-observability`, `/profile/admin-analytics`, `/admin/routes`) → `enableAdminScreens` (in-route redirect guard; `/admin/routes` additionally tree-shaken behind `AdminGate.isAvailable`).
- `/open-banking`, `/open-banking/*` → `enableOpenBanking` (in-route redirect guard).
- `/anonymous/*` → `enableAnonymousFlow`.

Any new route the agent adds MUST set `killFlag` to one of the above metadata strings or `null`, and MUST pass `tools/checks/route_registry_parity.py`. G1 note: most values are forward-referenced metadata for Phase 33; runtime `FeatureFlags` currently exposes only OpenBanking/Admin gates plus supporting config.

---

## 1.5 Auth + public routes (root; outside the shell)

These are registered at the top of the router (`app.dart:301-339`) with `scope: RouteScope.public`. No profile/ledger reads; they gate access to the rest of the app. They are LIVE builder routes and each needs a non-blank error state.

| route | screen | reads | writes | entryConditions | emptyState | partialState | errorState | routesOut[] | killFlag |
|---|---|---|---|---|---|---|---|---|---|
| `/` (app.dart:302) | `LandingScreen` | ∅ | ∅ | none | n/a (static landing) | n/a | render failure → static hero + CTA `/auth/login`. i18n `landing.error.title` | `/auth/login`, `/auth/register`, `/anonymous/chat` | null |
| `/auth/login` (307) | `LoginScreen` | ∅ | ∅ (auth token via auth service, not the ledger) | none | n/a | n/a | login failure → inline error banner + Réessayer; NEVER blank. i18n `auth.login.error` | `/home`, `/auth/register`, `/auth/forgot-password` | null |
| `/auth/register` (312) | `RegisterScreen` | ∅ | ∅ | none | n/a | n/a | register failure → inline error banner. i18n `auth.register.error` | `/auth/verify-email`, `/auth/login` | null |
| `/auth/forgot-password` (317) | `ForgotPasswordScreen` | ∅ | ∅ | none | n/a | n/a | send failure → inline error + Réessayer. i18n `auth.forgot.error` | `/auth/login` | null |
| `/auth/verify-email` (322) | `VerifyEmailScreen` | ∅ | ∅ | none | awaiting verification → "Vérifie ta boîte mail." + renvoyer CTA. i18n `auth.verifyEmail.title` | n/a | verification poll failure → Réessayer. i18n `auth.verifyEmail.error` | `/home`, `/auth/login` | null |
| `/auth/verify` (327) | `_MagicLinkVerifyScreen(token: query['token'])` | `token` from `state.uri.queryParameters['token']` (id only, §0) | ∅ | none | token missing → "Lien invalide." CTA `/auth/login`. i18n `auth.verify.empty` | n/a | token expired/verify failed → "Ce lien n'est plus valide." CTA `/auth/login`. i18n `auth.verify.error` | `/home`, `/auth/login` | null |
| `/anonymous/chat` (336) | anonymous coach chat (`intent` from query) | `intent` from `state.uri.queryParameters['intent']` (enum, §0) | ∅ (anonymous; no ledger write) | none | no intent → generic opener. i18n `anonymous.empty.opener` | n/a | transport failure → safe fallback bubble + Réessayer. i18n `anonymous.error.fallback` | `/auth/register`, `/coach/chat` | enableAnonymousFlow |

---

## 2. Shell tabs

### `/home` — Pulse
| | |
|---|---|
| shell | shell:0 |
| purpose | Daily lucidity pulse: one true thing about the user's money now. |
| reads | `MintUserState{profile, lifecyclePhase, archetype, budgetGap, currentCap, confidenceScore, friScore}`; `FinancialPlanProvider{currentPlan,isPlanStale}` |
| writes | ledger ∅; stale-plan recovery replaces only the derived `financial_plan_v1` artifact through `FinancialPlanProvider.setPlan()` |
| entryConditions | none |
| emptyState | No profile → calm card "Commençons par une chose vraie." CTA → `/coach/chat?topic=premier-eclairage` (real destination — see §2.note). i18n `home.empty.title` / `home.empty.cta` |
| partialState | Minimal profile (age+salary+canton only) → budget insight + band widened honestly + `enrichmentPrompts` (ranked, top 3). MUST render at least one prompt CTA to `/data-block/:type`. A loaded plan with absent/unloaded/null or mismatched ledger authority renders only `financial_plan_stale_state` and `financial_plan_stale_recalculate`; no plan amount, projection, milestone, date or narrative is visible. i18n `home.partial.enrichHint` |
| errorState | `MintStateProvider` compute threw → "On n'a pas pu rafraîchir ton aperçu." CTA Réessayer → `context.read<MintStateProvider>().recompute(context.read<CoachProfileProvider>().profile)` + CTA `/coach/chat`. i18n `home.error.title` / `home.error.retry` |
| routesOut | `/mon-argent`, `/coach/chat`, `/explore`, `/data-block/:type`, `/confidence`, `/rapport` |
| killFlag | null |

> §2.note — **No real first-insight onboarding screen exists**; `/onboarding/premier-eclairage` is an alias shim → `/coach/chat` (route_metadata.dart:1054). Every "start here" recovery CTA in this document therefore targets `/coach/chat?topic=premier-eclairage` directly, and the coach branch seeds a first-insight opener from that `topic` (i18n `coach.empty.opener.premierEclairage`). The agent MUST NOT route recovery CTAs to the shim.
> Invariant F-1/F-4: confirmed budget base facts publish through
> `CoachProfileProvider` and refresh both eager proxies. Their present-budget
> oracle is `MintUserState.budgetSnapshot.present.monthlyCharges/monthlyFree`.
> `BudgetProvider` keeps one local scenario envelope (`future` XOR `variables`),
> never both. The last edited field wins and does not mutate `MintUserState`;
> `budgetGap` remains null while official AVS
> facts are unavailable. See §10.4.
>
> **BND-06 plan boundary (technical GREEN at
> `28d0097f65b2f0a88d3ae6610614d912d0ba943a`).**
> Aujourd'hui watches the eagerly bound `FinancialPlanProvider` and renders
> `FinancialPlanCard` in both empty- and populated-timeline branches. A
> persisted plan fails closed until `CoachProfileProvider.isLoaded` with a
> non-null profile, then whenever its branch-scoped v3 dependency envelope is
> incomplete, expired or differs from the current ledger inputs consumed by
> that branch. In particular, `retirementNoLpp` depends on owned affiliation
> and exact birth facts, not salary; `retirementLpp` additionally requires the
> owned gender, current salary, strict self-LPP facts and current legal
> contract. Recovery preserves only goal description/category, target date and
> final target amount, and recomputes the artifact from the current loaded
> ledger. Its local in-flight/error guards prevent duplicate taps and unsafe
> publication. The exact runtime barrier waits for the unique `landing_route`,
> opens `mint:///home`, then waits for the distinct production `home_route`
> before asserting stale recovery. The test-only compile-time flag remains
> default-off; technical GREEN is not an activation decision.

### `/mon-argent` — Money / Budget home
| | |
|---|---|
| shell | shell:1 |
| purpose | The user's budget reality: income, fixed, variable, gap. |
| reads | `MintUserState{budgetSnapshot.present, budgetGap}`, `BudgetProvider` |
| writes | confirmed budget fields → `mergeAnswers()`; the published profile independently refreshes the eager BudgetProvider and MintStateProvider proxies (§10.4) |
| entryConditions | none |
| emptyState | No budget data → "Trois chiffres suffisent pour un premier aperçu." CTA `/budget/setup`. i18n `money.empty.title` / `money.empty.cta` |
| partialState | Income known, expenses missing → partial gap with "estimation" tag + inline DIFF CTA to add expenses. i18n `money.partial.addExpenses` |
| errorState | Gap compute failed → message + Réessayer(`recompute(profile)`) + `/coach/chat`. i18n `money.error.title` |
| routesOut | `/budget/setup`, `/budget`, `/data-block/revenu`, `/data-block/patrimoine`, `/open-banking`, `/coach/chat`, `/home` |
| killFlag | null (budget CONTENT widgets gate on `enableBudget`) |

### `/coach/chat` — Coach
| | |
|---|---|
| shell | shell:2 |
| purpose | Conversational lucidity; teaches mechanisms, refuses advice. Compliance filter on every utterance. |
| reads | `CoachProfile` (full), `MintUserState`, eagerly bound `FinancialPlanProvider{currentPlan,isPlanStale}`, `conversationId` from `state.uri.queryParameters['conversationId']` or `_chat_conversation_index`; `topic` from query params |
| writes | facts via `save_fact`→`applySaveFact()` (§6.note on provenance); conversation persists in its reference store; plan recovery writes only the derived `financial_plan_v1` artifact through `FinancialPlanProvider.setPlan()` |
| entryConditions | none (also the `/tools`, `/ask-mint`, `/anonymous/chat`, `/onboarding/*` redirect target) |
| emptyState | No history → seeded opener from `topic` query param if present (e.g. `?topic=lpp`, `?topic=investment`, `?topic=premier-eclairage`). i18n `coach.empty.opener` (+ per-topic variants) |
| partialState | If `topic` references a missing field → coach asks that field's DIFF question. A `generate_financial_plan` call waits separately for plan hydration and ledger report answers before first generation; an existing stale plan renders only `financial_plan_stale_state` plus `financial_plan_stale_recalculate`, with every amount/date/narrative hidden and LLM `monthly_amount` ignored. i18n `coach.partial.askField` |
| errorState | LLM/transport failure → safe fallback bubble + Réessayer; NEVER blank. i18n `coach.error.fallback` / `coach.error.retry` |
| routesOut | `/data-block/:type`, `/confidence`, `/explore`, `/coach/history`, any simulator deep-link |
| killFlag | enableCoachChat |

#### G1-COACH-01 — inline amounts (accepted contract, `green`)

The live `ask_user_input` amount path is
`WidgetRenderer/ChatAmountInput → CoachMessageBubble → CoachChatScreen`.
G1-COACH-01 makes every callback in that chain asynchronous and awaits the
single provider write before marking the input answered or emitting its echo.
It has exactly three accepted mappings: `salaireBrut → incomeGrossYearly`,
`avoirLpp → avoirLpp`, and `epargne3a → pillar3aBalance`. The first value is an
annual salary: profile reconstruction uses the already-persisted contractual
period count (`12` gives CHF 10,000/month for CHF 120,000/year; `13` gives about
CHF 9,230.77/month). LPP and 3a are stock balances; the flow must not infer
contributions, components, advice, or normative targets.

Zero is valid. Negative, NaN, and infinite values fail before persistence and
produce no answered marker, notification, or echo. A manual loose LPP value
must fail closed before persistence whenever `typedLppEvidence` is active and a
strict LPP root key is present, even if the root is malformed/stale or has no
current selector; it must never become a second authority or return a false
success. The retry state may offer `/scan?type=lppCertificate` for
reconciliation. A failed save keeps the input retryable. Success order is
durable `applySaveFact` → one
provider notification → answered marker/echo, and the value must survive a cold
reload with `{source: userInput, updatedAt, sourceDate: null}`. Do not add a
`ChatDataCaptureHandler`, alias key, or parallel persistence facade: none exists
in the live chain. The exact registry command is 14/14 at pushed SHA `fec1d4119e`; dedicated
Patrol is 1/1 with accepted visual evidence, and both first-pass wrapper audit
lenses pass with P0/P1=0. This is bounded ticket evidence only: G1 stays NO-GO
and G2/G3 remain forbidden.

Coach stale-plan recovery uses the same persisted goal description/category,
target date and final target amount as Aujourd'hui, but recalculates every
financial output from the current loaded `CoachProfile`. The two stable
semantics identifiers are intentionally shared across both surfaces for
Maestro/Patrol. Rich tool calls remain conversation-local; Aujourd'hui is the
durable cold recovery caller after process death.

### `/coach/history` — Conversation history (root, app.dart:632)
| | |
|---|---|
| shell | root |
| purpose | List past coach conversations; reopen one. |
| reads | conversation store (`_chat_conversation_index`) |
| writes | ∅ |
| entryConditions | none |
| emptyState | No conversations → "Aucune conversation pour l'instant." CTA `/coach/chat`. i18n `coachHistory.empty.title` / `.cta` |
| partialState | n/a (list) |
| errorState | Store read failed → message + Réessayer + CTA `/coach/chat`. i18n `coachHistory.error.title` |
| routesOut | `/coach/chat?conversationId=<id>`, `/coach/chat` |
| killFlag | enableCoachChat |

### `/explore` — Explorer root
| | |
|---|---|
| shell | shell:3 |
| purpose | Entry to the 7 life-domain hubs. |
| reads | `MintUserState{archetype, lifecyclePhase}` |
| writes | ∅ |
| entryConditions | none |
| emptyState | Never truly empty (hubs static). Archetype unknown → all 7 unranked. i18n `explore.empty.allDomains` |
| partialState | Archetype known → reorder hubs by relevance; mark unexplored. i18n `explore.partial.suggested` |
| errorState | State read failed → static 7 hubs (graceful degrade) + banner "ordre par défaut". i18n `explore.error.defaultOrder` |
| routesOut | `/explore/{retraite,famille,travail,logement,fiscalite,patrimoine,sante}` |
| killFlag | null |

---

## 3. The 7 Explorer hubs

All 7 share the shape below; only `reads` slice, `routesOut`, and `killFlag` differ. Each is a `GoRoute` on `_rootNavigatorKey`.

**Shared shape**
- writes: ∅ (collection happens in `/data-block/:type`)
- entryConditions: none
- emptyState (REQUIRED): "Tu n'as encore rien renseigné sur {domaine}." CTA → the hub's primary `/data-block/:type`. i18n `explore.<domain>.empty.title` / `.cta`
- partialState (REQUIRED): known facts as confidence-tagged tiles + ranked enrichment prompts (`rankEnrichmentPrompts`) filtered to this domain; MUST render ≥1 prompt or a "tout est à jour" re-confirm tile. i18n `explore.<domain>.partial.enrich`
- errorState (REQUIRED): "On n'a pas pu charger {domaine}." CTA Réessayer + CTA `/coach/chat`. i18n `explore.<domain>.error.title`

| route | domain | killFlag | reads (ledger slice) | routesOut[] |
|---|---|---|---|---|
| `/explore/retraite` | retirement | enableExplorerRetraite | `prevoyance{avoirLppTotal, renteAVSEstimeeMensuelle, lacunesAVS}`, `targetRetirementAge`, `archetype` | `/retraite`, `/rente-vs-capital`, `/rachat-lpp`, `/pilier-3a`, `/decaissement`, `/libre-passage`, `/data-block/{lpp,avs,3a}` |
| `/explore/famille` | family | enableExplorerFamille | `nombreEnfants`, `conjoint`, `gender` | `/mariage`, `/naissance`, `/concubinage`, `/divorce`, `/succession`, `/data-block/compositionMenage`, `/couple` |
| `/explore/travail` | work | enableExplorerTravail | `employmentStatus`, `salaireBrutMensuel`, `archetype` | `/first-job`, `/unemployment`, `/segments/independant`, `/simulator/job-comparison`, `/expatriation`, `/data-block/revenu` |
| `/explore/logement` | housing | enableExplorerLogement | `patrimoine`, mortgage fields | `/hypotheque`, `/mortgage/amortization`, `/mortgage/epl-combined`, `/mortgage/imputed-rental`, `/mortgage/saron-vs-fixed`, `/epl`, `/arbitrage/location-vs-propriete`, `/data-block/patrimoine` |
| `/explore/fiscalite` | tax | enableExplorerFiscalite | `canton`, `salaireBrutMensuel`, tax-regime | `/fiscal`, `/3a-retroactif`, `/cantonal-benchmark`, `/data-block/fiscalite`, `/scan` |
| `/explore/patrimoine` | wealth | enableExplorerPatrimoine | `patrimoine`, `prevoyance` | `/arbitrage/bilan`, `/arbitrage/allocation-annuelle`, `/data-block/patrimoine`, `/open-banking` |
| `/explore/sante` | health/insurance | enableExplorerSante | `archetype`, `employmentStatus` | `/assurances/lamal`, `/assurances/coverage`, `/invalidite`, `/disability/insurance`, `/disability/self-employed` |

---

## 4. Life-event + simulator routes

Simulators are **read-current-facts-from-ledger, keep scenario levers local**.
Moving a slider or recalculating a result is never consent to update
`CoachProfile`. Only an explicit, separately labelled “confirm current fact”
action may write through the provider with owner/provenance metadata. The G1
scenario hard floor classifies durable-sink method calls by verb/subject,
proves five bypass shapes red, and scans the six exact audited source files
(`apps/mobile/test/routing/no_scenario_writeback_to_profile_test.dart:5-46,48-90,92-159`).

**Shared simulator shape**
- shell: root
- reads: relevant `CoachProfile`/`MintUserState` fields (per row) — from ledger, NEVER `extra`
- writes: explicit confirmed current-fact actions only → provider fact spine; scenario levers and derived outputs stay local/Case-scoped and never write back on edit
- entryConditions: **none** (per §1.2 — simulators use the in-screen mode switch, not an entry redirect). Below the confidence threshold (finding D: <30 premier_eclairage; 30–50 +projections; 50–70 +arbitrage w/ bands; 70–85 +precise; >85 +full), the screen renders **illustrative mode** (general-population numbers, no personalised compute); at/above, **personalised mode**. Render-mode is chosen from `MintUserState.confidenceScore`.
- emptyState (REQUIRED): missing required input → inline DIFF prompt for exactly the missing field, "estimation" defaults pre-filled + tagged. i18n `<sim>.empty.needInput`
- partialState (REQUIRED): some inputs known → prefill from ledger, ask only the delta; band widened for unknowns; every prefilled-but-stale (freshness <0.60) or estimated field carries an "à confirmer"/"estimation" tag (asserted by §10 test 4). i18n `<sim>.partial.assume`
- errorState (REQUIRED): engine failure/timeout → "Le calcul n'a pas abouti." CTA Réessayer + CTA `/coach/chat`; show last good range if any. i18n `<sim>.error.title`
- EVERY numeric output: range + `EnhancedConfidence` band + "à confirmer / barème {year}" + non-promissory phrasing (invariant F-5)

| route | killFlag | purpose (1 line) | reads (key ledger fields) | routesOut[] |
|---|---|---|---|---|
| `/retraite` | enableExplorerRetraite | Integrated retirement picture (AVS+LPP+3a+PC). | `prevoyance.*`, `targetRetirementAge`, `age`, `archetype`, `conjoint` | `/rente-vs-capital`, `/rachat-lpp`, `/pilier-3a`, `/decaissement`, `/confidence`, `/data-block/lpp` |
| `/rente-vs-capital` | enableExplorerRetraite | Rente vs capital + panachage + survivor. | `prevoyance.avoirLppTotal`, `renteAVSEstimeeMensuelle`, `conjoint`, `gender` | `/decaissement`, `/coach/chat`, `/data-block/compositionMenage` |
| `/rachat-lpp` | enableExplorerRetraite | LPP buy-back trade-offs (vs market). | `prevoyance{avoirLppTotal}`, `salaireBrutMensuel`, `canton` | `/3a-retroactif`, `/fiscal`, `/coach/chat` |
| `/pilier-3a` | enableExplorerRetraite | 3a mechanism + retroactive buy-back (in force tax-year 2025). | `canton`, `salaireBrutMensuel`, `isFatcaResident`, `canContribute3a` | `/3a-retroactif`, `/3a-deep/comparator`, `/3a-deep/real-return`, `/3a-deep/staggered-withdrawal`, `/data-block/3a` |
| `/3a-deep/comparator` | enableExplorerRetraite | 3a provider comparator. | `canton`, `salaireBrutMensuel`, `canContribute3a` | `/pilier-3a`, `/3a-retroactif`, `/coach/chat` |
| `/3a-deep/real-return` | enableExplorerRetraite | 3a real-return (net of fees/inflation) illustration. | `canton`, `salaireBrutMensuel` | `/pilier-3a`, `/3a-deep/comparator`, `/coach/chat` |
| `/3a-deep/staggered-withdrawal` | enableExplorerRetraite | Staggered 3a withdrawal tax illustration. | `canton`, `age`, `prevoyance.*` | `/pilier-3a`, `/decaissement`, `/coach/chat` |
| `/3a-retroactif` | enableExplorerFiscalite | 3a retroactive buy-back (gaps from 2025, current year first). | `canton`, `salaireBrutMensuel`, `age` | `/pilier-3a`, `/fiscal`, `/coach/chat` |
| `/decaissement` | enableExplorerRetraite | Staggered withdrawal calendar. | `prevoyance.*`, `targetRetirementAge`, `canton` | `/rente-vs-capital`, `/coach/chat` |
| `/libre-passage` | enableExplorerRetraite | Vested-benefits (libre passage) mechanism. | `prevoyance{avoirLppTotal}`, `employmentStatus` | `/rachat-lpp`, `/data-block/lpp`, `/coach/chat` |
| `/hypotheque`, `/mortgage/amortization`, `/mortgage/epl-combined`, `/mortgage/imputed-rental`, `/mortgage/saron-vs-fixed` | enableExplorerLogement | Affordability (~33% rule, ~5% calculatory rate), amortisation, EPL-combined, imputed rental value, SARON vs fixed. | `salaireBrutMensuel`, `patrimoine`, `canton`, `prevoyance.avoirLppTotal` | `/epl`, `/hypotheque`, `/arbitrage/location-vs-propriete` |
| `/epl` | enableExplorerLogement | Early withdrawal for property trade-offs. | `prevoyance.avoirLppTotal`, `patrimoine` | `/hypotheque`, `/rachat-lpp`, `/mortgage/epl-combined` |
| `/fiscal` | enableExplorerFiscalite | Tax across 3 tiers; regime-detected. | `canton`, `salaireBrutMensuel`, `archetype`, tax-regime | `/3a-retroactif`, `/scan`, `/coach/chat` |
| `/cantonal-benchmark` | enableExplorerFiscalite | Cross-canton tax/benefit benchmark (illustrative). | `canton`, `salaireBrutMensuel` | `/fiscal`, `/coach/chat` |
| `/divorce`, `/mariage`, `/naissance`, `/concubinage` | enableExplorerFamille | Family life events. | `conjoint`, `nombreEnfants`, `patrimoine`, `prevoyance` | `/succession`, `/couple`, `/data-block/compositionMenage`, `/coach/chat` |
| `/succession` | enableExplorerFamille | Estate organisation / property transmission. Reads property-transmission facts from the ledger only: no fictive patrimoine, no local property-value slider, no recommendation to sell/give/reserve usufruct. If `q_property_market_value` is missing it renders `succession_property_missing` and routes to `/data-block/patrimoine?inputKey=q_property_market_value`; if mortgage is missing after a known property value it routes to `/data-block/patrimoine?inputKey=_coach_dettes_hypotheque`. It may explain Swiss legal/financial forces and prepare questions for notary/fiscalist/bank/pension fund, but it must not present a legal decision as MINT's answer. | `patrimoine.propertyMarketValue`, `_coach_dettes_hypotheque`, `conjoint`, `nombreEnfants`, `canton` | `/data-block/patrimoine?inputKey=q_property_market_value`, `/data-block/patrimoine?inputKey=_coach_dettes_hypotheque`, `/coach/chat` |
| `/life-event/donation` | enableExplorerFamille | Gift/donation lucidity screen. Reads age, canton, civil status, children, broad wealth reference, and property value for real-estate gifts from the ledger only. It must render a missing-facts state and keep result cards hidden until the required facts are user-provided. The estate base for réserve/quotité is shown as an estimated net estate base, not "fortune totale": `q_wealth_estimate` reconciled with user-provided liquid savings from `q_cash_total`, positive user-provided investments from `q_investments_total`, and net real-estate value only when both `q_property_market_value` and `_coach_dettes_hypotheque` are known. `q_wealth_estimate` is not mandatory when these detailed facts already form a positive net estate base; if no broad estimate exists, the screen marks the rebuilt estate base as partial because other assets may still be missing. It must surface the reconciliation status: divergent broad estimate/details require decomposition before high-stakes output, and known property with missing mortgage shows a secondary CTA to `/data-block/patrimoine?inputKey=_coach_dettes_hypotheque`. It must not feed gross property value or heuristic investment estimates into succession-reserve calculations. Real-estate gifts additionally require `_coach_dettes_hypotheque` and use net value through `SuccessionReserveCalculator.netRealEstateGiftValue`. Donation amount, relationship, donation type, and advancement-of-inheritance flag are scenario assumptions to confirm, not profile facts. Marital-property regime is not collected in this screen until MINT has dedicated facts for own property/acquired property and can use them without fake precision. Swiss gift tax must never use a flat hardcoded cantonal rate or silently fallback to another canton; for non-exempt relationships and all descendant gifts it renders an "estimated/to confirm" state and specialist/fiscal-authority checklist unless an authoritative canton table is later wired. It may show educational forces and specialist questions, but no legal/tax recommendation. | `q_birth_year`, `q_canton`, `q_civil_status`, `q_children`, `q_wealth_estimate`, `q_cash_total`, `q_investments_total`, `q_property_market_value` + `_coach_dettes_hypotheque` for real-estate donation | `/data-block/revenu?inputKey=q_birth_year`, `/data-block/revenu?inputKey=q_canton`, `/data-block/composition_menage?inputKey=q_civil_status`, `/data-block/composition_menage?inputKey=q_children`, `/data-block/patrimoine?inputKey=q_wealth_estimate`, `/data-block/patrimoine?inputKey=q_property_market_value`, `/data-block/patrimoine?inputKey=_coach_dettes_hypotheque`, `/coach/chat` |
| `/life-event/deces-proche` | enableExplorerFamille | Death of a relative: survivor benefits + estate steps. | `conjoint`, `nombreEnfants`, `patrimoine`, `canton` | `/succession`, `/coach/chat` |
| `/life-event/housing-sale` | enableExplorerLogement | Sale of a primary residence. | `patrimoine`, `canton`, `prevoyance.avoirLppTotal` | `/hypotheque`, `/fiscal`, `/coach/chat` |
| `/life-event/demenagement-cantonal` | enableExplorerFiscalite | Inter-cantonal move tax/benefit impact. | `canton`, `salaireBrutMensuel`, `nombreEnfants` | `/cantonal-benchmark`, `/fiscal`, `/coach/chat` |
| `/first-job` | enableExplorerTravail | First-job transition. | `employmentStatus`, `salaireBrutMensuel`, `archetype`, `nationality` | `/data-block/revenu`, `/data-block/lpp`, `/coach/chat` |
| `/expatriation` | enableExplorerTravail | Expatriation orientation. Its AVS tab keeps years abroad as a nullable local scenario lever, never an AVS-gap fact; only CI-observed self missing contribution years may unlock a raw contribution-duration benchmark. That benchmark is neither a pension reduction nor an official decision: the compensation office examines possible compensation, then determines the official scale and amount. | `CoachProfile.avsGapEvidence.selfCertifiedYears` only when certificate-ready as CI-observed periods to examine; years abroad is local and nullable | `/scan/avs-guide`, back |
| `/segments/independant` | enableExplorerTravail | Independent entry hub. Reads declared independent income, age, and canton from the Data Ledger; it must render partial/missing state instead of defaulting to a fictive CHF 80'000 / age 42 / ZH scenario. Coverage controls must disclose provenance: voluntary LPP and 3a are profile facts persisted to `q_has_voluntary_lpp` / `q_has_3a`; IJM and LAA are temporary comparison assumptions until their dedicated ledger facts exist. | `employmentStatus`, `q_self_employed_income`, `q_birth_year`, `q_canton`, `q_has_voluntary_lpp`, `q_has_pension_fund`, `q_has_3a` | `/data-block/revenu?inputKey=q_self_employed_income`, `/data-block/revenu?inputKey=q_birth_year`, `/data-block/revenu?inputKey=q_canton` |
| `/unemployment` | enableExplorerTravail | Swiss unemployment lucidity. Reads known ledger facts only; result stays partial until explicit gross annual salary, birth year/date, and LACI contribution months over the last 24 months are user-provided. It must not derive LACI insured earnings from net-income estimates. Children/disability controls are scenario/current-situation levers; children may hydrate from the ledger when already known. Age is a known fact even after 65; the ordinary LACI calculator then renders a non-eligible AVS-reference transition state instead of re-asking age or producing a normal benefit. The budget crash-test must use declared monthly net income plus only ledger expenses (`q_housing_cost_period_chf`, `q_lamal_premium_monthly_chf`, optional transport); it may compare those against a clearly labelled estimated net LACI cash-flow derived from the gross benefit, but never against the gross benefit itself. If budget facts are missing it renders a collection CTA, never invented ratios and never gross-vs-net cash-flow mixing. | `q_gross_salary_annual`, `q_net_income_period_chf`, `q_birth_year`, `q_date_of_birth`, `q_gender`, `q_unemployment_contribution_months`, `q_children`, `q_housing_cost_period_chf`, `q_lamal_premium_monthly_chf`, `depenses.transport` | `/data-block/revenu?inputKey=q_gross_salary_annual`, `/data-block/revenu?inputKey=q_birth_year`, `/data-block/revenu?inputKey=q_unemployment_contribution_months`, `/budget/setup`, `/coach/chat` |
| `/independants/avs`, `/independants/ijm`, `/independants/3a`, `/independants/dividende-salaire`, `/independants/lpp-volontaire` | enableExplorerTravail | Independent: AVS cotisations, daily-allowance (IJM), 3a indep, dividend-vs-salary, voluntary LPP. IJM uses Data Ledger income and birth year only; its 80% output is an illustrative contract scenario, not a legal entitlement or verified policy. 3a indep may use `q_cash_total` as a completion/liquidity fact only when it is an explicit declared cash amount; `q_emergency_fund` heuristics must not unlock that fact. Dividend-vs-salary uses SA/Sarl `q_company_profit_annual_chf`, not sole-proprietor `q_self_employed_income`. | `employmentStatus`, `q_self_employed_income`, `q_company_profit_annual_chf`, `q_birth_year`, `q_has_voluntary_lpp`, `q_has_pension_fund`, `q_has_3a`, `q_cash_total`, `canton`, `prevoyance` | `/segments/independant`, `/data-block/revenu?inputKey=q_self_employed_income`, `/data-block/revenu?inputKey=q_birth_year`, `/data-block/revenu?inputKey=q_company_profit_annual_chf`, `/coach/chat` |
| `/segments/gender-gap` | enableExplorerRetraite | Gender pension-gap illustration. | `gender`, `prevoyance`, `nombreEnfants` | `/retraite`, `/rachat-lpp`, `/coach/chat` |
| `/segments/frontalier` | enableExplorerTravail | Ledger-first frontier-jurisdiction collector and educational orientation. The screen reads `CoachProfileProvider.profile`, writes only `q_residence_country`, `q_work_country`, and conditional `q_work_canton` through `mergeAnswers`, and evaluates `frontierJurisdictionAt(now)`. It renders `missing` with the canonical collector, current known values, the required missing delta and a coach CTA; `stale` with the prior canton plus one-gesture reconfirmation; CH/CH as a known domestic branch with an explicit `/fiscal` CTA; FR/CH/GE as CDI 1966 art. 17 **candidate**; the eight named cantons as accord-1983 **candidate**; and unsupported complete pairs as `specialistOnly`. Fiscal orientation and social-insurance controls stay separate. No state may display a tax amount/rate, universal 90-day gauge, LAMal/CMU ranking, social-affiliation conclusion, barème C default, or 3a eligibility. Permit G, status `frontalier`, nationality, `q_canton`, salary and archetype may open collection but never fill or infer jurisdiction. | `residenceCountry`, `workCountry`, conditional `workCanton`, `dataSources`, `dataTimestamps`, `dataSourceDates`, `userProvidedFields` | `/coach/chat`, `/fiscal` |
| `/invalidite` | enableExplorerSante | Disability-gap explainer. Reads known ledger facts only; result stays partial until salary, birth year/age, explicit `q_cash_total` liquid savings, and explicit monthly fixed charges are user-provided. `q_emergency_fund` heuristics must not unlock cash-sensitive countdowns or scorecards. IJM toggle is a scenario/current-coverage lever, not a profile fact. | `q_gross_salary_annual`, `q_birth_year`, `q_cash_total`, `q_housing_cost_period_chf`, `q_lamal_premium_monthly_chf`, `depenses.*`, `employmentStatus` | `/data-block/revenu?inputKey=q_gross_salary_annual`, `/data-block/revenu?inputKey=q_birth_year`, `/data-block/patrimoine?inputKey=q_cash_total`, `/budget/setup`, `/disability/insurance`, `/disability/self-employed`, `/coach/chat` |
| `/disability/insurance` | enableExplorerSante | Employee disability insurance detail. Reads known ledger facts only; result stays partial until salary, explicit `q_cash_total` liquid savings, and explicit monthly fixed charges are user-provided. `q_emergency_fund` heuristics must not unlock cash-sensitive scorecards. IJM/private insurance toggles are scenario/current-coverage levers, not profile facts. | `q_gross_salary_annual`, `q_cash_total`, `q_housing_cost_period_chf`, `q_lamal_premium_monthly_chf`, `depenses.*`, `employmentStatus` | `/data-block/revenu?inputKey=q_gross_salary_annual`, `/data-block/patrimoine?inputKey=q_cash_total`, `/budget/setup`, `/coach/chat` |
| `/disability/self-employed` | enableExplorerSante | Self-employed disability gap. Reads independent income, explicit `q_cash_total` liquid savings, and monthly fixed charges from ledger; red-screen risk cards unlock only with income + explicit monthly charges, while the countdown also requires explicit `q_cash_total`. `q_emergency_fund` heuristics must not unlock the cash countdown. Loss-of-income insurance toggle is a scenario/current-coverage lever. | `q_self_employed_income`, `q_cash_total`, `q_housing_cost_period_chf`, `q_lamal_premium_monthly_chf`, `depenses.*`, `employmentStatus` | `/data-block/revenu?inputKey=q_self_employed_income`, `/data-block/patrimoine?inputKey=q_cash_total`, `/budget/setup`, `/coach/chat` |
| `/assurances/lamal` | enableExplorerSante | LAMal franchise comparison. Reads known ledger facts only; result stays partial until monthly LAMal premium, current LAMal franchise, and recurring monthly medical costs are user-provided. Adult/child selector is a scenario lever, not a profile fact. Broad open-banking insurance totals must not unlock the comparison because they can include non-LAMal policies. | `q_lamal_premium_monthly_chf`, `q_lamal_franchise`, `_coach_depenses_frais_medicaux`, `depenses.assuranceMaladie`, `depenses.fraisMedicaux` | `/budget/setup?focus=lamal`, `/coach/chat` |
| `/assurances/coverage` | enableExplorerSante | Coverage check reads profile facts from the ledger only. Result stays partial until canton, employment status, household children, housing status, and mortgage context are user-provided; current insurance switches and frequent-travel are scenario/current-coverage levers, not profile facts. | `q_canton`, `q_employment_status`, `q_children`, `q_housing_status`, `_coach_dettes_hypotheque` | `/data-block/revenu?inputKey=q_canton`, `/data-block/composition_menage`, `/data-block/patrimoine?inputKey=_coach_dettes_hypotheque`, `/coach/chat?topic=employmentStatus` |
| `/arbitrage/bilan`, `/arbitrage/allocation-annuelle`, `/arbitrage/location-vs-propriete` | enableExplorerPatrimoine | Balance-sheet / allocation / rent-vs-buy. | `MintUserState` full | `/rapport`, `/confidence`, `/coach/chat` |
| `/simulator/job-comparison` | null | Job-change LPP/IJM comparison. Current job salary and age are ledger facts, never local illustrative sliders; the comparison stays partial until explicit salary and birth-year/age facts exist. New-job values are scenario/offer assumptions and remain editable. Neutral zero-delta plans must render as comparable, not as a false recommendation. | `q_gross_salary_annual`, `q_birth_year`; optional current/new LPP certificate facts and IJM coverage assumptions | `/data-block/revenu?inputKey=q_gross_salary_annual`, `/data-block/revenu?inputKey=q_birth_year`, back |
| `/simulator/compound`, `/simulator/leasing`, `/simulator/credit` | null (general-population) | Standalone illustrative simulators. | minimal/none (illustrative) | `/coach/chat`, back |
| `/check/debt`, `/debt/ratio`, `/debt/repayment` | null | Debt-risk check, debt ratio, repayment plan. | `salaireBrutMensuel`, `totalDebt`, `hasDebt`, `budgetGap` | `/debt/help`, `/coach/chat` |
| `/debt/help` | null | Debt help resources (static, general-population). | ∅ | `/coach/chat`, back |
| `/education/hub`, `/education/theme/:id` | null | General-population educational modules. | `financialLiteracyLevel` only; `id` from `state.pathParameters['id']` (§0) | `/coach/chat`, `/explore` |
| `/open-banking`, `/open-banking/transactions`, `/open-banking/consents` | enableOpenBanking (in-route redirect) | Aggregation onboarding + transactions + consent (riskiest flow; consent-gated). | `∅` pre-consent; writes accounts post-consent via `mergeAnswers()` | `/mon-argent`, `/confidence`, `/data-block/patrimoine` |
| `/bank-import` | null | Manual CSV/PDF statement review fallback; not a live Open Banking source. | `∅` pre-confirmation; after explicit review writes only `q_net_income_period_chf` + `q_pay_frequency` via `mergeAnswers()` with `userInput` provenance. Categorized charges remain preview-only and never write housing, LAMal, tax, debt, or `q_other_fixed_costs_monthly_chf`. | `/mon-argent`, `/open-banking`, `/coach/chat` |

#### G1-FRONT-01 stable control/state map

These are checked-in Flutter `Key` values for widget/Patrol selection. They do
not by themselves claim Maestro or device proof; exact-SHA runtime evidence is
still required.

| screen/state | stable id | action and contract |
|---|---|---|
| collector | `frontier_residence_country_field` | writes `q_residence_country` as `userInput` |
| collector | `frontier_work_country_field` | writes `q_work_country`; a non-CH selection clears `q_work_canton` in the same write |
| collector, only when work country is CH | `frontier_work_canton_field` | writes one of the 26 canonical Swiss canton codes |
| missing | `frontier_jurisdiction_missing_state`, `frontier_jurisdiction_capture_cta` | keep all orientation results hidden; CTA routes to `/coach/chat` |
| stale | `frontier_jurisdiction_stale_state`, `frontier_jurisdiction_reconfirm_cta` | show prior canton and restamp the same fact through the provider in one gesture |
| known domestic | `frontier_jurisdiction_domestic_state`, `frontier_domestic_fiscal_cta` | state remains non-frontier; fiscal navigation occurs only on the explicit CTA |
| known frontier | `frontier_jurisdiction_known_state`, `frontier_tax_orientation_card` | show one legal candidate plus uncertainty, never a computed conclusion |
| complete unsupported pair | `frontier_jurisdiction_specialist_only_state`, `frontier_tax_orientation_card` | show facts and specialist-only explanation; no candidate or amount |
| all complete branches | `frontier_jurisdiction_facts_card`, `frontier_social_insurance_card`, `frontier_specialist_questions_card`, `frontier_disclaimer` | preserve fact summary, fiscal/social separation, handoff questions and no-advice disclaimer |

### 4.1 G1 mechanical addendum — route truth after scenario isolation

- `/rachat-lpp` and `/3a-retroactif` hydrate their source facts from
  `CoachProfileProvider` and consume no financial route prefill. Buy-back and
  retroactive-3a widget proofs assert zero provider updates and unchanged LPP
  facts (`rachat_echelonne_screen_test.dart:63-113`,
  `retroactive_3a_screen_test.dart:63-91`).
- `/pilier-3a` hydrates its simulator inputs and protective boundary from
  `CoachProfileProvider`. Its sole production protection read is
  `profile?.isInDebtCrisis` (`simulator_3a_screen.dart:114-153,182-203`), never
  the any-debt alias. Unknown is fail-closed: while the provider loads, render
  progress; once loaded without a profile, render `MintEmptyState` with the
  diagnostic CTA to `/coach/chat`, never an implicitly debt-free simulator.
  Because the canonical predicate also covers an emergency-fund shortfall, the
  lock title and strategy text remain generic to financial stabilization and
  do not assert debt.
- `/fiscal` hydrates current facts from `CoachProfileProvider`. Because it has
  no explicit withdrawal control, `montant_retrait` and `impot_retrait` remain
  missing rather than becoming false zero
  (`fiscal_comparator_screen.dart:107-186`).
- `COACH-PREFILL-RISK` is closed by `e1d42191a`. `WidgetRenderer` ignores
  legacy tool-supplied route/partial/prefill values and derives canonical route
  plus readiness from `RoutePlanner` and the ledger profile
  (`widget_renderer.dart:96-132`). The ready fixture treats canton as known
  only with its user-provided marker and timestamp, then proves
  `/rachat-lpp`, no warning, and null destination extra
  (`widget_renderer_test.dart:25-44,99-132`).

### 4.2 `/expatriation` — AVS verification orientation (LIVE G1 contract)

| | |
|---|---|
| shell | root |
| purpose | Give a truthful, educational AVS orientation before directing the user to official verification. A period lived abroad is context to verify, not proof of an AVS contribution gap. |
| reads | `CoachProfile.avsGapEvidence.selfCertifiedYears` only when a reviewed CI makes self missing contribution years observable as periods to examine. Certificate provenance authenticates the document, not final uncompensated gaps or an official pension scale. Missing self evidence leaves the raw duration benchmark unknown; spouse evidence is outside this self-only result and is never synthesized. |
| writes | ∅. `_yearsAbroad`, `_avsScenarioStarted`, and `AvsGapAssessment` are route-local scenario state; selection, opt-in, and result rendering never write `q_avs_years_abroad`, `prevoyance.lacunesAVS`, partner facts, or any CHF amount. |
| entryConditions | none |
| emptyState | `_yearsAbroad == null`: show the explicit-selection placeholder, disable `expat_avs_start_scenario`, and render no assessment. No synthetic default year count. |
| partialState | After a local year selection but before explicit opt-in, keep the assessment hidden. After opt-in with no CI-observed self missing contribution years, render `expat_avs_gap_unknown`; years abroad remain visibly distinct from contribution periods to examine. |
| contentState | With CI-observed self missing contribution years, render only the raw contribution-duration benchmark (`observed missing contribution years / canonical full contribution duration`) and its evidence boundary. It is not a reduction of the user's pension and not an official scale decision. The compensation office first determines which periods may be compensated, then fixes the official scale and amount. Never render a personal AVS pension, CHF loss, eligibility decision, or household total. |
| errorState | Input is constrained to 0–44 years. A missing or invalid assessment remains hidden rather than falling back to a fabricated value. Official-link failures are handled by `/scan/avs-guide`. |
| routesOut | `expat.edge.avs.open_verification_guide` → `/scan/avs-guide`; back |
| partnerInvariant | Partner linking is optional, purpose-specific, field-scoped, and revocable. Missing or revoked spouse AVS evidence is unknown, never zero; this self-only orientation performs no couple-rente calculation. |
| runtimeProof | `apps/mobile/.maestro/expat_avs_verification.yaml` plus `apps/mobile/integration_test/expat_avs_verification_patrol_test.dart` for real nullable-picker input and no-write persistence. |
| killFlag | `enableExplorerTravail` |

> **`/budget`, `/budget/setup`** (budget CONTENT, gated `enableBudget`):
> - `/budget` — reads `BudgetProvider` (eager derived proxy, §10.4); confirmed budget lines write through `mergeAnswers()`, then profile publication refreshes BudgetProvider and MintStateProvider. emptyState "Configurons ton budget." CTA `/budget/setup`. partialState: some lines set → DIFF for the rest. errorState + Réessayer. killFlag `enableBudget`.
> - `/budget/setup` — pre-fills only explicit persisted answers through the existing `ReportPersistenceService.loadAnswers()` compatibility seam, never derived `CoachProfile` defaults. This direct read remains P2 I-1 migration debt; writes already flow through `CoachProfileProvider.mergeAnswers()` using `q_housing_pay_frequency` for housing cadence and canonical `q_other_fixed_costs_monthly_chf` for other fixed costs. It never writes legacy `_coach_depenses_autres`. emptyState = the setup form itself (3 fields). errorState (save failed) → keep values + Réessayer. killFlag `enableBudget`.

> **`/couple` sub-flow** (own contract, not a simulator):
> - `/couple` — reads `HouseholdProvider` + `conjoint` (bridged to recompute, §10 test 3); writes spouse fields → `mergeAnswers()`. emptyState "Aucun partenaire lié." CTA "Inviter" → `/couple/accept` share flow. partialState: spouse partially known → DIFF prompt. errorState + Réessayer. killFlag `enableExplorerFamille`.
> - `/couple/accept` — reads invitation `code` from query param (id only, per §0); writes acceptance. emptyState (invalid/expired code) "Cette invitation n'est plus valide." CTA → `/couple`. errorState + Réessayer. killFlag `enableExplorerFamille`.

> **`/timeline`, `/documents`, `/documents/:id`** (own contracts):
> - `/timeline` — reads `TimelineProvider` (bridged, §10 test 3). emptyState "Rien à afficher pour l'instant." CTA `/explore`. partialState: some sources loaded → show loaded, mark pending. errorState (any of 4 fetches failed/timeout) → show loaded subset + banner "certaines données indisponibles" + Réessayer. killFlag null.
> - `/documents` — reads `DocumentsProvider`. emptyState "Aucun document." CTA `/scan`. errorState + Réessayer. killFlag null.
> - `/documents/:id` — reads `DocumentsProvider.byId(state.pathParameters['id'])`. emptyState (id missing/not found) "Ce document n'existe plus." CTA `/documents`. errorState + Réessayer. killFlag null.

> **`/profile` sub-routes** (root; parent `/profile` redirects exact match → `/profile/bilan`, app.dart:1010-1052):
> - `/profile/bilan` (`FinancialSummaryScreen`) — reads `MintUserState` full. emptyState "Ton bilan est encore vide." CTA `/coach/chat?topic=premier-eclairage`. errorState + Réessayer(`recompute(profile)`). routesOut `/data-block/:type`, `/confidence`, `/rapport`. killFlag null.
> - `/profile/byok` (`ByokSettingsScreen`) — reads BYOK settings store; writes key via settings service (not the ledger). emptyState = form. errorState (save failed) + Réessayer. killFlag null.
> - `/profile/slm` (`SlmSettingsScreen`) — reads SLM settings; writes via settings service. emptyState = form. errorState + Réessayer. killFlag null.
> - `/profile/privacy-control` (`PrivacyControlScreen`) — reads consent state; writes consent toggles via privacy service. emptyState = controls. errorState + Réessayer. killFlag null.
> - `/profile/privacy` (`PrivacyCenterScreen`) — reads consent receipts. emptyState "Aucun reçu de consentement." errorState + Réessayer. killFlag null.
> - `/profile/admin-observability` (`AdminObservabilityScreen`), `/profile/admin-analytics` (`AdminAnalyticsScreen`) — admin-only (in-route redirect `enableAdminScreens ? null : '/'`). reads admin telemetry. emptyState "Aucune donnée." errorState + Réessayer. killFlag `enableAdminScreens`.

> **System / info routes** (root):
> - `/settings/langue` (`LangueSettingsScreen`, app.dart:1152) — reads current locale; writes locale via settings service (not the ledger). emptyState = language list. errorState (persist failed) + Réessayer. routesOut back. killFlag null.
> - `/about` (`AboutScreen`, app.dart:1159, public) — static legal/info page. emptyState n/a. errorState → static fallback. routesOut back, `/`. killFlag null.
> - `/admin/routes` (`RoutesRegistryScreen` in `AdminShell`, app.dart:1170; tree-shaken behind `AdminGate.isAvailable`) — reads `route_metadata.dart` registry. emptyState "Registre vide." errorState + Réessayer. routesOut per-route deep links. killFlag `enableAdminScreens`.

> **Legacy redirects** (`route_metadata.dart` category `alias`; killFlag null): `/coach/dashboard`, `/coach/cockpit`, `/coach/checkin`, `/coach/refresh`, `/coach/agir`, `/coach/decaissement`, `/coach/succession`, `/retirement`, `/retirement/projection`, `/arbitrage/rente-vs-capital`, `/arbitrage/rachat-vs-marche`, `/arbitrage/calendrier-retraits`, `/simulator/rente-capital`, `/simulator/3a`, `/simulator/disability-gap`, `/lpp-deep/*`, `/life-event/{divorce,succession}`, `/mortgage/affordability`, `/disability/gap`, `/document-scan`, `/document-scan/avs-guide`, `/report`, `/report/v2`, `/score-reveal`, `/achievements`, `/ask-mint`, `/advisor`, `/advisor/plan-30-days`, `/advisor/wizard`, `/household`, `/household/accept`, onboarding shims (`/onboarding/{quick,quick-start,premier-eclairage,intent,promise,plan,smart,minimal,enrichment}`) → canonical routes. Contract target: redirects SHOULD preserve query params (§9 general rule) and emit `MintBreadcrumbs.legacyRedirectHit`. G1 live status: query preservation is verified only for `/ask-mint`, `/tools`, `/portfolio`, `/score-reveal`; several other aliases still return bare target paths.

---

## 5. Scan flow — LIVE session-ID boundary; typed LPP remains default-off

`/scan/review` and `/scan/impact` no longer receive financial domain data in
`state.extra`. They resolve one opaque `scanSessionId` query parameter through
`ScanSessionProvider`. A missing, evicted or cold-restart id renders the live
localized recovery scaffold with AppBar/back and a stable recovery CTA; it
never renders the former bare `Document non disponible` trap.

### 5.0 `ScanSessionProvider` — LIVE volatile registry

File: `apps/mobile/lib/providers/scan_session_provider.dart`.
`ScanSessionProvider` is an in-memory `ChangeNotifier`, not a persisted workflow
engine. Its exact payload is:

```dart
class ScanSessionPayload {
  final ExtractionResult extraction;
  final LppExtractionCandidate? lppCandidate;
  final LppAcquisitionAuthorization? lppAuthorization;
  final TaxExtractionCandidate? taxCandidate;
  final int? previousConfidence;
}
```

- `retainExtraction(...)` creates an opaque process-local id and retains the
  extraction plus at most one typed candidate. The registry keeps at most five
  entries and evicts the oldest insertion when the sixth is retained.
- There is no `ScanStatus`, transition machine, timestamp, SharedPreferences
  key, restart rehydration or asynchronous recompute callback in this provider.
  A process death deliberately loses unconfirmed session data and routes to the
  recovery scaffold.
- For LPP, `DocumentScanScreen` fixes owner before acquisition, binds one
  complete `LppAcquisitionAuthorization` to the exact transmitted-byte SHA,
  then converts extraction output through the strict source-aware adapter.
  `retainExtraction` requires candidate and authorization together and retains
  them with the canonical raw-free extraction; route/query data contains only
  the id.
- After a successful reviewed write, `retainImpact(...)` replaces the entry
  with a source-text-free impact extraction, drops both typed candidates and
  the LPP authorization, and records `previousConfidence`. `/scan/impact`
  resolves only that retained payload. A review disposed before transfer
  discards its entry.

### `/scan` — Scan capture / entry
| | |
|---|---|
| shell | root |
| purpose | Capture or pick a document (LPP cert, AVS extract, tax cert). |
| reads | optional `DocumentType.name` from query `type`; local feature flags; for LPP, exact `CoachProfile.conjoint != null` to decide whether `manualPartner` may be offered; profile canton for backend extraction and age only for AVS parsing. `HouseholdProvider`, membership, invitation and account-link state are never part of this owner predicate |
| writes | no ledger fact. After a successful extraction/adaptation, `retainExtraction(...)` creates the volatile session payload used by review |
| entryConditions | route available behind `enableScan`; camera/file permission. LPP is selectable and its handlers are callable only when `typedLppEvidence && documentLppEvidenceEnabled`. The self path keeps the PROV-02 gate. The technically implemented `manualPartner` option is offered only for exact `CoachProfile.conjoint != null` and additionally requires `partnerLppAccountabilityEnabled`, represented authorization, current external facts, authenticated actor and pending binding before permission/picker, then an active receipt after local choice and before document-byte read/network. The default `/scan` builder injects no production `PartnerAccountabilityExternalGate`, so the branch remains fail-closed even if a developer flips local flags. |
| emptyState | No camera/no doc selected → guide card + "Scanner mon certificat" CTA + `/scan/avs-guide`. i18n `scan.empty.title` / `scan.empty.cta` |
| partialState | Local `_isProcessing` is true during extraction → progress UI; this is screen state, not a persisted session status |
| errorState | Permission denied/OCR failure → localized recovery. LPP plan, unknown, lower-confidence or classifier failure → neutral personal-certificate recovery with no review/session/write |
| routesOut | `/scan/review?scanSessionId=…`, `/scan/avs-guide`, `/data-block/:type` |
| privacyInvariant | LPP camera/gallery asks only `visionExtraction + transferUsAnthropic`, never `persistence365d`, and does so before camera/picker. For self, the exact transmitted-byte SHA remains volatile under PROV-02. For `manualPartner`, §5.1 additionally requires the minimized receipt after local file choice and before any document-byte network; the receipt contains no SHA/acquisition id/value. Authorization/SHA never enter ledger, provenance, Biography, route/query, logs or analytics; image/PDF uses direct candidate extraction, PDF skips persistent upload, and LPP BYOK/fused/SSE paths are unreachable |
| killFlag | enableScan; LPP content additionally requires the local composite gate above |

### 5.1 G1 BND-02A/BND-02 — default-off progressive implementation; activation NO-GO

**Status:** accepted interaction contract and technical GREEN default-off
implementation at exact SHA `1d022c508`; activation remains blocked. This
section replaces the older proxy-attestation
wording for the `manualPartner` branch only. It does not publish the explicitly
non-publishable notice contract, supply the production external descriptor,
activate BND-02/BND-02A or authorize G2/G3. System and lifecycle wiring are
frozen in `DATA_LEDGER.md`; the focused control/state map is
`PARTNER_LPP_ACCOUNTABILITY_FLOW.mmd`.

#### Preconditions and non-preconditions

- The owner question is first. `manualPartner` is offered **only** when
  `CoachProfile.conjoint != null`, exactly as in PROV-02. A linked household,
  invitation, membership, `HouseholdProvider.partner` or partner MINT account
  neither creates nor authorizes that choice. Conversely, none is required.
- Selecting `manualPartner` never creates a synthetic/minimal partner profile.
  When the local partner context is absent, the screen offers only `self`; it
  must not route the user into account linking as a hidden prerequisite.
- The acting user must have a current authenticated MINT session before making
  the declaration or creating a receipt. The notice and partner-rights link
  remain readable without a partner account and without account linking. If the
  acting session is absent, the login recovery returns to this exact owner and
  notice step; no picker, byte read, receipt or ledger write has occurred.
- A prior manual-partner owner UUID is reused from the strict-secure root or
  binding when present. Otherwise one UUIDv4 is preallocated once after the
  external gate + authenticated declaration and before permission/picker. A
  logical receipt UUIDv4 is generated at the same point, and their pending
  binding is written immediately. Both ids are reused unchanged by receipt and
  reviewed root save. They are never rendered, logged, placed in a route, or
  derived from partner identity.
- All default-off feature flags and the exact external facts from
  `partner_lpp_notice_contract_v1.md` must be current. A missing/expired
  controller/contact, notice/policy version, transfer guarantee, retention,
  rights channel or AIPD verdict blocks before permission, picker and bytes.

#### Ordered interaction — one meaningful decision at a time

This is a progressive acquisition, never a generic partner profile or consent
form:

1. **Owner.** Show the existing self/partner choice. Freeze the selected
   `manualPartner` subject; changing it means cancel/restart, never editing it on
   review.
2. **External gate.** Resolve the exact, dated, publishable notice descriptor.
   Failure renders the blocked recovery below and performs zero acquisition
   side effects.
3. **Notice + rights.** Show a concise summary, immutable notice version,
   controller/contact, actual transfer/retention facts, `Voir la notice` and
   `Exercer un droit`. The full notice is accessible/shareable without partner
   account or account link.
4. **Acting-user authorization.** After authentication, require an unchecked
   explicit declaration that the acting user is authorized for this one-shot
   LPP extraction and made that exact notice accessible. It is never direct
   partner consent, an opposable declaration, a mandate, or reusable permission.
5. **Prepare the accountability operation.** Reuse or allocate the exact owner
   UUIDv4, generate the logical `receiptId` once, then write their strict-secure
   `pending` binding. This happens after the current external gate,
   authentication and explicit declaration, but before permission or picker.
   The pending entry shadows any older active binding for that owner so no new
   root can ever validate against an old receipt.
6. **Technical permission.** For `manualPartner`, request only the generic
   `visionExtraction` permission; the exact typed notice in steps 2–4 is the
   authoritative disclosure for the Anthropic transfer. Do not show the older
   generic `transferUsAnthropic` copy on top of that versioned descriptor. Self
   retains both generic purposes. These acting-user technical permissions never
   substitute for step 4, and `persistence365d` is forbidden. Permission denial
   rolls back the new pending binding and explicitly restores the older active
   binding it shadowed, when one exists.
7. **Local file choice.** Revalidate the external gate, then open the picker
   with `withData=false`: selection returns only a local path/handle, not the
   document bytes. Cancellation creates no receipt and performs the same
   explicit safe rollback to the prior active binding. The ids remain frozen in
   `pending`; byte read/hash/compression waits until step 8 succeeds.
8. **Minimized receipt.** After a file was chosen, create/verify the isolated
   receipt using the already-pending `receiptId` and exact owner token. This
   metadata-only accountability call is the only network permitted between the
   local file choice and the document request. No document byte may leave the
   device until the receipt is active for this actor, owner, purpose and
   notice/policy version. Retry reuses the same logical ids. Cancel or terminal
   receipt failure erases the pending binding, restores its explicitly shadowed
   prior active binding, and schedules any created orphan receipt for its
   idempotent erasure path. Since `09b0a6543`, only a typed
   `PartnerAccountabilityException(retryable:true)` offers exact-id retry;
   terminal or unexpected errors go directly through one cleanup/rollback.
9. **Extraction.** Send only the prepared document plus
   `subjectKind=manualPartner` and `receiptId` to the authenticated direct Vision
   path. `/consents/grant-nominative`, linked-grant, BYOK, fused, SSE and
   persistent-upload paths remain unreachable. Before byte read/hash, local
   parser, request dispatch and review handoff, revalidate the same external
   gate and exact pending binding. First drift terminalizes the logical receipt,
   attempts exactly one DELETE+rollback and suppresses every later callback,
   fallback and review.
10. **Review.** Render the immutable partner owner badge, source date and
   canonical editable facts. Show `fundReturnRateRatio`, if present, only as
   `information de la caisse — non utilisée dans cette simulation`; never feed
   it to `conjoint.prevoyance.rendementCaisse` or a calculator.
11. **Atomic save.** On confirmation, first verify the already-written pending
    binding and exact owner; do **not** allocate ids or save a second pending
    binding. Then save the complete secure LPP root with that owner → activate
    that same binding → publish profile → recompute once. Any failure leaves the
    previous profile/results visible and the new partner slot unavailable.
12. **Visible benefit.** `/scan/impact` offers `Voir l'effet sur ma vue retraite`
    to `/retraite`. `RetirementDashboardScreen` must visibly identify the active
    partner-certificate source/freshness and show the changed ranged household
    result; merely listing the fact on scan impact does not close BND-02.

#### Control and stable-id registry

| screen/state | stable id | action and contract |
|---|---|---|
| `/scan` owner | `lpp_acquisition_owner_manual_partner` | select only the existing local `conjoint`; no account-link read/write |
| blocked external gate | `lpp_partner_external_gate_blocked` | explain that no document was opened/sent; primary back/cancel, no picker CTA |
| notice summary | `lpp_partner_notice_gate` | render exact versioned descriptor, not a placeholder or historical privacy copy |
| notice version | `lpp_partner_notice_version` | visible immutable `noticeVersion` + effective date |
| full notice | `lpp_partner_notice_open` | public/account-free notice access |
| partner rights | `lpp_partner_rights_link` | public/account-free contact and privacy-rights channel; present before acquisition and in every later status |
| authorization check | `lpp_partner_authorization_declaration` | initially unchecked; proxy declaration semantic only |
| authorization CTA | `lpp_partner_authorization_continue` | disabled until current auth + explicit check + current external gate |
| auth recovery | `lpp_partner_auth_required` | login then resume at notice; never ask the partner to create/link an account |
| receipt progress/error | `lpp_partner_receipt_pending`, `lpp_partner_receipt_retry` | pending binding already exists; no document-byte network while pending/error; exact-id retry only, cancel/terminal error safely rolls back to the shadowed active binding |
| review | existing `lpp_review_owner_badge`, `lpp_review_confirm_cta` | owner immutable; pending binding required before secure root save |
| review caisse fact | `lpp_review_caisse_rate_quarantined` | visible source fact, explicitly excluded from computation |
| scan impact | `lpp_impact_retirement_cta` | route to `/retraite`; no second write |
| dashboard active | `retirement_partner_lpp_status_active` | active backend status + exact owner + expiry + source/freshness |
| dashboard partial | `retirement_partner_lpp_status_partial` | unknown/not-used state, never CHF 0 or stale result |
| dashboard retry | `retirement_partner_lpp_retry_status` | reverify exact receipt status; no duplicate receipt |
| dashboard manual recovery | `retirement_partner_lpp_manual_recovery` | restore an existing independent `userInput` automatically, otherwise open one highest-impact Ask |
| dashboard rights | `retirement_partner_lpp_rights_link` | same account-free notice/rights channel |

No control, route or endpoint for `direct_partner_confirmation` is included.
That optional distinct receipt is explicitly deferred until it has its own real
public caller and rights flow; a disabled or decorative CTA would be a facade.

The live `ScanSessionPayload` now carries one typed, volatile
`ManualPartnerAccountabilityContext` **only when** the candidate subject is
`manualPartner`: `{receiptId, manualPartnerOwnerId, expiresAt, noticeVersion,
policyVersion, receiptStatus=active}`. It is retained atomically with candidate
+ acquisition authorization, never reconstructed from route/profile/household,
and never contains backend actor/owner HMACs. Review verifies the already
durable pending binding from this context; `retainImpact` drops it only after
that same binding is active.

Since `09b0a6543`, a route/navigation exception after the scan marks the receipt
as handed to review discards the volatile session, releases review ownership,
attempts exactly one receipt DELETE and one persistent rollback, clears the
binding and removes every owned temp file. The former post-handoff pending-
binding P2 is therefore closed in code; real-device cleanup evidence remains an
activation gate.

#### Cold start and degraded-state matrix

| binding/backend status | ledger and recompute behavior | visible recovery |
|---|---|---|
| exact owner + active + current versions | expose receipt-bound partner certificate facts, recompute once, render active source/freshness/expiry | notice + rights remain accessible |
| cold start while status is loading | do not expose receipt-bound facts; render `partial+ask`, not cached GREEN | `Vérifier maintenant`; keep independent facts/results only |
| offline/timeout/unverifiable | same `partial+ask`; no stale partner result and no automatic new receipt | retry status; explain that partner certificate figures are temporarily excluded |
| expired | invalidate only receipt-bound certificate presentation and dependent results | `Renouveler et relire le certificat` starts at current notice; no silent revival |
| revoked | same targeted invalidation, then recompute exactly once | notice/rights + optional fresh represented declaration; never relabel as direct consent |
| erased/owner mismatch/missing binding | fail closed and sever the unusable binding | restart acquisition; no hydration by name, household or legacy receipt |
| save crash with pending binding | new slot remains unselectable; previous canonical state stays intact | retry exact save or safe rollback; rollback erases pending and explicitly restores the older active binding it shadowed |

An independent manual partner declaration (`source=userInput`) is a different
provenance path. It is never removed by receipt expiry/revocation/erasure. If an
older independent fact exists, the dashboard restores it automatically after
targeted invalidation and marks it `à confirmer`. Otherwise the dashboard asks
only the first missing fact that can change its named result — annual partner
LPP pension when directly consumable, otherwise current total LPP capital —
with `Je ne sais pas` and dismiss controls. It must not open a complete LPP
form, ask a fresh known fact again, or ask for the caisse rate.

#### User-facing copy and six-ARB contract

No value below may be shipped while the legal notice remains non-publishable.
When external facts are verified, every key exists with equivalent semantics in
`app_{fr,en,de,es,it,pt}.arb`; controller/contact/version/regions/guarantee/
retention/effective date are injected only from the verified notice descriptor.

| ARB key | canonical French meaning / constraint |
|---|---|
| `lppPartnerNoticeTitle` | `Avant de lire le certificat de ton/ta partenaire` |
| `lppPartnerNoticeSummary` | explains one-shot LPP reading, actual recipient/regions/retention, raw non-retention and confirmed-figures storage; no DPF/ZDR placeholder |
| `lppPartnerNoticeVersion` | `Notice {version} — en vigueur depuis le {effectiveDate}` |
| `lppPartnerNoticeOpen` | `Voir la notice` |
| `lppPartnerRightsOpen` | `Exercer un droit ou contacter MINT` |
| `lppPartnerNoLinkedAccount` | `Ton/ta partenaire n'a pas besoin de créer ou de lier un compte MINT.` |
| `lppPartnerAuthorizationDeclaration` | `Je déclare être autorisé·e par mon/ma partenaire, uniquement pour faire lire ce certificat LPP une fois, et avoir rendu la notice {version} accessible.` |
| `lppPartnerAuthorizationContinue` | `Choisir le certificat` — never `Accepter le consentement` |
| `lppPartnerExternalGateBlocked` | says the partner path is unavailable and **no document was opened or sent**; it does not invent the missing legal fact |
| `lppPartnerAuthRequired` | says the acting user must reconnect; it never asks the partner to authenticate |
| `lppPartnerReceiptFailed` | says nothing was sent and offers exact-id retry or cancel |
| `lppPartnerStatusActive` | `Déclaration vérifiée jusqu'au {date}`; never `Partenaire consentant` |
| `lppPartnerStatusNeedsVerification` | says certificate figures are temporarily excluded while status is unverifiable |
| `lppPartnerStatusExpired`, `lppPartnerStatusRevoked` | distinguish lifecycle cause and explain targeted result refresh |
| `lppPartnerManualRecovery` | invites one independent manual value, marked `à confirmer`, without implying certificate evidence |
| `lppPartnerCaisseRateExcluded` | `Taux indiqué par la caisse — non utilisé dans cette simulation.` |
| `lppPartnerRetirementBenefitChanged` | identifies which ranged household result changed after review and keeps source/confidence visible; no promise or recommendation |

The current `lppAcquisitionPartnerAttestationBody` and
`consentPurposeTransferUsAnthropicWhy` are **not activation-ready**: the former
must no longer claim that a partner was informed merely from the acting user's
check, and the latter must not claim ZDR or a future hosting migration without
verified applicable proof. Their six-language replacements are a blocking
semantic gate, not a wording polish. All strings also pass ARB parity, French
accent lint, banned-term scan and no-advice review.

#### Exact semantic RED→GREEN proof and remaining acceptance gates

The registry's combined mobile command remains:

```bash
cd apps/mobile && flutter test \
  test/providers/partner_financial_consent_lifecycle_test.dart \
  test/providers/household_bridge_recompute_test.dart \
  test/screens/coach/manual_partner_lpp_accountability_rendering_test.dart \
  --reporter expanded
```

The semantic RED predates the implementation and fails on behavior assertions,
never missing imports/fixtures. The default-off implementation now supplies
these behaviors, but its passing command is not sufficient to promote either
registry row without accepted evidence:

1. `partner_financial_consent_lifecycle_test.dart` proves exact owner predicate,
   account-link independence, acting-user auth, public notice/rights, external
   fail-closed zero side effects, pending-before-permission/picker,
   picker-before-receipt, receipt-before-document network, exact-id retry,
   explicit prior-binding restoration on denial/cancel/terminal error, save
   ordering without a second pending write, cold status verification and
   expired/revoked/erased/offline targeted invalidation + independent-fact
   restoration.
2. `household_bridge_recompute_test.dart` proves one active owner-matched
   certificate fact changes `MintStateEngine -> ForecasterService` exactly once,
   removal restores remaining canonical `userInput` facts and recomputes once,
   missing partner data stays unknown rather than zero, `HouseholdProvider`
   membership never gates the fact, and certificate `fundReturnRateRatio`
   changes no result.
3. `manual_partner_lpp_accountability_rendering_test.dart` proves every stable
   id above, represented-authorization semantics, notice/version/rights access,
   no partner-account CTA, immutable review owner, caisse quarantine label,
   active/partial dashboard states, visible changed ranged result and one-Ask
   recovery. It also scans all six ARBs to reject direct-consent/opposable,
   blanket-permission, unverified DPF/ZDR and promissory/advice semantics.

Keep `test/screens/document_scan/lpp_pre_upload_authorization_test.dart` as the
PROV-02 regression for flags, owner-before-picker and byte/SHA volatility. Then
run `flutter gen-l10n`, `python3 tools/checks/arb_parity.py`, Doctor, the focused
Mermaid render, Maestro for visible state transitions and Patrol for the real
process-death proof. At `1d022c508`, the exact commands, PostgreSQL gate,
Patrol writer→terminate→cold-reader, 17-step Maestro flow and four wrapper-only
Claude final confirmations are accepted. The partner runtime remains
default-off; eight external production facts keep activation and G1 NO-GO.

### `/scan/avs-guide` — AVS extract guide
| | |
|---|---|
| shell | root |
| purpose | Keep two official steps distinct: A) request an individual-account statement (CI) to verify income, contribution years, and gaps; B) separately request the future-pension calculation with form 318.282. For married couples and, by MINT convention, registered partners, the future-calculation branch explains the joint-request path. |
| reads | locale for the official 318.282 language suffix; otherwise static educational copy. It consumes no financial profile value and no spouse amount. |
| writes | ∅. Opening the CI hub, opening 318.282, or continuing to scan does not write a ledger fact. A later reviewed scan is the separate certificate write path. |
| entryConditions | none |
| emptyState | n/a (static) |
| partialState | The CI and future-calculation cards remain separately actionable; the scan action is available only inside branch A. Debug scan simulation may show a processing state but is not the production acquisition contract. |
| errorState | An official external link that cannot open keeps the guide visible and shows a localized retry/error snackbar; it never fabricates a successful request or evidence. |
| routesOut | official domicile-aware CI request hub; official localized form `318.282`; `/scan` with `DocumentType.avsExtract`; back |
| evidenceInvariant | Years abroad are not gaps. A reviewed CI may expose self missing contribution years to examine, but does not decide the final uncompensated years, pension reduction, scale, or amount. The compensation office examines possible compensation and makes those official decisions; future-calculation output remains a separate official evidence kind. Missing self evidence is unknown, never zero; spouse evidence is outside this self-only guide result and is never synthesized. |
| killFlag | enableScan |

### `/scan/review` — LIVE identifier-only review boundary
| | |
|---|---|
| shell | root |
| purpose | Review + confirm OCR figures before any compute (OCR confirm gate). |
| reads | `ScanSessionProvider.byId(query['scanSessionId'])` → retained extraction plus optional typed candidate and volatile LPP authorization; current `CoachProfile` for before/after confidence and the provider's manual-partner fail-closed recheck |
| writes | LPP only: self keeps one `LppReviewConfirmation(authorization: retainedAuthorization) → CoachProfileProvider.acceptLppReview` call, then `retainImpact` after the awaited secure save. Under §5.1, `manualPartner` verifies the already-persisted pending binding from the exact typed accountability context → saves the complete secure root with that owner → activates that same binding before profile publication; it never writes a second pending binding, and missing/inactive context rejects before persistence load. `subject` is derived from authorization, never supplied independently. Tax uses its typed review writer; existing non-LPP types retain their own reviewed writer. LPP never calls `applySaveFact`, a legacy LPP writer, Biography or generic backend sync |
| entryConditions | non-empty `scanSessionId` resolving in the volatile registry. LPP additionally requires the composite flag, an exact canonical raw-free candidate matching every rendered field, and its complete paired authorization. Under §5.1, `manualPartner` also requires the exact active receipt/owner/version context. Missing/evicted authorization or accountability context uses recovery; neither is reconstructed after process death |
| emptyState (LIVE) | id missing/evicted/cold-restart → localized AppBar+back recovery scaffold; stable `scan_review_recovery_cta` routes to `/scan` |
| disabledState (LIVE, LPP) | either LPP flag false → `lpp_review_disabled_recovery`; missing/mismatched candidate or authorization → `lpp_review_missing_candidate_recovery`. Both expose back/cancel recovery and no writer CTA |
| partialState (LIVE, LPP) | preserve source overall/per-field confidence and `needsReview`; request effective date and editable canonical values. Untouched documentary facts require a valid non-future date; corrected facts become `userInput` with null source date; untouched derived balance facts do not persist unless edited |
| validationInvariant (LPP) | validate canonical key/value/unit and `LppBalanceCoherence` without reopening owner choice. Component > total or a three-part difference above CHF 1 shows localized `lpp_review_balance_error`; persistence and navigation remain untouched |
| ownerInvariant (LPP) | owner was fixed before acquisition and is rendered as a non-editable badge. A mistake requires `Recommencer`. `manualPartner` requires exact `CoachProfile.conjoint != null`, the §5.1 represented-authorization receipt and authenticated acting user; account linking remains optional and `HouseholdProvider` is irrelevant. The route supplies no owner/actor/grant token. The provider revalidates authorization + owner-matched accountability context before persistence load, then persists only `manualPartnerDeclaration` with `grantId=null` |
| errorState (LIVE, LPP) | invalid/missing/future date or incoherent edit stays on the editable review. Secure save failure re-enables confirmation and retains the review; no fallback, success screen, impact transfer or partial publication |
| routesOut | `/scan/impact?scanSessionId=…`, `/scan`, `/data-block/:type` |
| privacyInvariant (LPP) | candidate/review fields contain no OCR passage, source label, warning or diagnostic. The volatile authorization/SHA stays only in the bounded session and is dropped by `retainImpact`; it is never serialized. Under §5.1, the typed receipt/owner context also stays out of route, query, financial root, provenance and impact payload, and enters only the separate pending/active binding. Route and query contain only `scanSessionId` |
| killFlag | enableScan; LPP confirmation additionally requires `lppEvidenceIngestionEnabled` |

### `/scan/impact` — LIVE retained-impact boundary
| | |
|---|---|
| shell | root |
| purpose | Show the already-applied reviewed fields plus `previousConfidence + retained confidenceDelta`; it does not perform the ledger write |
| reads | `ScanSessionProvider.byId(query['scanSessionId'])` → source-text-free impact extraction and non-null `previousConfidence` |
| writes | no ledger, backend, Biography or coach-memory write for LPP. The volatile session is discarded when the screen is disposed or its terminal CTA completes |
| entryConditions | non-empty `scanSessionId` resolves and `previousConfidence` is present. There is no persisted `applied` status |
| emptyState (LIVE) | id missing/evicted/cold-restart or baseline absent → localized AppBar+back recovery scaffold; stable `scan_impact_recovery_cta` routes to `/home` |
| partialState | none for a missing baseline: the router uses the recovery state instead of fabricating an after-only comparison |
| LPP boundary | render canonical fact labels and ratio/CHF semantics from the retained reviewed result. `_fetchPremierEclairage` and `_persistScanEvent` return before any generic backend insight or event call for LPP |
| errorState | no distinct live computation-error branch: this screen renders an already-retained deterministic payload; absent required payload uses the recovery state above |
| routesOut | `/home`, `/confidence`, `/scan`, `/explore/<relevant domain>`; §5.1 target adds the stable `lpp_impact_retirement_cta` to `/retraite` after an active manual-partner save |
| killFlag | enableScan; no flag change can reconstruct a lost volatile session |

> Test: `test/routing/scan_flow_repair_test.dart` — pump `/scan/review` and `/scan/impact` with `extra: null` and no query param → assert an AppBar with a back button AND a localized CTA exposed by stable `Semantics(identifier:)` for Maestro; assert NO widget with literal text `Document non disponible` and NO bare `Center(child: Text(...))`.

---

## 6. `/data-block/:type` — DIFF collection (reuse, do not rebuild — finding D)

Backed by `screens/onboarding/data_block_enrichment_screen.dart` (~70% built: confidence bar, impact-ranked prompts, cross-validation, dual mode form/chat).

| | |
|---|---|
| shell | root |
| purpose | Collect/refresh exactly the missing-or-stale delta for one typed block. |
| reads | `CoachProfile` fields for `:type`; per-field provenance `dataSources{path→source}` + `dataTimestamps{path→updatedAt}` + `dataSourceDates{path→sourceDate}`; `FreshnessDecayService` |
| writes | `mergeAnswers()` / `applySaveFact()` per field, carrying per-field `dataSources`/`dataTimestamps`/`dataSourceDates` (§6.note) |
| entryConditions | none. The route passes `:type` through; `DataBlockEnrichmentScreen` canonicalizes known aliases and renders unsupported values as the unknown block (see §6.validation). |
| emptyState (REQUIRED) | Invalid/unknown `:type` → migration-safe unknown block. i18n `dataBlockUnknownTitle` / `dataBlockUnknownDesc` / `dataBlockUnknownCta`; no silent fallback to `revenu`. |
| partialState (REQUIRED) | Some fields present → **DIFF, not FORM**: render only missing fields as questions; render present-but-stale (freshness <0.60) as **re-confirm** prompts ("Toujours exact ?"), NOT re-ask; show before/after delta on save (finding E). i18n `dataBlock.partial.confirmStale` / `.delta` |
| errorState (REQUIRED) | Save failed (provider threw / backend allowlist reject) → keep entered values, "On n'a pas pu enregistrer." CTA Réessayer + CTA `/coach/chat?topic=:type`. i18n `dataBlock.error.saveFailed` / `.retry` |
| routesOut | back to referrer, `/coach/chat?topic=:type`, `/confidence`, the domain hub for `:type` |
| killFlag | null |

### 6.tax — exact fiscal-reference delta (G1-RET-REF-01 code-GREEN)

At exact pushed SHA `cdc786782`, the existing `fiscalite` block is the visible
consumer of the derived tax-decision reference; no new route, prompt service or
persistence root is introduced.

- The tax-document Ask is active only when the composite
  `typedTaxProfile && documentTaxAssessmentEnabled` gate is true. Either flag off
  hides acquisition and does not manufacture a prompt.
- `ConfidenceScorer.score` first obtains the status-only assessed completeness
  result, then performs a precise tax-year + subject + canton selection. It
  suppresses the fiscal document Ask only when the selected snapshot has the
  exact `latestTaxDecisionReference.referenceId` and its source date,
  confirmation instant, final status and attestation are coherent.
- Missing, appealable, ineligible, future, provenance-invalid, UUID-mismatched or
  same-rank-conflicted evidence produces the existing
  `EnrichmentPrompt.taxDocument`: copy code `tax.document.review`, field path
  `fiscal.assessedBaseline`, category `fiscalite`. It never fabricates a known
  value or silently chooses a UUID winner.
- The prompt is rendered as part of `/data-block/fiscalite`; the block's fiscal
  domain CTA routes to `/fiscal`. An exact coherent reference removes only this
  tax-document Ask; unrelated fiscal deltas such as a missing municipality stay
  visible.
- `latestTaxDecisionReference` is metadata derived from the one
  `_coach_tax_snapshots_v1` root after exact provenance validation. The screen
  never reads a second root, document payload or backend copy and performs no
  financial calculation from the reference.

This is bounded code reality, not ticket promotion, G1 closure or G2/G3 GO.

### 6.validation — no silent `'revenu'` coercion (live contract)

The `/data-block/:type` route must pass the matched path parameter through to
`DataBlockEnrichmentScreen` without defaulting to `revenu`. It also preserves
the optional `?inputKey=...` query parameter so DataQuest can collect exactly
one missing revenue field instead of reopening the whole revenue block. Other
block types ignore `inputKey` until their field-level collectors are live.
`:type` is required by the route pattern, and unsupported values are handled inside the screen as a
migration-safe unknown block using `dataBlockUnknown*` i18n labels.

```dart
builder: (context, state) {
  return DataBlockEnrichmentScreen(
    blockType: state.pathParameters['type']!,
    initialInputKey: state.uri.queryParameters['inputKey'],
  );
}
```

`DataBlockEnrichmentScreen._supportedBlockTypes` remains the local allowlist
for rendered data blocks (`revenu`, `lpp`, `avs`, `3a`, `patrimoine`,
`fiscalite`, `objectifRetraite`, `compositionMenage`). Unsupported legacy links
such as `/data-block/zzz` render the unknown block, not the revenue form.
Asserted by `test/screens/data_block_enrichment_screen_test.dart` and
`tools/checks/tests/test_screen_contracts_route_contract.py`.

### 6.note — per-field provenance API (mobile implemented; backend residual)

The mobile ledger already exposes
`Future<bool> applySaveFact(String factKey, dynamic factValue, {String confidence = 'medium', ProfileDataSource source = ProfileDataSource.userInput, DateTime? sourceDate})`.
`mergeAnswersWithProvenance` records `CoachProfile.dataSources[path]`,
`dataTimestamps[path]`, and `dataSourceDates[path]`, persists them under the
reserved `wizard_answers_v2.__provenance` envelope, and reconstructs them on
load. A direct user entry therefore uses `ProfileDataSource.userInput`, an
`updatedAt` generated by the write, and nullable `sourceDate`; derived facts use
the existing confidence `.60`. Do not invent a generic `SourceKind`, locator,
`observedAt`, or `confirmedAt` vocabulary on this mobile seam.

Backend `save_fact` still exposes one record-level `updated_at` and no equivalent
durable per-field provenance envelope. That backend residual must be handled as
its own bounded contract; it does not make the implemented mobile envelope
fictive and must not expand the 36-key value allowlist.

---

## 7. `/rapport` — PARTIAL, TARGET extra-dependency + spinner-forever repair (findings C-4, wiring-1)

| | |
|---|---|
| shell | root |
| purpose | Exportable educational dossier: situation, pillars/housing/debts/assets tagged confidence+source, ranged projections, barème-year footer. |
| reads | LEDGER FIRST: `CoachProfile.fromWizardAnswers(await ReportPersistenceService.loadAnswers())`; `MintUserState`; provenance maps `dataSources`/`dataTimestamps`/`dataSourceDates`. `extra['wizardAnswers']` is an **optional fast-path cache only** — never the sole source. |
| writes | ∅ |
| entryConditions | none |
| emptyState (REQUIRED) | `loadAnswers()` returned `{}` AND no extra → "Ton rapport est encore vide." CTA Commencer → `/coach/chat?topic=premier-eclairage`; secondary `/mon-argent`. i18n `rapport.empty.title` / `.cta` |
| partialState (REQUIRED) | Some sections empty → render available sections, mark missing as "à renseigner" with per-section CTA to `/data-block/:type`. The retirement block follows the fail-closed evidence contract below. i18n `rapport.partial.addSection` |
| errorState (REQUIRED) | `loadAnswers()` threw OR **timed out** OR reconstruction failed → "On n'a pas pu charger ton rapport." CTA Réessayer + CTA `/home`. i18n `rapport.error.title` / `.retry` |
| routesOut | export/share sheet, `/confidence`, `/data-block/:type`, `/scan/avs-guide`, `/scan` with `DocumentType.lppCertificate`, `/data-block/3a`, `/home`, `/coach/chat` |
| killFlag | null |

### 7.1 Retirement evidence states — fail closed for AVS, LPP, and 3a

#### LPP capital-notice deadline — G1-RET-REF-01 technical GREEN

At exact runtime SHA `e010132690bf22fe953f1bddbbecf5fee8bda723`, the
technical atom is GREEN. `RetirementDashboardScreen` adds one educational
reminder only when
`lppCapitalNoticeDeadlineEnabled` is true **and** the cold-derived Profile
candidate exactly resolves through hydrated BND-05 to the current self LPP
snapshot. The stable target id is
`retirement_lpp_capital_notice_deadline_education`.

- **Known:** show the explicit `deadlineDate` and reviewed-document context.
  The civil day of the deadline remains known.
- **Stale:** yesterday or earlier shows an expired/stale educational state; it
  never silently rolls the date into another year.
- **Missing/conflict:** flag off, absent/malformed root, ordinary certificate,
  `manualPartner`, factless snapshot, generic `kind=lpp`, unmatched BND tuple,
  failed hydration, replaced snapshot or replacement conflict renders no
  reminder and no inferred date.
- **Forbidden influence:** the reference/date cannot change AVS/LPP/3a values,
  retirement income, replacement rate, confidence, projection ranges,
  scenario selection, CTA ranking or specialist recommendation. Calendar or
  `legalYear` change alone is not freshness logic.
- **Replacement:** an explicit replacement is invisible until the new exact
  BND tuple is stored; a numeric self-snapshot replacement drops the reminder.

The live technical chain is
`CoachProfileProvider.acceptLppCapitalNotice` ->
`DocumentProvider.recordLppCapitalNotice` -> cold
`CoachProfile.lppCapitalNoticeDeadline` ->
`DocumentProvider.resolveLppCapitalNotice` ->
`_RetirementDashboardScreenState._buildLppCapitalNoticeEducation`. Patrol
proves cold display and invalidation after a new numeric self-LPP snapshot;
Maestro proves the production-default flag-off surface stays absent.

This path uses no new route and remains default-off. Runtime data is
synthetic-only, private-fixture use is false, and no production acquisition
seam exists. Activation is therefore NO-GO. This technical atom does not
promote RET-REF-01, close G1, or authorize G2/G3.

#### LPP regulation reference — G1-RET-REF-01 semantic RED

No screen is live: backend knows `lpp_plan`, but Docling collapses LPP to
`lpp_certificate`, mobile has no plan mapping/review, and BND rejects
`lppRegulation`. Target id `retirement_lpp_regulation_reference_education` is
hidden unless a local default-false/non-remote flag is on, exact plan authority
was reviewed with `sourceDate`+`legalYear`, the current strict self snapshot is
non-empty, and cold BND resolution joins the exact raw-free tuple.

- **Known:** neutral Dashboard education, then specialist-handoff metadata only.
- **Missing/conflict:** certificate/ambiguous kind, flag off, `manualPartner`,
  factless/replaced root, failed hydration, generic LPP or tuple drift → hidden.
- **Forbidden:** plan values/rates/scales/returns as person facts, calculations,
  confidence, rank, recommendation, advice, raw document data or implied route.
- **Replacement:** identical retry is idempotent; semantic replacement is
  explicit; a new numeric self snapshot invalidates the reference.

First RED is `apps/mobile/test/providers/lpp_regulation_reference_document_authority_test.dart`; backend classifier/
Docling reconciliation precedes the separate mobile authority/consumer stage.
Private certificates stay negative; plans become positive only through a second
human-reviewed manifest. Status remains `missing`, activation NO-GO, RET-REF/G1
open and G2/G3 forbidden.

`/rapport` and its PDF export consume evidence-bearing ledger facts; they do
not recreate pension entitlements from illustrative inputs. The three pillars
remain independent evidence envelopes:

- **AVS:** without an accepted official self pension amount, render
  `À vérifier` and route to `/scan/avs-guide`. Arrival chronology, declared gap
  status, contribution years, or an unreviewed extraction cannot become a
  pension amount.
- **LPP:** without certified fund-specific pension/capital facts, render
  `À vérifier` and route to `/scan` with `DocumentType.lppCertificate`. Never
  apply the statutory minimum conversion rate to a combined mandatory and
  extra-mandatory balance; a maximum buy-back capacity is not a completed
  buy-back and is excluded from the baseline.
- **3a:** an annual contribution is neither a current balance nor a committed
  future plan. Without a current balance, explicit contribution plan, and a
  sourced net-return/fee range, render `À vérifier` and route to
  `/data-block/3a`. The report must not expose a point capital projection or a
  provider ranking.

If any pillar required by a retirement total is unknown, all dependent totals
and the replacement rate stay unknown. A current-income denominator must also
be explicitly known; it is never replaced with a population median. Known
independent components may remain visible, but they cannot manufacture a
complete aggregate.

Partner data uses a separate evidence envelope. Account linking is optional,
purpose-specific, field-scoped, and revocable; manual partner entry remains an
equal path. Missing or revoked partner evidence is unknown, never CHF 0, and
cannot unlock a household AVS amount, total, or replacement rate. See the
focused interaction/evidence map:
`.planning/journeys/diagrams/financial_report_evidence_states.mmd`.

> **Spinner-forever fix (mechanical, finding wiring-1):** the `FutureBuilder` MUST guard ALL of:
> ```dart
> future: ReportPersistenceService.loadAnswers()
>     .timeout(const Duration(seconds: 8)),   // TimeoutException → errorState
> ...
> if (snapshot.connectionState == ConnectionState.waiting) return LoadingState(); // bounded by the timeout above
> if (snapshot.hasError) return RapportErrorState();          // incl. TimeoutException
> final answers = snapshot.data ?? const {};
> if (answers.isEmpty && extraAnswers == null) return RapportEmptyState();
> ```
> `.timeout(...)` converts a never-completing future into `snapshot.hasError` → errorState, eliminating the infinite `CircularProgressIndicator`. The screen MUST render identically with `extra: null`. Asserted by `test/routing/rapport_timeout_test.dart` (inject a `loadAnswers` that never completes → after the timeout, errorState with `rapport.error.retry` is shown, not a spinner).

---

## 8. `/confidence` — TARGET (single-source + spinner)

### 8.0 Single confidence source — reconcile the two engines (finding arch-1)

Today `MintUserState.confidenceScore` is a `double` from `ConfidenceScorer` (mint_user_state.dart:92) while the dashboard wants the 4-axis output of `EnhancedConfidenceService`. Two engines = divergent numbers = F-3 violation.

**Fix (idiomatic, in the ledger — NOT recomputed in the route):**
1. Upgrade the ledger's confidence source of truth: have `MintStateProvider.recompute(CoachProfile profile)` build the 4-axis `ConfidenceResult` once and set `MintUserState.confidenceScore = result.overall`. The per-axis breakdown and ranked prompts the dashboard renders are **derived at render time from the documented ledger fields** — `confidenceScore` (headline) plus the provenance maps `dataSources` / `dataTimestamps` / `dataSourceDates` (which feed the completeness/accuracy/freshness axes via the §8.1 adapter). No new ledger field is introduced; every name a screen reads already resolves in `DATA_LEDGER.md`.
2. In `recompute`, build it via:
   `final result = EnhancedConfidenceService.computeConfidence(profileMap, fieldSources, literacyLevel: …, checkInCount: …, educationModulesCompleted: …)` using the §8.1 adapter, and store only `result.overall` into `confidenceScore`.
3. `/confidence` and `/home` BOTH read confidence from the ledger (`confidenceScore` for the headline number; the 4 axes/prompts are re-derived from `dataSources`/`dataTimestamps`/`dataSourceDates` via the same §8.1 adapter — never a divergent second compute). The route does **NOT** run an independent `computeConfidence` against an empty map. This removes the empty-map bug AND guarantees home Pulse and dashboard show the same headline number.

### 8.1 Adapter (finding codex-5) — CoachProfile → (profileMap, List<FieldSource>)

Add `EnhancedConfidenceInput.fromProfile(CoachProfile p)` in `enhanced_confidence_service.dart`:
- `profileMap` = `p.toWizardAnswers()` (existing serialization; the same `Map<String,dynamic>` shape `scoreCompleteness` expects).
- `fieldSources` = for each field path in `p.dataSources`: `FieldSource(fieldName: path, source: p.dataSources[path], updatedAt: p.dataTimestamps[path] ?? p.createdAt, value: profileMap[path])`. For fields with no `dataSources` entry yet: `source: DataSource.estimated`, `updatedAt: p.createdAt`.
- Cache invalidation: `MintStateProvider` recomputes confidence on EVERY `recompute(profile)` (i.e. on every profile change, which is exactly when the provenance/values change). No separate hash needed — the ledger recompute IS the invalidation.

| | |
|---|---|
| shell | root |
| purpose | 4-axis confidence dashboard + ranked enrichment actions. |
| reads | `MintUserState.confidenceScore` (headline) + provenance maps `dataSources` / `dataTimestamps` / `dataSourceDates` (feed the 4 axes + ranked prompts via the §8.1 adapter). NO in-route independent compute. |
| writes | ∅ |
| entryConditions | none |
| emptyState (REQUIRED) | Adapter reports completeness 0 (empty `dataSources` / no answered fields) → honest 0% + "On n'a encore rien" + top enrichment action CTA → `/data-block/<top-impact>` (from the adapter's ranked prompts, first). i18n `confidence.empty.title` / `.cta` |
| partialState (REQUIRED) | Normal state: bars (derived from provenance maps) + top ranked enrichment actions, each CTA → its `/data-block/:type` or `/scan`. i18n `confidence.partial.nextAction` |
| errorState (REQUIRED) | `MintUserState` itself is in error (recompute threw) → message + Réessayer(`recompute(profile)`) + `/home`. i18n `confidence.error.title` |
| routesOut | `/data-block/:type`, `/scan`, `/open-banking`, `/coach/chat`, `/home` |
| killFlag | null |

> The previous empty-map fallback (`computeConfidence({}, [])`) is DELETED. The dashboard never runs a divergent second compute; it reads `confidenceScore` and re-derives the axes/prompts from the ledger's provenance maps via the §8.1 adapter. This is the F-3-compliant fix.

---

## 9. Repaired legacy traps

| route | shell | was | repaired contract |
|---|---|---|---|
| `/ask-mint` | redirect (target = coach branch, shell:2) | legacy alias only. | Live query-preserving redirect to `/coach/chat` via `_redirectPreservingQuery(state, '/coach/chat')`. killFlag null. |
| `/tools` | redirect (target = coach branch, shell:2) | legacy alias only; no report action may target bare `/tools`. | Redirect `/tools` → `/coach/chat`, forwarding query params. `financial_report_screen_v2.dart` maps `investment` and `other` to `/coach/chat?topic=investment` and `/coach/chat?topic=other`, never bare `/tools`. Navigation uses `context.go(route)` for coach-branch routes (resolves into shell branch 2 with query params per §1.1). Coach opens seeded by topic; investment stays general-population/illustrative (securities-3a excluded from personalised engine). i18n opener `coach.empty.opener.investment` / `.other`. killFlag null. |
| `/portfolio` | redirect | legacy alias only. | Live query-preserving redirect to `/home` via `_redirectPreservingQuery(state, '/home')`. killFlag null. |
| `/score-reveal` | redirect | legacy alias only. | Live query-preserving redirect to `/home` via `_redirectPreservingQuery(state, '/home')`. killFlag null. |

**General rule:** redirect aliases must preserve `state.uri.query`. The live
`/ask-mint`, `/tools`, `/portfolio`, and `/score-reveal` legacy aliases are guarded by the
static route test `apps/mobile/test/routes/legacy_redirect_query_preservation_test.dart`
and the doc/code guard `tools/checks/tests/test_screen_contracts_route_contract.py`.

---

## 10. Cross-cutting invariants (machine-checkable) — exact predicates

Each maps to finding §F. A single registry-driven harness (`test/routing/_route_harness.dart`) enumerates `route_metadata.dart` entries and provides per-route degraded fixtures (§10.0).

### 10.0 Degraded-input fixture registry (removes ambiguity, finding wiring-5)

`test/routing/route_degraded_fixtures.dart` exports `Map<String, DegradedFixture>` keyed by route. `DegradedFixture{ extra: null, queryParameters: {}, pathParameters: <minimal invalid>, profile: CoachProfile.empty() }`. "Degraded input" for a route is EXACTLY: `extra: null`, empty query, and — for `:param` routes — a path param that is present-but-invalid (`/data-block/zzz`, `/documents/nonexistent`, `/scan/review` with no `scanSessionId`), plus an empty ledger (`CoachProfile.empty()`, `MintUserState` from recompute of empty). Every route in `route_metadata.dart` with `category != alias` MUST have an entry; parity checked by `test/routing/fixture_parity_test.dart`.

### 10.1 F-1 Single source — `no_domain_data_in_extra_test.dart`

**ONE strategy: recursive production source scan** (not a widget pump). The
executable contract is intentionally narrower than “strings/enums are fine”:

- writer allowlist: the two named `DocumentType` scan expressions,
  `scanSessionId`, or the exact sequence map with both `runId` and `stepId`;
- raw-reader allowlist: an exact `DocumentType` guard or a typed two-key
  `runId`/`stepId` map consumer;
- every other `extra:` expression, key, raw read, or cast fails;
- the production inventory must contain more than 100 Dart files, so a
  hand-picked/vacuous scan cannot pass;
- coach navigation must use `context.push(route)` without extra and the
  renderer/planner/card source set must contain no prefill facade.

Definitions and writer parser are evidenced at
`apps/mobile/test/routing/no_domain_data_in_extra_test.dart:5-20,32-37,143-225`;
reader validation and recursive aggregation at `:256-355`; seeded-to-production
tests at `:357-467`; coach-specific assertions at `:448-467`.

### 10.2 F-2 No blank dead-ends — `every_route_has_recovery_test.dart`
Widget-pump each route with its `DegradedFixture` (§10.0). For each: assert (a) a back affordance exists (`find.byType(BackButton)` OR an `AppBar` with `automaticallyImplyLeading != false`); (b) at least one tappable whose label resolves to a non-null `AppLocalizations` key AND whose `onPressed`/`onTap` triggers a `context.go`/`context.push` to a route present in `route_metadata.dart` (the "recovery CTA" is defined as: a `MintButton`/`TextButton`/`ListTile` tagged with `Key('recoveryCta')` — the agent MUST tag the primary recovery CTA in every empty/error state with `key: const Key('recoveryCta')`); (c) NO widget matches a bare `Center(child: Text(<literal, non-l10n>))`. (c) is the blank-dead-end matcher.

### 10.3 F-3 Single write path — `single_write_path_test.dart`
Static source scan: FAIL if `SharedPreferences` `.setString(`/`.setInt(`/`.setDouble(`/`.setBool(` referencing a profile/budget/household key appears in any file EXCEPT `report_persistence_service.dart` and `coach_profile_provider.dart`. Ordinary profile writes go through `mergeAnswers/applySaveFact/updateProfile`; typed LPP review uses the dedicated `acceptLppReview` atomic seam. Assert `ScanSessionProvider` has no persistence API or profile-key writer, retains at most five process-local payloads, requires LPP candidate+authorization together, and strips candidates/authorization/source text before impact.

### 10.4 F-4 Bridged providers — `provider_bridge_recompute_test.dart`
For the BND-03 Budget slice, pump the production provider tree and mutate the
canonical housing, LAMal and monthly debt keys through
`CoachProfileProvider.mergeAnswers`. Assert the eager Budget proxy rehydrates
inputs and plan exactly once, the eager MintState proxy refreshes
`budgetSnapshot.present.monthlyCharges/monthlyFree` by the same base-fact
delta, and a stale `budget_inputs_v1` cache cannot override the ledger on cold
start. Exactly one persisted `future` XOR `variables` override may change only
`BudgetPlan`. Assert last-edited-wins in memory and storage, opposite-key
remove-first, and serialized rapid mutations. A cold legacy pair must preserve
historical `future` precedence once and purge `variables`.
Add a distinct declared-tax fixture with
`q_tax_provision_monthly_chf=300` and
`q_other_fixed_costs_monthly_chf=100`: the typed profile must retain both
facts and provenance independently, and BudgetInputs must expose
`taxProvision=300`, `otherFixedCosts=100`, `isTaxEstimated=false`, with neither
loss nor double count.
Exercise both normalization orders: canonical write after a persisted legacy
snapshot, then a legacy-form compatibility delta after a canonical snapshot.
The final snapshot must contain only `q_other_fixed_costs_monthly_chf`;
`_coach_depenses_autres` is absent, and the single
`depenses.autresDepensesFixes` provenance entry belongs to the last real
writer. Cold legacy migration preserves that entry without restamping it.
Assert separately that `budgetGap` stays null without official AVS facts.
`HouseholdProvider`, `TimelineProvider`, `DocumentsProvider` and conversation
bridges remain separate F-4 debt and are not promoted by the Budget test.
`ScanSessionProvider` remains excluded because it owns only volatile route
payloads; the reviewed provider write precedes `retainImpact`.

### 10.5 F-5 Ranged + confidence — `projection_compliance_test.dart`
For every screen rendering a numeric projection: assert presence of (a) a range widget (`find.byType(RangeBandWidget)`), (b) an `EnhancedConfidence` band, (c) text containing "à confirmer" OR "barème {year}", (d) the deterministic compliance filter passes (no banned terms: garanti/optimal/meilleur/certain/assuré/sans risque/parfait; no imperative/promissory forms). Runs against rendered strings.

### 10.6 F-6 / partialState DIFF — `data_block_diff_test.dart` + `partial_state_test.dart`
- `data_block_diff_test.dart`: `/data-block/:type` with a fully-known FRESH field renders a **re-confirm** prompt (widget keyed `Key('reconfirm_<field>')`), NOT an empty input.
- `partial_state_test.dart` (NEW, makes partialState testable — finding wiring-4): for every route with `reads[].length >= 1`, pump with a ledger where reads are **partially** satisfied (first field set, rest empty via a partial fixture). Assert the rendered tree contains AT LEAST ONE of: a DIFF prompt (`Key('diffPrompt')`), an "estimation" tag, or an "à confirmer" tag. FAIL if the screen renders a complete-looking result with no such marker (this is the degenerate near-blank/stale-but-present case). The agent MUST tag partial affordances accordingly.

---

## 11. Empty/Error/Partial state — required widget contract (`RouteStateScaffold`)

File: `apps/mobile/lib/widgets/route_state_scaffold.dart` (NEW, reusable). Real signature:

```dart
class RouteStateScaffold extends StatelessWidget {
  final String titleKey;        // AppLocalizations key -> AppBar title (back button ALWAYS shown)
  final IconData icon;          // calm illustrative icon (MintIcons.*)
  final String messageKey;      // AppLocalizations key, FR accents 100%
  final String primaryCtaKey;   // AppLocalizations key
  final String primaryRoute;    // a REAL route present in route_metadata.dart (validated in debug assert)
  final Map<String,String>? primaryQuery; // optional query params (ids/enums only)
  final String? secondaryCtaKey;
  final String? secondaryRoute;

  const RouteStateScaffold({
    required this.titleKey, required this.icon, required this.messageKey,
    required this.primaryCtaKey, required this.primaryRoute,
    this.primaryQuery, this.secondaryCtaKey, this.secondaryRoute, super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    assert(routeMetadata.containsKey(primaryRoute), 'recovery CTA must be a real route');
    return Scaffold(
      appBar: MintAppBar(title: Text(l10n.byKey(titleKey))), // back button always present
      body: Center(child: Column(children: [
        Icon(icon),
        Text(l10n.byKey(messageKey)),
        MintButton(
          key: const Key('recoveryCta'),                 // required for §10.2
          label: l10n.byKey(primaryCtaKey),
          onPressed: () => context.go(_withQuery(primaryRoute, primaryQuery)),
        ),
        if (secondaryCtaKey != null && secondaryRoute != null)
          MintTextButton(
            label: l10n.byKey(secondaryCtaKey!),
            onPressed: () => context.go(secondaryRoute!),
          ),
      ])),
    );
  }
}
```

Rules:
- Back handling: `MintAppBar` renders the platform back button; from a shell branch root it pops within the branch, from a root route it pops to the previous route. Never `automaticallyImplyLeading: false` on a state scaffold.
- No route may render `Scaffold(body: Center(child: Text(<literal>)))`. Every empty/error/partial state is a `RouteStateScaffold` (or, for partial, a screen that includes a tagged DIFF affordance per §10.6). The agent introduces `RouteStateScaffold` ONCE and reuses it everywhere in this document.
- `l10n.byKey(String)` is a thin generated lookup helper the agent adds so keys can be passed dynamically; all keys still exist in the 6 ARB files (no runtime-only strings).

---

## 12. Route coverage ledger (every LIVE builder route in app.dart → its contract)

Path coverage was audited against `app.dart` at `095eeaa32`; most line numbers
below therefore remain historical evidence snapshots, as stated at the top of
this document. The executable spec-reality gate additionally keeps the two scan
anchors (`/scan/review` and `/scan/impact`) reconciled to the current router.
Redirect-only entries (category `alias`) are listed in §4 "Legacy redirects"
and are NOT in this table (they carry no screen). Every path below has a
`builder:` in `app.dart`.

| route (line) | contract § | route (line) | contract § |
|---|---|---|---|
| `/` (302) | §1.5 | `/succession` (637) | §4 |
| `/auth/login` (307) | §1.5 | `/libre-passage` (651) | §4 |
| `/auth/register` (312) | §1.5 | `/pilier-3a` (662) | §4 |
| `/auth/forgot-password` (317) | §1.5 | `/3a-deep/comparator` (672) | §4 |
| `/auth/verify-email` (322) | §1.5 | `/3a-deep/real-return` (677) | §4 |
| `/auth/verify` (327) | §1.5 | `/3a-deep/staggered-withdrawal` (682) | §4 |
| `/anonymous/chat` (336) | §1.5 | `/3a-retroactif` (687) | §4 |
| `/home` (355) | §2 | `/fiscal` (692) | §4 |
| `/mon-argent` (394) | §2 | `/hypotheque` (699) | §4 |
| `/coach/chat` (404) | §2 | `/mortgage/amortization` (709) | §4 |
| `/explore` (431) | §2 | `/mortgage/epl-combined` (714) | §4 |
| `/explore/retraite` (441) | §3 | `/mortgage/imputed-rental` (719) | §4 |
| `/explore/famille` (456) | §3 | `/mortgage/saron-vs-fixed` (724) | §4 |
| `/explore/travail` (470) | §3 | `/budget` (731) | §4 |
| `/explore/logement` (485) | §3 | `/budget/setup` (736) | §4 |
| `/explore/fiscalite` (501) | §3 | `/check/debt` (741) | §4 |
| `/explore/patrimoine` (516) | §3 | `/debt/ratio` (746) | §4 |
| `/explore/sante` (530) | §3 | `/debt/help` (751) | §4 |
| `/retraite` (546) | §4 | `/debt/repayment` (756) | §4 |
| `/rente-vs-capital` (565) | §4 | `/divorce` (763) | §4 |
| `/rachat-lpp` (579) | §4 | `/mariage` (773) | §4 |
| `/epl` (593) | §4 | `/naissance` (778) | §4 |
| `/decaissement` (603) | §4 | `/concubinage` (783) | §4 |
| `/coach/history` (632) | §2 | `/unemployment` (790) | §4 |
| `/first-job` (795) | §4 | `/scan/impact` (1248) | §5 |
| `/expatriation` (800) | §4 | `/documents` (935) | §4 |
| `/simulator/job-comparison` (805) | §4 | `/documents/:id` (940) | §4 |
| `/segments/independant` (812) | §4 | `/couple` (950) | §4 |
| `/independants/avs` (817) | §4 | `/couple/accept` (960) | §4 |
| `/independants/ijm` (822) | §4 | `/rapport` (974) | §7 |
| `/independants/3a` (827) | §4 | `/profile/admin-observability` (1018) | §4 |
| `/independants/dividende-salaire` (832) | §4 | `/profile/admin-analytics` (1024) | §4 |
| `/independants/lpp-volontaire` (837) | §4 | `/profile/byok` (1031) | §4 |
| `/invalidite` (844) | §4 | `/profile/slm` (1035) | §4 |
| `/disability/insurance` (858) | §4 | `/profile/bilan` (1039) | §4 |
| `/disability/self-employed` (863) | §4 | `/profile/privacy-control` (1043) | §4 |
| `/assurances/lamal` (868) | §4 | `/profile/privacy` (1048) | §4 |
| `/assurances/coverage` (873) | §4 | `/segments/gender-gap` (1056) | §4 |
| `/scan` (880) | §5 | `/segments/frontalier` (1061) | §4 |
| `/scan/avs-guide` (894) | §5 | `/life-event/housing-sale` (1066) | §4 |
| `/scan/review` (1223) | §5 | `/life-event/donation` (1071) | §4 |
| `/life-event/deces-proche` (1076) | §4 | `/simulator/leasing` (1108) | §4 |
| `/life-event/demenagement-cantonal` (1081) | §4 | `/simulator/credit` (1113) | §4 |
| `/education/hub` (1088) | §4 | `/arbitrage/bilan` (1120) | §4 |
| `/education/theme/:id` (1093) | §4 | `/arbitrage/allocation-annuelle` (1125) | §4 |
| `/cantonal-benchmark` (1145) | §4 | `/arbitrage/location-vs-propriete` (1130) | §4 |
| `/settings/langue` (1152) | §4 | `/simulator/compound` (1103) | §4 |
| `/about` (1159) | §4 | `/timeline` (1194) | §4 |
| `/admin/routes` (1170) | §4 | `/confidence` (1199) | §8 |
| `/open-banking` (1282) | §4 | `/open-banking/transactions` (1289) | §4 |
| `/open-banking/consents` (1296) | §4 | `/bank-import` (1303) | §4 |
| `/data-block/:type` (1271) | §6 | | |

**Coverage assertion (`test/routing/contract_coverage_test.dart`):** enumerate every `ScopedGoRoute` in `app.dart` that has a `builder:` (LIVE). FAIL if any such path is absent from this §12 table. Redirect-only entries are exempt (they have no `builder:`).
