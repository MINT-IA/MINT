# G1-PROV-03 verification

Accepted implementation SHA:
`5a772865b9c9fdcb7efa99496799838640a8f3fb`

## Exact ticket proof

- Registry command:
  `cd apps/mobile && flutter test test/services/document_parser/tax_declaration_parser_test.dart test/providers/tax_provenance_profile_test.dart test/screens/document_scan/tax_extraction_review_screen_test.dart --reporter expanded`.
- Detached RED SHA `6bcba7ab0cf8384e45d2a928cc679a17a7e7b267`:
  exit `1`; 40 tests passed before six semantic load failures proved that the
  typed tax candidate, review, flag, persistence and selector production APIs
  did not exist.
- Frozen GREEN SHA: exit `0`; **143/143 tests passed**.
- Machine evidence: `red.json`, `green.json`; sanitized command output:
  `red-output.txt`, `green-output.txt`.
- Registry/evidence hard floor:
  `python3 -m pytest tools/checks/tests/test_g1_p0_ledger_dead_keys.py -q`
  → **19/19 passed**.

All fixtures are synthetic. The sanitized logs contain no real user financial
data and replace local checkout/worktree paths with placeholders.

## Frozen-SHA non-regression

- Full `flutter analyze`: **GREEN**, zero issue.
- Full `flutter test --reporter compact`: **8,896 passed**, 33 skipped,
  zero failed, exit `0` in 304 seconds.
- Permanent `mint-quality-gate`: **GO**, P0/P1/P2 = 0 for the bounded
  malformed-root and ticket-evidence gates.
- Permanent `mint-data-ledger-architect`: **GO**, P0/P1/P2 = 0 for the bounded
  malformed-root ledger/provenance/privacy gate.

## Activation truth

The typed implementation and its ticket are GREEN, but
`FeatureFlags.documentTaxAssessmentEnabled` and
`FeatureFlags.typedTaxProfile` remain false. The ledger matrix therefore marks
the typed tax rows `quarantined`, not live. Frozen-SHA Maestro/Patrol evidence,
external Claude audits and the named activation decision remain required.

**G1 remains NO-GO; G2/G3 remain forbidden.**
