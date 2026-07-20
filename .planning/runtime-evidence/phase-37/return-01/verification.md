# G1-RETURN-01 verification

Date: 2026-07-20

Decision: **GREEN for G1-RETURN-01 only.** `G1-RUNTIME-01` remains
`red_proven`; G1 remains NO-GO and G2/G3 remain forbidden.

## Ticket predicate

Five routed P0 producers must return to their exact typed origin on every
applicable save, cancel, validation and persistence-retry terminal. Frontalier
must collect residence country, work country and work canton inline without a
DataBlock/`returnUri`, remain on `/segments/frontalier`, and retain FR/CH/GE
across a cold relaunch. Invalid, forged, sensitive or inappropriate registered
return targets must fail closed to typed Home. The already-linked RVC LPP return
must still pass on the same exact runtime source.

## RED -> GREEN

Canonical command:

```bash
cd apps/mobile && flutter test test/navigation/data_block_return_uri_test.dart --reporter expanded
```

| stage | exact SHA | result | artifact |
|---|---|---|---|
| semantic RED | `0035356f969236031772bc1956e956a6414c9487` | 72/82; ten business-predicate failures | `red.json` |
| implementation GREEN | `6427a97722db879d74ccb04bde50d3c75e755112` | 82/82 | historical implementation point, retained in `green.json` output |
| accepted reconfirmation | `d13d032504837cd4bc9233cb6309ebd36b24e4bb` | 82/82 after the runtime feature-flag test correction | `green.json` |

The RED is semantic, not a missing-file/import/timing failure. GitHub CI run
`29777377274` completed successfully at the accepted exact SHA
`d13d032504837cd4bc9233cb6309ebd36b24e4bb`.

## Native runtime

Authoritative six-origin metadata:

`runtime-5eb8a78a2b-20260720T202301Z/metadata.json`

Source is the exact pushed SHA
`5eb8a78a2b38caba9ef165ad90f023773bba81f0`. The run passed:

- Patrol 1/1 and Maestro for Work save;
- Patrol 1/1 and Maestro for Housing cancel with no write;
- Patrol 1/1 and Maestro for Disability validation cancel with no write;
- Patrol 1/1 and Maestro for Succession save;
- Patrol 1/1 and Maestro for Frontalier inline FR/CH/GE, followed by a cold
  relaunch that still exposes the known jurisdiction state;
- linked exact-SHA RVC LPP Patrol and Maestro under
  `../return-01-rvc/runtime-5eb8a78a2b-20260720T202301Z/metadata.json`.

The six-origin metadata records `result=passed`, `pushedShaVerified=true`,
physical exact production source and overlay, five Patrol stages, five Maestro
stages, screenshots/hierarchies/store witnesses, RVC exactness, verified
checksums, synthetic-only data, cleanup `passed`, restoration `restored`, no raw
runtime retention and a clean source tree after runtime. `SHA256SUMS` verifies
for the six-origin directory. The RVC link pins the linked metadata hash.

## External review

The wrapper audit lineage and dispositions are archived beside this report,
including code and product-domain lenses. Accepted records report no unresolved
P0/P1. No new audit was launched for this registry-only promotion.

## Residual boundaries

This proof closes safe return behavior only. It does not prove the separate
salary/canton -> mortgage persistence/recompute predicate in
`G1-RUNTIME-01`, does not close the four other `ticket_only` rows, and does not
close the still-open `G1-COHERENCE-01` assembled First Job screen acceptance
floor. Registry truth after promotion is 26/31 GREEN, four `ticket_only`, one
`red_proven`: five hard floors remain.
