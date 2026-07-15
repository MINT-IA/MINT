# G1-PROV-02 verification

Accepted implementation and runtime SHA:
`30728b8a0671a0b54bcf47807a0c69bac905e6e3`

- Ticket decision: **GREEN**
- Production activation: **NO**
- G1 decision: **NO-GO**

## Exact TDD ticket proof

- Registry command:
  `cd apps/mobile && flutter test test/providers/provenance_restart_test.dart --reporter expanded`.
- Semantic RED SHA `ffaa2c6f18bd246ce19615b3d6d7ddcf58210a4b`:
  exit `1`. The command reached the first cold-reconstruction business
  predicate, but four critical projected self-LPP presentation facts returned
  with null values and absent field provenance.
- GREEN SHA `30728b8a0671a0b54bcf47807a0c69bac905e6e3`:
  exit `0`; **22 passed, 0 failed, 0 skipped**.
- Machine evidence: `red.json`, `green.json`. Sanitized transcripts:
  `red-output.txt`, `green-output.txt`.

The tracked RED transcript removes checkout paths and financial example
values. Every ticket/runtime fixture is synthetic. Confidential local parser
inputs were used only by an ignored local oracle; none of their identifiers,
paths, contents, values, screenshots, or raw logs is tracked.

## Exact-SHA runtime chain

The sanitized immutable bundle is
`runtime-proof-30728b8a0671/README.md`.

1. Full Doctor, Patrol tooling guard and Mermaid render guard passed.
2. The normal default-off iOS application built and installed successfully.
3. Maestro passed before and after the instrumented run, proving that LPP
   acquisition stayed hidden by default and stale review/impact routes
   recovered.
4. A native Patrol writer persisted synthetic self and manual-partner LPP facts
   through the real review, provider and strict-secure store path: **1 passed,
   0 failed, 0 skipped**.
5. The orchestrator explicitly terminated the application. A separately built
   cold reader then verified strict and presentation facts for both owners:
   **1 passed, 0 failed, 0 skipped**.
6. Independent xcresult summaries both report `Passed`, total `1`, failed `0`,
   skipped `0`.
7. The external Patrol build was removed, the normal build was restored, and
   all three normal core hashes matched before/after exactly.
8. Runtime source hashes match the accepted SHA and the orchestrator contract
   suite passed **23/23**.

No device identifier, absolute user path, screenshot, raw log, build product,
xcresult bundle, document content, or confidential parser input is tracked.

## Exact-SHA non-regression

- Full Flutter suite: **9,031 passed, 36 skipped, 0 failed**, exit `0`.
- Flutter analyze: **0 issues**, exit `0`.
- Backend suite: **6,108 passed, 7 skipped, 0 failed**, exit `0`.
- Local confidential parser oracle: **1 passed, 0 failed**, six case tokens
  checked; only the aggregate result and source-log hash are retained.
- Doctor, Mermaid guard, Patrol guard and changed-orchestrator Ruff: exit `0`.
- Backend global Ruff: exit `1`, **93 known baseline errors**, 57 normally
  fixable plus 10 unsafe fixes available. This unchanged repository baseline
  is unrelated to the mobile PROV-02 predicate and is not relabelled green.

## External audit disposition

Opus first-pass and accepted Sonnet-rerun sanitized summaries are in the new
runtime bundle. The machine disposition is `audit-manifest.json`.

- Code rerun: **PASS**. Its UUID-v4 P1 is resolved by direct exact-SHA proof in
  `uuid-v4-validation.json`; all code P2s are resolved or accepted without a
  persistence defect.
- Product-domain rerun: **PASS**. The prior owner-before-upload P1 and
  single-user partner-slot P2 are fixed.
- The absence of a frozen cold-reload-to-named-consumer proof and the unresolved
  named legal/privacy accountability decision and outcome remain explicit
  **later-G1/activation blockers**. Existing services do read partner LPP
  scalars; G1-BND-02 must prove one user-visible fail-closed recompute and the
  institution scope of the partner fund-return rate. G1-BND-02A must implement
  the selected accountability mechanism; any durable proxy-attestation record
  is conditional and never proves direct partner consent. These items are
  resolved only for the bounded ticket decision by activation NO; they are not
  claimed implemented.
- Other product P2s remain later-G1 data-model, freshness, dossier, usability,
  or activation hardening and are enumerated without suppression in the
  manifest.

One superseded code-rerun attempt against an oversized base exceeded the audit
prompt budget and is not an accepted manifest run. The bounded Sonnet rerun
returned exit `0`; no further audit carousel is authorized.

## Decision boundary

The PROV-02 persistence predicate is evidence-backed GREEN. Both LPP production
flags remain `false`; test processes alone enabled the isolated runtime path.
This ticket does not authorize product activation, close the later consumer or
privacy gates, close `G1-RUNTIME-01`, or waive any other Phase 37 row.

After this promotion the registry truth is **14/31 GREEN**, **16
`ticket_only`**, **1 `red_proven`**: **17 hard floors remain open**.

**G1 remains NO-GO; G2/G3 remain forbidden.**
