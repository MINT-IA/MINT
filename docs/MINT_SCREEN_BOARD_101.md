# MINT Screen Board 113

> Statut: board de référence pour la migration UX des surfaces MINT
> Source: codebase actuel + `MINT_UX_GRAAL_MASTERPLAN.md`
> Usage: savoir quel template appliquer à chaque écran et dans quel ordre le migrer
> Périmètre: `113` surfaces actives (`108 *_screen.dart` + `1 *_screen_v2.dart` + `4` shell/tabs)
> Note: le label historique `101` reste un nom de chantier dans certains échanges, pas un décompte exact
> Source de vérité: oui, pour le mapping `surface -> template -> priorité`
> Ne couvre pas: logique métier détaillée, copy, navigation complète, contrats techniques
> Dernière synchronisation: 2026-03-25 (121 fichiers .dart dans screens/, 8 helpers exclus)

---

## 1. Légende

### Templates
- `HP` = Hero Plan
- `DC` = Decision Canvas
- `RF` = Roadmap Flow
- `QU` = Quiet Utility
- `HY` = Hybrid / Coach / shell

### Priorités
- `T1-T5` = déjà traités ou quasi traités dans S52
- `T6-A` = priorité haute du restant
- `T6-B` = migration standard
- `T6-C` = utilitaire / admin / dette faible urgence
- `T-future` = surface roadmap hors codebase actuel

### Score S52
- `10/10` = écran aligné avec le standard cible S52
- `8/10` = écran très avancé mais encore dépendant d'un composant partagé à refondre
- `—` = non audité ou non encore migré dans S52

### Behavior (orchestration chat-to-screen)

> Spec complète : `CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md` §3 et §9.

- `A` = Direct Answer — réponse inline dans le chat (widget, fait éducatif, comparaison rapide)
- `B` = Decision Canvas — ouvrir un écran de simulation/arbitrage depuis le chat
- `C` = Roadmap Flow — ouvrir un parcours de vie depuis le chat
- `D` = Capture / Utility — donnée manquante ou document, déclenché quand la readiness échoue pour B ou C
- `E` = Conversation pure — pas de surface, texte + éventuellement un fait éducatif
- `—` = Non routable depuis le chat (landing, auth, admin, shell tabs)

### Required Fields

Champs `CoachProfile` nécessaires pour ouvrir la surface sans readiness bloquante. Définis dans le `ScreenRegistry` (`lib/services/navigation/screen_registry.dart`). Un `—` signifie aucun prérequis.

### Preferred from chat

`oui` = le coach peut proposer l'ouverture de cette surface. `non` = navigation directe depuis Explorer uniquement.

### Règle

Si un écran ne rentre pas naturellement dans un template, c'est le template qui doit gagner.
On ne crée pas une 5e famille juste pour un cas particulier.

---

## 2. Master templates

### HP — Hero Plan
Écran centré sur:
- 1 chiffre
- 1 phrase
- 1 action

### DC — Decision Canvas
Écran centré sur:
- inputs compacts
- arbitrage
- résultat dominant

### RF — Roadmap Flow
Écran centré sur:
- impact
- étapes
- checklist
- prochaine action

### QU — Quiet Utility
Écran centré sur:
- gestion
- liste
- détail
- réglages

### HY — Hybrid
Coquille, shell, coach, containers, pages de transition.

### Correspondance templates ↔ behaviors d'orchestration

Les templates maîtres et les behaviors d'orchestration sont deux axes orthogonaux. Un `DC` peut être `B` (ouvert depuis le chat) ou non routable (`—`). Référence : `CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md` §9 pour la cartographie complète des 109 surfaces par behavior.

| Template | Behaviors les plus fréquents | Remarque |
|----------|------------------------------|----------|
| `HP` | `A`, `—` | Les Hero Plans répondent souvent inline ou ne sont pas ouverts depuis le chat |
| `DC` | `B` | Les Decision Canvas sont la cible principale du RoutePlanner |
| `RF` | `C` | Les Roadmap Flows sont déclenchés par événements de vie |
| `QU` | `D`, `—` | Capture / settings, ouverts quand la readiness échoue |
| `HY` | `—` | Shell et coach, non routables directement |

---

## 3. Board par écran

## 3.1 Shell, top-level, marketing

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Landing | `landing_screen.dart` | HY | T6-B | — | — | marketing / conversion |
| Main Navigation Shell | `main_navigation_shell.dart` | HY | T1-T5 | — | — | shell 4 tabs |
| Explore Tab | `main_tabs/explore_tab.dart` | HY | T1-T5 | — | — | hub launcher |
| Dossier Tab | `main_tabs/dossier_tab.dart` | HY | T1-T5 | — | — | dossier launcher |
| Mint Coach Tab | `main_tabs/mint_coach_tab.dart` | HY | T6-B | — | — | à aligner avec coach final |
| Budget Container | `budget/budget_container_screen.dart` | HY | T6-C | — | — | container technique |

## 3.2 Aujourd'hui, onboarding, hero

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Aujourd'hui / Pulse | `pulse/pulse_screen.dart` | HP | T1-T5 | 8/10 | A | réponse inline — score, cap du jour |
| Quick Start | `onboarding/quick_start_screen.dart` | RF | T1-T5 | 10/10 | — | onboarding, non routable depuis chat |
| Chiffre-Choc | `onboarding/chiffre_choc_screen.dart` | HP | T1-T5 | 10/10 | — | non routable depuis chat |
| Smart Onboarding | `onboarding/smart_onboarding_screen.dart` | RF | T6-B | — | — | 7-step value-first onboarding flow (Lot 2 + P8-2), non routable depuis chat |
| Data Block Enrichment | `onboarding/data_block_enrichment_screen.dart` | RF | T6-A | — | D | capture, déclenché par readiness bloquante |
| Score Reveal | `advisor/score_reveal_screen.dart` | HP | T6-A | — | — | non routable depuis chat |
| Financial Report V2 | `advisor/financial_report_screen_v2.dart` | HP | T6-B | — | — | synthèse premium, billing-gated, doit rester un `Hero Plan` et jamais devenir un dump de données |

## 3.3 Coach, mémoire, conversation

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Coach Chat | `coach/coach_chat_screen.dart` | HY | T1-T5 | 10/10 | E | conversation orchestrator — héberge les réponses A/E |
| Ask Mint | `ask_mint_screen.dart` | HY | T6-A | — | E | fusion à terme dans Coach |
| Conversation History | `coach/conversation_history_screen.dart` | QU | T6-B | — | D | utilitaire |
| Coach Check-in | `coach/coach_checkin_screen.dart` | RF | T6-B | — | D | mini-flow data, déclenché par coach |
| Annual Refresh | `coach/annual_refresh_screen.dart` | RF | T6-B | — | D | refresh annuel, déclenché par coach |
| Cockpit Detail | `coach/cockpit_detail_screen.dart` | HP | T6-B | — | A | réponse inline enrichie |
| Weekly Recap | `coach/weekly_recap_screen.dart` | HP | T6-B | — | B | intent: `weekly_recap` — ajouté S59, uses MintSurface+MintEntrance |

## 3.4 Retraite / prévoyance

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Retirement Dashboard | `coach/retirement_dashboard_screen.dart` | HP | T1-T5 | 10/10 | B | intent: `retirement_overview` |
| Rente vs Capital | `arbitrage/rente_vs_capital_screen.dart` | DC | T1-T5 | 10/10 | B | intent: `retirement_choice` |
| Rachat Échelonné | `lpp_deep/rachat_echelonne_screen.dart` | DC | T1-T5 | 10/10 | B | intent: `lpp_buyback` |
| Optimisation Décaissement | `coach/optimisation_decaissement_screen.dart` | DC | T1-T5 | 10/10 | B | intent: `withdrawal_optimization` |
| Succession Patrimoine | `coach/succession_patrimoine_screen.dart` | RF | T1-T5 | 10/10 | C | intent: `succession_planning` |
| Libre Passage | `lpp_deep/libre_passage_screen.dart` | DC | T6-A | — | B | intent: `free_passage` |
| EPL | `lpp_deep/epl_screen.dart` | DC | T6-A | — | B | intent: `epl_combined` |
| Simulator 3a | `simulator_3a_screen.dart` | DC | T1-T5 | 10/10 | B | intent: `simulator_3a` |
| Real Return | `pillar_3a_deep/real_return_screen.dart` | DC | T1-T5 | 10/10 | B | intent: `real_return` |
| Staggered Withdrawal | `pillar_3a_deep/staggered_withdrawal_screen.dart` | DC | T1-T5 | 10/10 | B | intent: `tax_optimization_3a` |
| Retroactive 3a | `pillar_3a_deep/retroactive_3a_screen.dart` | DC | T6-A | — | B | intent: `retroactive_3a` |
| Provider Comparator | `pillar_3a_deep/provider_comparator_screen.dart` | DC | T6-B | — | B | intent: `provider_comparator` |

## 3.5 Budget, dette, crédit

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Budget | `budget/budget_screen.dart` | HP/DC | T1-T5 | 10/10 | B | intent: `budget_overview` |
| Debt Ratio | `debt_prevention/debt_ratio_screen.dart` | DC | T6-A | — | B | intent: `debt_crisis` |
| Repayment | `debt_prevention/repayment_screen.dart` | DC | T6-A | — | B | intent: `debt_repayment` |
| Help Resources | `debt_prevention/help_resources_screen.dart` | QU | T6-B | — | D | ressources, déclenché en Safe Mode |
| Debt Risk Check | `debt_risk_check_screen.dart` | DC | T6-B | — | B | intent: `debt_risk` |
| Consumer Credit | `consumer_credit_screen.dart` | DC | T6-B | — | B | intent: `consumer_credit` |
| Leasing | `simulator_leasing_screen.dart` | DC | T6-B | — | B | intent: `simulator_leasing` |
| Compound Interest | `simulator_compound_screen.dart` | DC | T6-B | — | B | intent: `compound_interest` |

## 3.6 Fiscalité, arbitrage, allocation

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Fiscal Comparator | `fiscal_comparator_screen.dart` | DC | T1-T5 | 10/10 | B | intent: `cantonal_comparison` |
| Allocation Annuelle | `arbitrage/allocation_annuelle_screen.dart` | DC | T1-T5 | 10/10 | B | intent: `annual_allocation` |
| Arbitrage Bilan | `arbitrage/arbitrage_bilan_screen.dart` | DC | T6-B | — | B | intent: `arbitrage_bilan` |
| Location vs Propriété | `arbitrage/location_vs_propriete_screen.dart` | DC | T6-B | — | B | intent: `rent_vs_buy` |
| Cantonal Benchmark | `cantonal_benchmark_screen.dart` | DC | T6-B | — | B | intent: `cantonal_benchmark` |

## 3.7 Logement / hypothèque

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Affordability | `mortgage/affordability_screen.dart` | DC | T1-T5 | 10/10 | B | intent: `housing_purchase` |
| Amortization | `mortgage/amortization_screen.dart` | DC | T6-A | — | B | intent: `amortization` |
| EPL Combined | `mortgage/epl_combined_screen.dart` | DC | T6-A | — | B | intent: `epl_combined` |
| Imputed Rental | `mortgage/imputed_rental_screen.dart` | DC | T6-B | — | B | intent: `imputed_rental` |
| SARON vs Fixed | `mortgage/saron_vs_fixed_screen.dart` | DC | T6-B | — | B | intent: `saron_vs_fixed` |
| Housing Sale | `housing_sale_screen.dart` | RF | T6-B | — | C | intent: `housing_sale` |

## 3.8 Famille, couple, succession, life events

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Mariage | `mariage_screen.dart` | RF | T1-T5 | 10/10 | C | intent: `life_event_marriage` |
| Naissance | `naissance_screen.dart` | RF | T1-T5 | 10/10 | C | intent: `life_event_birth` |
| Divorce | `divorce_simulator_screen.dart` | RF | T1-T5 | 10/10 | C | intent: `life_event_divorce` |
| Déménagement Cantonal | `demenagement_cantonal_screen.dart` | RF | T1-T5 | 10/10 | C | intent: `canton_move` |
| Concubinage | `concubinage_screen.dart` | RF | T6-A | — | C | intent: `life_event_concubinage` |
| Donation | `donation_screen.dart` | RF | T6-B | — | C | intent: `donation` |
| Décès proche | `deces_proche_screen.dart` | RF | T6-B | — | C | intent: `death_of_relative` |
| Household | `household/household_screen.dart` | QU/RF | T6-B | — | D | utilitaire couple |
| Accept Invitation | `household/accept_invitation_screen.dart` | RF | T6-B | — | — | non routable depuis chat |

## 3.9 Travail, statut, emploi

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Unemployment | `unemployment_screen.dart` | RF | T1-T5 | 10/10 | C | intent: `life_event_unemployment` |
| First Job | `first_job_screen.dart` | RF | T1-T5 | 10/10 | C | intent: `life_event_first_job` |
| Expat | `expat_screen.dart` | RF | T1-T5 | 10/10 | C | intent: `expat` |
| Frontalier | `frontalier_screen.dart` | RF | T1-T5 | 10/10 | C | intent: `cross_border` |
| Job Comparison | `job_comparison_screen.dart` | DC | T1-T5 | 10/10 | B | intent: `job_comparison` |
| Indépendant | `independant_screen.dart` | RF | T1-T5 | 10/10 | C | intent: `self_employment` |
| Gender Gap | `gender_gap_screen.dart` | HP/RF | T1-T5 | 10/10 | B | intent: `gender_gap` |

## 3.10 Sous-écrans indépendant

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| AVS Cotisations | `independants/avs_cotisations_screen.dart` | DC | T6-B | — | B | intent: `avs_independent` |
| IJM | `independants/ijm_screen.dart` | DC | T6-B | — | B | intent: `ijm` |
| 3a indépendant | `independants/pillar_3a_indep_screen.dart` | DC | T6-B | — | B | intent: `3a_independent` |
| LPP volontaire | `independants/lpp_volontaire_screen.dart` | DC | T6-B | — | B | intent: `lpp_voluntary` |
| Dividende vs Salaire | `independants/dividende_vs_salaire_screen.dart` | DC | T6-B | — | B | intent: `dividende_vs_salaire` |

## 3.11 Santé, protection, assurance

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| LAMal Franchise | `lamal_franchise_screen.dart` | DC | T1-T5 | 10/10 | B | intent: `lamal_franchise` |
| Coverage Check | `coverage_check_screen.dart` | DC | T6-A | — | B | intent: `coverage_check` |
| Disability Gap | `disability/disability_gap_screen.dart` | RF | T6-A | — | B | intent: `disability_gap` |
| Disability Insurance | `disability/disability_insurance_screen.dart` | RF | T6-A | — | B | intent: `disability_insurance` |
| Disability Self Employed | `disability/disability_self_employed_screen.dart` | RF | T6-B | — | C | intent: `disability_self_employed` |

## 3.12 Documents, scan, import, confiance

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Documents | `documents_screen.dart` | QU | T1-T5 | 10/10 | D | intent: `documents` |
| Document Detail | `document_detail_screen.dart` | QU | T6-B | — | D | utilitaire |
| Document Scan | `document_scan/document_scan_screen.dart` | RF | T6-A | — | D | intent: `document_scan` — déclenché par readiness bloquante |
| AVS Guide | `document_scan/avs_guide_screen.dart` | RF | T6-B | — | D | guidance scan |
| Extraction Review | `document_scan/extraction_review_screen.dart` | RF | T6-B | — | D | validation |
| Document Impact | `document_scan/document_impact_screen.dart` | HP | T6-A | — | A | retour inline après scan |
| Confidence Dashboard | `confidence/confidence_dashboard_screen.dart` | QU | T6-B | — | D | précision / qualité |
| Bank Import | `bank_import_screen.dart` | QU/RF | T6-B | — | D | intent: `open_banking_hub` |

## 3.13 Open banking

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Open Banking Hub | `open_banking/open_banking_hub_screen.dart` | QU | T6-C | — | D | intent: `open_banking_hub` |
| Transaction List | `open_banking/transaction_list_screen.dart` | QU | T6-C | — | D | utilitaire |
| Consent Screen | `open_banking/consent_screen.dart` | QU | T6-C | — | D | intent: `consent` |

**Règle OB : narrative-first, evidence-available.**
Quand Open Banking devient actif, la couche primaire est l'insight narratif (le Cap, le levier, l'histoire).
Le tableau de transactions reste accessible comme couche de preuve, jamais comme surface d'entrée.

## 3.14 Dossier, profile, réglages

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Profile | `profile_screen.dart` | QU | T1-T5 | 10/10 | D | intent: `profile` |
| Financial Summary | `profile/financial_summary_screen.dart` | HP/QU | T6-B | — | D | aperçu dossier |
| Consent Dashboard | `consent_dashboard_screen.dart` | QU | T6-C | — | D | intent: `consent` |
| BYOK Settings | `byok_settings_screen.dart` | QU | T6-C | — | D | intent: `byok_settings` |
| SLM Settings | `slm_settings_screen.dart` | QU | T6-C | — | D | intent: `slm_settings` |

## 3.15 Education, content, hubs

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Comprendre Hub | `education/comprendre_hub_screen.dart` | QU | T6-B | — | E | réponse conversationnelle préférée |
| Theme Detail | `education/theme_detail_screen.dart` | QU | T6-B | — | E | réponse conversationnelle préférée |
| Tools Library | `tools_library_screen.dart` | QU | T6-C | — | — | à absorber dans Explore |
| Retraite Hub | `explore/retraite_hub_screen.dart` | QU | T1-T5 | 10/10 | — | Explorer autonome, non routable depuis chat |
| Famille Hub | `explore/famille_hub_screen.dart` | QU | T1-T5 | 10/10 | — | Explorer autonome |
| Travail Hub | `explore/travail_hub_screen.dart` | QU | T1-T5 | 10/10 | — | Explorer autonome |
| Logement Hub | `explore/logement_hub_screen.dart` | QU | T1-T5 | 10/10 | — | Explorer autonome |
| Fiscalité Hub | `explore/fiscalite_hub_screen.dart` | QU | T1-T5 | 10/10 | — | Explorer autonome |
| Patrimoine Hub | `explore/patrimoine_hub_screen.dart` | QU | T1-T5 | 10/10 | — | Explorer autonome |
| Santé Hub | `explore/sante_hub_screen.dart` | QU | T1-T5 | 10/10 | — | Explorer autonome |

## 3.16 Achievements, portfolio, time-based views

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Achievements | `achievements_screen.dart` | HP/QU | T1-T5 | 10/10 | — | non routable depuis chat |
| Timeline | `timeline_screen.dart` | QU | T6-C | — | — | non routable depuis chat |
| Portfolio | `portfolio_screen.dart` | QU | T6-C | — | — | non routable depuis chat |

## 3.17 Auth

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Login | `auth/login_screen.dart` | QU | T6-C | — | — | non routable depuis chat |
| Register | `auth/register_screen.dart` | QU | T6-C | — | — | non routable depuis chat |
| Forgot Password | `auth/forgot_password_screen.dart` | QU | T6-C | — | — | non routable depuis chat |
| Verify Email | `auth/verify_email_screen.dart` | QU | T6-C | — | — | non routable depuis chat |

## 3.18 Admin

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Admin Observability | `admin_observability_screen.dart` | QU | T6-C | — | — | non routable depuis chat |
| Admin Analytics | `admin_analytics_screen.dart` | QU | T6-C | — | — | non routable depuis chat |

## 3.19 Expert tier

| Écran | Fichier | Template | Priorité | Score S52 | Behavior | Notes |
|---|---|---:|---:|---:|---:|---|
| Expert Tier | `expert/expert_tier_screen.dart` | DC | T6-B | — | B | intent: `expert_tier` — 3 specialist types, dossier prep, Phase 3 feature |

---

## 4. Priorité de migration du restant

## T6-A — priorité haute

À migrer avant le long tail:
- `data_block_enrichment_screen`
- `score_reveal_screen`
- `libre_passage_screen`
- `epl_screen`
- `retroactive_3a_screen`
- `document_scan_screen`
- `document_impact_screen`
- `coverage_check_screen`
- `disability_gap_screen`
- `disability_insurance_screen`
- `amortization_screen`
- `epl_combined_screen`
- `concubinage_screen`
- `debt_ratio_screen`
- `repayment_screen`

## T6-B — migration standard

Tous les simulateurs, life events secondaires, éducation et détails document.

## T6-C — migration utilitaire

Settings, admin, open banking, portfolio, timeline, tools legacy.

---

## 5. Ce qu'il faut imposer à tous les écrans restants

### Visuel
- tokens MINT uniquement
- aucune wall of sliders
- un point focal unique
- carte et espace plus sobres

### Produit
- un écran doit déboucher sur une action ou une compréhension claire
- pas de section purement décorative

### Copy
- aucun texte visible hardcodé en FR
- semantics localisées
- CTA concrets

### Technique
- imports l10n cohérents
- aucun pattern legacy de composants dépréciés
- capture / feedback loop visible quand pertinent

---

## 6. Ordre recommandé après S52

1. Refondre `ResponseCardWidget`
2. Implémenter `CapEngine`
3. Migrer tous les `T6-A`
4. Nettoyer les fuites i18n des écrans déjà refondus
5. Migrer le long tail `T6-B`
6. Fermer les utilitaires `T6-C`
7. Screenshot board final des 113 surfaces actives
