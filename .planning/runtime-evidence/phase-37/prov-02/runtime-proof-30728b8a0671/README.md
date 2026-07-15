# G1-PROV-02 exact-SHA runtime proof

Ticket: `G1-PROV-02`

Runtime source SHA:
`30728b8a0671a0b54bcf47807a0c69bac905e6e3`

Decision at this recording point:

- PROV-02 TDD ticket contract: **GREEN**, 22/22.
- Exact-SHA iOS process-death runtime: **GREEN**, writer 1/1 and cold reader
  1/1.
- Claude code and product-domain lenses: **PASS**, all findings dispositioned.
- Production activation: **NO**. Both LPP feature flags remain false; only
  isolated test processes enabled the runtime path.
- G1: **NO-GO**, with 17 of 31 hard floors still open.
- G2/G3: **forbidden**.

## Runtime chain

1. The exact pushed SHA and clean preflight were recorded.
2. Full Doctor, Patrol tooling guard and Mermaid render guard passed.
3. The normal default-off iOS application built and installed successfully.
4. Initial Maestro proved LPP acquisition hidden and stale review/impact deep
   links recoverable.
5. A Patrol writer selected the enabled synthetic LPP surface and persisted
   12 populated facts from the canonical 13-key vocabulary independently for
   self and manual partner
   through the production review/provider/strict-secure path.
6. The orchestrator explicitly terminated the application. A separately built
   cold reader verified strict and presentation facts, provenance/status,
   privacy redaction and owner/authorization invariants without a write
   shortcut.
7. Independent xcresult summaries each report exactly 1 passed, 0 failed and
   0 skipped.
8. The external Patrol tree was removed. The normal build's three core hashes
   matched before and after, the normal app was restored, and the same
   default-off Maestro flow passed again.
9. Exact-SHA broad suites passed: Flutter 9,031/36/0 and backend 6,108/7/0;
   Flutter analyze reported zero issues. The 93-error global backend Ruff
   baseline is recorded separately and is unrelated to this mobile ticket.

All runtime data is synthetic. A confidential local parser oracle passed, but
none of its inputs, identifiers, paths, contents, or values is present here.
No raw OCR, personal identity, device identifier, absolute user path,
screenshot, raw log, build product or xcresult bundle is tracked.

## Tracked evidence

- `patrol-metadata.sanitized.json` — lifecycle, exact SHA, synthetic-data
  boundary, process termination, source/build restoration and binary hashes.
- `write-xcresult-summary.sanitized.json` and
  `read-xcresult-summary.sanitized.json` — independent native 1/1 results with
  device identifier removed.
- `source-contract-sha256.json` — five runtime sources and exact hashes.
- `normal-build-core-sha256.json` — three normal bundle cores before/after.
- `suite-counts.json` and `gate-exit-codes.json` — exact broad/runtime counts,
  including the unrelated Ruff baseline disposition.
- `uuid-v4-validation.json` — direct resolution of the Sonnet code P1.
- Four `audit-*.sanitized.txt` files — bounded Opus/Sonnet findings without
  confidential runtime material.
- `raw-artifact-sha256.json` — hashes linking these summaries to the local raw
  bundle without tracking its logs or screenshots.
- `SHA256SUMS` — hashes of every tracked sanitized artifact except itself.

The complete ticket-level finding disposition is one directory above in
`audit-manifest.json`; the RED/GREEN and decision narrative are in
`red.json`, `green.json` and `verification.md`.
