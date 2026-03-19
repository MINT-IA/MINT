# MINT Screen Board 109

> Statut: board de référence pour la migration UX des surfaces MINT
> Source: codebase actuel + `MINT_UX_GRAAL_MASTERPLAN.md`
> Usage: savoir quel template appliquer à chaque écran et dans quel ordre le migrer
> Périmètre: `109` surfaces actives (`105 *_screen.dart` + `4` shell/tabs)
> Note: le label historique `101` reste un nom de chantier dans certains échanges, pas un décompte exact

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

---

## 3. Board par écran

## 3.1 Shell, top-level, marketing

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Landing | `landing_screen.dart` | HY | T6-B | — | marketing / conversion |
| Main Navigation Shell | `main_navigation_shell.dart` | HY | T1-T5 | — | shell 4 tabs |
| Explore Tab | `main_tabs/explore_tab.dart` | HY | T1-T5 | — | hub launcher |
| Dossier Tab | `main_tabs/dossier_tab.dart` | HY | T1-T5 | — | dossier launcher |
| Mint Coach Tab | `main_tabs/mint_coach_tab.dart` | HY | T6-B | — | à aligner avec coach final |
| Budget Container | `budget/budget_container_screen.dart` | HY | T6-C | — | container technique |

## 3.2 Aujourd'hui, onboarding, hero

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Aujourd'hui / Pulse | `pulse/pulse_screen.dart` | HP | T1-T5 | 8/10 | futur hero du `Cap du jour`, dépend encore de la refonte `ResponseCardWidget` |
| Quick Start | `onboarding/quick_start_screen.dart` | RF | T1-T5 | 10/10 | onboarding progressif |
| Chiffre-Choc | `onboarding/chiffre_choc_screen.dart` | HP | T1-T5 | 10/10 | hero d'impact |
| Data Block Enrichment | `onboarding/data_block_enrichment_screen.dart` | RF | T6-A | — | onboarding / enrichissement |
| Score Reveal | `advisor/score_reveal_screen.dart` | HP | T6-A | — | hero milestone / score |
| Financial Report V2 | `advisor/financial_report_screen_v2.dart` | HP | T6-B | — | synthèse premium, billing-gated, doit rester un `Hero Plan` et jamais devenir un dump de données |

## 3.3 Coach, mémoire, conversation

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Coach Chat | `coach/coach_chat_screen.dart` | HY | T1-T5 | 10/10 | conversation orchestrator |
| Ask Mint | `ask_mint_screen.dart` | HY | T6-A | — | fusion à terme dans Coach |
| Conversation History | `coach/conversation_history_screen.dart` | QU | T6-B | — | historique |
| Coach Check-in | `coach/coach_checkin_screen.dart` | RF | T6-B | — | mini-flow data |
| Annual Refresh | `coach/annual_refresh_screen.dart` | RF | T6-B | — | refresh annuel |
| Cockpit Detail | `coach/cockpit_detail_screen.dart` | HP | T6-B | — | détail hero |

## 3.4 Retraite / prévoyance

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Retirement Dashboard | `coach/retirement_dashboard_screen.dart` | HP | T1-T5 | 10/10 | traité |
| Rente vs Capital | `arbitrage/rente_vs_capital_screen.dart` | DC | T1-T5 | 10/10 | traité |
| Rachat Échelonné | `lpp_deep/rachat_echelonne_screen.dart` | DC | T1-T5 | 10/10 | traité |
| Optimisation Décaissement | `coach/optimisation_decaissement_screen.dart` | DC | T1-T5 | 10/10 | traité |
| Succession Patrimoine | `coach/succession_patrimoine_screen.dart` | RF | T1-T5 | 10/10 | traité |
| Libre Passage | `lpp_deep/libre_passage_screen.dart` | DC | T6-A | — | retraite / mobilité |
| EPL | `lpp_deep/epl_screen.dart` | DC | T6-A | — | logement / LPP |
| Simulator 3a | `simulator_3a_screen.dart` | DC | T1-T5 | 10/10 | traité |
| Real Return | `pillar_3a_deep/real_return_screen.dart` | DC | T1-T5 | 10/10 | traité |
| Staggered Withdrawal | `pillar_3a_deep/staggered_withdrawal_screen.dart` | DC | T1-T5 | 10/10 | traité |
| Retroactive 3a | `pillar_3a_deep/retroactive_3a_screen.dart` | DC | T6-A | — | fiscal + retraite |
| Provider Comparator | `pillar_3a_deep/provider_comparator_screen.dart` | DC | T6-B | — | comparatif |

## 3.5 Budget, dette, crédit

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Budget | `budget/budget_screen.dart` | HP/DC | T1-T5 | 10/10 | traité |
| Debt Ratio | `debt_prevention/debt_ratio_screen.dart` | DC | T6-A | — | mini-hub dette |
| Repayment | `debt_prevention/repayment_screen.dart` | DC | T6-A | — | mini-hub dette |
| Help Resources | `debt_prevention/help_resources_screen.dart` | QU | T6-B | — | dette / ressources |
| Debt Risk Check | `debt_risk_check_screen.dart` | DC | T6-B | — | dette / diagnostic |
| Consumer Credit | `consumer_credit_screen.dart` | DC | T6-B | — | crédit conso |
| Leasing | `simulator_leasing_screen.dart` | DC | T6-B | — | arbitrage leasing |
| Compound Interest | `simulator_compound_screen.dart` | DC | T6-B | — | simulateur épargne |

## 3.6 Fiscalité, arbitrage, allocation

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Fiscal Comparator | `fiscal_comparator_screen.dart` | DC | T1-T5 | 10/10 | traité |
| Allocation Annuelle | `arbitrage/allocation_annuelle_screen.dart` | DC | T1-T5 | 10/10 | traité |
| Arbitrage Bilan | `arbitrage/arbitrage_bilan_screen.dart` | DC | T6-B | — | synthèse arbitrage |
| Location vs Propriété | `arbitrage/location_vs_propriete_screen.dart` | DC | T6-B | — | logement / fiscal |
| Cantonal Benchmark | `cantonal_benchmark_screen.dart` | DC | T6-B | — | benchmark fiscal |

## 3.7 Logement / hypothèque

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Affordability | `mortgage/affordability_screen.dart` | DC | T1-T5 | 10/10 | traité |
| Amortization | `mortgage/amortization_screen.dart` | DC | T6-A | — | hypothèque |
| EPL Combined | `mortgage/epl_combined_screen.dart` | DC | T6-A | — | hypothèque + LPP |
| Imputed Rental | `mortgage/imputed_rental_screen.dart` | DC | T6-B | — | fiscal logement |
| SARON vs Fixed | `mortgage/saron_vs_fixed_screen.dart` | DC | T6-B | — | arbitrage taux |
| Housing Sale | `housing_sale_screen.dart` | RF | T6-B | — | vente / transition |

## 3.8 Famille, couple, succession, life events

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Mariage | `mariage_screen.dart` | RF | T1-T5 | 10/10 | traité |
| Naissance | `naissance_screen.dart` | RF | T1-T5 | 10/10 | traité |
| Divorce | `divorce_simulator_screen.dart` | RF | T1-T5 | 10/10 | traité |
| Déménagement Cantonal | `demenagement_cantonal_screen.dart` | RF | T1-T5 | 10/10 | traité |
| Concubinage | `concubinage_screen.dart` | RF | T6-A | — | couple |
| Donation | `donation_screen.dart` | RF | T6-B | — | patrimoine |
| Décès proche | `deces_proche_screen.dart` | RF | T6-B | — | moment sensible |
| Household | `household/household_screen.dart` | QU/RF | T6-B | — | couple / ménage |
| Accept Invitation | `household/accept_invitation_screen.dart` | RF | T6-B | — | flow d'entrée |

## 3.9 Travail, statut, emploi

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Unemployment | `unemployment_screen.dart` | RF | T1-T5 | 10/10 | traité |
| First Job | `first_job_screen.dart` | RF | T1-T5 | 10/10 | traité |
| Expat | `expat_screen.dart` | RF | T1-T5 | 10/10 | traité |
| Frontalier | `frontalier_screen.dart` | RF | T1-T5 | 10/10 | traité |
| Job Comparison | `job_comparison_screen.dart` | DC | T1-T5 | 10/10 | traité |
| Indépendant | `independant_screen.dart` | RF | T1-T5 | 10/10 | traité |
| Gender Gap | `gender_gap_screen.dart` | HP/RF | T1-T5 | 10/10 | traité |

## 3.10 Sous-écrans indépendant

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| AVS Cotisations | `independants/avs_cotisations_screen.dart` | DC | T6-B | — | sous-tool |
| IJM | `independants/ijm_screen.dart` | DC | T6-B | — | sous-tool |
| 3a indépendant | `independants/pillar_3a_indep_screen.dart` | DC | T6-B | — | sous-tool |
| LPP volontaire | `independants/lpp_volontaire_screen.dart` | DC | T6-B | — | sous-tool |
| Dividende vs Salaire | `independants/dividende_vs_salaire_screen.dart` | DC | T6-B | — | sous-tool |

## 3.11 Santé, protection, assurance

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| LAMal Franchise | `lamal_franchise_screen.dart` | DC | T1-T5 | 10/10 | traité |
| Coverage Check | `coverage_check_screen.dart` | DC | T6-A | — | protection |
| Disability Gap | `disability/disability_gap_screen.dart` | RF | T6-A | — | protection |
| Disability Insurance | `disability/disability_insurance_screen.dart` | RF | T6-A | — | protection |
| Disability Self Employed | `disability/disability_self_employed_screen.dart` | RF | T6-B | — | protection |

## 3.12 Documents, scan, import, confiance

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Documents | `documents_screen.dart` | QU | T1-T5 | 10/10 | traité |
| Document Detail | `document_detail_screen.dart` | QU | T6-B | — | détail |
| Document Scan | `document_scan/document_scan_screen.dart` | RF | T6-A | — | capture |
| AVS Guide | `document_scan/avs_guide_screen.dart` | RF | T6-B | — | guidance scan |
| Extraction Review | `document_scan/extraction_review_screen.dart` | RF | T6-B | — | validation |
| Document Impact | `document_scan/document_impact_screen.dart` | HP | T6-A | — | action success |
| Confidence Dashboard | `confidence/confidence_dashboard_screen.dart` | QU | T6-B | — | précision / qualité |
| Bank Import | `bank_import_screen.dart` | QU/RF | T6-B | — | import bancaire |

## 3.13 Open banking

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Open Banking Hub | `open_banking/open_banking_hub_screen.dart` | QU | T6-C | — | hub |
| Transaction List | `open_banking/transaction_list_screen.dart` | QU | T6-C | — | liste |
| Consent Screen | `open_banking/consent_screen.dart` | QU | T6-C | — | consentements |

**Règle OB : narrative-first, evidence-available.**
Quand Open Banking devient actif, la couche primaire est l'insight narratif (le Cap, le levier, l'histoire).
Le tableau de transactions reste accessible comme couche de preuve, jamais comme surface d'entrée.

## 3.14 Dossier, profile, réglages

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Profile | `profile_screen.dart` | QU | T1-T5 | 10/10 | traité |
| Financial Summary | `profile/financial_summary_screen.dart` | HP/QU | T6-B | — | aperçu dossier |
| Consent Dashboard | `consent_dashboard_screen.dart` | QU | T6-C | — | permissions |
| BYOK Settings | `byok_settings_screen.dart` | QU | T6-C | — | IA |
| SLM Settings | `slm_settings_screen.dart` | QU | T6-C | — | IA |

## 3.15 Education, content, hubs

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Comprendre Hub | `education/comprendre_hub_screen.dart` | QU | T6-B | — | hub éducatif |
| Theme Detail | `education/theme_detail_screen.dart` | QU | T6-B | — | détail de thème |
| Tools Library | `tools_library_screen.dart` | QU | T6-C | — | à absorber dans Explore |
| Retraite Hub | `explore/retraite_hub_screen.dart` | QU | T1-T5 | 10/10 | traité |
| Famille Hub | `explore/famille_hub_screen.dart` | QU | T1-T5 | 10/10 | traité |
| Travail Hub | `explore/travail_hub_screen.dart` | QU | T1-T5 | 10/10 | traité |
| Logement Hub | `explore/logement_hub_screen.dart` | QU | T1-T5 | 10/10 | traité |
| Fiscalité Hub | `explore/fiscalite_hub_screen.dart` | QU | T1-T5 | 10/10 | traité |
| Patrimoine Hub | `explore/patrimoine_hub_screen.dart` | QU | T1-T5 | 10/10 | traité |
| Santé Hub | `explore/sante_hub_screen.dart` | QU | T1-T5 | 10/10 | traité |

## 3.16 Achievements, portfolio, time-based views

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Achievements | `achievements_screen.dart` | HP/QU | T1-T5 | 10/10 | traité |
| Timeline | `timeline_screen.dart` | QU | T6-C | — | historique |
| Portfolio | `portfolio_screen.dart` | QU | T6-C | — | portefeuille |

## 3.17 Auth

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Login | `auth/login_screen.dart` | QU | T6-C | — | auth |
| Register | `auth/register_screen.dart` | QU | T6-C | — | auth |
| Forgot Password | `auth/forgot_password_screen.dart` | QU | T6-C | — | auth |
| Verify Email | `auth/verify_email_screen.dart` | QU | T6-C | — | auth |

## 3.18 Admin

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Admin Observability | `admin_observability_screen.dart` | QU | T6-C | — | admin |
| Admin Analytics | `admin_analytics_screen.dart` | QU | T6-C | — | admin |

## 3.19 Futur / roadmap hors codebase

| Écran | Fichier | Template | Priorité | Score S52 | Notes |
|---|---|---:|---:|---:|---|
| Weekly Recap | `future` | HP | T-future | — | prévu en phase 2 roadmap, pas encore implémenté dans le codebase |

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
7. Screenshot board final des 109 surfaces actives
