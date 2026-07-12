# Phase 37-02 analyzer audit chain

The original final-head audit from `3397d48b2` was rejected by the wrapper
before Claude execution because its unified-80 prompt was 13,301 lines, above
the 4,500-line hard budget. `CLAUDE_AUDIT_ALLOW_LARGE_DIFF` was not used.

To preserve continuous review coverage without hiding the analyzer changes,
the analyzer-only tree was rebuilt from the last externally reviewed head
`ef80e8cb8` as three bounded slices:

1. `ef80e8cb8..be42b9e6e` — production and journey mechanical cleanup;
2. `be42b9e6e..e266da836` — widget/test mechanical cleanup;
3. `e266da836..429aec5d9` — Flutter 3.41 a11y migration and dormant contracts.

Each slice has one Opus/high `code` audit and one Opus/high `product-domain`
audit on the same head. All six wrapper runs exited 0 with PASS and zero P0/P1.
The raw outputs and fail-closed metadata are archived beside this file.

This chain covers every analyzer change before the analyzer baseline is merged
normally into the product branch. The later Phase 37-02 final audit must still
cover the bounded product-remediation delta and must not treat this manifest as
the final wave `audit-manifest.json`.

**G2 allowed: NO.**
