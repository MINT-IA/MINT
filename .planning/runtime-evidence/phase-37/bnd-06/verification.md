# G1-BND-06 verification

Accepted implementation and runtime SHA:
`28d0097f65b2f0a88d3ae6610614d912d0ba943a`

- Ticket decision: **GREEN**
- G1 score and decision: **8.2/10 — NO-GO**
- G2/G3 decision: **forbidden**
- Production activation: **default-off / not authorized**

## Exact TDD ticket proof

- Registry command:
  `cd apps/mobile && flutter test test/providers/financial_plan_staleness_test.dart --reporter expanded`.
- Semantic RED SHA `9e86539d21533f0daec70f1b3707def544dafa44`:
  exact physical-archive replay exited `1`; **6 passed / 27 semantic
  failures** after reaching the real fingerprint, provenance, hydration,
  provider and stale-consumer surfaces.
- GREEN SHA `28d0097f65b2f0a88d3ae6610614d912d0ba943a`:
  exit `0`; **17 passed, 0 failed, 0 skipped** with the identical command.
- Machine evidence: `red.json`, `green.json`, `runtime-summary.json` and
  `audit-manifest.json`.

The GREEN proves that a loaded canonical ledger owns financial-plan freshness,
that every stale or authority-unknown state suppresses derived figures, and
that recalculation keeps goal intent while never reverse-writing ledger facts.
The no-LPP branch fingerprints only its consumed affiliation and date-of-birth
facts; irrelevant income changes do not create false staleness.

## Exact-SHA runtime chain

The versioned lightweight record is `runtime-summary.json`; heavy local runtime
artifacts remain excluded.

1. The synthetic Patrol writer, explicit app launch, process termination and
   separate cold reader passed.
2. The app was exported from the exact pushed Git SHA to a physical disposable
   tree, built from the production entrypoint, signature-verified, checked for
   forbidden extended attributes and installed successfully.
3. Maestro passed **1/1** after waiting for the unique landing readiness
   identifier, opening the home deep link, observing the real home readiness
   identifier, then proving stale recovery and the regenerated visible amount.
4. All **13/13** stage exit codes are zero; all **14/14** expected sanitized
   logs exist; cleanup passed and the original build was restored.
5. No raw device identifier, absolute repository/home/temp path, raw log,
   xcresult, screenshot, private certificate or real financial fixture is
   retained in the versioned evidence.

The runtime enables `MINT_TEST_FINANCIAL_PLAN_SETUP` only for the exact-archive
debug proof. Its recorded default remains `false`; the flag is not server-
drivable and production activation is not claimed.

## External audit disposition

- Wrapper-only Sonnet rerun `product-domain`: **PASS**, P0=0 and P1=0.
- Wrapper-only final Opus confirmation `code`: **PASS**, P0=0 and P1=0.
- No further audit carousel is authorized.
- All six P2 observations are explicit in `audit-manifest.json`: persisted
  amount parsing, test-opt-in runtime scope, default-off release value, Swiss
  comma input, explicit 2026 LPP fallback sourcing and AVS-exclusion specialist
  wording. They are nonblocking for this default-off technical ticket and
  remain required follow-ups before the affected user-facing activation.

## Decision boundary

This promotion closes only `G1-BND-06`. It does not activate the financial-plan
path, close `G1-RUNTIME-01`, complete G1, or authorize G2/G3. G1 remains
**8.2/10 — NO-GO** with **12 open hard floors**.
