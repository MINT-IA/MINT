---
phase: 97-mvp-ship-gate
plan: 03
subsystem: compliance
tags: [finsa, ship-gate, evidence, ci]
requires:
  - .planning/decisions/2026-05-06-test-theater-post-mortem-doctrine.md
  - .planning/decisions/2026-05-02-data-residency.md
provides:
  - docs/compliance/CONTROL_MATRIX.md
  - docs/EVIDENCE.md
  - tools/checks/control_matrix_coverage.py
  - tools/checks/test_control_matrix_coverage.py
  - .github/workflows/ci.yml#control-matrix-coverage
affects:
  - .github/workflows/ci.yml
tech-stack:
  added:
    - Python 3 stdlib (re, dataclasses, argparse, json) — coverage script
    - pytest (existing) — 10-test verification suite
  patterns:
    - "Defensive normalisation of declared Status against anchor + test_id presence (mitigates T-97-03-01 lie-via-Status)"
    - "DEFERRED-excluded-from-denominator coverage formula (Plan 97-03 Decision Option A)"
key-files:
  created:
    - docs/compliance/CONTROL_MATRIX.md
    - docs/EVIDENCE.md
    - tools/checks/control_matrix_coverage.py
    - tools/checks/test_control_matrix_coverage.py
  modified:
    - .github/workflows/ci.yml
decisions:
  - "Hand-curated MD table for v2.14 (Karpathy practice 2 simplicity); auto-aggregated registry deferred to v2.15"
  - "Coverage formula = GREEN / (GREEN + AMBER + RED) — DEFERRED excluded from denominator (Option A)"
  - "Defensive normalisation: empty anchor -> RED, empty test_id -> AMBER, regardless of declared Status"
  - "Data-residency row marked DEFERRED (decision exists, automated test wiring deferred to v2.15) rather than RED-faking it"
metrics:
  duration: ~25 min
  completed: 2026-05-07
---

# Phase 97 Plan 97-03: Compliance Control Matrix Summary

FinSA art. 7 / 8 / 9 / 12 / 13 / 16 mapped to 17 GREEN + 3 DEFERRED control rows backed by real implementation + test anchors, with a stdlib-only Python coverage gate wired into CI as a merge blocker. SHIP-03 closes.

## What shipped

| Artefact | Lines | Purpose |
|---|---|---|
| `docs/compliance/CONTROL_MATRIX.md` | 68 | 20 rows × 8 columns Markdown table — journalist + counsel readable |
| `tools/checks/control_matrix_coverage.py` | 164 | Stdlib parser + coverage formula + threshold gate (CLI + JSON) |
| `tools/checks/test_control_matrix_coverage.py` | 181 | 10 pytest cases (parser, formula, threshold pass/fail, defensive overrides, real matrix, JSON, missing-file) |
| `docs/EVIDENCE.md` | 37 | Single source of truth for « tested » per doctrine §5; row 1 = matrix |
| `.github/workflows/ci.yml` | +29 lines | New `control-matrix-coverage` job + ci-gate wiring |

## Coverage on the shipped matrix

```
FinSA control matrix coverage: 100.00% (target >= 95%)
  GREEN: 17  AMBER: 0  RED: 0  DEFERRED: 3  (total rows: 20)
EXIT 0
```

JSON output:

```json
{
  "matrix": "docs/compliance/CONTROL_MATRIX.md",
  "total_rows": 20,
  "tally": { "GREEN": 17, "AMBER": 0, "RED": 0, "DEFERRED": 3 },
  "coverage": 1.0,
  "threshold": 0.95,
  "pass": true
}
```

## FinSA article coverage breakdown

| Article | Rows | Status |
|---|---|---|
| art. 7 (pre-contractual disclosure) | 2 | 1 GREEN + 1 DEFERRED (cost row deferred to art. 16) |
| art. 8 (information when providing services) | 4 | 4 GREEN |
| art. 9 (information format + timing) | 2 | 2 GREEN |
| art. 12 (suitability + appropriateness) | 4 | 4 GREEN (incl. FATCA gate + 2 negative paths) |
| art. 13 (documentation + accountability) | 4 | 4 GREEN (audit log emit + retention + Sentry release-health) |
| art. 16 (cost transparency) | 1 | DEFERRED (pre-monetization) |
| (operational) | 3 | 2 GREEN (i18n parity, test infra) + 1 DEFERRED (data-residency test wiring v2.15) |

## Tamper-detection dry-run (T-97-03-01 mitigation verified)

Empty an anchor cell on the GREEN `art. 8 al. 1 let. d` row:

```
::error::Coverage 94.12% below threshold 95%
FinSA control matrix coverage: 94.12% (target >= 95%)
  GREEN: 16  AMBER: 0  RED: 1  DEFERRED: 3  (total rows: 20)
EXIT 1
```

Defensive normalisation flips the row to RED → coverage tanks → CI fails. The « lie via Status column » vector is closed.

## pytest suite — 10 GREEN

```
test_parser_extracts_all_rows                 PASSED
test_coverage_excludes_deferred               PASSED
test_threshold_pass_at_exact_ratio            PASSED
test_threshold_fail_below                     PASSED
test_missing_anchor_overrides_to_red          PASSED
test_missing_test_id_overrides_to_amber       PASSED
test_deferred_row_excluded_from_threshold     PASSED
test_shipped_matrix_meets_threshold           PASSED
test_json_output_well_formed                  PASSED
test_missing_matrix_file_exits_one            PASSED
======================== 10 passed, 1 warning in 0.17s =========================
```

Charter required ≥ 6 ; shipped 10.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Anchor file paths corrected against on-branch reality**
- **Found during:** Task 1 anchor SHA resolution
- **Issue:** Plan's `<interfaces>` table referenced future-state paths (e.g. `services/backend/app/coach/fatca_gate.py`, `services/backend/app/db/models/coach_message_audit.py`). Real paths on `feat/phase-A-e2e-unblock` are `services/backend/app/services/coach/fatca_gate.py` and `services/backend/app/models/coach_message_audit.py` (Phase 93 commits already merged into this branch).
- **Fix:** Used `find` + `git log -1 --format=%h -- <real_path>` to resolve actual SHAs. Matrix references real on-disk files; coverage on shipped matrix = 1.00 (not the « may fail until upstream phases close » R2 scenario).
- **Files modified:** `docs/compliance/CONTROL_MATRIX.md`
- **Commit:** part of single atomic commit below

**2. [Rule 2 - Critical functionality] sys.modules registration in test loader**
- **Found during:** Task 2 GREEN run on Python 3.9
- **Issue:** Loading the script via `importlib.util.spec_from_file_location` without registering in `sys.modules` first causes `dataclasses` introspection to crash on Python 3.9 (`__module__.__dict__` AttributeError) when combined with `from __future__ import annotations`.
- **Fix:** Added `sys.modules[name] = mod` before `spec.loader.exec_module(mod)` per Python `importlib.util` docs.
- **Files modified:** `tools/checks/test_control_matrix_coverage.py`

**3. [Rule 1 - Bug] Status auto-correct treats `(compute)` SHA placeholder + dashes as empty**
- **Found during:** Task 2 author-time (defensive)
- **Issue:** Plan said `(compute)` is a Last-Green-Commit placeholder ; if a future row uses `(compute)` / `—` / `-` in anchor or test_id cells (e.g. backfill-pending), `normalise()` should flag AMBER, not silently honor a declared GREEN.
- **Fix:** `_is_empty()` helper expands the « empty » set to `{"", "n/a", "na", "-", "—", "(compute)"}`.
- **Files modified:** `tools/checks/control_matrix_coverage.py`

**4. [Rule 2 - Critical functionality] Wired control-matrix-coverage into ci-gate aggregator**
- **Found during:** ci.yml integration
- **Issue:** Plan's CI snippet was an isolated step appended somewhere ; without wiring into the `ci-gate` job's `needs` array + result tally, a failing matrix gate would not block the merge.
- **Fix:** Added job to `needs:`, added `control_matrix="${{ needs.control-matrix-coverage.result }}"` line, added skipped-pass-through, added to final `if` chain.
- **Files modified:** `.github/workflows/ci.yml`

## Public-repo discipline (per `feedback_public_repo_discipline.md`)

`tools/checks/no_legal_admission_in_public_docs.py --paths docs/compliance/CONTROL_MATRIX.md docs/EVIDENCE.md` → 0 hits. Matrix uses neutral compliance-control phrasing (« no-promise / no-guarantee in financial communication ») not adverse-admission language.

## Threat model — dispositions

| Threat | Disposition | How mitigated |
|---|---|---|
| T-97-03-01 Tampering (lie via Status) | mitigate | `normalise()` autocorrect + tamper dry-run reproduces exit 1 |
| T-97-03-02 Information Disclosure (legal admissions) | mitigate | `no_legal_admission_in_public_docs.py` lint clean on both new docs |
| T-97-03-03 Repudiation (commit SHA tamper) | accept | git-history-anchored, manual cross-check during counsel review |
| T-97-03-04 DoS (script in CI) | accept | < 5 s runtime, stdlib-only |

## Risks reassessed

- **R1 (Last Green Commit backfill):** N/A — all referenced test files exist on `feat/phase-A-e2e-unblock` with real SHAs ; no `(compute)` placeholders remain in shipped matrix.
- **R2 (referenced tests not yet merged):** N/A — Phases 93-94 commits already on this branch ; the only DEFERRED rows are intentional (art. 7 cost / art. 16 / data-residency v2.15).
- **R3 (counsel revisions):** OPEN — Plan 97-04 counsel brief includes the matrix as section (2). Any counsel revisions ride a single follow-up commit on this same Phase 97 PR.

## Self-Check

- File presence:
  - FOUND: docs/compliance/CONTROL_MATRIX.md (68 lines)
  - FOUND: docs/EVIDENCE.md (37 lines)
  - FOUND: tools/checks/control_matrix_coverage.py (164 lines)
  - FOUND: tools/checks/test_control_matrix_coverage.py (181 lines)
  - FOUND: .github/workflows/ci.yml `control-matrix-coverage` job
- Verification commands:
  - `python3 tools/checks/control_matrix_coverage.py --threshold 0.95 --json` → exit 0, coverage 1.0
  - `python3 -m pytest tools/checks/test_control_matrix_coverage.py -v` → 10 passed
  - `python3 tools/checks/no_legal_admission_in_public_docs.py --paths docs/compliance/CONTROL_MATRIX.md docs/EVIDENCE.md` → 0 hits
  - YAML syntax of ci.yml validated via `yaml.safe_load`

## Self-Check: PASSED
