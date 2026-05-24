# Summary 12 — Drawer navigation smoke

## Résultat

Le flow `flow_drawer_navigation_smoke.yaml` est redevenu autonome depuis un cold launch simulateur.

## Changements

- Remplacement du bootstrap obsolète `_fragment_cold_launch_to_aujourdhui.yaml` par un deep-link `mintapp:///explore`.
- Suppression de la dépendance au bouton landing `Continuer sans compte`, qui route désormais volontairement vers `/onb`.
- Remplacement des retours iOS fragiles par des retours explicites vers `/explore` entre deux entrées drawer.
- Mise à jour des ancres réelles:
  - `/profile/bilan` → `MON PROFIL`;
  - `/documents` → `Coffre-fort`.
- Mise à jour du README perfect-set.
- Nettoyage de deux locators persona racine pour que `maestro_locator_audit.py` repasse.

## Vérification locale

- RED initial:
  - `bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml --format junit --output .planning/walker/maestro-flows/drawer-navigation-smoke/plan-12-red/result.xml`
  - Échec: `_fragment_cold_launch_to_aujourdhui.yaml` attendait `Aujourd'hui`, mais le CTA landing route maintenant vers `/onb`.
- GREEN:
  - `bash tools/simulator/maestro_with_watchdog.sh test tools/simulator/flows/maestro-perfect-set/flow_drawer_navigation_smoke.yaml`
  - `maestro returned 0`, artifact log: `.planning/_walker/20260524T080320/maestro.log`.
- `python3 tools/checks/maestro_locator_audit.py`
  - `[OK] All locators resolve.`
- `python3 tools/checks/accent_lint_fr.py --file ...`
  - exit 0 on the changed planning/flow files.

## Limite volontaire

Cette phase ne corrige pas encore `flow_empty_state_cascade.yaml`, qui garde une précondition `/explore` séparée dans le README. C'est le prochain bon candidat navigation si on continue le perfect-set avant de revenir au budget/data-spine.
