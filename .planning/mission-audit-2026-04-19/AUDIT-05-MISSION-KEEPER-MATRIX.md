# AUDIT-05 — Mission Keeper Matrix (18 life events × 4-layer insight engine)

2026-04-19 • `feature/wave-c-scan-handoff-coach` • dev tip `f35ec8ff`

## 1. Préambule

**Mission** (MINT_IDENTITY.md) : "Mint te dit ce que personne n'a intérêt à te dire." Lucidité via **4-layer insight engine** : (1) **Factual** extraction brute (durée/pénalités/frais/flex), (2) **HumanTranslation** reformulation jargon → courant, (3) **PersonalPerspective** fait rapporté à archétype/canton/couple, (4) **QuestionsToAsk** questions à poser avant signature.

**18 life events** — enum `LifeEventType` à `apps/mobile/lib/models/age_band_policy.dart:9-39` : Famille 5 · Pro 5 · Patrimoine 4 · Santé 1 · Mobilité 2 · Crise 1.

**Constat préalable global** : l'enum existe mais n'est **jamais persisté** sur `CoachProfile` (grep `profile.lifeEvents` = 0 hits), **jamais injecté** dans `services/coach/context_injector_service.dart` (grep `lifeEvent|recentEvent` = 0), et `widgets/coach/life_event_sheet.dart` a **zéro call-site** hors de son propre fichier. Vocabulaire, pas machine.

## 2. Matrice 18 × 6

Légende : ✅ OK bout-en-bout · 🟡 code existe/non câblé UI · 🔴 partiel ou buggy · ❌ absent.

| # | Event | Factual | HumTrans | PersoPersp | Questions | Déclencheur UI | Persisté dossier |
|---|---|---|---|---|---|---|---|
| 1 | marriage | 🟡 `mariage_screen.dart` tabs | 🔴 ARB partiel | 🟡 `marriage_penalty_gauge.dart` non lu coach | ❌ | 🟡 `/mariage` + hub Famille | ❌ pas de `marriageDate` |
| 2 | divorce | ✅ `divorce_simulator_screen` + backend `life_events.py` + checklist | 🟡 `divorce_film_widget.dart` | 🔴 régime demandé chaque run | ❌ | 🟡 `/divorce` | ❌ endpoint stateless |
| 3 | birth | 🟡 `naissance_screen.dart` allocs/congé | 🔴 | ❌ pas d'impact budget/3a/impôt perso | ❌ | 🟡 `/naissance` | ❌ `childrenCount` oui, `birthDate` non |
| 4 | concubinage | 🟡 `concubinage_screen` + `concubinage_decision_matrix` | 🟡 matrice vs mariage | 🔴 `civilStatus` lu pas persistent coach | ❌ | 🟡 `/concubinage` | 🟡 pas de durée |
| 5 | deathOfRelative | 🟡 `deces_proche_screen` + `succession_simulator.py` + `survivor_pension_widget`+`testament_invisible_widget` | 🔴 | ❌ | ❌ | 🟡 `/life-event/deces-proche` | ❌ |
| 6 | firstJob | ✅ `first_job_screen` + `first_job_service` + backend `first_job/` | 🟡 fallback templates | 🔴 heuristique `age≤28` au lieu de flag event | ❌ | 🟡 `/first-job` | ❌ pas `firstJobDate` |
| 7 | newJob | 🟡 `job_comparison_screen` + backend `job_comparator.py` | ❌ | ❌ | ❌ | 🟡 `/simulator/job-comparison` | ❌ |
| 8 | selfEmployment | 🟡 `independant_screen` + `independants/` | 🔴 inserts partiels | 🟡 archetype détecté, câblage inconsistant | ❌ | 🟡 `/segments/independant` | 🟡 `employmentStatus` seul |
| 9 | jobLoss | 🔴 `unemployment_screen` + service basique | ❌ | ❌ SafeMode non câblé ici | ❌ | 🟡 `/unemployment` absent hub Explorer | ❌ |
| 10 | retirement | ✅ tout `financial_core/` + `retirement_dashboard_screen` + backend | ✅ `coach_narrative_service` + `scenario_narration.py` | ✅ archetype + `couple_optimizer` | 🔴 pas de checklist questions caisse LPP | ✅ `/retraite` | ✅ LPP/3a/AVS persistés |
| 11 | housingPurchase | ✅ `mortgage/` (affordability, amort, epl_combined, saron, imputed) + backend | 🟡 inserts éduc | 🟡 EPL ignore archetype FATCA | ❌ | 🟡 `/hypotheque`+`/epl` | ❌ pas `housingPurchaseDate` |
| 12 | housingSale | 🟡 `housing_sale_screen` + service + backend | 🔴 squelette | ❌ | ❌ | 🟡 `/life-event/housing-sale` | ❌ |
| 13 | inheritance | 🟡 `succession_patrimoine_screen` + `succession_simulator.py` | 🔴 | ❌ variations cantonales non persist. | ❌ | 🟡 `/succession` | ❌ |
| 14 | donation | 🟡 `donation_screen` + `donation_service.py` | ❌ | ❌ | ❌ | 🟡 `/life-event/donation` (seuil `age≥55∧income>100k`) | ❌ |
| 15 | disability | 🟡 `disability/` (gap, insurance, self_employed) + backend | 🔴 | 🔴 déclencheur `children>0 OR income>6k` ignore archetype | ❌ | 🟡 `/invalidite` | ❌ |
| 16 | cantonMove | 🟡 `demenagement_cantonal_screen` + `fiscal_comparator_screen` + backend `fiscal/` | 🔴 | 🟡 comparateur OK mais déclenche sur canton "high-tax" pas sur event | ❌ | 🟡 `/life-event/demenagement-cantonal` | 🟡 `canton` seul, pas `previousCanton` |
| 17 | countryMove | 🟡 `expat_screen` + `frontalier_screen` + backend `expat/` + `frontalier_service` | 🔴 FATCA copie incomplète | 🔴 archetype `expat_us` détecté non exposé UI | ❌ | 🔴 pas de route `/countryMove`, via `/segments/frontalier` | ❌ |
| 18 | debtCrisis | ✅ SafeMode gate + `debt_prevention/` + `debt_risk_check_screen` | 🟡 `debt_prevention_service` | 🟡 SafeMode désactive optims (Wave 0) | 🟡 `help_resources_screen` services, pas questions | ✅ `/debt-prevention/*`+ SafeMode auto | 🔴 `debtRatio` calculé pas event persisté |

**Bilan 108 cellules** : ~8 ✅, ~55 🟡, ~25 🔴, ~20 ❌. Axe **Questions 17/18 absents**. Axe **PersoPersp 12/18 partiel** (calculators archetype-aware mais output ne l'expose jamais).

## 3. Top 5 PIRE gap (backlog #1)

| # | Event | Absent sur | Pourquoi critique |
|---|---|---|---|
| 1 | **newJob** | 3 axes ❌ | Événement ultra-fréquent 25-55. Impact LPP direct (libre passage). Promesse MINT non tenue. |
| 2 | **donation** | 3 axes ❌ | Fiscalité cantonale complexe. Backend tourne à vide UI. |
| 3 | **housingSale** | 3 axes ❌ | Gains immo = impôt spécial cantonal. Écran vide de sens. |
| 4 | **countryMove** | FATCA 🔴, pas de route directe | `expat_us` existe, écran ne l'utilise pas. Doctrine FATCA non tenue. |
| 5 | **deathOfRelative** | PersoPersp ❌, Questions ❌ | `testament_invisible_widget` existe mais isolé du coach. |

## 4. Top 3 RELATIVEMENT couverts (quick wins)

| Event | Ce qui manque pour ✅ | Effort |
|---|---|---|
| **retirement** | Checklist "questions caisse LPP au départ" | ~1j |
| **debtCrisis** | Questions ciblées curateur/désendettement (`help_resources_screen` liste déjà services) | ~0.5j |
| **housingPurchase** | FATCA dans EPL + checklist "questions courtier/banque" | ~1.5j |

## 5. Pattern systémique

- **P1 — Simulateurs stateless** : 14/18 events ont backend+UI mais aucun ne persiste l'événement sur `CoachProfile`. Le coach ignore un mariage survenu hier.
- **P2 — Layer 4 quasi inexistant** : aucune DB de questions compliance-ready (LSFin art. 8 le permet). 17/18 absents. C'est pourtant la signature MINT vs Cleo/VZ.
- **P3 — Déclencheur UI orphelin** : `LifeEventSheet` couvre 18 events mais 0 call-site. Le seul path réel = `LifeEventSuggestionsSection` (heuristiques age/income) dans `financial_report_screen_v2.dart` — rate `jobLoss`, `housingSale`, `countryMove`, `cantonMove` (sauf canton high-tax), `deathOfRelative`, `debtCrisis`, partial `selfEmployment/newJob/disability`.

## 6. Plan de câblage ordonné (impact × facilité, ~18j)

| # | Chantier | j |
|---|---|---|
| C1 | Ajouter `List<LifeEventRecord> recentLifeEvents` sur `CoachProfile` + migration + backend persist | 2 |
| C2 | Câbler `LifeEventSheet` sur Coach FAB + Home capture sheet (remplace heuristiques age/income) | 1 |
| C3 | Injecter `recentLifeEvents` dans `context_injector_service.dart` (section "Événements récents") | 1 |
| C4 | Layer 4 factory : `life_event_questions_service.dart` — 5-8 questions/event, ARB 6 langues, validé `/autoresearch-compliance-hardener` | 4 |
| C5 | Enrichir Layer 3 : chaque simulator injecte `archetype`+`canton`+`couple` dans output narratif (5 calculators) | 3 |
| C6 | `new_job_screen` (libre passage + comparaison caisses) | 2 |
| C7 | housingSale + donation + countryMove(FATCA) refresh HumanTranslation | 3 |
| C8 | Device walkthrough 18 events (iPhone sim, cycle 7 étapes Wave C) | 2 |

## 7. Fichiers — créer / câbler / supprimer

**CRÉER** : `apps/mobile/lib/models/life_event_record.dart` · `apps/mobile/lib/services/life_event_questions_service.dart` · `services/backend/app/schemas/life_event_record.py` + migration Alembic · `apps/mobile/lib/screens/new_job_screen.dart` · ARB `lifeEventQuestion_<event>_<n>` × 18 × 5-8 × 6 langues.

**CÂBLER** (code existe, zéro/partiel call-site) : `widgets/coach/life_event_sheet.dart` → appelé depuis `aujourdhui_screen.dart` (capture sheet) + `coach_chat_screen.dart` (FAB). `services/coach/context_injector_service.dart` → `_buildRecentLifeEventsSection()`. `testament_invisible_widget`+`survivor_pension_widget` → référencés depuis `deces_proche_screen.dart`. `marriage_penalty_gauge` → output exposé au coach. `fiscal_service.dart` comparateur cantonal → déclencher sur event `cantonMove` pas sur canton "high-tax".

**SUPPRIMER/réconcilier** : `widgets/life_event_suggestions.dart` `buildLifeEventSuggestions()` (heuristiques age/income, ~180 LOC morts) → remplacer par lecture `recentLifeEvents`+lifecycle. Redirects dupliqués `/life-event/succession`, `/coach/succession` → garder 1 par event, aliases dans `screen_registry.dart`.

---

**Conclusion ops** : le backlog #1 n'est PAS d'écrire plus de simulators. C'est **C1 persister les events**, **C3 les injecter dans le coach**, **C4 construire Layer 4 QuestionsToAsk** — les 3 chantiers qui transforment MINT de "collection de calculators" en "moteur 4-couches" tel que décrit dans MINT_IDENTITY.md.
