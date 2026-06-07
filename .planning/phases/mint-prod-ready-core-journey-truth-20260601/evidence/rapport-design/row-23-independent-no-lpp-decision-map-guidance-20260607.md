---
description: Row 23 proof that the independent/no-LPP Coach 3a fallback now uses a structured decision map instead of a flat legal paragraph.
---

# Row 23 - Independent/No-LPP Coach Decision-Map Guidance

Date: 2026-06-07

## Scope

Persona: `independent_no_lpp_income_reality`.

Route: `/coach/chat`.

Prompt: `Combien verser en 3a ?`

This follow-up hardens the audited local Coach answer for an independent person
without LPP. The answer keeps the VZ-style 3a margin calculation, but now
structures the guidance as:

- `Faits MINT`
- `Confirmations manquantes`
- `Carte de décision`
- `Comparer avant de verser`
- `Prochaine action prudente`

## Quality Contract

The response must:

- show `Marge 3a à vérifier`;
- show `min(20 % du revenu déterminant, 36'288 CHF/an) - versements 3a déjà planifiés`;
- use the seeded MINT facts `86'400 CHF/an`, `6'000 CHF/an`, and `11'280 CHF/an`;
- label the professional base as MINT-declared and to confirm as fiscal/AVS determining income;
- compare legal 3a margin, monthly capacity, risk cover, optional LPP, liquidity, and fiscal checks;
- say that legal margin is not monthly capacity;
- state that the user must not treat the ceiling as the amount to pay.

The response must not:

- show the generic `Versement 3a 2026` card;
- show `Impact fiscal indicatif`;
- show stale card amounts `2'218 CHF`, `7'137 CHF`, or `3'068 CHF`;
- use product/provider framing such as `ouvre` or `fintech`;
- use overclaiming terms such as `meilleur`, `optimal`, or `sans risque`;
- invent a remaining margin when professional income is missing.

## Proof

TDD red proof first failed on the missing decision-map sections.

Green proof:

- `flutter test test/services/coach/local_fallback_service_test.dart test/services/coach_hard_gate_killswitch_test.dart test/screens/coach/coach_chat_test.dart`
- Result: `93` passed, `5` existing skips.

Static proof:

- `flutter analyze` passed with no issues.
- `python3 tools/checks/maestro_locator_audit.py` passed: `515` locators.
- MCP banned-terms check: clean.
- MCP French accent-pattern check: clean.

Runtime proof:

- Flow: `tools/simulator/flows/maestro-perfect-set/flow_row23_independent_no_lpp_coach_chat_runtime.yaml`
- Evidence: `evidence/maestro-ci/row-23-independent-no-lpp-decision-map-quality-20260607T124439/`
- Result: `tests=1`, `failures=0`
- Device: `iPhone 16e - iOS 26.2`
- Watchdog: `maestro returned 0`
- Screenshot: `runtime-final-decision-map-guidance.jpg`

## Score

Scenario score moves from `8.2/10` to `8.6/10`.

Why it rises:

- The guidance is no longer a long flat paragraph; it is a decision map.
- Maestro now verifies the answer by meaning-bearing sections, not by a single
  topic phrase.
- The flow checks both positive guidance and negative regressions from the
  previously misleading tax-impact card.

Why it is not yet `10/10`:

- The decision map is still text rendered inside chat, not a dedicated
  structured UI component with field-level provenance.
- Source freshness is not visible beside each money fact.
- Runtime VoiceOver/focus traversal for the long answer remains open.
- Restart/profile-update proof for this exact Coach path remains open.
- Broader no-LPP and other persona-flow scoring remains partial.

Row 23 remains `PARTIAL`.
