description: Plan 33 ajoute un repère visuel compact à la carte budget de Mon Argent.

# Plan 33 — Mon Argent budget flow visual

## Objectif
Rendre la carte budget plus lisible et plus visuelle sans créer de nouveau modèle.

## Contexte
La carte `Ton budget ce mois` affichait seulement trois lignes de chiffres. C'est correct techniquement, mais faible pour une app de lucidité financière : l'utilisateur doit voir immédiatement comment son revenu se transforme en dépenses et reste mensuel.

## Critères
- Ajouter un repère visuel stable revenu / dépenses / reste.
- Garder les libellés i18n existants.
- Exposer un identifiant `mon_argent_budget_flow_bar` pour tests et Maestro.
- Ne pas modifier les calculs.

## Vérification
- `cd apps/mobile && flutter test test/widgets/mon_argent_budget_summary_card_test.dart`
- Flow Maestro `flow_mon_argent_budget_setup_spine.yaml` enrichi avec l'assertion du nouveau repère.
