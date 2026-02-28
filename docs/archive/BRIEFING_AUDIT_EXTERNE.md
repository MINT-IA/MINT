# Briefing pour l'auditeur externe — Etat reel du code MINT

> Date: 2026-02-25
> Objectif: Donner a l'auditeur qui a produit l'audit strategique une vision factuellement exacte du code, pour qu'il puisse mettre a jour ses recommandations.

---

## PARTIE 1 — Etat reel du code (inventaire factuel)

### 1.1 Metriques globales

| Metrique | Valeur |
|----------|--------|
| Lignes Dart (Flutter) | 169,839 |
| Lignes Python (Backend) | 60,085 |
| Total code | ~230,000 lignes |
| Ecrans Flutter | 110 fichiers, 19 categories, 88,615 lignes |
| Services Flutter | 63 fichiers, 27,611 lignes |
| Endpoints API (FastAPI) | 46 endpoints REST |
| Services backend | 27 modules |
| Tests backend (pytest) | 2,464 fonctions dans 69 fichiers |
| Tests Flutter | 2,214 fonctions dans 130 fichiers |
| **Total tests** | **4,678** |
| Sprints livres | S0-S30 (complets, commits traces) |
| i18n | 6 langues (FR/DE/EN/ES/IT/PT), 1,348 cles chacune, parite 100% |
| Education inserts | 40 fichiers Markdown, 2,373 lignes |
| Documentation active | 74 fichiers .md, 23,760 lignes |

### 1.2 Financial Core — Moteur de calcul unifie

**Repertoire**: `apps/mobile/lib/services/financial_core/` — 13 fichiers, 5,716 lignes

C'est le coeur du produit. Tous les calculs financiers passent par ces calculatrices statiques (fonctions pures, deterministes, testables). Aucun service ne reimplemente de formule.

| Fichier | Lignes | Role |
|---------|--------|------|
| `arbitrage_engine.dart` | 1,803 | 5 comparateurs (rente vs capital, allocation, location vs propriete, rachat vs marche, calendrier retraits) |
| `bayesian_enricher.dart` | 971 | Enrichissement bayesien des profils |
| `tornado_sensitivity_service.dart` | 726 | Analyse de sensibilite (tornado charts) |
| `withdrawal_sequencing_service.dart` | 585 | Sequencement optimal des retraits (3a, LPP, libre passage) |
| `monte_carlo_service.dart` | 417 | Simulations Monte Carlo (rendement, inflation, longevite) |
| `arbitrage_models.dart` | 311 | Modeles de donnees arbitrage |
| `fri_calculator.dart` | 239 | Financial Readiness Index |
| `confidence_scorer.dart` | 232 | Score de confiance des projections |
| `avs_calculator.dart` | 122 | Calcul rentes AVS (LAVS art. 21-40) |
| `lpp_calculator.dart` | 115 | Projection LPP + bonifications (LPP art. 14-16) |
| `monte_carlo_models.dart` | 92 | Modeles Monte Carlo |
| `tax_calculator.dart` | 82 | Impot retrait capital + revenu (LIFD art. 38) |
| `financial_core.dart` | 21 | Barrel export |

**ADR de reference**: `decisions/ADR-20260223-unified-financial-engine.md`

### 1.3 Coach Layer — Intelligence narrative

**2 services**, 1,425 lignes Dart:

| Service | Lignes | Role |
|---------|--------|------|
| `coach_narrative_service.dart` | 763 | Orchestrateur dual-mode: BYOK cloud LLM ou templates statiques enrichis |
| `coach_llm_service.dart` | 662 | Client BYOK (OpenAI, Anthropic, Mistral), prompt engineering, safety |

**Architecture actuelle**:
- Mode BYOK: L'utilisateur fournit sa cle API → appels cloud (OpenAI/Anthropic/Mistral)
- Mode sans cle: Templates statiques enrichis avec les donnees du profil
- `CoachNarrative`: 6 blocs (greeting, scoreSummary, trendMessage, topTipNarrative, urgentAlert, milestoneMessage)
- Cache: SharedPreferences, cle `coach_narrative_{date}`, TTL 24h
- Regle fondamentale: "Le LLM ne calcule JAMAIS — les calculs passent par le financial_core"
- ComplianceGuard prevu (5 couches): banned terms, prescriptif, hallucination, disclaimer, longueur

### 1.4 Arbitrage Engine — Comparaisons financieres

5 comparateurs dans `arbitrage_engine.dart` (1,803 lignes):

1. **`compareRenteVsCapital()`** — 3 options (full rente, full capital, mixte obligatoire/surobligatoire), breakeven point, sensibilite
2. **`compareAllocationAnnuelle()`** — Repartition epargne (3a, LPP rachat, ETF, amortissement)
3. **`compareLocationVsPropriete()`** — Location vs achat immobilier avec Tragbarkeit
4. **`compareRachatVsMarche()`** — Rachat LPP vs investissement marche
5. **`compareCalendrierRetraits()`** — Sequencement fiscal optimal des retraits prevoyance

Chaque comparateur produit: options cote-a-cote (jamais classees), hypotheses visibles et modifiables, point de croisement, bande de sensibilite, disclaimer, sources juridiques.

### 1.5 Subscription & Monetisation

**Fichier**: `apps/mobile/lib/services/subscription_service.dart`

- 2 tiers: `free` / `coach` (4.90 CHF/mois)
- 11 features gatees par abonnement: dashboard, forecast, checkin, scoreEvolution, alertesProactives, historique, profilCouple, coachLlm, scenariosEtSi, exportPdf, vault
- Integrations: Stripe (web) + Apple IAP (iOS) + Google Play Billing (Android)
- **Etat actuel**: Paywall mocke (`tier: SubscriptionTier.coach` en dur) — `// TODO: restore paywall gate before production launch`

### 1.6 OCR / Document Pipeline

2 modules backend complementaires:

**Docling** (`services/backend/app/services/docling/`):
- `parser.py` — Parsing PDF via Docling
- `categorizer.py` — Classification automatique du type de document
- `extractors/bank_statement.py` — Extraction releves bancaires
- `extractors/lpp_certificate.py` — Extraction certificats LPP

**Document Parser** (`services/backend/app/services/document_parser/`):
- `lpp_certificate_parser.py` — Parsing structure certificat LPP
- `tax_declaration_parser.py` — Parsing declaration fiscale
- `avs_extract_parser.py` — Parsing extrait AVS
- `extraction_confidence_scorer.py` — Score de confiance de l'extraction
- `document_models.py` — Modeles communs

### 1.7 Onboarding

3 ecrans progressifs:

1. **`onboarding_minimal_screen.dart`** — 3 inputs (salaire presets, age slider, canton picker) → chiffre choc
2. **`chiffre_choc_screen.dart`** — Affichage du chiffre choc personnalise (ecart retraite)
3. **`progressive_enrichment_screen.dart`** — Enrichissement progressif du profil

### 1.8 Ecrans (19 categories)

```
advisor/       arbitrage/    auth/        budget/       coach/
confidence/    dashboard/    debt_prevention/  document_scan/  education/
fri/           independants/ lpp_deep/    main_tabs/    mortgage/
onboarding/    open_banking/ pillar_3a_deep/  settings/
```

### 1.9 Backend Services (27 modules)

```
arbitrage/     coach/        confidence/    debt_prevention/  docling/
document_parser/ expat/      family/        first_job/     fiscal/
fri/           i18n/         independants/  lpp_deep/      mortgage/
notifications/ onboarding/   open_banking/  pillar_3a_deep/ precision/
rag/           reengagement/ retirement/    scenario/      snapshots/
unemployment/
```

### 1.10 Decisions architecturales (ADR)

8 ADRs formels dans `decisions/`:

| ADR | Sujet |
|-----|-------|
| ADR-20260111-wizard-progression-clarte | Progression wizard |
| ADR-20260217-document-vault-premium | Vault documents premium |
| ADR-20260223-archetype-driven-retirement | 8 archetypes utilisateur (expat EU/non-EU/US, independant, frontalier, etc.) |
| ADR-20260223-simulator-enrichment | Enrichissement progressif des simulateurs |
| ADR-20260223-unified-financial-engine | Moteur de calcul unifie (dedup AVS/LPP/Tax) |
| ADR-CH-BUDGET-MVP | Budget MVP |
| ADR-CH-EDU-SIMULATORS | Simulateurs educatifs |

---

## PARTIE 2 — Corrections factuelles de l'audit

L'audit strategique identifiait 5 problemes structurels. Voici la confrontation avec le code reel.

### 2.1 "Documentation sprawl" — CONFIRME, CORRIGE

**Audit**: "Trop de fichiers .md, les agents perdent 30%+ de contexte."
**Realite**: Exact. 112 fichiers .md, 32,829 lignes.
**Action prise le 25.02.2026**: Consolidation chirurgicale.
- 20 fichiers archives via `git mv` (zero perte d'historique)
- Hierarchy of truth deduplicee (5 copies → 2 completes + 2 pointeurs)
- **Resultat**: 74 fichiers actifs, 23,760 lignes (-22%)

### 2.2 "BYOK = friction" — CONFIRME

**Audit**: "L'architecture BYOK (Bring Your Own Key) est une barriere a l'adoption."
**Realite**: Exact. `coach_llm_service.dart` requiert `apiKey` dans `LlmConfig`. Aucun utilisateur non-tech ne fera ca.
**Nuance manquante**: Le mode fallback (templates statiques enrichis) fonctionne deja sans cle API. L'app est 100% fonctionnelle sans BYOK, le LLM est un bonus narratif.
**Plan adopte**: Remplacement par SLM on-device (Gemma 3n 4B E4B via MediaPipe LLM Inference). Architecture cible: SLM on-device → fallback templates → BYOK cloud (optionnel).

### 2.3 "30 sprints sans utilisateurs" — PARTIELLEMENT JUSTE

**Audit**: "Trop de feature dev, pas assez de validation terrain."
**Realite**: Correct sur le fait que le paywall est mocke et qu'il n'y a pas de beta publique.
**Nuance manquante**: Le code n'est pas un prototype. C'est un produit feature-complete avec:
- 4,678 tests automatises
- 46 endpoints API
- 110 ecrans Flutter
- 13 calculateurs financiers unifies referencant la loi suisse
- 6 langues a parite 100%
- Pipeline OCR fonctionnel (certificats LPP, declarations fiscales, extraits AVS, releves bancaires)

Le probleme n'est pas "trop de sprints" mais "paywall pas encore active". Une seule ligne de code a changer: `subscription_service.dart:88`.

### 2.4 "Monetisation est un angle mort" — SOUS-ESTIME PAR L'AUDIT

**Audit**: "Pas de strategie de revenus claire."
**Realite**: Le code est deja la.
- `SubscriptionService`: 2 tiers (free/coach), 11 features gatees
- Integrations Stripe + Apple IAP + Google Play Billing implementees
- Architecture "free = read-only calculators, coach = intelligence narrative + vault + PDF export"
- Prix: 4.90 CHF/mois (positionne pour le marche suisse)
- Document `docs/BUSINESS_MODEL.md` detaille le modele

### 2.5 "Besoin d'un SLM on-device" — VISION JUSTE

**Audit**: Recommandation d'un SLM on-device pour eliminer la friction BYOK.
**Realite**: Vision strategiquement correcte. Le choix adopte:
- **Modele**: Gemma 3n 4B E4B (Google, optimise mobile)
- **Framework**: MediaPipe LLM Inference pour Flutter (iOS + Android)
- **Architecture**: 3 niveaux (SLM on-device → templates enrichis → BYOK cloud)
- **ComplianceGuard**: 5 couches de post-processing obligatoires avant affichage utilisateur

### 2.6 Ce que l'audit n'a pas vu (sous-estimations)

| Element | Realite dans le code |
|---------|---------------------|
| **Arbitrage Engine** | 5 comparateurs, 1,803 lignes, breakeven + sensibilite + Monte Carlo |
| **Financial Readiness Index (FRI)** | Calculateur complet, 239 lignes, score composite |
| **Bayesian Enricher** | 971 lignes, enrichissement profils incomplets |
| **Tornado Sensitivity** | 726 lignes, analyse "what-if" sur chaque variable |
| **Withdrawal Sequencing** | 585 lignes, ordre fiscal optimal (3a/LPP/LP) |
| **OCR Pipeline** | 2 modules (Docling + Document Parser), 4 types de documents |
| **8 archetypes utilisateur** | ADR formel, pas juste "salarie suisse" (expat EU/non-EU/US, independant, frontalier, retour CH) |
| **Confidence Scoring** | Chaque projection a un score de confiance + band d'incertitude |
| **Education inserts** | 40 contenus pedagogiques, references legales, integres dans les wizards |
| **i18n complet** | 6 langues, 1,348 cles, parite verifiee |

---

## PARTIE 3 — Plan adopte (90 jours)

### Decisions prises

| Question | Decision |
|----------|----------|
| Modele SLM | **Gemma 3n 4B E4B** (Google, 4B params, optimise mobile) |
| Framework integration | **MediaPipe LLM Inference** (Flutter plugin officiel) |
| Plateformes beta | **iOS + Android** simultanement |
| Strategie Coach | SLM on-device (tier 1) → Templates enrichis (fallback) → BYOK cloud (optionnel) |
| Paywall | Reactiver `subscription_service.dart:88` avant beta |

### Mois 1 — Activation & Beta (S31-S34)

| Action | Detail |
|--------|--------|
| Reactiver le paywall | `subscription_service.dart:88` — changer `SubscriptionTier.coach` → `SubscriptionTier.free` |
| Configurer Stripe production | Webhook + product/price creation (4.90 CHF/mois) |
| Apple IAP | Soumettre in-app purchase a App Store Connect |
| Google Play Billing | Configurer produit d'abonnement |
| TestFlight + Internal Testing | Deployer pour 20-30 beta-testeurs cibles |
| Onboarding analytics | Tracker completion rate du flux minimal (3 inputs → chiffre choc) |

### Mois 2 — SLM Integration (S35-S38)

| Action | Detail |
|--------|--------|
| Integrer MediaPipe LLM Inference | Plugin Flutter, charger Gemma 3n 4B E4B |
| Creer `SlmCoachService` | Nouveau service remplacant `coach_llm_service.dart` |
| Implementer ComplianceGuard | 5 couches: banned terms, prescriptif, hallucination, disclaimer, longueur |
| Connecter SLM ↔ CoachNarrativeService | Remplacer le mode BYOK par SLM, garder BYOK en option |
| Tests compliance | Suite de tests verifiant qu'aucun output SLM ne viole les regles |
| Benchmark perf | Temps de reponse < 3s, memoire < 500MB, batterie acceptable |

### Mois 3 — Production & Lancement (S39-S42)

| Action | Detail |
|--------|--------|
| App Store submission | Review Apple (pre-check FINMA wording) |
| Google Play submission | Review Google |
| Stripe production live | Activer les paiements reels |
| Monitoring | Crash analytics, conversion funnel, retention J1/J7/J30 |
| Premier pilot B2B | Contacter 2-3 caisses de pension / RH pour integration |
| Feedback loop | Iterrer sur le coach narrative et les templates |

---

## PARTIE 4 — Ce qu'on peut partager directement

Pour que l'auditeur puisse mettre a jour son analyse, voici les documents les plus utiles a partager:

### Documents clefs (par ordre de priorite)

1. **Ce document** (`BRIEFING_AUDIT_EXTERNE.md`) — Vue d'ensemble factuelle
2. **`CLAUDE.md`** — Contexte projet complet (architecture, constantes, compliance, anti-patterns) — 350 lignes
3. **`visions/vision_features.md`** — Specs produit detaillees
4. **`visions/vision_compliance.md`** — Cadre legal et FINMA
5. **`decisions/ADR-20260223-unified-financial-engine.md`** — Architecture du moteur financier
6. **`decisions/ADR-20260223-archetype-driven-retirement.md`** — Les 8 archetypes utilisateur
7. **`docs/BUSINESS_MODEL.md`** — Modele de revenus
8. **`docs/BLUEPRINT_COACH_AI_LAYER.md`** — Architecture technique du Coach AI

### Metriques a communiquer

```
Code total:       ~230,000 lignes (170k Flutter + 60k Python)
Tests:            4,678 (2,464 backend + 2,214 Flutter)
Ecrans:           110 fichiers, 19 categories
Endpoints API:    46
Calculateurs:     13 (financial_core unifie)
Langues:          6 (FR/DE/EN/ES/IT/PT)
Sprints livres:   S0-S30
OCR:              4 types de documents (LPP, fiscalite, AVS, releves)
Archetypes:       8 profils utilisateur
```

### Ce qu'on NE partage PAS

- Code source (propriete intellectuelle)
- Cles API / secrets
- Donnees utilisateur (il n'y en a pas encore, mais principe)
- Details d'implementation securite (auth, encryption)
