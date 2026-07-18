# Audit acceptance and dispositions

## Boundary

The dossier/PDF parity slice is GREEN at exact pushed SHA
`274736a50bca659579fe26f68ae4e600469e3a9a`. It closes only
`pdf_dossier_caveat_parity`. RET-REF remains `ticket_only` and default-off;
activation is NO-GO. G1 remains open at 8.2/10, and G2/G3 are forbidden.

## Accepted lineage

1. Dossier wiring `0c12f9c84`: code PASS with P0/P1=0. Product-domain found one
   P1 because the PDF omitted the handoff.
2. PDF export `9055cf47b`: code and product-domain PASS with P0/P1=0. This
   remediates the dossier P1 with a production byte builder and ordered text
   contract.
3. Runtime delta `df217f8c0`: the wrapper correctly refused the 2579-line prompt
   against its 2500-line budget. No full-diff audit PASS is claimed.
4. Bootstrap `274736a50`: code and product-domain PASS with P0/P1=0 after the
   reader joined the production account bootstrap.

The exact runtime claim is grounded by the executable native suite, host text
contract, source verifier, Maestro before/after, and lifecycle/privacy checks.

## Nonblocking observations retained

- Dossier presentation still has open SafeMode/animation design observations.
- Showing the six neutral topics unconditionally and the single-kind localized
  label remain deliberate bounded product choices.
- The host text test requires `pdftotext`; the share callback remains
  fire-and-forget.
- Built-in PDF fonts drop some punctuation glyphs, and the text contract
  normalizes those glyphs. This remains a presentation-fidelity P2, not a loss
  of the negative-authority caveat or an activation waiver.
- Bootstrap keeps defensive bind/hydration calls that are harmless but partly
  redundant.

These observations lower the bounded slice score and keep activation NO-GO.
They do not reopen the fixed omission of the dossier/PDF handoff, and they are
not inflated into RET-REF or G1 closure.
