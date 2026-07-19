# Phase 37 Evidence Contract

This directory is the checked-in evidence boundary for the 31 G1 blocking
tickets. It contains synthetic gate metadata only. Do not store names, email
addresses, document content, authentication material, or real financial values.

## Ticket states

- `ticket_only`: the contract exists, but no RED or GREEN is claimed. All SHA
  and artifact fields are `null`.
- `red_proven`: the exact registry command reached the named business predicate
  and failed semantically. Missing files, imports, selectors, tools, simulator
  boot, or compilation are harness gaps and do not qualify.
- `green`: the same command passes and its accepted SHA is recorded. This
  closes one ticket only; it does not authorize G2.

Every executor must update one registry row and the matching JSON record in the
same reviewable change. Batch GREEN transitions are forbidden.

## Evidence modes

- `red_green`: retain one JSON RED log and one JSON GREEN log.
- `baseline_green_controlled`: when the predicate already passes, retain a
  failing negative fixture or mutation CONTROL plus the baseline GREEN log.

Evidence logs record the ticket ID, exact command, UTC time, 40-character Git
SHA, exit code, gate assertion, classification, non-empty output, and
`synthetic_data_only: true`. Paths must be repository-relative and remain below
`.planning/runtime-evidence/phase-37/`.

## Audit manifests

Every implementation wave requires exactly one accepted `code` run and one
accepted `product-domain` run through
`tools/checks/claude_external_audit.sh`. Final closure additionally requires
exactly one `architecture` run. Failed, quota-limited, authentication-failed,
timed-out, or superseded attempts remain separate artifacts and never become a
second accepted `runs[]` entry.

Current machine truth after `G1-SCN-01` promotion: **24 `green`, 6
`ticket_only`, 1 `red_proven`; 7 of 31 hard floors remain open**. G1 remains
**8.2/10 — NO-GO**; G2/G3 stay forbidden.

`G2 allowed` remains **NO** until all 31 records are `green`, runtime evidence
is accepted on the same product SHA, required audits have zero unresolved
P0/P1/critical/high findings, and the Phase 37 score is at least 9.0/10.
