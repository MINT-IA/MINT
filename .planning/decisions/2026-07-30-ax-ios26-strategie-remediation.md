---
description: Stratégie de remédiation de l'effondrement AX iOS 26.2 (Proposed) — pilote app-side sur le chemin du gate (retrait des wrappers Semantics racine), upgrade Flutter 3.44.8 planifié, migration SliverAppBar conditionnée au re-test, quarantaine outillage documentée.
---

# AX iOS 26.2 — stratégie de remédiation (Proposed)

Panel 2026-07-30 : a11y/VoiceOver + Flutter engine + lead séquencement,
sur diagnostic instrumenté (8 builds sim, comptages de nœuds cités dans
`.claude/agent-memory-local/mint-mobile/project_ios26_ax_tree_collapse.md`).

## Contexte

Sur iOS 26.2 / Flutter 3.41.6, deux déclencheurs indépendants effondrent
l'arbre AX des routes poussées au-dessus de la ShellRoute :

1. **Wrapper racine** `Semantics(container:true, explicitChildNodes:true)`
   (motif hérité ILLOG-02) → double frontière avec le `scopesRoute` que
   ModalRoute pose déjà (`routes.dart:2643`) → 1 nœud au repos.
2. **SliverAppBar** dans un CustomScrollView → re-effondrement au scroll
   (lignée flutter #61012 ; fix candidat #184155 livré en 3.44.0, mais
   ciblé 1-fichier et actif seulement VoiceOver-on — effet sur notre
   matrice idb NON prouvé).

Empreintes mesurées : 47 fichiers écrans avec SliverAppBar, 11 avec les
deux déclencheurs, 3 wrappers racine identifiés sur le chemin du gate
(first_job, rente_vs_capital, coach_chat). Gravité : bug VoiceOver de
production (WCAG 4.1.2 / EN 301 549 ; exposition EAA réelle — archétypes
expat_eu/cross_border). Le perfect-set asserte sur du texte (0 assert par
id) : silencieusement dégradable sur 26.2 ; l'effondrement siège dans le
chemin du gate (`mint2_quality_gate.sh:18`).

## Décision (Proposed)

1. **Pilote app-side maintenant** : retirer le wrapper Semantics racine des
   3 écrans du chemin du gate (retour au défaut du framework — la frontière
   ModalRoute demeure), re-gater les flows Maestro sur ids internes
   (`firstjob-net-value`…), verrous SemanticsTester côté widget tests,
   évidence idb au repos + après scroll. Panel design 4 lentilles sur le
   motif (une fois), pas par écran.
2. **Ne PAS migrer les 47 SliverAppBar maintenant** : décision reportée
   après re-test sur Flutter 3.44.8 (le fix engine peut rendre la migration
   caduque ; il est VoiceOver-gated donc seul un test VoiceOver réel tranche).
3. **Upgrade Flutter 3.44.8 planifié** (piste parallèle, ~2-5 j de triage) :
   contraintes pub compatibles (go_router/provider/intl vérifiés), 3.41.x en
   fin de vie hotfix. Inclut le pin des 2 workflows qui flottent déjà sur
   stable (`walker_nightly.yml:73`, `journey-os-runtime-replay.yml:61`).
4. **Quarantaine outillage documentée** : asserts sémantiques des routes
   poussées non migrées = non-gating sur 26.2 (annotés), pixel diffs
   vivants, ré-armement des asserts obligatoire à chaque migration.
5. **Gates de preuve** : matrice idb multi-runtime (acquérir 1 runtime iOS
   18.x — gate dur du rollout large, pas du pilote) ; session VoiceOver
   réelle sur device = G2 Julien (VoiceOver n'existe pas sur simulateur) ;
   issue upstream à filer (repro minimal double-frontière).

## Séquence

Étape 0 : ADR + runtime antérieur en acquisition · Étape 1 : pilote 3 écrans
· Étape 2 : flow d'acceptation vert sur ids internes + G2 VoiceOver = valeur
débloquée · Étape 3 : politique quarantaine codifiée · Étape 4 : upgrade
3.44.8 puis re-test, et seulement alors décision sur les 47.

## Counter-arguments and data gaps

### Contre-arguments

- **« Upgrade d'abord, pilote ensuite »** : rejeté — la double frontière
  n'est corrigée nulle part engine-side ; l'upgrade seul ne rend aucun
  écran lisible ; le pilote est indépendant de la version.
- **« Big-bang 47 écrans »** : rejeté — non-revuable, chaque écran porte
  une décision visuelle (AppBar), et #184155 peut rendre le chantier
  caduque ; par tranches sur les lots 12D.
- **« Wrapper conditionnel par version d'OS »** : rejeté — aucune
  littérature ne le valide, double la matrice de test, préserve un nœud
  qui ne rend aucun service (scopesRoute non-focusable par définition).
- **« Attendre un runtime antérieur avant le pilote »** : risque accepté
  pour 3 écrans à revert rapide — l'argument structurel (frontière
  framework conservée) est sourcé ; le runtime reste gate dur du rollout.

### Data gaps

- Comportement VoiceOver réel (l'évidence est idb-only) → fermé par G2.
- Comportement iOS 18/26.0-26.1 sans wrapper → fermé par la matrice
  multi-runtime (runtime à acquérir).
- Effet réel de 3.44.8 sur le re-effondrement au scroll → fermé par le
  re-test post-upgrade (VoiceOver-on).
- Décompte exact des wrappers racine (3 vs 19 selon la voix) → grep
  déterministe à l'exécution du pilote.

## Sources

flutter/flutter #61012 · #184155 (mergée 2026-04-06, ancêtre du tag 3.44.0,
absente de 3.41.x — vérifié par compare API) · #66308 · #67345 · release
notes 3.44.0 · scopesRoute API docs · routes.dart:2643 (SDK local) ·
EN 301 549 / EAA (services financiers, en vigueur 2025-06-28).
