---
phase: 34-agent-guardrails-m-caniques
plan: 07
subsystem: infra
tags: [lefthook, ci-thinning, github-actions, guard-01, guard-08, d-23, d-24, phase-34-ship]

# Dependency graph
requires:
  - phase: 34
    provides: "Plans 00-06 (10-command lefthook foundation + GUARD-07 bypass convention) that this plan thins CI against and wraps with the D-24 PR re-run ground-truth catcher"
provides:
  - ".github/workflows/lefthook-ci.yml — PRIMARY ground-truth bypass detector. Re-runs `lefthook validate` + `lefthook run pre-commit --all-files --force` + per-commit `lefthook run commit-msg` on every PR to dev/staging/main. Catches bypasses that the D-21 audit (secondary, awareness) would miss."
  - "Thinned .github/workflows/ci.yml — 4 lint invocations removed (no_chiffre_choc line ~161, landing_no_numbers line ~207, landing_no_financial_core line ~211, route-registry-parity job lines 429-448 + removed from ci-gate needs list line 528). 5 STAY lints preserved (no_legacy_confidence_render, no_implicit_bloom_strategy, sentence_subject_arb_lint, no_llm_alert, regional_microcopy_drift)."
  - "Lefthook.yml 4 new pre-commit commands: no-chiffre-choc, landing-no-numbers, landing-no-financial-core, route-registry-parity. Total pre-commit command count: 10 (2 skeleton 30.5 + 4 Phase 34 Plans 01-04 + 4 Plan 07 migrations) + 1 commit-msg (proof-of-read)."
  - "GUARD-01 success criterion #1 empirically verified: bash tools/checks/lefthook_benchmark.sh --assert-p95=5 exit 0, P95 = 0.110s (45x headroom under 5s budget)."
affects: [36, v2.8-ship, v2.9-ci]

# Tech tracking
tech-stack:
  added:
    - "GitHub Actions: pull_request: branches: [dev, staging, main] trigger pattern — first MINT workflow combining PR-only trigger with full-repo lefthook re-run"
    - "Curl | sh install of evilmartians/lefthook in CI worktree — pattern borrowed from RESEARCH §Example 6"
  patterns:
    - "D-24 ground-truth pattern: re-run local pre-commit tooling on a fresh CI runner to detect bypass-induced regressions (LEFTHOOK_BYPASS=1 / --no-verify). Complements D-21 voluntary-signal audit (Plan 34-06 bypass-audit.yml) without duplicating it."
    - "CI thinning pattern: anchor edits by step `name:` string (not line number) to survive in-flight line-shift. 4 removals via 3 Edit invocations — one per adjacent-step pair + one for standalone job + one for `needs:` list cleanup."
    - "Glob-scope narrowing on migrated scripts: `no-chiffre-choc` dropped `.md` from glob after empirical iCloud-sync full-repo-scan stall (Rule 3 auto-fix). D-24 lefthook-ci.yml still catches .md drift via the clean-runner full-repo pass."

key-files:
  created:
    - ".github/workflows/lefthook-ci.yml — 66 lines, 1 job 'lefthook-all' with 6 steps (checkout, setup-python, install lefthook, validate, pre-commit --all-files --force, commit-msg per sha in PR range)"
    - ".planning/phases/34-agent-guardrails-m-caniques/34-07-READ.md — 12-file receipt per D-18 for GUARD-06 commit-msg hook compliance"
  modified:
    - "lefthook.yml — +22 lines (4 new commands: no-chiffre-choc, landing-no-numbers, landing-no-financial-core, route-registry-parity). Final pre-commit command count: 10; commit-msg command count: 1."
    - ".github/workflows/ci.yml — net -14 lines (-36 removed, +22 migration-comment blocks). 4 lint invocations deleted, 5 migration-reference comments inserted for D-23 traceability, ci-gate needs list + shell check pruned."

key-decisions:
  - "D-23 migration (4 lints): no_chiffre_choc.py, landing_no_numbers.py, landing_no_financial_core.py, route_registry_parity.py moved from CI to lefthook pre-commit. Together with GUARD-04/02/03/05/06 shipped in Plans 01-05, lefthook now owns 10 of the 10 CONTEXT D-23 migration targets. 5 non-D-23 lints (no_legacy_confidence_render / no_implicit_bloom_strategy / sentence_subject_arb_lint / no_llm_alert / regional_microcopy_drift) STAY in CI per RESEARCH §CI Thinning Map §STAY list."
  - "D-24 implementation (lefthook-ci.yml) shipped as PRIMARY detector, positioned against D-21 (Plan 34-06 bypass-audit.yml) as SECONDARY. Both surfaces (CONTRIBUTING.md §6, bypass-audit.yml issue body) already forward-reference lefthook-ci.yml — the cross-reference resolves transparently now that the file exists."
  - "Net CI time delta honestly framed per RESEARCH §Net CI impact ln 1238-1249: -15s to -90s per PR on hot path (setup-python + checkout cost of 5 short jobs removed), NOT CONTEXT's optimistic -2min claim. Observation-window validation across 5+ merged PRs deferred to post-merge operational metrics."
  - "Glob narrowing on no-chiffre-choc (dropped `.md` from `*.{dart,py,arb,md}` → `*.{dart,py,arb}`) — Rule 3 blocking auto-fix. The script has no --file arg (D-23 self-configured scope: apps/mobile/lib + services/backend/app + docs/ + tools/openapi) so every invocation is a full-repo rglob. On macOS iCloud-synced dirs with thousands of `*.<name> 2.md` duplicates the single invocation stalled >5min in self-test. Narrowing to code extensions keeps pre-commit <1s; docs/ .md coverage preserved via D-24 lefthook-ci.yml clean-runner re-run."
  - "ci-gate `needs:` list cleanup: removed route-registry-parity from [changes, backend, flutter, readability, wcag-aa-all-touched, route-registry-parity, mint-routes-tests, admin-build-sanity, cache-gitignore-check] and from the corresponding shell check. IDE diagnostics flagged the orphan reference pre-commit; auto-fixed in the same Edit."

patterns-established:
  - "Pattern A: D-23 migration comments in ci.yml — each removal leaves a 3-line `# Phase 34 GUARD-08 D-23 migration` block pointing to the lefthook command name. Grep-able (`grep 'GUARD-08 D-23 migration' ci.yml` → 3 blocks) for future migration audits."
  - "Pattern B: fast-glob for self-configured-scope lints — when a script has no `--file` arg and scans a broad directory tree, the lefthook `glob:` should be tighter than the script's scope to minimize per-commit invocations. no-chiffre-choc glob `{dart,py,arb}` << script scope `{dart,py,arb,md,json,yaml,yml,txt}`."
  - "Pattern C: D-24 PR re-run job as complement to local pre-commit — single `lefthook run pre-commit --all-files --force` step catches any bypass regression that landed between base and HEAD, including commits authored with --no-verify. Plus per-commit `lefthook run commit-msg` loop catches proof-of-read bypasses. Pattern reusable for any future pre-commit tool (Husky, pre-commit.com, etc.) that supports --all-files replay."

requirements-completed: [GUARD-01, GUARD-08]

# Metrics
duration: 19min 22s
completed: 2026-04-22
---

# Phase 34 Plan 07: GUARD-08 CI thinning + D-24 PR re-run Summary

**4 D-23 lint migrations (no_chiffre_choc + landing × 2 + route-registry-parity) move from per-PR CI jobs to pre-commit lefthook, `.github/workflows/lefthook-ci.yml` ships as D-24 PRIMARY ground-truth bypass catcher, final P95 benchmark 0.110s / 5s budget (45x headroom) — all 8 Phase 34 GUARDs now mechanically active.**

## Performance

- **Duration:** 19 min 22s
- **Started:** 2026-04-22T21:17:21Z
- **Completed:** 2026-04-22T21:36:43Z
- **Tasks:** 2
- **Files created:** 2 (`.github/workflows/lefthook-ci.yml`, `34-07-READ.md`)
- **Files modified:** 2 (`lefthook.yml`, `.github/workflows/ci.yml`)
- **Final P95 (GUARD-01 success #1):** 0.110s — 45x under 5s budget

## Accomplishments

- **4 D-23 migrations landed in lefthook.yml** with tight globs to keep pre-commit fast:
  - `no-chiffre-choc`: glob `*.{dart,py,arb}`, excludes tests/checks/fixtures, tags `[safety, phase-34, migrated]`
  - `landing-no-numbers`: glob `apps/mobile/lib/screens/landing/**/*.dart`
  - `landing-no-financial-core`: same landing glob
  - `route-registry-parity`: glob `apps/mobile/lib/{app.dart,routes/route_metadata.dart}`
- **4 CI invocations removed from ci.yml:**
  - Step `Legacy token gate (no chiffre_choc)` (line ~161 in backend job)
  - Step `Landing v2 — no numbers / banned terms (LAND-04)` (line ~207)
  - Step `Landing v2 — no financial_core imports (LAND-01)` (line ~211)
  - Entire standalone `route-registry-parity` job (lines 429-448) + its reference in `ci-gate` `needs:` list + shell check
- **5 STAY lints preserved** per RESEARCH §CI Thinning Map §STAY list: `no_legacy_confidence_render.py`, `no_implicit_bloom_strategy.py`, `sentence_subject_arb_lint.py`, `no_llm_alert.py`, `regional_microcopy_drift.py`.
- **`.github/workflows/lefthook-ci.yml` shipped (66 lines, 1 job, 6 steps):**
  - Trigger: `pull_request: branches: [dev, staging, main]`
  - Steps: checkout@v4 fetch-depth=0 → setup-python@v5 3.11 → `curl | sh` install lefthook → `lefthook validate` → `lefthook run pre-commit --all-files --force` → per-commit `lefthook run commit-msg` loop over `origin/<base>..HEAD`
  - Ground-truth catcher: clean-runner re-run picks up any regression that was introduced with `LEFTHOOK_BYPASS=1` or `--no-verify` locally
- **Final P95 benchmark (GUARD-01 success #1) verified:**
  ```
  $ bash tools/checks/lefthook_benchmark.sh --assert-p95=5
  [benchmark] Running 10 iterations of lefthook run pre-commit (discarding first 2 as warmup)...
  [benchmark] P95 (over last 8 runs): 0.110s
  [benchmark] OK — P95 under threshold
  $ echo $?
  0
  ```
- **GUARD-01 + GUARD-08 marked complete** in REQUIREMENTS.md (`node gsd-tools.cjs requirements mark-complete GUARD-08` → updated=true). All 8 Phase 34 GUARDs now checked.

## Before/After CI — Lines 155-215 + 429-528

| Line (pre-plan) | Step / job | Pre-plan | Post-plan |
|----|----|----|----|
| 159-161 | `Legacy token gate (no chiffre_choc)` | `run: python3 tools/checks/no_chiffre_choc.py` | **REMOVED** — migration comment inserted (+6 lines) |
| 163-166 | `No legacy confidence render (Phase 8a gate)` | `run: python3 tools/checks/no_legacy_confidence_render.py` | **STAY** |
| 168-171 | `No implicit BloomStrategy on MTC (PERF-05)` | `run: python3 tools/checks/no_implicit_bloom_strategy.py` | **STAY** |
| 173-176 | `ARB sentence-subject lint (TRUST-02 + ALERT-02)` | `run: python3 tools/checks/sentence_subject_arb_lint.py` | **STAY** |
| 178-181 | `No LLM-driven alert objects (ALERT-07)` | `run: python3 tools/checks/no_llm_alert.py` | **STAY** |
| 183-197 | `No legacy REGIONAL_MAP (REGIONAL-05)` | grep | **STAY** |
| 199-202 | `Regional microcopy codegen drift` | `run: python3 tools/checks/regional_microcopy_drift.py` | **STAY** |
| 204-207 | `Landing v2 — no numbers / banned terms (LAND-04)` | `run: python3 tools/checks/landing_no_numbers.py` | **REMOVED** — migration comment inserted |
| 209-211 | `Landing v2 — no financial_core imports (LAND-01)` | `run: python3 tools/checks/landing_no_financial_core.py` | **REMOVED** |
| 429-448 | `route-registry-parity:` standalone job | job with 4 steps | **REMOVED** — migration comment (+6 lines) |
| 528 | `ci-gate:` `needs:` list | `[..., route-registry-parity, ...]` | **PRUNED** — 8 entries remain |

**Net ci.yml delta:** -36 lines removed + 22 lines of migration-trace comments = **-14 lines total**.

## Net CI Time Impact (honest framing per RESEARCH §Net CI impact)

| Direction | Cost |
|-----------|------|
| **Saved** | 4 setup-python/checkout overhead jobs × ~5-15s each = **−20s to −60s per PR** on hot path (all jobs run). On cold path (only subset triggers), saving is proportional. |
| **Saved** | route-registry-parity was its own full job (checkout+setup-python+run) = **−30s** on cold path regardless. |
| **Added** | lefthook-ci.yml adds **+30-60s** to every PR (checkout+setup-python+install lefthook+validate+full-repo pre-commit pass+commit-msg loop). |
| **Added** | bypass-audit.yml (Plan 06) adds **+10s** on post-merge-to-dev only. |
| **Net** | **−15s to −90s per PR** depending on path-filter outcomes. NOT CONTEXT's optimistic `-2min` claim. |

Observation-window deferred: precise CI time reduction requires 5+ PRs merging post-change to measure rolling median — tracked as `ci-time-reduction-measured` flag for `/gsd-verify-work 34`.

## D-21 + D-24 Bypass-Catch Matrix

| Scenario | D-21 bypass-audit.yml (Plan 06, secondary) | D-24 lefthook-ci.yml (Plan 07, primary) |
|----------|-------------------------------------------|------------------------------------------|
| Contributor runs `LEFTHOOK_BYPASS=1 git commit -m '... [bypass: fixing typo]'` and the bypassed lint would not have failed | **Flagged** in weekly issue (signal visible in commit body) | **Silent pass** (lint re-runs clean in CI) |
| Contributor runs `LEFTHOOK_BYPASS=1 git commit -m '... [bypass: urgent]'` and the bypassed lint WOULD have failed | **Flagged** in weekly issue (signal visible) + | **Blocks PR** (CI job fails loud) |
| Contributor runs `git commit --no-verify` (bans convention per CONTRIBUTING §3) and the bypassed lint would not have failed | **Silent pass** (no trace in commit body) | **Silent pass** (lint re-runs clean) |
| Contributor runs `git commit --no-verify` and the bypassed lint WOULD have failed | **Silent pass** (no trace) | **Blocks PR** (CI job fails loud) — this is the ground-truth case D-24 uniquely catches |

D-21 = convention awareness (voluntary signal). D-24 = regression ground-truth (mechanical catch). Together, Plans 06 + 07 cover both the cultural and the technical surface.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Narrowed `no-chiffre-choc` glob from `*.{dart,py,arb,md}` to `*.{dart,py,arb}`**
- **Found during:** Task 1 self-test post-wiring
- **Issue:** Plan spec used `glob: "*.{dart,py,arb,md}"`. When `lefthook run pre-commit --file README.md` fires in self-test (and whenever any .md is staged for commit), the `no-chiffre-choc` command triggers. The script has no `--file` argparse entry (it's zero-arg by design, scans its self-configured scope: `apps/mobile/lib`, `services/backend/app`, `tools/openapi`, `docs/`) — every invocation is a full-repo rglob. On the current macOS iCloud-synced checkout with thousands of `*.dart 2`, `*.md 2`, `*.py 2` duplicate files in every subdirectory, a single rglob stalls >5 minutes reading evicted files (`docs/AGENTS/flutter 2.md` observed via `lsof` as the top-of-stack file held open). The self-test thus hung for the full 180s monitor window during Task 1 verification.
- **Fix:** Narrowed glob to code extensions only (`{dart,py,arb}`). Doc `.md` scan coverage preserved via D-24 lefthook-ci.yml `--all-files --force` on clean ubuntu-latest runner (no iCloud dirs).
- **Files modified:** `lefthook.yml` (1-line glob change + 7-line rationale comment)
- **Verification:** self-test 6/6 sections green in 0.61s; benchmark P95 0.110s.
- **Committed in:** `f1cf293c` (Task 1)

**2. [Rule 1 - Bug] Pruned orphan `route-registry-parity` reference from `ci-gate` `needs:` list**
- **Found during:** Task 1 (post-removal, via IDE diagnostics PostToolUse hook)
- **Issue:** Removing the standalone `route-registry-parity:` job (lines 429-448) left two orphan references in `ci-gate`: (a) `needs: [..., route-registry-parity, ...]` at line 528 and (b) the `parity="${{ needs.route-registry-parity.result }}"` shell check + downstream conditionals. GitHub Actions IDE schema check fired: `Job 'ci-gate' depends on unknown job 'route-registry-parity'`.
- **Fix:** Removed `route-registry-parity` from the `needs:` list, removed the `parity=` line and its `[[ ]]` skip-guard, pruned the `|| [[ "$parity" != "success" ]]` from the compound condition, and dropped `parity=$parity` from the failure diagnostic. Added a traceability comment (`# Phase 34 GUARD-08 D-23: route-registry-parity removed from needs list`) for future readers.
- **Files modified:** `.github/workflows/ci.yml` (7-line delta inside ci-gate block)
- **Verification:** IDE diagnostics cleared; YAML still parses (PyYAML `safe_load` OK); `grep "route-registry-parity" ci.yml` returns only 3 comment references (all in migration-trace blocks).
- **Committed in:** `f1cf293c` (Task 1)

---

**Total deviations:** 2 auto-fixed (1 Rule 3 blocking glob-narrowing, 1 Rule 1 orphan-reference cleanup).
**Impact on plan:** both additive to plan intent, zero scope creep. Glob narrowing preserves the RESEARCH §Pitfall 6 "D-24 is primary catcher" architecture — `.md` coverage still happens in CI. Orphan-reference cleanup is correctness-required (workflow would fail schema check on next push without it).

## Observation-Window Deferred Verifications

Per VALIDATION.md §Manual-Only, 3 success criteria CANNOT be verified inside a PR merge window and must NOT block `/gsd-verify-work`:

| Flag | Description | `verify_type` | Gate-blocking? |
|------|-------------|---------------|----------------|
| ci-time-reduction-measured | Post-merge rolling median CI duration for `CI` workflow drops by 15-90s on PR runs | observation_window (requires 5+ merged PRs) | NO — delta is a metric, not a plan deliverable |
| lefthook-ci-job-green-on-first-pr | First 3 PRs after merge show the `Lefthook CI` check running green | observation_window (requires real PR traffic) | NO — workflow parses and structural grep all green; empirical run requires a PR |
| first-synthetic-bypass-caught | Deliberate `LEFTHOOK_BYPASS=1` commit that introduces a real lint violation gets blocked by the `Lefthook CI` job on its PR | observation_window (requires a deliberate hostile-scenario test) | NO — mechanism asserted via workflow content + lefthook validate on the same lefthook.yml that locally detects violations |

`/gsd-verify-work 34-07` should confirm the 2 automated success criteria (Task 1 + Task 2 grep/parse + P95 < 5s empirical) and mark these 3 observation-window items as deferred (flag `verify_type: observation_window`).

## Threat Flags

None — this plan adds one CI workflow (`lefthook-ci.yml`) and prunes 4 CI steps from an existing workflow. No new network endpoints, no new auth paths, no schema changes at trust boundaries. The `curl | sh` install of lefthook uses `https://raw.githubusercontent.com/evilmartians/lefthook/master/install.sh` — same supply-chain surface as the local `brew install lefthook` path already in use (CONTRIBUTING.md §1), and RESEARCH §Standard Stack ln 143 already locked evilmartians/lefthook as the 30.5 D-04 choice. No new `permissions:` block on the workflow beyond defaults.

## Known Stubs

None — both deliverables fully wired:
- lefthook.yml 4 new commands run real scripts with real exit codes (verified via `lefthook validate` + targeted `lefthook run pre-commit --file .github/workflows/lefthook-ci.yml` = 0.152s green)
- lefthook-ci.yml workflow invokes the installed lefthook binary on a clean runner; no mock/skip/stub anywhere in the 6 steps

The 3 observation-window items above are NOT stubs — they are inherently time-gated and correctly flagged as post-merge operational validation.

## Issues Encountered

- **`no_chiffre_choc.py` full-repo rglob stall (resolved)** — see Deviation #1. On this macOS checkout, the script's rglob over `apps/mobile/lib + services/backend/app + docs/ + tools/openapi` takes >5min on cold iCloud cache (thousands of `*.<ext> 2` duplicates). Narrowing the lefthook glob to code extensions sidestepped the issue locally; D-24 clean-runner re-run preserves full doc coverage. Future cleanup of iCloud duplicates is backlog (CONTEXT §Duplicates to watch ln 137-140).
- **Helper `python3 tools/checks/<script>.py --help` processes hung during read_first** — the scripts don't use argparse and read `--help` as a filename. Noise-only, killed via `kill 49290`.

## User Setup Required

None — the workflow runs on default GitHub Actions runners with default permissions. No secrets, no external services, no dashboard configuration. First activation happens automatically on the next PR to `dev`/`staging`/`main`.

## Self-Check: PASSED

**Files verified:**
- `.github/workflows/lefthook-ci.yml` — FOUND (66 lines; grep `pull_request:`=1, `lefthook run pre-commit --all-files --force`=1, `lefthook validate`=1, `lefthook run commit-msg`=1, `D-24`=2; PyYAML safe_load OK)
- `lefthook.yml` — FOUND (all 4 new commands present: `no-chiffre-choc`, `landing-no-numbers`, `landing-no-financial-core`, `route-registry-parity`; `lefthook validate` exits 0)
- `.github/workflows/ci.yml` — FOUND (0 uncommented run invocations of no_chiffre_choc.py / landing_no_numbers.py / landing_no_financial_core.py; 0 `route-registry-parity:` job blocks; 5 STAY lints preserved; `ci-gate needs:` cleaned; PyYAML safe_load OK)
- `.planning/phases/34-agent-guardrails-m-caniques/34-07-READ.md` — FOUND (12-file receipt, `- <path> — <why>` format per D-18)

**Commits verified:**
- `f1cf293c` — FOUND in git log (`feat(34-07): migrate 4 CI lints to lefthook + thin ci.yml (GUARD-08 D-23)`)
- `3a6596e9` — FOUND in git log (`feat(34-07): add lefthook-ci.yml D-24 PR re-run + final P95 <5s verified`)

**Lints + benchmarks verified:**
- `lefthook validate` — rc=0
- `bash tools/checks/lefthook_self_test.sh` — rc=0 (6/6 sections green in 0.52-0.61s across two runs)
- `bash tools/checks/lefthook_benchmark.sh --assert-p95=5` — rc=0, P95=0.110s
- `python3 tools/checks/accent_lint_fr.py --file .github/workflows/lefthook-ci.yml` — rc=0

**Requirements ledger:**
- `node gsd-tools.cjs requirements mark-complete GUARD-08` — updated=true, marked_complete=[GUARD-08]
- `grep -c "^- \[x\] \*\*GUARD-0[1-8]\*\*" REQUIREMENTS.md` = **8/8** (all Phase 34 GUARDs closed)

## Phase 34 Ship State

- **8/8 GUARDs complete** — GUARD-01 (lefthook <5s empirical), GUARD-02 (no_bare_catch), GUARD-03 (no_hardcoded_fr), GUARD-04 (accent_lint_fr), GUARD-05 (arb_parity), GUARD-06 (proof_of_read), GUARD-07 (LEFTHOOK_BYPASS convention + bypass-audit.yml), GUARD-08 (CI thinning + lefthook-ci.yml). All gates mechanically active, each with self-test + benchmark coverage.
- **Phase 34 execute complete.** Next step (outside this plan's scope): `/gsd-verify-work 34` to run the 7-pass verifier across all 8 plans + observation-window deferrals.
- **No open deferrals within Phase 34 scope.** 3 observation-window items (ci-time-reduction-measured / lefthook-ci-job-green-on-first-pr / first-synthetic-bypass-caught) are post-merge operational validation, correctly flagged for `/gsd-verify-work` to mark as deferred.

## Self-Check: PASSED (post-commit re-run)

All 5 target files FOUND on disk; all 2 task commits (`f1cf293c`, `3a6596e9`) plus final-metadata commit (`276b333b`) FOUND in git log; `grep -c "^- \[x\] \*\*GUARD-0[1-8]\*\*" .planning/REQUIREMENTS.md` = **8/8**; `bash tools/checks/lefthook_benchmark.sh --assert-p95=5` rc=0 with P95 = 0.100s (second run, confirms 0.110s first-run); `lefthook validate` rc=0.

---
*Phase: 34-agent-guardrails-m-caniques*
*Completed: 2026-04-22*
