# Maestro Evidence — Plan 40

## Command

```sh
bash tools/simulator/maestro_env.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml \
  --format junit \
  --output .planning/_walker/maestro-evidence-20260525T111635-plan40/maestro.xml
```

## Result

- Flow: `flow_mon_argent_budget_setup_spine`
- Device: iPhone 17 Pro, iOS 26.2
- Result: success
- Duration: 36s

## Numeric Assertions

- Asserted visible value matching housing: `2'200`.
- Asserted visible value matching LAMal: `420`.
- Asserted absent stale values: `19'272'200`, `420'420`.

## Screenshot Review

- `mon-argent-03-budget-direct-relaunch.png` shows one coherent budget story:
  CHF 5'379 net income, CHF 3'140 charges, CHF 0 future, CHF 2'239 available.
- The displayed arithmetic now matches the rounded rows:
  `5'379 - 2'200 - 520 - 420 - 0 = 2'239`.
