# G1-BND-05 verification

Accepted implementation and runtime SHA:
`cbb040a4aeaa9155cf4ec70b9b5c279916dc3b97`

- Ticket decision: **GREEN**
- G1 score and decision: **8.2/10 — NO-GO**
- G2/G3 decision: **forbidden**

## Exact TDD ticket proof

- Registry command:
  `cd apps/mobile && flutter test test/providers/document_reference_bridge_test.dart --reporter expanded`.
- Semantic RED SHA `cec4f0245c08adb8f2881e61ae53d50819f37e31`:
  exact physical-archive replay exited `1`; **0 passed / 6 semantic failures**.
  The failures reached strict review persistence, restart/snapshot-swap,
  production bridge APIs, the exact raw-free allowlist, legacy-orphan removal
  and opaque detail routing. They were not missing-import or harness failures.
- GREEN SHA `cbb040a4aeaa9155cf4ec70b9b5c279916dc3b97`:
  exit `0`; **12 passed, 0 failed, 0 skipped** with the identical command.
- Machine evidence: `red.json`, `green.json`, `runtime-summary.json` and
  `audit-manifest.json`.

The GREEN proves that the strict owner-scoped LPP root remains the sole
financial authority while the reference store contains exactly
`{referenceId, kind, snapshotId, ownerKind, confirmedAt}`. Timeline and detail
resolve only an opaque ID back through the current strict snapshot. Malformed
roots, owner/snapshot drift and expired partner authority fail closed; deleting
or retrying metadata never rewrites, revokes or duplicates accepted ledger
facts.

## Exact-SHA runtime chain

The complete sanitized local runtime bundle is
`runtime-cbb040a4aeaa-20260716T084916Z/`; the versioned lightweight record is
`runtime-summary.json`.

One earlier diagnostic attempt at `91dfe480bac0b5960bdc54d0efd98946e1e268a3`
rendered the correct production UI, but its Maestro selector was Flutter
Key-only rather than a discoverable semantics identifier. That attempt was not
acceptance evidence: its retained bundle also failed the privacy scan and was
destroyed. The accepted/effective runtime attempt count remains one.

1. The Patrol writer, explicit process termination and separate cold reader
   passed using synthetic facts only.
2. The production app was exported from the exact Git SHA to a physical,
   disposable tree, built, signature-verified, inspected for forbidden extended
   attributes and installed successfully.
3. Production-default Maestro passed **1/1**, proving acquisition stays off and
   an opaque missing reference fails closed with a recoverable document-list
   route and no financial value.
4. All **13/13** stage exit codes are zero and all **14/14** expected sanitized
   logs exist; cleanup passed and the original build was restored.
5. No raw device identifier, absolute repository/home/temp path, raw log,
   xcresult bundle, screenshot, private certificate or real financial fixture
   is retained in the versioned evidence.

The heavy sanitized build/test logs remain local and excluded. The versioned
summary binds their sanitized metadata, Maestro report, source manifest and
both audit outputs by real SHA-256 digests.

## External audit disposition

- Wrapper-only first-pass Opus `code`: **PASS**, P0=0 and P1=0.
- Wrapper-only first-pass Opus `product-domain`: **PASS**, P0=0 and P1=0.
- No rerun is authorized.
- Seven P2 observations remain explicit and nonblocking in
  `audit-manifest.json`: durable expiry purge, bounded hydration retry, visible
  certificate vintage, survivor-pension model coverage, confirmed-vs-preview
  field scope, stale-reference pruning, and confirmed-record wording. They are
  follow-ups, not hidden acceptance claims, and do not authorize activation or
  G2/G3.

## Decision boundary

This promotion closes only `G1-BND-05`. It does not activate LPP acquisition,
close `G1-RUNTIME-01`, complete G1, or authorize G2/G3. The canonical next G1
Wave 3 ticket is `G1-BND-06`; G1 remains **8.2/10 — NO-GO** with 13 open hard
floors.
