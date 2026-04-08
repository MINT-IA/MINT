# MINT

## What This Is

Swiss financial protection & education app (Flutter + FastAPI) that tells users what nobody has an interest in telling them. MINT illuminates blind spots in financial products and decisions through personalized insights covering 18 life events — not just retirement.

## Core Value

A user opens MINT and within 3 minutes receives a personalized, surprising insight about their financial situation that they couldn't have found elsewhere — then knows exactly what to do next.

## Current Milestone: v2.2 La Beauté de Mint (Design v0.2.3)

**Goal:** Élever la beauté, le design, l'UI, l'UX et la voix de Mint — calme dans la main, vif dans la voix, curseur d'intensité 5 niveaux. Layer 1: 5 surfaces immuables (S1-S5), 7 chantiers (Phase 0 stabilisation gate + 6 design chantiers).

**Doctrine (immuable):**
- Mint protège sans juger. Mint prouve sans surjouer. Mint parle peu — mais avec l'intensité juste, du murmure au coup de poing verbal.
- 4 principes fondateurs (P1 éclairer pas juger, P2 incertitude visible, P3 une idée par écran, P4 voix vivante avec curseur d'intensité)

**Surfaces Layer 1 (5):**
1. S1 — `apps/mobile/lib/screens/onboarding/intent_screen.dart` (AAA)
2. S2 — `apps/mobile/lib/screens/main_tabs/mint_home_screen.dart` (AAA)
3. S3 — `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` (AAA)
4. S4 — `apps/mobile/lib/widgets/coach/response_card_widget.dart` (AAA)
5. S5 — `apps/mobile/lib/widgets/mint_alert_object.dart` — à créer (AAA)

**Chantiers Layer 1 (7, with expert challenge applied):**
- **L1.0 — Phase 0 stabilisation gate** (carryover v2.1): STAB-17 manual tap-to-render walkthrough by Julien on real device, blocks TestFlight. Galaxy A14 device provisioned + perf baseline documented (cold start, scroll FPS, MTC bloom timing). VoiceCursorContract extracted as Dart const + Pydantic model — single source of truth for L1.5 + L1.6. Krippendorff α tooling provisioned for L1.6 metric work.
- **L1.1 — Audit du retrait sur S1-S5** (-20% éléments visuels). Includes deletion of legacy confidence rendering on S4 to make room for MTC.
- **L1.2a — MintTrameConfiance v1 component + S4 migration**: composant unique rendant `EnhancedConfidence` (4-axis) en ligne + détail tappable + version "1 ligne audio" pour TalkBack/VoiceOver + bloom 250ms ease-out. C'est le SEUL geste "mécanisme visible au tap" de Layer 1 — le horlogère vit ici, nulle part ailleurs.
- **L1.2b — MTC migration sur surfaces décisionnelles restantes** (~12 écrans de projection consommant `confidence_scorer.dart`). Élimine le dual-system legacy badges + MTC. Peut tourner en parallèle de L1.3/L1.4.
- **L1.3 — Microtypographie pass sur S1-S5**: Montserrat/Inter, paragraphes 45-75 char, max 80, hiérarchie 3 niveaux. Tests Galaxy A14 + simulation DMLA + simulation dyslexie. Référence Spiekermann (Edenspiekermann/FF Meta) sur micro-typographie haute-densité.
- **L1.4 — Voix régionale VS/ZH/TI**: 30 microcopies par canton, base languages uniquement (fr-CH pour VS, de-CH pour ZH, it-CH pour TI). Stockage `app_regional_<canton>.arb` séparé du namespace ARB principal. Validation par natifs locaux. Étend `RegionalVoiceService.forCanton()`. ComplianceGuard sur tout.
- **L1.5 — MintAlertObject (G2/G3 implémenté)**: composant Flutter réutilisable. Importe `VoiceCursorContract` (sortie de L1.0) — ne hardcode pas la matrice. G2 = soulignement direct dans grammaire calme. G3 = rupture grammaticale. Tests Patrol obligatoires.
- **L1.6 — Voice Pass: Curseur d'Intensité v1**: trois sous-chantiers (a) `docs/VOICE_CURSOR_SPEC.md` + 50 phrases-types (10 par niveau) + matrice routage Gravité×Relation + garde-fous, (b) réécriture des 30 phrases coach les plus utilisées avec validation Krippendorff α≥0.67 (15 testeurs × 20 phrases, weighted ordinal IRR) une fois pour valider le spec, puis revue éditoriale Julien + 2 copywriters francophones pour les itérations, (c) réglage utilisateur "Ton" dans intent_screen + ProfileDrawer (`soft`/`direct`/`unfiltered`, default `direct`), backend `Profile.voiceCursorPreference` Pydantic v2, garde-fous immuables (jamais sous N2 sur G3, jamais au-dessus de N3 sur sujets sensibles, mode fragile plafonne N3 30j).

**Cut from Layer 1 (R&D library, pas de scope drift):**
- ❌ "Précision horlogère secondaire à la demande" → cut. Le seul geste "mécanisme visible au tap" Layer 1 vit dans MTC bloom (L1.2a). Toute autre instance = dérive d'inconsistance.
- ❌ MINT Signature v0 (générative), palate cleansers comme écrans dédiés, Lock Screen widget, archétype "grand frère" → restent en R&D (déjà tués au brief).

**Why this milestone:** v2.0 a montré que Mint marche. v2.1 a prouvé que les fils sont bien soudés. v2.2 répond à la question "et est-ce que c'est beau, calme, vif au bon moment?" — la dernière mile entre "ça fonctionne" et "on sent que c'est Mint".

## Requirements

### Validated

<!-- Shipped through v2.1 Stabilisation v2.0 — confirmed working. -->

- Chat AI with Claude (tool calling, compliance guard, BYOK fallback) — S51+S56
- 8 financial calculators in financial_core/ (AVS, LPP, tax, arbitrage, Monte Carlo, confidence, withdrawal, tornado) — S51-S53
- 18 life events, 8 archetypes with detection — S53
- 3-tab shell (Aujourd'hui | Coach | Explorer) + ProfileDrawer — S52+S56
- 7 Explorer hubs (Retraite, Famille, Travail, Logement, Fiscalite, Patrimoine, Sante) — S52
- Design system (MintColors, Montserrat/Inter, Material 3) — S54
- i18n 6 languages (fr template + en/de/es/it/pt) — S55
- Coach with regional voice scaffolding (Romande, Deutschschweiz, Svizzera Italiana) — S55
- Intent-based onboarding screen — S56
- Léa golden path landing → onboarding → premier éclairage → plan → check-in — v2.0
- Document intelligence (photo/PDF → extraction → enrichment) — v2.0
- Rule-based anticipation engine — v2.0
- FinancialBiography local-only encrypted store — v2.0
- Contextual Aujourd'hui smart card ranking — v2.0
- 9-persona QA + accessibility + multilingual coverage — v2.0
- Coach tool-call choreography wired E2E (route_to_screen, generate_document, generate_financial_plan, record_check_in) on BYOK + RAG paths — v2.1
- 6-axis façade-sans-câblage audit complete (coach wiring, dead code, orphan routes, contract drift, swallowed errors, tap-render scaffold) — v2.1
- 12'892 tests green, flutter analyze lib/ 0, backend ruff 0, CI dev green — v2.1

### Active

<!-- v2.2 La Beauté de Mint — REQ-IDs assigned during requirements step. -->

Defined in `.planning/REQUIREMENTS.md` (see Phase 0 carryover + 6 design chantiers above).

### Out of Scope

<!-- Explicit boundaries for v2.2 + standing exclusions. -->

**v2.2 design milestone exclusions:**
- Layer 2 prototypes (Lock Screen widget, ambient computing, voice AI surfaces) — internal only, ne ship pas
- Layer 3 R&D bibliothèque (MINT Signature générative, halo sacré, parfumerie, gastronomie, cinéma de plans dramatiques, palate cleansers comme écrans dédiés, archétype "grand frère") — documentés, non shippés
- "Précision horlogère" mécanisme visible au tap au-delà du MTC bloom — cut, scope drift
- Touch-up sur surfaces hors S1-S5 — interdit ce milestone, sauf migration MTC L1.2b sur écrans de projection
- Ajout d'une 6e surface Layer 1 — interdit, viendra en remplacement d'une existante seulement
- Voix régionale au-delà de VS/ZH/TI — autres cantons en v2.3
- Régional microcopy traduit hors langue de base (fr-CH, de-CH, it-CH) — translating Valaisan en portugais = noise
- Galaxy A14 perf en Android-in-CI automatisée — manuel par Julien ce milestone, automation v2.3 (Firebase Test Lab investigation)
- 12 orphan GoRouter routes documentés en v2.1 AUDIT_ORPHAN_ROUTES.md — déférés v3.0 sauf si chantier touche le code

**Standing exclusions (compliance/identity, never):**
- bLink production (requires SFTI membership + per-bank contracts) — v3.0+
- Background processing / WorkManager — v3.0
- Cloud sync for FinancialBiography (requires E2E encryption) — v3.0
- Multi-LLM routing — Phase 3 roadmap
- B2B / institutional features — Phase 4 roadmap
- Money movement / investment advice — never (compliance)
- Product recommendations / ranking — never (compliance)
- Comparaison sociale ("top X% des Suisses") — never (CLAUDE.md §6)
- "Chiffre choc" wording — utiliser "premier éclairage" systématiquement

## Context

- **Post v1.0**: 8 phases shipped (cleanup → tool dispatch → onboarding → plan gen → suivi → calc wiring → journeys → UX polish). Journey pipeline works end-to-end.
- **Core shift**: v1.0 wired the house; v2.0 makes it alive. MINT still waits for user — v2.0 makes MINT come to the user.
- **Document intelligence**: Screenshots/photos are the most natural input ("balance-moi le print screen"). Primary input method ahead of PDF.
- **Compliance evolution**: New output channels (alerts, narratives, openers) all need ComplianceGuard validation.
- **Privacy**: Document originals deleted after extraction (nLPD). FinancialBiography local-only. AnonymizedBiographySummary for coach.
- **Data freshness**: Every extracted field carries extractedAt + decay model. Stale data = conservative fallback.
- **LPP plan types**: Must detect légal vs surobligatoire vs 1e — applying 6.8% to 1e capital = massive overestimate.
- **9 personas**: Incremental QA from Léa (Phase 1) to full 9-persona coverage (Phase 6).
- **Codebase map**: .planning/codebase/ (snapshot — verify before acting)

## Constraints

- **Tech stack**: Flutter + FastAPI, no changes this milestone
- **Compliance**: Read-only, no advice, no ranking, no promises (LSFin/FINMA). ComplianceGuard sur tout texte généré.
- **Identity**: "Mint te dit ce que personne n'a interet a te dire" — protection-first, not retirement-first
- **Target**: ALL Swiss residents 18-99, segmented by life event, never by age
- **Branch flow**: feature/* -> dev -> staging -> main (no direct push to staging/main)
- **Testing**: flutter analyze 0 errors + flutter test + pytest before any merge
- **Device floor (v2.2)**: Samsung Galaxy A14 (Android 13, 4 GB RAM). Manual perf gate by Julien before merge ce milestone (Android-in-CI automation déférée v2.3).
- **Accessibility (v2.2)**: WCAG 2.1 AA bloquant CI sur toute surface touchée. AAA cible sur S1-S5. 3 sessions live tests minimum (1 malvoyant·e, 1 ADHD, 1 français-seconde-langue) à cadence milestone.
- **Behavioral Data Minimization (v2.2 → tier 1 rules.md)**: aucune donnée comportementale (ouverture app, durée d'attention, contexte) ne déclenche un message vers l'utilisateur sans opt-in nommé et révocable. Suppression à 90 jours par défaut.
- **i18n carve-out (v2.2)**: l'i18n rule (ALL user-facing strings → ARB 6 langues) a une exception explicite pour la voix régionale. Les chaînes regional microcopy vivent dans des namespaces ARB scopés au canton (`app_regional_<canton>.arb`) et ne sont pas traduites hors de leur langue de base (fr-CH, de-CH, it-CH).
- **Phrases interdites à tous les niveaux** (CLAUDE.md §6 + brief v0.2.3): "garanti", "certain", "assuré", "sans risque", "optimal", "meilleur", "parfait" (en absolu), "Cher client...", "Il est important de noter...", "Bestie...", "Tu fais n'importe quoi", "Les gens de ton âge épargnent en moyenne X", "Prends un moment pour respirer".
- **Curseur d'intensité (v2.2)**: 5 niveaux N1-N5. N5 max 1/utilisateur/semaine (règle éditoriale). N1 par défaut sur sujets sensibles (deuil, divorce, perte d'emploi, maladie). Le visuel ne change jamais — seule la voix module. Mot "curseur" interne uniquement; côté utilisateur "Ton".

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 3-tab + drawer (not 4 tabs) | Dossier tab removed, profile in drawer | Good |
| Coach-first, UI-assisted | AI as narrative layer, not chatbot-first | Good |
| Protection-first identity | Not retirement app, not calculator, not dashboard | Good |
| financial_core/ as single source | All calcs centralized, consumers import only | Good |
| Intent-based onboarding | Ask what user cares about, not demographics | Pending |
| UX Journey before Coach depth | Fix the house before decorating rooms | ✓ Good |
| DataIngestionService adapter pattern | Unified pipeline for all input channels (doc, bank, pension) | — Pending |
| FinancialBiography local-only | Privacy-first: never sent to external APIs | — Pending |
| Rule-based anticipation triggers | Zero LLM cost, deterministic, instant | — Pending |
| bLink sandbox only for v2.0 | Production requires SFTI + per-bank contracts (18-24 months) | — Pending |
| v2.2 archetype "personnage" abandonné | Mint n'est ni grand frère ni coach ni banquier — c'est une voix qui module selon gravité × relation × réglage | — Pending |
| v2.2 curseur d'intensité 5 niveaux remplace l'archétype | Voix module N1-N5, visuel reste calme et constant | — Pending |
| v2.2 5 surfaces Layer 1 (immuables) | S1-S5 only. Pas de 6e surface; remplacement uniquement | — Pending |
| v2.2 MTC = single rendering layer everywhere | Pas de dual-system legacy badges + MTC. L1.2a build composant + S4, L1.2b migrate ~12 surfaces de projection | — Pending (expert challenge point 2) |
| v2.2 VoiceCursorContract Phase 0 deliverable | Single source of truth (Dart const + Pydantic) consommé par L1.5 et L1.6, évite hardcode + rework | — Pending (expert challenge point 3) |
| v2.2 i18n carve-out pour voix régionale | Régional microcopy ne se traduit pas hors langue de base. Namespaces ARB séparés par canton | — Pending (expert challenge point 4) |
| v2.2 Galaxy A14 manuel par Julien (pas CI auto) | Honest about infra delta. Android-in-CI déféré v2.3 (Firebase Test Lab investigation) | — Pending (expert challenge point 5) |
| v2.2 Krippendorff α≥0.67 (weighted ordinal) pour valider spec curseur, puis revue éditoriale | IRR statistique honnête une fois, jugement humain ensuite. 80% naive % agreement = broken sur ordinal 5-level | — Pending (expert challenge point 1) |
| v2.2 Précision horlogère cut de Layer 1 | Le seul "mécanisme visible au tap" autorisé Layer 1 = MTC bloom (250ms ease-out). Tout autre = scope drift | — Pending (expert challenge point 6) |
| v2.2 décision politique (Stiegler) | (b) solidarité cible, (a) adaptation défaut tant que partenaires non signés. MintAlertObject G3 propose info seule par défaut | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd-transition`):
1. Requirements invalidated? -> Move to Out of Scope with reason
2. Requirements validated? -> Move to Validated with phase reference
3. New requirements emerged? -> Add to Active
4. Decisions to log? -> Add to Key Decisions
5. "What This Is" still accurate? -> Update if drifted

**After each milestone** (via `/gsd-complete-milestone`):
1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-07 after v2.1 archived + v2.2 La Beauté de Mint initialized (with expert challenge applied)*
