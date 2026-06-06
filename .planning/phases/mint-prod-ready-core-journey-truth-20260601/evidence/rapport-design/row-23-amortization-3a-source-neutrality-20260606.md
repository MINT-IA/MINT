# Row 23 — Amortization 3a Source Neutrality — 2026-06-06

## Scope

Follow-up to CJT-049. The `/mortgage/amortization` screen still showed a
salary-only 3a source line:

`Plafond 3a salarié 2026 : CHF 7'258`

That is too narrow for an amortization-indirect screen because the 3a ceiling
depends on LPP affiliation: with LPP the 2026 ceiling is CHF 7'258; without LPP
it is 20 % of net income, capped at CHF 36'288.

## Change

- Updated `amortizationSource` in FR/EN/DE/ES/IT/PT to name both LPP-affiliated
  and no-LPP ceilings.
- Regenerated Flutter localizations.
- Added a widget regression that scrolls to the source, asserts
  `Plafond 3a selon affiliation LPP`, and rejects `Plafond 3a salarié`.
- Replaced the amortization chart legend `Row` with a centered `Wrap` after the
  new test surfaced a horizontal overflow during scroll.
- Added a narrow-width widget regression for the chart legend so the layout fix
  is covered directly, not only through the source-scroll test.

## Proof

- Red proof: the new focused widget test failed before the ARB change because no
  neutral source was found.
- Green proof: the focused widget test passed after the source and legend fix.
- Full mortgage screen smoke suite passed: `54` tests.
- Targeted Flutter analyze passed for `amortization_screen.dart` and
  `mortgage_screens_smoke_test.dart`.
- ARB parity passed: `6` locales, `6874` keys each.
- French accent and LSFin banned-term checks for the changed source were clean.
- CJT context guard, route registry check, Maestro locator audit, and
  `git diff --check` were clean.
- Dedicated code-review subagent verdict: `NO BLOCK`. It confirmed the 2026
  3a ceiling values against MINT constants/OFAS source and noted the narrow
  legend guard as the right strengthening, which was added before commit.
- Claude CLI was attempted for this lot but ended in provider-side
  `API Error: 529 Overloaded`; no Claude approval is claimed.

## Decision

CJT-050 is a local Row 23 content/layout fix. Row 23 remains `PARTIAL`; this does
not prove the full mortgage flow, per-archetype suitability, dynamic type, or
screen-reader traversal.
