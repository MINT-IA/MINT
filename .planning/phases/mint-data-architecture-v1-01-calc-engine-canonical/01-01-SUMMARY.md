---
phase: mint-data-architecture-v1-01-calc-engine-canonical
plan: 01
subsystem: infra
tags: [prometheus, metrics, regulatory-registry, bundle-size, telemetry, swiss-cantons, gzip, tdd]

# Dependency graph
requires:
  - phase: mint-calc-engine-v1
    provides: "RegulatoryRegistry singleton + version_hash(today) + Plan-17 Prometheus metrics module (mint_calc_invoke_total et al.) — Phase 01 measurement script consumes get_all() + version_hash ; telemetry block appends to the same metrics.py."
provides:
  - "tools/measurement/regulatory_snapshot_bundle_size.py — one-shot D-14 validator (raw_bytes/gzip_bytes/threshold/verdict)."
  - "01-01-BUNDLE-SIZE-REPORT.md — committed evidence artifact citeable by Plan 02 doctrine. Measured 4509 gzip bytes / 95.6% headroom vs 100 KB ceiling."
  - "Three Prometheus telemetry primitives declared (declaration-only, firing in Phase 02) : mint_offline_session_total, mint_l1_only_session_total, mint_constants_staleness_at_render_seconds."
  - "+7 backend tests (3 measurement + 4 telemetry), zero regression."
affects:
  - mint-data-architecture-v1-01-calc-engine-canonical/Plan 02 (doctrine + ADR — cites BUNDLE-SIZE-REPORT.md)
  - mint-data-architecture-v1-01-calc-engine-canonical/Plan 03 (constants snapshot endpoint — reuses same is_active(today) + .to_dict() serialisation)
  - mint-data-architecture-v1-02 (event-log + projection — fires the 3 telemetry primitives client-side)

# Tech tracking
tech-stack:
  added: []  # No new deps ; reuses prometheus_client (Plan 17) + stdlib gzip/json/argparse.
  patterns:
    - "Subprocess-driven measurement script tests with pinned DATABASE_URL env to immunise against pytest-session env pollution."
    - "Backend-side Prometheus declarations carry docstrings naming their Phase-02 firing path + the CONTEXT.md decision they implement."
    - "Phase-01 metrics block prefaced by a Phase-tagged comment so the metrics module reads as a chronologically-stamped append-only log."

key-files:
  created:
    - "tools/measurement/regulatory_snapshot_bundle_size.py"
    - ".planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-01-BUNDLE-SIZE-REPORT.md"
    - "services/backend/tests/test_regulatory_snapshot_bundle_size_measurement.py"
    - "services/backend/tests/test_data_architecture_telemetry_counters.py"
  modified:
    - "services/backend/app/core/metrics.py (appended Phase-01 block + extended __all__)"

key-decisions:
  - "Measurement payload filter aligned with RegulatoryRegistry.version_hash(today) — both call is_active(today) — so the measured bytes correspond exactly to the snapshot hash the future endpoint publishes (codex MEDIUM 'semantic drift' resolved)."
  - "Test coverage invariant is the 27-jurisdiction set (CH + 26 cantons), NOT a brittle param_count >= 100 assertion (codex MEDIUM test-brittleness resolved)."
  - "Telemetry counters declared label-less to forbid high-cardinality user/session tags at firing time (T-mintda-01-02 mitigation)."
  - "Histogram buckets aligned with D-07 thresholds (7d soft / 30d hard) so the data partition matches the UX partition."

patterns-established:
  - "Pattern : pre-flight bundle-size measurement script with --ci JSON + --write-report markdown so the same tool serves CI / lefthook / human ad-hoc."
  - "Pattern : subprocess test env pinning (DATABASE_URL=sqlite:///:memory:) to isolate from full-suite env pollution when the script transitively imports SQLAlchemy."
  - "Pattern : Phase-tagged comment header + reserved __all__ region for chronologically-stamped append-only metrics module."

requirements-completed: [D-14, D-13-telemetry-implication, planner-discretion-bundle-size-methodology, planner-discretion-observability-hooks]

# Metrics
duration: 12min
completed: 2026-05-17
---

# Phase mint-data-architecture-v1-01 Plan 01: Pre-flight measurement + telemetry scaffolding

**D-14 bundle-size measurement script + report (gzip=4509 bytes vs 100 KB ceiling, 95.6% headroom) + 3 Phase-02-firing-ready Prometheus telemetry primitives appended to app/core/metrics.py — zero regression on 7322 baseline.**

## Performance

- **Duration:** 12 min
- **Started:** 2026-05-17T15:21:52Z
- **Completed:** 2026-05-17T15:34:41Z
- **Tasks:** 2 (both TDD, both atomic-commit)
- **Files modified:** 4 created + 1 modified (5 total)

## Accomplishments

- Bundle-size measurement script ships : `tools/measurement/regulatory_snapshot_bundle_size.py --ci` exits 0 / writes JSON with `raw_bytes`, `gzip_bytes`, `threshold_bytes: 102400`, `verdict: PASS`.
- D-14 ceiling held with massive 95.6% headroom : **measured 4509 gzip bytes vs 100 KB ceiling.** The bake-all-26-cantons posture is empirically justified ; D-14 re-litigation trigger NOT fired.
- 27 jurisdictions covered (CH + 26 cantons) verified by automated test ; coverage invariant gates against future jurisdiction-set drift.
- Three Prometheus telemetry primitives declared (declaration-only — Phase 02 wires firing) :
  - `mint_offline_session_total` (Counter, no labels) — D-05 offline-chip rendering.
  - `mint_l1_only_session_total` (Counter, no labels) — denominator for the <2% offline-session re-litigation gate.
  - `mint_constants_staleness_at_render_seconds` (Histogram, buckets 0/1h/1d/7d/14d/30d/60d aligned with D-07).
- Plan-17 counters preserved : regression-guard test confirms `mint_calc_invoke_total`, `mint_cache_lookup_total`, `mint_calc_warm_total`, `mint_zero_citation_total`, `mint_calc_latency_seconds` still importable.
- Full backend suite : **7325 passed, 63 skipped, 3 xfailed, 0 failed** (was 7318 pre-plan ; +7 = 3 measurement + 4 telemetry, as planned).

## Task Commits

Each task was committed atomically (with `--no-verify` per parallel-executor contract) :

1. **Scaffolding (PLAN + REVIEWS into worktree)** — `97b5e513` (docs)
2. **Task 1: Bundle-size measurement script + report + test** — `cb483a62` (feat ; TDD : RED 3/3 fail → GREEN 3/3 pass)
3. **Task 2: Telemetry counters appended to app.core.metrics** — `0c5d36af` (feat ; TDD : RED 3/4 fail → GREEN 4/4 pass)
4. **Rule 1 auto-fix : subprocess env isolation in measurement test** — `0ce23602` (fix ; surfaced during Task 2 full-suite regression run)

## Files Created/Modified

- `tools/measurement/regulatory_snapshot_bundle_size.py` (new, 178 lines) — D-14 validator. `_build_payload(today)` reuses `is_active(today)` semantics matching `RegulatoryRegistry.version_hash(today)`. Exit 0 PASS / 1 FAIL.
- `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-01-BUNDLE-SIZE-REPORT.md` (new, 39 lines) — committed measurement evidence. 4 named sections : ## Methodology / ## Results / ## Verdict / ## Re-litigation trigger. Plan 02 doctrine cites this file.
- `services/backend/tests/test_regulatory_snapshot_bundle_size_measurement.py` (new, 134 lines) — 3 subprocess-driven tests. DATABASE_URL pinned to sqlite:///:memory: in subprocess env to isolate from full-suite pollution.
- `services/backend/tests/test_data_architecture_telemetry_counters.py` (new, 95 lines) — 4 tests : importability, prometheus_client type sanity, Plan-17 regression guard, generate_latest() text exposition.
- `services/backend/app/core/metrics.py` (modified ; +41 lines appended) — Phase-01 block prefaced by header comment, 3 new declarations, `__all__` extended.

## Decisions Made

1. **Measurement payload filter = `is_active(today)` aligned with `version_hash(today)`** — both code paths share the same filter so the measured byte count corresponds exactly to the snapshot version_hash the future `/v1/regulatory/constants/snapshot` endpoint (Plan 03) will publish. Resolves codex MEDIUM "semantic drift" finding from REVIEWS.md.
2. **Coverage invariant = exact 27-jurisdiction set, not param_count** — testing the doctrinal invariant (every canton baked per D-14) instead of a flaky count. Resolves codex MEDIUM "test brittleness on param_count >= 100" finding.
3. **Telemetry counters declared without labels** — forbids high-cardinality user/session tags from being added at firing time. Matches threat model T-mintda-01-02 mitigation. Documented in each counter docstring.
4. **Histogram buckets `(0, 1h, 1d, 7d, 14d, 30d, 60d)`** — 7d and 30d boundaries land exactly on D-07 soft-warn / hard-refuse thresholds so Prometheus partitions the data by the same window Phase 02's UX uses. 1h / 60d are headroom for sanity-check visualisation.
5. **Three commits not two (Task 2 + Rule 1 fix separated)** — Rule 1 auto-fix lives in its own commit `0ce23602` so the history reads cleanly : Task 2 ships the feature, the fix ships the env-pollution mitigation. Both atomic.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Subprocess env pollution breaks measurement test in full pytest suite**
- **Found during:** Task 2 full-suite regression run (`pytest tests/ -q`)
- **Issue:** Some upstream test in the full backend suite mutates `os.environ['DATABASE_URL']` to an unparseable value. The subprocess invoked by `test_regulatory_snapshot_bundle_size_measurement.py` inherits the broken env. The measurement script transitively imports `app.models.user` → `app.core.database` → `create_engine()` which raises `sqlalchemy.exc.ArgumentError: Could not parse SQLAlchemy URL from given URL string` BEFORE any of the script's code runs. Isolated runs pass (3/3) ; full-suite runs fail (3/3) on the same tests.
- **Fix:** Added `env["DATABASE_URL"] = "sqlite:///:memory:"` in `_run_script()` to pin a known-good URL. The measurement script never touches the DB ; the URL only needs to parse for the SQLAlchemy `create_engine()` call at module-import time.
- **Files modified:** `services/backend/tests/test_regulatory_snapshot_bundle_size_measurement.py` (one env-line + 7-line docstring)
- **Verification:** Full backend suite re-run after fix : **7325 passed, 0 failed** (was 7322 passed + 3 failed pre-fix).
- **Committed in:** `0ce23602`

### Codex MEDIUM findings applied inline (from REVIEWS.md)

Per REVIEWS.md recommendation #2 ("brief executor on MEDIUM findings via plan inline notes during execution — surgical adjustments at task level, not full replans"), the following codex concerns were proactively addressed during Task 1 :

- **codex MEDIUM "test brittleness on param_count >= 100"** : replaced with the 27-jurisdiction set invariant. param_count only asserted `> 0`. Documented in test docstring.
- **codex MEDIUM "is_active(today) filter semantic drift vs version_hash()"** : confirmed via Read of `registry.py:1389-1426` that `version_hash(today)` uses the identical `is_active(check_date)` filter. Documented in script docstring + test docstring + bundle-size report Methodology section.
- **codex LOW ">=7268 full-suite pass-count assertion brittle"** : applied — full-suite verification is now a relative `+7 vs pre-plan baseline` claim in commits + SUMMARY, no absolute number in tests.

---

**Total deviations:** 1 auto-fixed (Rule 1 bug — subprocess env pollution)
**Impact on plan:** Surgical fix in test infrastructure ; no production-code change, no scope creep, no architectural drift. Test-isolation pattern is reusable for any future subprocess-driven test that transitively imports the SQLAlchemy engine.

## Issues Encountered

- **Worktree branch base mismatch** : worktree `worktree-agent-a299fdfe0bb440fef` was initialised at commit `255373bb` but orchestrator's expected base is `da11f9e6`. Resolved per `<worktree_branch_check>` protocol via `git rebase --onto da11f9e6 HEAD HEAD` (no destructive `--hard` needed since tree was clean). PLAN.md + REVIEWS.md only existed as untracked files in the parent worktree ; copied them in and committed as scaffolding before per-task work.
- **Write tool writes to absolute path = parent worktree, not subworktree** : noticed after Task 1 RED that my `Write` calls landed in `/Users/julienbattaglia/Desktop/MINT.nosync/...` (parent) instead of `/Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-a299fdfe0bb440fef/...`. Resolved by `cp` into worktree before each commit. Future runs : write directly with the worktree-absolute path.

## User Setup Required

None — no external service configuration required.

## 0-Trust Evidence Receipts (CLAUDE.md §9 protocol)

Each claim above carries a deterministic citation :

| Claim | Evidence |
|---|---|
| Measurement script ships | `commit cb483a62` ; `python3 tools/measurement/regulatory_snapshot_bundle_size.py --ci` exits 0 |
| gzip_bytes = 4509 | stdout JSON `{"gzip_bytes": 4509, ...}` captured 2026-05-17T15:23Z |
| 27-jurisdiction coverage | stdout JSON `cantons_covered` = exact 27-element sorted list |
| 3 Prometheus primitives declared | `grep -c "^mint_offline_session_total = Counter" services/backend/app/core/metrics.py` = 1 (same for `mint_l1_only_session_total` Counter + `mint_constants_staleness_at_render_seconds` Histogram) |
| Plan-17 counters preserved | `test_existing_plan17_counters_still_present` passes in `test_data_architecture_telemetry_counters.py` |
| Full suite 7325 passed | `pytest tests/ -q` output `7325 passed, 63 skipped, 3 xfailed, 1 warning in 117.60s` (after Rule 1 fix) |
| LSFin clean | `python3 tools/checks/banned_terms_python.py services/backend/app/core/metrics.py tools/measurement/regulatory_snapshot_bundle_size.py services/backend/tests/test_data_architecture_telemetry_counters.py services/backend/tests/test_regulatory_snapshot_bundle_size_measurement.py` exit 0 |
| Accent lint clean | `python3 tools/checks/accent_lint_fr.py --scope backend` exit 0 |

Caveats : no Phase-02 firing wired (out of scope) ; no Flutter-side consumption (out of scope) ; no Sim end-to-end check (declaration-only plan, nothing user-visible).

## Next Phase Readiness

- **Plan 02 (doctrine + ADR PR)** UNBLOCKED — can cite `01-01-BUNDLE-SIZE-REPORT.md` for D-14 evidence ("4509 gzip bytes, 95.6% headroom") and can name the 3 telemetry primitives without inventing them.
- **Plan 03 (constants snapshot endpoint)** UNBLOCKED — `_build_payload(today)` in the measurement script is the prototype serialisation pattern ; the endpoint MUST use the same `is_active(today)` + `.to_dict()` + `json.dumps(separators=(",", ":"), sort_keys=True, ensure_ascii=False)` pipeline so the byte-count and the version_hash stay coherent.
- **Phase 02 telemetry wiring** UNBLOCKED — the 3 primitives exist as importable names in `app.core.metrics` ; Phase 02 only needs to `.inc()` / `.observe()` them at the firing sites.
- **No blockers** for downstream plans in this wave.

## Known Stubs

None. All deliverables are wired end-to-end (script runs, report exists, tests pass, lints clean). The telemetry counters are declaration-only by design (Phase 01 scope) — that is not a stub, it is the documented phase boundary per CONTEXT.md.

## Threat Flags

None — no new network endpoints, auth paths, file access patterns, or schema changes introduced. The measurement script is read-only against an in-process registry ; the telemetry declarations carry no labels (forbidding high-cardinality user tags). All threats in the plan's threat_model are addressed.

## Self-Check: PASSED

Files (6/6 found) :
- `tools/measurement/regulatory_snapshot_bundle_size.py`
- `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-01-BUNDLE-SIZE-REPORT.md`
- `services/backend/tests/test_regulatory_snapshot_bundle_size_measurement.py`
- `services/backend/tests/test_data_architecture_telemetry_counters.py`
- `services/backend/app/core/metrics.py`
- `.planning/phases/mint-data-architecture-v1-01-calc-engine-canonical/01-01-SUMMARY.md`

Commits (4/4 found in `git log --all`) : `97b5e513`, `cb483a62`, `0c5d36af`, `0ce23602`.

---
*Phase: mint-data-architecture-v1-01-calc-engine-canonical*
*Plan: 01*
*Completed: 2026-05-17*
