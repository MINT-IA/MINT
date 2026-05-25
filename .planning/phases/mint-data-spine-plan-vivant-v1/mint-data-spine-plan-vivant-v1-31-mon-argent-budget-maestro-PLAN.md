description: Plan 31 ajoute un flow Maestro pour prouver la navigation Mon Argent et Budget Setup.

# Plan 31 — Mon Argent / Budget Maestro

## Objectif

Ajouter un flow simulateur qui vérifie les surfaces financières centrales avec des ancres iOS stables.

## Flow

`tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml`

## Scénario

1. Lancer l'app avec état propre.
2. Ouvrir `/mon-argent`.
3. Vérifier le résumé data spine, la situation, la trajectoire, le budget et le patrimoine.
4. Ouvrir `/budget/setup`.
5. Saisir logement et LAMal.
6. Vérifier le total live et les actions.

## Vérification

- Build iOS simulateur avec `MINT_E2E_ARCHETYPE=julien_swiss`.
- Installer l'app.
- Lancer le flow via `maestro_with_watchdog.sh`.
