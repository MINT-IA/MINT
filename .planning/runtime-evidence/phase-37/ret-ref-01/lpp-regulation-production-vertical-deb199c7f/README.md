# G1 LPP regulation vertical — external audit archive

This directory archives the bounded Claude-wrapper reviews for the G1
`lpp_plan` acquisition, ephemeral backend boundary, and review writer at code
slice `deb199c7f`.

This is **audit evidence only**. It is not a device-runtime, Maestro, Patrol,
Doctor, activation, or release-readiness claim. G1 remains governed by its
separate exact-SHA runtime and acceptance gates.

## Wrapper stages and disposition

| Evidence | Lens | Wrapper stage / model | Verdict | Disposition |
|---|---|---|---|---|
| `audits/acquisition-code-first-pass-opus-high.txt` | code | first pass / Opus high | PASS, dormant only | P1 writer wiring and P2 retention/flag-recovery findings were carried forward; this PASS did not clear activation. |
| `audits/acquisition-product-first-pass-opus-high.txt` | product-domain | first pass / Opus high | NO-GO | The missing writer and unresolved persistence boundary blocked product value. Both were addressed before rerun. |
| `audits/backend-ephemeral-code-first-pass-opus-high.txt` | code | first pass / Opus high | PASS | P0/P1 = 0. P2 notes remain non-blocking backlog/disposition items. |
| `audits/backend-ephemeral-product-first-pass-opus-high.txt` | product-domain | first pass / Opus high | PASS | P0/P1 = 0. The noisy-title certificate precedence edge was subsequently fixed and tested; other P2 notes stayed non-blocking. |
| `audits/writer-code-rerun-sonnet-high.txt` | code | same-gate rerun / Sonnet high | PASS | P0/P1 = 0 after the real acquisition-to-writer chain was wired. |
| `audits/writer-product-rerun-sonnet-high.txt` | product-domain | same-gate rerun / Sonnet high | PASS | P0/P1 = 0. The suggested 1985 legal-year floor was not adopted: later Swiss review found that it conflated the start of mandatory LPP with a regulation edition/reference year. |
| `audits/writer-code-final-opus-high.txt` | code | final confirmation / Opus high | PASS | P0/P1 = 0; remaining findings are P2 polish only. |
| `audits/writer-product-final-opus-high.txt` | product-domain | final confirmation / Opus high | PASS | P0/P1 = 0; terminology/help-text and self-only coupling remain explicit non-blocking follow-ups. |

The wrapper loop is exhausted for this slice: one Opus first pass, one Sonnet
same-gate rerun, and one Opus final confirmation. No audit was rerun to create
this archive.

## Sanitization boundary

The archived reports preserve verdicts, findings, test statements, and
dispositions. Sanitization removed only:

- an isolated temporary audit-worktree label;
- a raw cross-user preview sentinel used by a test;
- any absolute local path, private-fixture identity, raw document value/hash,
  device identifier, secret, or transient-worktree detail if present.

No exit code was reconstructed or inferred. `SHA256SUMS` covers this README and
the eight sanitized reports.
