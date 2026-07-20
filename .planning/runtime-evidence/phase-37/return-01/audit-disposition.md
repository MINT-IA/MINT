# G1-RETURN-01 contract audit disposition

Date: 2026-07-20

Accepted audit: `opus-contract-product-domain-audit.txt` — **PASS**, P0=0,
P1=0.

## P2 dispositions

1. **Frontalier persistence failure has no visible retry.** Confirmed as a
   pre-existing Frontalier/FRONT recovery gap, not a RETURN terminal: the
   collector is inline, never creates a typed return target and never leaves
   `/segments/frontalier`. RETURN-01 will assert only route stability and the
   absence of a fabricated DataBlock Ask. The visible retry remains explicitly
   tracked as a FRONT follow-up and is not claimed by the contract decision.
2. **Non-P0 DataBlock producers are outside this ticket.** Accepted as an
   explicit scope boundary. RETURN-01 remains responsible for the five routed
   P0 origins plus the Frontalier in-place outcome; the global route registry
   and parser adversaries still fail closed, while unrelated producers are not
   silently promoted by this ticket.

No audit rerun is warranted: neither P2 changes the accepted planning decision,
and the ticket remains `ticket_only` until its exact RED -> GREEN proof exists.
