# Maestro Evidence — Plan 39

## Command

```sh
bash tools/simulator/maestro_env.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml \
  --format junit \
  --output .planning/_walker/maestro-evidence-20260525T103909-plan39/maestro.xml
```

## Result

- Flow: `flow_mon_argent_budget_setup_spine`
- Device: iPhone 17 Pro, iOS 26.2
- Result: success
- Duration: 34s

## Screenshots

- `mon-argent-01-data-spine.png`
- `mon-argent-02-budget-setup.png`
- `mon-argent-03-budget-direct-relaunch.png`
- `mon-argent-04-coach-return.png`

## Budget Regression Check

- Budget setup field values: CHF 2'200 housing, CHF 420 LAMal.
- Direct `/budget` relaunch values: CHF 2'200 housing, CHF 420 LAMal.
- The screenshot regression with appended millions-level monthly charges did not reproduce.
