# MINT — CARTE D'INTÉGRATION DES ÉCRANS

> **Companion du WIRE_SPEC_V2.md**
> Pour chaque écran existant : son sort dans la nouvelle architecture (3 tabs + drawer),
> comment le coach interagit avec lui, et les câbles à connecter.
>
> **⚠️ LEGACY NOTE (2026-04-05):** Ce document utilise "chiffre choc" comme legacy term technique.
> Concept canonique : **"premier éclairage"** (voir `docs/MINT_IDENTITY.md`). Migration code à planifier.
>
> **Légende statut** :
> - **KEEP** = reste tel quel, accessible via Explorer ou route directe
> - **MOVE** = change de place dans la navigation (ex: de tab à drawer)
> - **MERGE** = fusionné dans un autre écran
> - **ARCHIVE** = supprimé de la navigation, code conservé (peut revenir)
> - **NEW** = nouvel écran à créer
> - **REDIRECT** = route de compatibilité (pas un vrai écran)

---

## 1. SYNTHÈSE — 108 routes actives triées

| Statut | Nombre | Exemples |
|--------|--------|----------|
| **KEEP** | 72 | Tous les simulateurs, hubs, life events |
| **MOVE** | 12 | Profile, documents, achievements → drawer |
| **MERGE** | 8 | Confidence + ScoreReveal → MintHome, etc. |
| **ARCHIVE** | 9 | AskMint, Tools, CoachCockpit, BankImportV1, etc. |
| **NEW** | 3 | MintHomeScreen, PromiseScreen, ProfileDrawer |
| **REDIRECT** | 34 | Legacy redirects (inchangés) |
| **TOTAL** | **138** | |

---

## 2. ARCHITECTURE CIBLE — Où vit chaque écran

```
┌─────────────────────────────────────────────────────────────────┐
│  TAB 0 — MINT HOME (NEW)                                       │
│  Chiffre vivant + Itinéraire alternatif + Signal + Radar +     │
│  Coach input bar                                                │
│                                                                 │
│  Intègre les données de :                                       │
│  - PulseScreen (MERGE → MintHome absorbe son contenu)           │
│  - ConfidenceDashboardScreen (MERGE → barre de confiance)       │
│  - ScoreRevealScreen (MERGE → animation reveal dans MintHome)   │
│  - WeeklyRecapScreen (MERGE → signal hebdo si pertinent)        │
│  - CantonalBenchmarkScreen (MOVE → Explorer/Fiscalité)          │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  TAB 1 — COACH (KEEP : CoachChatScreen, isEmbeddedInTab)       │
│  Full conversation, IndexedStack preserved                      │
│  Reçoit CoachEntryPayload depuis : MintHome, simulateurs,       │
│  bottom sheet, notifications                                    │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  TAB 2 — EXPLORER (KEEP : ExploreTab, refactored)              │
│  Search bar + Parcours adaptatif + 7 hubs + Événements de vie  │
│  Tous les simulateurs accessibles via les hubs                  │
│                                                                 │
├─────────────────────────────────────────────────────────────────┤
│  DRAWER — PROFIL/DOSSIER (NEW : ProfileDrawer)                  │
│  Mon profil + Mon plan + Couple + Documents + Paramètres        │
│  Absorbe : DossierTab, ProfileScreen, DocumentsScreen,          │
│  AchievementsScreen, TimelineScreen, PortfolioScreen            │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. CARTE DÉTAILLÉE — CHAQUE ÉCRAN

### 3.1 Landing & Auth (5 écrans)

| Route | Écran | Statut | Détail |
|-------|-------|--------|--------|
| `/` | LandingScreen | **KEEP** (refactored) | Devient l'Onboarding Hinge : 3 prompts plein-écran au lieu d'un formulaire. Stocke via OnboardingProvider. |
| `/auth/login` | LoginScreen | **KEEP** | Inchangé. |
| `/auth/register` | RegisterScreen | **KEEP** (modified) | Ne demande PLUS âge/salaire/canton (déjà dans OnboardingProvider). Seuls champs : email + mot de passe (ou Apple/Google). |
| `/auth/forgot-password` | ForgotPasswordScreen | **KEEP** | Inchangé. |
| `/auth/verify-email` | VerifyEmailScreen | **KEEP** | Inchangé. |

### 3.2 Onboarding (5 écrans)

| Route | Écran | Statut | Détail |
|-------|-------|--------|--------|
| `/chiffre-choc-instant` | InstantChiffreChocScreen | **KEEP** (modified) | Lit OnboardingProvider au lieu de route extras. Appelle ChiffreChocSelector. Stocke émotion via OnboardingProvider. Post-émotion → `/onboarding/promise`. |
| `/onboarding/promise` | PromiseScreen | **NEW** | Texte adapté par LifecyclePhase. 2 boutons : Allons-y (register) / Juste les chiffres (mode libre). |
| `/onboarding/quick` | QuickStartScreen | **ARCHIVE** | Remplacé par l'Onboarding Hinge dans LandingScreen. Les données sont collectées via les 3 prompts du landing + enrichissement progressif via le coach. Route gardée pour compat mais redirige vers `/`. |
| `/onboarding/chiffre-choc` | ChiffreChocScreen | **ARCHIVE** | Unifié dans `/chiffre-choc-instant`. Redirection. |
| `/data-block/:type` | DataBlockEnrichmentScreen | **KEEP** | Enrichissement de données via le coach. Inchangé. |

### 3.3 Main Shell (1 écran)

| Route | Écran | Statut | Détail |
|-------|-------|--------|--------|
| `/home` | MainNavigationShell | **KEEP** (modified) | 4 tabs → 3 tabs + drawer. Tab 0: MintHomeScreen (NEW), Tab 1: CoachChatScreen (isEmbeddedInTab), Tab 2: ExploreTab. Drawer: ProfileDrawer (NEW). |

### 3.4 Tab Components (4 fichiers, pas de routes propres)

| Fichier | Statut | Détail |
|---------|--------|--------|
| `pulse_screen.dart` | **MERGE → MintHomeScreen** | Le contenu (hero number, cap card, signals) migre dans MintHomeScreen avec le nouveau design GPS/chiffre vivant. Le fichier est archivé. |
| `mint_coach_tab.dart` | **KEEP** | Reste le tab 1. Wrapper autour de CoachChatScreen(isEmbeddedInTab: true). |
| `explore_tab.dart` | **KEEP** (modified) | Ajout : search bar, section "Événements de vie". Lifecycle ordering déjà fait (W17). |
| `dossier_tab.dart` | **MERGE → ProfileDrawer** | Le contenu migre dans le drawer latéral. Le fichier est archivé. |

### 3.5 Explorer Hubs (7 écrans) — TOUS KEEP

| Route | Écran | Statut | Coach interaction |
|-------|-------|--------|-------------------|
| `/explore/retraite` | RetraiteHubScreen | **KEEP** | Content gating par LifecyclePhase (déjà fait W17). Liste 9+ outils retraite. |
| `/explore/famille` | FamilleHubScreen | **KEEP** | Événements : divorce, mariage, naissance, concubinage, décès. |
| `/explore/travail` | TravailHubScreen | **KEEP** | Premier emploi, chômage, expat, indépendants, comparaison jobs. |
| `/explore/logement` | LogementHubScreen | **KEEP** | Hypothèque, amortissement, EPL combiné, valeur locative, SARON vs fixe. |
| `/explore/fiscalite` | FiscaliteHubScreen | **KEEP** | 3a, 3a comparateur, 3a rendement, 3a échelonné, 3a rétroactif, fiscal. **+ CantonalBenchmark (MOVE ici)**. |
| `/explore/patrimoine` | PatrimoineHubScreen | **KEEP** | Succession, donation, vente immo, arbitrage bilan, allocation. Content gating (déjà fait W17). |
| `/explore/sante` | SanteHubScreen | **KEEP** | Invalidité, assurance invalidité, indép invalidité, LAMal, couverture. |

### 3.6 Retraite & Prévoyance (9 écrans)

| Route | Écran | Statut | Coach Bottom Sheet | CoachInterrupt |
|-------|-------|--------|-------------------|----------------|
| `/retraite` | RetirementDashboardScreen | **KEEP** | ✅ V2+ (payload: projections actuelles) | — |
| `/rente-vs-capital` | RenteVsCapitalScreen | **KEEP** | ✅ V1 (5 simulateurs prioritaires) | ✅ `100% capital && age > 60 → "0 rente garantie"` |
| `/rachat-lpp` | RachatEchelonneScreen | **KEEP** | ✅ V1 | ✅ `rachat > 0 && years_to_ret < 3 → "blocage EPL"` |
| `/epl` | EplScreen | **KEEP** | ✅ V2+ | — |
| `/decaissement` | OptimisationDecaissementScreen | **KEEP** | ✅ V2+ | — |
| `/succession` | SuccessionPatrimoineScreen | **KEEP** | ✅ V2+ | — |
| `/libre-passage` | LibrePassageScreen | **KEEP** | ✅ V2+ | — |

### 3.7 Fiscalité / Pilier 3a (6 écrans)

| Route | Écran | Statut | Coach Bottom Sheet | CoachInterrupt |
|-------|-------|--------|-------------------|----------------|
| `/pilier-3a` | Simulator3aScreen | **KEEP** | ✅ V1 | ✅ `annual < 7258 && annual > 0 → "tu laisses {delta} d'impôts"` |
| `/3a-deep/comparator` | ProviderComparatorScreen | **KEEP** | ✅ V2+ | — |
| `/3a-deep/real-return` | RealReturnScreen | **KEEP** | ✅ V2+ | — |
| `/3a-deep/staggered-withdrawal` | StaggeredWithdrawalScreen | **KEEP** | ✅ V2+ | — |
| `/3a-retroactif` | Retroactive3aScreen | **KEEP** | ✅ V2+ | — |
| `/fiscal` | FiscalComparatorScreen | **KEEP** | ✅ V2+ | — |

### 3.8 Logement & Hypothèque (5 écrans)

| Route | Écran | Statut | Coach Bottom Sheet | CoachInterrupt |
|-------|-------|--------|-------------------|----------------|
| `/hypotheque` | AffordabilityScreen | **KEEP** | ✅ V1 | ✅ `charges > 33% revenu → "banques refuseront"` |
| `/mortgage/amortization` | AmortizationScreen | **KEEP** | ✅ V2+ | — |
| `/mortgage/epl-combined` | EplCombinedScreen | **KEEP** | ✅ V2+ | — |
| `/mortgage/imputed-rental` | ImputedRentalScreen | **KEEP** | ✅ V2+ | — |
| `/mortgage/saron-vs-fixed` | SaronVsFixedScreen | **KEEP** | ✅ V2+ | — |

### 3.9 Budget & Dettes (5 écrans)

| Route | Écran | Statut | Coach Bottom Sheet | CoachInterrupt |
|-------|-------|--------|-------------------|----------------|
| `/budget` | BudgetContainerScreen | **KEEP** | ✅ V1 | ✅ `expenses > income → "déficit de {delta}/mois"` |
| `/check/debt` | DebtRiskCheckScreen | **KEEP** | ✅ V2+ | — |
| `/debt/ratio` | DebtRatioScreen | **KEEP** | ✅ V2+ | — |
| `/debt/help` | HelpResourcesScreen | **KEEP** | — | — |
| `/debt/repayment` | RepaymentScreen | **KEEP** | ✅ V2+ | — |

### 3.10 Famille / Life Events (8 écrans)

| Route | Écran | Statut | Coach Bottom Sheet |
|-------|-------|--------|-------------------|
| `/divorce` | DivorceSimulatorScreen | **KEEP** | ✅ V2+ |
| `/mariage` | MariageScreen | **KEEP** | ✅ V2+ |
| `/naissance` | NaissanceScreen | **KEEP** | ✅ V2+ |
| `/concubinage` | ConcubinageScreen | **KEEP** | ✅ V2+ |
| `/life-event/housing-sale` | HousingSaleScreen | **KEEP** | ✅ V2+ |
| `/life-event/donation` | DonationScreen | **KEEP** | ✅ V2+ |
| `/life-event/deces-proche` | DecesProcheScreen | **KEEP** | ✅ V2+ |
| `/life-event/demenagement-cantonal` | DemenagementCantonalScreen | **KEEP** | ✅ V2+ |

### 3.11 Emploi & Statut (4 écrans)

| Route | Écran | Statut |
|-------|-------|--------|
| `/unemployment` | UnemploymentScreen | **KEEP** |
| `/first-job` | FirstJobScreen | **KEEP** |
| `/expatriation` | ExpatScreen | **KEEP** |
| `/simulator/job-comparison` | JobComparisonScreen | **KEEP** |

### 3.12 Indépendants (6 écrans)

| Route | Écran | Statut |
|-------|-------|--------|
| `/segments/independant` | IndependantScreen | **KEEP** |
| `/independants/avs` | AvsCotisationsScreen | **KEEP** |
| `/independants/ijm` | IjmScreen | **KEEP** |
| `/independants/3a` | Pillar3aIndepScreen | **KEEP** |
| `/independants/dividende-salaire` | DividendeVsSalaireScreen | **KEEP** |
| `/independants/lpp-volontaire` | LppVolontaireScreen | **KEEP** |

### 3.13 Santé & Invalidité (5 écrans)

| Route | Écran | Statut |
|-------|-------|--------|
| `/invalidite` | DisabilityGapScreen | **KEEP** |
| `/disability/insurance` | DisabilityInsuranceScreen | **KEEP** |
| `/disability/self-employed` | DisabilitySelfEmployedScreen | **KEEP** |
| `/assurances/lamal` | LamalFranchiseScreen | **KEEP** |
| `/assurances/coverage` | CoverageCheckScreen | **KEEP** |

### 3.14 Documents & Scan (6 écrans)

| Route | Écran | Statut | Détail |
|-------|-------|--------|--------|
| `/scan` | DocumentScanScreen | **KEEP** | Inchangé. Lance Claude Vision. |
| `/scan/avs-guide` | AvsGuideScreen | **KEEP** | Guide pour scanner un extrait AVS. |
| `/scan/review` | ExtractionReviewScreen | **KEEP** | Vérification des données extraites. |
| `/scan/impact` | DocumentImpactScreen | **KEEP** (enrichi) | **Moment Shazam post-review** : affiche delta confiance + insight immédiat. |
| `/documents` | DocumentsScreen | **MOVE → Drawer** | Accessible depuis la section "Mes documents" du drawer. |
| `/documents/:id` | DocumentDetailScreen | **KEEP** | Détail d'un document. Accessible via push depuis le drawer. |

### 3.15 Couple (2 écrans)

| Route | Écran | Statut |
|-------|-------|--------|
| `/couple` | HouseholdScreen | **MOVE → Drawer** | Section "Couple" dans le drawer. |
| `/couple/accept` | AcceptInvitationScreen | **KEEP** | Deep link d'invitation. |

### 3.16 Profil & Paramètres (8 écrans)

| Route | Écran | Statut | Détail |
|-------|-------|--------|--------|
| `/profile` | ProfileScreen | **MOVE → Drawer** | Section "Mon profil" dans le drawer. |
| `/profile/consent` | ConsentDashboardScreen | **MOVE → Drawer** | Paramètres > Confidentialité. |
| `/profile/byok` | ByokSettingsScreen | **MOVE → Drawer** | Paramètres > Clé API. |
| `/profile/slm` | SlmSettingsScreen | **MOVE → Drawer** | Paramètres > Modèle local. |
| `/profile/bilan` | FinancialSummaryScreen | **MOVE → Drawer** | Section "Mon bilan" dans le drawer. |
| `/profile/data-transparency` | DataTransparencyScreen | **MOVE → Drawer** | Paramètres > Transparence. |
| `/profile/admin-observability` | AdminObservabilityScreen | **KEEP** (feature-gated) | Dev only. |
| `/profile/admin-analytics` | AdminAnalyticsScreen | **KEEP** (feature-gated) | Dev only. |

### 3.17 Rapport (1 écran)

| Route | Écran | Statut |
|-------|-------|--------|
| `/rapport` | FinancialReportScreenV2 | **KEEP** | Rapport financier complet. Accessible depuis le coach ("Génère mon rapport") ou depuis le drawer ("Mon bilan"). |

### 3.18 Segments & Éducation (4 écrans)

| Route | Écran | Statut | Détail |
|-------|-------|--------|--------|
| `/segments/gender-gap` | GenderGapScreen | **KEEP** | Accessible via Explorer > Travail. |
| `/segments/frontalier` | FrontalierScreen | **KEEP** | Accessible via Explorer > Travail. |
| `/education/hub` | ComprendreHubScreen | **MERGE → Explorer** | Le hub éducatif devient une section dans Explorer (pas un écran séparé). Les thèmes restent accessibles. |
| `/education/theme/:id` | ThemeDetailScreen | **KEEP** | Détail d'un thème éducatif. |

### 3.19 Simulateurs divers (3 écrans)

| Route | Écran | Statut |
|-------|-------|--------|
| `/simulator/compound` | SimulatorCompoundScreen | **KEEP** | Intérêts composés. Accessible via Explorer. |
| `/simulator/leasing` | SimulatorLeasingScreen | **KEEP** | Leasing. Accessible via Explorer > Logement. |
| `/simulator/credit` | ConsumerCreditSimulatorScreen | **KEEP** | Crédit conso. Accessible via Explorer. |

### 3.20 Arbitrage (3 écrans)

| Route | Écran | Statut |
|-------|-------|--------|
| `/arbitrage/bilan` | ArbitrageBilanScreen | **KEEP** | Via Explorer > Patrimoine. |
| `/arbitrage/allocation-annuelle` | AllocationAnnuelleScreen | **KEEP** | Via Explorer > Patrimoine. |
| `/arbitrage/location-vs-propriete` | LocationVsProprieteScreen | **KEEP** | Via Explorer > Logement. |

### 3.21 Coach (5 écrans)

| Route | Écran | Statut | Détail |
|-------|-------|--------|--------|
| `/coach/chat` | CoachChatScreen | **KEEP** | Tab 1 (embedded) + route push (depuis simulateurs). Accepte CoachEntryPayload en V2. |
| `/coach/history` | ConversationHistoryScreen | **MOVE → Drawer** | Accessible depuis le drawer > section Coach. |
| `/coach/cockpit` | CockpitDetailScreen | **ARCHIVE** | Données intégrées dans MintHome (chiffre vivant + itinéraire). |
| `/coach/checkin` | CoachCheckinScreen | **ARCHIVE** | Remplacé par le scan corporel mensuel (post-launch). |
| `/coach/refresh` | AnnualRefreshScreen | **ARCHIVE** | Remplacé par le Financial Wrapped (décembre). |

### 3.22 Outils divers (7 écrans)

| Route | Écran | Statut | Détail |
|-------|-------|--------|--------|
| `/achievements` | AchievementsScreen | **MOVE → Drawer** | Section "Mes accomplissements" dans le drawer (maturity >= 3). |
| `/weekly-recap` | WeeklyRecapScreen | **MERGE → MintHome** | Devient un signal proactif dans MintHome (via ProactiveTriggerService, trigger `weeklyRecapAvailable`). |
| `/cantonal-benchmark` | CantonalBenchmarkScreen | **MOVE → Explorer** | Accessible via Explorer > Fiscalité. |
| `/ask-mint` | AskMintScreen | **ARCHIVE** | Le coach EST "Ask MINT". Redirection vers `/home?tab=1`. |
| `/tools` | ToolsLibraryScreen | **ARCHIVE** | Les outils sont dans Explorer. Redirection vers `/home?tab=2`. |
| `/portfolio` | PortfolioScreen | **MOVE → Drawer** | Section "Mon patrimoine" dans le drawer. |
| `/timeline` | TimelineScreen | **MOVE → Drawer** | Section "Mon plan" dans le drawer. |

### 3.23 Confidence & Score (2 écrans)

| Route | Écran | Statut | Détail |
|-------|-------|--------|--------|
| `/confidence` | ConfidenceDashboardScreen | **MERGE → MintHome** | La barre de confiance est dans le Chiffre Vivant. Le dashboard détaillé accessible en tapant la barre. |
| `/score-reveal` | ScoreRevealScreen | **MERGE → MintHome** | L'animation de reveal intégrée dans la première ouverture de MintHome post-onboarding. |

### 3.24 Open Banking (5 écrans, feature-gated)

| Route | Écran | Statut |
|-------|-------|--------|
| `/open-banking` | OpenBankingHubScreen | **KEEP** (feature-gated, Phase 2+) |
| `/open-banking/transactions` | TransactionListScreen | **KEEP** (feature-gated) |
| `/open-banking/consents` | ConsentScreen | **KEEP** (feature-gated) |
| `/bank-import` | BankImportScreen | **ARCHIVE** | V1 remplacée par V2. |
| `/bank-import-v2` | BankImportV2Screen | **KEEP** | Seule version active. |

### 3.25 Institutionnel (3 écrans, feature-gated)

| Route | Écran | Statut |
|-------|-------|--------|
| `/expert-tier` | ExpertTierScreen | **KEEP** (feature-gated, Phase 3+) |
| `/b2b` | B2bHubScreen | **KEEP** (feature-gated, Phase 4+) |
| `/pension-fund-connect` | PensionFundConnectScreen | **KEEP** (feature-gated, Phase 4+) |

### 3.26 Smart Onboarding (8 fichiers, pas de routes directes)

| Fichier | Statut | Détail |
|---------|--------|--------|
| `smart_onboarding_screen.dart` | **ARCHIVE** | Redirigé vers `/onboarding/quick` (lui-même archivé). Le flow est remplacé par l'Onboarding Hinge. |
| `smart_onboarding_viewmodel.dart` | **ARCHIVE** | ViewModel du smart onboarding. |
| 7 fichiers `step_*.dart` | **ARCHIVE** | Sous-composants du smart onboarding. |

---

## 4. RÉSUMÉ DES CHANGEMENTS DE NAVIGATION

### 4.1 Routes archivées (9 routes → redirections)

```
/onboarding/quick           → REDIRECT → /
/onboarding/chiffre-choc    → REDIRECT → /chiffre-choc-instant
/coach/cockpit              → REDIRECT → /home?tab=0
/coach/checkin              → REDIRECT → /home?tab=1
/coach/refresh              → REDIRECT → /home?tab=0
/ask-mint                   → REDIRECT → /home?tab=1
/tools                      → REDIRECT → /home?tab=2
/bank-import                → REDIRECT → /bank-import-v2
/weekly-recap               → SUPPRIMÉ (signal dans MintHome)
```

### 4.2 Routes nouvelles (1 route)

```
/onboarding/promise         → PromiseScreen (NEW)
```

### 4.3 Routes inchangées (72 routes actives)

Tous les simulateurs, hubs, life events, famille, emploi, indépendants, santé, arbitrage, documents, rapport — **inchangés**. Ils restent accessibles via les mêmes routes, via Explorer et via le coach (tool call ROUTE_TO_SCREEN).

### 4.4 Routes déplacées dans le drawer (12 routes)

```
/profile                    → Drawer > Mon profil
/profile/consent            → Drawer > Paramètres > Confidentialité
/profile/byok               → Drawer > Paramètres > Clé API
/profile/slm                → Drawer > Paramètres > Modèle local
/profile/bilan              → Drawer > Mon bilan
/profile/data-transparency  → Drawer > Paramètres > Transparence
/documents                  → Drawer > Mes documents
/couple                     → Drawer > Couple
/coach/history              → Drawer > Historique coach
/achievements               → Drawer > Mes accomplissements
/portfolio                  → Drawer > Mon patrimoine
/timeline                   → Drawer > Mon plan
```

**Note importante** : ces routes RESTENT FONCTIONNELLES via GoRouter. Le drawer les ouvre via `context.push()`. Aucune route n'est supprimée du GoRouter — seul le point d'accès UI change (de tab 3 à drawer).

### 4.5 Écrans fusionnés (8 → disparaissent en tant que routes indépendantes)

```
PulseScreen                 → MintHomeScreen (contenu absorbé)
DossierTab                  → ProfileDrawer (contenu absorbé)
ConfidenceDashboardScreen   → MintHome (barre de confiance)
                              MAIS /confidence reste comme vue détaillée
ScoreRevealScreen           → MintHome (animation premier lancement)
                              MAIS /score-reveal reste pour le rapport
WeeklyRecapScreen           → Signal dans MintHome
ComprendreHubScreen         → Section dans Explorer
CantonalBenchmarkScreen     → Section dans Explorer > Fiscalité
```

---

## 5. COACH INTERACTION PAR ÉCRAN

### 5.1 Coach Bottom Sheet — V1 (5 simulateurs prioritaires)

Ces 5 écrans ont un FAB 💬 qui ouvre le coach bottom sheet avec un `CoachEntryPayload` contenant les valeurs courantes du simulateur :

| Écran | payload.topic | payload.data (clés principales) |
|-------|--------------|--------------------------------|
| Simulator3aScreen | `'pillar_3a'` | `{annual, maxAnnual, taxSaving, yearsRemaining}` |
| AffordabilityScreen | `'mortgage'` | `{purchasePrice, downPayment, rate, chargeRatio, income}` |
| RenteVsCapitalScreen | `'rente_vs_capital'` | `{renteMonthly, capitalTotal, mixed, age}` |
| RachatEchelonneScreen | `'rachat_lpp'` | `{buybackAmount, taxSaving, eplBlocked, yearsToRetirement}` |
| BudgetContainerScreen | `'budget'` | `{income, expenses, deficit, savingsRate}` |

### 5.2 Coach Interrupt — V1 (5 seuils)

| Écran | Condition | messageKey | Max dismiss |
|-------|-----------|------------|-------------|
| Simulator3aScreen | `annual < 7258 && annual > 0` | `coachInterrupt3aUnderMax` | 3 |
| AffordabilityScreen | `chargeRatio > 0.33` | `coachInterruptMortgageOverThird` | 3 |
| RenteVsCapitalScreen | `choice == 'capital' && age > 60` | `coachInterruptFullCapitalRisk` | 3 |
| RachatEchelonneScreen | `buyback > 0 && yearsToRet < 3` | `coachInterruptEplBlock` | 3 |
| BudgetContainerScreen | `expenses > income` | `coachInterruptBudgetDeficit` | 3 |

### 5.3 Coach Bottom Sheet — V2+ (tous les simulateurs)

Tous les autres simulateurs (30+) recevront le coach bottom sheet en V2+ via le pattern `CoachAwareSimulator`. La priorité V2 :

| Priorité | Écrans |
|----------|--------|
| V2a (haute) | RetirementDashboard, Decaissement, EPL, FiscalComparator, Divorce |
| V2b (moyenne) | Tous les mortgage/*, disability/*, independants/* |
| V2c (basse) | Simulateurs secondaires (compound, leasing, credit) |

### 5.4 Coach Tool Calls — routes accessibles

Le coach peut router vers n'importe quel écran KEEP ou MOVE via `ROUTE_TO_SCREEN`. Voici la liste exhaustive des routes valides pour ce tool call :

```dart
static const Set<String> _validCoachRoutes = {
  // Retraite
  '/retraite', '/rente-vs-capital', '/rachat-lpp', '/epl',
  '/decaissement', '/succession', '/libre-passage',
  // Fiscalité
  '/pilier-3a', '/3a-deep/comparator', '/3a-deep/real-return',
  '/3a-deep/staggered-withdrawal', '/3a-retroactif', '/fiscal',
  // Logement
  '/hypotheque', '/mortgage/amortization', '/mortgage/epl-combined',
  '/mortgage/imputed-rental', '/mortgage/saron-vs-fixed',
  // Budget
  '/budget', '/check/debt', '/debt/ratio', '/debt/help', '/debt/repayment',
  // Famille
  '/divorce', '/mariage', '/naissance', '/concubinage',
  // Life events
  '/life-event/housing-sale', '/life-event/donation',
  '/life-event/deces-proche', '/life-event/demenagement-cantonal',
  // Emploi
  '/unemployment', '/first-job', '/expatriation', '/simulator/job-comparison',
  // Indépendants
  '/segments/independant', '/independants/avs', '/independants/ijm',
  '/independants/3a', '/independants/dividende-salaire',
  '/independants/lpp-volontaire',
  // Santé
  '/invalidite', '/disability/insurance', '/disability/self-employed',
  '/assurances/lamal', '/assurances/coverage',
  // Documents
  '/scan', '/documents',
  // Arbitrage
  '/arbitrage/bilan', '/arbitrage/allocation-annuelle',
  '/arbitrage/location-vs-propriete',
  // Simulateurs
  '/simulator/compound', '/simulator/leasing', '/simulator/credit',
  // Segments
  '/segments/gender-gap', '/segments/frontalier',
  // Éducation
  '/education/hub',
  // Profil
  '/profile', '/profile/bilan', '/profile/byok',
  // Rapport
  '/rapport',
  // Couple
  '/couple',
  // Hubs Explorer
  '/explore/retraite', '/explore/famille', '/explore/travail',
  '/explore/logement', '/explore/fiscalite', '/explore/patrimoine',
  '/explore/sante',
};
```

---

## 6. FICHIER À SUPPRIMER

| Fichier | Raison |
|---------|--------|
| `instant_chiffre_choc_screen 2.dart` | Doublon avec espace dans le nom. Version ancienne. |

---

## 7. NETTOYAGE POST-IMPLÉMENTATION

Après que les 5 phases du Wire Spec V2 sont complètes :

1. **Vérifier que les 34 redirections (legacy + archive) fonctionnent**
2. **Vérifier que les 72 routes KEEP sont accessibles depuis Explorer**
3. **Vérifier que les 12 routes MOVE sont accessibles depuis le drawer**
4. **Vérifier que les 5 coach bottom sheets passent le bon payload**
5. **Vérifier que les 5 coach interrupts se déclenchent aux bons seuils**
6. **Vérifier que les 34 wire tests (W1-W34) passent**
7. **`flutter analyze` = 0 issues**
8. **`flutter test` = 0 failures**
