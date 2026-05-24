description: Plan 26 made the shared Maestro cold-launch fragment reach Aujourd'hui again; F001 still stops at its documented card-key precondition.

# Plan 26 — Summary

## Changed

- `_fragment_cold_launch_to_aujourdhui.yaml` now conditionally handles:
  - `Ouvrir`
  - `Je regarde d’abord`
  - the US tax question with `Non`
  - canton selection with `VD`
  - `Suivant`, `Continuer`, `Terminer`, and `Voir`
- The fragment then deep-links to `/home` and asserts `Aujourd'hui`.

## Verification

- Initial F001 run failed before the fragment reached home, first at `Ouvrir`,
  then at the US tax question, then at age/canton/storyboard transition.
- Final F001 run showed:
  - `Run ../maestro-perfect-set/_fragment_cold_launch_to_aujourdhui.yaml... COMPLETED`
  - `Assert that ".*Aujourd'hui.*" is visible... COMPLETED`
  - outer flow failure remained at `card_mon_3a_2026`, matching the flow header's documented precondition.
