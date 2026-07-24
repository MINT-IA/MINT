---
date: 2026-07-24
status: Verified
description: "W1 Travail triade (firstJob/newJob/jobLoss) — état réel sur dev vs audit périmé. Le code est complet+câblé ; la preuve de rendu-calculé au niveau widget est maintenant complète pour les 3 écrans. La preuve end-to-end sur sim est bloquée par une régression du harnais Maestro (onboarding)."
related:
  - .planning/decisions/2026-07-24-campagne-contenu-officiel-garanti.md
  - apps/mobile/test/screens/life_event_screens_additional_smoke_test.dart
---

# W1 Travail triade — preuve runtime (état vérifié sur dev @4c8a220c5)

## TLDR

L'audit 2026-07 (SHA gelé) listait la triade Travail comme « incomplète, sans preuve runtime ». Vérification sur dev courant (agent mint-mobile, citations) : **l'audit est périmé sur le code** — les 3 événements (firstJob / newJob / jobLoss) sont réels, routés, atteignables, et service-backed. Le seul écart réel vs le mandat ADR:48 (« complète avec preuve runtime ») était la preuve de **rendu-calculé**. Elle existait déjà pour 2 des 3 écrans (tests widget passants) ; ce bead ajoute le 3e (job_comparison). La preuve **end-to-end sur sim** reste bloquée par une régression du harnais Maestro (voir §Blocage).

## Ce qui était déjà prouvé (audit périmé)

- `first_job_screen` : `_calculate()` en `initState` → rend le premier éclairage + CHF calculé. Preuve : `test/screens/life_event_screens_additional_smoke_test.dart` groupe FirstJobScreen, test « shows results section with CHF amounts » (passant sur dev).
- `unemployment_screen` (jobLoss) : `calculateBenefits()` en `initState` → rend l'indemnité CHF. Preuve : même fichier, groupe UnemploymentScreen, test « shows result after initial calculation » (passant).
- `job_comparison_screen` (newJob) : `job_comparison_profile_seed_test.dart` prouvait le **seeding des entrées** depuis le profil, mais **pas** le rendu de la sortie calculée (verdict) après le tap « Comparer ».

## Ce que ce bead ajoute

Un 3e test de rendu-calculé pour `JobComparisonScreen`, dans le fichier qui héberge déjà les 2 autres : tap « Comparer » → assert que la carte VERDICT (gated sur `_result != null`) apparaît (absente avant le tap, présente après → garde anti-façade auto-portée). Les 3 écrans de la triade ont désormais une preuve de rendu-calculé passante et gatée en CI.

## Blocage : preuve end-to-end sur sim (harnais Maestro cassé sur dev)

La preuve « utilisateur réel : lance → auth → navigue → écran → voit la valeur » n'est **pas** livrable actuellement : le fragment canonique `tools/simulator/flows/maestro-perfect-set/_fragment_cold_launch_to_aujourdhui.yaml` **échoue sur dev** (probe 2026-07-24 : atteint `openLink mintapp:///home` puis l'assertion `.*Aujourd'hui.*` échoue — l'onboarding storyboard n'est pas complété, `/home` redirige vers `/onb`). Cela affecte **tous** les flows perfect-set qui dépendent de ce fragment, pas seulement la triade. Le chemin authentifié (build `--dart-define=MINT_DEV_AUTH_TOKEN`) contourne l'onboarding mais exige un build iOS complet + un token dev.

**Bead séparé recommandé** : réparer le fragment cold-launch (dérive du storyboard onboarding) OU documenter le chemin authentifié comme preuve sim canonique, puis ajouter `tools/simulator/flows/travail_triad.yaml` (Explorer → Travail → 3 écrans, assert valeur CHF).

## Follow-up i18n (bead séparé, ne PAS fusionner)

Strings narratives service-layer hardcodées FR + bugs accents, rendues à l'écran (rule-5 i18n + rule-2 accents) : `unemployment_service.dart:110-250`, `job_comparison_service.dart:321-334` (`presente`/`criteres`/`indemnite`), `first_job_service.dart:199-249`, `app.dart:816,823` (`Chomage`/`Independant`). Une preuve sim en locale non-FR échouerait dessus.

## Data gaps / limites

- La preuve widget prouve le rendu-calculé, pas le parcours utilisateur complet (auth+nav). C'est une garde anti-façade + anti-régression, pas un substitut à la preuve sim (0-TRUST §9 distingue « tests verts » de « feature marche pour l'utilisateur »).
- `MINT_E2E_ARCHETYPE` injecte un profil en bypassant le flush wizard (`coach_profile_provider.dart:686`) : valide pour prouver le rendu écran, **non** pour prouver le contrat d'onboarding onb-01.
