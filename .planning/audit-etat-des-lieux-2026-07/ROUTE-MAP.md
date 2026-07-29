---
description: "Carte de navigation complète de MINT (158 routes GoRouter, 126 fichiers écrans) : diagrammes Mermaid par flux, classification câblée/séquence-seulement/île, inventaire boutons-champs par écran, façades détectées. Verdict : 33/158 routes (21 %) ont un lien de navigation visible ; 108 ne sont atteignables que par navigation dynamique (ScreenRegistry/séquences) ; 17 sont des îles sans aucun chemin. Base du plan de taille (pruning) navigation."
---

# ROUTE-MAP — Cartographie navigation MINT (2026-07-23)

**TL;DR — le constat est sévère et chiffré : la navigation visible ne couvre que 21 % des routes.**

| Classe | Routes | % | Signification |
|---|---|---|---|
| 🟢 Câblée | 33 | 21 % | Un `context.go/push` littéral y mène depuis un écran ou widget |
| 🟡 Séquence-seulement | 108 | 68 % | Atteignable UNIQUEMENT via ScreenRegistry / SequenceCoordinator / coach `route_to_screen` — aucun bouton ni lien visible |
| 🔴 Île | 17 | 11 % | Aucun chemin détecté (ni littéral, ni registre) |

Autres signaux mécaniques : 61 arêtes de navigation littérales au total pour 158 routes ; flux Logement : 8 routes / **0 arête** ; Life events : 33 routes / 5 arêtes.

## Méthodologie (déterministe, zéro mémoire)
- Routes : parsing à pile d'imbrication de `apps/mobile/lib/app.dart` (158 GoRoute, chemins complets résolus parent+enfant).
- Arêtes : grep exhaustif `context.go/push/replace('...')` littéraux dans `lib/screens/**` + `lib/widgets/**`.
- Navigation dynamique : croisement avec les 142 entrées `ScreenRegistry` (`lib/services/navigation/screen_registry.dart`).
- Boutons/champs/nav par écran : extraction exhaustive des 126 fichiers par 4 agents — détail dans `routemap-parts/screens-{A,B,C,D}.md`.
- Limite honnête : 66 appels `context.go/push` NON-littéraux (variables) ne sont pas résolus arête-par-arête ; ils passent majoritairement par le registre (comptés en 🟡).

## Façades et orphelins détectés (extraction écran par écran)

| Écran | Défaut | Source |
|---|---|---|
| `AnonymousChatScreen` | Orphelin : route `/anonymous/chat` retirée, classe ne vit plus que dans les tests | screens-A |
| `DocumentStreamResultScreen` | Orphelin complet : 0 référence, helper `pushDocumentStreamResult` jamais appelé | screens-B |
| `ConfidenceDashboardScreen` | 3 cartes d'enrichissement `onTap: () {}` mort + TODO (`:349-351`) | screens-B |
| `OpenBankingHubScreen` | Bouton banque mort + données mock | screens-D |
| `ConsentScreen` (onboarding) | Mock sans persistance | screens-D |
| `TransactionListScreen` | Filtre période sans effet | screens-D |
| `Retroactive3aScreen` | 3 action cards sans `onTap` | screens-D |
| Strings FR hardcodées | `onboarding_shell_screen`, `libre_passage_screen`, `rachat_echelonne_screen` | screens-C |

## Les 17 îles (aucun chemin détecté)

- `/__e2e/budget-direct-inputs` → DebugBudgetBootstrapScreen
- `/__e2e/row23-independent-no-lpp-profile` → DebugMint2AccountClaimScreen
- `/admin/debug-spine` → AdminShell
- `/admin/routes` → AdminShell
- `/anonymous/chat` → ?
- `/auth/verify` → ?
- `/debug/chat-as-verb` → ChatAsVerbDemoScreen
- `/onboarding/enrichment` → ?
- `/onboarding/intent` → ?
- `/onboarding/minimal` → ?
- `/onboarding/plan` → ?
- `/onboarding/promise` → ?
- `/onboarding/quick` → ?
- `/onboarding/quick-start` → ?
- `/onboarding/smart` → ?
- `/rente-vs-capital` → ?
- `/simulator/rente-capital` → ?

Note : certaines îles sont voulues (admin/debug/e2e, deeplinks). Les candidates
sérieuses à trancher : les variantes d'onboarding non câblées et
`/simulator/rente-capital` vs `/retraite/rente-vs-capital` (doublon).

## Diagrammes par flux

Convention : nœud vert = présent dans ScreenRegistry (navigable dynamiquement) ;
nœud orange pointillé = source/cible hors table des routes (widget ou chemin
dynamique) ; flèches = navigation littérale UNIQUEMENT. Un flux pauvre en
flèches avec beaucoup de nœuds = écrans découvrables uniquement par séquence.

### Onboarding & entrée — 15 routes, 14 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/` | LandingScreen | 🟢 câblée |
| `/ask-mint` | ? | 🟢 câblée |
| `/onb` | OnboardingShellScreen | 🟢 câblée |
| `/onboarding/enrichment` | ? | 🔴 île |
| `/onboarding/intent` | ? | 🔴 île |
| `/onboarding/minimal` | ? | 🔴 île |
| `/onboarding/plan` | ? | 🔴 île |
| `/onboarding/premier-eclairage` | ? | 🟡 séquence-seulement |
| `/onboarding/promise` | ? | 🔴 île |
| `/onboarding/quick` | ? | 🔴 île |
| `/onboarding/quick-start` | ? | 🔴 île |
| `/onboarding/smart` | ? | 🔴 île |
| `/score-reveal` | ? | 🟡 séquence-seulement |
| `/start` | ? | 🟢 câblée |
| `/waitlist` | WaitlistProvider | 🟢 câblée |

```mermaid
flowchart LR
  R_["/<br/><i>LandingScreen</i>"]:::reg
  R_ask_mint["/ask-mint<br/><i>?</i>"]:::reg
  R_onb["/onb<br/><i>OnboardingShellScreen</i>"]:::reg
  R_onboarding_enrichment["/onboarding/enrichment<br/><i>?</i>"]
  R_onboarding_intent["/onboarding/intent<br/><i>?</i>"]
  R_onboarding_minimal["/onboarding/minimal<br/><i>?</i>"]
  R_onboarding_plan["/onboarding/plan<br/><i>?</i>"]
  R_onboarding_premier_eclairage["/onboarding/premier-eclairage<br/><i>?</i>"]:::reg
  R_onboarding_promise["/onboarding/promise<br/><i>?</i>"]
  R_onboarding_quick["/onboarding/quick<br/><i>?</i>"]
  R_onboarding_quick_start["/onboarding/quick-start<br/><i>?</i>"]
  R_onboarding_smart["/onboarding/smart<br/><i>?</i>"]
  R_score_reveal["/score-reveal<br/><i>?</i>"]:::reg
  R_start["/start<br/><i>?</i>"]
  R_waitlist["/waitlist<br/><i>WaitlistProvider</i>"]
  XAnonymousChatScreen(["AnonymousChatScreen"]):::ext
  XAnonymousChatScreen --> R_
  R_profile_byok --> R_ask_mint
  R_coach_chat --> R_waitlist
  R_profile_bilan --> R_onb
  R_ --> R_auth_login
  R_ --> R_start
  R_auth_login --> R_
  R_onb --> R_retraite_rente_vs_capital
  R_onb --> R_waitlist
  R_profile_privacy --> R_
  R_auth_register --> R_
  R_retraite --> R_onb
  Xwaitlist_success(["waitlist_success"]):::ext
  Xwaitlist_success --> R_
  X_widget__profile_drawer(["[widget] profile_drawer"]):::ext
  X_widget__profile_drawer --> R_
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### Auth & compte — 5 routes, 15 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/auth/forgot-password` | ForgotPasswordScreen | 🟢 câblée |
| `/auth/login` | LoginScreen | 🟢 câblée |
| `/auth/register` | RegisterScreen | 🟢 câblée |
| `/auth/verify` | ? | 🔴 île |
| `/auth/verify-email` | VerifyEmailScreen | 🟢 câblée |

```mermaid
flowchart LR
  R_auth_forgot_password["/auth/forgot-password<br/><i>ForgotPasswordScreen</i>"]:::reg
  R_auth_login["/auth/login<br/><i>LoginScreen</i>"]:::reg
  R_auth_register["/auth/register<br/><i>RegisterScreen</i>"]:::reg
  R_auth_verify["/auth/verify<br/><i>?</i>"]
  R_auth_verify_email["/auth/verify-email<br/><i>VerifyEmailScreen</i>"]:::reg
  R_coach_chat --> R_auth_login
  R_coach_chat --> R_auth_register
  R_scan --> R_auth_register
  R_auth_forgot_password --> R_auth_login
  R_couple --> R_auth_login
  R_ --> R_auth_login
  R_auth_login --> R_
  R_auth_login --> R_auth_forgot_password
  R_auth_login --> R_auth_register
  R_auth_login --> R_auth_verify_email
  R_auth_register --> R_
  R_auth_register --> R_about
  R_auth_register --> R_auth_login
  R_auth_verify_email --> R_auth_login
  X_widget__profile_drawer(["[widget] profile_drawer"]):::ext
  X_widget__profile_drawer --> R_auth_login
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### Coach & chat — 17 routes, 16 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/advisor` | ? | 🟡 séquence-seulement |
| `/advisor/plan-30-days` | ? | 🟡 séquence-seulement |
| `/advisor/wizard` | ? | 🟡 séquence-seulement |
| `/anonymous/chat` | ? | 🔴 île |
| `/arbitrage/rachat-vs-marche` | ? | 🟡 séquence-seulement |
| `/coach/agir` | ? | 🟡 séquence-seulement |
| `/coach/chat` | CoachChatScreen | 🟢 câblée |
| `/coach/checkin` | ? | 🟡 séquence-seulement |
| `/coach/cockpit` | ? | 🟡 séquence-seulement |
| `/coach/dashboard` | ? | 🟡 séquence-seulement |
| `/coach/decaissement` | ? | 🟡 séquence-seulement |
| `/coach/history` | ConversationHistoryScreen | 🟡 séquence-seulement |
| `/coach/refresh` | ? | 🟡 séquence-seulement |
| `/coach/succession` | ? | 🟡 séquence-seulement |
| `/debug/chat-as-verb` | ChatAsVerbDemoScreen | 🔴 île |
| `/lpp-deep/rachat` | ? | 🟡 séquence-seulement |
| `/rachat-lpp` | RachatEchelonneScreen | 🟡 séquence-seulement |

```mermaid
flowchart LR
  R_advisor["/advisor<br/><i>?</i>"]:::reg
  R_advisor_plan_30_days["/advisor/plan-30-days<br/><i>?</i>"]:::reg
  R_advisor_wizard["/advisor/wizard<br/><i>?</i>"]:::reg
  R_anonymous_chat["/anonymous/chat<br/><i>?</i>"]
  R_arbitrage_rachat_vs_marche["/arbitrage/rachat-vs-marche<br/><i>?</i>"]:::reg
  R_coach_agir["/coach/agir<br/><i>?</i>"]:::reg
  R_coach_chat["/coach/chat<br/><i>CoachChatScreen</i>"]:::reg
  R_coach_checkin["/coach/checkin<br/><i>?</i>"]:::reg
  R_coach_cockpit["/coach/cockpit<br/><i>?</i>"]:::reg
  R_coach_dashboard["/coach/dashboard<br/><i>?</i>"]:::reg
  R_coach_decaissement["/coach/decaissement<br/><i>?</i>"]:::reg
  R_coach_history["/coach/history<br/><i>ConversationHistoryScreen</i>"]:::reg
  R_coach_refresh["/coach/refresh<br/><i>?</i>"]:::reg
  R_coach_succession["/coach/succession<br/><i>?</i>"]:::reg
  R_debug_chat_as_verb["/debug/chat-as-verb<br/><i>ChatAsVerbDemoScreen</i>"]
  R_lpp_deep_rachat["/lpp-deep/rachat<br/><i>?</i>"]:::reg
  R_rachat_lpp["/rachat-lpp<br/><i>RachatEchelonneScreen</i>"]:::reg
  R_arbitrage_bilan --> R_coach_chat
  XAujourdhuiScreen(["AujourdhuiScreen"]):::ext
  XAujourdhuiScreen --> R_coach_chat
  XBudgetScreen(["BudgetScreen"]):::ext
  XBudgetScreen --> R_coach_chat
  R_cantonal_benchmark --> R_coach_chat
  R_coach_chat --> R_auth_login
  R_coach_chat --> R_auth_register
  R_coach_chat --> R_profile_byok
  R_coach_chat --> R_scan
  R_coach_chat --> R_waitlist
  R_coach_history --> R_coach_chat
  XDocumentImpactScreen(["DocumentImpactScreen"]):::ext
  XDocumentImpactScreen --> R_coach_chat
  R_3a_retroactif --> R_coach_chat
  R_3a_deep_staggered_withdrawal --> R_coach_chat
  Xfinancial_report_screen_v2(["financial_report_screen_v2"]):::ext
  Xfinancial_report_screen_v2 --> R_coach_chat
  X_widget__cap_du_jour_banner(["[widget] cap_du_jour_banner"]):::ext
  X_widget__cap_du_jour_banner --> R_coach_chat
  X_widget__commitments_and_checkins_card(["[widget] commitments_and_checkins_card"]):::ext
  X_widget__commitments_and_checkins_card --> R_coach_chat
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### Aujourd'hui, budget, argent & transactions — 11 routes, 19 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/arbitrage/bilan` | ArbitrageBilanScreen | 🟢 câblée |
| `/bank-import` | BankImportScreen | 🟢 câblée |
| `/budget` | BudgetContainerScreen | 🟢 câblée |
| `/budget/setup` | BudgetSetupScreen | 🟢 câblée |
| `/home` | Scaffold | 🟡 séquence-seulement |
| `/mon-argent` | MonArgentScreen | 🟢 câblée |
| `/open-banking` | OpenBankingHubScreen | 🟡 séquence-seulement |
| `/open-banking/consents` | ConsentScreen | 🟡 séquence-seulement |
| `/open-banking/transactions` | TransactionListScreen | 🟡 séquence-seulement |
| `/portfolio` | ? | 🟡 séquence-seulement |
| `/profile/bilan` | FinancialSummaryScreen | 🟢 câblée |

```mermaid
flowchart LR
  R_arbitrage_bilan["/arbitrage/bilan<br/><i>ArbitrageBilanScreen</i>"]:::reg
  R_bank_import["/bank-import<br/><i>BankImportScreen</i>"]:::reg
  R_budget["/budget<br/><i>BudgetContainerScreen</i>"]:::reg
  R_budget_setup["/budget/setup<br/><i>BudgetSetupScreen</i>"]:::reg
  R_home["/home<br/><i>Scaffold</i>"]:::reg
  R_mon_argent["/mon-argent<br/><i>MonArgentScreen</i>"]:::reg
  R_open_banking["/open-banking<br/><i>OpenBankingHubScreen</i>"]:::reg
  R_open_banking_consents["/open-banking/consents<br/><i>ConsentScreen</i>"]:::reg
  R_open_banking_transactions["/open-banking/transactions<br/><i>TransactionListScreen</i>"]:::reg
  R_portfolio["/portfolio<br/><i>?</i>"]:::reg
  R_profile_bilan["/profile/bilan<br/><i>FinancialSummaryScreen</i>"]:::reg
  R_arbitrage_bilan --> R_coach_chat
  R_budget --> R_budget_setup
  XBudgetScreen(["BudgetScreen"]):::ext
  XBudgetScreen --> R_profile_bilan
  X_coach_chat_topic_budget(["/coach/chat?topic=budget"]):::ext
  R_budget_setup --> X_coach_chat_topic_budget
  R_settings_confidentialite --> R_profile_bilan
  R_documents --> R_bank_import
  R_profile_bilan --> R_onb
  R_profile_bilan --> R_scan
  R_profile_bilan --> R_settings_confidentialite
  R_mon_argent --> R_budget
  R_mon_argent --> R_budget_setup
  R_mon_argent --> X_coach_chat_topic_budget
  R_mon_argent --> R_profile_bilan
  R_mon_argent --> R_scan
  R_retraite --> R_profile_bilan
  Xfinancial_report_screen_v2(["financial_report_screen_v2"]):::ext
  Xfinancial_report_screen_v2 --> R_mon_argent
  X_widget__arbitrage_teaser_card(["[widget] arbitrage_teaser_card"]):::ext
  X_widget__arbitrage_teaser_card --> R_arbitrage_bilan
  X_widget__coach_message_bubble(["[widget] coach_message_bubble"]):::ext
  X_widget__coach_message_bubble --> R_budget
  X_widget__widget_renderer(["[widget] widget_renderer"]):::ext
  X_widget__widget_renderer --> R_budget
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### Retraite, prévoyance & Rente-vs-Capital — 22 routes, 12 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/__e2e/row23-independent-no-lpp-profile` | DebugMint2AccountClaimScreen | 🔴 île |
| `/arbitrage/rente-vs-capital` | ? | 🟡 séquence-seulement |
| `/assurances/coverage` | CoverageCheckScreen | 🟡 séquence-seulement |
| `/assurances/lamal` | LamalFranchiseScreen | 🟡 séquence-seulement |
| `/decaissement` | OptimisationDecaissementScreen | 🟡 séquence-seulement |
| `/independants/lpp-volontaire` | LppVolontaireScreen | 🟡 séquence-seulement |
| `/invalidite` | DisabilityGapScreen | 🟡 séquence-seulement |
| `/libre-passage` | LibrePassageScreen | 🟡 séquence-seulement |
| `/lpp-deep/epl` | ? | 🟡 séquence-seulement |
| `/lpp-deep/libre-passage` | ? | 🟡 séquence-seulement |
| `/rente-vs-capital` | ? | 🔴 île |
| `/retirement` | ? | 🟡 séquence-seulement |
| `/retirement/projection` | ? | 🟡 séquence-seulement |
| `/retraite` | RetirementDashboardScreen | 🟢 câblée |
| `/retraite/rente-vs-capital` | RenteVsCapitalScreen | 🟢 câblée |
| `/simulator/3a` | ? | 🟡 séquence-seulement |
| `/simulator/compound` | SimulatorCompoundScreen | 🟡 séquence-seulement |
| `/simulator/credit` | ConsumerCreditSimulatorScreen | 🟡 séquence-seulement |
| `/simulator/disability-gap` | ? | 🟡 séquence-seulement |
| `/simulator/job-comparison` | JobComparisonScreen | 🟡 séquence-seulement |
| `/simulator/leasing` | SimulatorLeasingScreen | 🟡 séquence-seulement |
| `/simulator/rente-capital` | ? | 🔴 île |

```mermaid
flowchart LR
  R___e2e_row23_independent_no_lpp_profile["/__e2e/row23-independent-no-lpp-profile<br/><i>DebugMint2AccountClaimScreen</i>"]
  R_arbitrage_rente_vs_capital["/arbitrage/rente-vs-capital<br/><i>?</i>"]:::reg
  R_assurances_coverage["/assurances/coverage<br/><i>CoverageCheckScreen</i>"]:::reg
  R_assurances_lamal["/assurances/lamal<br/><i>LamalFranchiseScreen</i>"]:::reg
  R_decaissement["/decaissement<br/><i>OptimisationDecaissementScreen</i>"]:::reg
  R_independants_lpp_volontaire["/independants/lpp-volontaire<br/><i>LppVolontaireScreen</i>"]:::reg
  R_invalidite["/invalidite<br/><i>DisabilityGapScreen</i>"]:::reg
  R_libre_passage["/libre-passage<br/><i>LibrePassageScreen</i>"]:::reg
  R_lpp_deep_epl["/lpp-deep/epl<br/><i>?</i>"]:::reg
  R_lpp_deep_libre_passage["/lpp-deep/libre-passage<br/><i>?</i>"]:::reg
  R_rente_vs_capital["/rente-vs-capital<br/><i>?</i>"]
  R_retirement["/retirement<br/><i>?</i>"]:::reg
  R_retirement_projection["/retirement/projection<br/><i>?</i>"]:::reg
  R_retraite["/retraite<br/><i>RetirementDashboardScreen</i>"]:::reg
  R_retraite_rente_vs_capital["/retraite/rente-vs-capital<br/><i>RenteVsCapitalScreen</i>"]:::reg
  R_simulator_3a["/simulator/3a<br/><i>?</i>"]:::reg
  R_simulator_compound["/simulator/compound<br/><i>SimulatorCompoundScreen</i>"]:::reg
  R_simulator_credit["/simulator/credit<br/><i>ConsumerCreditSimulatorScreen</i>"]:::reg
  R_simulator_disability_gap["/simulator/disability-gap<br/><i>?</i>"]:::reg
  R_simulator_job_comparison["/simulator/job-comparison<br/><i>JobComparisonScreen</i>"]:::reg
  R_simulator_leasing["/simulator/leasing<br/><i>SimulatorLeasingScreen</i>"]:::reg
  R_simulator_rente_capital["/simulator/rente-capital<br/><i>?</i>"]
  R_onb --> R_retraite_rente_vs_capital
  R_retraite --> R_education_hub
  R_retraite --> R_onb
  R_retraite --> R_profile
  R_retraite --> R_profile_bilan
  R_retraite --> R_retraite
  X_widget__coach_message_bubble(["[widget] coach_message_bubble"]):::ext
  X_widget__coach_message_bubble --> R_retraite
  X_widget__coach_message_bubble --> R_retraite_rente_vs_capital
  X_widget__early_retirement_comparison(["[widget] early_retirement_comparison"]):::ext
  X_widget__early_retirement_comparison --> R_retraite
  X_widget__smart_shortcuts(["[widget] smart_shortcuts"]):::ext
  X_widget__smart_shortcuts --> R_retraite
  X_widget__trajectory_card(["[widget] trajectory_card"]):::ext
  X_widget__trajectory_card --> R_retraite
  X_widget__widget_renderer(["[widget] widget_renderer"]):::ext
  X_widget__widget_renderer --> R_retraite
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### 3e pilier & arbitrages — 13 routes, 4 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/3a-deep/comparator` | ProviderComparatorScreen | 🟡 séquence-seulement |
| `/3a-deep/real-return` | RealReturnScreen | 🟡 séquence-seulement |
| `/3a-deep/staggered-withdrawal` | StaggeredWithdrawalScreen | 🟡 séquence-seulement |
| `/3a-retroactif` | Retroactive3aScreen | 🟡 séquence-seulement |
| `/arbitrage/allocation-annuelle` | AllocationAnnuelleScreen | 🟡 séquence-seulement |
| `/arbitrage/calendrier-retraits` | ? | 🟡 séquence-seulement |
| `/arbitrage/location-vs-propriete` | LocationVsProprieteScreen | 🟡 séquence-seulement |
| `/independants/3a` | Pillar3aIndepScreen | 🟡 séquence-seulement |
| `/independants/avs` | AvsCotisationsScreen | 🟡 séquence-seulement |
| `/independants/dividende-salaire` | DividendeVsSalaireScreen | 🟡 séquence-seulement |
| `/independants/ijm` | IjmScreen | 🟡 séquence-seulement |
| `/pilier-3a` | Simulator3aScreen | 🟢 câblée |
| `/segments/independant` | IndependantScreen | 🟡 séquence-seulement |

```mermaid
flowchart LR
  R_3a_deep_comparator["/3a-deep/comparator<br/><i>ProviderComparatorScreen</i>"]:::reg
  R_3a_deep_real_return["/3a-deep/real-return<br/><i>RealReturnScreen</i>"]:::reg
  R_3a_deep_staggered_withdrawal["/3a-deep/staggered-withdrawal<br/><i>StaggeredWithdrawalScreen</i>"]:::reg
  R_3a_retroactif["/3a-retroactif<br/><i>Retroactive3aScreen</i>"]:::reg
  R_arbitrage_allocation_annuelle["/arbitrage/allocation-annuelle<br/><i>AllocationAnnuelleScreen</i>"]:::reg
  R_arbitrage_calendrier_retraits["/arbitrage/calendrier-retraits<br/><i>?</i>"]:::reg
  R_arbitrage_location_vs_propriete["/arbitrage/location-vs-propriete<br/><i>LocationVsProprieteScreen</i>"]:::reg
  R_independants_3a["/independants/3a<br/><i>Pillar3aIndepScreen</i>"]:::reg
  R_independants_avs["/independants/avs<br/><i>AvsCotisationsScreen</i>"]:::reg
  R_independants_dividende_salaire["/independants/dividende-salaire<br/><i>DividendeVsSalaireScreen</i>"]:::reg
  R_independants_ijm["/independants/ijm<br/><i>IjmScreen</i>"]:::reg
  R_pilier_3a["/pilier-3a<br/><i>Simulator3aScreen</i>"]:::reg
  R_segments_independant["/segments/independant<br/><i>IndependantScreen</i>"]:::reg
  R_3a_retroactif --> R_coach_chat
  X_coach_intent_fatca_3a_alternatives(["/coach?intent=fatca_3a_alternatives"]):::ext
  R_pilier_3a --> X_coach_intent_fatca_3a_alternatives
  R_3a_deep_staggered_withdrawal --> R_coach_chat
  X_widget__coach_message_bubble(["[widget] coach_message_bubble"]):::ext
  X_widget__coach_message_bubble --> R_pilier_3a
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### Logement & hypothèque — 8 routes, 0 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/epl` | EplScreen | 🟡 séquence-seulement |
| `/hypotheque` | AffordabilityScreen | 🟡 séquence-seulement |
| `/life-event/housing-sale` | HousingSaleScreen | 🟡 séquence-seulement |
| `/mortgage/affordability` | ? | 🟡 séquence-seulement |
| `/mortgage/amortization` | AmortizationScreen | 🟡 séquence-seulement |
| `/mortgage/epl-combined` | EplCombinedScreen | 🟡 séquence-seulement |
| `/mortgage/imputed-rental` | ImputedRentalScreen | 🟡 séquence-seulement |
| `/mortgage/saron-vs-fixed` | SaronVsFixedScreen | 🟡 séquence-seulement |

```mermaid
flowchart LR
  R_epl["/epl<br/><i>EplScreen</i>"]:::reg
  R_hypotheque["/hypotheque<br/><i>AffordabilityScreen</i>"]:::reg
  R_life_event_housing_sale["/life-event/housing-sale<br/><i>HousingSaleScreen</i>"]:::reg
  R_mortgage_affordability["/mortgage/affordability<br/><i>?</i>"]:::reg
  R_mortgage_amortization["/mortgage/amortization<br/><i>AmortizationScreen</i>"]:::reg
  R_mortgage_epl_combined["/mortgage/epl-combined<br/><i>EplCombinedScreen</i>"]:::reg
  R_mortgage_imputed_rental["/mortgage/imputed-rental<br/><i>ImputedRentalScreen</i>"]:::reg
  R_mortgage_saron_vs_fixed["/mortgage/saron-vs-fixed<br/><i>SaronVsFixedScreen</i>"]:::reg
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### Documents & scan — 8 routes, 14 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/document-scan` | ? | 🟡 séquence-seulement |
| `/document-scan/avs-guide` | ? | 🟡 séquence-seulement |
| `/documents` | DocumentsScreen | 🟢 câblée |
| `/documents/:id` | DocumentDetailScreen | 🟡 séquence-seulement |
| `/scan` | DocumentScanScreen | 🟢 câblée |
| `/scan/avs-guide` | AvsGuideScreen | 🟡 séquence-seulement |
| `/scan/impact` | Scaffold | 🟢 câblée |
| `/scan/review` | Scaffold | 🟢 câblée |

```mermaid
flowchart LR
  R_document_scan["/document-scan<br/><i>?</i>"]:::reg
  R_document_scan_avs_guide["/document-scan/avs-guide<br/><i>?</i>"]:::reg
  R_documents["/documents<br/><i>DocumentsScreen</i>"]:::reg
  R_documents__id["/documents/:id<br/><i>DocumentDetailScreen</i>"]:::reg
  R_scan["/scan<br/><i>DocumentScanScreen</i>"]:::reg
  R_scan_avs_guide["/scan/avs-guide<br/><i>AvsGuideScreen</i>"]:::reg
  R_scan_impact["/scan/impact<br/><i>Scaffold</i>"]:::reg
  R_scan_review["/scan/review<br/><i>Scaffold</i>"]:::reg
  R_scan_avs_guide --> R_scan
  R_scan_avs_guide --> R_scan_review
  R_coach_chat --> R_scan
  R_scan --> R_auth_register
  R_scan --> R_scan_review
  R_documents --> R_bank_import
  XExtractionReviewScreen(["ExtractionReviewScreen"]):::ext
  XExtractionReviewScreen --> R_scan_impact
  R_profile_bilan --> R_scan
  R_mon_argent --> R_scan
  X_widget__cap_du_jour_banner(["[widget] cap_du_jour_banner"]):::ext
  X_widget__cap_du_jour_banner --> R_scan
  X_widget__data_quality_card(["[widget] data_quality_card"]):::ext
  X_widget__data_quality_card --> R_scan
  X_widget__document_scan_cta(["[widget] document_scan_cta"]):::ext
  X_widget__document_scan_cta --> R_scan
  X_widget__hero_retirement_card(["[widget] hero_retirement_card"]):::ext
  X_widget__hero_retirement_card --> R_scan
  X_widget__widget_renderer(["[widget] widget_renderer"]):::ext
  X_widget__widget_renderer --> R_documents
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### Profil, privacy, couple & consentements — 13 routes, 10 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/couple` | HouseholdScreen | 🟢 câblée |
| `/couple/accept` | AcceptInvitationScreen | 🟡 séquence-seulement |
| `/household` | ? | 🟡 séquence-seulement |
| `/household/accept` | ? | 🟢 câblée |
| `/profile` | <redirect → /profile/bilan> | 🟢 câblée |
| `/profile/admin-analytics` | AdminAnalyticsScreen | 🟡 séquence-seulement |
| `/profile/admin-observability` | AdminObservabilityScreen | 🟡 séquence-seulement |
| `/profile/byok` | ByokSettingsScreen | 🟢 câblée |
| `/profile/privacy` | PrivacyCenterScreen | 🟢 câblée |
| `/profile/privacy-control` | PrivacyControlScreen | 🟡 séquence-seulement |
| `/profile/slm` | SlmSettingsScreen | 🟡 séquence-seulement |
| `/settings/confidentialite` | ConfidentialiteSettingsScreen | 🟢 câblée |
| `/settings/langue` | LangueSettingsScreen | 🟡 séquence-seulement |

```mermaid
flowchart LR
  R_couple["/couple<br/><i>HouseholdScreen</i>"]:::reg
  R_couple_accept["/couple/accept<br/><i>AcceptInvitationScreen</i>"]:::reg
  R_household["/household<br/><i>?</i>"]:::reg
  R_household_accept["/household/accept<br/><i>?</i>"]:::reg
  R_profile["/profile<br/><i>redirect → /profile/bilan</i>"]:::reg
  R_profile_admin_analytics["/profile/admin-analytics<br/><i>AdminAnalyticsScreen</i>"]:::reg
  R_profile_admin_observability["/profile/admin-observability<br/><i>AdminObservabilityScreen</i>"]:::reg
  R_profile_byok["/profile/byok<br/><i>ByokSettingsScreen</i>"]:::reg
  R_profile_privacy["/profile/privacy<br/><i>PrivacyCenterScreen</i>"]
  R_profile_privacy_control["/profile/privacy-control<br/><i>PrivacyControlScreen</i>"]:::reg
  R_profile_slm["/profile/slm<br/><i>SlmSettingsScreen</i>"]:::reg
  R_settings_confidentialite["/settings/confidentialite<br/><i>ConfidentialiteSettingsScreen</i>"]:::reg
  R_settings_langue["/settings/langue<br/><i>LangueSettingsScreen</i>"]:::reg
  R_couple_accept --> R_couple
  R_profile_byok --> R_ask_mint
  R_coach_chat --> R_profile_byok
  R_settings_confidentialite --> R_profile_bilan
  R_profile_bilan --> R_settings_confidentialite
  R_couple --> R_auth_login
  R_couple --> R_household_accept
  R_profile_privacy --> R_
  R_profile_privacy_control --> R_profile_privacy
  R_retraite --> R_profile
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### Rapports & insights — 7 routes, 1 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/about` | AboutScreen | 🟢 câblée |
| `/achievements` | ? | 🟡 séquence-seulement |
| `/confidence` | ConfidenceDashboardScreen | 🟡 séquence-seulement |
| `/data-block/:type` | DataBlockEnrichmentScreen | 🟡 séquence-seulement |
| `/rapport` | FinancialReportScreenV2 | 🟡 séquence-seulement |
| `/report` | ? | 🟡 séquence-seulement |
| `/report/v2` | ? | 🟡 séquence-seulement |

```mermaid
flowchart LR
  R_about["/about<br/><i>AboutScreen</i>"]
  R_achievements["/achievements<br/><i>?</i>"]:::reg
  R_confidence["/confidence<br/><i>ConfidenceDashboardScreen</i>"]:::reg
  R_data_block__type["/data-block/:type<br/><i>DataBlockEnrichmentScreen</i>"]:::reg
  R_rapport["/rapport<br/><i>FinancialReportScreenV2</i>"]:::reg
  R_report["/report<br/><i>?</i>"]:::reg
  R_report_v2["/report/v2<br/><i>?</i>"]:::reg
  R_auth_register --> R_about
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### Life events & fiscal — 33 routes, 5 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/cantonal-benchmark` | CantonalBenchmarkScreen | 🟡 séquence-seulement |
| `/check/debt` | DebtRiskCheckScreen | 🟡 séquence-seulement |
| `/concubinage` | ConcubinageScreen | 🟡 séquence-seulement |
| `/debt/help` | HelpResourcesScreen | 🟡 séquence-seulement |
| `/debt/ratio` | DebtRatioScreen | 🟡 séquence-seulement |
| `/debt/repayment` | RepaymentScreen | 🟢 câblée |
| `/disability/gap` | ? | 🟡 séquence-seulement |
| `/disability/insurance` | DisabilityInsuranceScreen | 🟡 séquence-seulement |
| `/disability/self-employed` | DisabilitySelfEmployedScreen | 🟡 séquence-seulement |
| `/divorce` | DivorceSimulatorScreen | 🟡 séquence-seulement |
| `/education/hub` | ComprendreHubScreen | 🟢 câblée |
| `/education/theme/:id` | ThemeDetailScreen | 🟡 séquence-seulement |
| `/expatriation` | ExpatScreen | 🟡 séquence-seulement |
| `/explore` | ExplorerScreen | 🟡 séquence-seulement |
| `/explore/famille` | ExploreHubScreen | 🟡 séquence-seulement |
| `/explore/fiscalite` | ExploreHubScreen | 🟡 séquence-seulement |
| `/explore/logement` | ExploreHubScreen | 🟡 séquence-seulement |
| `/explore/patrimoine` | ExploreHubScreen | 🟡 séquence-seulement |
| `/explore/retraite` | ExploreHubScreen | 🟡 séquence-seulement |
| `/explore/sante` | ExploreHubScreen | 🟡 séquence-seulement |
| `/explore/travail` | ExploreHubScreen | 🟡 séquence-seulement |
| `/first-job` | FirstJobScreen | 🟡 séquence-seulement |
| `/fiscal` | FiscalComparatorScreen | 🟢 câblée |
| `/life-event/deces-proche` | DecesProcheScreen | 🟡 séquence-seulement |
| `/life-event/demenagement-cantonal` | DemenagementCantonalScreen | 🟡 séquence-seulement |
| `/life-event/divorce` | ? | 🟡 séquence-seulement |
| `/life-event/donation` | DonationScreen | 🟡 séquence-seulement |
| `/life-event/succession` | ? | 🟡 séquence-seulement |
| `/mariage` | MariageScreen | 🟡 séquence-seulement |
| `/naissance` | NaissanceScreen | 🟡 séquence-seulement |
| `/segments/frontalier` | FrontalierScreen | 🟡 séquence-seulement |
| `/segments/gender-gap` | GenderGapScreen | 🟡 séquence-seulement |
| `/succession` | SuccessionPatrimoineScreen | 🟡 séquence-seulement |

```mermaid
flowchart LR
  R_cantonal_benchmark["/cantonal-benchmark<br/><i>CantonalBenchmarkScreen</i>"]:::reg
  R_check_debt["/check/debt<br/><i>DebtRiskCheckScreen</i>"]:::reg
  R_concubinage["/concubinage<br/><i>ConcubinageScreen</i>"]:::reg
  R_debt_help["/debt/help<br/><i>HelpResourcesScreen</i>"]:::reg
  R_debt_ratio["/debt/ratio<br/><i>DebtRatioScreen</i>"]:::reg
  R_debt_repayment["/debt/repayment<br/><i>RepaymentScreen</i>"]:::reg
  R_disability_gap["/disability/gap<br/><i>?</i>"]:::reg
  R_disability_insurance["/disability/insurance<br/><i>DisabilityInsuranceScreen</i>"]:::reg
  R_disability_self_employed["/disability/self-employed<br/><i>DisabilitySelfEmployedScreen</i>"]:::reg
  R_divorce["/divorce<br/><i>DivorceSimulatorScreen</i>"]:::reg
  R_education_hub["/education/hub<br/><i>ComprendreHubScreen</i>"]:::reg
  R_education_theme__id["/education/theme/:id<br/><i>ThemeDetailScreen</i>"]:::reg
  R_expatriation["/expatriation<br/><i>ExpatScreen</i>"]:::reg
  R_explore["/explore<br/><i>ExplorerScreen</i>"]:::reg
  R_explore_famille["/explore/famille<br/><i>ExploreHubScreen</i>"]:::reg
  R_explore_fiscalite["/explore/fiscalite<br/><i>ExploreHubScreen</i>"]:::reg
  R_explore_logement["/explore/logement<br/><i>ExploreHubScreen</i>"]:::reg
  R_explore_patrimoine["/explore/patrimoine<br/><i>ExploreHubScreen</i>"]:::reg
  R_explore_retraite["/explore/retraite<br/><i>ExploreHubScreen</i>"]:::reg
  R_explore_sante["/explore/sante<br/><i>ExploreHubScreen</i>"]:::reg
  R_explore_travail["/explore/travail<br/><i>ExploreHubScreen</i>"]:::reg
  R_first_job["/first-job<br/><i>FirstJobScreen</i>"]:::reg
  R_fiscal["/fiscal<br/><i>FiscalComparatorScreen</i>"]:::reg
  R_life_event_deces_proche["/life-event/deces-proche<br/><i>DecesProcheScreen</i>"]:::reg
  R_life_event_demenagement_cantonal["/life-event/demenagement-cantonal<br/><i>DemenagementCantonalScreen</i>"]:::reg
  R_life_event_divorce["/life-event/divorce<br/><i>?</i>"]:::reg
  R_life_event_donation["/life-event/donation<br/><i>DonationScreen</i>"]:::reg
  R_life_event_succession["/life-event/succession<br/><i>?</i>"]:::reg
  R_mariage["/mariage<br/><i>MariageScreen</i>"]:::reg
  R_naissance["/naissance<br/><i>NaissanceScreen</i>"]:::reg
  R_segments_frontalier["/segments/frontalier<br/><i>FrontalierScreen</i>"]:::reg
  R_segments_gender_gap["/segments/gender-gap<br/><i>GenderGapScreen</i>"]:::reg
  R_succession["/succession<br/><i>SuccessionPatrimoineScreen</i>"]:::reg
  R_cantonal_benchmark --> R_coach_chat
  R_debt_ratio --> R_debt_repayment
  R_retraite --> R_education_hub
  X_widget__coach_message_bubble(["[widget] coach_message_bubble"]):::ext
  X_widget__coach_message_bubble --> R_education_hub
  X_widget__coach_message_bubble --> R_fiscal
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### Admin, debug & e2e — 3 routes, 0 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/__e2e/budget-direct-inputs` | DebugBudgetBootstrapScreen | 🔴 île |
| `/admin/debug-spine` | AdminShell | 🔴 île |
| `/admin/routes` | AdminShell | 🔴 île |

```mermaid
flowchart LR
  R___e2e_budget_direct_inputs["/__e2e/budget-direct-inputs<br/><i>DebugBudgetBootstrapScreen</i>"]
  R_admin_debug_spine["/admin/debug-spine<br/><i>AdminShell</i>"]
  R_admin_routes["/admin/routes<br/><i>AdminShell</i>"]
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

### Autres — 3 routes, 0 arêtes littérales

| Route | Écran | Classe |
|---|---|---|
| `/timeline` | TimelineScreen | 🟡 séquence-seulement |
| `/tools` | ? | 🟡 séquence-seulement |
| `/unemployment` | UnemploymentScreen | 🟡 séquence-seulement |

```mermaid
flowchart LR
  R_timeline["/timeline<br/><i>TimelineScreen</i>"]:::reg
  R_tools["/tools<br/><i>?</i>"]:::reg
  R_unemployment["/unemployment<br/><i>UnemploymentScreen</i>"]:::reg
  classDef reg fill:#e8f5e9,stroke:#2e7d32;
  classDef ext fill:#fff3e0,stroke:#ef6c00,stroke-dasharray:3;
```

## Suite décisionnelle (proposition)

1. **Plan de taille (pruning)** : chaque route 🔴 et chaque façade ci-dessus
   reçoit un verdict garder-et-câbler / supprimer. Décision produit — à
   trancher avec Julien, pas unilatéralement.
2. Les routes 🟡 ne sont pas « mortes » (séquences, coach `route_to_screen`)
   mais leur découvrabilité utilisateur est nulle : le redesign (bead -e05)
   doit définir la navigation visible cible (bottom nav / hubs par flux).
3. Détail boutons/champs par écran : `routemap-parts/screens-A.md` … `screens-D.md`.

Contre-arguments et manques : la carte ne couvre pas les deeplinks externes ni
les notifications push (chemins d'entrée alternatifs) ; les 66 navigations
non-littérales mériteraient une résolution statique fine ; l'analyse est
statique (pas de télémétrie d'usage réel pour pondérer quoi supprimer).
