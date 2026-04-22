---
id: ADR-20260422
title: MVP wedge onboarding — archétype déféré à canvas N3
status: accepted
date: 2026-04-22
authors:
  - Julien (fondateur)
  - Claude (audit PR #380)
related:
  - PR-380 (feat(onboarding): MVP wedge storyboard v2)
  - .planning/mvp-wedge-onboarding-2026-04-21/STORYBOARD-FINAL-LOCKED.md
  - docs/AGENTS/swiss-brain.md (8 archétypes)
  - apps/mobile/lib/services/income_converter.dart
---

# MVP wedge onboarding — archétype déféré à canvas N3

## Contexte

Le storyboard v2 locké 2026-04-22 capture en 9 tours : intent, âge, canton, revenu
net mensuel, email. **L'archétype n'est pas capturé.** Les 3 scènes N2
(`RenteTrouee`, `CapaciteAchat`, `3aLevier`) appellent toutes
`IncomeConverter.netMonthlyToGrossAnnual(netMonthly)` sans passer le paramètre
`isSalaried`, ce qui applique le facteur par défaut `1.17` (salarié AVS+LPP+LAA+IJM).

Pour les **indépendants** (facteur `1.10`), les **expats FATCA**, les
**frontaliers permis G**, et les **returning_swiss**, l'estimation brut→net diverge
d'environ 5–7 %. Les 8 archétypes MINT (swiss_native, expat_eu, expat_us FATCA,
cross_border, indep_with_lpp, indep_no_lpp, returning_swiss, plus un 8ème défini
dans swiss-brain.md) ne sont donc pas différenciés à ce stade du flow.

## Options considérées

### A — Ajouter un tour « statut professionnel » (T3.5 ou T5)
Capturer salarié / indépendant / expat / frontalier avant les scènes N2. Pour :
précision immédiate. Contre : +1 friction dans un flow déjà à 9 étapes pour un
MVP wedge. Le but du wedge est de **minimiser la friction jusqu'au chiffre choc**,
pas de faire un onboarding complet.

### B — Déférer au canvas N3 post-magic-link *(retenu)*
Les scènes N2 du onboarding donnent une estimation « medium confidence »
(`EnhancedConfidence` axe accuracy). Le coach, au premier canvas N3 ouvert après
l'email sealing, re-pose la question d'archétype dans un contexte narratif
(« Pour affiner ton chiffre, dis-moi comment tu perçois tes revenus : en fiche
de salaire, en factures, ou autre ? »). Le CoachProfile est alors upgraded
`accuracy: high`.

### C — Inférer depuis le canton + âge + revenu
Heuristique : canton GE ou permis G détecté via UI → frontalier présumé. Contre :
erreurs silencieuses, viole le principe « archétype explicite ».

## Décision

**Option B.** L'onboarding v2 ship avec l'hypothèse par défaut `isSalaried=true`
et `EnhancedConfidence.accuracy=medium`. Le coach canvas N3 porte la
responsabilité de la capture d'archétype explicite avant toute projection
financière en confidence `high`.

## Conséquences

### Positives
- **Friction onboarding préservée** — 9 tours, pas 10. Time-to-chiffre-choc < 90 s.
- **Progression naturelle** — le coach pose la question d'archétype dans un
  contexte narratif (post-wow), pas comme étape admin dans un wizard.
- **Doctrine MINT respectée** — chat-first, le coach mène. L'onboarding seed.
- **Dégradation gracieuse** — pour les 80 %+ salariés (swiss_native), les scènes
  N2 sont exactes. Pour les ~15-20 % autres, elles sont à ±5 % près — acceptable
  vu le framing « signal, pas conseil ».

### Négatives / risques
- **Indépendants voient un chiffre 5 % trop bas** sur capacité d'achat et rente.
  Mitigation : label `EnhancedConfidence.accuracy=medium` visible, phrase
  d'ouverture scène « c'est une première estimation ».
- **Le canvas N3 DOIT re-poser la question** avant toute projection `confidence=high`.
  Si jamais le N3 oublie → archétype reste `swiss_native` implicite.
  *Gate* : test Nyquist `canvas_n3_archetype_prompt_before_projection`.
- **Pas de donnée fiscale expat/FATCA** dans le wedge — un user US se voit comme
  un Swiss native. Mitigation : n'impacte pas le wedge (qui ne touche pas fiscalité
  US), mais le N3 doit re-catégoriser avant d'exposer les scènes tax-sensitives.

### Kill-policy
Si, après 30 jours de production, les analytics backend montrent :
- **>15 % des onboardés sont indépendants** (q_professional_status depuis
  canvas N3), OU
- **taux de ré-ouverture N3 par indépendants < 60 %** (ils ne corrigent pas
  l'estimation),

alors re-prioriser la capture d'archétype à un tour dédié T3.5 dans une
itération suivante. Le canvas N3 reste le re-ask de dernier recours.

## Implémentation

- `onboarding_provider.dart` — inchangé, ne capture pas archétype.
- `scenes/mint_scene_*.dart` — appellent `IncomeConverter.netMonthlyToGrossAnnual(netMonthly)`
  sans `isSalaried` (default = true).
- `CoachProfile` au flush T9 — `accuracy=medium` sur les projections dérivées
  du revenu.
- **Canvas N3** (TODO hors scope PR #380) — doit inclure un handshake
  archétype explicite avant toute projection confidence=high.

## Exit criteria

Cette ADR devient obsolète quand le canvas N3 ship avec capture archétype
explicite + test Nyquist vert. Doc archivée vers `decisions/archive/` une fois
la capture N3 validée device walkthrough.

## Références

- `apps/mobile/lib/services/income_converter.dart` — facteurs documentés
- `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_capacite_achat.dart:34`
- `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_rente_trouee.dart:41`
- `apps/mobile/lib/screens/onboarding/mvp_wedge/scenes/mint_scene_3a_levier.dart:52`
- `docs/AGENTS/swiss-brain.md` §archétypes (source de vérité 8 types)
