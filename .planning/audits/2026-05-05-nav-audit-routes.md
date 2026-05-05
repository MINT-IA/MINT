# Sprint 1 — Navigation audit — Inventaires routes (Étapes 1 + 2)

> Source : `apps/mobile/lib/app.dart` (1907 LOC) + `apps/mobile/lib/services/navigation/screen_registry.dart` (2046 LOC).
> Date : 2026-05-05. Branche : `feat/sprint1-nav-audit` (worktree `MINT.sprint1-nav.nosync`).
>
> Comptes bruts (extracteur regex `tools/checks/screen_registry_parity.py`) :
> - `app.dart` : **153 path literals** (canoniques + redirects + nested children)
> - `screen_registry.dart` : **138 ScreenEntry routes**
> - Parity tool actuel : `[OK] 125 routes parity OK (after KNOWN-MISSES exemption).`

---

## Étape 1 — Routes déclarées dans `app.dart`

Sections suivent l'ordre du fichier. Numéros de ligne précis. `B` = builder (écran réel) · `R` = redirect (ScopedGoRoute avec `redirect:` only) · `S` = route shell (StatefulShellBranch).

### 1.1 — Landing + Auth (public, lignes 304–356)

| Route | Widget | Behavior | Commentaire |
|---|---|---|---|
| `/` (308) | `LandingScreen` | B | RouteScope.public. CTA `/start`. |
| `/start` (317) | redirect → `/onb` (flag) ou `/anonymous/intent` | R | FIX-02. |
| `/onb` (326) | `OnboardingShellScreen` | B | MVP wedge 9-step. `enableMvpWedgeOnboarding`. |
| `/auth/login` (331) | `LoginScreen` | B | |
| `/auth/register` (336) | `RegisterScreen` | B | |
| `/auth/forgot-password` (341) | `ForgotPasswordScreen` | B | |
| `/auth/verify-email` (346) | `VerifyEmailScreen` | B | |
| `/auth/verify` (351) | `_MagicLinkVerifyScreen` | B | Token via query param. |

### 1.2 — Anonymous (public, lignes 364–377)

| Route | Widget | Behavior | Commentaire |
|---|---|---|---|
| `/anonymous/intent` (365) | `AnonymousIntentScreen` | B | Pills d'intent + free-text. |
| `/anonymous/chat` (371) | `AnonymousChatScreen(intent: …)` | B | 3-msg auth gate. |

### 1.3 — Shell 4-tab (lignes 380–472)

| Route | Widget | Behavior | Commentaire |
|---|---|---|---|
| `/home` (390) | `AujourdhuiScreen` (loggedIn / localMode) sinon `LandingScreen` | S | Tab 0. Parse `?tab=N&intent=X&screen=S` (lignes 251–276 redirect). |
| `/mon-argent` (429) | `MonArgentScreen` | S | Tab 1. |
| `/coach/chat` (439) | `CoachChatScreen(entryPayload, conversationId, isEmbeddedInTab: true)` | S+B | Tab 2. RouteScope.public (anonyme). `?topic=…&conversationId=…`. |
| `/explore` (466) | `ExplorerScreen` | S | Tab 3. |

### 1.4 — Explorer hubs (lignes 475–577)

| Route | Widget | Behavior | Commentaire |
|---|---|---|---|
| `/explore/retraite` (476) | `ExploreHubScreen(...6 entries)` | B | rootNav. |
| `/explore/famille` (491) | `ExploreHubScreen(...5 entries)` | B | |
| `/explore/travail` (505) | `ExploreHubScreen(...6 entries)` | B | |
| `/explore/logement` (520) | `ExploreHubScreen(...7 entries)` | B | |
| `/explore/fiscalite` (536) | `ExploreHubScreen(...6 entries)` | B | |
| `/explore/patrimoine` (551) | `ExploreHubScreen(...5 entries)` | B | |
| `/explore/sante` (565) | `ExploreHubScreen(...5 entries)` | B | |

### 1.5 — Retraite & Prevoyance (lignes 580–693)

| Route | Widget | Behavior | Commentaire |
|---|---|---|---|
| `/retraite` (581) | `RetirementDashboardScreen` | B | |
| `/coach/dashboard` (586) | redirect → `/retraite` | R | Legacy. |
| `/retirement` (590) | redirect → `/retraite` | R | Legacy. |
| `/retirement/projection` (594) | redirect → `/retraite` | R | Legacy. |
| `/rente-vs-capital` (599) | `RenteVsCapitalScreen` | B | |
| `/arbitrage/rente-vs-capital` (604) | redirect → `/rente-vs-capital` | R | |
| `/simulator/rente-capital` (608) | redirect → `/rente-vs-capital` | R | |
| `/rachat-lpp` (613) | `RachatEchelonneScreen` | B | |
| `/lpp-deep/rachat` (618) | redirect → `/rachat-lpp` | R | |
| `/arbitrage/rachat-vs-marche` (622) | redirect → `/rachat-lpp` | R | |
| `/epl` (627) | `EplScreen` | B | |
| `/lpp-deep/epl` (632) | redirect → `/epl` | R | |
| `/decaissement` (637) | `OptimisationDecaissementScreen` | B | |
| `/coach/decaissement` (642) | redirect → `/decaissement` | R | |
| `/arbitrage/calendrier-retraits` (646) | redirect → `/decaissement` | R | |
| `/coach/cockpit` (652) | redirect → `/retraite` | R | Zombie. |
| `/coach/checkin` (657) | redirect → `/coach/chat` | R | STAB-14 archived. |
| `/coach/refresh` (661) | redirect → `/home` | R | |
| `/coach/history` (667) | `ConversationHistoryScreen` | B | |
| `/succession` (671) | `SuccessionPatrimoineScreen` | B | |
| `/coach/succession` (676) | redirect → `/succession` | R | |
| `/life-event/succession` (680) | redirect → `/succession` | R | |
| `/libre-passage` (685) | `LibrePassageScreen` | B | |
| `/lpp-deep/libre-passage` (690) | redirect → `/libre-passage` | R | |

### 1.6 — Fiscalité + Immobilier + Budget/Dette (lignes 696–794)

| Route | Widget | Behavior | Commentaire |
|---|---|---|---|
| `/pilier-3a` (697) | `Simulator3aScreen` | B | |
| `/simulator/3a` (701) | redirect → `/pilier-3a` | R | |
| `/3a-deep/comparator` (706) | `ProviderComparatorScreen` | B | |
| `/3a-deep/real-return` (712) | `RealReturnScreen` | B | |
| `/3a-deep/staggered-withdrawal` (716) | `StaggeredWithdrawalScreen` | B | |
| `/3a-retroactif` (721) | `Retroactive3aScreen` | B | |
| `/fiscal` (726) | `FiscalComparatorScreen` | B | |
| `/hypotheque` (733) | `AffordabilityScreen` | B | |
| `/mortgage/affordability` (738) | redirect → `/hypotheque` | R | |
| `/mortgage/amortization` (743) | `AmortizationScreen` | B | |
| `/mortgage/epl-combined` (748) | `EplCombinedScreen` | B | |
| `/mortgage/imputed-rental` (753) | `ImputedRentalScreen` | B | |
| `/mortgage/saron-vs-fixed` (758) | `SaronVsFixedScreen` | B | |
| `/budget` (765) | `BudgetContainerScreen` | B | |
| `/budget/setup` (770) | `BudgetSetupScreen` | B | |
| `/check/debt` (775) | `DebtRiskCheckScreen` | B | |
| `/debt/ratio` (780) | `DebtRatioScreen` | B | |
| `/debt/help` (785) | `HelpResourcesScreen` | B | |
| `/debt/repayment` (790) | `RepaymentScreen` | B | |

### 1.7 — Famille + Emploi + Indépendants + Assurance (lignes 797–911)

| Route | Widget | Behavior | Commentaire |
|---|---|---|---|
| `/divorce` (798) | `DivorceSimulatorScreen` | B | |
| `/life-event/divorce` (802) | redirect → `/divorce` | R | |
| `/mariage` (807) | `MariageScreen` | B | |
| `/naissance` (812) | `NaissanceScreen` | B | |
| `/concubinage` (817) | `ConcubinageScreen` | B | |
| `/unemployment` (824) | `UnemploymentScreen` | B | |
| `/first-job` (829) | `FirstJobScreen` | B | |
| `/expatriation` (834) | `ExpatScreen` | B | |
| `/simulator/job-comparison` (839) | `JobComparisonScreen` | B | |
| `/segments/independant` (846) | `IndependantScreen` | B | |
| `/independants/avs` (851) | `AvsCotisationsScreen` | B | |
| `/independants/ijm` (856) | `IjmScreen` | B | |
| `/independants/3a` (861) | `Pillar3aIndepScreen` | B | |
| `/independants/dividende-salaire` (866) | `DividendeVsSalaireScreen` | B | |
| `/independants/lpp-volontaire` (871) | `LppVolontaireScreen` | B | |
| `/invalidite` (878) | `DisabilityGapScreen` | B | |
| `/disability/gap` (883) | redirect → `/invalidite` | R | |
| `/simulator/disability-gap` (887) | redirect → `/invalidite` | R | |
| `/disability/insurance` (892) | `DisabilityInsuranceScreen` | B | |
| `/disability/self-employed` (897) | `DisabilitySelfEmployedScreen` | B | |
| `/assurances/lamal` (902) | `LamalFranchiseScreen` | B | |
| `/assurances/coverage` (907) | `CoverageCheckScreen` | B | |

### 1.8 — Documents + Couple + Rapport + Profile (lignes 914–1086)

| Route | Widget | Behavior | Commentaire |
|---|---|---|---|
| `/scan` (915) | `DocumentScanScreen(initialType: state.extra)` | B | extra = `DocumentType?`. |
| `/document-scan` (923) | redirect → `/scan` | R | |
| `/scan/avs-guide` (929) | `AvsGuideScreen` | B | |
| `/document-scan/avs-guide` (933) | redirect → `/scan/avs-guide` | R | |
| `/scan/review` (937) | `ExtractionReviewScreen(result: state.extra)` | B | extra requis sinon « Document non disponible ». |
| `/scan/impact` (950) | `DocumentImpactScreen(result, previousConfidence)` | B | extra Map requis. |
| `/documents` (969) | `DocumentsScreen` | B | |
| `/documents/:id` (974) | `DocumentDetailScreen(documentId)` | B | |
| `/couple` (985) | `HouseholdScreen` | B | |
| `/household` (989) | redirect → `/couple` | R | |
| `/couple/accept` (994) | `AcceptInvitationScreen(initialCode)` | B | |
| `/household/accept` (1002) | redirect → `/couple/accept?code=…` | R | |
| `/rapport` (1008) | `FinancialReportScreenV2(wizardAnswers)` | B | extra ou fallback `ReportPersistenceService.loadAnswers()`. |
| `/report` (1033) | redirect → `/rapport` | R | |
| `/report/v2` (1037) | redirect → `/rapport` | R | |
| `/profile` (1045) | redirect → `/profile/bilan` (si exact) sinon passthrough | R+nested | KILL-04. |
| `/profile/admin-observability` (1052) | `AdminObservabilityScreen` | B | gated `enableAdminScreens`. |
| `/profile/admin-analytics` (1058) | `AdminAnalyticsScreen` | B | gated. |
| `/profile/byok` (1065) | `ByokSettingsScreen` | B | |
| `/profile/slm` (1069) | `SlmSettingsScreen` | B | |
| `/profile/bilan` (1073) | `FinancialSummaryScreen` | B | « Dossier » canonique. |
| `/profile/privacy-control` (1077) | `PrivacyControlScreen` | B | |
| `/profile/privacy` (1082) | `PrivacyCenterScreen` | B | |

### 1.9 — Segments + Life events + Education + Simulateurs + Arbitrage (lignes 1089–1167)

| Route | Widget | Behavior | Commentaire |
|---|---|---|---|
| `/segments/gender-gap` (1091) | `GenderGapScreen` | B | |
| `/segments/frontalier` (1095) | `FrontalierScreen` | B | |
| `/life-event/housing-sale` (1101) | `HousingSaleScreen` | B | |
| `/life-event/donation` (1106) | `DonationScreen` | B | |
| `/life-event/deces-proche` (1111) | `DecesProcheScreen` | B | |
| `/life-event/demenagement-cantonal` (1116) | `DemenagementCantonalScreen` | B | |
| `/education/hub` (1123) | `ComprendreHubScreen` | B | |
| `/education/theme/:id` (1128) | `ThemeDetailScreen(themeId)` | B | |
| `/simulator/compound` (1138) | `SimulatorCompoundScreen` | B | |
| `/simulator/leasing` (1143) | `SimulatorLeasingScreen` | B | |
| `/simulator/credit` (1148) | `ConsumerCreditSimulatorScreen` | B | |
| `/arbitrage/bilan` (1155) | `ArbitrageBilanScreen` | B | |
| `/arbitrage/allocation-annuelle` (1160) | `AllocationAnnuelleScreen` | B | |
| `/arbitrage/location-vs-propriete` (1165) | `LocationVsProprieteScreen` | B | |

### 1.10 — Divers (lignes 1170–1255)

| Route | Widget | Behavior | Commentaire |
|---|---|---|---|
| `/achievements` (1170) | redirect → `/home` | R | |
| `/cantonal-benchmark` (1180) | `CantonalBenchmarkScreen` | B | |
| `/settings/langue` (1187) | `LangueSettingsScreen` | B | |
| `/settings/confidentialite` (1192) | `ConfidentialiteSettingsScreen` | B | |
| `/about` (1199) | `AboutScreen` | B | RouteScope.public. |
| `/admin/routes` (1210) | `AdminShell(child: RoutesRegistryScreen())` | B | dev-only `AdminGate.isAvailable`. |
| `/ask-mint` (1220) | redirect → `/coach/chat` | R | |
| `/tools` (1225) | redirect → `/coach/chat` | R | STAB-14 archived. |
| `/portfolio` (1229) | redirect → `/home` | R | |
| `/timeline` (1234) | `TimelineScreen` | B | |
| `/confidence` (1239) | `ConfidenceDashboardScreen(result)` | B | extra = `ConfidenceResult?`. |
| `/score-reveal` (1252) | redirect → `/home` | R | |

### 1.11 — Onboarding shims + Open Banking + bank-import + advisor redirects (lignes 1261–1379)

| Route | Widget | Behavior | Commentaire |
|---|---|---|---|
| `/onboarding/quick` (1262) | redirect → `/coach/chat` | R | P10-02b. |
| `/onboarding/quick-start` (1270) | redirect → `/coach/chat` | R | |
| `/onboarding/premier-eclairage` (1278) | redirect → `/coach/chat` | R | |
| `/onboarding/intent` (1287) | redirect → `/coach/chat` | R | KILL-01. |
| `/onboarding/promise` (1295) | redirect → `/coach/chat` | R | |
| `/onboarding/plan` (1303) | redirect → `/coach/chat` | R | |
| `/data-block/:type` (1311) | `DataBlockEnrichmentScreen(blockType)` | B | RouteScope.onboarding. |
| `/open-banking` (1322) | `OpenBankingHubScreen` | B | gated `enableOpenBanking`. |
| `/open-banking/transactions` (1329) | `TransactionListScreen` | B | gated. |
| `/open-banking/consents` (1336) | `ConsentScreen` | B | gated. |
| `/bank-import` (1343) | `BankImportScreen` | B | |
| `/advisor` (1351) | redirect → `/coach/chat` | R | |
| `/advisor/plan-30-days` (1355) | redirect → `/coach/chat` | R | |
| `/advisor/wizard` (1359) | redirect → `/coach/chat[?topic=…]` | R | |
| `/coach/agir` (1364) | redirect → `/coach/chat` | R | |
| `/onboarding/smart` (1368) | redirect → `/coach/chat` | R | |
| `/onboarding/minimal` (1372) | redirect → `/coach/chat` | R | |
| `/onboarding/enrichment` (1376) | redirect → `/profile/bilan` | R | |

**Total app.dart : 153 path literals (somme des B + R + S + nested children).**

Note non-route: `/home` route emits a SOFT redirect (lignes 251–276) selon `?tab=`, `?intent=`, `?screen=` — ce n'est PAS une nouvelle ScopedGoRoute mais un branchement à l'intérieur du `redirect:` global.

---

## Étape 2 — `ScreenEntry` dans `MintScreenRegistry`

Source : `apps/mobile/lib/services/navigation/screen_registry.dart` (master list lignes 1845–2001 dans `MintScreenRegistry.entries`). 138 entries totales.

Format : `intentTag` | `route` | `behavior` | `requiredFields` | `preferFromChat` | `prefillFromProfile`. Custom gates marqués (cg) là où définis.

### A — Direct Answer (348–367)

| intentTag | route | behavior | requiredFields | preferFromChat | prefillFromProfile |
|---|---|---|---|---|---|
| `budget_overview` | `/budget` | directAnswer | `[netIncome]` | true | true |
| `cantonal_comparison` | `/cantonal-benchmark` | directAnswer | `[canton, netIncome]` | true | true |

### B — Decision Canvas (373–832)

| intentTag | route | behavior | requiredFields | preferFromChat | prefillFromProfile |
|---|---|---|---|---|---|
| `retirement_choice` | `/rente-vs-capital` | decisionCanvas | `[salaireBrut, age]` (cg) | true | true |
| `retirement_projection` | `/retraite` | decisionCanvas | `[salaireBrut, age, canton]` | true | true |
| `preretraite_complete` | `/retraite?mode=preretraite` (norm. `/retraite`) | decisionCanvas | `[salaireBrut, age, canton]` | true | true |
| `simulator_3a` | `/pilier-3a` | decisionCanvas | `[salaireBrut, canton]` | true | true |
| `tax_optimization_3a` | `/3a-deep/staggered-withdrawal` | decisionCanvas | `[age, canton]` | true | true |
| `cantonal_fiscal_comparator` | `/fiscal` | decisionCanvas | `[canton, netIncome]` | true | true |
| `lpp_buyback` | `/rachat-lpp` | decisionCanvas | `[salaireBrut, age, canton]` | true | true |
| `lpp_deep_rachat` | `/lpp-deep/rachat` | decisionCanvas | `[]` (cg) | true | true |
| `early_pension_withdrawal` | `/epl` | decisionCanvas | `[salaireBrut, age, canton]` | true | true |
| `housing_purchase` | `/hypotheque` | decisionCanvas | `[salaireBrut, canton]` | true | true |
| `disability_gap` | `/invalidite` | decisionCanvas | `[employmentStatus, salaireBrut]` (cg) | true | true |
| `job_comparison` | `/simulator/job-comparison` | decisionCanvas | `[salaireBrut, canton]` | true | true |
| `lamal_franchise` | `/assurances/lamal` | decisionCanvas | `[]` | true | false |
| `withdrawal_sequencing` | `/decaissement` | decisionCanvas | `[salaireBrut, age, canton]` | true | true |
| `mortgage_amortization` | `/mortgage/amortization` | decisionCanvas | `[]` | true | false |
| `saron_vs_fixed` | `/mortgage/saron-vs-fixed` | decisionCanvas | `[]` | true | false |
| `epl_combined` | `/mortgage/epl-combined` | decisionCanvas | `[salaireBrut, age, canton]` | true | true |
| `dividende_vs_salaire` | `/independants/dividende-salaire` | decisionCanvas | `[employmentStatus]` | true | true |
| `provider_comparator_3a` | `/3a-deep/comparator` | decisionCanvas | `[]` | true | false |
| `real_return_3a` | `/3a-deep/real-return` | decisionCanvas | `[]` | true | false |
| `retroactive_3a` | `/3a-retroactif` | decisionCanvas | `[salaireBrut, age, canton]` | true | true |
| `rent_vs_buy` | `/arbitrage/location-vs-propriete` | decisionCanvas | `[salaireBrut, canton]` | true | true |
| `succession_patrimoine` | `/succession` | decisionCanvas | `[]` | true | false |
| `libre_passage` | `/libre-passage` | decisionCanvas | `[employmentStatus]` | true | true |
| `annual_allocation` | `/arbitrage/allocation-annuelle` | decisionCanvas | `[salaireBrut, canton]` | true | true |
| `coverage_check` | `/assurances/coverage` | decisionCanvas | `[canton]` | true | true |
| `gender_gap` | `/segments/gender-gap` | decisionCanvas | `[salaireBrut, age]` | true | false |
| `disability_self_employed` | `/disability/self-employed` | decisionCanvas | `[employmentStatus]` | true | true |
| `avs_cotisations_independant` | `/independants/avs` | decisionCanvas | `[employmentStatus]` | true | true |
| `ijm_independant` | `/independants/ijm` | decisionCanvas | `[employmentStatus]` | true | true |
| `pillar_3a_independant` | `/independants/3a` | decisionCanvas | `[employmentStatus]` | true | true |
| `lpp_volontaire` | `/independants/lpp-volontaire` | decisionCanvas | `[employmentStatus]` | true | true |
| `compound_interest_simulator` | `/simulator/compound` | decisionCanvas | `[]` | true | false |
| `leasing_simulator` | `/simulator/leasing` | decisionCanvas | `[]` | true | false |
| `consumer_credit_simulator` | `/simulator/credit` | decisionCanvas | `[]` | true | false |
| `debt_ratio` | `/debt/ratio` | decisionCanvas | `[netIncome]` (cg) | true | true |
| `debt_repayment` | `/debt/repayment` | decisionCanvas | `[]` | true | false |
| `debt_risk_check` | `/check/debt` | decisionCanvas | `[]` | true | false |
| `financial_report` | `/rapport` | decisionCanvas | `[salaireBrut, age, canton]` | true | true |
| `life_timeline` | `/timeline` | decisionCanvas | `[age]` | true | true |
| `arbitrage_bilan` | `/arbitrage/bilan` | decisionCanvas | `[salaireBrut, age, canton]` | true | true |
| `financial_cockpit` | `/coach/cockpit` ⚠️ | decisionCanvas | `[salaireBrut, age, canton]` | true | true |
| `imputed_rental` | `/mortgage/imputed-rental` | decisionCanvas | `[]` | true | false |
| `portfolio_overview` | `/portfolio` ⚠️ | decisionCanvas | `[]` | true | false |
| `financial_summary` | `/profile/bilan` | decisionCanvas | `[]` | true | true |

### C — Roadmap Flow (836–977)

| intentTag | route | behavior | requiredFields | preferFromChat | prefillFromProfile |
|---|---|---|---|---|---|
| `life_event_divorce` | `/divorce` | roadmapFlow | `[salaireBrut, conjoint]` | true | false |
| `life_event_birth` | `/naissance` | roadmapFlow | `[salaireBrut, canton]` | true | false |
| `life_event_marriage` | `/mariage` | roadmapFlow | `[salaireBrut]` | true | false |
| `life_event_concubinage` | `/concubinage` | roadmapFlow | `[salaireBrut]` | true | false |
| `life_event_job_loss` | `/unemployment` | roadmapFlow | `[salaireBrut, age]` | true | false |
| `life_event_first_job` | `/first-job` | roadmapFlow | `[]` | true | false |
| `life_event_housing_sale` | `/life-event/housing-sale` | roadmapFlow | `[canton]` | true | false |
| `life_event_donation` | `/life-event/donation` | roadmapFlow | `[canton]` | true | false |
| `life_event_death_of_relative` | `/life-event/deces-proche` | roadmapFlow | `[canton]` | true | false |
| `life_event_country_move` | `/expatriation` | roadmapFlow | `[canton]` | true | false |
| `cross_border` | `/segments/frontalier` | roadmapFlow | `[employmentStatus]` (cg) | true | false |
| `self_employment` | `/segments/independant` | roadmapFlow | `[]` | true | false |
| `life_event_canton_move` | `/life-event/demenagement-cantonal` | roadmapFlow | `[]` | true | false |
| `disability_insurance_flow` | `/disability/insurance` | roadmapFlow | `[employmentStatus]` | true | false |

### D — Capture / Utility (981–1169)

| intentTag | route | behavior | requiredFields | preferFromChat | prefillFromProfile |
|---|---|---|---|---|---|
| `document_scan` | `/scan` | captureUtility | `[]` | true | false |
| `documents_list` | `/documents` | captureUtility | `[]` | true | false |
| `profile_enrichment` | `/profile` | captureUtility | `[]` | true | false |
| `avs_guide` | `/scan/avs-guide` | captureUtility | `[]` | true | false |
| `household_couple` | `/couple` | captureUtility | `[]` | true | false |
| `open_banking` | `/open-banking` | captureUtility | `[]` | true | false |
| `consent_settings` | `/profile/privacy-control` | captureUtility | `[]` | **false** | false |
| `byok_settings` | `/profile/byok` | captureUtility | `[]` | **false** | false |
| `slm_settings` | `/profile/slm` | captureUtility | `[]` | **false** | false |
| `scan_review` | `/scan/review` | captureUtility | `[]` | **false** | false |
| `scan_impact` | `/scan/impact` | captureUtility | `[]` | **false** | false |
| `document_detail` | `/documents/:id` | captureUtility | `[]` | **false** | false |
| `couple_accept_invitation` | `/couple/accept` | captureUtility | `[]` | **false** | false |
| `data_block_enrichment` | `/data-block/:type` | captureUtility | `[]` | **false** | false |
| `bank_import` | `/bank-import` | captureUtility | `[]` | true | false |
| `open_banking_transactions` | `/open-banking/transactions` | captureUtility | `[]` | **false** | false |
| `open_banking_consents` | `/open-banking/consents` | captureUtility | `[]` | **false** | false |
| `admin_observability` | `/profile/admin-observability` | captureUtility | `[]` | **false** | false |
| `admin_analytics` | `/profile/admin-analytics` | captureUtility | `[]` | **false** | false |
| `coach_annual_refresh` | `/coach/refresh` ⚠️ | captureUtility | `[]` | **false** | false |
| `onboarding_quick` | `/onboarding/quick` ⚠️ | captureUtility | `[]` | **false** | false |
| `onboarding_premier_eclairage` | `/onboarding/premier-eclairage` ⚠️ | captureUtility | `[]` | **false** | false |
| `debt_help_resources` | `/debt/help` | captureUtility | `[]` | true | false |

### E — Conversation Pure / Non-routable (1173–1394)

| intentTag | route | behavior | requiredFields | preferFromChat | prefillFromProfile |
|---|---|---|---|---|---|
| `landing` | `/` | conversationPure | `[]` | **false** | false |
| `coach_chat` | `/coach/chat` | conversationPure | `[]` | **false** | false |
| `achievements` | `/achievements` ⚠️ | conversationPure | `[]` | **false** | false |
| `home_shell` | `/home` | conversationPure | `[]` | **false** | false |
| `auth_login` | `/auth/login` | conversationPure | `[]` | **false** | false |
| `auth_register` | `/auth/register` | conversationPure | `[]` | **false** | false |
| `auth_forgot_password` | `/auth/forgot-password` | conversationPure | `[]` | **false** | false |
| `auth_verify_email` | `/auth/verify-email` | conversationPure | `[]` | **false** | false |
| `explore_hub_retraite` | `/explore/retraite` | conversationPure | `[]` | true | false |
| `explore_hub_famille` | `/explore/famille` | conversationPure | `[]` | true | false |
| `explore_hub_travail` | `/explore/travail` | conversationPure | `[]` | true | false |
| `explore_hub_logement` | `/explore/logement` | conversationPure | `[]` | true | false |
| `explore_hub_fiscalite` | `/explore/fiscalite` | conversationPure | `[]` | true | false |
| `explore_hub_patrimoine` | `/explore/patrimoine` | conversationPure | `[]` | true | false |
| `explore_hub_sante` | `/explore/sante` | conversationPure | `[]` | true | false |
| `coach_checkin` | `/coach/checkin` ⚠️ | conversationPure | `[]` | **false** | false |
| `coach_history` | `/coach/history` | conversationPure | `[]` | **false** | false |
| `education_hub` | `/education/hub` | conversationPure | `[]` | true | false |
| `education_theme_detail` | `/education/theme/:id` | conversationPure | `[]` | true | false |
| `score_reveal` | `/score-reveal` ⚠️ | conversationPure | `[]` | **false** | false |
| `ask_mint` | `/ask-mint` ⚠️ | conversationPure | `[]` | true | false |
| `confidence_dashboard` | `/confidence` | directAnswer | `[]` | true | false |
| `consult_specialist` | `/coach/chat?topic=specialist` (norm. `/coach/chat`) | conversationPure | `[]` | true | false |
| `prepare_tax_form` | `/coach/chat?topic=taxDeclaration` (norm. `/coach/chat`) | conversationPure | `[]` | true | false |
| `prepare_avs_letter` | `/coach/chat?topic=avsExtract` (norm. `/coach/chat`) | conversationPure | `[]` | true | false |
| `prepare_lpp_transfer` | `/coach/chat?topic=lppTransfer` (norm. `/coach/chat`) | conversationPure | `[]` | true | false |

### Phase 53-01 fill — ROUTABLE shadow entries (1496–1783)

> Same physical screens as canonical routes, but exposed as Phase 53-01 parity-fill shims pointing at LEGACY redirect paths in `app.dart` (e.g. `/retirement` → `/retraite`). Marked **DUPLICATE-INTENT-SHIM** below — they exist solely so the LLM resolver doesn't break when prompts contain the legacy form. Cleanup candidate.

| intentTag | route | behavior | preferFromChat |
|---|---|---|---|
| `advisor_handoff` | `/advisor` (redirect) | decisionCanvas | true |
| `advisor_30_day_plan` | `/advisor/plan-30-days` (redirect) | decisionCanvas | true |
| `advisor_wizard` | `/advisor/wizard` (redirect) | captureUtility | true |
| `withdrawal_calendar` | `/arbitrage/calendrier-retraits` (redirect) | decisionCanvas | true |
| `lpp_buyback_vs_market` | `/arbitrage/rachat-vs-marche` (redirect) | decisionCanvas | true |
| `rente_vs_capital_arbitrage` | `/arbitrage/rente-vs-capital` (redirect) | decisionCanvas | true |
| `budget_setup` | `/budget/setup` | captureUtility | true |
| `decaissement_plan` | `/coach/decaissement` (redirect) | decisionCanvas | true |
| `succession_planning` | `/coach/succession` (redirect) | decisionCanvas | true |
| `disability_gap_check` | `/disability/gap` (redirect) | decisionCanvas | true |
| `document_scan_entry` | `/document-scan` (redirect) | captureUtility | true |
| `avs_extract_guide` | `/document-scan/avs-guide` (redirect) | captureUtility | true |
| `household_overview` | `/household` (redirect) | decisionCanvas | true |
| `household_accept_invite` | `/household/accept` (redirect) | captureUtility | true |
| `life_event_divorce_v2` | `/life-event/divorce` (redirect) | decisionCanvas | true |
| `life_event_succession` | `/life-event/succession` (redirect) | decisionCanvas | true |
| `lpp_deep_epl` | `/lpp-deep/epl` (redirect) | decisionCanvas | true |
| `lpp_deep_libre_passage` | `/lpp-deep/libre-passage` (redirect) | decisionCanvas | true |
| `mortgage_affordability_v2` | `/mortgage/affordability` (redirect) | decisionCanvas | true |
| `report_overview` | `/report` (redirect) | captureUtility | true |
| `report_v2` | `/report/v2` (redirect) | captureUtility | true |
| `retirement_overview` | `/retirement` (redirect) | decisionCanvas | true |
| `retirement_projection_v2` | `/retirement/projection` (redirect) | decisionCanvas | true |
| `simulator_3a_v2` | `/simulator/3a` (redirect) | decisionCanvas | true |
| `simulator_disability_gap` | `/simulator/disability-gap` (redirect) | decisionCanvas | true |
| `simulator_rente_capital` | `/simulator/rente-capital` (redirect) | decisionCanvas | true |

### Phase 53-01 fill — NOT_CHAT_ROUTABLE shadows (1786–1833)

| intentTag | route | preferFromChat |
|---|---|---|
| `coach_action_log` | `/coach/agir` (redirect) | false |
| `coach_dashboard` | `/coach/dashboard` (redirect) | false |
| `explore_tab` | `/explore` | false |
| `mon_argent_tab` | `/mon-argent` | false |
| `tools_tab` | `/tools` (redirect) | false |
| `settings_privacy` | `/settings/confidentialite` | false |
| `settings_language` | `/settings/langue` | false |

**Total ScreenEntry : 138.** Annotation `⚠️` = entry pointe sur une route APP-DART qui est REDIRECT-ONLY ou ZOMBIE (`/coach/cockpit`, `/coach/checkin`, `/coach/refresh`, `/portfolio`, `/score-reveal`, `/onboarding/quick`, `/onboarding/premier-eclairage`, `/achievements`, `/ask-mint`) — donc le ScreenEntry ne ramène jamais sur l'écran cible décrit par son `intentTag`. Cf. `nav-audit-gaps.md` §3.b.
