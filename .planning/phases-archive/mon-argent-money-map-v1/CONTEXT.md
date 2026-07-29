description: Contexte GSD pour nettoyer Mon argent et Budget autour du fil canonique CoachProfile -> DataSpine/BudgetSnapshot.

# Phase mon-argent-money-map-v1: Context

**Gathered:** 2026-05-25
**Status:** Executed, verified on simulator

## Domain

Mint doit rendre la situation financière lisible sans devenir un cockpit de
KPIs. Les photos VZ/Raiffeisen rappellent le modèle traditionnel: dossier,
checklist, rendez-vous, planification retraite statique. Mint doit transformer
ces sujets en parcours vivant: voir, comprendre, décider, planifier, rester en
track.

## Decisions

- `wizard_answers_v2` reste la source locale persistée.
- `CoachProfile` reste la couche d'hydratation.
- `DataSpineSnapshot` et `BudgetSnapshot` sont les read models à renforcer.
- Aucun nouveau modèle persistant MoneyMap n'est créé dans cette phase.
- `BudgetInputs` devient un adapter d'édition/fallback, pas une vérité
  financière globale.
- `Mon argent` doit devenir un cockpit d'action en onglets: Aujourd'hui, Mois,
  Patrimoine, Prévoyance, Futur.
- `Budget mensuel` doit rester un atelier de flux mensuel: revenu, charges,
  épargne prévue, disponible, détails repliables.

## Current Code Risks

- `/budget` restaure `budget_inputs_v1` même quand un `CoachProfile` canonique
  existe.
- `BudgetScreen` reconstruit un `PresentBudget` local depuis `BudgetInputs`.
- `MonArgentScreen` lit déjà `DataSpine/BudgetSnapshot`, donc il peut diverger
  de `/budget`.
- Certaines clés budget ont des doublons historiques, notamment loyer/LAMal.
- Le budget a des sections redondantes au-dessus du fold: hero, breakdown,
  flow map, formula proof, action insight.

## References

- `docs/data-flow.md` — source de vérité et writers autorisés.
- `docs/MINT_IDENTITY.md` — lucidité, pas banque ni comparateur.
- `docs/DESIGN_SYSTEM.md` — un élément dominant par vue.
- `docs/VOICE_SYSTEM.md` — chiffre, contexte, action.
- `apps/mobile/lib/models/data_spine_snapshot.dart`
- `apps/mobile/lib/models/budget_snapshot.dart`
- `apps/mobile/lib/services/budget_living_engine.dart`
- `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart`
- `apps/mobile/lib/screens/budget/budget_container_screen.dart`
- `apps/mobile/lib/screens/budget/budget_screen.dart`

## Deferred

- Full open-banking transaction categorization.
- Full visual redesign of all patrimoine/profile drawers.
- Arbitrage tabs and coach personality upgrades.
- Backend event-log/bitemporal cutover.

## Execution Notes

- Budget-first answers now hydrate a partial `CoachProfile` before E2E seeds
  are considered, so values entered in budget setup survive a relaunch.
- `/budget` prefers profile-derived `BudgetInputs` when a `CoachProfile`
  exists; `budget_inputs_v1` remains a fallback for direct opens before
  profile hydration.
- `Mon argent` follows the same profile-first rule, so its budget card cannot
  keep showing a stale monthly cache while `/budget` shows the profile-derived
  calculation.
- `Mon argent` now exposes a money-map segmented IA:
  Aujourd'hui, Mois, Patrimoine, Prévoyance, Futur. Each tab reuses existing
  read models/widgets rather than adding a new store.
- Money-map tab labels are now localized through ARB across fr/en/de/es/it/pt
  and generated into `app_localizations_*`.
- Budget calculation detail is now secondary/repliable to reduce first-viewport
  repetition.
- Maestro evidence screenshots are stored under `evidence/`; latest watchdog
  artifact: `.planning/_walker/20260525T194442`.
