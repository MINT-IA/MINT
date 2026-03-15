# Autoresearch UX Navigation — MINT

## Purpose
Autonomous research loop to converge on the optimal navigation architecture for MINT V1.
Generates N variants of navigation structure, scores them mechanically against MINT's 7 hermeneutic principles + UX metrics, keeps the best, iterates.

## Trigger
Invoke with `/autoresearch-ux-navigation` or `/autoresearch-ux-navigation 30` (number of iterations).

## Context

### MINT Mission
"Juste quand il faut: une explication, une action, un rappel."
Coach de vie financier suisse, bienveillant, éducatif, proactif, jamais jugeant, jamais submergant.

### Current State (audit S48)
- 97 routes, ~82 écrans, 49+ outils, 8 feature flags
- 4 onglets: Pulse, Agir, Apprendre, Profil
- ExploreTab surchargée (18 life events + 49 outils)
- 40% des écrans cachés derrière des flags
- Écrans orphelins, routes dupliquées, navigation confuse

### Vision V1 Target
- ~25 écrans maximum
- Coach-centric (pas feature-menu)
- Progression naturelle (Cercles 1-5 de confiance)
- 1 écran = 1 information = 1 action possible

## Scoring Rubric (100 points max)

### Principes Herméneutiques (60 points)

**H1 — Lisibilité immédiate (10 pts)**
- 1 écran = 1 intention = 1 action ? (0-5)
- Titre ≤ 8 mots, explication ≤ 2 lignes ? (0-5)

**H2 — Progression naturelle (10 pts)**
- Les cercles 1→5 sont-ils reflétés dans la navigation ? (0-5)
- L'utilisateur est-il guidé vers le cercle suivant ? (0-5)

**H3 — Contextualité radicale (10 pts)**
- Le profil/archétype détermine-t-il ce qui est visible ? (0-5)
- Les écrans inutiles pour l'utilisateur sont-ils cachés ? (0-5)

**H4 — Transparence totale (5 pts)**
- Chaque chiffre a sa source visible ? (0-3)
- Les hypothèses sont explicites ? (0-2)

**H5 — Éducation avant action (10 pts)**
- Chaque CTA est éducatif ("Simuler", "Explorer") ? (0-5)
- Les inserts didactiques sont accessibles à ≤ 1 tap ? (0-5)

**H6 — Couple comme unité (5 pts)**
- Vue Julien/Lauren/Couple accessible ? (0-3)
- Séquençage couple visible ? (0-2)

**H7 — Sobriété intentionnelle (10 pts)**
- Nombre total d'écrans ≤ 25 ? (0-5, pénalité -1 par écran > 25)
- Zéro feature flag, zéro mode caché ? (0-3)
- Chaque écran a un CTA éducatif clair ? (0-2)

### Métriques UX (40 points)

**Taps to key action (12 pts — x3 weight)**
- Scanner un certificat ≤ 2 taps ? (0-3)
- Voir son aperçu financier ≤ 1 tap ? (0-3)
- Lancer une simulation ≤ 2 taps ? (0-3)
- Accéder au coach ≤ 1 tap ? (0-3)

**Navigation depth (8 pts — x2 weight)**
- Profondeur max ≤ 3 taps ? (0-4)
- Retour au hub ≤ 1 tap depuis n'importe où ? (0-4)

**Zero orphans (4 pts — x2 weight)**
- Aucun écran sans chemin visible ? (0-4)

**Zero duplicates (2 pts)**
- Chaque feature a un chemin canonique unique ? (0-2)

**Tab balance (2 pts)**
- Écart entre tabs ≤ 3 écrans de profondeur ? (0-2)

**Anti-overwhelm (6 pts)**
- L'utilisateur ne voit jamais plus de 5-7 choix par écran ? (0-3)
- Pas de grille > 6 éléments sans recherche ? (0-3)

**Bienveillance (6 pts)**
- Aucun jugement ("bon/mauvais", scoring comparatif social) ? (0-2)
- Cadrage en progrès personnel (pas en manque) ? (0-2)
- Ton encourageant sur les écrans clés ? (0-2)

## Loop Mechanics

### Phase 1: Generate variant (1 per iteration)
Generate a navigation architecture variant as a structured document:
- Tab structure (name, icon, purpose, screens)
- Screen inventory (max 25)
- Route map (how user navigates)
- Key user journeys (5 scenarios)

### Phase 2: Score variant
Apply the 100-point rubric mechanically. Be harsh. Justify each score.

### Phase 3: Compare & select
Keep the best-scoring variant. If new variant scores higher, it replaces the current best.
Log: iteration number, variant summary, total score, delta vs previous best.

### Phase 4: Mutate
Take the current best and generate a mutation:
- Merge 2 screens into 1
- Split an overloaded screen
- Move a feature between tabs
- Remove a screen entirely
- Add a missing user journey

### Phase 5: Repeat
Loop phases 1-4. Every 5 iterations, produce a summary checkpoint.

## Output
Write results to `docs/UX_NAVIGATION_ARCHITECTURE.md`:
- Best variant with full architecture
- Score breakdown
- User journey maps
- Screen inventory
- Migration plan from current → target

## Constraints
- NEVER propose > 30 écrans
- ALWAYS include: scan certificat, aperçu financier, coach, simulateur, profil
- ALWAYS respect: read-only, no advice, educational tone, bienveillance
- The 18 life events exist but should be CONTEXTUAL (shown when relevant), not in a catalogue
- Safe Mode (dette) must be a first-class citizen
- Couple view (Julien/Lauren) must be native, not an afterthought

## Reference Files
- `visions/vision_product.md` — Core promise
- `docs/VISION_UNIFIEE_V1.md` — V1 target (7 principles)
- `rules.md` — Non-negotiable rules
- `CLAUDE.md` — Project context
- Current routes: `apps/mobile/lib/app.dart` (~97 routes)
- Current tabs: `apps/mobile/lib/screens/main_navigation_shell.dart`
