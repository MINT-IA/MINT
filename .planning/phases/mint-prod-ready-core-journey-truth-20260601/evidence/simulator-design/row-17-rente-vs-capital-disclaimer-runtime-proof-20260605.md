# Row 17 — Rente vs Capital disclaimer runtime proof — 2026-06-05

## Status

`PARTIAL`.

This proof closes the runtime screenshot/accessibility slice for the lower
disclaimer/source card on canonical `/rente-vs-capital`. Row 17 remains partial
because chart summaries, dynamic type, and broader top-simulator coverage are
still separate gates.

## Bug Found

The previous widget proof showed a `Semantics(identifier:
rente_vs_capital_disclaimer_card)` node with `LSFin`, `LPP art. 14`, and
`LIFD art. 38`. Runtime inspection found a stricter issue: the disclaimer was
visually present on iPhone, but iOS runtime tooling did not expose it as a
reachable/focusable node until the card was made explicitly focusable.

## Change Covered

- `_buildDisclaimerCard()` now sets `focusable: true` on the semantic wrapper.
- The Row 17 widget smoke test asserts the semantic node has a focus state
  (`flagsCollection.isFocused != Tristate.none`) in addition to the stable
  identifier and legal-source labels.
- Added `flow_row17_rente_vs_capital_disclaimer_runtime.yaml`, which opens
  `/rente-vs-capital`, scrolls to the lower disclaimer section, asserts the
  stable semantic id and the LSFin/LIFD source text, and captures the screen.

## Runtime Evidence

Build:

```bash
cd apps/mobile
CODE_SIGNING_ALLOWED=NO flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
xcrun simctl install booted build/ios/iphonesimulator/Runner.app
```

Flow:

```bash
MAESTRO_HARD_LIMIT=300 MAESTRO_STALL_THRESHOLD=90 \
MINT_WALKER_ARTIFACTS=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-17-rente-vs-capital-disclaimer-runtime-20260605T020611 \
  bash tools/simulator/maestro_with_watchdog.sh test \
  --format junit \
  --output .planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-17-rente-vs-capital-disclaimer-runtime-20260605T020611/result.xml \
  tools/simulator/flows/maestro-perfect-set/flow_row17_rente_vs_capital_disclaimer_runtime.yaml
```

Result:

- JUnit: `tests=1`, `failures=0`, `time=23.0`.
- Watchdog: `EXIT_CODE=0`.
- Device: iPhone 17 Pro iOS 26.2 simulator
  `B03E429D-0422-4357-B754-536637D979F9`.

Artifacts:

- `evidence/maestro-ci/row-17-rente-vs-capital-disclaimer-runtime-20260605T020611/result.xml`
- `evidence/maestro-ci/row-17-rente-vs-capital-disclaimer-runtime-20260605T020611/maestro.log`
- `evidence/maestro-ci/row-17-rente-vs-capital-disclaimer-runtime-20260605T020611/row17-rente-vs-capital-disclaimer-runtime.jpg`

Runtime snapshot after the fix exposed:

```text
rente_vs_capital_disclaimer_card
Avertissement. Outil educatif — ne constitue pas un conseil financier (LSFin).
Sources : LPP art. 14 / LIFD art. 22 / LIFD art. 38
```

## Deterministic Evidence

```bash
cd apps/mobile
flutter test test/screens/arbitrage_screens_smoke_test.dart \
  --plain-name "renders reachable semantic disclaimer and legal sources"
```

Result: passed.

```bash
cd apps/mobile
flutter analyze \
  lib/screens/arbitrage/rente_vs_capital_screen.dart \
  test/screens/arbitrage_screens_smoke_test.dart
```

Result: no issues found.

## Runtime Guidance Quality Review

- `mechanical proof`: Maestro JUnit is green and runtime snapshot exposes the
  stable disclaimer id with LSFin/LPP/LIFD source text.
- `user-visible outcome`: the user can scroll to a visible lower warning/source
  block on the shipped simulator screen.
- `guidance quality`: the screen does not leave the user with a financial
  estimate without educational limitation and legal-source context.
- `non-absurd`: the disclaimer is not hidden behind advanced controls and is
  reachable after the main result/hypotheses sections.
- `inclusive`: no salary-only or employee-only copy was introduced.
- `financial trust`: the proof reinforces that the simulator is educational,
  not personal financial advice, and cites pension/tax legal anchors.
- `remaining qualitative gaps`: Row 17 still needs chart accessibility
  summaries, dynamic-type runtime proof, and broader top-simulator visual audit.

## Scope Limit

This proof covers the `/rente-vs-capital` disclaimer/source card only. It does
not close every simulator in Row 17.
