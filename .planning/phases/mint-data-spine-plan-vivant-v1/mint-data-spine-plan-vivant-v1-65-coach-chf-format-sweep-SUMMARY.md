# Plan 65 — Coach CHF Format Sweep Summary

## Done
- Replaced the remaining raw CHF interpolation in `ContextInjectorService` EVI uncertainty with `formatChfWithPrefix`.
- Replaced the raw retirement delta in `RetirementHeroZone` with the shared CHF formatter.
- Replaced the raw yearly impact in `MicroActionCard` with the shared CHF formatter.
- Added focused tests for coach context, retirement hero delta, and micro-action impact.

## Verification
- Red-first focused tests failed on raw values:
  - `±CHF 200998`
  - `+CHF 12345/mois`
  - `~CHF 12345/an`
- Green focused tests:
  - `flutter test test/services/context_injector_service_test.dart test/widgets/coach/chf_formatting_test.dart`
- Analyze:
  - `flutter analyze lib/services/coach/context_injector_service.dart lib/widgets/coach/retirement_hero_zone.dart lib/widgets/coach/micro_action_card.dart test/services/context_injector_service_test.dart test/widgets/coach/chf_formatting_test.dart`
- Coach raw-CHF grep has no remaining code hit; only the comment `Impact CHF` remains.
- MCP banned-term and accent checks are clean for this summary.

## Decision
Keep this phase formatting-only. No financial formulas or business assumptions changed.
