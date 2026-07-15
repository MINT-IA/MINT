# G1-PROV-02 exact-SHA runtime proof

Ticket: `G1-PROV-02`

Runtime source SHA:
`3aff2a0c839c2b57f021ccaa2453e93797e5bb3a`

Decision at this recording point:

- PROV-02 code/runtime contract: **GREEN**.
- Exact-SHA iOS runtime: **GREEN**.
- Production activation: **NO**. Both LPP feature flags remain false; only
  isolated Patrol processes set them true.
- PROV-02 promotion: **NO-GO until the required Claude wrapper code and
  product-domain audits are recorded and all findings are dispositioned**.
- G1: **NO-GO**. No G2/G3 work is authorized.

## Runtime chain

1. Full Doctor, Patrol tooling guard and Mermaid render guard passed.
2. The normal default-off application built and installed on one iOS
   Simulator from the pushed SHA.
3. Maestro proved LPP acquisition hidden and stale review/impact deep links
   recoverable.
4. Patrol writer selected the enabled synthetic LPP surface, confirmed the
   2025 certificate date and self ownership, then persisted exactly 12 typed
   facts through the real review/provider/secure-store/impact path.
5. The orchestrator explicitly launched and terminated the app. A separately
   built cold reader verified the persisted strict root, five critical
   presentation facts, provenance/status, privacy redaction and owner/auth
   invariants without a write shortcut.
6. Independent xcresult summaries each report exactly 1 passed, 0 failed,
   0 skipped.
7. The external Patrol tree was removed; the three core files of the normal
   build matched before/after hashes. The normal app was reinstalled and the
   same default-off Maestro flow passed again.
8. Full exact-SHA suites passed: Flutter 8,996/36/0 and backend 6,116/4/0;
   Flutter analyze reported zero issues.

All runtime data is synthetic. Private pension certificates and the local
private-fixture manifest were not used. No raw OCR, personal identity, UDID,
absolute user path, screenshot, build product or xcresult bundle is tracked.
Raw artifacts remain local; only deterministic sanitized summaries are here.

## Tracked evidence

- `patrol-metadata.sanitized.json` — lifecycle, exact SHA, synthetic/private
  boundary, source/build restoration, xcresult and entitlement hashes.
- `write-xcresult-summary.sanitized.json` and
  `read-xcresult-summary.sanitized.json` — independent 1/1 results.
- `source-contract-sha256.json` — five tracked runtime sources and invariant.
- `normal-build-core-sha256.json` — three normal bundle cores before/after.
- `suite-counts.json` and `gate-exit-codes.json` — exact broad/runtime gates.
- `raw-artifact-sha256.json` — hashes linking sanitized evidence to local raw
  metadata, xcresult summaries and broad-suite logs.
- `SHA256SUMS` — hashes of every tracked sanitized artifact except itself.
