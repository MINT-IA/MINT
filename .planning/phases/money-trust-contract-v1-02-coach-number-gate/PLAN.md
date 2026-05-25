description: Plan to gate heuristic Coach CHF amounts behind structured producers.

# Money Trust Contract v1-02 — Coach Number Gate

## Goal

Stop Coach static copy from presenting 3a tax CHF amounts as loose heuristics.

## Scope

1. Replace local `margin * 0.30` tax-saving estimates with
   `RetirementTaxCalculator.estimate3aTaxImpact`.
2. Make the Q4 3a deadline alert state the visible assumption when the rate is
   estimated.
3. Add focused tests for the static alert copy.
4. Suppress Coach tax-saving CHF copy when canton or salary assumptions are
   missing or invalid.

## Non-Goals

No backend prompt rewrite, no Coach UI redesign, no Budget changes, and no new
tax formula.

## Verification

- `flutter analyze --no-fatal-infos lib/services/coach_narrative_service.dart lib/services/coach/fallback_templates.dart test/services/coach_narrative_number_gate_test.dart test/services/fallback_templates_test.dart test/services/coach_narrative_service_test.dart`
- `flutter test test/services/coach_narrative_number_gate_test.dart test/services/fallback_templates_test.dart test/services/coach_narrative_service_test.dart`
- `python3 tools/checks/wiki_lint.py lint`
- `git diff --check`
- MCP `check_accent_patterns`, `check_banned_terms`, and `validate_arb_parity`
- Read-only reviews: internal code/product agents and Claude Opus; P1 findings
  addressed before PR.
