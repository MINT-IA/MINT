# Row 17 — Rente vs Capital Semantic Disclaimer Contract — 2026-06-05

## Claim

Canonical `/rente-vs-capital` now has deterministic widget proof that the
lower trust card is reachable after the first calculation and exposes a stable
semantic target containing:

- the LSFin educational disclaimer;
- legal sources including `LPP art. 14` and `LIFD art. 38`;
- a stable `rente_vs_capital_disclaimer_card` semantic identifier.

The same test also caught a real narrow-viewport overflow in the hypothesis
impact labels before the disclaimer could be reached. The layout now keeps both
impact labels inside the row with flexible text and no RenderFlex overflow.

This does **not** close Row 17. It closes the local widget accessibility/source
slice only. A simulator runtime scroll screenshot, chart summaries, dynamic
type, and broader top-simulator review remain open.

## Deterministic Evidence

Commands:

```bash
cd apps/mobile
flutter test test/screens/arbitrage_screens_smoke_test.dart \
  --plain-name "renders reachable semantic disclaimer and legal sources"
flutter test test/screens/arbitrage_screens_smoke_test.dart
flutter analyze lib/screens/arbitrage/rente_vs_capital_screen.dart \
  test/screens/arbitrage_screens_smoke_test.dart
```

Results:

- Targeted widget test: passed.
- Full arbitrage smoke suite: `27` tests passed.
- Targeted `flutter analyze`: no issues.

## Covered Contracts

- `_buildDisclaimerCard()` has a stable `Semantics` wrapper with key and
  identifier `rente_vs_capital_disclaimer_card`.
- The semantic label includes the localized warning, engine disclaimer, and
  source text.
- The widget test waits for the async API/fallback calculation, scrolls to the
  lower card, and asserts `LSFin`, `LPP art. 14`, and `LIFD art. 38`.
- The hypothesis impact row no longer overflows on the 800x1600 widget-test
  viewport.

## Runtime Guidance Quality Review

- Product logic improved: the screen no longer has a purely hidden source
  contract. The trust/disclaimer layer is discoverable by a semantic target
  after calculation, and the warning remains educational rather than advisory.
- Remaining guidance risk: the proof is widget-level, not a Maestro screenshot.
  A real iPhone flow still needs to scroll from first viewport to the
  disclaimer card and capture the visible LSFin/source copy.
- Row 17 must stay `PARTIAL` until runtime reachability, chart semantics,
  dynamic type, and the broader simulator audit are covered.

## Remaining Gaps

- Maestro/runtime screenshot of the lower disclaimer card.
- VoiceOver/focus-order proof for the simulator inputs, chart, assumptions, and
  disclaimer.
- Accessible chart summaries beyond the current generic chart semantics.
- Dynamic type proof for `/rente-vs-capital`.
- Broader top-simulator source/disclaimer/i18n/accessibility audit.
