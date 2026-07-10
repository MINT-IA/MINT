# Interaction Registry Index

> Generated view. Source of truth: `interactions/*.yaml`.

| flow | edge | from | to | trigger | transition | proof |
|---|---|---|---|---|---|---|
| revenu_to_mortgage | `db.edge.revenu.save_facts` | `db.route.revenu` | `db.route.revenu` | submit | in_shell | `apps/mobile/.maestro/f2_datablock_to_mortgage.yaml` |
| revenu_to_mortgage | `db.edge.revenu.open_mortgage_deeplink` | `db.route.revenu` | `mortgage.route.hypotheque` | system | reset_stack | `apps/mobile/.maestro/f2_datablock_to_mortgage.yaml` |
