# PLAN — Wave 0 : Walkthrough de vérité

**Branche** : `feature/wave-0-walkthrough-verite` (à créer depuis dev après merge PR #353)
**Durée max** : 90 min
**Livrable** : `.planning/wave-0-walkthrough-verite/FINDINGS.md`
**PR cible** : aucun code commit, juste artefact documentaire

## Goal

Avant de démarrer Wave B-prime (home orchestrateur), **vérifier avec le device** ce que l'utilisateur voit réellement dans MINT tel que dev le livre aujourd'hui. Source de vérité empirique pour éclairer Wave B-prime.

Panel iconoclaste a prouvé par le code : `aujourdhui_screen.dart` = 301 lignes, 0 CapEngine. Wave 0 confirme visuellement.

## Non-goals

- Pas de fix
- Pas de code
- Pas de dispatch aux agents (fait par moi-même)
- Pas de 50 screenshots (cap strict 15-20)

## Protocole

### Setup (5 min)

1. iPhone 17 Pro sim UDID `B03E429D-0422-4357-B754-536637D979F9`
2. Build staging :
   ```
   cd apps/mobile && flutter build ios --simulator --debug \
     --no-codesign \
     --dart-define=API_BASE_URL=https://mint-staging.up.railway.app/api/v1
   ```
3. Install + launch sur sim
4. `export PATH="$HOME/Library/Python/3.9/bin:$PATH"` pour idb

### 12 flows à parcourir (5 min chacun max)

| # | Flow | Attendu | AX tree + 1 screenshot si décision |
|---|---|---|---|
| 1 | Cold launch → landing | Animation 3.2s, CTA "Commencer", disclaimer LSFin footer | screenshot |
| 2 | Tap CTA → coach chat | Silent opener ou intent chip ? | screenshot si surprise |
| 3 | Tap tab Aujourd'hui | Qu'est-ce qui s'affiche ? TensionCards + timeline ? Cap du jour ? Nudge ? FRI ? | screenshot obligatoire |
| 4 | Tap tab Explorer | Grid 7 hubs, personnalisé ou template ? | screenshot |
| 5 | Open hub Retraite → premier écran | Quel écran ? Hub template ou ExploreHubScreen ? | screenshot |
| 6 | Open simulateur Rachat LPP (depuis hub) | Prefill profil ? Valeurs par défaut ? | screenshot |
| 7 | Tap scan document (bouton principal ?) | Où est ce bouton ? Capture sheet ? | screenshot |
| 8 | Scan un certificat (mock si golden) | DocumentImpactScreen, confidence ring animation ? | screenshot |
| 9 | Après scan → où retourner ? | Back button, retour coach, retour home ? | screenshot |
| 10 | Ouvrir ProfileDrawer (endDrawer) | Contenu, actions, lien dossier ? | screenshot |
| 11 | Tester une question coach quantitative | "j'ai 49 ans salaire 120k VS, LPP 70k, mon 3a vaut-il le coup" → latence, qualité, widget inline ? | screenshot |
| 12 | App fermer + rouvrir | Cold restart replays-t-il landing ou skip vers home ? | screenshot si replay |

### Pour chaque flow

- Note l'écran atterri
- Note la latence perçue (instantané / 1-2s / 3+s / timeout)
- Note les éléments visibles (titre, chiffres, CTA, widgets)
- Note si MINT reconnaît l'utilisateur (prénom, archétype, scan précédent)
- Note les frictions (écran blanc, erreur, bouton absent, text overflow)
- AX tree uniquement quand screenshot obligatoire

### Profil utilisé

Fresh install anonymous. Pas de golden Julien+Lauren préchargé (car demo toggle n'existe pas encore — c'est Wave F). Accepter que les simulateurs afficheront des estimations vides.

Alternative si temps : créer manuellement un profil via questionnaire onboarding + 2 save_fact via chat (age=49, canton=VS) pour activer les calculs.

## Livrable `.planning/wave-0-walkthrough-verite/FINDINGS.md`

Format :
```
## Flow N — <nom>
Écran : <path route>
État : mort / tiède / vivant
Latence : <ms>
Éléments visibles : <liste courte>
Reconnaissance utilisateur : oui/non/partiel
Frictions : <liste>
Screenshot : <si obligatoire>
Verdict : <1 phrase>
```

À la fin :
```
## Synthèse globale
- 3 forces objectives
- 3 frictions majeures
- 1 recommandation pour Wave B-prime (ajuster priorité commits)
```

## Gate sortie Wave 0

- 12 flows couverts en ≤ 90 min
- FINDINGS.md avec verdict par flow + synthèse
- Décision explicite : Wave B-prime démarre comme planifié OU ajustement prioritaire si blocker découvert

## Après Wave 0

- Si rien de bloquant : écrire `PLAN-WAVE-B.md` détaillé → 3 panels review → EXECUTE
- Si blocker critique : nouvelle ADR + Wave 0.5 correctif
- Dans tous les cas : commit docs dans `.planning/wave-0-walkthrough-verite/` sur une branche dédiée, pas de code mobile/backend touché

## Décision d'exécution

Étant donné la complexité (90 min de device walkthrough avec screenshots + AX tree), et considérant que cette session est déjà riche, **option réaliste** :
1. **Wave 0 "light"** (~30 min) : build + launch + 5 flows critiques (1, 3, 7, 8, 11) sans les 7 autres
2. Si Wave 0 light ne révèle pas de blocker, enchaîner sur Wave B-prime
3. Wave 0 "full" (12 flows) peut être différée en Wave F release walkthrough

Cette version light reste un investissement device-truth, pas du code spéculatif, mais borne le coût contexte.
