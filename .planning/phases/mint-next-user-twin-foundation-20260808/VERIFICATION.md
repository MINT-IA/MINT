# Verification — Canonical Lifelong User Twin Foundation

Status: `accepted`

## Reviewed receipts

- Runtime candidate: `538c52647e58394be16bc87c68e1e6e814a7613e`.
- Evidence commit: `b36667a69`.
- Receipt: `evidence/housing-lifecycle/runtime.json`.
- Runtime log: `evidence/housing-lifecycle/maestro.log`.
- Five hash-bound screenshots prove create, two cold relaunches, edit, exact
  confirmed delete and deletion surviving another cold relaunch.

The disposable iOS 26.2 simulator ran an ad-hoc signed application. The receipt
records the valid CDHash and contains no host user/path or unrelated device
inventory. A post-run audit observed the disposable UDID absent from `simctl`;
that cleanup observation is independent evidence, not a field in the receipt.
No cloud path was enabled. Candidate commit `538c52647…` pins the runner source.

## Acceptance results

- Every command in the `SPEC.md` verify block: **PASS**.
- Targeted Flutter contract: **30/30 PASS**.
- Signed lifecycle runner and receipt tests: **PASS**.
- Independent exact-receipt roast: **ACCEPT — P1=0, P2=0, P3=0**.
- Runtime SHA, flow SHA, log SHA, screenshot hashes and byte counts match the
  committed receipt. The runner source is transitively pinned by the runtime
  candidate commit; `runtime.json` does not claim a separate runner hash.

## Resolved and superseded findings

- Candidate `cdb12ce64` was rejected after cold relaunch exposed non-durable
  persistence. The canonical encrypted record and reset coordination replaced
  that design before the accepted candidate.
- An earlier Maestro run produced a false positive because it did not require
  the exact confirmation button and dialog dismissal. The accepted flow checks
  both boundaries before testing card absence.
- The first passing receipt exposed excessive simulator inventory. Commit
  `538c52647…` minimized it, then the clean evidence was regenerated and
  independently re-roasted before commit `b36667a69`.

The human promise is met for the bounded housing fact lifecycle. This receipt
does not enable the default-off feature, promote to dev/TestFlight, authorize
cloud sync, or add another housing question.
