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

## GREEN implementation audit dispositions

Accepted audits: `opus-green-code-audit.txt` and
`opus-green-product-domain-audit.txt` — both **PASS**, P0=0, P1=0.

1. **The five-path allowlist is hand-maintained.** Current producer completeness
   is directly tested by the 82-predicate canonical suite and the existing live-
   origin suite. A future producer/allowlist parity guard remains a nonblocking
   drift-hardening follow-up; it is not represented as automatic today.
2. **Two non-P0 IndicatifBanner callers still rely on history.** Annual-
   allocation and rent-versus-buy are outside the six P0 RETURN ticket and were
   not promoted by this fix. Their deterministic typed return is tracked as a
   separate follow-up rather than silently widening G1-RETURN-01.
3. **Paired GREEN artifact.** Closed in this same delivery by `green.json`,
   bound to exact SHA `6427a97722db879d74ccb04bde50d3c75e755112` and the
   identical 82/82 command.

No carousel rerun is warranted. Runtime and registry promotion remain separate
fail-closed gates.

## Six-origin runtime harness audit dispositions

Accepted audits: `opus-mobile-runtime-harness-audit.txt` (code) and
`opus-runtime-harness-product-domain-audit.txt` — both **PASS**, P0=0, P1=0.

1. **Witness booleans initially mirrored the stage name.** Fixed before commit:
   every stage now returns an observed `_StageProof` built from actual router
   URIs, collector state, persisted writes, byte-stable no-write comparisons,
   retained invalid input, and Frontalier no-DataBlock/canonical-write checks.
   The static contract rejects reintroduction of stage-derived truth booleans.
2. **Patrol behavior is simulator-only and CI-invisible.** Accepted only as a
   transparency boundary: static/contract tests cannot promote the ticket. The
   checked-in exact-SHA orchestrator must actually run and retain successful
   artifacts before RETURN-01 changes state.
3. **The static runtime contract is structural.** It is a drift guard, never a
   substitute for the five native stages, independent Maestro flows, exact-SHA
   RVC rerun, screenshots, witnesses and restoration.
4. **Disability uses the existing `revenu` block for birth year.** This is the
   current canonical storage surface and no alias was added. The naming wrinkle
   is tracked as a nonblocking product-language follow-up.

No same-gate carousel rerun was launched after the observed-witness hardening.
The harness remains unaccepted until its first exact-SHA runtime completes.
