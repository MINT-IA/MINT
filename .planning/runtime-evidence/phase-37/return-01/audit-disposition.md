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

## Bash 3.2 runtime-runner audit disposition

Accepted audit: `opus-bash32-runtime-runner-audit.txt` — **PASS**, P0=0,
P1=0.

1. **Sibling RVC runner portability.** The auditor requested an explicit check
   that the separately invoked RVC runner did not retain Bash-4-only constructs.
   `grep` found no `declare -A`, `local -A`, `mapfile`, `readarray`, `wait -n`,
   or Bash-4 case-conversion expansion, and `/bin/bash -n` passed.
2. **Runtime acceptance remains outstanding.** The mapping regression executes
   the three checked-in lookup functions under macOS `/bin/bash` 3.2 and proves
   exact outputs plus unknown-stage rejection, but it is not native app proof.
   The full six-outcome runtime must restart from a new pushed exact SHA.

No rerun is warranted: the only P2 verification is resolved directly above.

## Maestro failure-diagnostics audit disposition

Accepted audit: `opus-maestro-diagnostics-audit.txt` — **PASS**, P0=0,
P1=0.

The first retry on exact pushed SHA
`08d2160bf3117615add8cb7cbf03b85a60e38944` reached Work Patrol 1/1 and
then exited 1 in Work Maestro. This is **not** a partial acceptance: no
`metadata.json`, final checksums, screenshot/hierarchy, later stages or exact-
SHA RVC proof exist. Normal-app restoration and private cleanup passed.

1. **The original Maestro detail was lost before sanitisation.** Fixed by
   explicitly capturing the command status, validating and sanitising the raw
   log, sanitising JUnit when present, and only then emitting a stage-named
   fail-closed error. The regression locks this order.
2. **Errexit is disabled inside the bounded Maestro subshell.** Accepted as
   nonblocking: `-u` and `pipefail` remain active, the Maestro command is the
   final subshell command, its status is captured, and any nonzero status still
   terminates through the named failure after privacy-safe evidence retention.
3. **Runtime acceptance remains outstanding.** A fresh exact pushed SHA must
   rerun the entire matrix; the retained Work Patrol witness from the failed run
   is diagnostic only and cannot be composed into a later PASS.

No audit carousel rerun is warranted. The next native attempt must diagnose the
actual Work Maestro failure if it recurs.
