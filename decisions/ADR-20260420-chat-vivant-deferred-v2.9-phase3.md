# ADR-20260420 — Chat Vivant handoff déféré à v2.9 Phase 3

**Status** : Accepted
**Date** : 2026-04-20
**Context** : Expert panel review (UX/designer × 3, engineering × 1, product × 1) du handoff `chat-vivant-2026-04-19` post Phase 31 ship.

## Contexte

Le handoff `.planning/handoffs/chat-vivant-2026-04-19/` (Cloud Design, reçu 2026-04-19) propose une refonte du chat MINT vers une grammaire "3 niveaux de projection" : inline insight → scène interactive → canvas plein écran. Vision : *"le chat ne raconte plus, il montre"*.

Déjà planté comme seed v2.9 dans `REVIEW.md` avec 3 frictions identifiées (duplication Explorer, scope refactor orchestrator, i18n 6 langues).

Session 2026-04-20 : panel 3 experts élargi sollicité avant décision d'exécution.

### Findings du panel

**Design (3 designers, verdict unanime)** : 7.5/10 "fit lucidité". Pas shippable as-is. 3 blockers production :
- Fraunces fallback Georgia sur LTE casse la micro-rhétorique éditoriale
- Slider thumb 16×16 sous minimum iOS 48pt + conflit gestures slider horizontal vs scroll chat vertical
- 7 couches d'info dans une bulle chat = cognitive drag pour utilisateurs 65+

**Engineering (codebase audit)** : codebase partiellement prêt.
- ✓ `MintCountUp`, Fraunces via `google_fonts`, `rente_vs_capital_calculator.dart` (217L pure function)
- ✗ `ChatMessage.kind` enum absent, `IntentResolver` ne retourne pas `ScenePayload`, `SceneRegistry` + `CanvasReturn` à créer
- `CoachOrchestrator` 1407 lignes, 4 code paths (SLM, BYOK narrative, BYOK chat, ServerKey) → refactor Future→Stream = **6-8 jours**, pas 2-3
- i18n = ~30 strings × 6 langues = **180 entrées ARB**
- 5 frictions additionnelles manquées par REVIEW.md initial (canvas nav model, SceneRegistry circular dep, a11y absent, i18n scope, feature flag par scène)
- P50 scope réel : **19-25 jours solo**, pas 12-16

**Product (roadmap check)** : v2.8 kill-policy scellée per `ADR-20260419-v2.8-kill-policy.md`. "0 feature nouvelle, pas de stabilisation v2.9, break déjà-vu pattern". Chat Vivant = feature nouvelle, viole la kill-policy. Phases 32-36 (Cartographier → Kill-switches → GUARD-02 → Boucle Daily → Finissage E2E) non-empruntables, 5-6 semaines de travail restant sur v2.8.

## Décision

**Chat Vivant est déféré à v2.9 Phase 3, précédé de :**

1. **v2.8 fermeture clean** — Phases 32, 33, 34, 35, 36 dans l'ordre, sans exception. Pas de micro-wedge en Phase 37. Kill-policy respectée.
2. **Creator-device gate Phase 31** — Julien iPhone 17 Pro physique + Sentry DSN live avant tout flip `sessionSampleRate > 0`. Non-skippable avant v2.9 Phase 3.
3. **v2.9 Phase 1 (dettes)** — Wave E-PRIME findings (POST/PATCH profile, /overview/me, /budget CRUD, /fri/*, 7 intent tags orphelins) câblés d'abord. La lucidité existe AVANT qu'on la "montre".
4. **v2.9 Phase 2 (migration)** — BirthDate migration (planifié dans MEMORY.md). Doit précéder tout nouveau flow archetype/profil.
5. **v2.9 Phase 2.5 (V0 prep, 0.5 jour)** — `ChatMessage.kind` enum + `FeatureFlags.enableChatVivant = false` + `ScenePayload` stub. Débloque la suite sans livrer de visuel.
6. **v2.9 Phase 3 (Chat Vivant, 4 sem)** — en 5 sub-phases indépendamment killables :
   - Phase 3.1 — `/gsd-discuss-phase` résolvant F1/F2/F3 + session de réduction design avec Julien (tranche thumb 48pt, phrase d'orientation post-recul, canvas v2.9 ou v2.10)
   - Phase 3.2 — Fraunces tokens + `MintReveal` + `MintInlineInsightCard` + `MintRatioCard` (creator-device gate obligatoire avant 3.3)
   - Phase 3.3 — `MintSceneRenteCapital` + `MintSceneRachatLPP` consommant `rente_vs_capital_calculator.dart` partagé (résout F1 sans duplication)
   - Phase 3.4 — `MintCanvasProjection` + `CanvasReturn` contract (optionnel, peut glisser v2.10)
   - Phase 3.5 — Stream refactor `CoachOrchestrator` + `SceneRegistry` intégration (le plus risqué, en dernier)
7. **i18n 180 ARB entries** — traduction parallèle depuis Phase 3.1 (long pole, pas sur chemin critique)

## Justification

### Pourquoi pas de micro-wedge en Phase 37 v2.8

Julien a scellé deux doctrines incompatibles avec un micro-wedge :
- `feedback_no_shortcuts_ever.md` — "Tout doit être parfait, parfaitement calculé/identifié/navigué/stocké"
- `ADR-20260419-v2.8-kill-policy.md` — "0 feature nouvelle, pas de v2.9 stabilisation, break déjà-vu pattern"

Un wedge `MintInlineInsightCard` seul = carte déco sans la grammaire scène + canvas + retour contextualisé. Valide rien de réel. Brûle discipline kill-policy pour peu de valeur. Précédent dangereux : si on accepte pour "excellent design", on acceptera 3× d'ici juin.

### Pourquoi les dettes Wave E-PRIME avant Chat Vivant

`feedback_facade_sans_cablage.md` est LA doctrine #1 après W14 (72 fichiers deleted, 5 duplicates). Wave E-PRIME a identifié :
- POST/PATCH profile silent-drop
- /overview/me orphelin
- /budget CRUD manquant
- /fri/* non branché
- 7 intent tags orphelins

Ces 5 câblages sont la lucidité **réelle** (le dossier fonctionne vraiment). Chat Vivant est la lucidité **visuelle** (le chat le montre). Câbler l'invisible avant d'améliorer le visible. Sinon : on "montre" de la donnée cassée.

### Pourquoi la Phase 36 non-empruntable tient

Phase 36 = 4 P0 fixes (UUID / anonymous / save_fact / Coach tab) + 388 catches → 0 + MintShell ARB parity audit + accents 100% + creator-device gate Julien 20 min cold-start. **C'est le sign-off v2.8.** Sans ça, l'app est fonctionnellement cassée au point que tout ajout feature Chat Vivant sera testé sur un socle instable. Tous les bugs Chat Vivant seront attribués à Chat Vivant, alors qu'ils viendront du socle.

### Pourquoi P50 19-25 jours et pas 12-16

L'audit engineering a trouvé 5 frictions additionnelles (F4-F8) et compté 4 paths orchestrator (pas 3). Stream refactor seul = 6-8j. i18n 180 entrées = 3-5j. Reordering V0-V7 proposé par engineering ajoute 1 sem vs REVIEW.md mais réduit le risque de façade à chaque jalon.

## Conséquences

### Positives
- v2.8 ferme clean avec creator-device gate green, sign-off Julien device.
- Chat Vivant attaqué sur socle stable, avec frictions F1-F8 résolues upstream.
- Zéro risque façade-sans-câblage (chaque Phase 3.1-3.5 indépendamment killable).
- ADR écrit ferme la porte à re-discussion hebdomadaire.

### Négatives
- Chat Vivant visible uniquement fin juin / mi-juillet 2026 (vs mai si Phase 37 v2.8).
- Le handoff reste "dormant" 6 semaines — risque léger de staleness (design system pourrait évoluer dans l'intervalle, à réauditer à Phase 3.1).
- Si CV ressort bloqué en Phase 3 (F2 stream refactor plus lourd qu'estimé), v2.9 glisse sur v2.10. Accepté : discipline > vitesse.

### Neutres
- Dettes Wave E-PRIME deviennent v2.9 Phase 1 par défaut (déjà notées dans MEMORY.md comme "déférées v2.8").
- BirthDate migration remonte en Phase 2 (vs flotter ad-hoc).

## Tripwires (à surveiller)

- Si Phase 36 slip > 4 sem → re-evaluer kill-policy (peut-être que Phase 36 elle-même est trop ambitieuse).
- Si Phase 31 creator-device gate échoue sur iPhone physique → masks cassés → v2.8 ne ferme pas, tout glisse.
- Si i18n 180 entries n'est pas démarré à Phase 3.1 → v2.9 Phase 3 slip garanti (chemin long).
- Si à Phase 3.2 `MintInlineInsightCard` ne passe pas creator-device gate Julien → réduction radicale design (ou kill complet Chat Vivant, garder juste `MintCountUp` existant).

## Sources

- Handoff : `.planning/handoffs/chat-vivant-2026-04-19/`
- REVIEW initial : `.planning/handoffs/chat-vivant-2026-04-19/REVIEW.md` (2026-04-19)
- v2.8 kill-policy : `decisions/ADR-20260419-v2.8-kill-policy.md`
- Autonomous profile tiers : `decisions/ADR-20260419-autonomous-profile-tiered.md`
- Wave E-PRIME findings : `topics/project_session_2026_04_18_wave_e_prime.md`
- Lucidité pivot : `topics/project_vision_post_audit_2026_04_12.md`
- Façade doctrine : `topics/feedback_facade_sans_cablage.md`
- No shortcuts doctrine : `topics/feedback_no_shortcuts_ever.md`

## Sign-off

Décidé par : Julien (validation 2026-04-20, "je te suis là où tu veux aller")
Panel : UX/design ×3 + Engineering + Product (2026-04-20)
Auteur : Claude Opus 4.7 (1M context), mode PM + senior dev
