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
- Exact runtime source SHA `ac74672db`: full `flutter analyze` **GREEN**, zero
  issue; full `flutter test --reporter compact` **8,899 passed**, 33 skipped,
  zero failed.

## Activation truth

The typed implementation and its ticket are GREEN. A later exact-SHA runtime
at `ac74672db209c20f35b4903e26d83d8f0ca2c93f` also passed the normal iOS
build/install, Maestro flag-off checks, Patrol writer, explicit process death,
separate cold reader, restoration, independent `xcresulttool` summaries,
Doctor, Patrol guard and 19/19 orchestrator contracts. The sanitized tracked
proof is `runtime-proof-ac74672db2/README.md`.

Claude Opus code and product-domain audits both returned PASS with zero P0/P1.
The first architecture pass returned G1-level NO-GO because the scorecard,
STATE and audit index were stale; it did not find a PROV-03 implementation P0
or P1. See `audit-manifest.json`.

`FeatureFlags.documentTaxAssessmentEnabled` and
`FeatureFlags.typedTaxProfile` still remain false in production. The runtime
used test-process static flags only, so the ledger matrix correctly keeps the
typed tax rows `quarantined`, not live. A named activation decision remains
required.

**G1 remains NO-GO; G2/G3 remain forbidden.**
