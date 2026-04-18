# Panel C — Backend endpoints ↔ Flutter callers façade audit

> Date : 2026-04-18 — dev tip `17d91776`
> Scope : `services/backend/app/api/v1/endpoints/**/*.py` vs `apps/mobile/lib/**`
> Méthode : inventaire bidirectionnel + spot-check services backend orphelins
> Doctrine : `feedback_facade_sans_cablage_absolu.md` — endpoint shippé mais jamais appelé = façade

---

## Résumé exécutif

| Indicateur | Valeur |
|---|---|
| Fichiers routers backend | 60 |
| Endpoints backend totaux (≈) | 210 |
| Endpoints LIVE (Flutter caller confirmé) | 55 |
| Endpoints ORPHELINS (façade) | ~150 |
| Endpoints admin/webhooks/cron (acceptables sans Flutter) | ~15 |
| Paths Flutter → 404 backend (broken) | 0 |
| Façade P0 critique (business shippé jamais touché) | 5 clusters |
| Façade P1 dette (features latentes) | 8 clusters |
| Façade P2 legacy/future-work | 10+ clusters |

Le ratio **LIVE / SHIPPÉ ≈ 26 %**. Les trois quarts de la surface API backend n'est pas consommée par Flutter. C'est LE profil typique d'une codebase agentique : les endpoints ont été scaffoldés sprint par sprint (S31–S67 visibles dans les tags) sans branchement UI.

Les 5 clusters P0 : `/coach/narrative`+`/coach/greeting`+`/coach/score-summary`+`/coach/tip`+`/coach/premier-eclairage`, `/overview/me`, `/budget/me` CRUD, `/fri/*`, `/open-banking/*`. Tous shippés avec logique métier, certains avec schémas Pydantic complets, et **ZÉRO caller Flutter** au 17d91776.

Bonne nouvelle : **zéro broken path**. Aucun fichier Flutter n'essaie de hit un endpoint qui n'existe plus. La séquence inverse (Flutter → 404) est clean. La façade est unilatérale : backend shippé, Flutter pas câblé.

---

## Méthodo

1. `services/backend/app/api/v1/router.py` donne les 60 prefixes (`/auth`, `/profiles`, `/arbitrage`, …).
2. `grep @router.(get|post|put|delete|patch)` dans chaque `endpoints/*.py` → ~210 décorateurs.
3. `grep -rnE "ApiService\.(get|post|put|delete|patch|getText)\b" apps/mobile/lib` → 16 call-sites directs.
4. `grep -rnE "Uri\.parse.*baseUrl"` pour les clients qui montent l'URL eux-mêmes (household_service, document_service, rag_service, commitment_service, fresh_start_service, bank_import_service, coach_memory_service, coach_chat_api_service).
5. Mapping path Flutter → path backend. Tout ce qui est déclaré backend sans consommateur Flutter est flaggé.
6. Les paths de type `/coach/chat`, `/arbitrage/rente-vs-capital` qui apparaissent aussi comme **routes GoRouter** sont traités séparément : seul l'usage `http.post(Uri.parse($baseUrl/...))` ou `ApiService.xxx('/...')` compte comme caller.

---

## Inventory Flutter callers confirmés (LIVE)

| Path (method) | Flutter file:line | Via |
|---|---|---|
| GET `/health` (sondage multi-base) | `services/api_service.dart:156` | ensureReachableBaseUrl |
| POST `/auth/register` | `services/api_service.dart:410` | direct |
| POST `/auth/login` | `services/api_service.dart:435` | direct |
| POST `/auth/refresh` | `services/api_service.dart:203` + `services/auth_service.dart:123` | direct |
| POST `/auth/magic-link/send` | `services/api_service.dart:456` | direct |
| POST `/auth/magic-link/verify` | `services/api_service.dart:474` | direct |
| POST `/auth/apple/verify` | `services/api_service.dart:495` | direct |
| GET `/auth/me` | `services/api_service.dart:516` | direct |
| DELETE `/auth/account` | `services/api_service.dart:532` | direct |
| POST `/auth/password-reset/request` | `services/api_service.dart:547` | direct |
| POST `/auth/password-reset/confirm` | `services/api_service.dart:568` | direct |
| POST `/auth/email-verification/request` | `services/api_service.dart:588` | direct |
| POST `/auth/email-verification/confirm` | `services/api_service.dart:608` | direct |
| GET `/auth/admin/observability` | `services/api_service.dart:625` | getAdminObservability() |
| GET `/auth/admin/onboarding-quality` | `services/api_service.dart:631` | — |
| GET `/auth/admin/onboarding-quality/cohorts` | `services/api_service.dart:637` | — |
| GET `/auth/admin/cohorts/export.csv` | `services/api_service.dart:640` | exportAdminCohortsCsv |
| GET `/profiles/me` | `providers/coach_profile_provider.dart:189` + `providers/auth_provider.dart:703` | direct |
| POST `/onboarding/minimal-profile` | `services/api_service.dart:661` | direct |
| POST `/onboarding/premier-eclairage` | `services/api_service.dart:761` | direct |
| POST `/arbitrage/rente-vs-capital` | `services/api_service.dart:883` via `screens/arbitrage/rente_vs_capital_screen.dart:471` | direct |
| POST `/coach/chat` | `services/coach/coach_chat_api_service.dart:42` | direct |
| POST `/coach/sync-insight` | `services/memory/coach_memory_service.dart:127` | direct |
| DELETE `/coach/sync-insight/{id}` | `services/memory/coach_memory_service.dart:157` | direct |
| POST `/coach/commitment` | `services/commitment_service.dart:48` | direct |
| GET `/coach/commitment` | `services/commitment_service.dart:127` | direct |
| PATCH `/coach/commitment/{id}` | `services/commitment_service.dart:165` | direct |
| GET `/coach/fresh-start` | `services/fresh_start_service.dart:65` | direct |
| POST `/anonymous/chat` | `services/coach/coach_chat_api_service.dart:160` | direct |
| POST `/rag/query` | `services/rag_service.dart:197` | direct |
| POST `/rag/vision` | `services/rag_service.dart:290` | direct |
| POST `/documents/upload` | `services/document_service.dart:942` | multipart |
| POST `/documents/upload-statement` | `services/document_service.dart:985` | multipart |
| GET `/documents/` | `services/document_service.dart:1012` | list |
| DELETE `/documents/{id}` | `services/document_service.dart:1049` | direct |
| POST `/documents/scan-confirmation` | `services/document_service.dart:1108` | direct |
| POST `/documents/extract-vision` | `services/document_service.dart:1156, 1255` | direct |
| POST `/documents/premier-eclairage` | `services/document_service.dart:1203` | direct |
| GET `/household` | `services/household_service.dart:37` | direct |
| POST `/household/invite` | `services/household_service.dart:51` | direct |
| POST `/household/accept` | `services/household_service.dart:77` | direct |
| DELETE `/household/member/{id}` | `services/household_service.dart:103` | direct |
| PUT `/household/transfer` | `services/household_service.dart:125` | direct |
| POST `/bank-import/import` | `services/bank_import_service.dart:142` | multipart |
| POST `/sync/claim-local-data` | `services/api_service.dart:1140` | direct |
| GET `/billing/entitlements` | `services/subscription_service.dart:280` | direct |
| POST `/billing/apple/verify` | `services/api_service.dart:1171` + `services/ios_iap_service.dart:60` | direct |
| POST `/snapshots` | `services/snapshot_service.dart:163` | direct |
| GET `/snapshots` | `services/snapshot_service.dart:212` | direct |
| GET `/consents` | `services/consent/consent_service.dart:85` | direct |
| POST `/consents/grant` | `services/consent/consent_service.dart:95` | direct |
| POST `/consents/grant-nominative` | `services/document/third_party_flow.dart:47, 75` | via overlay |
| POST `/consents/{id}/revoke` | `services/consent/consent_service.dart:105` | direct |
| POST `/analytics/events` | `services/analytics_service.dart:263` | direct |
| GET `/analytics/summary` | `screens/admin_analytics_screen.dart:53` | admin only |
| GET `/analytics/funnel` | `screens/admin_analytics_screen.dart:54` | admin only |
| GET `/regulatory/constants` | `services/regulatory_sync_service.dart:69` | direct |
| GET `/regulatory/constants/{key}` | `services/regulatory_sync_service.dart:103` | direct |
| GET `/regulatory/freshness` | `services/regulatory_sync_service.dart:168` | direct |
| GET `/config/feature-flags` | `services/feature_flags.dart:119` | direct |

**~55 endpoints réellement branchés.**

---

## P0 — Endpoints façade business critique

### P0-1 — Cluster Coach narratif (5 endpoints morts)

Router : `services/backend/app/api/v1/endpoints/coach.py` avec prefix `/coach`.

| Endpoint | File:line | État Flutter |
|---|---|---|
| POST `/coach/narrative` | `coach.py:61` | aucun caller |
| POST `/coach/greeting` | `coach.py:87` | aucun caller |
| POST `/coach/score-summary` | `coach.py:107` | aucun caller |
| POST `/coach/tip` | `coach.py:127` | aucun caller |
| POST `/coach/premier-eclairage` | `coach.py:147` | aucun caller |

Pourquoi P0 : cluster "Coach Narrative S35" complet, services backend dédiés (`claude_coach_service`), schémas (`CoachNarrativeResponse`, `ComponentNarrativeResponse`). Tout le coach narratif Flutter utilise le FALLBACK local (`services/coach_narrative_service.dart` → `fallback_templates.dart`) ou le flux conversationnel `/coach/chat`. Le cluster "narrative" backend est 100 % façade, mais il existe un risque de confusion : un dev qui cherche "greeting coach" voit l'endpoint et pense que c'est câblé. **Collision notable avec `/coach/premier-eclairage` qui duplique `/onboarding/premier-eclairage` (live) et `/documents/premier-eclairage` (live)** — trois endpoints différents pour la même feature, seuls les deux derniers sont utilisés.

### P0-2 — `/overview/me` (ajouté Gate 0 fix, jamais câblé)

| Endpoint | File:line | État Flutter |
|---|---|---|
| GET `/overview/me` | `overview.py:426` | aucun caller |

MEMORY dit : "ROADMAP cite 8 sections". Service backend complet (`_build_identity`, `_build_income`, `_build_patrimoine`, `_build_prevoyance`, `_build_assurances_sociales`, `_build_dettes`, `_build_couple`, `_build_budget`) — 470 lignes de logique. **Zéro `/overview` grep dans Flutter, même pas dans `api_service.dart`.** Endpoint shippé mais UI « Mon argent » / dossier-first consomme uniquement `/profiles/me` + calculs locaux. Doctrine dossier-first post-2026-04-12 dit que c'est l'endpoint clef — donc ship bloquant pour la prochaine wave dossier.

### P0-3 — Cluster Budget backend (5 endpoints morts)

Router : `budget.py` prefix `/budget`.

| Endpoint | File:line | État Flutter |
|---|---|---|
| GET `/budget/me` | `budget.py:233` | aucun caller |
| PUT `/budget/me` | `budget.py:246` | aucun caller |
| POST `/budget/me/lines` | `budget.py:281` | aucun caller |
| DELETE `/budget/me/lines/{id}` | `budget.py:327` | aucun caller |
| POST `/budget/anomalies` | `budget.py:421` | aucun caller |

Le Flutter `apps/mobile/lib/domain/budget/budget_service.dart` est 100 % pur Dart (data locale, math locale, disclaimers locaux, source CSIAS). Les écrans `screens/budget/*` consomment `BudgetProvider` local. MEMORY dit "Budget CRUD mentionné Gate 0 ship". Le CRUD a été shippé backend mais **aucune route client ne synchronise**. Risque : si un user supprime l'app, tout le budget disparaît (c'est local Hive/SharedPrefs via provider).

### P0-4 — Cluster FRI (2 endpoints morts)

| Endpoint | File:line | État Flutter |
|---|---|---|
| POST `/fri/current` | `fri.py:73` | aucun caller |
| POST `/fri/simulate-action` | `fri.py:105` | aucun caller |

Financial Resilience Index — feature stratégique visible dans ARB (`reengagementTitleQuarterlyFri`, `financialFitnessTitle`). Service Flutter `financial_fitness_service.dart` et `financial_health_score_service.dart` existent mais **ne font aucun call HTTP**. Le FRI backend fournit `action prioritaire`, `seuil de confiance`, `disclaimer` — tout invisible côté UI. C'est le genre de P0 où l'utilisateur voit un score local calé à côté d'un backend déjà scoré qui sera juste jeté.

### P0-5 — Cluster Open Banking (9 endpoints morts)

Router : `open_banking.py` prefix `/open-banking`.

| Endpoint | File:line | État Flutter |
|---|---|---|
| GET `/open-banking/status` | `open_banking.py:125` | — |
| POST `/open-banking/consent` | `open_banking.py:158` | — |
| DELETE `/open-banking/consent/{id}` | `open_banking.py:190` | — |
| GET `/open-banking/consents` | `open_banking.py:217` | — |
| GET `/open-banking/accounts` | `open_banking.py:258` | — |
| GET `/open-banking/accounts/{id}/transactions` | `open_banking.py:300` | — |
| GET `/open-banking/accounts/{id}/balance` | `open_banking.py:355` | — |
| GET `/open-banking/summary` | `open_banking.py:385` | — |
| POST `/open-banking/categorize` | `open_banking.py:420` | — |

Flutter `services/open_banking_service.dart:136` explicite : `/// Open Banking Service — all logic is local (mock data).` **3 screens** (`open_banking/consent_screen.dart`, `open_banking_hub_screen.dart`, `transaction_list_screen.dart`) rendent de la data mock. Backend entier orphelin. C'est le cas d'école d'un cluster shippé en sprint "prévoir Open Finance" puis abandonné. Si l'équipe BYOB veut revenir dessus, le backend est là, ok. Mais en l'état c'est **de la surface d'attaque inutile** (consent, balance, transactions — zéro caller = surface d'exposition gratuite).

---

## P1 — Dette : features latentes (mortes côté Flutter, utilité future plausible)

Chaque cluster est scaffoldé, a des schémas, des services backend. Façade car aucun écran n'appelle aujourd'hui.

### P1-1 — Cluster Retirement (4 endpoints morts)
- POST `/retirement/avs/estimate` (`retirement.py:40`)
- POST `/retirement/lpp/compare` (`retirement.py:79`)
- POST `/retirement/budget` (`retirement.py:117`)
- GET `/retirement/checklist` (`retirement.py:158`)

Tous les calculs retraite Flutter passent par `financial_core/` local. Backend dédoublé.

### P1-2 — Cluster Fiscal canton (4 endpoints morts)
- POST `/fiscal/estimate` (`fiscal.py:37`)
- POST `/fiscal/compare` (`fiscal.py:76`)
- POST `/fiscal/move` (`fiscal.py:134`)
- POST `/fiscal/wealth-tax/estimate`, `/compare`, `/move`, `/church` (`wealth_tax.py:45,83,143,186`)

Flutter `services/fiscal_service.dart` : "Pure Dart service for cantonal tax comparison… Effective rates = total charge / gross income (chef-lieu, 2024-2026)". Zéro HTTP. Backend orphelin.

### P1-3 — Cluster LPP-deep (3 endpoints morts)
- POST `/lpp-deep/rachat-echelonne` (`lpp_deep.py:45`)
- POST `/lpp-deep/libre-passage` (`lpp_deep.py:101`)
- POST `/lpp-deep/epl` (`lpp_deep.py:164`)

Screens `lpp_deep/rachat_echelonne_screen.dart`, `libre_passage_screen.dart`, `epl_screen.dart` : toutes les calculs locales via `financial_core/lpp_calculator.dart`.

### P1-4 — Cluster 3a-deep (3 endpoints morts)
- POST `/3a-deep/staggered-withdrawal` (`pillar_3a_deep.py:42`)
- POST `/3a-deep/real-return` (`pillar_3a_deep.py:98`)
- POST `/3a-deep/compare-providers` (`pillar_3a_deep.py:146`)

Idem — screens existent, backend orphelin.

### P1-5 — Cluster Mortgage (5 endpoints morts)
- POST `/mortgage/affordability` (`mortgage.py:57`)
- POST `/mortgage/saron-vs-fixed` (`mortgage.py:111`)
- POST `/mortgage/imputed-rental` (`mortgage.py:175`)
- POST `/mortgage/amortization` (`mortgage.py:228`)
- POST `/mortgage/epl-combined` (`mortgage.py:298`)

Screens `screens/mortgage/*` utilisent calculs locaux, zéro HTTP.

### P1-6 — Cluster Independants (5 endpoints morts)
- POST `/independants/avs-cotisations`, `/ijm-simulation`, `/3a-independant`, `/dividende-vs-salaire`, `/lpp-volontaire` (`independants.py:43,75,110,145,189`)

Screens `screens/independants/*` idem.

### P1-7 — Cluster Life Events (6 endpoints morts)
- POST `/life-events/divorce/simulate` (`life_events.py:47`)
- GET `/life-events/divorce/checklist` (`life_events.py:85`)
- POST `/life-events/succession/simulate` (`life_events.py:168`)
- GET `/life-events/succession/checklist` (`life_events.py:208`)
- POST `/life-events/donation/simulate` (`life_events.py:291`)
- POST `/life-events/housing-sale/simulate` (`life_events.py:341`)

Zéro caller Flutter. Service `donation_service.dart`, etc. sont tous purs Dart.

### P1-8 — Cluster Notifications server-side (3 endpoints morts)
- POST `/notifications/calendar` (`notifications.py:65`)
- POST `/notifications/events` (`notifications.py:90`)
- POST `/notifications/milestones` (`notifications.py:116`)

Wave A-MINIMAL (commit 17d91776 merge) vient de câbler `NotificationsWiringService` côté Flutter — **mais via scheduler local, pas via backend**. Backend orphelin mais c'est explicitement "retention/weekly killed" dans MEMORY. Noter pour cohérence future.

---

## P2 — Legacy / YAGNI / futur

### P2-1 — Family (14 endpoints)
Cluster géant `family.py` : mariage/compare, mariage/regime, mariage/survivant, mariage/checklist, naissance/conge, naissance/allocations, naissance/impact-fiscal, naissance/career-gap, naissance/checklist, concubinage/compare, concubinage/succession, concubinage/checklist (14 endpoints, `family.py:66-437`). Flutter `family_service.dart` local. 14 endpoints morts — pose la question : MINT a-t-il vraiment besoin d'une API family côté serveur ou tout doit rester local ?

### P2-2 — Expat / frontalier (10 endpoints)
`expat.py:58-377` : source-tax, quasi-resident, 90-day-rule, social-charges, lamal-option, forfait-fiscal, double-taxation, avs-gap, departure-plan, tax-comparison. Flutter `services/expat_service.dart:42` commente explicitement : "For precise calculations, the backend endpoint /expat/frontalier/source-tax should be called" — mais **personne ne l'appelle**. Connu mais orphelin.

### P2-3 — Segments (3 endpoints)
POST `/segments/gender-gap/simulate`, `/frontalier/simulate`, `/independant/simulate` (`segments.py:42,80,123`). Zéro caller.

### P2-4 — Scenario narration (2 endpoints)
POST `/scenario/narrate`, `/scenario/refresh-check` (`scenario_narration.py:33,80`). Zéro caller.

### P2-5 — Precision, confidence, document_parser (10 endpoints)
- `precision.py` : help/{field}, validate, smart-defaults, prompts (4 endpoints, `69-206`)
- `confidence.py` : score, enrichments, gates (3 endpoints, `95-179`)
- `document_parser.py` : parse, confidence-delta, field-impact/{type} (3 endpoints, `94-227`)

Widgets `widgets/precision/smart_default_indicator.dart` existent mais consomment du local uniquement. Aucun call HTTP.

### P2-6 — Reengagement (5 endpoints)
`reengagement.py:42-203` : messages, consent (GET + GET /me + PATCH), byok-detail. ARB contient les strings reengagement. Jamais câblé.

### P2-7 — Disability, unemployment, first-job, next-steps, job-comparison (8 endpoints)
- POST `/disability-gap/compute`
- POST `/unemployment/calculate`, GET `/checklist`, GET `/orp-link/{canton}`
- POST `/first-job/analyze`, GET `/checklist`
- POST `/next-steps/calculate`
- POST `/job-comparison/compare`, GET `/checklist`

Tous screen-less ou backed par logique locale (unemployment → `unemployment_service.dart` local).

### P2-8 — Assurances (2 endpoints)
- POST `/assurances/lamal/optimize` (`assurances.py:39`)
- POST `/assurances/coverage/check` (`assurances.py:97`)

Screens `screens/assurances/*` locaux.

### P2-9 — Educational content (3 endpoints)
- GET `/educational-content/phase/{phase}`
- GET `/educational-content`
- GET `/educational-content/{question_id}`

Flutter `EducationalInsertService` est 100 % local (18 fichiers MD dans `education/inserts/`).

### P2-10 — Communes (4 endpoints)
- GET `/communes/search`, `/cheapest`, `/canton/{code}`, `/{npa}` (`communes.py:46-188`)

Flutter `data/commune_data.dart` = data statique locale. Backend dédoublé.

### P2-11 — Profile CRUD legacy (3 endpoints)
- POST `/profiles` (`profiles.py:99`) — wrappé par `ApiService.createProfile()` **marqué `@Deprecated`** line 1215 `api_service.dart`. Aucun caller.
- GET `/profiles/{profile_id}` (`profiles.py:168`) — zéro caller.
- PATCH `/profiles/{profile_id}` (`profiles.py:229`) — zéro caller.

Toutes les updates profile passent par `coach_profile_provider.updateProfile()` local. Pas de PATCH backend. Seul `GET /profiles/me` est live.

### P2-12 — Sessions (2 endpoints)
- POST `/sessions` (`sessions.py:22`) — wrappé par `ApiService.createSession()` jamais appelé
- GET `/sessions/{id}/report` (`sessions.py:118`) — zéro caller

`SessionReport` model Flutter existe mais c'est embedded dans des flows conversationnels → jamais instancié via HTTP.

### P2-13 — Recommendations (1)
POST `/recommendations/preview` (`recommendations.py:20`). Zéro caller.

### P2-14 — Scenarios (2)
POST `/scenarios`, GET `/scenarios/{profile_id}` (`scenarios.py:66,102`). Zéro caller.

### P2-15 — Partners (2)
GET `/partners`, POST `/partners/click` (`partners.py:56,62`). Zéro caller. Affiliate service Flutter (`affiliate_service.dart`) 100 % local.

### P2-16 — Snapshots secondaires (2)
- DELETE `/snapshots` (`snapshots.py:150`)
- GET `/snapshots/evolution` (`snapshots.py:168`)

`snapshot_service.dart` utilise POST + GET `?limit=50` mais pas DELETE ni `/evolution`.

### P2-17 — Documents secondaires (2)
- GET `/documents/{id}` (`documents.py:631`) — detail endpoint, zéro caller
- POST `/documents/upload-statement/preview` (`documents.py:835`) — zéro caller

### P2-18 — Consents secondaires (2)
- GET `/consents/{id}/receipt` (`consents.py:146`) — zéro caller
- GET `/consents/verify-chain` (`consents.py:169`) — zéro caller

### P2-19 — Coaching tips (1)
- POST `/coaching/tips` (`coaching.py:30`) — Flutter `coaching_service.dart:12` commentaire explicite : "All logic is local (no backend call)". 100 % façade.

### P2-20 — Knowledge (1)
- GET `/knowledge/status` (`knowledge.py:21`). Zéro caller.

### P2-21 — Debt prevention (3)
- POST `/debt/ratio` (`debt_prevention.py:41`)
- POST `/debt/repayment-plan` (`debt_prevention.py:85`)
- GET `/debt/resources/{canton}` (`debt_prevention.py:149`)

Toutes les routes `/debt/*` dans `app.dart` sont GoRouter, pas HTTP. `debt_prevention_service.dart` pur Dart.

### P2-22 — Household admin (2)
- DELETE `/household/dissolve` (`household.py:99`)
- POST `/household/admin/override-cooldown` (`household.py:110`)

`household_service.dart` ne wrappe que getHousehold/invite/accept/revokeMember/transfer. Les 2 admin endpoints zéro caller.

### P2-23 — RAG ingest/status (2)
- POST `/rag/ingest` (`rag.py:292`)
- GET `/rag/status` (`rag.py:349`)

Méthode `RagService.getStatus()` déclarée ligne 349 mais **jamais invoquée**. Ingest idem.

### P2-24 — Arbitrage annexes (4)
- POST `/arbitrage/allocation-annuelle` (`arbitrage.py:161`)
- POST `/arbitrage/location-vs-propriete` (`arbitrage.py:237`)
- POST `/arbitrage/rachat-vs-marche` (`arbitrage.py:302`)
- POST `/arbitrage/calendrier-retraits` (`arbitrage.py:361`)

Seul `/arbitrage/rente-vs-capital` est live. Les 4 autres scaffolds morts.

### P2-25 — Privacy (4)
- POST `/privacy/export`, `/privacy/delete`, GET `/privacy/consent-status`, POST `/privacy/consent-update` (`privacy.py:53,243,321,371`). Zéro caller. nLPD compliance exposée mais inaccessible UI.

---

## Endpoints admin/webhooks/cron (pas de caller Flutter = acceptable)

Ces endpoints N'ONT PAS VOCATION à être appelés par Flutter. Non flagué.

- POST `/auth/admin/purge-unverified` (`auth.py:827`) — cron
- POST `/admin/flags/{flag}`, GET `/admin/flags/{flag}`, GET `/admin/audit` (`admin.py`) — admin dashboard autre
- POST `/billing/checkout/stripe`, `/billing/portal/stripe` (`billing.py:64,83`) — web-only
- POST `/billing/webhooks/stripe` (`billing.py:100`) — Stripe server-to-server
- POST `/billing/webhooks/apple` (`billing.py:210`) — Apple server-to-server
- POST `/billing/debug/activate` (`billing.py:114`) — `include_in_schema=False`, dev only
- GET `/health`, `/health/live`, `/health/ready` — probes

---

## P0 — Broken paths (Flutter → 404)

**Aucun broken path détecté.** Tous les paths référencés par Flutter existent backend. Le couplage sens client→serveur est propre. La façade est unidirectionnelle : backend shippé sans consommateur.

---

## Services backend orphelins (spot-check)

Analyse rapide, pas exhaustive. Services consommés par endpoints ne sont PAS orphelins.

**Services clairement LIVE** (importés par au moins un endpoint live) :
- `coach/claude_coach_service.py` → `/coach/chat`
- `coach/coach_tools.py` → idem
- `rules_engine.py` → `/regulatory/*`
- `auth_service.py`, `auth_admin_service.py`, `magic_link_service.py` → `/auth/*`
- `billing_service.py` → `/billing/*`
- `document_vision_service.py` → `/documents/extract-vision`
- `document_third_party.py` → `/consents/grant-nominative`
- `household_service.py` → `/household/*`
- `bank_import_service.py` → `/bank-import/import`
- `privacy_service.py` → `/privacy/*` (mais endpoints façade)

**Services probablement orphelins (endpoint façade → service dormant)** :
- `divorce_simulator.py` → seulement `/life-events/divorce/*` (façade)
- `succession_simulator.py` → `/life-events/succession/*` + `family/concubinage/succession` (façade)
- `donation_service.py` → `/life-events/donation/simulate` (façade)
- `housing_sale_service.py` → `/life-events/housing-sale/simulate` (façade)
- `gender_gap_service.py` → `/segments/gender-gap/simulate` (façade)
- `frontalier_service.py` → `/expat/frontalier/*` + `/segments/frontalier/simulate` (façade)
- `independant_service.py` → `/independants/*` + `/segments/independant/simulate` (façade)
- `lamal_franchise_service.py` → `/assurances/lamal/optimize` (façade)
- `coverage_checklist_service.py` → `/assurances/coverage/check` (façade)
- `next_steps_service.py` → `/next-steps/calculate` (façade)
- `disability_gap_service.py` → `/disability-gap/compute` (façade)
- `job_comparator.py` → `/job-comparison/*` (façade)
- `educational_content_service.py` → `/educational-content/*` (façade)
- `coaching_engine.py` → `/coaching/tips` (façade)
- `anomaly_detection_service.py` → `/budget/anomalies` (façade)

Tous ces services sont des chandeliers éteints. Le code backend a été écrit, testé probablement (cf. tests en `services/backend/tests/`), puis jamais consommé. Dette froide mais non bloquante.

**Utilitaires non-API (normal sans endpoint)** :
- `audit_service.py`, `slo_monitor.py`, `idempotency.py`, `flags_service.py`, `feature_flags.py`, `email_service.py`, `document_memory_service.py`, `profile_bootstrap.py` → acceptables, utility internes.

---

## Schémas Pydantic orphelins

Spot-check seulement. Schémas utilisés par endpoint façade = schémas façade par extension.

**Schémas fichiers probablement orphelins** (correspondance 1:1 avec endpoints façade) :
- `schemas/coaching.py` → endpoint façade
- `schemas/disability_gap.py` → endpoint façade
- `schemas/job_comparison.py` → endpoint façade
- `schemas/life_events.py` → endpoint façade
- `schemas/next_steps.py` → endpoint façade
- `schemas/notifications.py` → endpoint façade
- `schemas/pillar_3a_deep.py` → endpoint façade
- `schemas/lpp_deep.py` → endpoint façade
- `schemas/precision.py` → endpoint façade
- `schemas/recommendation.py` → endpoint façade
- `schemas/reengagement.py` → endpoint façade
- `schemas/retirement.py` → endpoint façade
- `schemas/scenario.py` → endpoint façade
- `schemas/scenario_narration.py` → endpoint façade
- `schemas/segments.py` → endpoint façade
- `schemas/unemployment.py` → endpoint façade
- `schemas/wealth_tax.py` → endpoint façade
- `schemas/expat.py` → endpoint façade
- `schemas/family.py` → endpoint façade
- `schemas/fiscal.py` → endpoint façade
- `schemas/fri.py` → endpoint façade
- `schemas/mortgage.py` → endpoint façade
- `schemas/independants.py` → endpoint façade
- `schemas/educational_content.py` → endpoint façade
- `schemas/assurances.py` → endpoint façade
- `schemas/debt_prevention.py` → endpoint façade
- `schemas/document_parser.py` → endpoint façade
- `schemas/partner.py` → endpoint façade
- `schemas/commune.py` → endpoint façade
- `schemas/privacy.py` → endpoint façade
- `schemas/open_banking.py` → endpoint façade (P0)
- `schemas/coach.py` → narrative endpoints façade (P0)
- `schemas/session.py` → endpoint façade
- `schemas/voice_cursor.py` → utilisé en tests uniquement, pas endpoint

**Schémas LIVE** :
- `schemas/auth.py`, `schemas/profile.py`, `schemas/document.py`, `schemas/document_scan.py`, `schemas/document_understanding.py`, `schemas/coach_chat.py`, `schemas/anonymous_chat.py`, `schemas/analytics.py`, `schemas/audit.py` (si admin live), `schemas/bank_import.py`, `schemas/billing.py`, `schemas/common.py`, `schemas/consent_receipt.py`, `schemas/onboarding.py` (premier-eclairage + minimal-profile), `schemas/snapshots.py`, `schemas/household.py`, `schemas/rag.py`, `schemas/enhanced_confidence.py`, `schemas/arbitrage.py` (partial — seul rente-vs-capital live), `schemas/response_card.py`.

---

## Suspect endpoints revérifiés (du brief)

| Endpoint | Statut | Note |
|---|---|---|
| `/overview/me` | **FAÇADE P0** | Shippé Gate 0, zéro caller |
| `/profiles/me` | LIVE sain | `coach_profile_provider.dart:189` + `auth_provider.dart:703` |
| `/coach/chat` | LIVE sain | `coach_chat_api_service.dart:42` |
| `/coach/sync-insight` (POST + DELETE) | LIVE | `coach_memory_service.dart:127,157` |
| `/coach/commitment/*` | LIVE | `commitment_service.dart` |
| `/coach/fresh-start` | LIVE | `fresh_start_service.dart:65` |
| `/coach/narrative`, `/greeting`, `/score-summary`, `/tip`, `/premier-eclairage` | **FAÇADE P0** | Cluster coach narrative orphelin |
| `/budget/*` (5) | **FAÇADE P0** | Budget CRUD Gate 0 shippé, Flutter 100 % local |
| `/documents/upload`, `/upload-statement`, `/scan-confirmation`, `/extract-vision`, `/premier-eclairage` | LIVE | `document_service.dart` |
| `/documents/{id}` detail | FAÇADE P2 | Zéro caller |
| `/documents/upload-statement/preview` | FAÇADE P2 | Zéro caller |
| `/notifications/*` (3) | FAÇADE P1 | Wave A utilise scheduler local, pas backend |

---

## Observations transversales

**Pattern principal** : tout ce qui concerne les calculs financiers (retirement, LPP, 3a, fiscal, mortgage, expat, family) est **dédoublé**. Backend a une implémentation, Flutter aussi (`financial_core/`). CLAUDE.md §2 dit "Financial Core Library… single source of truth" et "Backend = source of truth for constants and formulas. Flutter mirrors, never invents." — mais en pratique Flutter CALCULE tout localement et le backend n'est jamais sollicité. La vraie single-source-of-truth est donc `financial_core/` Dart, pas le backend.

**Implication doctrinale** : soit on accepte que Flutter est autoritaire et on supprime ~40 endpoints calculatoires, soit on bascule les screens (rachat LPP, 3a, fiscal, mortgage) pour appeler le backend. L'état intermédiaire actuel (les deux existent, seul le local est consommé) est la pire des trois options : double maintenance, drift garanti.

**Surface d'exposition** : 150 endpoints non appelés mais montés dans `router.py` = 150 routes accessibles en production (`mint-production-3a41.up.railway.app/api/v1/...`). Chacune est authentifiée (require_current_user sur la plupart) mais reste une surface d'attaque et de test coverage qui pèse sur la CI.

**Collision de noms** : `/coach/premier-eclairage` (façade) vs `/onboarding/premier-eclairage` (live) vs `/documents/premier-eclairage` (live). Trois endpoints, trois schémas, un seul concept métier. À clarifier.

**Profile CRUD legacy** : `POST /profiles`, `PATCH /profiles/{id}` non appelés — toute update profile est locale uniquement (CoachProfile). Le `/profiles/me` ne fait que GET, jamais PATCH. Conséquence : si on croit que le backend a le dernier état profile, on se trompe — l'app est la source, le backend stocke un snapshot qui n'est jamais mis à jour après onboarding. À vérifier avec panel couvrant profile persistence.

**Zéro rupture client** : aucun path Flutter n'appelle un endpoint disparu. C'est rassurant : la façade est unidirectionnelle, pas de crash runtime.

---

## Recommandations (hors scope audit, pour info)

1. Décider : backend calculs ou Flutter calculs ? Ne pas maintenir les deux. Option A : supprimer 40+ endpoints calculatoires (P1+P2). Option B : brancher Flutter sur backend (risque latence, régression tests).
2. Câbler `/overview/me` côté Flutter maintenant ou retirer le endpoint. Il consomme des ressources et teste inutilement.
3. Câbler `/budget/me` CRUD si on veut vraiment que le budget survive à la désinstall (ce qui est l'intention Gate 0).
4. Retirer le cluster `/coach/narrative` S35 complet. Le flux conversationnel `/coach/chat` le remplace — ne pas laisser 5 endpoints alternatifs qui prêtent à confusion.
5. Retirer `POST /profiles` + `PATCH /profiles/{id}` OU brancher `CoachProfile.save()` via PATCH. L'absence de sync est un P0 fonctionnel silencieux.
6. Clore `/open-banking/*` (surface d'attaque inutile) ou scheduler ingestion open-finance.
