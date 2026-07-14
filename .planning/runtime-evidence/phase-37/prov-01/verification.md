# G1-PROV-01 verification

Accepted implementation SHA: `9da8bc96f47c7897328faefa0e7caddc80a3adf2`

## Bounded ticket result

- Exact detached-worktree command: `cd apps/mobile && flutter test test/providers/provenance_on_write_test.dart --reporter expanded`.
- Result: **17/17 GREEN**.
- Provider suite on the implementation worktree: **170/170 GREEN**.
- `flutter analyze`: **GREEN**.
- G1 ledger/AVS hard floors and staged Lefthook gates: **GREEN**.
- Permanent `mint-quality-gate`: **GO** with no residual P0/P1/P2 in the bounded migrated writer set.

The accepted contract covers `mergeAnswers`, self LPP, self AVS, salary certificate, inline edits, and Open Banking. Values and exact field-centric `{source, updatedAt, sourceDate}` provenance are persisted before publication and survive cold reconstruction.

## Audit truth

- Product/domain Opus: **PASS**, no P0/P1.
- Code and architecture reruns remain **NO-GO for full G1**, because tax, partner LPP, freshness consumers, runtime proof, and other registered G1 tickets are still open.
- Those findings are not relabelled as green: tax is G1-PROV-03; partner LPP restart/ownership is G1-PROV-02 plus G1-BND-02A; document-date consumption is G1-FRESH-01; runtime is G1-RUNTIME-01.

Therefore `G1-PROV-01` is GREEN, while **G1 remains NO-GO and G2/G3 remain forbidden**.
