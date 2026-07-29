description: Closeout for Mon Argent compact selector.

# Phase mon-argent-compact-selector-v1 — Summary

## Result

Mon Argent section navigation is now adaptive:

- normal widths keep the existing `SegmentedButton`;
- compact widths render a two-row `ChoiceChip` selector;
- `Futur` is directly visible/tappable at 320px without horizontal hunting.

No financial calculation, data spine shape, budget model, route, or persisted
state changed.

## Files Changed

- `apps/mobile/lib/screens/mon_argent/mon_argent_screen.dart`
- `apps/mobile/test/screens/mon_argent_screen_test.dart`

## Verification

```bash
cd apps/mobile && flutter analyze --no-fatal-infos \
  lib/screens/mon_argent/mon_argent_screen.dart \
  test/screens/mon_argent_screen_test.dart
```

PASS — no issues.

```bash
cd apps/mobile && flutter test test/screens/mon_argent_screen_test.dart
```

PASS — 7 tests.

```bash
mint_tools.validate_arb_parity
```

PASS — 6 locales, 6817 keys each.

```bash
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --no-codesign --debug \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

PASS — built `apps/mobile/build/ios/iphonesimulator/Runner.app`.

```bash
xcrun simctl install booted apps/mobile/build/ios/iphonesimulator/Runner.app
```

PASS.

```bash
MINT_WALKER_ARTIFACTS=.planning/_walker/mon-argent-compact-selector-v1 \
  bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml \
  --output .planning/walker/maestro-flows/mon-argent-compact-selector-v1/result.xml \
  --format junit
```

PASS — 42s, result:
`.planning/walker/maestro-flows/mon-argent-compact-selector-v1/result.xml`.

## Claude Review

Claude Opus was used for next-phase selection and recommended this scope before
the broader money-trust-contract work. A later read-only code-review invocation
stalled without output and was killed after several minutes; deterministic
gates above were used as the merge criteria.

## Next

The next high-leverage phase should be `money-trust-contract-v1-00-figure-audit`:
enumerate every visible CHF figure across Mon Argent, Budget, Coach, and 3a
with producer, source, freshness/confidence signal, and consumer screens before
adding any trust-chip code.
