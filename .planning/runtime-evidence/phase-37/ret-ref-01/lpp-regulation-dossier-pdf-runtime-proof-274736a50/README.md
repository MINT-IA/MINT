# G1 RET-REF LPP regulation dossier/PDF — minimized runtime proof

## Decision boundary

This bundle accepts the bounded dossier/PDF parity slice at exact pushed SHA
`274736a50bca659579fe26f68ae4e600469e3a9a`. It closes only
`pdf_dossier_caveat_parity`. RET-REF remains `ticket_only`, every production
flag remains false, and activation is **NO-GO**. G1 remains open at **8.2/10**;
G2 and G3 are forbidden.

## Accepted proof

- The exact native Patrol suite passes **2/2** with zero failures and distinct
  writer/reader processes.
- The cold reader uses `MintApp`, joins production account bootstrap, opens the
  real `/rapport` route, observes the metadata-only handoff, and constructs the
  production financial-report bytes.
- The tracked reader verifies a valid document header and nontrivial byte
  length. The separate host byte contract passes **3/3** and uses `pdftotext`
  to prove ordered allowlisted text, null-handoff omission, and sensitive-token
  absence.
- Missing-reference, mismatched-reference, and legacy recovery states all
  suppress the dossier handoff. The original strict root and BND are restored.
- Production-default Maestro passes **1/1 before** and **1/1 after**. Production
  reinstall preserves identity/state, cleanup and restoration pass, and the
  retained-output contract is **22/22**.

## Assertion trace

XCTest exposes the native 2/2 aggregate, not each internal Flutter assertion.
Dossier and runtime-byte claims therefore require both the exact-SHA tracked
reader and the passing native aggregate. Exact text claims additionally require
the passing tracked host byte contract. No OS share-sheet or external viewer is
claimed.

## Audit honesty

The dossier, PDF, and bootstrap component deltas have bounded wrapper evidence.
The wrapper refused the combined runtime diff because its prompt exceeded the
configured diff budget; this bundle records that refusal rather than inventing
a PASS. Runtime acceptance rests on the executable exact-SHA gates.

## Evidence minimization

Only allowlisted sanitized summaries are tracked. No local environment path,
device identifier, private fixture, source document, document digest or bytes,
result bundle, screenshot, media, or raw runtime/audit output is retained.
`SHA256SUMS` covers every retained artifact except itself.
