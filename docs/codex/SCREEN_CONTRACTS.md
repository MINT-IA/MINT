I now have all the ground truth I need. The `/tools`, `/portfolio`, `/score-reveal` are `RouteCategory.alias` with no killFlag (null); `/home`, `/mon-argent`, `/rapport`, `/confidence`, `/timeline` are destinations with no killFlag (null); `/scan` has `enableScan`. `computeConfidence` is `(Map<String,dynamic> profile, List<FieldSource> fieldSources, {...})`. `applySaveFact(String factKey, dynamic factValue, {String confidence})` — no per-field source, and it maps to `mergeAnswers`. `recompute(CoachProfile profile)` requires a profile arg.

Now I'll produce the full revised document.

Here is the FULL revised `SCREEN_CONTRACTS.md`:

```markdown
# SCREEN_CONTRACTS.md — Per-Route Wiring Contracts (MINT)

> Source of truth for route wiring. Verified against `apps/mobile/lib/app.dart`, `apps/mobile/lib/routes/route_metadata.dart`, `apps/mobile/lib/models/coach_profile.dart`, `apps/mobile/lib/models/mint_user_state.dart`, `apps/mobile/lib/providers/mint_state_provider.dart`, `apps/mobile/lib/providers/coach_profile_provider.dart`, `apps/mobile/lib/services/confidence/enhanced_confidence_service.dart`, `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart` at commit `255373b`.
> A coding agent (Codex) implements these contracts directly. Every row is mechanical and test-verifiable. Violations are bugs, not style notes.

---

## 0. HARD RULE — stated up front, applies to EVERY route

**Domain data NEVER travels via `GoRouter.extra`.**

`state.extra` and query params MAY carry ONLY: entity **ids** (`documentId`, `themeId`, `conversationId`, `scanSessionId`), **enums** (`ActionCategory`, life-event type, data-block `type`), invitation **codes**, and **ephemeral selection** (which tab, which scenario preset key). They MUST NOT carry `CoachProfile`, `MintUserState`, `ExtractionResult`, `wizardAnswers`, `ConfidenceResult`, budget snapshots, or any object a screen needs to *render its financial content*.

Every screen resolves the domain data it renders from the **ledger**:
- Profile / computed state → `context.watch<MintStateProvider>().state` (`MintUserState`) and `context.read<CoachProfileProvider>().profile` (`CoachProfile`).
- Scan extraction in-flight → `ScanSessionProvider` (NEW, §5.0) keyed by `scanSessionId` passed in `extra`.
- Documents → `DocumentsProvider` / `BiographyRepository` by `id`.
- Confidence → read from `MintUserState.confidenceResult` (NEW ledger field, §8.0), never passed in.

**Test that enforces this rule (must exist):** `test/routing/no_domain_data_in_extra_test.dart` — see §10.1 for the exact matcher and harness.

---

## 1. Column semantics

| Column | Meaning |
|---|---|
| **route** | Path as registered in `app.dart`. |
| **shell** | `shell:<branchIndex>` if the route lives inside the `StatefulShellRoute.indexedStack` (app.dart:345); `root` if registered on `_rootNavigatorKey`; `redirect` if it is a redirect-only entry. See §1.1. |
| **reads[]** | Ledger fields/providers the screen reads. `∅` = none. |
| **writes[]** | Ledger fields written, ALWAYS via `CoachProfileProvider.mergeAnswers()/applySaveFact()/updateProfile()`. `∅` = read-only. |
| **entryConditions** | Guard before render. `none` = always enterable. Guards are `ReadinessGate` REDIRECTS; in-screen mode switches are NOT entry conditions (see §1.2). |
| **emptyState** | REQUIRED. Shown when ledger has no data for this screen. Recovery CTA + i18n key. |
| **partialState** | REQUIRED where `reads[]` has ≥1 field. Shown when ledger has *some* but not all needed fields. Drives DIFF collection, not a form. Enforced by §10 test 4. |
| **errorState** | REQUIRED. Shown on resolution/compute failure (incl. timeout). Recovery CTA + i18n key. |
| **routesOut[]** | Reachable destinations (CTAs / navigation). |
| **killFlag** | The exact `RouteMeta.killFlag` value (`FeatureFlags.<name>`) or `null`. See §1.3 — these are the REAL values; do not write `live`. |

All `i18n key` values below are keys the agent MUST add to all 6 ARB files (`lib/l10n/app_{fr,en,de,es,it,pt}.arb`) and resolve via `AppLocalizations.of(context)!`. Accents 100% FR in the FR ARB.

### 1.1 Shell vs root registration (do not misregister)

`/home`, `/mon-argent`, `/coach/chat`, `/explore` are the four branches of the `StatefulShellRoute.indexedStack` in `app.dart:345`. The agent MUST register them as `StatefulShellBranch`es (they already are) and MUST NOT flatten them into top-level `GoRoute`s. Their contracts below are the per-branch root screen contracts; the shell wrapper (bottom nav) is unchanged.

**Navigating INTO a shell branch with query params** (e.g. the `/tools` repair targeting `/coach/chat?topic=…`): use `context.go('/coach/chat?topic=investment&actionId=<id>')`. `GoRouter` resolves the URI to the coach branch and rebuilds the branch root with `state.uri.queryParameters` available. Do NOT use `StatefulNavigationShell.goBranch(index)` for this — `goBranch` cannot carry query params. The coach branch root screen reads `topic`/`actionId` from `GoRouterState.of(context).uri.queryParameters`.

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
- `/anonymous/*` → `enableAnonymousFlow`.

Any new route the agent adds MUST set `killFlag` to one of the above `FeatureFlags.<name>` values or `null`, and MUST pass `tools/checks/route_registry_parity.py`.

---

## 2. Shell tabs

### `/home` — Pulse
| | |
|---|---|
| shell | shell:0 |
| purpose | Daily lucidity pulse: one true thing about the user's money now. |
| reads | `MintUserState{profile, lifecyclePhase, archetype, budgetGap, budgetSnapshot, currentCap, confidenceResult, friScore}` |
| writes | ∅ |
| entryConditions | none |
| emptyState | No profile → calm card "Commençons par une chose vraie." CTA → `/coach/chat?topic=premier-eclairage` (real destination — see §2.note). i18n `home.empty.title` / `home.empty.cta` |
| partialState | Minimal profile (age+salary+canton only) → budget insight + band widened honestly + `enrichmentPrompts` (ranked, top 3). MUST render at least one prompt CTA to `/data-block/:type`. i18n `home.partial.enrichHint` |
| errorState | `MintStateProvider` compute threw → "On n'a pas pu rafraîchir ton aperçu." CTA Réessayer → `context.read<MintStateProvider>().recompute(context.read<CoachProfileProvider>().profile)` + CTA `/coach/chat`. i18n `home.error.title` / `home.error.retry` |
| routesOut | `/mon-argent`, `/coach/chat`, `/explore`, `/data-block/:type`, `/confidence`, `/rapport` |
| killFlag | null |

> §2.note — **No real first-insight onboarding screen exists**; `/onboarding/premier-eclairage` is an alias shim → `/coach/chat` (route_metadata.dart:1054). Every "start here" recovery CTA in this document therefore targets `/coach/chat?topic=premier-eclairage` directly, and the coach branch seeds a first-insight opener from that `topic` (i18n `coach.empty.opener.premierEclairage`). The agent MUST NOT route recovery CTAs to the shim.
> Invariant F-1/F-4: `budgetGap` MUST reflect `BudgetProvider` overrides. See §F-repair B-1 (§10 test 3).

### `/mon-argent` — Money / Budget home
| | |
|---|---|
| shell | shell:1 |
| purpose | The user's budget reality: income, fixed, variable, gap. |
| reads | `MintUserState{budgetSnapshot, budgetGap}`, `BudgetProvider` |
| writes | budget fields → `mergeAnswers()`, then bridge fires `recompute(profile)` (§10 test 3) |
| entryConditions | none |
| emptyState | No budget data → "Trois chiffres suffisent pour un premier aperçu." CTA `/budget/setup`. i18n `money.empty.title` / `money.empty.cta` |
| partialState | Income known, expenses missing → partial gap with "estimation" tag + inline DIFF CTA to add expenses. i18n `money.partial.addExpenses` |
| errorState | Snapshot compute failed → message + Réessayer(`recompute(profile)`) + `/coach/chat`. i18n `money.error.title` |
| routesOut | `/budget/setup`, `/budget`, `/data-block/revenu`, `/data-block/patrimoine`, `/open-banking`, `/coach/chat`, `/home` |
| killFlag | null (budget CONTENT widgets gate on `enableBudget`) |

### `/coach/chat` — Coach
| | |
|---|---|
| shell | shell:2 |
| purpose | Conversational lucidity; teaches mechanisms, refuses advice. Compliance filter on every utterance. |
| reads | `CoachProfile` (full), `MintUserState`, `conversationId` from `state.uri.queryParameters['conversationId']` or `_chat_conversation_index`; `topic`/`actionId` from query params |
| writes | via `save_fact`→`applySaveFact()` (§6.note on provenance), conversation persisted by conversation store bridged to recompute |
| entryConditions | none (also the `/tools`, `/ask-mint`, `/anonymous/chat`, `/onboarding/*` redirect target) |
| emptyState | No history → seeded opener from `topic` query param if present (e.g. `?topic=lpp`, `?topic=investment`, `?topic=premier-eclairage`). i18n `coach.empty.opener` (+ per-topic variants) |
| partialState | If `topic` references a missing field → coach asks that field's DIFF question. i18n `coach.partial.askField` |
| errorState | LLM/transport failure → safe fallback bubble + Réessayer; NEVER blank. i18n `coach.error.fallback` / `coach.error.retry` |
| routesOut | `/data-block/:type`, `/confidence`, `/explore`, any simulator deep-link |
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
| `/explore/retraite` | retirement | enableExplorerRetraite | `prevoyance{avoirLppTotal, renteAVSEstimeeMensuelle, lacunesAVS}`, `targetRetirementAge`, `archetype` | `/retraite`, `/rente-vs-capital`, `/rachat-lpp`, `/pilier-3a`, `/decaissement`, `/data-block/{lpp,avs,3a}` |
| `/explore/famille` | family | enableExplorerFamille | `nombreEnfants`, `conjoint`, `gender` | `/mariage`, `/naissance`, `/concubinage`, `/divorce`, `/succession`, `/data-block/compositionMenage`, `/couple` |
| `/explore/travail` | work | enableExplorerTravail | `employmentStatus`, `salaireBrutMensuel`, `archetype` | `/first-job`, `/unemployment`, `/segments/independant`, `/simulator/job-comparison`, `/expatriation`, `/data-block/revenu` |
| `/explore/logement` | housing | enableExplorerLogement | `patrimoine`, mortgage fields | `/hypotheque`, `/mortgage/affordability`, `/mortgage/amortization`, `/epl`, `/arbitrage/location-vs-propriete`, `/data-block/patrimoine` |
| `/explore/fiscalite` | tax | enableExplorerFiscalite | `canton`, `salaireBrutMensuel`, tax-regime | `/fiscal`, `/3a-retroactif`, `/data-block/fiscalite`, `/scan` |
| `/explore/patrimoine` | wealth | enableExplorerPatrimoine | `patrimoine`, `prevoyance` | `/arbitrage/bilan`, `/arbitrage/allocation-annuelle`, `/data-block/patrimoine`, `/open-banking` |
| `/explore/sante` | health/insurance | enableExplorerSante | `archetype`, `employmentStatus` | `/assurances/lamal`, `/assurances/coverage`, `/invalidite`, `/disability/gap` |

---

## 4. Life-event + simulator routes

All simulators are **read-from-ledger, write-back-on-edit**. Verified working: simulators call `provider.updateProfile()` (finding C-6). The contract makes empty/error states explicit so they never trap.

**Shared simulator shape**
- shell: root
- reads: relevant `CoachProfile`/`MintUserState` fields (per row) — from ledger, NEVER `extra`
- writes: committed edits → `updateProfile()`; ephemeral sliders may stay local, committed values write back
- entryConditions: **none** (per §1.2 — simulators use the in-screen mode switch, not an entry redirect). Below the confidence threshold (finding D: <30 premier_eclairage; 30–50 +projections; 50–70 +arbitrage w/ bands; 70–85 +precise; >85 +full), the screen renders **illustrative mode** (general-population numbers, no personalised compute); at/above, **personalised mode**. Render-mode is chosen from `MintUserState.confidenceResult.overall`.
- emptyState (REQUIRED): missing required input → inline DIFF prompt for exactly the missing field, "estimation" defaults pre-filled + tagged. i18n `<sim>.empty.needInput`
- partialState (REQUIRED): some inputs known → prefill from ledger, ask only the delta; band widened for unknowns; every prefilled-but-stale (freshness <0.60) or estimated field carries an "à confirmer"/"estimation" tag (asserted by §10 test 4). i18n `<sim>.partial.assume`
- errorState (REQUIRED): engine failure/timeout → "Le calcul n'a pas abouti." CTA Réessayer + CTA `/coach/chat`; show last good range if any. i18n `<sim>.error.title`
- EVERY numeric output: range + `EnhancedConfidence` band + "à confirmer / barème {year}" + non-promissory phrasing (invariant F-5)

| route | killFlag | purpose (1 line) | reads (key ledger fields) | routesOut[] |
|---|---|---|---|---|
| `/retraite` | enableExplorerRetraite | Integrated retirement picture (AVS+LPP+3a+PC). | `prevoyance.*`, `targetRetirementAge`, `age`, `archetype`, `conjoint` | `/rente-vs-capital`, `/rachat-lpp`, `/pilier-3a`, `/decaissement`, `/confidence`, `/data-block/lpp` |
| `/rente-vs-capital` | enableExplorerRetraite | Rente vs capital + panachage + survivor. | `prevoyance.avoirLppTotal`, `renteAVSEstimeeMensuelle`, `conjoint`, `gender` | `/decaissement`, `/coach/chat`, `/data-block/compositionMenage` |
| `/rachat-lpp` | enableExplorerRetraite | LPP buy-back trade-offs (vs market). | `prevoyance{avoirLppTotal}`, `salaireBrutMensuel`, `canton` | `/3a-retroactif`, `/fiscal`, `/coach/chat` |
| `/pilier-3a`, `/3a-deep/*` | enableExplorerRetraite | 3a mechanism + retroactive buy-back (in force tax-year 2025). | `canton`, `salaireBrutMensuel`, `isFatcaResident`, `canContribute3a` | `/3a-retroactif`, `/3a-deep/comparator`, `/data-block/3a` |
| `/3a-retroactif` | enableExplorerFiscalite | 3a retroactive buy-back (gaps from 2025, current year first). | `canton`, `salaireBrutMensuel`, `age` | `/pilier-3a`, `/fiscal`, `/coach/chat` |
| `/decaissement` | enableExplorerRetraite | Staggered withdrawal calendar. | `prevoyance.*`, `targetRetirementAge`, `canton` | `/rente-vs-capital`, `/coach/chat` |
| `/hypotheque`, `/mortgage/affordability`, `/mortgage/amortization`, `/mortgage/renewal` | enableExplorerLogement | Affordability (~33% rule, ~5% calculatory rate, ~3–5% acquisition costs), renewal shock. | `salaireBrutMensuel`, `patrimoine`, `canton` | `/epl`, `/mortgage/amortization`, `/arbitrage/location-vs-propriete` |
| `/epl` | enableExplorerLogement | Early withdrawal for property trade-offs. | `prevoyance.avoirLppTotal`, `patrimoine` | `/hypotheque`, `/rachat-lpp` |
| `/fiscal` | enableExplorerFiscalite | Tax across 3 tiers; regime-detected. | `canton`, `salaireBrutMensuel`, `archetype`, tax-regime | `/3a-retroactif`, `/scan`, `/coach/chat` |
| `/cantonal-benchmark` | enableExplorerFiscalite | Cross-canton tax/benefit benchmark (illustrative). | `canton`, `salaireBrutMensuel` | `/fiscal`, `/coach/chat` |
| `/divorce`, `/mariage`, `/naissance`, `/concubinage` | enableExplorerFamille | Family life events. | `conjoint`, `nombreEnfants`, `patrimoine`, `prevoyance` | `/succession`, `/couple`, `/data-block/compositionMenage`, `/coach/chat` |
| `/succession`, `/life-event/donation` | enableExplorerFamille | Estate organisation / gifts. | `patrimoine`, `conjoint`, `nombreEnfants`, `canton` | `/succession`, `/coach/chat` |
| `/first-job`, `/unemployment`, `/expatriation`, `/segments/independant`, `/independants/*` | enableExplorerTravail | Career transitions / independent. | `employmentStatus`, `salaireBrutMensuel`, `archetype`, `nationality` | `/data-block/revenu`, `/data-block/lpp`, `/coach/chat` |
| `/invalidite`, `/disability/gap`, `/disability/insurance` | enableExplorerSante | Disability coverage gap. | `salaireBrutMensuel`, `prevoyance`, `employmentStatus` | `/coach/chat` |
| `/assurances/lamal`, `/assurances/coverage`, `/assurances/*` | enableExplorerSante | Health-insurance mechanisms (illustrative; no product naming). | `archetype`, `canton`, `nombreEnfants` | `/coach/chat`, `/data-block/compositionMenage` |
| `/arbitrage/bilan`, `/arbitrage/allocation-annuelle`, `/arbitrage/location-vs-propriete` | enableExplorerPatrimoine | Balance-sheet / allocation / rent-vs-buy. | `MintUserState` full | `/rapport`, `/confidence`, `/coach/chat` |
| `/simulator/job-comparison`, `/simulator/compound`, `/simulator/leasing`, `/simulator/credit`, `/check/debt`, `/debt/*` | null (general-population) | Standalone illustrative simulators / debt check. | minimal/none (illustrative) | `/coach/chat`, back |
| `/education/*` | null | General-population educational modules. | `understanding` counters only | `/coach/chat`, `/explore` |
| `/open-banking/*` | null | Aggregation onboarding + consent (riskiest flow; consent-gated). | `∅` pre-consent; writes accounts post-consent via `mergeAnswers()` | `/mon-argent`, `/confidence`, `/data-block/patrimoine` |

> **`/couple` sub-flow** (own contract, not a simulator):
> - `/couple` — reads `HouseholdProvider` + `conjoint` (bridged to recompute, §10 test 3); writes spouse fields → `mergeAnswers()`. emptyState "Aucun partenaire lié." CTA "Inviter" → `/couple/accept` share flow. partialState: spouse partially known → DIFF prompt. errorState + Réessayer. killFlag `enableExplorerFamille`.
> - `/couple/accept` — reads invitation `code` from query param (id only, per §0); writes acceptance. emptyState (invalid/expired code) "Cette invitation n'est plus valide." CTA → `/couple`. errorState + Réessayer. killFlag `enableExplorerFamille`.

> **`/timeline`, `/documents`, `/documents/:id`** (own contracts):
> - `/timeline` — reads `TimelineProvider` (bridged, §10 test 3). emptyState "Rien à afficher pour l'instant." CTA `/explore`. partialState: some sources loaded → show loaded, mark pending. errorState (any of 4 fetches failed/timeout) → show loaded subset + banner "certaines données indisponibles" + Réessayer. killFlag null.
> - `/documents` — reads `DocumentsProvider`. emptyState "Aucun document." CTA `/scan`. errorState + Réessayer. killFlag null.
> - `/documents/:id` — reads `DocumentsProvider.byId(state.pathParameters['id'])`. emptyState (id missing/not found) "Ce document n'existe plus." CTA `/documents`. errorState + Réessayer. killFlag null.

> **Legacy redirects** (`route_metadata.dart` category `alias`; killFlag null): `/coach/dashboard`, `/retirement`, `/retirement/projection`, `/arbitrage/rente-vs-capital`, `/simulator/rente-capital`, `/lpp-deep/*`, `/document-scan`, `/report`, `/report/v2`, `/score-reveal`, onboarding shims → canonical routes. Contract: redirects MUST preserve query params (§9 general rule) and emit `MintBreadcrumbs.legacyRedirectHit`.

---

## 5. Scan flow — REPAIRED (was the worst dead road, finding C-1)

**Root cause:** `/scan/review` and `/scan/impact` read the `ExtractionResult` from `state.extra`; on null they render `Scaffold(body: Center(Text('Document non disponible')))` — no AppBar, no back, no CTA, not i18n. Violates §0 (domain data in `extra`) and F-2.

### 5.0 `ScanSessionProvider` — NEW, fully specified

File: `apps/mobile/lib/providers/scan_session_provider.dart`. `ChangeNotifier`. Registered in `app.dart` provider tree ABOVE `MintStateProvider` so the bridge (below) can fire.

```dart
enum ScanStatus { captured, extracting, extracted, applying, applied, failed }

class ScanSession {
  final String id;              // uuid v4, generated at capture; the ONLY thing put in extra/query
  final String docType;         // 'lpp' | 'avs' | 'tax' | 'other'
  final ScanStatus status;
  final ExtractionResult? extraction;   // null until status >= extracted
  final double? confidenceBefore;       // MintUserState.confidenceResult.overall snapshot, taken at APPLY start
  final DateTime createdAt;
  final DateTime updatedAt;
  ScanSession copyWith({...});
}
```

**State machine (the ONLY legal transitions; enforced by `scan_session_provider.dart` + `test/providers/scan_session_state_machine_test.dart`):**

```
captured ──(OCR pipeline starts)──▶ extracting
extracting ──(OCR success)────────▶ extracted
extracting ──(OCR failure/timeout)▶ failed
extracted ──(user taps Appliquer on /scan/review)──▶ applying
applying ──(applySaveFact writes committed, recompute done)──▶ applied
applying ──(write/backend failure)────────────────────────────▶ failed
failed ──(user retries)──▶ extracting   // re-parse
```
Any other transition throws `StateError`.

**WHO/WHEN writes the ExtractionResult:** `DocumentScanScreen`'s OCR pipeline (existing OCR service) calls `scanSessionProvider.setExtraction(id, ExtractionResult)` on OCR completion, moving `extracting → extracted`. This is the single integration point; no screen constructs `ExtractionResult` from `extra`.

**Persistence:** SharedPreferences key `scan_session_v1` = JSON `{ "sessions": [ScanSession...] }`.
- **Eviction/GC:** keep at most **5** sessions; on write, drop oldest by `updatedAt`. Additionally, on provider init, purge any session with `status == applied` older than **7 days** and any `status == failed` older than **24h**. A session that reaches `applied` is retained (for `/scan/impact`) until GC.

**F-4 bridge (trigger point, explicit):** on the `applying → applied` transition, AFTER the per-field `applySaveFact()` writes complete, the provider calls `context.read<MintStateProvider>().recompute(context.read<CoachProfileProvider>().profile)`. (The provider holds a callback injected at construction: `Future<void> Function() onApplied` wired in `app.dart` to `() => mintState.recompute(coachProfile.profile)`.) Asserted by §10 test 3.

### `/scan` — Scan capture / entry
| | |
|---|---|
| shell | root |
| purpose | Capture or pick a document (LPP cert, AVS extract, tax cert). |
| reads | `ScanSessionProvider` (recent sessions), `archetype` (to suggest doc type) |
| writes | creates `ScanSession{id, docType, status: captured}` in provider |
| entryConditions | camera/file permission; if denied → permission-denied errorState (not blank) |
| emptyState | No camera/no doc selected → guide card + "Scanner mon certificat" CTA + `/scan/avs-guide`. i18n `scan.empty.title` / `scan.empty.cta` |
| partialState | OCR in progress (`extracting`) → progress UI with cancel. i18n `scan.partial.processing` |
| errorState | Permission denied OR OCR engine failure → explanation + CTA Réglages / Réessayer + CTA manual entry `/data-block/lpp`. i18n `scan.error.permission` / `scan.error.ocr` |
| routesOut | `/scan/review?scanSessionId=…`, `/scan/avs-guide`, `/data-block/:type` |
| killFlag | enableScan |

### `/scan/review` — REPAIRED
| | |
|---|---|
| shell | root |
| purpose | Review + confirm OCR figures before any compute (OCR confirm gate). |
| reads | `ScanSessionProvider.byId(state.uri.queryParameters['scanSessionId'])` → `ExtractionResult`; current `CoachProfile` (for before/after) |
| writes | on confirm: `applySaveFact()` per confirmed field with `source: DataSource.scan` (accuracy .85), `sourceDate: DateTime.now()` — see §6.note on the required signature extension |
| entryConditions | `scanSessionId` present AND session resolves in `status: extracted`. |
| emptyState (REQUIRED) | id missing OR session not found (deep link, restart, GC) → **NOT blank**. AppBar+back. "Ce document n'est plus disponible. Tu peux le scanner à nouveau." CTA Rescanner → `/scan`; secondary → `/documents`. i18n `scan.review.empty.title` / `.rescan` |
| partialState (REQUIRED) | Some fields low-OCR-confidence → flag them, require manual confirm before enabling "Appliquer". i18n `scan.review.partial.confirmLow` |
| errorState (REQUIRED) | Session resolution threw OR re-parse failed → AppBar+back + "On n'a pas pu lire ce document." CTA Réessayer + CTA `/data-block/:type`. i18n `scan.review.error.title` / `.manual` |
| routesOut | `/scan/impact?scanSessionId=…`, `/scan`, `/documents`, `/data-block/:type` |
| killFlag | enableScan |

### `/scan/impact` — REPAIRED
| | |
|---|---|
| shell | root |
| purpose | Show before/after confidence + ranged figure delta from the scan. |
| reads | `ScanSessionProvider.byId(...)` (incl. `confidenceBefore`); `MintUserState.confidenceResult.overall` (current = "after") |
| writes | ∅ (write happened at `/scan/review`) |
| entryConditions | `scanSessionId` resolves AND session `status: applied`. |
| emptyState (REQUIRED) | id missing/not found → AppBar+back + "Aucun impact à afficher." CTA Voir mon aperçu → `/home`; secondary `/scan`. i18n `scan.impact.empty.title` / `.cta` |
| partialState (REQUIRED) | `confidenceBefore` absent → show after-state only, label "comparaison indisponible". i18n `scan.impact.partial.noBaseline` |
| errorState (REQUIRED) | Confidence read failed → AppBar+back + message + Réessayer + `/coach/chat`. i18n `scan.impact.error.title` |
| routesOut | `/home`, `/confidence`, `/scan`, `/explore/<relevant domain>` |
| killFlag | enableScan |

> Test: `test/routing/scan_flow_repair_test.dart` — pump `/scan/review` and `/scan/impact` with `extra: null` and no query param → assert an AppBar with a back button AND a `MintButton` whose label resolves to a non-null `AppLocalizations` key; assert NO widget with literal text `Document non disponible` and NO bare `Center(child: Text(...))`.

---

## 6. `/data-block/:type` — DIFF collection (reuse, do not rebuild — finding D)

Backed by `screens/onboarding/data_block_enrichment_screen.dart` (~70% built: confidence bar, impact-ranked prompts, cross-validation, dual mode form/chat).

| | |
|---|---|
| shell | root |
| purpose | Collect/refresh exactly the missing-or-stale delta for one typed block. |
| reads | `CoachProfile` fields for `:type`; per-field `dataSources{source, sourceDate}`; `FreshnessDecayService` |
| writes | `mergeAnswers()` / `applySaveFact()` per field, carrying per-field `{source, sourceDate, updatedAt}` (§6.note) |
| entryConditions | none. Validation of `:type` happens IN THE ROUTE BUILDER (see §6.validation), not in the screen. |
| emptyState (REQUIRED) | Invalid/unknown `:type` → "Ce thème n'existe pas." CTA → `/explore`. i18n `dataBlock.empty.unknownType` / `.cta` |
| partialState (REQUIRED) | Some fields present → **DIFF, not FORM**: render only missing fields as questions; render present-but-stale (freshness <0.60) as **re-confirm** prompts ("Toujours exact ?"), NOT re-ask; show before/after delta on save (finding E). i18n `dataBlock.partial.confirmStale` / `.delta` |
| errorState (REQUIRED) | Save failed (provider threw / backend allowlist reject) → keep entered values, "On n'a pas pu enregistrer." CTA Réessayer + CTA `/coach/chat?topic=:type`. i18n `dataBlock.error.saveFailed` / `.retry` |
| routesOut | back to referrer, `/coach/chat?topic=:type`, `/confidence`, the domain hub for `:type` |
| killFlag | null |

### 6.validation — resolve the silent `'revenu'` coercion (finding wiring-2)

The current builder does `state.pathParameters['type'] ?? 'revenu'`. **This fallback MUST be removed.** Replace with, in the `/data-block/:type` route `builder:` in `app.dart`:

```dart
const _allowedDataBlockTypes = {
  'revenu','lpp','avs','3a','patrimoine','fiscalite','objectifRetraite','compositionMenage',
};
builder: (context, state) {
  final type = state.pathParameters['type'];
  if (type == null || !_allowedDataBlockTypes.contains(type)) {
    return DataBlockEmptyState(); // renders emptyState above (unknownType), NOT '/revenu'
  }
  return DataBlockEnrichmentScreen(type: type);
}
```
`_allowedDataBlockTypes` is the single source; `DataBlockEnrichmentScreen` no longer defaults. Asserted by `test/routing/data_block_unknown_type_test.dart` (pump `/data-block/zzz` → `DataBlockEmptyState` with `dataBlock.empty.unknownType`, NOT the revenu form).

### 6.note — per-field provenance API (the missing 30%, finding E / B-4)

Per-field `{source, sourceDate, updatedAt}` does NOT yet persist end-to-end. The current `applySaveFact(String factKey, dynamic factValue, {String confidence})` (coach_profile_provider.dart:542) maps to `mergeAnswers` and carries no source/date; backend `save_fact` has ONE `updated_at`. The agent MUST:

1. **Extend the signature (backward-compatible):**
   `Future<bool> applySaveFact(String factKey, dynamic factValue, {String confidence = 'medium', DataSource source = DataSource.userInput, DateTime? sourceDate})`.
2. **Add a ledger field:** `CoachProfile.fieldProvenance : Map<String, FieldProvenance>` where `FieldProvenance{DataSource source, DateTime sourceDate, DateTime updatedAt}`, keyed by canonical field name. `mergeAnswers` populates it; persisted in `wizard_answers_v2` under a reserved `__provenance` sub-map (never collides with wizard keys). `CoachProfile.fromWizardAnswers` reconstructs it.
3. **Backend:** add per-field provenance to `ProfileModel.data` under a reserved `_provenance` dict (does NOT expand the 40-key allowlist for values; provenance is metadata, redaction rules unchanged). Fire-and-forget sync as today.

Until (1)–(3) land, any write in this document that "carries per-field source" is implemented via the extended `applySaveFact`. Do NOT assume provenance already persists.

---

## 7. `/rapport` — REPAIRED extra-dependency + spinner-forever (findings C-4, wiring-1)

| | |
|---|---|
| shell | root |
| purpose | Exportable educational dossier: situation, pillars/housing/debts/assets tagged confidence+source, ranged projections, barème-year footer. |
| reads | LEDGER FIRST: `CoachProfile.fromWizardAnswers(await ReportPersistenceService.loadAnswers())`; `MintUserState`; `fieldProvenance`. `extra['wizardAnswers']` is an **optional fast-path cache only** — never the sole source. |
| writes | ∅ |
| entryConditions | none |
| emptyState (REQUIRED) | `loadAnswers()` returned `{}` AND no extra → "Ton rapport est encore vide." CTA Commencer → `/coach/chat?topic=premier-eclairage`; secondary `/mon-argent`. i18n `rapport.empty.title` / `.cta` |
| partialState (REQUIRED) | Some sections empty → render available sections, mark missing as "à renseigner" with per-section CTA to `/data-block/:type`. i18n `rapport.partial.addSection` |
| errorState (REQUIRED) | `loadAnswers()` threw OR **timed out** OR reconstruction failed → "On n'a pas pu charger ton rapport." CTA Réessayer + CTA `/home`. i18n `rapport.error.title` / `.retry` |
| routesOut | export/share sheet, `/confidence`, `/data-block/:type`, `/home`, `/coach/chat` |
| killFlag | null |

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

## 8. `/confidence` — REPAIRED (single-source + spinner) 

### 8.0 Single confidence source — reconcile the two engines (finding arch-1)

Today `MintUserState.confidenceScore` is a `double` from `ConfidenceScorer` (mint_user_state.dart:92) while the dashboard wants the 4-axis `ConfidenceResult` from `EnhancedConfidenceService`. Two engines = divergent numbers = F-3 violation.

**Fix (idiomatic, in the ledger — NOT recomputed in the route):**
1. Add `final ConfidenceResult confidenceResult;` to `MintUserState` (keep the legacy `double confidenceScore` as `=> confidenceResult.overall` for existing callers; deprecate).
2. In `MintStateProvider.recompute(CoachProfile profile)`, build it once:
   `confidenceResult = EnhancedConfidenceService.computeConfidence(profileMap, fieldSources, literacyLevel: …, checkInCount: …, educationModulesCompleted: …)` using the §8.1 adapter, and put it on `MintUserState`.
3. `/confidence` and `/home` BOTH read `state.confidenceResult` from the ledger. The route does **NOT** call `computeConfidence` itself. This removes the empty-map bug AND guarantees home Pulse and dashboard show the same number.

### 8.1 Adapter (finding codex-5) — CoachProfile → (profileMap, List<FieldSource>)

Add `EnhancedConfidenceInput.fromProfile(CoachProfile p)` in `enhanced_confidence_service.dart`:
- `profileMap` = `p.toWizardAnswers()` (existing serialization; the same `Map<String,dynamic>` shape `scoreCompleteness` expects).
- `fieldSources` = for each entry in `p.fieldProvenance`: `FieldSource(fieldName: key, source: prov.source, updatedAt: prov.updatedAt, value: profileMap[key])`. For fields with no provenance yet: `source: DataSource.estimated`, `updatedAt: p.createdAt`.
- Cache invalidation: `MintStateProvider` recomputes `confidenceResult` on EVERY `recompute(profile)` (i.e. on every profile change, which is exactly when the provenance/values change). No separate hash needed — the ledger recompute IS the invalidation. (Delete the old "fresh ConfidenceResult for current profile hash" cache note; it is superseded by ledger recompute.)

| | |
|---|---|
| shell | root |
| purpose | 4-axis confidence dashboard + ranked enrichment actions. |
| reads | `MintUserState.confidenceResult` (from ledger, §8.0). NO in-route compute. |
| writes | ∅ |
| entryConditions | none |
| emptyState (REQUIRED) | `confidenceResult.completeness == 0` → honest 0% + "On n'a encore rien" + top enrichment action CTA → `/data-block/<top-impact>` (from `confidenceResult.prompts.first`). i18n `confidence.empty.title` / `.cta` |
| partialState (REQUIRED) | Normal state: bars + `confidenceResult.prompts` top actions, each CTA → its `/data-block/:type` or `/scan`. i18n `confidence.partial.nextAction` |
| errorState (REQUIRED) | `MintUserState` itself is in error (recompute threw) → message + Réessayer(`recompute(profile)`) + `/home`. i18n `confidence.error.title` |
| routesOut | `/data-block/:type`, `/scan`, `/open-banking`, `/coach/chat`, `/home` |
| killFlag | null |

> The previous empty-map fallback (`computeConfidence({}, [])`) is DELETED. The dashboard never computes; it reads the ledger. This is the F-3-compliant fix.

---

## 9. Repaired legacy traps

| route | shell | was | repaired contract |
|---|---|---|---|
| `/tools` | redirect (target = coach branch, shell:2) | redirect → `/coach/chat`, no context; `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart:51-52` maps BOTH `ActionCategory.investment` AND `ActionCategory.other` → `/tools` → dead-end (finding C-2). | Redirect `/tools` → `/coach/chat`, forwarding query params. `financial_report_screen_v2.dart:51-52` MUST be changed so `investment` and `other` map to `/coach/chat?topic=investment&actionId=<id>` (and `topic=other`), never bare `/tools`. Navigation uses `context.go('/coach/chat?topic=…')` (resolves into shell branch 2 with query params per §1.1). Coach opens seeded on that action; investment stays general-population/illustrative (securities-3a excluded from personalised engine). i18n opener `coach.empty.opener.investment` / `.other`. killFlag null. |
| `/portfolio` | redirect | redirect → `/home`, **query params dropped** (finding C-3). | `redirect: (c,s) => '/home${s.uri.query.isEmpty ? '' : '?${s.uri.query}'}'`. killFlag null. |
| `/score-reveal` | redirect | redirect → `/home`. | Same query-preserving redirect. killFlag null. |

**General rule:** EVERY redirect entry preserves `state.uri.query`. Asserted by `test/routing/redirect_preserves_query_test.dart`.

---

## 10. Cross-cutting invariants (machine-checkable) — exact predicates

Each maps to finding §F. A single registry-driven harness (`test/routing/_route_harness.dart`) enumerates `route_metadata.dart` entries and provides per-route degraded fixtures (§10.0).

### 10.0 Degraded-input fixture registry (removes ambiguity, finding wiring-5)

`test/routing/route_degraded_fixtures.dart` exports `Map<String, DegradedFixture>` keyed by route. `DegradedFixture{ extra: null, queryParameters: {}, pathParameters: <minimal invalid>, profile: CoachProfile.empty() }`. "Degraded input" for a route is EXACTLY: `extra: null`, empty query, and — for `:param` routes — a path param that is present-but-invalid (`/data-block/zzz`, `/documents/nonexistent`, `/scan/review` with no `scanSessionId`), plus an empty ledger (`CoachProfile.empty()`, `MintUserState` from recompute of empty). Every route in `route_metadata.dart` with `category != alias` MUST have an entry; parity checked by `test/routing/fixture_parity_test.dart`.

### 10.1 F-1 Single source — `no_domain_data_in_extra_test.dart`
**ONE strategy: static AST/source scan of `app.dart`** (not a widget pump). Parse `app.dart`; for every `GoRoute.builder` body, FAIL if it contains any of these source patterns (regex over the builder AST text):
```
state.extra as CoachProfile
state.extra as MintUserState
state.extra as ExtractionResult
state.extra as ConfidenceResult
state.extra as Map<String, dynamic>   // wizardAnswers-shaped
(state.extra as ...).<field>          // any member access on a cast extra
```
ALLOWED (must NOT fail): `state.extra as String`, `... as ActionCategory`, `... as <enum>`, `state.pathParameters[...]`, `state.uri.queryParameters[...]`. The forbidden-pattern list above is the complete matcher.

### 10.2 F-2 No blank dead-ends — `every_route_has_recovery_test.dart`
Widget-pump each route with its `DegradedFixture` (§10.0). For each: assert (a) a back affordance exists (`find.byType(BackButton)` OR an `AppBar` with `automaticallyImplyLeading != false`); (b) at least one tappable whose label resolves to a non-null `AppLocalizations` key AND whose `onPressed`/`onTap` triggers a `context.go`/`context.push` to a route present in `route_metadata.dart` (the "recovery CTA" is defined as: a `MintButton`/`TextButton`/`ListTile` tagged with `Key('recoveryCta')` — the agent MUST tag the primary recovery CTA in every empty/error state with `key: const Key('recoveryCta')`); (c) NO widget matches a bare `Center(child: Text(<literal, non-l10n>))`. (c) is the blank-dead-end matcher.

### 10.3 F-3 Single write path — `single_write_path_test.dart`
Static source scan: FAIL if `SharedPreferences` `.setString(`/`.setInt(`/`.setDouble(`/`.setBool(` referencing a profile/budget/household key appears in any file EXCEPT `report_persistence_service.dart` and `coach_profile_provider.dart`. All profile writes go through `mergeAnswers/applySaveFact/updateProfile`. Also assert `ScanSessionProvider` writes only `scan_session_v1` and no profile keys.

### 10.4 F-4 Bridged providers — `provider_bridge_recompute_test.dart`
For each of `BudgetProvider`, `HouseholdProvider`, `TimelineProvider`, `DocumentsProvider`, conversation store, `ScanSessionProvider`: perform a mutation, then assert `MintStateProvider.recompute(profile)` was invoked (spy) AND the resulting `MintUserState` differs from pre-mutation. Each bridge obtains the profile via `context.read<CoachProfileProvider>().profile` at the call site (recompute REQUIRES the `CoachProfile` arg — see §0/§8; there is no zero-arg variant). For Budget specifically, assert `MintUserState.budgetGap` changed (fixes B-1).

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
```

Key gap resolutions embedded above:

- **arch-1 (double confidence source):** §8.0 puts `ConfidenceResult` on `MintUserState` in `recompute`; `/confidence` and `/home` both read it from the ledger. No in-route compute. Verified `computeConfidence(Map, List<FieldSource>, {...})` and that `mint_user_state.dart:92` is a `double`.
- **arch-2 / codex-4 (ScanSessionProvider):** §5.0 gives the complete state machine, OCR write point (`setExtraction`), `scan_session_v1` schema, GC policy (max 5 / applied 7d / failed 24h), and the exact recompute bridge trigger.
- **arch-3 (file path):** corrected to `apps/mobile/lib/screens/advisor/financial_report_screen_v2.dart:51-52` with both `investment` and `other`.
- **arch-4 / B-4 / E (provenance API):** §6.note states `applySaveFact` must be extended (with real current signature) and a `fieldProvenance` ledger field added; does not pretend it exists.
- **arch-5 / D (entry vs mode):** §1.2 makes it mechanical — simulators use in-screen mode switch, `entryConditions: none`, asserted by a test.
- **wiring-1 (spinner-forever):** §7 adds `.timeout(8s)` → `hasError` → errorState with a named test.
- **wiring-2 (`?? 'revenu'`):** §6.validation removes the coercion in the route builder with exact code + `_allowedDataBlockTypes`.
- **wiring-3 (shell routing):** §1.1 documents the `StatefulShellRoute.indexedStack`, shell column added, `/tools`→coach-branch `context.go` with query params specified.
- **wiring-4 (partialState untested):** §10.6 `partial_state_test.dart` with concrete marker keys.
- **wiring-5 / codex-6 (loose tests):** §10.0 fixture registry + §10.1 exact matcher list + single strategy per test.
- **codex-1 (killFlag):** §1.3 + real per-row values (null / enableScan / enableCoachChat / enableExplorer* / null for aliases), verified from `route_metadata.dart`.
- **codex-2 (recompute arg):** every call site shows `recompute(context.read<CoachProfileProvider>().profile)`.
- **codex-3 (premier-eclairage shim):** all recovery CTAs point to `/coach/chat?topic=premier-eclairage`, not the shim.
- **codex-5 (adapter):** §8.1 defines the `CoachProfile → (profileMap, List<FieldSource>)` mapping and replaces the hash note with ledger-recompute invalidation.
- **codex-7 (coverage):** added contracts for `/couple`, `/couple/accept`, `/timeline`, `/documents`, `/documents/:id`, `/budget`, `/check/debt`, `/independants/*`, `/assurances/*`, `/mortgage/*`, `/3a-deep/*`, `/life-event/donation`, `/cantonal-benchmark`, `/education/*`, `/open-banking/*`, plus killFlags.