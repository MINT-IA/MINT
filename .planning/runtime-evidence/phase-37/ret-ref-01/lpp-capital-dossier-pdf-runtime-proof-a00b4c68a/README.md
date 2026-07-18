# G1 RET-REF LPP capital-notice dossier/PDF — minimized proof

## Decision boundary

This bundle accepts the bounded capital-notice dossier/PDF parity slice at
exact pushed SHA `a00b4c68a272cbde9f21fee14662171c4a12530f`. It closes only
`capital_notice_dossier_pdf_parity`. Activation remains **NO-GO**, RET-REF
remains `ticket_only`, and G1 remains open at **8.2/10**. G2 and G3 are
forbidden.

## Accepted proof

- The native writer and distinct-process cold reader each pass **1/1**.
- The reader boots the real application/account session, opens `/rapport`,
  observes both specialist handoffs in the required order, and calls the
  production report and PDF builders.
- Native runtime proves only a valid PDF header and nontrivial byte length. It
  does **not** prove extracted PDF text.
- Separate host contracts pass **11/11**: six dossier/presenter checks and five
  real-PDF text checks for ordered allowlisted content, omission, ordering and
  sensitive-token absence.
- Missing and mismatched capital references suppress only the capital handoff;
  legacy regulation recovery suppresses both. The strict root and BND are
  restored exactly before authority and numeric-snapshot invalidations.
- Production-default Maestro passes **1/1**, and the capital report handoff is
  absent with the shipping-default flag state.

## Assertion trace

Native XCTest output exposes the two aggregate test results, not every Flutter
assertion. Runtime claims therefore require the exact-SHA tracked contracts and
their passing native aggregates. Text-parity claims require the separate host
PDF suite; they are not attributed to Patrol or Maestro.

## Evidence minimization

Only allowlisted summaries are retained. The bundle contains no raw output,
local environment location, device material, private fixture, source document,
document digest or bytes, result bundle, generated PDF, screenshot, media,
synthetic marker, or raw audit transcript. `SHA256SUMS` covers every retained
artifact except itself.
