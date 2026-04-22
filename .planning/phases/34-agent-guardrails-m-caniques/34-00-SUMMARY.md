---
phase: 34-agent-guardrails-m-caniques
plan: 00
subsystem: infra
tags: [lefthook, pytest, fixtures, pre-commit, benchmark, schema-migration]

# Dependency graph
requires:
  - phase: 30.5
    provides: skeleton lefthook.yml with memory-retention-gate + map-freshness-hint commands (D-01)
provides:
  - schema-valid lefthook.yml (skip: moved under pre-commit: block per lefthook 2.1.x)
  - baseline P95 benchmark capture (0.120s on skeleton, <<5s budget headroom)
  - tools/checks/lefthook_benchmark.sh reusable by Plan 07 CI regression guard via --assert-p95=5
  - tests/checks/conftest.py pytest scaffolding with fixtures_dir + tmp_git_repo fixtures
  - 26 fixture files under tests/checks/fixtures/ covering all 5 Phase 34 lints (GUARD-02/03/04/05/06)
  - Pitfall 7 exclusion contract documented in lefthook_self_test.sh reminder banner
affects: [34-01, 34-02, 34-03, 34-04, 34-05, 34-06, 34-07]

# Tech tracking
tech-stack:
  added:
    - lefthook 2.1.5+ schema migration (skip: nested)
    - pytest conftest.py module for Phase 34 lint tests
  patterns:
    - P95 benchmark via /usr/bin/time -p + warmup discard + Python stdlib sort
    - fixture-as-data pytest pattern (Path-based, no subprocess needed for Python lints)
    - lint exclude: contract documented in self-test (future-proofs against Pitfall 7 self-regression)

key-files:
  created:
    - tools/checks/lefthook_benchmark.sh
    - tests/checks/conftest.py
    - tests/checks/__init__.py
    - tests/checks/fixtures/__init__.py
    - tests/checks/fixtures/bare_catch_bad.dart
    - tests/checks/fixtures/bare_catch_good.dart
    - tests/checks/fixtures/bare_catch_bad.py
    - tests/checks/fixtures/bare_catch_good.py
    - tests/checks/fixtures/async_star_exempt.dart
    - tests/checks/fixtures/hardcoded_fr_bad_widget.dart
    - tests/checks/fixtures/hardcoded_fr_good_widget.dart
    - tests/checks/fixtures/accent_bad.dart
    - tests/checks/fixtures/accent_good.dart
    - tests/checks/fixtures/arb_parity_pass/app_{fr,en,de,es,it,pt}.arb (6 files)
    - tests/checks/fixtures/arb_drift_missing/app_{fr,en,de,es,it,pt}.arb (6 files)
    - tests/checks/fixtures/arb_drift_placeholder/app_{fr,en}.arb (2 files)
    - tests/checks/fixtures/commit_with_read_trailer.txt
    - tests/checks/fixtures/commit_without_read_trailer.txt
    - tests/checks/fixtures/commit_human_no_claude.txt
  modified:
    - lefthook.yml (schema migration: skip: nested under pre-commit:)
    - tools/checks/lefthook_self_test.sh (Pitfall 7 reminder banner appended)

key-decisions:
  - "Schema migration preserves 30.5 skeleton verbatim (memory-retention-gate + map-freshness-hint), only topology changes"
  - "parallel: false maintained in Wave 0 — Plan 02 flips to true once no-bare-catch (read-only lint) lands per RESEARCH Pattern 6"
  - "Baseline P95 captured empirically (0.120s) before ANY Phase 34 lint added — Plan 07 regression delta is now measurable against a real number, not a moving target"
  - "Fixtures live under tests/checks/fixtures/ (not tools/checks/fixtures/) so future lint exclude: lists use single glob tests/checks/fixtures/** (T-34-07 mitigation)"
  - "commit-msg fixtures created in Wave 0 (even though GUARD-06 is Plan 34-05 scope per D-27 amendment) — single fixture write, multiple plan consumers"

patterns-established:
  - "Pattern A — P95 benchmark idiom: /usr/bin/time -p <cmd> 2>>log + warmup discard + Python stdlib sort. Reusable for any hook budget guard."
  - "Pattern B — Pytest fixture for diff-only lints: tmp_git_repo factory in conftest.py lets GUARD-02 diff tests run without touching the main repo's git state."
  - "Pattern C — Fixture exclusion contract: every new lint in subsequent plans MUST add tests/checks/fixtures/** to its lefthook exclude: — documented in self-test banner as a reminder."

requirements-completed: [GUARD-01]

# Metrics
duration: ~10min
completed: 2026-04-22
---

# Phase 34 Plan 00: Wave 0 Schema Fix + Benchmark + Fixture Tree Summary

**lefthook.yml schema migrated (skip: nested under pre-commit:), baseline P95 captured at 0.120s, and 26 fixture files landed across 5 GUARD contracts to unblock Waves 1-4.**

## Performance

- **Duration:** ~10 min (Task 1 commit 19:57:01 UTC, Task 2 commit 20:00:34 UTC, SUMMARY ~20:01 UTC)
- **Started:** 2026-04-22T19:51:00Z (approx — context load + initial read)
- **Completed:** 2026-04-22T20:01:10Z
- **Tasks:** 2/2 auto (no checkpoints)
- **Files created:** 28 (1 benchmark script + 1 conftest + 2 __init__.py + 5 bare-catch/accent fixtures + 2 hardcoded_fr fixtures + 14 ARB fixtures + 3 commit-msg fixtures)
- **Files modified:** 2 (lefthook.yml schema migration, lefthook_self_test.sh banner append)

## Accomplishments

- **A7 blocker unblocked (RESEARCH.md Pattern 1):** `lefthook validate` returns "All good" (exit 0) — was previously failing with `skip: Value is array but should be object` → would have silently broken Plan 07 CI invocations.
- **Baseline P95 captured empirically: 0.120s** (over 8 runs after 2-run warmup discard). Far below the 5s budget. Plan 07 will enforce `--assert-p95=5` against this measurable baseline, not a moving target.
- **26 fixture files land atomically** covering all 5 Phase 34 lint contracts: 5 bare-catch fixtures (Dart/Python bad+good + async* exemption), 2 hardcoded-fr widget fixtures, 2 accent fixtures, 14 ARB fixtures across 3 parity scenarios (clean / missing-key / placeholder-mismatch), 3 commit-msg fixtures (Claude+Read / Claude-only / human-only).
- **30.5 skeleton preserved end-to-end:** memory-retention-gate + map-freshness-hint still present and still fire on `lefthook run pre-commit --all-files` (verified both via direct invocation and via Task 1 commit which passed through the hook).
- **Pitfall 7 contract documented:** lefthook_self_test.sh now prints a 3-line reminder that every new lint in subsequent plans must add `tests/checks/fixtures/**` to its `exclude:` list.

## Task Commits

Each task was committed atomically on `feature/S30.7-tools-deterministes`:

1. **Task 1: lefthook.yml schema fix + benchmark scaffold** — `59c8b1a8` (fix)
   - Files: `lefthook.yml`, `tools/checks/lefthook_benchmark.sh`
   - 77 insertions, 17 deletions
   - Verified: `lefthook validate` exits 0, `lefthook run pre-commit --all-files` exits 0, benchmark exits 0 with P95 readout.

2. **Task 2: Wave 0 fixture tree + conftest.py + self-test reminder** — `5a8ffb33` (feat)
   - Files: 26 new fixtures + `tests/checks/conftest.py` + 2 `__init__.py` + `tools/checks/lefthook_self_test.sh`
   - Verified: 12/12 ARB fixtures parse as valid JSON, de missing `goodbye` in drift_missing confirmed, pytest collects clean (18 tests from Phase 32 still green, conftest.py importable).

## Files Created/Modified

### lefthook.yml — schema migration

**Before (broken, `lefthook validate` rejected):**
```yaml
min_version: 2.1.5
pre-commit:
  parallel: false
  commands:
    memory-retention-gate: ...
    map-freshness-hint: ...
skip:              # top-level — rejected by 2.1.x as "Value is array but should be object"
  - merge
  - rebase
```

**After (schema-valid, `lefthook validate` → "All good"):**
```yaml
min_version: 2.1.5

pre-commit:
  parallel: false
  skip:            # nested under pre-commit: per lefthook 2.1.x schema
    - merge
    - rebase
  commands:
    memory-retention-gate:
      run: python3 tools/checks/memory_retention.py
      tags: [memory, phase-30.5]
    map-freshness-hint:
      run: python3 tools/checks/map_freshness_hint.py {staged_files}
      glob: "*.{dart,py}"
      tags: [map, agents]
```

### tools/checks/lefthook_benchmark.sh (new, executable)

Measures `lefthook run pre-commit` over 10 iterations, discards first 2 (warmup per Pitfall 10 — cold cache + Python import init), reports P95 of last 8. Optional `--assert-p95=<N>` flag for CI regression guard (Plan 07 consumer). Python 3.9-compat stdlib parsing (no numpy). portable `/usr/bin/time -p` wrapper (macOS + Linux).

### tests/checks/ tree

```
tests/checks/
├── __init__.py
├── conftest.py                          # pytest fixtures: fixtures_dir, tmp_git_repo
└── fixtures/
    ├── __init__.py
    ├── accent_bad.dart                  # 'creer un compte et decouvrir la securite'
    ├── accent_good.dart                 # 'créer un compte et découvrir la sécurité'
    ├── arb_drift_missing/
    │   ├── app_de.arb                   # missing 'goodbye' (drift scenario)
    │   ├── app_en.arb, app_es.arb, app_fr.arb, app_it.arb, app_pt.arb
    ├── arb_drift_placeholder/
    │   ├── app_fr.arb                   # declares 'name' placeholder
    │   └── app_en.arb                   # uses '{n}' — type mismatch
    ├── arb_parity_pass/
    │   └── app_{fr,en,de,es,it,pt}.arb  # 6 parity-clean files
    ├── async_star_exempt.dart           # async* generator + bare catch (D-06 exempt)
    ├── bare_catch_bad.dart              # } catch (e) {}
    ├── bare_catch_bad.py                # except Exception: pass
    ├── bare_catch_good.dart             # catch + Sentry.captureException + rethrow
    ├── bare_catch_good.py               # except + logger.error + raise
    ├── commit_human_no_claude.txt       # no Co-Authored-By (human commit bypass)
    ├── commit_with_read_trailer.txt     # Claude + Read: trailer
    ├── commit_without_read_trailer.txt  # Claude but no Read: trailer
    ├── hardcoded_fr_bad_widget.dart     # Text('Bonjour tout le monde')
    └── hardcoded_fr_good_widget.dart    # AppLocalizations.of(context)!.greeting + inline override demo
```

**Count:** 26 fixture files + 1 conftest + 2 __init__.py = 29 files under `tests/checks/`.

### tools/checks/lefthook_self_test.sh — reminder banner

Appended 3 lines before `exit 0`:
```
self-test: reminder — Phase 34 fixtures under tests/checks/fixtures/ must be
  added to each new lint's lefthook 'exclude:' list (per Pitfall 7).
  This self-test still only exercises the 30.5 retention gate.
```

## Baseline Benchmark (critical for Plan 07 regression check)

**Measurement:** `bash tools/checks/lefthook_benchmark.sh` — two runs performed during execution.

| Run | P95 (s) | Context |
|-----|---------|---------|
| Run 1 (Task 1 verification) | **0.110s** | Clean working tree, only skeleton commands active |
| Run 2 (Wave 0 final) | **0.120s** | After fixtures staged (skeleton still the only commands firing) |

**Baseline P95 for Plan 07:** ~0.12s (call it 0.15s with measurement noise buffer).

**Budget headroom:** 5.00s - 0.12s = **4.88s available** for 5 Phase 34 lints to be added in Plans 01-05. Assuming equal apportionment ≈ 0.98s per lint — comfortable per RESEARCH Pattern 5/6 estimates (regex lints ~100-500ms each on typical diff).

**No P95 red flag.** Hardware/disk I/O is healthy.

## `lefthook validate` Output

```
$ lefthook validate
All good
$ echo $?
0
```

(Was previously: `skip: Value is array but should be object │  Error: validation failed for main config`.)

## 30.5 Skeleton Regression Check

```
$ bash tools/checks/lefthook_self_test.sh
...
┃  memory-retention-gate ❯
retention: FAIL — 1 non-whitelisted file(s) in topics/ have mtime >30d and are not archived:
  .../stalenote_lefthook_selftest_31d.md (31.0d old)
  -> Run: python3 tools/memory/gc.py

exit status 1
self-test: OK — lefthook caught the stale fixture as expected (exit 1)
self-test: reminder — Phase 34 fixtures under tests/checks/fixtures/ must be
  added to each new lint's lefthook 'exclude:' list (per Pitfall 7).
  This self-test still only exercises the 30.5 retention gate.
$ echo $?
0
```

Gate still fires correctly — no 30.5 regression introduced.

## Per-Decision Coverage

| Decision | Status | Evidence |
|----------|--------|----------|
| D-01 (skeleton preserved) | ✓ | `grep -c` on config body: memory-retention-gate=1, map-freshness-hint=1 |
| D-04 (min_version 2.1.5) | ✓ | `grep -c "min_version: 2.1.5" lefthook.yml` = 1 |
| D-25 (self-test extension) | partial — reminder banner landed | self-test prints new 3-line banner; per-lint FAIL/PASS cases deferred to Plans 01-05 as planned |
| D-26 (benchmark <5s) | ✓ | Baseline 0.120s captured, <<5s. Script reusable via `--assert-p95=5` in Plan 07. |
| D-27 (commit-msg fixtures) | ✓ | 3 commit-msg fixtures landed in Wave 0 even though GUARD-06 is Plan 05 scope — one fixture write, multiple plan consumers. |
| A7 (RESEARCH — schema fix unblock) | ✓ | `lefthook validate` exits 0 (was exit 1 pre-Task-1) |
| A10 (map-freshness-hint preserved) | ✓ | Still in config body, still fires on --all-files run |

## Decisions Made

None beyond what PLAN.md specified. Two small editorial choices within Claude's discretion:

1. **Fixture set 3 (`arb_drift_placeholder/`) sized at 2 files**, not 6, because the placeholder-mismatch test only needs fr (template with declaration) + en (drift with wrong placeholder name). Wasteful to generate 4 more locales of identical mismatched shape. Matches plan's explicit "only 2 files needed" guidance.

2. **Trust the commit-msg fixtures to Wave 0** rather than deferring to Plan 34-05. Single atomic fixture landing > fragmented per-plan additions. D-27 amendment confirms Plan 34-05 reads commit-msg at commit-msg hook time, but the fixtures themselves are passive test data — harmless to land early.

## Deviations from Plan

None - plan executed exactly as written. All acceptance criteria per Task 1 + Task 2 met. Full-plan verification green across V1-V6.

## Issues Encountered

**Issue:** When running `lefthook run pre-commit` without `--all-files`, `memory-retention-gate` reports "(skip) no matching staged files" (because no files were staged for the plain dry-run).

**Resolution:** Verified behaviour is correct by running `lefthook run pre-commit --all-files` which forces the gate to execute — it returns "retention: OK — 30j gate green" (exit 0). The hook is correctly wired; the skip behaviour is per-lefthook filter design (no-files → no-op). Task 1 commit itself passed through the hook with the gate firing on the staged lefthook.yml + benchmark.sh files (visible in commit output).

No unplanned work required. Pre-existing `tests/checks/ 2/` and `tests/checks/fixtures/ 2/` iCloud duplicate directories (flagged in CONTEXT §Duplicates-to-watch) were deliberately NOT touched — out of scope per plan cleanup disclaimer.

## User Setup Required

None — all changes are repo-local scaffolding. No external services, no env vars, no secrets. Lefthook already installed per Phase 30.5 onboarding (version 2.1.6 on dev box, min_version: 2.1.5 in config).

## Next Phase Readiness

**Wave 0 unblocks Waves 1-4 per 34-VALIDATION.md:**
- Plan 34-01 (GUARD-04 accent_lint activation) can now reference `tests/checks/fixtures/accent_{bad,good}.dart` in its pytest.
- Plan 34-02 (GUARD-02 no_bare_catch Dart+Python) has all 5 fixtures it needs (2 bad + 2 good + async_star_exempt).
- Plan 34-03 (GUARD-03 no_hardcoded_fr) has widget bad+good with inline override example.
- Plan 34-04 (GUARD-05 arb_parity) has 14 ARB fixtures across 3 scenarios.
- Plan 34-05 (GUARD-06 proof_of_read, D-27 commit-msg hook) has 3 commit-msg fixtures.
- Plan 34-07 (CI thinning) can invoke `bash tools/checks/lefthook_benchmark.sh --assert-p95=5` against the 0.120s baseline captured here.

**No blockers. No concerns.** Every success criterion in PLAN.md `<success_criteria>` is true as of this commit.

## Self-Check: PASSED

**Files verified on disk:**
- FOUND: lefthook.yml (schema-valid per `lefthook validate`)
- FOUND: tools/checks/lefthook_benchmark.sh (executable bit set)
- FOUND: tests/checks/conftest.py (importable per `pytest --collect-only`)
- FOUND: tests/checks/fixtures/ (18 entries, 26 fixture files + 2 __init__.py)
- FOUND: tests/checks/fixtures/arb_parity_pass/ (6 files, all valid JSON)
- FOUND: tests/checks/fixtures/arb_drift_missing/ (6 files, all valid JSON, de missing `goodbye` confirmed)
- FOUND: tests/checks/fixtures/arb_drift_placeholder/ (2 files, all valid JSON)
- FOUND: 3 commit-msg .txt fixtures
- FOUND: 2 accent fixtures, 2 hardcoded-fr fixtures, 5 bare-catch fixtures (incl. async_star_exempt)

**Commits verified:**
- FOUND: `59c8b1a8` — fix(34-00): lefthook.yml schema + Wave 0 benchmark scaffold
- FOUND: `5a8ffb33` — feat(34-00): Wave 0 fixture tree + conftest.py + self-test reminder

---
*Phase: 34-agent-guardrails-m-caniques*
*Plan: 00*
*Completed: 2026-04-22*
