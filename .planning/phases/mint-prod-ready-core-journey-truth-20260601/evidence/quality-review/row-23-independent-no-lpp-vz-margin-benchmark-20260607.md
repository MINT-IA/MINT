---
description: Row 23 benchmark for the independent/no-LPP Coach 3a capacity scenario, comparing MINT output against Swiss expert-guidance expectations.
---

# Row 23 - Independent/No-LPP Coach 3a Capacity Benchmark

Date: 2026-06-07

## Scenario

- Persona: `independent_no_lpp_income_reality`
- Route: `/coach/chat`
- Runtime prompt target: `Combien verser en 3a ?`
- User need: know the 3a legal margin and the checks required before paying
  more, without being pushed into a tax-impact teaser or product action.

## Swiss Benchmark

Primary source:

- VZ, `Pilier 3a: montant maximal 2026`:
  https://www.vermoegenszentrum.ch/fr/competences/pilier-3a-montant-maximum

Benchmark requirements extracted from VZ and local MINT constants:

1. Distinguish LPP-affiliated people from people without a pension fund.
2. For no-LPP active people, use the rule `20 % du revenu déterminant`,
   capped at `36'288 CHF` for 2026.
3. For independent work, treat the relevant income base as the professional
   result after social-insurance contributions and tax corrections, not as a
   generic household salary or monthly cashflow.
4. Explain that legal room is not payment capacity: liquidity, variable
   income, risk cover, and monthly budget need their own checks.
5. Compare the role of 3a and possible pension-fund affiliation without
   making a product prescription.
6. Keep the LSFin boundary: educational guidance, no suitability claim, no
   promise, no provider recommendation.

MINT constants check:

- `pillar3a.max_without_lpp = 36'288 CHF`
- `pillar3a.income_rate_without_lpp = 0.2`
- `pillar3a.historical_limits.2026 = 7'258 CHF`

## Current MINT Output Contract

The deterministic local response now has to show:

- `Marge 3a à vérifier`
- formula: `min(20 % du revenu déterminant, 36'288 CHF/an) - versements 3a déjà planifiés`
- MINT facts used:
  - base professionnelle déclarée: `86'400 CHF/an`
  - versements 3a planifiés: `6'000 CHF/an`
  - remaining legal margin before fiscal/AVS validation: `11'280 CHF/an`
- missing confirmations:
  - revenu déterminant fiscal/AVS
  - statut AVS d'indépendant·e
  - couverture accident/perte de gain
  - liquidity/reserve if income varies
  - possible LPP facultative role
- explicit boundary: legal margin is not monthly capacity.

The response must not show:

- `Versement 3a 2026`
- `Impact fiscal indicatif`
- `2'218 CHF`
- stale previous amounts such as `7'137 CHF` or `3'068 CHF`
- product-opening or provider-framing copy.

## Score

Before card suppression: `5.0 / 10`.

After card suppression: `6.7 / 10`.

After context-aware margin guidance, Claude review fixes, and iPhone 16e
runtime proof: `8.2 / 10`.

Why it rises:

- The answer now uses persona facts, not only a generic legal paragraph.
- The legal margin is computed and shown with the calculation chain.
- The text separates legal room, fiscal/AVS base, and monthly affordability.
- Maestro has stricter assertions against the actual reasoning, not only
  against a visible topic.
- The scenario no longer relies on the user repeating "indépendant sans LPP";
  `CoachContext.archetype` carries that fact.
- Runtime proof validates the long answer by sections: legal/LSFin tail,
  formula, MINT facts, professional checks, and legal-margin-vs-cashflow
  warning.
- The computed base is explicitly labelled as a MINT-declared professional
  base to confirm as fiscal/AVS determining income; the missing-income
  hard-gate path now refuses to compute a remaining margin.

Why it is not yet `10 / 10`:

- The answer is still text-only; it does not expose a structured decision map
  for 3a vs LPP facultative vs liquidity vs risk cover.
- Source freshness and field-level provenance are not visible beside each
  money fact.
- VoiceOver/focus order for this long answer is not yet proven at runtime.

## Verification Links

- Local tests:
  `flutter test test/services/coach/local_fallback_service_test.dart test/services/coach_hard_gate_killswitch_test.dart test/screens/coach/coach_chat_test.dart`
- Runtime flow to rerun:
  `tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_coach_chat_runtime.yaml`
- Runtime evidence:
  `evidence/maestro-ci/row-23-independent-no-lpp-vz-margin-quality-20260607T111701-after-claude/result.xml`
- Runtime screenshot:
  `evidence/maestro-ci/row-23-independent-no-lpp-vz-margin-quality-20260607T111701-after-claude/runtime-final-capacity-guidance.jpg`
