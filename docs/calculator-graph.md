# Calculator graph — from CoachProfile to UI

**Why this file exists.** MINT has ~20 calculators. Most are pure
functions of `CoachProfile`. Some have subtle dependencies (e.g.
`FriComputationService` calls 4 other calculators internally). When
you change `CoachProfile`, or add a field, or swap a derived value, you
don't know which UI surface will notice — unless this map is fresh.

**Invariant (CLAUDE.md §4).** Every financial calculation **must** live
under `apps/mobile/lib/services/financial_core/`. The backend mirrors
via `services/backend/app/services/rules_engine/`. Never duplicate a
calculation in a feature directory — it drifts, Julien + Lauren golden
values stop matching, and two calculators with different rounding
arrive in prod.

Grep to enforce:
```
grep -rn "_calculate\|_compute" apps/mobile/lib/services/ | grep -v financial_core/
```
If you hit a match outside `financial_core/`, it's a regression.

---

## The graph at a glance

```mermaid
flowchart LR
    PROFILE[CoachProfile]:::profile

    PROFILE --> AVS_REF[AvsReferenceAge]:::calc
    CI_OBSERVED["CI-observed self missing contribution years"]:::profile --> EXPAT_AVS["ExpatService.assessAvsGapOrientation<br/>count only / no write"]:::composer
    AVS_REGISTRY["RegulatoryRegistry<br/>avs.full_contribution_years"]:::profile --> AVS_RANGE["Expat input range guard<br/>not a personal denominator"]:::composer
    AVS_RANGE --> EXPAT_AVS
    EXPAT_LOCAL["Nullable local years abroad + explicit opt-in<br/>no ledger write"]:::profile --> EXPAT_AVS
    EXPAT_AVS --> EXPAT_UI["/expatriation AVS tab<br/>declared + CI counts only<br/>no pension / CHF / % / official scale"]:::ui
    OFFICIAL_AVS["Official person-owned pension evidence<br/>entitlement + scale + payment mode + legal facts"]:::profile --> AVS_COUPLE["AvsCalculator.computeCouplePensions<br/>fail closed / zero production callers"]:::calc
    AVS_COUPLE --> AVS_COUPLE_CONTRACT["Contract and tests only<br/>no activated product result"]:::composer
    SELF_EMPLOYED_NET["Self-employed net income"]:::profile --> AVS_GAUGE["AvsCalculator.selfEmployedCotisationGaugePosition"]:::calc
    AVS_GAUGE --> INDEP_AVS_UI["/independants/avs barème gauge"]:::ui
    RAMD_INPUT["Explicit RAMD lookup input"]:::profile --> AVS_RAMD["AvsCalculator.renteFromRAMD<br/>isolated Échelle 44 lookup<br/>zero production callers"]:::calc
    AVS_MONTHS["Owner-scoped monthly AVS evidence"]:::profile --> AVS_13[AvsThirteenthPensionCalculator]:::calc
    AVS_DECEMBER["1 December entitlement evidence"]:::profile --> AVS_13
    AVS_13 --> INDEP
    PROFILE --> LPP[LppCalculator]:::calc
    PROFILE --> TAX[TaxCalculator]:::calc
    PROFILE --> HOUSING[HousingCostCalculator]:::calc
    PURCHASE_FACTS["Fixed monthly salary x declared contractual months + liquid savings + 3a + LPP"]:::profile --> PURCHASE_CAP[MortgagePurchaseCapacityCalculator]:::calc
    PURCHASE_CAP --> CAP_SEQUENCE[CapSequenceEngine]:::composer
    PURCHASE_CAP --> AFFORDABILITY[AffordabilityCalculator]:::composer
    PROFILE --> BAYESIAN[BayesianEnricher]:::calc

    FRI[FriCalculator]:::composer
    LPP --> FRI
    TAX --> FRI
    HOUSING --> FRI

    PROFILE --> COUPLE[CoupleOptimizer]:::calc
    PROFILE --> CROSS[CrossPillarCalculator]:::calc
    PROFILE --> ARB[ArbitrageEngine]:::composer
    CROSS --> ARB
    TAX --> ARB
    PROFILE --> DISABILITY[DisabilityInsuranceCalculator]:::calc
    REPORT_INCOME["Retirement income (nullable) + current income"]:::profile --> REPLACEMENT[ReplacementRateCalculator]:::calc
    REPLACEMENT --> RETIREMENT_REPORT["RetirementProjection / report"]:::ui
    WIZARD[Wizard answers]:::profile --> EMERGENCY[EmergencyFundHeuristic]:::calc
    EMERGENCY --> PERSIST[ReportPersistenceService legacy quarantine]:::composer
    PROFILE --> WEALTH[WealthFinancialFacts]:::calc
    PROFILE --> SUCCESSION[SuccessionReserveCalculator]:::calc
    LAMAL_FACTS[LAMal Ledger Facts]:::profile --> LAMAL[LamalPremiumNormalizer]:::calc

    PROFILE --> CONF[ConfidenceScorer]:::score
    PROFILE --> CONF_ENH[EnhancedConfidenceService]:::score
    CONF --> CONF_ENH

    PROFILE --> PAT[PatrimoineAggregator]:::ui
    PROFILE --> WHISPER[CoachWhisperService]:::ui

    FRI --> NAR[CoachNarrativeService]:::ui
    CONF --> NAR

    MC[MonteCarloService]:::calc --> ARB
    WITHDRAW[WithdrawalSequencingService]:::calc --> ARB
    COMPOUND[CompoundContributionProjectionCalculator]:::calc --> INDEP[IndependantsService]:::composer
    SUCCESSION --> DONATION[DonationService]:::composer

    classDef profile fill:#E0F2F1,stroke:#00382E
    classDef calc fill:#FFF,stroke:#1D1D1F
    classDef composer fill:#FBFBFD,stroke:#1D1D1F,stroke-width:2px
    classDef score fill:#F5F5F7,stroke:#6E6E73
    classDef ui fill:#E6F9F0,stroke:#157B35
```

---

## Calculators in `financial_core/` (source of truth)

Each is a pure function of its inputs. No side-effects. Tested against
Julien + Lauren golden values.

| Calculator | File | Inputs | Returns | Primary consumers |
|---|---|---|---|---|
| **AvsCalculator** | `avs_calculator.dart` | Official person-owned pension, entitlement, scale, percentage/payment mode, legal status, and sourced separation evidence for the couple contract; self-employed net income for the gauge; explicit RAMD or bridge/lifetime amounts for isolated primitives | Fail-closed couple-cap result; self-employed barème gauge; isolated Échelle 44, bridge, and lifetime-loss primitives. No method derives a pension, CHF effect, or percentage from declared residence years or a CI gap count. | `/independants/avs` is the only production caller, for the gauge. `computeCouplePensions`, `renteFromRAMD`, and the bridge/lifetime primitives have no production caller and remain contract/test surfaces. |
| **AvsReferenceAge** | `avs_reference_age.dart` | birth year/date, gender | AVS21 reference age in months/years/date + reached-window checks | LACI/unemployment eligibility surfaces |
| **AvsThirteenthPensionCalculator** | `avs_thirteenth_pension_calculator.dart` | owner-scoped monthly ordinary AVS evidence, 1 December entitlement, legal snapshot, payment cadence/date | exact-cent ordinary cashflow, separate certified or illustrative December supplement, correction and readiness | IndependantsService scenario bridge behind `enableAvsThirteenthScenarioCashflow` |
| **LppCalculator** | `lpp_calculator.dart` | avoir, rate, years | projected capital + rente | FriCalculator, ProjectionRetraiteScreen, ArbitrageEngine |
| **TaxCalculator** | `tax_calculator.dart` | income, canton, marital, 3a | federal + cantonal + marginal | ArbitrageEngine, ProjectionFiscaleScreen |
| **HousingCostCalculator** | `housing_cost_calculator.dart` | loyer/hyp + canton | monthly housing effective cost | FriCalculator, budget calcs |
| **MortgagePurchaseCapacityCalculator** | `mortgage_purchase_capacity_calculator.dart` | durable annual gross income, liquid savings, 3a assets, LPP assets; mortgage ratios/rates via the regulatory registry | maximum purchase price + revenue/equity binding constraint | CapSequenceEngine, AffordabilityCalculator |
| **FriCalculator** (composite) | `fri_calculator.dart` | CoachProfile | FRI score 0-100 + breakdown | FriComputationService, CoachNarrativeService |
| **IncomeConversionCalculator** | `income_conversion_calculator.dart` | salary, months, bonus, employment rate | normalized salary/bonus/rate units | CoachProfile.fromWizardAnswers, CoachProfileProvider |
| **ConfidenceScorer** | `confidence_scorer.dart` | CoachProfile | score 0-100 + per-field confidence | ExtractionReviewScreen, RetirementDashboardScreen, `dataReliability` |
| **CrossPillarCalculator** | `cross_pillar_calculator.dart` | 3 pillars values | arbitrage opportunities | ArbitrageEngine |
| **CoupleOptimizer** | `couple_optimizer.dart` | 2 profiles | optimization suggestions | CoupleDashboardScreen |
| **ArbitrageEngine** (composite) | `arbitrage_engine.dart` | profile + constants | action list | ArbitrageBilanScreen, coach suggestions |
| **BayesianEnricher** | `bayesian_enricher.dart` | profile + priors | enriched profile w/ estimates | CoachReasoner |
| **MonteCarloService** | `monte_carlo_service.dart` | profile + scenarios | probability distributions | RetirementDashboard scenarios (Prudent/Base/Optimiste) |
| **WithdrawalSequencingService** | `withdrawal_sequencing_service.dart` | retirement params | sequencing plan | DecaissementScreen |
| **CompoundContributionProjectionCalculator** | `compound_contribution_projection_calculator.dart` | annual contribution, years, annual return | future value of repeated contributions | IndependantsService 3a projection bridge |
| **CoachReasoner** | `coach_reasoner.dart` | CoachContext | reasoning chain | CoachNarrativeService advanced narratives |
| **DisabilityInsuranceCalculator** | `disability_insurance_calculator.dart` | gross monthly salary, age, liquid savings, monthly fixed charges, IJM scenario flag | reserve months, employer/IJM/AI+LPP timeline income, LPP reset capital, life-drop % | DisabilityGapScreen, DisabilityInsuranceScreen |
| **ReplacementRateCalculator** | `replacement_rate_calculator.dart` | monthly retirement income (nullable), current monthly income | nullable replacement rate in %, clamped to 0–150%; invalid or incomplete inputs stay null | `RetirementProjection.replacementRate`, financial report |
| **EmergencyFundHeuristic** | `emergency_fund_heuristic.dart` | `q_emergency_fund` bucket, housing cost/frequency, monthly LAMal premium | reconstructed old emergency-fund cash estimate | ReportPersistenceService legacy quarantine only; never an explicit cash fact |
| **LamalPremiumNormalizer** | `lamal_premium_normalizer.dart` | actual monthly premium, current franchise, adult/child flag, franchise savings table | monthly premium normalized to CHF 300 franchise baseline | LamalFranchiseService, LamalFranchiseScreen |
| **WealthFinancialFacts** | `wealth_financial_facts.dart` | cash, investments, property market value, broad wealth estimate | property net value, net wealth, consumer debt, aggregate-vs-detail reconciliation status and resolved total | PatrimoineProfile, DonationScreen, patrimoine and life-event consumers |
| **GiftTaxConfirmation** | `gift_tax_confirmation.dart` | none | no computed cantonal gift-tax rate/amount sentinel for confirmation states | DonationService |
| **SuccessionReserveCalculator** | `succession_reserve_calculator.dart` | estate reference, civil status, children count | Swiss compulsory-heir reserve, disposable portion, spouse/children context flags, large-donation threshold | DonationService |
| **IndependentProtectionFinancialFacts** | `independent_protection_financial_facts.dart` | declared independent annual net income proxy, age, declared vested-benefits balance | monthly AVS extra share + LPP employer-share proxy on coordinated salary; named educational proxies for voluntary LPP tax saving, IJM/LAA protection cost and five-year vested-benefits scenarios; illustrative until former gross/insured salary and real insurance quotes are known | IndependantScreen |

### Mortgage durable-income boundary

`CapSequenceEngine` supplies the prudential housing headline with
`salaireBrutMensuel × nombreDeMois`. A declared 13th salary therefore counts
only through its contractual month count. `bonusPourcentage` remains excluded
until MINT has separate evidence that the compensation is durable and the
lender accepts it. A linked spouse is not a co-borrower and contributes no
income without an explicit, scoped co-borrower contract. The same durable base
is used by the fallback monthly-margin estimate; the purchase-price arithmetic
itself remains owned by `MortgagePurchaseCapacityCalculator`.

---

## Aggregators & downstream services (above the pure core)

Not in `financial_core/` but still pure-ish — compose core calculators
for a specific UI surface. Found under `apps/mobile/lib/services/`.

| Service | File | Role | Reads | Consumers |
|---|---|---|---|---|
| **FriComputationService** | `fri_computation_service.dart` | Runs `FriCalculator` + archetype detection + breakdown | CoachProfile | CoachNarrativeService, MintStateEngine |
| **PatrimoineAggregator** | `mon_argent/patrimoine_aggregator.dart` | 5-state snapshot (empty/loading/partial/data/error) | CoachProfile | `mon_argent_screen.dart`, PatrimoineSummaryCard |
| **CoachWhisperService** | `mon_argent/coach_whisper_service.dart` | Silent whisper trigger (loyer > 33% net, etc.) | budget + patrimoine + profile | Mon argent screen |
| **CoachNarrativeService** | `coach_narrative_service.dart` | Daily narrative (greeting, scoreSummary, topTip, scenarios) | CoachProfile, FriComputation, CapMemoryStore | Aujourd'hui screen |
| **MintStateEngine** | `mint_state_engine.dart` | Session delta computation | SessionSnapshot + profile | App startup, Aujourd'hui |
| **StreakService** | `streak_service.dart` | Check-in streak | `profile.checkIns` | CoachNarrativeService |
| **EnhancedConfidenceService** | `confidence/enhanced_confidence_service.dart` | Per-field confidence + enrichment prompts | CoachProfile | Extraction review, Retirement dashboard |
| **SnapshotService** | `snapshot_service.dart` | Persists daily/scan/life-event snapshots | CoachProfile | `updateFromRefresh`, `createSnapshotFromProfile` |
| **SessionSnapshotService** | `session_snapshot_service.dart` | In-session delta | Snapshot + current profile | MintStateEngine |
| **DonationService** | `donation_service.dart` | ledger facts + scenario assumptions + SuccessionReserveCalculator | educational gift-tax status, reserve/disposable portion, alerts/checklist | DonationScreen |
| **ExpatService** | `expat_service.dart` | Returns a count-only `AvsGapAssessment`; declared years abroad remain local and opt-in, while CI-observed self missing years stay nullable and certificate-backed | Declared years abroad, nullable self CI count, and registry key `avs.full_contribution_years` strictly as the input range bound—never as a personal pension denominator | ExpatScreen, AvsGapWidget; no percentage, CHF effect, pension, readiness-score effect, official scale, partner synthesis, or profile write |

---

## UI consumers of `CoachProfileProvider` (not exhaustive — grep for the latest)

Watch/read sites where a stale or null profile breaks the UI. Grep:

```
grep -rn "context\.watch<CoachProfileProvider>\|context\.read<CoachProfileProvider>\|Provider\.of<CoachProfileProvider>" apps/mobile/lib
```

Typical hotspots:
- `aujourdhui_screen.dart` → « Cap du jour » uses narrative
- `mon_argent_screen.dart` → Budget + Patrimoine cards
- `financial_summary_screen.dart` (`/profile/bilan`) → full dashboard
- `retirement_dashboard_screen.dart` → « Mes données » + scenarios
- `coach_chat_screen.dart` → context builder + narrative + `applySaveFact`
- Extraction review screen → confidence delta + insights

---

## Façade watchlist (from 2026-04-21 audit)

Services that EXIST but are under- or un-wired. Do not build new
features on top of these until the câblage is real. Full details:
[`.planning/triage-2026-04-20-service-audit.md`](../.planning/triage-2026-04-20-service-audit.md).

| Service | Status | What's broken |
|---|---|---|
| **CoachCacheService** | 🔴 Dead code | `invalidate()` is called; `get()` / `set()` are never called in prod. Greenfield. Either remove or wire a real consumer. |
| **MilestoneService** | 🔴 Does not exist | Only l10n strings + `PlanMilestone` model. Jalons trimestriels = UI decoration, not computed. |
| **AnnualRefresh trigger** | 🔴 Orphaned | `snapshot_service.dart:193` checks `trigger == 'annual_refresh'`. Zero caller. Screen deleted in deep-audit 2026-04-17, check left behind. |
| **LifeEventsService** | 🟡 Under-wired | 1 external caller (`divorce_simulator_screen.dart`). 17 other simulators read profile directly — fine in isolation, but no « your active life events » hub. |

---

## When you add a new calculator — the 5-step protocol

1. **Place it under `apps/mobile/lib/services/financial_core/`**. Not
   elsewhere. If backend needs it too, mirror in
   `services/backend/app/services/rules_engine/` and write a golden
   value test in both that asserts the same output for the same input.
2. **Pure function.** No DB, no network, no I/O, no state. Inputs from
   CoachProfile or explicit params. Output = immutable value.
3. **Test against Julien + Lauren golden values** at
   [`test/golden/`](../apps/mobile/test/golden/). Any non-trivial
   output must match a known-good fixture.
4. **Register it in this graph.** Add a row to the calculator table
   above. Draw the mermaid edge. Name the consumers.
5. **If the calculator exposes a named result (FRI score, fitness %,
   etc.)**, add it to the SOT.md data contract so mobile and backend
   agree on the wire shape.

---

## When you consume a calculator from a new UI surface

1. Never call the calculator from a widget directly — go through the
   aggregator service or the provider if one exists. Otherwise the same
   math gets redone 4 times.
2. If an aggregator doesn't exist, create one in
   `apps/mobile/lib/services/<feature>/` and add a row to the
   aggregators table.
3. Add the route / screen to the route_metadata (Phase 32) so Sentry
   can pick up per-route performance.

---

*Last updated: 2026-07-14 after G1-AVS-03 retired the unofficial AVS gap-effect bridge, made Expat AVS count-only, and recorded the production-unwired official couple contract alongside the independent barème gauge. The graph also registers `MortgagePurchaseCapacityCalculator` and `AvsThirteenthPensionCalculator`.
Façade status comes from the 2026-04-21 audit in
`.planning/triage-2026-04-20-service-audit.md`. When you refactor any
service in `financial_core/` or add a new aggregator, update this file
in the same PR.*
