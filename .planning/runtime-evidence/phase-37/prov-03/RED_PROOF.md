# G1-PROV-03 RED proof

Date: 2026-07-14
RED commit: `6bcba7ab0`
Overall G1 verdict: **NO-GO**
Quality verdict for committing RED: **GO**, no residual P0.

## Commands

Run from `apps/mobile` with synthetic fixtures only:

```text
flutter test test/services/document_parser/tax_declaration_parser_test.dart --reporter expanded
=> exit 1; 40 passed / 4 exact semantic failures

flutter test test/services/document_parser/tax_assessment_parser_contract_test.dart --reporter expanded
=> exit 1; typed parser/candidate contract absent

flutter test test/providers/tax_provenance_profile_test.dart --reporter expanded
=> exit 1; typed model, persistence, flag, provider and selector APIs absent

flutter test test/screens/document_scan/tax_extraction_review_screen_test.dart --reporter expanded
=> exit 1; typed candidate/confirmation/widget seam absent
```

Machine status: `red-status.txt`.
Full outputs: `parser-red-output.txt`, `typed-parser-red-output.txt`,
`provider-red-output.txt`, `screen-red-output.txt`.

## Failure predicates proven

- Average/effective and `(ICC+IFD)/income` still become marginal in the legacy
  parser; cantonal-only and combined ICC are conflated.
- No typed parser candidate classifies document authority, period, tax unit,
  jurisdiction, ICC/IFD facts or average/marginal meaning.
- No secure schema-v1 FiscalProfile snapshot writer, nested legacy quarantine,
  source mapping, exact provenance, save-before-publish, cold reload, selector
  conflict policy or ConfidenceScorer consumer exists.
- No real widget metadata-confirmation path, default-off kill switch, local-only
  tax side-effect boundary or provider `acceptTaxReview` seam exists.

## Baseline context

`flutter analyze` was GREEN before test edits. A broad `flutter test` baseline
was interrupted after approximately 1646 passes and the already-registered
`RET-STATE-01` retirement-dashboard CTA failure; that unrelated failure was not
changed in PROV-03.

## Gate note

These tests intentionally leave the branch RED until the implementation lands.
G1-PROV-03 cannot become GREEN from compilation alone: the behavioral tests
cover pending persistence, cold restart, flag-off/malformed storage, 2024
assessment plus 2025 provisional coexistence, production consumer behavior and
real widget side effects.
