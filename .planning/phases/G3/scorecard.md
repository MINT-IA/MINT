# G3 Scorecard — stale data reconfirm

Status: blocked before code until infra gates are available on the product branch.

## Dependencies

- #851 `no_bypass_persistence`: required for DATA_QUEST DQ-4 / DATA_LEDGER I-3 proof.
- #852 `hardcoded_rate_gate`: required before any financial scenario code touches rates.

## Current PR

This PR only creates the mandatory Swiss Brain spec before code:

- `.planning/phases/G3/swiss-brain-spec.md`

## Code Gate

Do not add product code to G3 until the implementation PR can run:

- `python3 tools/checks/no_bypass_persistence.py --base-ref <base>`
- `python3 tools/checks/hardcoded_rate_gate.py --base-ref <base>`
- `cd apps/mobile && flutter test test/services/biography/ test/screens/data_block_enrichment_screen_test.dart`
- `cd apps/mobile && flutter analyze`

## First Implementation Slice

Target one vertical only:

- route: `/data-block/revenu`
- fields: `q_gross_salary_annual`, `q_canton`, `q_birth_year`
- behavior: stale known value → one reconfirm card; fresh known value → no Ask; missing value → existing collect flow.
