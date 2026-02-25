# FEUILLE DE ROUTE MINT — Audit vs Code Reel

## Contexte

Un audit strategique externe a identifie 5 problemes structurels et propose une strategie SLM embarque. Ce plan confronte chaque recommandation avec l'etat reel du codebase (explore le 25.02.2026) et definit des actions concretes implementables.

---

## ETAT REEL DU CODE (Faits vs Audit)

### Chiffres cles du codebase

| Metrique | Valeur |
|---|---|
| Fichiers Dart (Flutter) | 345 dans `apps/mobile/lib/` |
| Fichiers Python (Backend) | 252 dans `services/backend/app/` |
| Tests backend | 1965 passed, 0 failed, 71 fichiers test |
| Tests Flutter | 130 fichiers test, 1600+ tests |
| Financial core | 13 fichiers, 5716 lignes, 109 tests dedies |
| i18n | 6 langues (FR/DE/EN/IT/ES/PT), ~11'082 strings/langue |
| Educational inserts | 39 fichiers FR + variantes DE |
| Documentation | 63 fichiers .md (15 root + 40 docs + 8 ADR) |
| Screens | 22 repertoires dans `screens/` |
| Ecrans coach | 5 ecrans (dashboard 5147L, agir 2600L, checkin 1660L, chat 921L, refresh 974L) |
| Arbitrage | 5 comparateurs (rente-vs-capital, allocation, location-vs-propriete, rachat-vs-marche, calendrier) |
| OCR types | 8 types documents (LPP cert, salaire, 3a, assurance, bail, LAMal, releve bancaire, autre) |

### Ce que l'audit a raison de souligner

| Point audit | Confirme par le code | Detail |
|---|---|---|
| Doc sprawl (~150 pages) | PARTIELLEMENT — 63 .md hors inserts educatifs, bien organises mais volumieux | `docs/` (40 fichiers), `decisions/` (8), `visions/` (7), root (15) |
| BYOK = friction | OUI — `coach_llm_service.dart` requiert API key | L.28-37: `LlmConfig` avec `apiKey` obligatoire |
| Pas d'Android | OUI — `apps/mobile/android/` n'existe pas | iOS only (Podfile, Runner.xcodeproj) |
| Paywall desactivee | OUI — `subscription_service.dart:88` mock coach tier | `TODO: restore paywall gate before production launch` |
| Pas de SLM | OUI — zero dep MediaPipe/llama.cpp dans pubspec.yaml | Aucun package AI on-device |
| Pas de beta | OUI — zero config TestFlight/Play Store | Pas de provisioning profiles, pas de CI/CD |

### Ce que l'audit sous-estime massivement

| Point | Realite code | Impact |
|---|---|---|
| Arbitrage engine | 5 COMPARATEURS COMPLETS — `arbitrage_engine.dart` (1803L) + backend (2587L) + 5 ecrans Flutter | N'est pas a planifier, c'est livre |
| Onboarding | DOUBLE PATH — minimal 3-input (410L) + advisor complet (2717L) + chiffre choc (408L) + enrichment (653L) | Plus avance que ce que l'audit suggere |
| Coach dashboard | 5147 LIGNES — 2 etats (profil/pas profil), score gauge, trajectoire 3 scenarios, pulse, tips | Dashboard "vivant" deja construit |
| Fallback templates | FULL IMPL — `fallback_templates.dart` (126L) + `compliance_guard.py` (307L) + `hallucination_detector.py` (147L) | 4 composants narratifs deterministes fonctionnels |
| OCR pipeline | FULL IMPL — Docling backend + 4 parsers locaux (avs, lpp, tax, models) + 8 types docs | Scan certificat LPP = premium feature deja codee |
| Monetisation | FULL IMPL — Stripe + Apple IAP + billing backend (endpoints, webhooks, entitlements) + 11 features gatees | Infrastructure complete, manque activation |
| PDF export | FULL IMPL — `pdf_service.dart` (58KB+), rapport session A4, pagine, brande | Export PDF = premium feature prete |
| Financial core | 13 fichiers, 5716L, 109 tests — Monte Carlo, Bayesian, Tornado, Withdrawal Sequencing | Moteur stochastique complet |
| i18n | 6 langues, ~11K strings chacune, TOUTES REMPLIES | Pas de stubs, vrais contenus traduits |

---

## ACTIONS CONCRETES — 90 jours

### MOIS 1 : SHIP (Semaines 1-4)

#### Action 1.1 — Consolider la documentation (2 jours)
**Probleme**: 134 fichiers .md, agents perdent 30% de contexte a les lire.
**Action**:
- Archiver 30+ fichiers `docs/WIZARD_*.md` (6 fichiers), `docs/EMPLOYMENT_STATUS_*.md` (3), les changelogs et logs d'execution dans `docs/archive/`
- Fusionner `docs/BLUEPRINT_COACH_AI_LAYER.md` + `docs/MINT_COACH_VIVANT_ROADMAP.md` + `docs/UX_REDESIGN_COACH.md` → un seul `docs/COACH_SPEC.md`
- Fusionner `docs/PLAN_ACTION_10_CHANTIERS.md` + `docs/DELIVERY.md` → `docs/ROADMAP.md`
- Garder `CLAUDE.md` (bible technique), `docs/ROADMAP.md`, `docs/COMPLIANCE.md` (nouveau, extrait de visions/vision_compliance.md + LEGAL_RELEASE_CHECK.md)
- **Fichiers**: `docs/*.md` (archiver ~25 fichiers, fusionner ~8)

#### Action 1.2 — Activer le paywall (1 jour)
**Probleme**: `subscription_service.dart:88` est en mock `coach` tier.
**Action**:
- Changer `tier: SubscriptionTier.coach` → `tier: SubscriptionTier.free` dans `subscription_service.dart`
- Verifier que `hasAccess(CoachFeature)` gate correctement chaque ecran premium
- Implementer le trial flow (14 jours, deja configure dans `trialDurationDays`)
- **Fichiers**: `apps/mobile/lib/services/subscription_service.dart`

#### Action 1.3 — Creer le projet Android (2 jours)
**Probleme**: `apps/mobile/android/` n'existe pas.
**Action**:
- `flutter create --platforms android .` dans `apps/mobile/`
- Configurer `applicationId: ch.mint.coach`
- Aligner `minSdkVersion: 24` (Android 7+), `targetSdkVersion: 34`
- Configurer signing pour debug/release
- **Fichiers**: `apps/mobile/android/` (nouveau)

#### Action 1.4 — TestFlight + Play Store internal track (3 jours)
**Probleme**: Zero config beta.
**Action**:
- iOS: configurer App Store Connect, provisioning profiles, TestFlight group
- Android: configurer Google Play Console, internal testing track
- Configurer bundle ID `ch.mint.coach` sur les deux platforms
- Build pipeline minimal (script shell ou Codemagic free tier)
- **Fichiers**: `apps/mobile/ios/Runner.xcodeproj/`, `apps/mobile/android/app/build.gradle`

#### Action 1.5 — Beta 20-30 utilisateurs (continu)
**Probleme**: 0 utilisateurs reels.
**Action**:
- Distribuer via TestFlight/Play Store internal
- Instrumenter 3 metriques: onboarding completion rate, time-to-chiffre-choc, retention J7
- Feedback form integre (simple Google Form ou Typeform)
- PAS de SLM, PAS de LLM — templates statiques du `coach_narrative_service.dart` suffisent

---

### MOIS 2 : SLM ON-DEVICE (Semaines 5-8)

#### Action 2.1 — Integrer Gemma 3n 4B E4B via MediaPipe LLM Inference (5 jours)
**Choix**: Gemma 3n 4B E4B (Google, optimise mobile, fev 2026).
- Avantages vs Gemma 3n 4B E4B: meilleure perf/watt, optimise NPU/GPU mobiles, support vision (OCR futur potentiel), architecture "efficient 4B" qui tourne comme un 2B en latence
- Risque: modele plus recent, moins battle-tested. Mitige par ComplianceGuard + fallback templates
- Taille estimee: ~2.3 GB en INT4

**Prerequis**: Google MediaPipe pour Flutter est operationnel (Flutter FFI).
**Action**:
- Ajouter dep `google_mediapipe` dans `pubspec.yaml` (ou FFI directe vers `mediapipe_genai`)
- Creer `apps/mobile/lib/services/slm/slm_engine.dart`:
  - `init()` — charger modele depuis stockage local
  - `generate(prompt, maxTokens)` → `Stream<String>`
  - `isAvailable()` → check RAM/device capability + espace disque
  - `dispose()` — liberer memoire
- Download separe au premier lancement (pas dans le bundle app)
- Bonus futur: la capacite vision de Gemma 3n peut servir pour du post-processing OCR directement on-device (eliminerait la dependance au backend Docling pour les scans simples)
- **Fichiers nouveaux**: `apps/mobile/lib/services/slm/slm_engine.dart`, `apps/mobile/lib/services/slm/slm_download_service.dart`, `apps/mobile/lib/services/slm/compliance_guard.dart`

#### Action 2.2 — ComplianceGuard post-processing (2 jours)
**Action**:
- Creer `compliance_guard.dart` dans `services/slm/`:
  - Filtrer termes bannis (garanti, certain, assure, sans risque, optimal, meilleur, parfait)
  - Injecter disclaimer si absent
  - Verifier que zero montant/chiffre n'est genere par le SLM (seuls les chiffres du `financial_core` sont autorises)
  - Fallback vers template statique si le SLM echoue ou est trop lent (>5s)
- **REUTILISER** la logique existante de:
  - `services/backend/app/services/coach/compliance_guard.py` (307L) — regles Python, porter en Dart
  - `services/backend/app/services/coach/hallucination_detector.py` (147L) — detection hallucinations
  - `coach_llm_service.dart` L.150+ — filtrage termes bannis cote Flutter
  - `apps/mobile/lib/services/coach/fallback_templates.dart` (126L) — 4 composants (greeting, score_summary, tip_narrative, chiffre_choc_reframe)
- **Fichiers**: `apps/mobile/lib/services/slm/compliance_guard.dart` (nouveau, porte depuis Python)

#### Action 2.3 — Brancher le SLM sur le CoachNarrativeService (3 jours)
**Action**:
- Modifier `coach_narrative_service.dart` pour ajouter un 3eme mode:
  - Mode 1: BYOK → LLM cloud (existant)
  - Mode 2: Templates statiques (existant)
  - **Mode 3: SLM on-device** (nouveau)
- Priorite: SLM > Templates > BYOK (inverse de l'actuel)
- 5 prompts pre-optimises:
  1. Greeting personnalise (<30 tokens)
  2. Score narration (<80 tokens)
  3. Tip contextuel (<100 tokens)
  4. Reformulation chiffre choc (<60 tokens)
  5. Explication educative (<150 tokens)
- **Fichiers modifies**: `apps/mobile/lib/services/coach_narrative_service.dart`

#### Action 2.4 — UI de download du modele (2 jours)
**Action**:
- Ecran settings: toggle "Coach IA embarque" avec indicateur de download
- Progress bar pendant le telechargement (2.3 GB)
- Gestion de l'espace disque (avertissement si <5 GB libres)
- **Fichiers**: `apps/mobile/lib/screens/settings/` (modifier ecran settings existant)

#### Action 2.5 — Tests SLM (2 jours)
**Action**:
- Tests unitaires pour `compliance_guard.dart` (termes bannis, disclaimer, fallback)
- Tests d'integration pour le flow SLM → ComplianceGuard → CoachNarrative
- Mock du SLM engine pour les tests (pas de modele reel en CI)
- **Fichiers**: `apps/mobile/test/services/slm/` (nouveaux)

---

### MOIS 3 : MONETISER & DISTRIBUER (Semaines 9-12)

#### Action 3.1 — Activer Stripe + Apple IAP en production (3 jours)
**Prerequis**: Backend `billing.py` existe deja, `ios_iap_service.dart` existe.
**Action**:
- Configurer Stripe account production + webhook URL
- Configurer Apple IAP product `ch.mint.coach.monthly` dans App Store Connect
- Tester le flow complet: free → paywall → paiement → coach tier active
- Verifier `entitlements` endpoint retourne les bonnes features
- **Fichiers**: `services/backend/app/api/v1/endpoints/billing.py`, `apps/mobile/lib/services/ios_iap_service.dart`, `apps/mobile/lib/services/subscription_service.dart`

#### Action 3.2 — Paywall UX ancree sur la valeur (2 jours)
**Action**:
- Ecran paywall qui montre la valeur decouverte AVANT de demander le paiement:
  - "Tu pourrais economiser ~CHF X en impots" (calcule par `financial_core`)
  - "Ton 2eme pilier pourrait gagner CHF Y avec un rachat" (idem)
- Free = estimations (confiance 25-40%), Coach = donnees reelles (scan LPP, haute confiance)
- Pricing: 4.90 CHF/mois ou 39 CHF/an (ajouter plan annuel)
- **Fichiers**: nouveau screen `apps/mobile/lib/screens/subscription/paywall_screen.dart`

#### Action 3.3 — App Store / Play Store submission (3 jours)
**Action**:
- Preparer les assets (screenshots, description, privacy policy)
- Privacy policy: mettre en avant "zero donnee financiere ne quitte le device" (SLM argument)
- Soumettre iOS + Android
- **Fichiers**: metadata, pas de code

#### Action 3.4 — B2B pilot prep (continu)
**Action**:
- Creer un landing page simple (pas dans l'app)
- Preparer une demo pour 2-3 PME romandes
- Pricing B2B: 5-15 CHF/employe/an (deja defini dans `docs/BUSINESS_MODEL.md`)

---

## ARCHITECTURE SLM RECOMMANDEE

```
financial_core/ (calculs deterministes — NE CHANGE PAS)
       |
       v
CoachContext {scores, ratios, flags} — PAS de montants bruts
       |
       v
┌─────────────────────────────────┐
│  SLM Engine (on-device)         │
│  Gemma 3n 4B E4B INT4 (~2.3 GB)   │
│  via MediaPipe LLM Inference    │
│                                 │
│  5 prompts courts:              │
│  greeting, score, tip,          │
│  chiffre_choc, education        │
└─────────────┬───────────────────┘
              |
              v
   ComplianceGuard (post-process)
   - Filtre termes bannis
   - Injecte disclaimer
   - Verifie zero montant genere
              |
              v
   Fallback → templates statiques
   (si SLM indisponible/lent)
              |
              v
   [Optionnel] BYOK cloud → deep Q&A
```

**Regle d'or**: Le SLM ne calcule JAMAIS. Il narrate. Tous les chiffres viennent de `financial_core/`.

---

## CE QU'ON NE FAIT PAS (et pourquoi)

| Idee | Decision | Raison |
|---|---|---|
| Fine-tuning du SLM | Reporter | Gemma 3n 4B E4B est suffisant en zero-shot pour des prompts courts en FR. Fine-tuning quand on a du feedback utilisateur reel. |
| RAG local on-device | Reporter | Le corpus educatif (40 inserts) est petit, injectible directement dans le prompt. RAG = complexite inutile a ce stade. |
| Mistral 7B | Non | Trop lourd (5 GB RAM). Gemma 3n 4B E4B = meilleur compromis taille/qualite FR. |
| Refonte complete de l'onboarding | Non | `onboarding_minimal_screen.dart` fonctionne deja (3 inputs → chiffre choc). Iterer avec du feedback reel. |
| 16 sprints supplementaires avant launch | Non | La base est solide (4100+ tests, 13 calculators, 18 life events). Ship et itere. |

---

## FICHIERS CRITIQUES A MODIFIER

| Fichier | Action | Sprint |
|---|---|---|
| `apps/mobile/lib/services/subscription_service.dart` | Activer paywall (L.88) | Mois 1 |
| `apps/mobile/lib/services/coach_narrative_service.dart` | Ajouter mode SLM | Mois 2 |
| `apps/mobile/lib/services/slm/slm_engine.dart` | NOUVEAU — wrapper MediaPipe | Mois 2 |
| `apps/mobile/lib/services/slm/compliance_guard.dart` | NOUVEAU — filtrage post-SLM | Mois 2 |
| `apps/mobile/lib/services/slm/slm_download_service.dart` | NOUVEAU — gestion modele | Mois 2 |
| `apps/mobile/lib/services/ios_iap_service.dart` | Activer production IAP | Mois 3 |
| `apps/mobile/pubspec.yaml` | Ajouter dep MediaPipe | Mois 2 |
| `services/backend/app/api/v1/endpoints/billing.py` | Config Stripe prod | Mois 3 |
| `docs/*.md` (~25 fichiers) | Archiver/fusionner | Mois 1 |

---

## VERIFICATION

### Mois 1
- `flutter analyze` = 0 errors
- `flutter test` = tous les tests passent (baseline preservee)
- `python3 -m pytest tests/ -q` dans backend = baseline preservee
- Onboarding flow complet testable sur device reel (iOS + Android)
- Paywall visible quand `tier == free`

### Mois 2
- SLM genere des narrations en <5s sur iPhone 14 / Pixel 7
- ComplianceGuard bloque 100% des termes bannis
- Fallback vers templates si SLM indisponible
- Tests unitaires SLM: 15+ tests minimum

### Mois 3
- Flow paiement complet: free → paywall → Stripe/IAP → coach tier
- App Store submission accepted
- 20+ beta testeurs actifs avec metriques

---

## RESUME EXECUTIF

L'audit est pertinent sur 3 points critiques: (1) trop de docs, (2) BYOK = friction mortelle, (3) ship maintenant. Mais il sous-estime massivement ce qui est deja construit: l'arbitrage engine, l'OCR pipeline, la monetisation, les templates narratifs. Le code est plus avance que l'audit ne le suggere.

**La strategie en une phrase**: Activer ce qui existe (paywall, Android, beta), ajouter le SLM comme "coach vivant" sans friction, et confronter le marche dans 90 jours.
