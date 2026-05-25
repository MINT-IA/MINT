description: Closeout GSD de la phase Mon argent money-map v1.

# Phase mon-argent-money-map-v1 — Closeout

## Verdict

Phase executed and locally verified. The product direction is the right one:
stop adding parallel money screens, make `CoachProfile` the canonical local
profile, and make `Mon argent` a segmented user journey over existing read
models.

Do not add another persistent `MoneyMap` layer in the next step. The remaining
work is consolidation, not expansion.

## What Changed

- Budget-first saved answers now hydrate a partial `CoachProfile` on restart.
- `/budget` prefers profile-derived budget inputs when a `CoachProfile` exists.
- `Mon argent` follows the same profile-first budget rule.
- `Mon argent` now has five focused sections:
  - Aujourd'hui: current liquidity and situation map.
  - Mois: monthly budget.
  - Patrimoine: assets, debts, net worth.
  - Prevoyance: AVS, LPP, 3a.
  - Futur: trajectory A -> B.
- Budget formula proof is secondary/collapsible instead of competing with the
  hero and breakdown in the first viewport.
- Maestro now walks the money-map tabs and rechecks direct budget relaunch.

## External Review

Claude CLI was used as a read-only external reviewer. Its blocking findings
were resolved and captured in `CLAUDE_REVIEW.md`.

Resolved findings:

- `MonArgentScreen` now guards missing `CoachProfileProvider`.
- Partial profiles no longer overwrite a fuller saved budget cache.

## Review Findings

### P1 — Generated l10n files still use CRLF

`flutter gen-l10n` preserves CRLF in the tracked generated
`app_localizations*.dart` files. Because the new generated getters are added
with CRLF, raw `git diff --check` reports trailing whitespace on those generated
lines.

Source files are clean with:

```bash
git diff --check -- . ':(exclude)apps/mobile/lib/l10n/app_localizations*.dart'
```

Recommended follow-up: normalize generated l10n Dart files in a dedicated
mechanical cleanup commit, or exclude generated l10n Dart from whitespace
checks. Do not mix that normalization into this product phase because it turns a
small diff into a repository-wide line-ending diff.

### P3 — This should be split before PR

The current working diff is larger than the MINT rule of thumb for one PR. It
is coherent as a local phase, but should land as separate commits or PRs.

Recommended split:

1. `fix(budget): prefer canonical profile over stale budget cache`
2. `feat(mon-argent): add segmented money-map IA`
3. `test(maestro): verify money map and budget relaunch`
4. `i18n(mon-argent): localize money-map section labels`

## Verification

```bash
cd apps/mobile && flutter test \
  test/screens/mon_argent_screen_test.dart \
  test/screens/budget_setup_screen_test.dart \
  test/screens/budget_screen_smoke_test.dart
```

PASS — 14 tests.

After Claude review fixes:

```bash
cd apps/mobile && flutter test \
  test/screens/mon_argent_screen_test.dart \
  test/screens/budget_setup_screen_test.dart \
  test/screens/budget_screen_smoke_test.dart
```

PASS — 17 tests.

```bash
cd apps/mobile && flutter gen-l10n
```

PASS.

```bash
mint_tools.validate_arb_parity
```

PASS — 6 locales, 6817 keys each.

```bash
cd apps/mobile && flutter build ios --simulator --debug --no-codesign \
  --dart-define=MINT_E2E_ARCHETYPE=julien_swiss \
  --dart-define=MINT_DISABLE_BETA_MODAL=true
```

PASS.

```bash
bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml \
  --output .planning/walker/maestro-flows/mon-argent-money-map-v1/result.xml \
  --format junit
```

PASS — latest run 41s, status SUCCESS.

After Claude review fixes and safety commit `238bba1fb`:

```bash
bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml \
  --output .planning/walker/maestro-flows/mon-argent-money-map-v1/result-post-238bba1fb.xml \
  --format junit
```

PASS — 42s, status SUCCESS. Watchdog artifact:
`.planning/_walker/20260525T201234/maestro.log`.

On stacked PR-B branch `feat/mon-argent-money-map-ia-v1`:

```bash
bash tools/simulator/maestro_with_watchdog.sh test \
  tools/simulator/flows/maestro-perfect-set/flow_mon_argent_budget_setup_spine.yaml \
  --output .planning/walker/maestro-flows/mon-argent-money-map-v1/result-pr-b.xml \
  --format junit
```

PASS — 42s, status SUCCESS. Watchdog artifact:
`.planning/_walker/20260525T205200/maestro.log`.

```bash
python3 tools/checks/wiki_lint.py lint
```

PASS — no FAIL-level violations.

## Product Decision

`Mon argent` should be the user's financial map, not a pile of repeated cards.
The right hierarchy for Mint is:

1. What is true today?
2. What happens every month?
3. What do I own and owe?
4. What is locked or semi-locked in Swiss pension pillars?
5. Am I on track from A to B?

The coach and future arbitrage tabs should consume this same spine. They should
not invent figures, duplicate assumptions, or quote tax savings without an
explicit calculation context.

## Next Phase

Recommended next GSD phase:

`money-trust-contract-v1`

Goal: define a visible trust contract for every financial figure:

- source: user-entered, extracted, estimated, simulated, regulatory constant;
- freshness: when it was last updated;
- confidence: known, estimated, missing, stale;
- consumer list: which screens/chat/cards use it;
- no invented numbers in coach copy without an attached source/calculation.

This directly addresses the user's core concern: Mint must be creative and
pedagogical, but never numerically casual.
