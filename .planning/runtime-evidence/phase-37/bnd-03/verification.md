# G1-BND-03 verification

Accepted implementation and runtime SHA:
`7ed54e282183767b993fefd1a97daeff00c02849`

- Ticket decision: **GREEN**
- G1 decision: **NO-GO**
- G2/G3 decision: **forbidden**

## Exact TDD ticket proof

- Registry command:
  `cd apps/mobile && flutter test test/providers/provider_bridge_recompute_test.dart --reporter expanded`.
- Semantic RED SHA `683e2a1f20b9df59b1ee5f0b5ea852c8b63cf51b`:
  exit `1`; one predicate passed and four business predicates failed after the
  test reached the real provider/cache/cadence/recompute surfaces.
- GREEN SHA `7ed54e282183767b993fefd1a97daeff00c02849`:
  exit `0`; **12 passed, 0 failed, 0 skipped**.
- Machine evidence: `red.json`, `green.json`, `runtime-summary.json` and
  `audit-manifest.json`.

The GREEN proves that cold budget state is rehydrated from the canonical
ledger, income and housing cadences remain distinct, one canonical mutation
recomputes the provider/state exactly once, debt is counted once, and
`budgetGap` remains unknown without official AVS evidence.

## Exact-SHA runtime chain

The complete sanitized local runtime bundle is
`runtime-7ed54e282183-20260716T043608Z/`; the versioned lightweight record is
`runtime-summary.json`.

1. The Patrol writer, explicit process termination and separate cold reader
   passed using synthetic values.
2. The production app was exported from the exact Git SHA to a physical,
   disposable source tree, then built, signature-verified, inspected for
   forbidden extended attributes and installed successfully.
3. Maestro passed against that production bundle.
4. All 13 stage exit codes are zero; the 14 expected sanitized logs exist;
   build isolation cleanup passed and the original build was restored.
5. The source manifest verifies from the repository root. No raw device
   identifier, raw log, xcresult bundle, screenshot, private certificate or
   real financial fixture is retained.

The heavy sanitized build/test logs remain local and excluded. The versioned
summary retains their counts, decisions and SHA-256 bindings without device or
absolute-path identifiers.

## External audit disposition

- Wrapper-only Opus `code` audit: **PASS**, P0=0 and P1=0. Its real-toolchain
  P2 is resolved by the exact-SHA physical archive runtime above.
- Wrapper-only Opus `product-domain` audit: **PASS**, P0=0 and P1=0. The
  return-to-budget route is already asserted by
  `apps/mobile/test/screens/budget_setup_screen_test.dart`; the long runtime
  mode name is cosmetic and non-blocking.
- No additional audit rerun is authorized.
- The accepted runs and complete P2 dispositions are machine-readable in
  `audit-manifest.json`; their sanitized outputs are versioned as
  `audit-code-opus.md` and `audit-product-domain-opus.md`.

## Decision boundary

This promotion closes only `G1-BND-03`. It does not close the separate
`G1-RUNTIME-01` salary/canton-to-mortgage floor, authorize G2/G3, or complete
G1. The next canonical Wave 3 ticket is `G1-BND-05`.
