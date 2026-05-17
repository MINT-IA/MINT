---
date: 2026-05-14
status: Decided
authors: Julien (decided), Claude (drafted)
panel: single
supersedes: —
superseded_by: —
description: Mon Argent dissous dans Trajectoire (3-tab refonte PDF DS v2 mai 8 canonique) ; patrimoine snapshot devient milestone M0 « Où tu en es » sur Trajectoire ; tab bar passe à 3 (Aujourd'hui · Coach · Trajectoire).
related:
  - docs/vision/MON_ARGENT-PROPOSAL.md
  - .planning/audit/2026-05-14-handoff-vs-code-drift.md
  - .planning/handoff/pdfs/MINT-Design-System-2026-05-08.pdf
  - .planning/decisions/2026-05-14-aujourdhui-doctrine.md
  - .planning/decisions/2026-05-14-phase-7-ship-or-pause.md
---

# Mon Argent dissous dans Trajectoire (Proposition P2 ratifiée)

## TLDR

Mon Argent disparaît comme tab dédié ; patrimoine snapshot devient milestone M0 « Où tu en es aujourd'hui » sur Trajectoire ; tab bar passe à 3 tabs (Aujourd'hui · Coach · Trajectoire) — cohérent avec PDF DS v2 mai 8 page 3-4 canonique, JSX `docs/brand/mint-v2/`, et pivot Karpathy 2026 « outsource thinking, keep understanding ».

## Context

Le design doc APPROVED 2026-05-14 Open Question #3 demandait à trancher Mon Argent : « numbers panel statique / surface secondaire de la trajectoire / point d'entrée banking integration » (3 directions exclusives). Le drift audit `2026-05-14-handoff-vs-code-drift.md` Section A.3 a découvert que le PDF DS v2 mai 8 propose **3 tabs** (Mon Argent disparaît), ce qui transforme la question.

3 propositions développées dans `docs/vision/MON_ARGENT-PROPOSAL.md` avec matrice évaluation pondérée :
- P1 statu quo amélioré (4-tab patrimoine multi-chiffre) : score 45%
- **P2 dissolution dans Trajectoire (3-tab refonte PDF DS v2)** : score 78%
- P3 banking integration (Open Banking hub) : score 48%

Julien a tranché P2 le 2026-05-14 après lecture de la proposal.

## Decision

**Mon Argent comme tab dédié = SUPPRIMÉ.**

**Tab bar finale (3 tabs)** :
1. **Aujourd'hui** — director-dashboard one-number (cf. ADR 2026-05-14-aujourdhui-doctrine.md)
2. **Coach** — surface conversationnelle didactique (Option C Coach vivant)
3. **Trajectoire** — TrajectoryMap horizontale A→B avec marker position courante

**Patrimoine snapshot** = milestone **M0 « Où tu en es aujourd'hui »** sur Trajectoire :
- Hero chiffre = patrimoine net total (sourced from `financial_core` Dart + cited)
- ConfidenceBand obligatoire (PDF DS v2 mai 8 grammaire #6 + ADR Aujourd'hui)
- EnrichmentPrompts inline (compléter les sources manquantes : LPP / 3a / immo / banques)
- Tap M0 → overlay détail patrimoine (5 lignes : épargne / 3a / LPP / immo / dettes) — pas un push d'écran (cohérent Phase 96 chat-as-verb si jamais rebooté)

**Deep links migration** :
- `/mon-argent` → redirect vers `/trajectoire/m0`
- `/mon-argent/patrimoine` → redirect vers `/trajectoire/m0/detail`
- `/mon-argent/budget` → reste accessible via Coach overlay (carte d'action) OU intégré dans Aujourd'hui (delta hebdo)

**Pré-conditions implémentation** :
1. **Phase 7 chat-as-verb tranchée** : décision finale ship-or-pause-définitive sur `chatTabVisible`. Si PAUSED indéfiniment → Coach reste tab persistante (cohérent 3-tab P2). Si shippée → Coach devient overlay invocable depuis n'importe quel tab (déplace 3 vers 2 tabs effectifs : Aujourd'hui · Trajectoire).
2. **M0 milestone designed** : hero number + UX tap-to-expand + breakdown patrimoine. Décision design en Wave 2.
3. **DS v2 propagation Wave 1.5** (ADR séparé) : tokens warm + grammaire ConfidenceBand préparés avant ce refactor pour ne pas accumuler 2 dettes.

## Counter-arguments and data gaps

- **What does the strongest opposing view say ?**
  Anti-P2 : tuer 1 tab parce qu'un PDF design system mai 8 le dit, c'est laisser une grammaire visuelle dicter une décision navigation sans validation user. Le coût refonte (~30-35h Wave 2 + redirects + tests régression) est non-trivial pour un MVP qui n'a pas encore validé sur les 5 utilisateurs Wave 0 (sub-agent G persona guide). Si les tests 5 utilisateurs révèlent que 4/5 cherchent spontanément un tab dédié au patrimoine → on devra revenir à P1 lite et payer le coût pivot-back.

- **What does this source not address ?**
  - Aucun user observé en 4-tab actuel pour confirmer « je n'utilise jamais Mon Argent » OU « Mon Argent est mon premier réflexe ».
  - Le scénario où M0 « Où tu en es » est mal placé sur Trajectoire (perdu en milieu de stepper, par exemple) → users perdent l'accès rapide patrimoine.
  - La compatibilité avec les flows actuels de scan documentaire / Premier-Éclairage qui débouchent traditionnellement sur Mon Argent — où débouchent-ils en P2 ?
  - Le coupling avec décision Phase 7 : si Phase 7 reste PAUSED indéfiniment et qu'on garde Coach comme tab persistante, on a 3 tabs (Aujourd'hui · Coach · Trajectoire) ; si Phase 7 ship `chatTabVisible=false`, on a 2 tabs (Aujourd'hui · Trajectoire) avec Coach overlay. 2 architectures cibles selon Phase 7 — non résolu.

- **What would change this conclusion ?**
  1. Test 5 utilisateurs Wave 0 (sub-agent G persona guide + test wireframe sub-agent C) → si ≥ 3/5 disent spontanément « je veux un tab dédié pour voir mes comptes » → revisit P1 lite.
  2. Décision Open Banking strategic Wave 6+ → si MINT pivote vers banking-first, P3 redevient pertinent et P2 doit être ajusté pour intégrer un point d'entrée OB sur Trajectoire ou Coach.
  3. Si test wireframe TrajectoryMap (Wave 2 build + Wave 2 device walkthrough) montre que M0 cannibalise l'attention au détriment des autres milestones → re-design M0 ou réintroduire surface patrimoine séparée.

## Sources

- `docs/vision/MON_ARGENT-PROPOSAL.md` — proposal v1 avec matrice pondérée (P1=45%, P2=78%, P3=48%)
- `.planning/audit/2026-05-14-handoff-vs-code-drift.md` Section A.3 + D.bis — drift PDF DS v2 mai 8 montrant 3-tab canonique
- `.planning/handoff/pdfs/MINT-Design-System-2026-05-08.pdf` — pages 3 (Quotidien) + 4 (Coach + Trajectoire)
- `docs/brand/mint-v2/screen-aujourdhui.jsx` — proposition JSX 3-tab cohérente
- `.planning/decisions/2026-05-14-aujourdhui-doctrine.md` — Aujourd'hui director-dashboard one-number (cohérent P2)
- `.planning/decisions/2026-05-14-phase-7-ship-or-pause.md` — Phase 7 PAUSED (pré-condition implementation)
- `.planning/design/2026-05-14-trajectory-map-wireframe-v1.md` — wireframe TrajectoryMap sub-agent C (où M0 trouvera sa place)

## Status & follow-up

- **Implementation tracking** :
  - **Wave 1.5 propagation DS v2** (ADR séparé) : préparer les tokens warm + grammaire ConfidenceBand avant le refactor navigation P2.
  - **Wave 2 PR** : refonte tab bar 4→3 ([mint_shell.dart](apps/mobile/lib/widgets/mint_shell.dart)). Supprimer destination Mon Argent. Ajouter destination Trajectoire (nouvelle). Implémenter TrajectoryMap component (sub-agent C wireframe v1). Designer + implémenter milestone M0.
  - **Wave 2 redirects** : routes `/mon-argent/*` → `/trajectoire/m0/*` dans `app.dart` GoRouter.
  - **Wave 2 tests régression** : 0 régression sur les flows historiques passant par Mon Argent (budget / patrimoine summary / scan CTA).
  - **Wave 2 test 5 utilisateurs** (sub-agent G persona guide) : valider que les 5 personas naviguent au milestone M0 en ≤ 3 taps sans aide. Gate : ≥ 3/5 OK → continue ; ≤ 2/5 OK → re-design.

- **Re-litigation triggers** :
  - Test 5 utilisateurs Wave 0 montre ≥ 3/5 cherchant tab patrimoine dédié → revisit P1 lite
  - Décision Open Banking strategic Wave 6+ → adjustment P2 pour intégrer OB entry point
  - Walkthrough Wave 2 device montre M0 perdu / cannibalisateur → re-design M0 placement
  - Phase 7 ship-or-pause-définitive change l'architecture cible 3-tab vs 2-tab+overlay

---
*Decided 2026-05-14 par Julien via question explicite « Mon Argent vision ? » → « P2 dissolution dans Trajectoire 3-tab (Recommended 78%) ». Drafted Claude post-PR #600 Wave 0.*
