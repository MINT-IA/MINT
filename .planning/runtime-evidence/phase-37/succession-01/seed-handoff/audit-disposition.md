# G1-SUCCESSION-01 seed-handoff — audit disposition

External Opus first-pass audits:

- code: **PASS**;
- product/domain: **PASS**;
- P0: **0**;
- P1: **0**;
- P2: **3**.

| P2 finding | Disposition | Evidence / rationale |
|---|---|---|
| Fixture values could drift between the Patrol seed, runner witness, and checked-in contracts. | **Fixed** | The static cross-file orchestrator test binds the seed fixture and witness contract, so drift fails before runtime. |
| `selectedValuesSha256` originally covered only birth year, canton, and civil status. | **Fixed** | The digest scope now also hashes the normalized lifecycle assertions `mini=false` and `propertyPresent=false`; the pre-overlay and post-overlay sanitized witnesses therefore compare the complete accepted seed state. |
| A non-conforming witness is reported through the bounded polling timeout rather than an immediate mutation-specific diagnostic. | **Accepted — bounded fail-closed** | The wait is capped at 30 seconds and cannot produce a false PASS. Revisit only if exact-SHA runtime evidence shows that the diagnostic delay is operationally costly. |

No audit rerun is requested. Under the MINT no-carousel rule, the first-pass
PASS verdicts plus the dispositions above close this audit gate; rerunning the
same unchanged gate would add cost without new evidence.
