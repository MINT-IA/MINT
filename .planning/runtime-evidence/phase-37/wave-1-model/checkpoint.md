# Phase 37-02 quality checkpoint — fail closed

**Product SHA:** `8941a85b3d3baa18656e7f399997c7cca5b73f36`

**SOT/evidence SHA:** `3693978ea439d686096f5b4e0b0eab7c6bf616c4`

## Green evidence collected

- Six exact ticket commands pass independently on the product SHA.
- `flutter test test/models/ test/providers/mint_state_proxy_recompute_test.dart --reporter expanded`: 225 passed.
- Final full Flutter suite supplied by the mobile executor: 8,514 passed, 28 skipped, exit 0.
- Touched-file analyzer: no issues, exit 0.
- Global analyzer floor remains the pre-existing 114 diagnostics and exit 1; it is recorded as an unchanged baseline floor, not reported as a global PASS.
- Repo Doctor, Mermaid render, ledger parity, progressive ticket gate, and screen-contract route gate pass.
- The 39 stale `reader_evidence` windows in `G1-ledger-gap-matrix.md` were mechanically synchronized to live readers.
- Lefthook passed on the SOT/evidence checkpoint.

## Blocking audit state

The wrapper-only `code` audit could not produce an accepted run because the
Claude session limit was reached. The first local preflight also rejected an
undersized 3,500-line budget before Claude was invoked; both attempts are
recorded separately in `audit-failed-attempts.json`.

No `product-domain` audit was launched after the quota signal. There is no
accepted `audit-manifest.json`, no ticket promotion, and no Phase 37/G2
completion claim. Retry the two required wrapper modes after 21:20
Europe/Zurich; accept exactly one unique PASS run per mode with zero unresolved
P0/P1/critical/high findings.

**G2 allowed: NO.**
