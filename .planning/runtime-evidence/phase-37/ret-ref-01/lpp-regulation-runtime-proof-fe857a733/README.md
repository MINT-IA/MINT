# G1 RET-REF LPP regulation — exact-SHA runtime proof

Runtime source SHA:
`fe857a733385357a12d564bd0a7894b30f887e82`

Capture window: 2026-07-18 05:54–05:58 UTC. All runtime data was synthetic.

## Decision boundary

- Snapshot-bound `lppRegulationReference` technical runtime atom: **PASS / live**.
- Autonomous current-fund authority: **NO-GO**. The proven reference remains
  coupled to the current numeric self-LPP snapshot; architecture observation
  `#8730` requires a separately attested fund relationship before activation.
- Production activation: **NO-GO**. All product flags remain default-false.
- Whole `G1-RET-REF-01`: **ticket_only / open**. The autonomous fund authority,
  capital-notice production acquisition/activation, 3a beneficiary reference,
  and fiscal activation/currentness obligations remain incomplete.
- G1: **NO-GO at 8.2/10**. G2/G3 remain forbidden.

The bounded snapshot-coupled atom scores **9.0/10** under the fixed quality
rubric: data contract 1.5/2.0, Swiss correctness 1.0/1.5, UX lucidity 1.5/1.5,
runtime 1.5/1.5, automated tests 1.0/1.0, external audit 1.0/1.0,
integration/privacy 1.0/1.0, and diff/evidence discipline 0.5/0.5. The two
0.5 deductions are the same authority limitation, not an activation waiver.

## Exact-SHA proof chain

1. The orchestrator rejected non-HEAD/non-upstream inputs and ran at the exact
   pushed SHA above.
2. Full MINT Doctor and the checked-in Patrol tooling guard passed.
3. A physical Git archive built the normal production entrypoint with no test
   feature defines; export, extract, build, signature, xattr and installs all
   exited 0.
4. Production-default Maestro passed before the writer and again after the
   process boundary, each with one test and zero failures. The AFTER flow kept
   application state while all LPP-regulation controls remained default-off.
5. Patrol drove the production-shaped synthetic `lpp_plan` picker/uploader and
   real review UI. The writer persisted the raw-free reference tuple only after
   the ledger accept step; its independent summary is 1 passed / 0 failed.
6. Explicit simulator boot, launch and termination each exited 0. A separately
   built cold reader hydrated the Dashboard reference, opened the local
   metadata-only six-question specialist handoff, then proved a later numeric
   self-LPP replacement invalidates and hides the reference. Its independent
   summary is 1 passed / 0 failed.
7. Cleanup and normal-build restoration passed. No private fixture, document
   hash, raw document bytes, raw simulator identifier, or Xcode result bundle
   was retained.

## Sanitized command boundary

```text
tools/simulator/patrol_lpp_regulation_process_death.sh \
  --device <REDACTED_SIMULATOR_UDID> \
  --bundle-id ch.mint.app \
  --sha fe857a733385357a12d564bd0a7894b30f887e82 \
  --artifacts <LOCAL_IGNORED_EVIDENCE_DIR>
```

The source bundle remains ignored locally. This tracked promotion deliberately
copies only metadata, independent writer/reader counts and the two sanitized
Maestro JUnit reports. Raw build/test logs, generated build products, device
identifiers, media and result bundles are not tracked. A normal default-off
screen was inspected separately; no PNG is copied or hashed here.

## Tracked artifacts

- `metadata.sanitized.json` — exact SHA, lifecycle/stage exits, default-off,
  restoration and explicit privacy booleans.
- `gate-exit-codes.json` — compact deterministic stage accounting.
- `write-test-summary.sanitized.json` — writer 1/1.
- `read-test-summary.sanitized.json` — cold reader 1/1.
- `maestro-before-report.sanitized.xml` — production-default before, 1/1.
- `maestro-after-report.sanitized.xml` — state-preserving production-default
  after, 1/1.
- `SHA256SUMS` — integrity hashes of every tracked proof file except itself.

## Unresolved findings

1. Replace the snapshot-derived caisse relationship with the autonomous,
   explicitly attested current-fund authority from architecture observation
   `#8730`; an old numeric LPP snapshot cannot attest the current fund.
2. Keep `lppRegulationReferenceEnabled` and all acquisition flags false until
   that authority, activation gates and the remaining RET-REF ticket gaps pass.
3. Do not promote RET-REF or G1 from this bounded runtime atom.
