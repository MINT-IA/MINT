# MINT

## What This Is

Swiss financial protection & education app (Flutter + FastAPI) that tells users what nobody has an interest in telling them. MINT illuminates blind spots in financial products and decisions through personalized insights covering 18 life events — not just retirement.

## Core Value

A user opens MINT and within 3 minutes receives a personalized, surprising insight about their financial situation that they couldn't have found elsewhere — then knows exactly what to do next.

## Current Milestone: v2.3 Simplification Radicale

**Goal:** Inverser l'architecture. Le chat EST le shell, pas une feature. Tout écran "destination" qui échoue au test 3 secondes no-finance-human est supprimé, pas refait. Les 4 bugs P0 trouvés sur device le 2026-04-09 dissolvent comme effet de bord.

**Doctrine (les 2 principes fondateurs):**
1. **Test 3 secondes no-finance-human** — un humain qui ne comprend rien à la finance, à qui on montre l'écran 3s, doit pouvoir dire ce qu'il voit et ce qu'il doit faire. Sinon → écran mort, on le supprime. Remplace tous les autres ship gates UI.
2. **Le chat EST l'app (inversion architecturale)** — le chat est le shell, l'entrée, la navigation, le distributeur, le planificateur, le support. Tout autre écran est un tiroir contextuel que le chat ouvre à la demande. Pas de home tab, pas d'explorer, pas de profile dashboard, pas de centre de contrôle comme destinations.

**Inputs critiques (à lire avant toute phase):**
- `.planning/v2.3-handoff/HANDOFF.md` — contexte complet de l'inversion
- `.planning/v2.3-handoff/screenshots/WALKTHROUGH_NOTES.md` — diagnostic device
- `docs/NAVIGATION_MAP_v2.2_REALITY.md` — root-causes file:line des 4 P0
- `docs/AESTHETIC_AUDIT_v2.2_BRUTAL.md` — verdict simplification

**Priorités ordonnées (NE PAS inverser):**
1. **Architecture & navigation propres** — 0 cycle, 0 scope leak, scope-based guards (pas operation-based), 5 tests mécaniques en CI Gate (cycle DFS, scope-leak, empty-state-with-payload, guard snapshot, doctrine-string lint)
2. **Suppression radicale** — delete les écrans qui échouent au test 3s, ne pas les redesigner. Centre de contrôle, Moi dashboard, intent screen, "Faire mon diagnostic", "Créer ton compte" → supprimés ou réduits à des drawers chat-summoned
3. **4 bugs P0 dissolvent** — Bug 1 (auth leak) et Bug 3 (centre de contrôle) disparaissent par suppression. Bug 2 (loop) requiert fix mécanique explicite à coach_chat_screen.dart:1317. Bug 4 (créer ton compte) disparaît : account creation devient flow chat optionnel.
4. **Visuel sobre** — vient en dernier, sur base saine. Pas de chase Aesop/Arc tant que l'archi n'est pas juste.

**Gate 0 (mandatory, every phase):** creator-device annotated screenshots avant tout PR. Non-skippable. Tests verts ≠ app fonctionnelle (leçon v2.2).

**Why this milestone:** v2.2 a shippé 9326 tests verts + 18/18 ship gates + audit A-. Julien a installé sur iPhone et trouvé 4 bugs bloquants en 4 minutes. La gap entre "tests verts" et "app fonctionnelle" est exactement la gap entre "le widget render" et "l'utilisateur atteint son but". v2.3 répare l'archi qui a permis ce drift.

**Doctrine (immuable):**
- Mint protège sans juger. Mint prouve sans surjouer. Mint parle peu — mais avec l'intensité juste, du murmure au coup de poing verbal.
- 4 principes fondateurs (P1 éclairer pas juger, P2 incertitude visible, P3 une idée par écran, P4 voix vivante avec curseur d'intensité)

**Surfaces survivantes (post-suppression):**
- **Chat** (`coach_chat_screen.dart`) — devient le shell, l'entrée, le distributeur. Toute logique d'orientation y vit.
- **S0 Landing** — cold-start airlock minimaliste. 1 promesse, 1 CTA → chat direct.
- **Drawers chat-summoned** : tous les anciens écrans destinations (Moi, Centre de contrôle, simulateurs, profile) deviennent des bottom-sheets/overlays que le chat ouvre quand il en a besoin.

**Suppressions confirmées (par les 2 audits):**
- ❌ Intent screen (`/onboarding/intent`) — la conversation EST le diagnostic
- ❌ "Faire mon diagnostic" CoachEmptyState — dead-end widget, source du Bug 2 loop
- ❌ Centre de contrôle comme destination (`/profile/consent`) — consents demandés contextuellement par le chat au moment où la feature en a besoin
- ❌ Moi dashboard avec gamification 0% / +15% / +10% — anti-shame violation par construction
- ❌ Account creation comme étape onboarding — devient flow chat optionnel pour cloud sync
- ❌ ProfileDrawer comme menu global — démonté ou re-mounted derrière auth guard scope-based

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

**v2.3 milestone exclusions:**
- Chase esthétique pixel-perfect (Aesop/Things 3/Arc references) — l'aesthetic audit est un signal "pas ça", pas une cible. Vient après que l'archi soit juste. Visuel restera sobre.
- Nouvelles features (life events, calculatrices, capacités coach) — milestone de réparation, pas d'ajout
- Backend au-delà des bug fixes — coach service, voice cursor, MTC, regional voice, compliance guard restent intouchés
- ACCESS-01 a11y partner sessions — déféré v2.4 ou descopé via ACCESS-09
- Krippendorff α validation (15 testeurs) — infra prête, déférée v2.4
- Refonte visuelle des écrans supprimés — on supprime, on ne refait pas
- Multi-LLM routing — Phase 3 roadmap
- Re-introduction d'écrans destinations (home dashboard, explorer hubs comme nav cible) — interdit toute la durée v2.3, contredit Principe #2

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
| v2.3 chat-as-shell inversion | v2.2 a build dashboard-with-chat-feature. Device walkthrough 2026-04-09 a prouvé que c'est faux. Le chat doit être le shell. | — Pending |
| v2.3 test 3s remplace tous les ship gates UI | Tests verts ≠ app fonctionnelle. Le seul gate UI honest = un humain non-finance qui comprend en 3s. | — Pending |
| v2.3 Gate 0 creator-device par phase | Non-skippable. Annotated screenshots avant tout PR. Leçon v2.2 : 18/18 automated gates verts + 4 P0 sur device en 4 min. | — Pending |
| v2.3 reset phase numbering à 1 | Cohérent avec "Simplification Radicale" = nouveau départ. v2.2 phases archivées. | — Pending |
| v2.3 5 tests mécaniques nav en CI Gate | Cycle DFS, scope-leak, empty-state-with-payload, guard snapshot, doctrine-string lint. ~200 LOC Dart auraient catché les 4 P0 avant ship. | — Pending |
| v2.3 scope-based auth guard (pas operation-based) | app.dart:167 protectedPrefixes était une whitelist d'opérations → leak Bug 1. Remplacer par tagging de scope (public/onboarding/authenticated) sur chaque route. | — Pending |
| v2.3 visuel en dernier, sobre | Refaire du beau sur archi cassée = peinture sur façade. L'aesthetic audit est un signal "pas ça", pas une cible. | — Pending |

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
*Last updated: 2026-04-09 after v2.2 device walkthrough revealed 4 P0 + v2.3 Simplification Radicale initialized (chat-as-shell inversion, reset phase numbering)*
