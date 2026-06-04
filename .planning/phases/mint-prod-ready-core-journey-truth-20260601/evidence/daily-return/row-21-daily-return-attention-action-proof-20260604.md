# Row 21 — daily return attention/action proof — 2026-06-04

## Status

`PARTIAL`.

This proof shows that the `Aujourd'hui` daily-return screen can surface a
current attention card and expose direct next-action verbs on iPhone 17 Pro.
It does **not** yet prove the full loop where completing the action mutates the
daily state and the next return shows a different priority.

## Bug found and fixed

The runtime probe exposed a real route bug: tapping `Simule` on the Cap du jour
action bar navigated to `/explorer?simulate=cap_du_jour`, which is not a
registered route. The app landed on `Page introuvable`.

Fix:

- `CapDuJourBanner` now routes `Simule` to `/explore?simulate=cap_du_jour`.
- `MintCardActionBar` verb chips now expose stable Semantics identifiers:
  `mint_card_action_explain`, `mint_card_action_simulate`,
  `mint_card_action_reassure`.
- The demo screen and action-bar tests now use `/explore`, matching the route
  registry.

## Runtime evidence

Flow:

```bash
MAESTRO_HARD_LIMIT=240 MAESTRO_STALL_THRESHOLD=90 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-21-daily-return-attention-action-20260604T183725 \
  bash tools/simulator/maestro_with_watchdog.sh test \
  --udid B03E429D-0422-4357-B754-536637D979F9 \
  --debug-output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-21-daily-return-attention-action-20260604T183725/debug \
  --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-21-daily-return-attention-action-20260604T183725/result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row21_daily_return_attention_action.yaml
```

Result:

- JUnit: `tests=1`, `failures=0`, `time=21.0`.
- Watchdog: `EXIT_CODE=0`.
- Device: iPhone 17 Pro iOS 26.2 simulator
  `B03E429D-0422-4357-B754-536637D979F9`.

Artifacts:

- `evidence/maestro-ci/row-21-daily-return-attention-action-20260604T183725/result.xml`
- `evidence/maestro-ci/row-21-daily-return-attention-action-20260604T183725/maestro.log`
- `evidence/maestro-ci/row-21-daily-return-attention-action-20260604T183725/01-row21-aujourdhui-cap-action.jpg`
- `evidence/maestro-ci/row-21-daily-return-attention-action-20260604T183725/02-row21-simule-explorer.jpg`

Runtime snapshot after returning to `/home` exposed the stable action targets:

```text
card: Cap du jour : Versement 3a 2026
mint_card_action_explain
mint_card_action_simulate
mint_card_action_reassure
```

## Static/widget evidence

```bash
cd apps/mobile
flutter gen-l10n
flutter test \
  test/widgets/mint_card_action_bar_test.dart \
  test/widgets/mint_card_action_bar_routing_test.dart \
  test/widgets/aujourdhui/cap_du_jour_banner_test.dart \
  test/widgets/confidence_score_card_actionbar_test.dart
```

Result: `27/27` tests passed.

## Runtime Guidance Quality Review

- `mechanical proof`: JUnit green, watchdog `0`, screenshots cover the daily card and successful `Simule` navigation to Explorer.
- `user-visible outcome`: user sees a current attention card and can choose explain/simulate/reassure verbs.
- `guidance quality`: coherent for first attention/action surface; it fixes the previous broken route to a real exploration surface.
- `non-absurd`: `Simule` no longer sends the user to `Page introuvable`.
- `inclusive`: the proof does not introduce salary-only or unsupported-archetype assumptions.
- `financial trust`: it proves action routing only; it does not claim completion, advice quality, or priority correctness after action.
- `remaining qualitative gaps`: completion/acknowledgement, persistence, and next-priority behavior remain open.

## Remaining gap

Keep Row 21 at `PARTIAL` until there is a proof that:

- the daily action can be completed or acknowledged,
- the completed action is persisted,
- returning to `Aujourd'hui` shows the next correct priority instead of the
  same attention card.
