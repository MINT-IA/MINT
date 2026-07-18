# Audit acceptance and dispositions

## Boundary

The bounded `missingDocumentReference` recovery slice is technically GREEN.
RET-REF remains `ticket_only` and production-default-off; activation is NO-GO.
G1 remains open at 8.2/10, and G2/G3 are forbidden. PDF/dossier caveat parity
and a separate activation decision remain open.

## Accepted external audits

The wrapper first-pass Opus/high code and product-domain lenses both PASS with
P0=0 and P1=0. Each lens records two nonblocking P2 observations.

Accepted dispositions:

1. The minimal recovery router proves the CTA emits the exact scan URI, not that
   this test traverses the full production route graph. Production resolution is
   separately grounded by checked-in route wiring and production-default Maestro
   deep links. No broader end-to-end claim is made here.
2. Two constant-versus-string checks are not treated as independent privacy
   proof. The meaningful proof is the exact rendered neutral body together with
   absence of the known card, handoff CTA and fund-relation semantic.
3. The recovery Patrol body is intentionally skipped outside the Patrol CLI.
   The exact pushed native archive passes 2/2, while the checked-in orchestrator
   test guards the structural contract in ordinary automation.
4. XCTest output exposes the aggregate 2/2 result, not the individual internal
   Flutter assertions. UI claims are accepted only through the conjunction of
   the tracked exact-SHA reader and the passing native suite.

These P2s do not invalidate the bounded recovery proof. They do prohibit
inflating it into production activation, a full production-route traversal, or
RET-REF/G1 closure.
