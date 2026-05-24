# Summary 10 — Microcopy menu eclair

## Resultat

Le menu eclair ne commence plus ses choix visibles par des etiquettes possessives comme "Mon", "Ma", "Mes", "Notre" ou "Nos".

## Changements

- Recriture des titres readiness dans les 6 ARB (`fr`, `en`, `de`, `es`, `it`, `pt`) pour des libelles plus action-first.
- Conservation des routes et prompts existants: le changement reste purement microcopy.
- Extension du test widget du resolver pour bloquer le retour des prefixes possessifs en francais.

## Verification locale

- Commit runtime: `cab9cf5c feat(mobile): polish lightning menu microcopy`.
- Diff: 8 fichiers, `+90/-64`, sous la limite PR locale de 300 lignes.
- Surface touchee:
  - `apps/mobile/lib/l10n/app_*.arb`;
  - `apps/mobile/test/widgets/coach/lightning_menu_readiness_resolver_test.dart`;
  - plan GSD `mint-data-spine-plan-vivant-v1-10-lightning-menu-microcopy-PLAN.md`.

## Limite volontaire

Cette phase ne change pas encore l'ergonomie du menu eclair lui-meme. Elle corrige d'abord la question utilisateur explicite: les libelles "par quoi on commence" ne doivent plus lire comme une liste de proprietes personnelles.
