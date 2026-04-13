# MINT Inventaire — Verdict Screen-by-Screen

> **Statut** : Source of truth pour la décision KEEP/REFACTOR/MERGE/FREEZE/DELETE par écran.
> **Auteur** : Office-hours co-design avec Julien (2026-04-11), via 4 sub-agents parallèles qui ont lu chaque écran un par un.
> **Subordonné à** : `10-MANIFESTO.md` (vision et architecture cible)
> **Subordonné par** : `12-PLAN-EXECUTION.md` (sprint d'intégration 2-3 semaines)
> **Read time** : 20 minutes en lecture séquentielle, 5 minutes en mode tableau.
> **Purpose** : Julien lit ce document une fois et sait exactement quel écran reste, quel écran disparaît, et quel écran est refactoré.

---

## 1. TL;DR

**93 écrans audités. Voici le résultat consolidé :**

| Verdict | Nombre | % | Signification |
|---|---|---|---|
| **KEEP** | 20 | 21% | Reste tel quel ou avec polish léger. Mappe directement sur l'architecture cible (les 6 écrans principaux + secondaires). |
| **REFACTOR** | 21 | 23% | Reste mais nécessite réécriture pour matcher la voix MINT, l'architecture dossier-first, ou le pattern Cleo 3.0. Le contenu/logique est doctrinaire ; la forme ne l'est pas. |
| **MERGE** | 16 | 17% | Fusionne avec un autre écran ou plusieurs. Soit consolidation de doublons (4 disability → 1), soit absorption en composant d'un canvas unifié (5 mortgage → 1 "Logement"). |
| **FREEZE** | 21 | 23% | Reste dans le code, inaccessible depuis la nav, déglacé sur user demand validé. Beaucoup de simulateurs sliders dont la logique est précieuse mais la surface UI est anti-doctrine. |
| **DELETE** | 15 | 16% | Supprimé pour de bon. Doctrine indéfendable (gamification, ranking nominé, retirement framing), duplications mortes (timeline = doublon explorer hub), micro-calculateurs orphelins. |

**Lecture** : MINT a beaucoup plus de surface vivante qu'on ne pensait (41 KEEP+REFACTOR), beaucoup à consolider (16 MERGE), une grosse quantité à geler (21 FREEZE) en attendant validation utilisateur, et finalement très peu à vraiment supprimer (15 DELETE).

**Surface visible Phase 1 (post-sprint)** : ~12-15 écrans actifs (les 6 principaux + ~6-9 secondaires invocables contextuellement). Le reste est freezé en attendant evidence ou déglacé progressivement.

---

## 2. Patterns transverses observés par les 4 sub-agents

### Pattern 1 — Wizard-era legacy
La majorité des écrans "insight" sont câblés sur `wizardAnswers` plutôt que sur le dossier parsé. **Ce n'est pas un bug, c'est une dette architecturale héritée d'une ère antérieure de MINT.** Le rewire vers `DossierProfile` (qui existe déjà côté backend via les parsers + RAG + coach_context_builder) est mécanique mais systématique.

### Pattern 2 — God-screens (1000-1500 LOC)
Plusieurs écrans dépassent 1000 lignes : `retirement_dashboard_screen` (1374), `document_scan_screen` (1484), `concubinage_screen` (1261), `debt_ratio_screen` (1237), `repayment_screen` (1020), `divorce_simulator_screen` (961), `expat_screen` (1721), `frontalier_screen` (1490), `fiscal_comparator_screen` (1556), `naissance_screen` (1400), `mariage_screen` (1233), `documents_screen` (1464), `independant_screen` (1194), `first_job_screen` (1161), `donation_screen` (1075), `unemployment_screen` (1024), `rachat_echelonne_screen` (1100), `job_comparison_screen` (1125). **Ces écrans sont des "god views" multi-responsabilités** qui doivent être splittés en composants réutilisables (un "dossier widget" + un "résultat widget" + un "tool dispatcher widget" + une "comparison card").

### Pattern 3 — Forest de simulateurs sliders
**5 mortgage screens, 4 pillar_3a_deep screens, 5 indépendants screens, 3 disability screens, 3 simulators génériques.** Tous violent la doctrine dossier-first parce qu'ils demandent à l'utilisateur de remplir des sliders au lieu de lire ce que MINT sait déjà via le dossier. **Le travail n'est pas de les supprimer — c'est de FUSIONNER chaque famille en un seul "canvas" unifié dossier-driven.**

### Pattern 4 — Gamification + retirement framing = doctrine violation
`achievements_screen`, `score_reveal_screen`, `cockpit_detail_screen`, `retirement_dashboard_screen`, `optimisation_decaissement_screen`, `succession_patrimoine_screen`, `gender_gap_screen`, `cantonal_benchmark_screen` violent toutes au moins une règle de CLAUDE.md §6 ou MINT_IDENTITY.md. **Certaines sont DELETE (gamification pure), d'autres sont REFACTOR (le contenu est valable mais le framing est faux).**

### Pattern 5 — Auth, settings, legal sont propres
Tous les écrans auth (login, register, forgot_password, verify_email), settings (langue, byok, slm), legal (about), couple (household, accept_invitation), profile (privacy_control, financial_summary) sont **WORKS, doctrine YES, KEEP**. Ils ont juste besoin de rehousing sous la section Profile/Settings de l'architecture cible. Pas de refactor nécessaire.

### Pattern 6 — La colonne vertébrale dossier-first existe DÉJÀ
La chaîne **`document_scan` → `extraction_review` → `document_impact` → `document_detail` → `documents_screen` (vault) + `data_block_enrichment` + `avs_guide`** est exactement la spine de la nouvelle architecture. Elle existe, elle marche (avec du polish), elle implémente déjà le `premier_eclairage` et la structure 4 couches. **C'est notre point de départ, pas notre point d'arrivée.**

### Pattern 7 — Coach surface est stable
`coach_chat_screen` (1747 LOC mais déjà refactoré du 4193 LOC précédent), `conversation_history_screen`, `coach/coach_context_builder`, `claude_coach_service.py` — tout marche, tout est doctrinaire. C'est l'autre pilier du target architecture. **À garder, à faire évoluer, pas à reconstruire.**

### Pattern 8 — Open Banking est en mock + freezé pour FINMA
Les 3 écrans open_banking sont des mocks bien faits, gated FINMA, Phase 4 du roadmap. **FREEZE jusqu'à green light FINMA.** Ne pas supprimer — la logique compliance est précieuse pour quand l'opportunité revient.

### Pattern 9 — Compliance risk = `provider_comparator_screen`
Ce screen ranke nominativement les fournisseurs 3a (UBS, Raiffeisen, VIAC, Frankly, Swiss Life, etc.). **Violation directe de la règle "no nommer un émetteur" de MINT_IDENTITY.md.** Refactor obligatoire en comparaison de classes d'actifs (fintech vs bancaire vs assurance) sans noms, OU delete.

### Pattern 10 — Services backend > Screens
**Quasi tous les services backend sont valables et à préserver**, même quand l'écran qui les expose est FREEZE/DELETE. Exemples : `expat_service`, `frontalier_service`, `independants_service`, `lpp_deep_service`, `mortgage_service`, `family_service`, `donation_service`, `housing_sale_service`, `unemployment_service`, `disability_*_service`. **Ils deviennent des coach tools** invoqués par le chat ou par les Document Result cards, plutôt que des écrans dédiés.

---

## 3. Verdict détaillé screen-by-screen

### 3.1 — KEEP (20 écrans, 21%)

Ces écrans restent tels quels ou avec un polish léger. Ils mappent directement sur l'architecture cible (6 écrans principaux + secondaires).

| # | Screen | LOC | Pillar cible | Notes |
|---|---|---|---|---|
| 1 | `landing_screen.dart` | 189 | Splash/Welcome | **CI-gated, locked copy. C'est déjà le nouveau Welcome.** Ne pas toucher. |
| 2 | `auth/login_screen.dart` | 559 | Auth | Apple Sign In + magic link, fonctionne. Adjust post-auth route vers Document Upload pour new users. |
| 3 | `auth/register_screen.dart` | 727 | Auth | Consent gates LSFin/nLPD compliance. Mandatory. |
| 4 | `auth/forgot_password_screen.dart` | 248 | Auth | Plomberie auth standard. |
| 5 | `auth/verify_email_screen.dart` | 186 | Auth | Plomberie auth standard. |
| 6 | `about_screen.dart` | 181 | Profile/Settings | Liens légaux, version, identity. |
| 7 | `byok_settings_screen.dart` | 583 | Profile/Settings | BYOK Claude/OpenAI/Mistral. Privacy-core. |
| 8 | `slm_settings_screen.dart` | 788 | Profile/Settings | On-device Gemma 3n. nLPD-aligned. |
| 9 | `settings/langue_settings_screen.dart` | 98 | Profile/Settings | Locale switcher 6 langues. |
| 10 | `profile/privacy_control_screen.dart` | 281 | Profile/Settings + My Dossier | "Ce que MINT sait de toi" — transparence radicale, nLPD compliant. **Core doctrine.** |
| 11 | `household/household_screen.dart` | 514 | Profile/Settings | Couple/household — caps LAVS art. 35. |
| 12 | `household/accept_invitation_screen.dart` | 194 | Profile/Settings | Code à 6 chars. |
| 13 | `coach/coach_chat_screen.dart` | 1747 | Coach Chat | **Pilier #5.** Déjà refactoré du 4193 LOC précédent. Continuer. |
| 14 | `coach/conversation_history_screen.dart` | 279 | Coach Chat (secondary) | Multi-thread coach chat. |
| 15 | `document_scan/document_scan_screen.dart` | 1484 | Document Upload (#2) | **Pilier #2** — mais trop gros, voir REFACTOR ci-dessous (refactor + keep en parallèle : split god-view en composants, garder le pillar). |
| 16 | `document_scan/extraction_review_screen.dart` | 804 | Document Upload (transition) | "Voici ce qu'on a lu, corrige si besoin." Transparence + correction. |
| 17 | `document_scan/document_impact_screen.dart` | 787 | Document Result (#3) | **Pilier #3.** Déjà implémente le `premier_eclairage` et l'idée des 4 couches. |
| 18 | `document_scan/avs_guide_screen.dart` | 501 | Document Upload (acquisition) | Guide pour obtenir extrait AVS depuis ahv-iv.ch. |
| 19 | `document_detail_screen.dart` | 598 | My Dossier (#4) — voir REFACTOR | Affiche un doc parsé, mais ne lit que le `lastUploadResult`. **Refactor obligatoire pour vrai backend repository.** |
| 20 | `onboarding/data_block_enrichment_screen.dart` | 708 | My Dossier (gap-fill) | Per-block enrichment quand l'OCR a manqué quelque chose. |
| 21 | `confidence/confidence_dashboard_screen.dart` | 586 | My Dossier (tab) | 4-axis EnhancedConfidence. À fusionner comme tab dans My Dossier. |
| 22 | `debt_prevention/help_resources_screen.dart` | 403 | Coach (resources) | Dettes Conseils Suisse, Caritas, services cantonaux. **Pure protection doctrine.** |

### 3.2 — REFACTOR (21 écrans, 23%)

Ces écrans gardent leur logique mais doivent être réécrits pour matcher la voix MINT, l'architecture dossier-first, ou le pattern Cleo 3.0 (insight → plan → conversation → action → memory).

| # | Screen | LOC | Reason | Refactor target |
|---|---|---|---|---|
| 1 | `documents_screen.dart` | 1464 | God-screen mélangeant vault + paywall + upload sheet + empty states | Split en : My Dossier shell + Upload sheet (modal) + Paywall sheet (modal). C'est le pillar #4 (My Dossier). |
| 2 | `coach/retirement_dashboard_screen.dart` | 1374 | God-screen retirement-framed (anti-pattern #16) | Split en widgets réutilisables + démote en "résultat de life event retirement" invoqué depuis le dossier ou le coach. Strip retirement-as-default framing. |
| 3 | `concubinage_screen.dart` | 1261 | God-screen 4-tab life event | Split en (a) comparator widget mariage vs concubinage, (b) survivor gap widget, (c) checklist. Surface contextuellement quand profile.civilStatus = unmarried. |
| 4 | `debt_prevention/debt_ratio_screen.dart` | 1237 | God-screen 1237 LOC, sequence-tracker couplé | **Core protection screen.** Trim massif, dossier-driven (lit salaire/dette du profil), merge avec repayment_screen. |
| 5 | `divorce_simulator_screen.dart` | 961 | God-screen 4-tab life event | Refactor en flow coach-triggered. Strip duplicate `_formatChfSwiss` (use `chf_formatter.dart`). |
| 6 | `mariage_screen.dart` | 1233 | God-screen 4-tab life event | Coach-triggered flow émettant un premier_eclairage 4 couches, pas 4 tabs sliders. |
| 7 | `naissance_screen.dart` | 1400 | God-screen 4-tab life event | Même pattern : coach flow + premier_eclairage. APG/cantonal allocations/fiscal waterfall en composants. |
| 8 | `unemployment_screen.dart` | 1024 | God-screen LACI calculator | Coach-triggered flow, lit salaire du dossier, Crash Test Budget widget. **Critical life event.** |
| 9 | `deces_proche_screen.dart` | 442 | Slider form | Refactor en life-event flow, dossier-driven inputs. |
| 10 | `demenagement_cantonal_screen.dart` | 587 | Standalone simulator | Dossier-driven (déjà partiellement), coach-triggered au lieu de standalone. |
| 11 | `disability/disability_gap_screen.dart` | 484 | Hardcoded defaults (8333 CHF, age 45) | Dossier integration + merge avec siblings disability. **Core protection topic.** |
| 12 | `consumer_credit_screen.dart` | 365 | Slider-heavy simulator | Dossier-driven (lit prêts depuis bank statements). Trigger = upload doc crédit. |
| 13 | `coverage_check_screen.dart` | 746 | Toggle-driven, ignore les uploads insurance | Lit polices d'assurance parsées du dossier. **Pillar protection-first.** |
| 14 | `advisor/financial_report_screen_v2.dart` | 1041 | Dashboard wizard-driven | Refactor en surface "My Dossier insight" qui consomme `DossierProfile`, pas `wizardAnswers`. |
| 15 | `arbitrage/allocation_annuelle_screen.dart` | 716 | Standalone arbitrage simulator | Démote en in-chat tool widget invocable par le coach. |
| 16 | `arbitrage/location_vs_propriete_screen.dart` | 671 | Standalone arbitrage simulator | Idem : coach-triggered tool. |
| 17 | `arbitrage/rente_vs_capital_screen.dart` | 2096 | God-screen retirement-framed flagship | **Le 4-bloc Accroche/Explorer/Comprendre/Affiner reste précieux mais 2096 LOC est démesuré.** Strip retirement-default, reduce LOC, link to LPP cert upload flow. |
| 18 | `budget/budget_screen.dart` | 1065 | God-screen 1065 LOC, kitchen-sink dashboard | Shrink en surface focus dans My Dossier, dossier-driven (parsed bank statements). Garder `BudgetLivingEngine`. |
| 19 | `pillar_3a_deep/retroactive_3a_screen.dart` | 903 | Slider-heavy mais killer feature | **Hero feature de Phase 1 du roadmap, OPP3 art. 7 amendement 2026.** Refactor obligatoire pour driver depuis dossier (3a cert + tax history), pas sliders. KEEP-as-priority. |
| 20 | `pillar_3a_deep/provider_comparator_screen.dart` | 484 | Compliance violation : ranke des fournisseurs nominatifs | Refactor en comparaison de classes d'actifs (fintech vs bancaire vs assurance) sans noms. **Compliance audit obligatoire avant ship.** |
| 21 | `profile/financial_summary_screen.dart` | 509 | Stock view, déjà CoachProfile-driven | **Devient le summary tab de My Dossier.** Bonne base, bonne direction. Refactor = merge dans My Dossier. |

### 3.3 — MERGE (16 écrans, 17%)

Ces écrans fusionnent avec un autre écran ou plusieurs en un canvas unifié dossier-driven.

#### Famille mortgage : 5 écrans → 1 "Logement insight canvas"
- `mortgage/affordability_screen.dart` (758 LOC)
- `mortgage/amortization_screen.dart` (649 LOC)
- `mortgage/epl_combined_screen.dart` (784 LOC) — **hero du canvas**, EPL multi-source est THE Swiss property question
- `mortgage/imputed_rental_screen.dart` (536 LOC)
- `mortgage/saron_vs_fixed_screen.dart` (569 LOC)

**Total réduction : 3'296 LOC → ~600 LOC (1 canvas + 5 sections)**. Le canvas est invoqué quand le dossier détecte (a) bank statement avec montant immobilier, (b) LPP cert avec EPL eligible, (c) user dit "j'envisage d'acheter" dans le chat.

#### Famille pillar_3a_deep + simulator_3a : 4 écrans → 1 "3a insight canvas"
- `pillar_3a_deep/real_return_screen.dart` (536 LOC)
- `pillar_3a_deep/staggered_withdrawal_screen.dart` (539 LOC)
- `simulator_3a_screen.dart` (734 LOC)
- (`pillar_3a_deep/retroactive_3a_screen.dart` reste comme **hero** du canvas — voir REFACTOR section)

**Total réduction : 1'809 LOC → ~400 LOC.** Canvas invoqué quand le dossier ingère un certificat 3a (assurance ou bancaire).

#### Famille disability : 3 écrans → 1 "Couverture invalidité & santé canvas"
- `disability/disability_insurance_screen.dart` (343 LOC)
- `disability/disability_self_employed_screen.dart` (269 LOC)
- (`disability_gap_screen.dart` reste comme hero — voir REFACTOR)

**Branches sur `profile.archetype`** : indépendant_no_lpp / indépendant_with_lpp / salarié. **Total réduction : 612 LOC → ~250 LOC.**

#### Autres MERGE
- `arbitrage/arbitrage_bilan_screen.dart` (422 LOC) → fusion dans My Dossier comme insight section
- `bank_import_screen.dart` (981 LOC) → fusion dans Document Upload pillar (un type de doc parmi d'autres)
- `budget/budget_container_screen.dart` (79 LOC) → collapse dans budget_screen (élimine LOOP-01)
- `coach/optimisation_decaissement_screen.dart` (374 LOC) → coach insight insert via RAG content, pas standalone
- `coach/succession_patrimoine_screen.dart` (361 LOC) → coach insight insert + widgets (TestamentInvisibleWidget, AvancementHoirieWidget) gardés
- `debt_prevention/repayment_screen.dart` (1020 LOC) → fusion avec debt_ratio_screen en single "Ma situation dette" view
- `debt_risk_check_screen.dart` (374 LOC) → coach chat flow ("6 questions rapides")

**Total écrans MERGE : 16. Total LOC à compacter : ~10'000 LOC → ~2'500 LOC** (75% de réduction sans perte de fonctionnalité).

### 3.4 — FREEZE (21 écrans, 23%)

Ces écrans restent dans le code mais inaccessibles depuis la nav. Déglacés sur user demand validé. La logique est précieuse, la surface UI est anti-doctrine ou hors scope Phase 1.

| # | Screen | LOC | Reason de freeze | Quand déglacer |
|---|---|---|---|---|
| 1 | `admin_analytics_screen.dart` | 409 | Admin only, pas user-facing | Garder accessible via route admin uniquement |
| 2 | `admin_observability_screen.dart` | 354 | Admin only | Idem |
| 3 | `cantonal_benchmark_screen.dart` | 357 | Compliance risk anti-shame (comparaisons cantonales) | Doctrinal review obligatoire avant déglaçage |
| 4 | `expat_screen.dart` | 1721 | Simulator wall, archetype-driven via dossier | Quand expat archetype est exposé par les coach tools |
| 5 | `frontalier_screen.dart` | 1490 | Simulator + product gap connu | Quand le frontalier service est complété (memory: gap connu) |
| 6 | `first_job_screen.dart` | 1161 | Simulator-style premier emploi | Salvage SalaryBreakdown + PayslipXray widgets pour Document Result |
| 7 | `fiscal_comparator_screen.dart` | 1556 | Simulator + ranking borderline social comparison | Coach tool `tax_canton_compare` |
| 8 | `housing_sale_screen.dart` | 979 | Simulator | Coach tool `housing_sale_impact` |
| 9 | `independant_screen.dart` | 1194 | Toggle-and-slider form | Archetype detection via dossier + coach `independant_brief` |
| 10 | `lpp_deep/epl_screen.dart` | 771 | Slider simulator | Insight depuis Document Result LPP cert + coach `epl_brief` |
| 11 | `lpp_deep/libre_passage_screen.dart` | 543 | Standalone checklist | Trigger sur life events newJob/countryMove |
| 12 | `lpp_deep/rachat_echelonne_screen.dart` | 1100 | Slider simulator LPP buyback | Insight inside Document Result LPP cert |
| 13 | `lamal_franchise_screen.dart` | 670 | "Optimiser" wording violation | Coach tool depuis upload police LAMal. Rename obligatoire. |
| 14 | `donation_screen.dart` | 1075 | Pure calculator surface | Coach tool + dossier insight card |
| 15 | `education/comprendre_hub_screen.dart` | 124 | Education catalog hub anti-pattern | Content gardé dans RAG, exposé inline dans coach |
| 16 | `education/theme_detail_screen.dart` | 756 | Quiz/reading flow | Idem : RAG content + in-thread "lire" block |
| 17 | `job_comparison_screen.dart` | 1125 | Standalone simulator | Coach-triggered comparison card quand 2 offres uploadées |
| 18 | `coach/annual_refresh_screen.dart` | 901 | Wizard-driven refresh, archived per Wire Spec V2 | Confirm router redirect, then DELETE in Phase 2 |
| 19 | `open_banking/consent_screen.dart` | 958 | Mock + FINMA gate | Phase 4 du roadmap |
| 20 | `open_banking/open_banking_hub_screen.dart` | 705 | Mock + FINMA gate | Idem |
| 21 | `open_banking/transaction_list_screen.dart` | 549 | Mock + FINMA gate | Idem |

**Note importante** : freeze ≠ delete. Le code reste, le module backend reste, mais la route est inaccessible depuis la nav active. **Pour chaque freeze, le service backend correspondant devient un coach tool** invocable par le chat ou le Document Result, ce qui préserve 100% de la valeur de la logique financière sans encombrer la surface UI.

### 3.5 — DELETE (15 écrans, 16%)

Ces écrans sont supprimés pour de bon. Doctrine indéfendable, duplications mortes, ou micro-calculateurs orphelins.

| # | Screen | LOC | Reason de delete | Backend impact |
|---|---|---|---|---|
| 1 | `achievements_screen.dart` | 948 | Streaks/badges/milestones violent anti-shame doctrine | DailyEngagementService, StreakService, MilestoneDetectionService = candidats removal |
| 2 | `advisor/score_reveal_screen.dart` | 901 | Strava-style fitness score viole "MINT n'est pas un calculator/dashboard" + anti-shame | FinancialFitnessService = candidat removal ou demote |
| 3 | `ask_mint_screen.dart` | 1017 | Dupliquer chat surface, archived per Wire Spec V2 | RagService déjà consommé par coach_chat |
| 4 | `coach/cockpit_detail_screen.dart` | 591 | "Cockpit" retirement framing = anti-pattern #16, archived | Widgets (Monte Carlo, FRI, etc.) salvageables en coach tool cards |
| 5 | `coach/annual_refresh_screen.dart` | 901 | Wizard-driven refresh, archived | Already in router redirect |
| 6 | `gender_gap_screen.dart` | 665 | Demographic framing viole "segment by life event not demographics" | SegmentsService = migration vers coach insight engine |
| 7 | `independants/avs_cotisations_screen.dart` | 382 | Micro-calculator orphelin | IndependantsService.calculateAvsCotisations = preserve, devient coach tool |
| 8 | `independants/dividende_vs_salaire_screen.dart` | 758 | "Optimizer" wording + ranking + audience trop narrow | IndependantsService.calculateDividendeVsSalaire = preserve, archive |
| 9 | `independants/ijm_screen.dart` | 372 | Micro-calculator orphelin | IndependantsService.calculateIjm = coach tool |
| 10 | `independants/lpp_volontaire_screen.dart` | 628 | Duplicate + legacy "Chiffre choc" comment | IndependantsService.calculateLppVolontaire = coach tool |
| 11 | `independants/pillar_3a_indep_screen.dart` | 615 | Calculator pattern + legacy comment | IndependantsService.calculate3aIndependant = coach tool |
| 12 | `portfolio_screen.dart` | 207 | Stub, all "—" placeholders, no real pipeline | ProfileProvider legacy refs only |
| 13 | `simulator_compound_screen.dart` | 307 | Generic compound interest, no Swiss specificity | None |
| 14 | `simulator_leasing_screen.dart` | 312 | Off-scope (cars), debt crisis flow covers la pain case | None |
| 15 | `timeline_screen.dart` | 536 | Static taxonomy duplicate de l'Explorer hub | Routes restent, screen disparaît |

**Total LOC supprimées** : ~9'140 LOC. **Backend impact** : 5 services candidats à preservation (devienent coach tools), 0 service détruit, 1 module potentiellement archivé (FinancialFitnessService).

---

## 4. Vue par pillar de l'architecture cible

Mapping des écrans existants sur les 6 pillars de l'architecture cible (du manifesto Section 7).

### Pillar 1 — Splash / Welcome
- **`landing_screen.dart`** (KEEP, 189 LOC) — déjà CI-gated, locked copy. Aucun travail.

### Pillar 2 — Document Upload
- **`document_scan/document_scan_screen.dart`** (KEEP+REFACTOR, 1484 LOC) — pillar principal, à splitter en composants
- **`document_scan/extraction_review_screen.dart`** (KEEP, 804 LOC) — étape transition
- **`document_scan/avs_guide_screen.dart`** (KEEP, 501 LOC) — guide acquisition AVS
- **`bank_import_screen.dart`** (MERGE, 981 LOC) — fusionne dans Document Upload comme un type doc parmi d'autres

### Pillar 3 — Document Result (4 layers)
- **`document_scan/document_impact_screen.dart`** (KEEP, 787 LOC) — déjà implémente premier_eclairage et 4 couches. C'est le pillar #3.

### Pillar 4 — My Dossier (file vault)
- **`documents_screen.dart`** (REFACTOR, 1464 LOC) — vault principal, à splitter
- **`document_detail_screen.dart`** (KEEP+REFACTOR, 598 LOC) — détail d'un doc, refactor pour vrai backend repository
- **`onboarding/data_block_enrichment_screen.dart`** (KEEP, 708 LOC) — gap-fill per-block
- **`confidence/confidence_dashboard_screen.dart`** (KEEP, 586 LOC) — devient un tab "ce que MINT sait de moi"
- **`profile/financial_summary_screen.dart`** (REFACTOR/MERGE, 509 LOC) — devient le summary tab de My Dossier
- **`arbitrage/arbitrage_bilan_screen.dart`** (MERGE, 422 LOC) — fusion comme insight section

### Pillar 5 — Coach Chat
- **`coach/coach_chat_screen.dart`** (KEEP, 1747 LOC) — pillar principal
- **`coach/conversation_history_screen.dart`** (KEEP, 279 LOC) — multi-thread

### Pillar 6 — Profile / Settings
- **`about_screen.dart`** (KEEP, 181 LOC)
- **`byok_settings_screen.dart`** (KEEP, 583 LOC)
- **`slm_settings_screen.dart`** (KEEP, 788 LOC)
- **`settings/langue_settings_screen.dart`** (KEEP, 98 LOC)
- **`profile/privacy_control_screen.dart`** (KEEP, 281 LOC) — transparence radicale
- **`household/household_screen.dart`** (KEEP, 514 LOC)
- **`household/accept_invitation_screen.dart`** (KEEP, 194 LOC)
- **Auth screens (login, register, forgot, verify)** — sub-routes auth, 1720 LOC total

### Écrans secondaires (invocables contextuellement, pas dans nav principale)
- Coach insights inserts (depuis chat) : ex-`optimisation_decaissement`, `succession_patrimoine`, `gender_gap` content, debt_risk_check questions, education themes content
- Life event flows (depuis chat ou contextual triggers) : `mariage`, `naissance`, `divorce`, `unemployment`, `deces_proche`, `demenagement_cantonal`, `concubinage` (tous REFACTOR)
- Canvas unifiés (depuis chat ou Document Result) : Mortgage canvas (5 écrans → 1), 3a canvas (4 écrans → 1), Disability canvas (3 écrans → 1)
- Debt protection : `debt_ratio` + `repayment` + `help_resources` → 1 canvas "Ma situation dette" + resources directory
- Help resources : `debt_prevention/help_resources_screen.dart` (KEEP, 403 LOC)

### Coach tools (services backend invocables sans écran dédié)
Services préservés des écrans FREEZE/DELETE, exposés comme coach tools pour invocation contextuelle :
- `expat_service`, `frontalier_service`
- `independants_service` (×5 sub-calculators)
- `lpp_deep_service` (rachat_echelonne, epl, libre_passage)
- `mortgage_service` (5 sub-calculators)
- `pillar_3a_deep_service` (real_return, staggered_withdrawal)
- `family_service` (mariage, naissance, concubinage, deces)
- `donation_service`
- `housing_sale_service`
- `unemployment_service`
- `disability_*_service`
- `lamal_franchise_service`
- `assurances_service`
- `fiscal_service`, `wealth_tax_service`
- `consumer_credit` calculators
- `debt_prevention_service`
- `job_comparison_service`

**Tous ces services restent en code, restent testés, et deviennent appelables par le coach Claude via tool_use.**

---

## 5. Surface visible Phase 1 (post-sprint)

Après le sprint d'intégration de 2-3 semaines (voir Livrable 3), la surface utilisateur visible devient :

**Écrans principaux (~15) :**
1. Landing/Welcome
2. Auth (login, register, forgot, verify) — 4 sous-routes
3. Document Upload (consolidé)
4. Extraction Review
5. Document Result (4 layers)
6. My Dossier (vault + summary tab + confidence tab + privacy tab)
7. Document Detail
8. Data Block Enrichment (gap-fill modal)
9. Coach Chat
10. Conversation History (modal/secondary)
11. Profile/Settings (about + langue + byok + slm + privacy + household)

**Écrans secondaires invocables contextuellement (~10) :**
- Mortgage canvas (Logement insight)
- 3a canvas
- Disability canvas
- Debt situation canvas
- Life event flows (mariage, naissance, divorce, unemployment, etc.) — coach-triggered
- Help resources directory (dettes Conseils)
- Open banking flow (modal, Phase 4 quand FINMA OK)

**Surface gelée (~21 écrans) :** existent en code, services backend exposés comme coach tools, déglaçables un par un sur user demand validé.

**Surface supprimée (~15 écrans) :** disparues, services backend préservés (5 réintégrables), les autres archivés.

**Net** : 93 écrans → ~25 écrans actifs en surface visible. **73% de réduction de surface mentale**, sans perdre 1% de la valeur du code financier. C'est le diagnostic dette d'intégration en action.

---

## 6. Pré-requis avant le sprint Phase 1 (gates)

Avant de toucher au moindre fichier d'écran, ces décisions doivent être prises ou ces vérifications faites :

### Gate 1 — Decisions de routing & nav (du nav roadmap)
- ☐ Adopter `MintNav.back(fallback:)` du nav roadmap (Phase 1 step 1)
- ☐ Adopter `preserveQueryRedirect()` helper (Phase 1 step 2)
- ☐ Deprecate `safe_pop.dart` (Phase 1 step 3)
- ☐ Patch les 40 redirects `app.dart` ~lines 229-930 (Phase 1 step 4)
- ☐ Fix LOOP-01 (delete `BudgetContainerScreen`, route `/budget` correctement) (Phase 1 step 5)

### Gate 2 — Decisions de compliance
- ☐ Audit `provider_comparator_screen` pour la violation No-Ranking — décision : refactor en classes d'actifs OU delete
- ☐ Audit `cantonal_benchmark_screen` pour la violation No-Social-Comparison — décision : freeze permanent OU refactor
- ☐ Vérifier que tous les services backend FREEZE sont exposés comme coach tools ou marqués pour le devenir
- ☐ CI guards des anti-patterns du nav roadmap Section 7 (AP-1 à AP-8) en place

### Gate 3 — Decisions backend
- ☐ Création de `shared/route_registry.json` (nav roadmap Decision 10) avant toute deletion d'écran qui pourrait être référencée par le coach
- ☐ Grep `services/backend/app/` pour chaque route à supprimer, fix backend en premier
- ☐ Vérifier que `claude_coach_service.py` ne référence aucun des 15 écrans DELETE dans ses prompts/tools

### Gate 4 — Decisions UX
- ☐ Sign-off sur le manifesto (10-MANIFESTO.md) — Julien lit, valide ou corrige
- ☐ Sign-off sur cet inventaire (11-INVENTAIRE.md) — Julien lit, valide ou corrige
- ☐ Décider la décomposition des 18 écrans god-screen (1000+ LOC) en composants : qui fait quoi, dans quel ordre

### Gate 5 — Tests & QA
- ☐ Existing test suite passe (`flutter test`, `pytest tests/ -q`)
- ☐ `flutter analyze` à 0 erreurs avant tout refactor
- ☐ Snapshot des routes actuelles (pour validation post-sprint que rien d'utilisé n'a disparu)

### Gate 6 — Analytics
- ☐ Décider Plausible / PostHog / route logger via `audit_service.py` (cf. discussion office-hours)
- ☐ Instrumenter avant deletion (24-48h de baseline pour valider que les écrans à killer sont vraiment <1% MAU)

**Aucun de ces gates n'est optionnel.** Ils protègent contre les régressions et les violations doctrinales.

---

## 7. Ce que ce document NE dit pas (et qui appartient au Livrable 3)

- **L'ordre d'exécution** des refactors — quel écran en premier, quel sprint, quels gates entre sprints
- **L'allocation human-in-loop** vs CC agent
- **Les dépendances inter-écrans** (refactor X avant Y parce que Y consomme un widget de X)
- **Le timeline calendaire** (semaine par semaine)
- **Les rollback criteria** si un refactor casse quelque chose
- **Les critères de Phase 1 gate** (post-sprint)
- **La distribution / outreach** post-sprint
- **L'instrumentation analytics** détaillée
- **La spec UI** des 6 écrans principaux (couleurs, layout, animations) — à faire dans un design doc séparé si nécessaire

Tout ça est dans le Livrable 3 (`12-PLAN-EXECUTION.md`).

---

## 8. Métriques de succès de l'inventaire

L'inventaire est jugé réussi si :

- ☐ Julien lit le tableau récapitulatif (Section 1) en 2 minutes et comprend l'ampleur
- ☐ Julien lit la Section 2 (patterns transverses) en 5 minutes et reconnaît son code
- ☐ Pour chaque écran KEEP/REFACTOR/MERGE/FREEZE/DELETE, Julien peut dire "OK" ou "non, ce screen X est plus important que tu penses, voici pourquoi" en moins de 30 secondes
- ☐ Aucune surprise : Julien reconnaît les ~95 écrans, n'en découvre pas un qu'il avait oublié
- ☐ Le ratio KEEP+REFACTOR (44%) vs FREEZE+DELETE (39%) est jugé "raisonnable" (ni trop conservateur ni trop destructeur)
- ☐ Pour chaque DELETE, le service backend correspondant a été identifié comme préservé OU explicitement marqué pour archivage
- ☐ Pour chaque MERGE famille, la justification du regroupement est claire (pas arbitraire)
- ☐ Pour chaque FREEZE, le critère de déglaçage est défini

Si Julien valide les 8 critères, on passe au Livrable 3 (plan d'exécution).

---

*Fin de l'inventaire.*

*Document précédent : `10-MANIFESTO.md` (vision et architecture cible).*
*Document suivant : `12-PLAN-EXECUTION.md` (plan d'exécution sprint d'intégration 2-3 semaines).*
