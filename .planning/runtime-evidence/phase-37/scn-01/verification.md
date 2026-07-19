# G1-SCN-01 verification

Accepted implementation/runtime SHA:
`464d5c56b1067df31b77b8c01eb87cd5085f49c6`

- Ticket decision: **GREEN**
- G1 score and decision: **8.2/10 — NO-GO**
- G2/G3 decision: **forbidden**

## Exact TDD ticket proof

- Registry command:
  `cd apps/mobile && flutter test test/providers/scenario_fact_isolation_test.dart --reporter expanded`.
- Semantic RED SHA `d1276b753b9d7b04e54815c12383681297bddb50`:
  the identical command compiled, reached `EplScreen` and finished **0/1**
  because raw `montant_epl` and `impact_rente` still leaked through
  `stepOutputs`. This was a business/privacy predicate failure, not a missing
  file, import, fixture, command or harness failure.
- Accepted GREEN SHA `464d5c56b1067df31b77b8c01eb87cd5085f49c6`:
  the identical command passes **11/11**. The broader targeted scenario,
  sequence, EPL, rente-capital and Coach suite passes **149**, skips **5**
  native-only cases and fails **0**.
- Machine evidence: `red.json`, `green.json`, `runtime-summary.json` and
  `audit-manifest.json`.

`CoachProfileProvider` remains the canonical fact spine. The separate encrypted
cache is bounded to EPL and rente-capital, stores only opaque UUIDv4 identity,
closed lifecycle state and typed levers, and never stores certified facts or
derived financial results. Cold reload restores levers, rereads current facts
and recomputes. Missing/stale facts, malformed or wrong-kind identity, obsolete
async results, cache failure, feature disablement and session/account change all
fail closed. Sequence completion persists only exact run/step/event identity,
scenario ID and terminal status; it validates the encrypted store and preserves
anti-replay state. Two real callers are wired.

## Versioned Patrol and visual proof

The accepted runtime folder is
`runtime-464d5c56b1-20260719T111834Z/`. The checked-in executable runner
`tools/simulator/patrol_scn01_scenario_isolation.sh` builds the exact target in
an external isolated directory, then runs `xcodebuild test-without-building`
on the same booted simulator and completes the versioned visual-marker
handshake. It finished **1 test / 0 failures** and restored the original build,
removed Patrol's generated bundle and discarded the xcresult.

The runner is tracked as Git mode **100755**. Its fail-closed contract suite
passes **25/25** and covers SHA/cleanliness, tracked contracts, build isolation,
marker validation, screenshot failure, log sanitization, signals and cleanup.
This closes the initial Opus P1 that the earlier real pass depended on an
untracked temporary runner.

Direct original-resolution inspection accepted `final.png`: the clean no-label
screen shows “Rente ou capital : ta décision” and “Calcul non disponible” with
an explanation that facts must first be collected. No input, slider, CHF
amount, seed figure, scenario session or cache access is present. The DEBUG
ribbon is visible and no claim is made about release chrome. Runtime metadata
and logs retain no raw UDID, repository path, temp path, certificate or private
financial data.

## GitHub/Vercel clean-room proof

GitHub Actions run
[`29684891621`](https://github.com/MINT-IA/MINT/actions/runs/29684891621)
passes on the exact accepted SHA, including **482 repository contracts**,
Flutter services/screens/widgets, backend and CI Gate. Vercel deployment
`G6DkrHXSUNtV8ojZmpbDuDcc8gpi` also passes.

The previous GitHub run `29684539042` is retained as a useful clean-room RED:
it found that the new runner had been committed as `100644` despite being
locally executable. Commit `464d5c56b` fixed the Git index mode to `100755`,
then the exact runtime, CI and visual evidence were regenerated. The failed run
is not represented as accepted evidence.

## External audit disposition

Wrapper-only audits cover the core scenario boundary, exact sequence-bridge
blobs, purge/first-frame hardening, the product-domain meaning and the runtime
proof. The first runtime Opus audit correctly returned **NO-GO** with one P1
(no checked-in orchestrator) and one P2 (`TextFormField` did not match the real
`TextField`). Both are fixed. The one allowed Sonnet rerun passes with
P0=0/P1=0. After GitHub exposed the mode-only clean-room gap, the single
allowed Opus final confirmation on exact SHA `464d5c56b` also passes with
P0=0/P1=0; supporting Opus code and product-domain partitions pass too. The complete lineage, exact-blob mapping, failed attempt and ten
nonblocking P2 follow-ups are explicit in `audit-manifest.json`.

## Decision boundary

This promotion closes only `G1-SCN-01`. The registry becomes **24 GREEN / 6
`ticket_only` / 1 `red_proven`**, leaving **7 hard floors open**. G1 remains
**8.2/10 — NO-GO**; no mechanical score increase is invented. G2/G3 remain
forbidden until the real G1 closure contract is satisfied.
