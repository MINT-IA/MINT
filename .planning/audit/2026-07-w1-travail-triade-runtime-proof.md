---
date: 2026-07-24
status: Verified
description: "W1 Travail triade (firstJob/newJob/jobLoss) — état réel sur dev vs audit périmé. Le code est complet+câblé ; ce bead établit une preuve de rendu-CALCULÉ (widget gaté sur le résultat) pour les 3 écrans — en durcissant 2 tests faibles (CHF générique) et en ajoutant le 3e. La preuve end-to-end sur sim est bloquée par une régression du harnais Maestro (onboarding)."
related:
  - .planning/decisions/2026-07-24-campagne-contenu-officiel-garanti.md
  - apps/mobile/test/screens/life_event_screens_additional_smoke_test.dart
---

# W1 Travail triade — preuve runtime (état vérifié sur dev @4c8a220c5)

## TLDR

L'audit 2026-07 (SHA gelé) listait la triade Travail comme « incomplète, sans preuve runtime ». Vérification sur dev courant (agent mint-mobile, citations) : **l'audit est périmé sur le code** — les 3 événements (firstJob / newJob / jobLoss) sont réels, routés, atteignables, et service-backed. Le seul écart réel vs le mandat ADR:48 (« complète avec preuve runtime ») était la preuve de **rendu-calculé**. Correction post-Codex (#1022 r1 FAIL) : les 2 tests widget « pré-existants » n'étaient **pas** des preuves de rendu-calculé — ils assertaient `CHF` générique, satisfait par les libellés d'input inconditionnels. Ce bead **durcit les 3** en assertant un widget gaté sur `_result != null`. La preuve **end-to-end sur sim** reste bloquée par une régression du harnais Maestro (voir §Blocage).

## L'état réel avant ce bead (post-Codex, corrigé)

- `first_job_screen` : `_calculate()` en `initState` rend bien le résultat, MAIS le test « shows results section with CHF amounts » assertait `find.textContaining('CHF')` — **faux positif** : le slider de salaire rend des libellés CHF min/max inconditionnels (`first_job_screen.dart:374-389`). Le test restait vert même sans résultat calculé.
- `unemployment_screen` (jobLoss) : même défaut — le slider de gain assuré rend `CHF` inconditionnellement (`unemployment_screen.dart:196-212`). Le test « shows result after initial calculation » était donc faible.
- `job_comparison_screen` (newJob) : `job_comparison_profile_seed_test.dart` prouvait le **seeding des entrées**, pas la sortie calculée.

## Ce que ce bead livre

Preuve de rendu-**calculé** pour les 3 écrans, via l'assertion d'un widget **structurellement gaté sur le résultat** (impossible à rendre sans compute), pas `CHF` générique :
- `first_job` : `SalaryBreakdownWidget` (consomme `_result!.brut/netEstime/...`, gaté `if (_result != null)`). Preuve RED déterministe : neutraliser `_calculate()` → test rouge, restauré.
- `unemployment` : `UnemploymentTimelineWidget` (consomme `_result!.timeline`, même gate).
- `job_comparison` : carte VERDICT (`jobCompareVerdictLabel`, gate `_result != null`) après le tap « Comparer » — absente avant, présente après.

Les 3 écrans de la triade ont désormais une preuve de rendu-calculé passante, gatée en CI, et déterministe (non satisfiable par des libellés d'input).

## Blocage : preuve end-to-end sur sim (harnais Maestro cassé sur dev)

La preuve « utilisateur réel : lance → auth → navigue → écran → voit la valeur » n'est **pas** livrable actuellement : le fragment canonique `tools/simulator/flows/maestro-perfect-set/_fragment_cold_launch_to_aujourdhui.yaml` **échoue sur dev** (probe 2026-07-24 : atteint `openLink mintapp:///home` puis l'assertion `.*Aujourd'hui.*` échoue — l'onboarding storyboard n'est pas complété, `/home` redirige vers `/onb`). Cela affecte **tous** les flows perfect-set qui dépendent de ce fragment, pas seulement la triade. Le chemin authentifié (build `--dart-define=MINT_DEV_AUTH_TOKEN`) contourne l'onboarding mais exige un build iOS complet + un token dev.

**Bead séparé recommandé** : réparer le fragment cold-launch (dérive du storyboard onboarding) OU documenter le chemin authentifié comme preuve sim canonique, puis ajouter `tools/simulator/flows/travail_triad.yaml` (Explorer → Travail → 3 écrans, assert valeur CHF).

## Follow-up i18n (bead séparé, ne PAS fusionner)

Strings narratives service-layer hardcodées FR + bugs accents, rendues à l'écran (rule-5 i18n + rule-2 accents) : `unemployment_service.dart:110-250`, `job_comparison_service.dart:321-334` (`presente`/`criteres`/`indemnite`), `first_job_service.dart:199-249`, `app.dart:816,823` (`Chomage`/`Independant`). Une preuve sim en locale non-FR échouerait dessus.

## Data gaps / limites

- La preuve widget prouve le rendu-calculé, pas le parcours utilisateur complet (auth+nav). C'est une garde anti-façade + anti-régression, pas un substitut à la preuve sim (0-TRUST §9 distingue « tests verts » de « feature marche pour l'utilisateur »).
- `MINT_E2E_ARCHETYPE` injecte un profil en bypassant le flush wizard (`coach_profile_provider.dart:686`) : valide pour prouver le rendu écran, **non** pour prouver le contrat d'onboarding onb-01.
