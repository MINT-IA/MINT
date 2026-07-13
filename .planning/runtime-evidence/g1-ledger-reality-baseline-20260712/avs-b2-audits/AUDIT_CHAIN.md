# G1 AVS B2 external audit chain

Date: 2026-07-13
Exact implementation SHA: `6d0b1d19532c6ef498307d0ecf68507de9a9819a`

All four runs used `tools/checks/claude_external_audit.sh`, safe mode, strict
empty MCP, user-only settings, no session persistence, and high effort.

## First pass — Opus

Base `7758defa4`.

- Code: **NO-GO**, P1 flagship retirement sequences could not complete while
  the AVS projection was pending.
- Product/domain: **PASS**, P1 named form 318.282 did not deep-link to the
  sourced form.

The P1s were closed by:

- `fad6e9bc1`: first-class `avs_pending` sequence completion, with no
  numeric replacement-rate or gap output.
- `9b97fb677`: locale-aware direct official form, with English fallback for
  Spanish/Portuguese because the corresponding official endpoints returned
  404.

## Same-gate rerun — Sonnet

The original `7758defa4...HEAD` prompt expanded to 35,100 lines with the
wrapper's required context and was rejected by Claude as too long. The rerun
was therefore bounded to the complete repair/evidence slice
`471157cb2...6d0b1d195` (10,035 prompt diff lines), rather than weakening the
wrapper or sending a truncated diff.

- Code: **PASS**, no P0/P1.
- Product/domain: **PASS**, no P0. It still reports three P1 product-delivery
  debts: Tornado non-AVS blackout, orphaned `PremierEclairageSection`, and
  orphaned `EarlyRetirementComparison`. They remain open and must be deleted,
  explicitly quarantined, or wired safely before final G1 closure.

## Boundary

This audit chain closes the two original Opus P1s and validates the certified
null hard floor. It does not declare G1 complete. Parser/source-date, secure
atomic provenance, couple law/consent, legacy CoupleOptimizer, and the three
product-delivery P1s remain outside this evidence boundary. G2/G3 remain
forbidden.
