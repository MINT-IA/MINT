# MINT — Evidence of Tested Controls

**Doctrine:** `2026-05-06-test-theater-post-mortem-doctrine.md` §5 — single source of truth for « tested ».
**Update cadence:** weekly, post-phase-merge. Stale rows (> 30 days without update) flagged AMBER once `tools/checks/evidence_freshness.py` ships (v2.15).

This file is the **journalist + counsel entry point**. Each row links to the artefact that backs the claim. Empty cells = the artefact has not landed yet (Status `PENDING`).

## Active rows

| # | Domain | Artefact | Status | Coverage / Metric | Last Updated | Maintainer |
|---|---|---|---|---|---|---|
| 1 | LSFin / FinSA compliance | [`docs/compliance/CONTROL_MATRIX.md`](compliance/CONTROL_MATRIX.md) | GREEN | 16 GREEN / 0 AMBER / 0 RED / 3 DEFERRED — coverage 1.00 (≥ 0.95 threshold) | 2026-05-07 | Julien |
| 2 | Counsel sign-off | `.planning/compliance/counsel-signoff-2026-05.pdf` (Plan 97-04) | PENDING | — | — | Julien |
| 3 | TestFlight 24h soak | `.planning/phases/97-mvp-ship-gate/sentry-soak-2026-05.png` (Plan 97-02) | PENDING | crash-free ≥ 99.5 % over rolling 24 h | — | Julien |
| 4 | Maestro ship-gate suite | `.planning/phases/97-mvp-ship-gate/maestro-runs/all-*.json` (Plan 97-01) | PENDING | 8 flows × 3 devices = 24 green runs | — | Julien |

## Control matrix coverage script

Run locally before any push that touches `docs/compliance/CONTROL_MATRIX.md`:

```bash
python3 tools/checks/control_matrix_coverage.py --threshold 0.95 --json
```

CI invokes the same gate as a merge-blocking step (see `.github/workflows/ci.yml`).

## Update protocol

After every phase merge:

1. The maintainer (or designated executor) updates the relevant row with the freshest artefact link + status.
2. If a row's artefact is missing, status stays `PENDING` and the row links to the plan that will produce it.
3. Promoting a row from `PENDING` to `GREEN` requires the artefact to exist on disk + a fresh `Last Updated` timestamp.

## Doctrine reference

Per `2026-05-06-test-theater-post-mortem-doctrine.md` §5: « tested means there exists a row in EVIDENCE.md ». The Control Matrix in row 1 is the structured backbone — this file is the executive summary.
