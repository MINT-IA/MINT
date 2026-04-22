---
phase: 34-agent-guardrails-m-caniques
plan: 02
subsystem: infra
tags: [lefthook, no-bare-catch, guard-02, diff-only, parallel, pre-commit]

# Dependency graph
requires:
  - phase: 30.5
    provides: skeleton lefthook.yml with pre-commit block (parallel default false, 30.5 D-04)
  - plan: 34-00
    provides: tests/checks/conftest.py tmp_git_repo fixture + bare_catch_{bad,good}.{dart,py} + async_star_exempt.dart fixtures + schema-valid lefthook.yml
  - plan: 34-01
    provides: lefthook.yml with accent-lint-fr command + shell-loop pattern + Pitfall 7 exclude discipline
provides:
  - GUARD-02 activated day-1 via diff-only mode (D-07) — `git diff --staged --unified=0 --no-renames --diff-filter=AM` state-machine parser scans only ADDED lines, not full file content
  - tools/checks/no_bare_catch.py (255 LOC, stdlib-only Python 3.9-compat) — Dart + Python bare-catch detection with surrounding log-token check + async* exemption + 4 D-06 authorised exempt paths + inline override on same OR preceding line
  - tests/checks/test_no_bare_catch.py (12/12 pytest cases green) — covers D-05 detection, D-06 exemptions (test paths + async* + preceding-line override with >=3-word reason), D-07 diff-only (existing bare-catches ignored, only new flagged)
  - lefthook.yml pre-commit: parallel: true flipped (4 read-only commands) + no-bare-catch command with belt-and-braces `exclude:` for 4 D-06 paths
  - tools/checks/lefthook_self_test.sh extended with no_bare_catch FAIL + PASS cases (D-25) using temp git repo + --repo-root harness
  - Preceding-line override helper (`_override_in_preceding`) established as symmetric API shape for Plan 34-03 `no_hardcoded_fr.py` to mirror
affects: [34-03, 34-04, 34-05, 34-06, 34-07, 36-FIX-05]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Pattern D — Diff-only lint via stdlib state machine: `git diff --staged --unified=0 --no-renames --diff-filter=AM -- <path>` piped through a 1-regex hunk parser (`^@@ -\\d+(?:,\\d+)? \\+(\\d+)(?:,\\d+)? @@`). Returns (new_line_no, content) tuples. Reusable for any future diff-only gate (GUARD-03 no_hardcoded_fr.py already adopts this in Plan 34-03)."
    - "Pattern E — `_run_git()` subprocess helper: single cwd/kwargs plumbing for all `git diff`/`git show` calls. Enables --repo-root test harness (pytest + lefthook_self_test.sh spin up ephemeral repos and invoke process_file(repo_root=<tmp>)) without touching the main working tree."
    - "Pattern F — Preceding-line override check: accept `// lefthook-allow:<rule>: <reason>` comments on the line IMMEDIATELY PRECEDING the flagged line (not just same-line). Reason length >=3 whitespace-separated words enforced in a shared `_has_valid_override` helper that Dart and Python scans both reuse. Plan 34-03 mirrors this API verbatim."
    - "Pattern G — Parallel-safe lefthook flip: once all pre-commit commands are proven read-only (no writes to .git/index.lock, no `git add`/`git stash`), flipping `parallel: true` yields goroutine-level concurrency. Verified P95 0.110s with 4 commands (vs 0.100s sequential with 3 in Plan 01)."

key-files:
  created:
    - tools/checks/no_bare_catch.py
    - tests/checks/test_no_bare_catch.py
    - .planning/phases/34-agent-guardrails-m-caniques/34-02-SUMMARY.md
  modified:
    - lefthook.yml (parallel flip + no-bare-catch command + Plan 01 Pitfall-8 drift in inline comment fixed)
    - tools/checks/lefthook_self_test.sh (no_bare_catch FAIL + PASS cases appended before reminder banner; TMP_LINT cleanup added to EXIT trap)

key-decisions:
  - "D-07 diff-only is the single most important technical decision of Phase 34 — without it, the 388 existing bare-catches (332 mobile + 56 backend) would moving-target the FIX-05 Phase 36 migration. Chosen implementation: stdlib state-machine parser over `git diff --staged --unified=0`. Empirically verified in test_diff_only_ignores_existing_bad: file with pre-existing bare-catch at line 2 + unrelated line added at line 5 -> rc=0. File with pre-existing bare-catch + NEW bare-catch added -> rc=1 with exactly 1 violation (not 2). Plan 34 now ships standalone, Phase 36 FIX-05 converges progressively."
  - "parallel: true flipped despite 30.5 D-04 caveat (`parallel: false until phase 34`). Per RESEARCH Pattern 6, the caveat was about commands that WRITE to .git/index.lock; the 4 current pre-commit commands (memory-retention-gate, map-freshness-hint, accent-lint-fr, no-bare-catch) are all read-only (file reads + regex + git diff --staged). Verified no command writes to the index. P95 0.110s (vs 0.100s sequential Plan 01) — modest increase due to goroutine overhead on small diff, still 45x headroom vs 5s budget."
  - "Preceding-line override (`_override_in_preceding`) adopted over plan's original same-line-only pattern (B1 fix per Plan 34-02 revision 1/3). Justification: Dart line-length discipline pushes `// lefthook-allow:bare-catch: <reason>` above the catch for readability (catch line already has braces + method call). Python discipline ditto. Reviewing the override on the preceding line is also clearer for humans — the comment preludes the violation like a docstring. Plan 34-03 mirrors this API in `no_hardcoded_fr.py`."
  - "EXEMPT_PATH_PREFIXES is a tuple of EXACTLY 4 prefixes (W1 guard). No broad `tests/` entry — that would exempt any future top-level `tests/` directory beyond D-06 authorised scope. All 4 prefixes explicitly tested (test_test_dir_exempt, test_integration_test_exempt, test_services_backend_tests_exempt + tests/checks/fixtures/ implicit in the pytest harness)."
  - "Belt-and-braces exclusion: the lefthook `exclude:` block lists the same 4 D-06 prefixes as the lint's `is_exempt_path()`. Redundancy is intentional — lefthook gates at file-filter layer, the lint rejects in-process. Pytest harness bypasses lefthook entirely, so the in-process check is required for test independence. Both layers cooperate; neither is load-bearing alone."
  - "Rule 1 auto-fix: Plan 01 inherited a Pitfall-8 drift in its lefthook.yml inline comment — the prose cited a single ASCII-flattened stem verbatim in quotes, which the accent_lint_fr `\\b<stem>\\b` regex then matched. Plan 01 SUMMARY claimed `accent_lint_fr.py --file lefthook.yml` exits 0, but that claim was made before the comment drift landed. Rewrote the Plan 01 comment block to reference CLAUDE.md §2 authoritatively without citing stems verbatim. accent lint on lefthook.yml now exits 0 (regression closed)."
  - "Test count: 12 pytest cases instead of plan's loose '≥8' — 4 D-05 detection + 4 D-06 exemption + 2 D-07 diff-only + 1 override-valid + 1 override-insufficient-reason. 12 is the Plan 34-02 <behavior> list's full enumeration; went for full coverage rather than picking 8. pytest run 0.90s."

requirements-completed: [GUARD-02]

# Metrics
duration: ~7min
completed: 2026-04-22
---

# Phase 34 Plan 02: GUARD-02 no_bare_catch Diff-Only Lint Summary

**GUARD-02 shipped day-1 via diff-only mode (D-07): 255-LOC stdlib-only Python lint scans only added lines of `git diff --staged`, decoupling Phase 34 from Phase 36 FIX-05 migration of 388 existing bare-catches; 12/12 pytest green; lefthook pre-commit flipped to `parallel: true` with 4 read-only commands and P95 0.110s (45x headroom vs 5s budget).**

## Performance

- **Duration:** ~7 minutes 43 seconds
- **Started:** 2026-04-22T20:18:41Z
- **Completed:** 2026-04-22T20:26:24Z
- **Tasks:** 2/2 auto (no checkpoints)
- **Files created:** 2 (no_bare_catch.py + test_no_bare_catch.py)
- **Files modified:** 2 (lefthook.yml, lefthook_self_test.sh)
- **Commits:** 3 on `feature/S30.7-tools-deterministes`
  - `ef9ede9c` test(34-02) RED phase — 12 failing tests (module not yet created)
  - `794eaf14` feat(34-02) GREEN phase — no_bare_catch.py lint + 12 tests pass
  - `51e56adc` feat(34-02) Task 2 — lefthook wiring + parallel flip + self-test extension

## Accomplishments

- **D-07 diff-only empirically proven** — `test_diff_only_ignores_existing_bad` commits a file with a pre-existing bare-catch at line 2, then stages an unrelated new line. The lint exits 0 because the pre-existing catch is not in the added-lines set. `test_diff_adds_bare_catch_to_file_with_existing` commits the same file, then stages a NEW bare-catch on top — the lint exits 1 with exactly 1 violation (not 2). This is the single most important guarantee of the plan: GUARD-02 ships ACTIVE without blocking FIX-05's 388-catch convergence.
- **Dart + Python detection** — both surface patterns covered. Dart: `}\s*catch\s*\(\s*(?:e|_|err|error)\s*\)\s*\{\s*\}` (empty body) AND `on\s+\w+\s+catch\s*\(...\)\s*\{\s*\}` (typed exception) + body-scanning for logging/rethrow in the 5-line follow-on window. Python: `^\s*except\s*:\s*$`, `^\s*except\s+Exception\s*:\s*$`, `^\s*except\s+BaseException\s*:\s*$` + same body scan for `logger.`/`raise`/`sentry_sdk`/`print(`.
- **D-06 exemptions comprehensive** — 4 path prefixes (apps/mobile/test/, apps/mobile/integration_test/, services/backend/tests/, tests/checks/fixtures/) EXACTLY, no broad `tests/` (W1 guard); Dart `async *` generators (10-line lookback); inline override `// lefthook-allow:bare-catch: <reason>` OR `# lefthook-allow:bare-catch: <reason>` with >=3-word reason, accepted on SAME line or IMMEDIATELY PRECEDING line (B1 fix via `_override_in_preceding`).
- **parallel: true flipped** — all 4 current pre-commit commands (memory-retention-gate, map-freshness-hint, accent-lint-fr, no-bare-catch) are proven read-only. Inline YAML comment justifies the flip. P95 benchmark 0.110s (vs 0.100s sequential with 3 commands in Plan 01) — modest parallel overhead is real but well under 5s budget.
- **pytest 12/12 green in 0.90s** — all D-05/D-06/D-07 axes covered. Specifically `test_inline_override_valid` (preceding-line override with valid 5-word reason -> PASS, B1 fix) + `test_inline_override_insufficient_reason` (preceding-line override with 1-word reason -> FAIL).
- **Self-test extended** (D-25) — `lefthook_self_test.sh` now runs 2 additional direct-invocation checks via a temp git repo: stages bad.dart (empty catch) -> lint must FAIL; stages good.dart (Sentry + rethrow) -> lint must PASS. Uses the `--repo-root $TMP_LINT` harness to stay isolated from the main working tree. EXIT trap extended to rm -rf the temp repo. Full self-test rc=0 with 3 green sections (30.5 retention + Plan 01 accent + Plan 02 no_bare_catch).
- **Self-compliance (Pitfall 8) green** — `accent_lint_fr.py --file tools/checks/no_bare_catch.py` rc=0; technical English throughout, no FR diagnostics, no ARB i18n.
- **Rule 1 auto-fix inherited from Plan 01** — lefthook.yml inline comment contained a literal quoted ASCII-flattened stem that Plan 01 missed; rewrote to cite CLAUDE.md §2 authoritatively. `accent_lint_fr.py --file lefthook.yml` now rc=0 (regression Plan 01 missed, now closed).

## Task Commits

1. **RED — `ef9ede9c` test(34-02):** add failing tests for no_bare_catch diff-only lint
   - Files: `tests/checks/test_no_bare_catch.py` (new, 217 lines, 12 cases)
   - Verified: 12 failures with `ModuleNotFoundError: no_bare_catch` (expected RED).

2. **GREEN — `794eaf14` feat(34-02):** implement no_bare_catch.py diff-only lint (GUARD-02)
   - Files: `tools/checks/no_bare_catch.py` (new, 255 lines)
   - Verified: 12/12 pytest green in 0.90s, self-compliance rc=0, `--staged` on clean tree rc=0, all grep acceptance criteria met (git diff --staged:2, is_exempt_path:2, is_in_async_star:2, _has_valid_override:4, _override_in_preceding:2, lefthook-allow:.*bare-catch:5, EXEMPT_PATH_PREFIXES strict 4-prefix scope, no broad tests/).

3. **Task 2 — `51e56adc` feat(34-02):** wire no-bare-catch in lefthook + flip parallel:true
   - Files: `lefthook.yml`, `tools/checks/lefthook_self_test.sh`
   - Verified: `lefthook validate` All good; `grep -c no-bare-catch: lefthook.yml` = 1; `grep -c "parallel: true" lefthook.yml` = 1; `grep -c "parallel: false" lefthook.yml` = 0; `grep -c "apps/mobile/test" lefthook.yml` >= 1; self-test rc=0; benchmark P95 0.110s; accent lint on lefthook.yml rc=0.

## LOC + API Surface

| File | LOC | Purpose |
|------|-----|---------|
| tools/checks/no_bare_catch.py | 255 | Diff-only Dart + Python bare-catch lint with 4 D-06 exemptions + preceding-line override |
| tests/checks/test_no_bare_catch.py | 217 | 12 pytest cases covering D-05/D-06/D-07 |

**Public API surface of no_bare_catch.py:**
- `get_added_lines(file_path, repo_root=None)` -> `list[tuple[int, str]]` — diff parser
- `is_exempt_path(file_path)` -> `bool` — 4-prefix D-06 check
- `is_in_async_star(full_text, line_no)` -> `bool` — Dart async* lookback
- `has_surrounding_log_tokens(full_text, line_no, tokens)` -> `bool` — 5-line window check
- `_has_valid_override(line, is_python)` -> `bool` — same-line override with >=3-word reason
- `_override_in_preceding(lines, added_line_no, is_python)` -> `bool` — B1 fix, preceding-line check
- `scan_dart_added(added, full_text, file_path)` -> `list[str]` — Dart scan wrapper
- `scan_python_added(added, full_text, file_path)` -> `list[str]` — Python scan wrapper
- `read_staged_file(file_path, repo_root=None)` -> `str` — `git show :<path>` with working-tree fallback
- `process_file(file_path, repo_root=None)` -> `list[str]` — single-file orchestrator used by pytest + self-test
- `list_staged_files(repo_root=None)` -> `list[str]` — `git diff --staged --name-only`
- `main()` -> `int` — argparse entry point (exit 0/1/2)

Private helper `_scan_added` consolidates Dart/Python scan duplication.

## lefthook.yml Diff (no-bare-catch command + parallel flip)

```yaml
pre-commit:
  # Phase 34 Plan 02 — flipped to true per RESEARCH Pattern 6. All 5 Phase 34
  # commands (memory-retention-gate, map-freshness-hint, accent-lint-fr,
  # no-bare-catch, + future GUARD-03/05 lints) are read-only: they invoke
  # `git diff --staged` / file reads / regex only. Zero `.git/index.lock`
  # contention. Exit code = max across commands (lefthook 2.1.x semantics).
  parallel: true
  skip:
    - merge
    - rebase
  commands:
    # ... memory-retention-gate + map-freshness-hint + accent-lint-fr preserved ...
    # ─── Phase 34 GUARD-02 (diff-only, D-05/D-06/D-07) ───────────────────
    # Scans ONLY the lines added by the staged diff (D-07) -- decouples
    # Phase 34 from Phase 36 FIX-05 migration of 388 existing bare-catches.
    # Dart `} catch (e) {}` + Python `except Exception: pass` without
    # log/rethrow. Exemptions: test/integration_test paths, async *
    # generators, inline `// lefthook-allow:bare-catch: <reason>` (>=3 words).
    # `exclude:` is belt-and-braces for the 4 D-06 authorised path prefixes;
    # the lint's `is_exempt_path()` also rejects them for pytest independence.
    # No broad `tests/**` exclude (W1 guard).
    no-bare-catch:
      run: python3 tools/checks/no_bare_catch.py --staged
      glob: "*.{dart,py}"
      exclude:
        - "apps/mobile/test/**"
        - "apps/mobile/integration_test/**"
        - "services/backend/tests/**"
        - "tests/checks/fixtures/**"
      tags: [safety, phase-34]
```

## Benchmark Delta

| State | Commands | P95 (s) | Budget headroom |
|-------|----------|---------|-----------------|
| Wave 0 baseline | 2 (memory + map-freshness) | 0.120 | 4.88s |
| Plan 01 after GUARD-04 | 3 (+ accent-lint-fr) | 0.100 | 4.90s |
| **Plan 02 after GUARD-02 + parallel:true** | **4 (+ no-bare-catch)** | **0.110** | **4.89s** |

Flipping `parallel: true` adds ~0.01s goroutine overhead on a clean-tree pre-commit (no files staged matching the globs -> all commands early-return). This overhead is negligible on real diffs, where the parallel speedup recovers its cost quickly. 45x headroom against the 5s budget. GUARD-01 success criterion #1 uncompromised.

**Note on `lefthook run pre-commit --all-files`:** plan's `<important_notes>` asked whether this command would now fail on the repo's 388 pre-existing bare-catches. Investigation: `--all-files` passes matching file paths to lefthook's glob filter, but our lint reads `git diff --staged` internally (D-07 diff-only mode is authoritative, lefthook's file list is not). On a clean tree, `git diff --staged` is empty -> lint exits 0 regardless of how many pre-existing bare-catches exist in the working tree. Verified: `lefthook run pre-commit` on clean tree rc=0 (no-bare-catch step shows `(skip) no matching staged files`). No investigation needed; no contradiction with D-07.

## Self-test tail

```
[self-test] accent_lint_fr: OK (FAIL + PASS cases green)
[self-test] no_bare_catch: scanning known-bad diff...
[self-test] no_bare_catch: scanning known-good diff...
[self-test] no_bare_catch: OK (FAIL + PASS cases green)
self-test: reminder — Phase 34 fixtures under tests/checks/fixtures/ must be
  added to each new lint's lefthook 'exclude:' list (per Pitfall 7).
  Plans 01 + 02 exclude fixtures; Plans 03-05 must follow.
```

rc=0.

## Per-Decision Coverage

| Decision | Status | Evidence |
|----------|--------|----------|
| D-02 (parallel flip) | ✓ | `grep -c "parallel: true" lefthook.yml` = 1, `parallel: false` = 0, inline YAML comment justifies safety |
| D-05 (regex-first Dart + Python) | ✓ | `DART_BARE_CATCH` 2-pattern list + `PY_BARE_EXCEPT` 3-pattern list; body-scan via `has_surrounding_log_tokens` |
| D-06 (exemptions: test paths + async* + inline override) | ✓ | 4-prefix `EXEMPT_PATH_PREFIXES` strict scope (W1 guard, no broad `tests/`), `is_in_async_star` 10-line lookback, `_has_valid_override` same-line + `_override_in_preceding` preceding-line (B1 fix), >=3-word reason check |
| D-07 (diff-only, CRITICAL) | ✓ | `get_added_lines` uses `git diff --staged --unified=0 --no-renames --diff-filter=AM`; `test_diff_only_ignores_existing_bad` + `test_diff_adds_bare_catch_to_file_with_existing` empirically prove the decoupling from FIX-05 |
| D-25 (self-test extended with FAIL + PASS) | ✓ | `lefthook_self_test.sh` runs bad.dart + good.dart in $TMP_LINT, rc=0, 3 green sections |
| Pitfall 7 (fixture self-regression) | ✓ | `tests/checks/fixtures/**` in both lefthook exclude AND lint's `EXEMPT_PATH_PREFIXES` |
| Pitfall 8 (self-compliance) | ✓ | `accent_lint_fr.py --file tools/checks/no_bare_catch.py` rc=0; technical English only |
| RESEARCH Pattern 6 (parallel safety) | ✓ | All 4 current commands read-only (memory reads mtime; map-freshness reads files; accent reads files; no-bare-catch reads diff + files). None write to .git/index.lock. |
| GUARD-01 <5s budget preservation | ✓ | P95 0.110s with 4 commands + parallel:true — 45x headroom vs 5s budget |

## Decisions Made

None beyond what PLAN.md specified. Three small execution-discretion choices:

1. **Consolidated scan_dart_added + scan_python_added into a shared `_scan_added` helper** (kept public wrappers for API continuity). Plan's skeleton had verbatim duplication; DRY helper saves ~20 LOC and ensures the two code paths can never drift (e.g., adding a new exemption check to Dart but forgetting Python). Both wrappers are 3 lines each, trivially grep-able.

2. **Used a shared `_run_git(cmd, repo_root)` subprocess helper** rather than repeating the `capture_output=True, text=True, check=False` + cwd plumbing in 4 places (`get_added_lines`, `read_staged_file`, `list_staged_files`, and the future `--staged` CLI path). Saves ~8 LOC, makes the --repo-root test harness semantics uniform across all subprocess calls.

3. **Test count = 12, not 8** — picked the full `<behavior>` list rather than an arbitrary subset. `test_inline_override_valid` uses the preceding-line semantics (not same-line) to exercise the B1 fix directly. `test_logged_catch_passes` covers the positive case (Sentry + rethrow in the 5-line follow-on).

## Deviations from Plan

**Rule 1 auto-fix (Pitfall 8 regression inherited from Plan 01):** during Task 2 acceptance-criteria validation, `accent_lint_fr.py --file lefthook.yml` returned rc=1 on the literal quoted ASCII-flattened stem inside a Plan 01 inline comment block. Plan 01 SUMMARY claimed this command exited 0, but the drift landed in Plan 01's GREEN commit and the self-compliance check was run against a slightly earlier snapshot. Rewrote the Plan 01 comment block to cite CLAUDE.md §2 authoritatively without quoting stems. `accent_lint_fr.py --file lefthook.yml` now rc=0. Regression closed. No architectural change (Rule 4) — purely comment prose cleanup on a file already in this plan's modified set.

No other deviations. All 2 tasks executed as planned. No Rule 2, 3, or 4 escalations.

## Issues Encountered

**Issue 1 (resolved):** initial `no_bare_catch.py` verbatim-copy from the plan skeleton weighed 300 LOC; acceptance criterion bounded it to 150-260. Applied two compaction rounds: (a) shortened module docstring from 21 lines to 14; (b) extracted `_run_git()` helper; (c) consolidated scan_dart_added + scan_python_added into `_scan_added` shared kernel; (d) tightened docstrings on `is_in_async_star`, `has_surrounding_log_tokens`, `_has_valid_override`, `_override_in_preceding`. Final LOC 255, pytest 12/12 still green post-compaction. No functional change.

**Issue 2 (resolved):** Plan 01 inherited Pitfall-8 drift in lefthook.yml inline comment (detailed under Deviations → Rule 1).

No unplanned architectural work. No blockers.

## User Setup Required

None — all changes are repo-local lint infrastructure. No env vars, no secrets, no external services. Lefthook already installed (version 2.1.6 on dev box, min_version 2.1.5 in config).

## Threat Model Coverage

| Threat ID | Status | Evidence |
|-----------|--------|----------|
| T-34-02 (override abuse) | mitigated | `_has_valid_override` enforces >=3-word reason; `test_inline_override_insufficient_reason` proves 1-word reason fails. Override only accepted on same OR immediately preceding line (not 2 lines above) — minimal blast radius. |
| T-34-02b (over-broad exempt path, W1) | mitigated | `EXEMPT_PATH_PREFIXES` = EXACTLY 4 D-06 authorised prefixes; no broad `tests/`. Unit-tested via `test_test_dir_exempt` + `test_integration_test_exempt` + `test_services_backend_tests_exempt`. |
| T-34-04 (lint tampering) | flagged | Plan 34-07 `lefthook-ci.yml` will re-run hooks on CI worktree — tampering visible in PR diff. Not mitigated here; flagged for Plan 07 coverage. |
| T-34-05 (parallel index race) | mitigated | All 4 pre-commit commands are read-only (file reads + regex + `git diff --staged`). Verified by source inspection. Plan 01 accent-lint-fr + Plan 02 no-bare-catch + 30.5 memory-retention-gate + 30.5 map-freshness-hint — none invoke `git add`/`git stash`/`git commit`. Parallel safe. |
| T-34-DoS-regex (ReDoS) | mitigated | All Phase 34 patterns are linear bounded (no nested quantifiers, no backtracking traps). Compiled once at module load. Verified no pattern of form `(a+)+` or `(a\|a)+`. |
| T-34-07 (fixture self-regression) | mitigated | Fixture paths excluded via TWO layers: lefthook `exclude:` glob + lint `is_exempt_path()`. Belt-and-braces. |

## Next Phase Readiness

**Plan 02 unblocks Plans 03-07:**
- **Plan 34-03 (GUARD-03 no_hardcoded_fr)** mirrors the `_has_valid_override` + `_override_in_preceding` helper API shape — preceding-line override semantics established here as the Phase 34 convention.
- **Plan 34-04 (GUARD-05 arb_parity)** inherits the `_run_git` subprocess pattern and the parallel-safety constraint (must be read-only).
- **Plan 34-05 (GUARD-06 proof_of_read)** adds a `commit-msg:` block (D-27 amendment to D-04), orthogonal to pre-commit scope; parallel:true doesn't affect commit-msg hooks.
- **Plan 34-07 (CI thinning)** can invoke `bash tools/checks/lefthook_benchmark.sh --assert-p95=5` against the new 0.110s baseline.

**FIX-05 Phase 36 decoupling confirmed** — the 388 existing bare-catches (332 mobile + 56 backend per STATE.md §Blockers) remain in-place without blocking commits. D-07 diff-only mode ensures only NEW bare-catches fail the gate. FIX-05 can now converge the backlog by batch (backend 56 first per CONTEXT §Deferred) knowing no new entries enter on staged diffs.

**Plan 34-02 completes GUARD-02 (requirements-completed: [GUARD-02])** — 2/8 Phase 34 requirements done (GUARD-04 shipped Plan 01, GUARD-02 shipped Plan 02).

## Self-Check: PASSED

**Files verified on disk:**
- FOUND: `tools/checks/no_bare_catch.py` (255 LOC, stdlib-only, Python 3.9-compat, self-compliance rc=0)
- FOUND: `tests/checks/test_no_bare_catch.py` (217 LOC, 12 test cases, all green in 0.90s)
- FOUND: `lefthook.yml` (modified — `parallel: true`, no-bare-catch command block, validate rc=0)
- FOUND: `tools/checks/lefthook_self_test.sh` (extended with no_bare_catch FAIL + PASS cases)
- FOUND: `.planning/phases/34-agent-guardrails-m-caniques/34-02-SUMMARY.md` (this file)

**Commits verified:**
- FOUND: `ef9ede9c` — test(34-02): add failing tests for no_bare_catch diff-only lint
- FOUND: `794eaf14` — feat(34-02): implement no_bare_catch.py diff-only lint (GUARD-02)
- FOUND: `51e56adc` — feat(34-02): wire no-bare-catch in lefthook + flip parallel:true

**Hooks + tests green:**
- FOUND: `lefthook validate` -> All good
- FOUND: `bash tools/checks/lefthook_self_test.sh` -> rc=0 (3 sections green)
- FOUND: `bash tools/checks/lefthook_benchmark.sh` -> P95 0.110s (<<5s)
- FOUND: `python3 -m pytest tests/checks/test_no_bare_catch.py` -> 12/12 green in 0.90s
- FOUND: `accent_lint_fr.py --file tools/checks/no_bare_catch.py` -> rc=0 (self-compliance)
- FOUND: `accent_lint_fr.py --file lefthook.yml` -> rc=0 (Plan 01 Pitfall-8 drift closed)
- FOUND: `no_bare_catch.py --staged` on clean tree -> rc=0

---
*Phase: 34-agent-guardrails-m-caniques*
*Plan: 02*
*Completed: 2026-04-22*
