# Row 17 — Rente vs Capital Runtime Visual Proof — 2026-06-04

## Claim

Canonical `/rente-vs-capital` now has a green runtime visual proof for the
first decision surface:

- the route opens the shipped canonical screen, not the legacy
  `/simulator/rente-capital` alias;
- the first estimate surface no longer exposes salary-only copy;
- secondary controls stay folded behind `Paramètres avancés`;
- the advanced controls remain reachable when the user explicitly opens them.

This does **not** close Row 17. A later local slice now covers the engine
source/disclaimer contract and core Row 17 i18n labels (see 2026-06-05 addendum
below), but runtime disclaimer-card reachability, accessibility review, and the
full top-simulator visual audit remain open.

## Runtime Evidence

Flow:

`tools/simulator/flows/maestro-perfect-set/flow_row17_rente_vs_capital_runtime_visual.yaml`

Command:

```bash
FLOW=tools/simulator/flows/maestro-perfect-set/flow_row17_rente_vs_capital_runtime_visual.yaml
EVIDENCE=.planning/phases/mint-prod-ready-core-journey-truth-20260601/evidence/maestro-ci/row-17-rente-vs-capital-runtime-20260604T225941
MAESTRO_HARD_LIMIT=300 MAESTRO_STALL_THRESHOLD=90 MINT_WALKER_ARTIFACTS="$EVIDENCE" \
  bash tools/simulator/maestro_with_watchdog.sh test \
    --format junit \
    --output "$EVIDENCE/result.xml" \
    "$FLOW"
```

Result:

- Device: iPhone 17 Pro, iOS 26.2
- Watchdog exit: `0`
- JUnit: `tests=1`, `failures=0`
- Runtime: `19.0s`

Durable artifacts:

- `evidence/maestro-ci/row-17-rente-vs-capital-runtime-20260604T225941/result.xml`
- `evidence/maestro-ci/row-17-rente-vs-capital-runtime-20260604T225941/screenshots/01-row17-rente-vs-capital-hero.png`
- `evidence/maestro-ci/row-17-rente-vs-capital-runtime-20260604T225941/screenshots/02-row17-income-inclusive-primary-input.png`
- `evidence/maestro-ci/row-17-rente-vs-capital-runtime-20260604T225941/screenshots/03-row17-advanced-folded.png`
- `evidence/maestro-ci/row-17-rente-vs-capital-runtime-20260604T225941/screenshots/04-row17-advanced-expanded.png`

## Deterministic Text Contract

The runtime screenshots show the visual state, while the exact positive labels
are locked by widget test because Flutter's rendered input labels on this
screen are not consistently exposed as Maestro-visible iOS accessibility text.

Supporting command:

```bash
cd apps/mobile
flutter test test/screens/arbitrage_screens_smoke_test.dart \
  --plain-name "keeps first decision inputs neutral and advanced fields folded"
```

That test asserts:

- `Ton revenu brut annuel (CHF)` is present;
- `Ton salaire brut annuel (CHF)` is absent;
- `Rachat LPP annuel`, `Retrait EPL`, `Canton`, and `Marié·e` are absent before
  opening `Paramètres avancés`;
- the same advanced controls are visible after opening the section.

## 2026-06-05 Addendum — i18n + Source Contract

Follow-up evidence:

`evidence/simulator-design/row-17-rente-vs-capital-i18n-source-contract-20260605.md`

Additional deterministic proof now covers:

- `ArbitrageEngine.compareRenteVsCapital()` returns an LSFin educational
  disclaimer and legal sources including `LPP art. 14` and `LIFD art. 38`;
- `renteVsCapitalWarning` is localized in FR/EN/DE/ES/IT/PT;
- core non-French Row 17 labels no longer leak French fragments for age,
  monthly unit, chart axis, age delta, inflation, transmission/inheritance, and
  single-person survivor wording.

Proof commands:

```bash
cd apps/mobile
flutter gen-l10n
flutter test test/screens/arbitrage_screens_smoke_test.dart
flutter analyze test/screens/arbitrage_screens_smoke_test.dart \
  lib/l10n/app_localizations_en.dart \
  lib/l10n/app_localizations_de.dart \
  lib/l10n/app_localizations_es.dart \
  lib/l10n/app_localizations_it.dart \
  lib/l10n/app_localizations_pt.dart
```

MCP ARB parity passed with `6871` keys in each of the 6 locales.

## Runtime Guidance Quality Review

- `mechanical proof`: JUnit green, watchdog `0`, four screenshots cover hero, primary inputs, folded and expanded advanced controls.
- `user-visible outcome`: user reaches canonical `Rente ou capital : ta décision` and sees the main estimate inputs before optional advanced assumptions.
- `guidance quality`: the screen matches the retirement-choice job and keeps secondary assumptions out of the first decision surface.
- `non-absurd`: no legacy alias, no route mismatch, no overloaded first viewport.
- `inclusive`: uses income-inclusive `revenu brut annuel` wording instead of salary-only copy.
- `financial trust`: calculation remains simulator-style with assumptions; engine result source/disclaimer contract is now locally covered, but runtime disclaimer-card reachability still needs proof.
- `remaining qualitative gaps`: runtime disclaimer-card proof, accessibility, chart semantics, dynamic type, and broader top-simulator audit remain open.

## Scope Limit

Row 17 remains `PARTIAL`. This proof covers the canonical route's runtime visual
contract for first inputs and advanced-control folding only. Remaining closure
work:

- runtime scroll proof that the disclaimer card is reachable and legible on `/rente-vs-capital`;
- accessibility and broader i18n review across the top simulator set;
- visual audit for the rest of the shipped simulator surfaces;
- explicit release decision for any documented simulator exception.

## Learning

For this screen, use screenshot-backed Maestro proof plus Flutter widget tests
for exact text assertions. Tightening the Maestro flow to assert every visible
field label currently creates false red runs because some Flutter labels are
visually rendered but not reliably available to Maestro's text matcher.
