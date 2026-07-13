# G1 AVS B2 exact-SHA quality proof

Commit: `6d0b1d19532c6ef498307d0ecf68507de9a9819a`

- Full MINT Doctor: PASS.
- Full Flutter analyze: PASS, no issues.
- Full Flutter test: 8,542 passed, 29 skipped, no failures.
- Exact iOS build: PASS.
- Maestro dashboard → AVS guide → form 318.282 CTA: PASS.
- Patrol native contract: 1/1 PASS.
- Independent xcresult summary: Passed, 1 total, 1 passed, 0 failed.
- App and repository worktrees clean after Patrol cleanup and normal-app
  restoration.

Runtime details, commands, screenshots, checksums, and xcresult are under
`runtime-exact-sha/`. The screenshot proves the requested official-form CTA;
it also exposes secondary-action clipping below that proof surface, which is
not treated as a false green and remains a visual follow-up.

This is proof for the exact AVS B2 commit only. It does not close later G1
parser, couple-law, consent, or product-delivery changes.
