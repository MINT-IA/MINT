---
phase: 34-agent-guardrails-m-caniques
plan: 05
subsystem: infra
tags: [lefthook, commit-msg, proof-of-read, agents, safety, python, stdlib, guard-06, phase-34, d-27-amendment]

requires:
  - phase: 34-00
    provides: lefthook.yml schema-valid baseline + Wave 0 commit-msg fixtures (commit_with_read_trailer / commit_without_read_trailer / commit_human_no_claude) + conftest.py
  - phase: 34-02
    provides: python lint style template (no_bare_catch.py argparse + exit codes + technical English docstring) + self-test extension pattern
  - phase: 34-04
    provides: 5-section self-test structure to extend with 6th section
provides:
  - GUARD-06 proof-of-read commit-msg hook (Claude trailer detection + Read: trailer validation + file-on-disk check + D-18 bullet format check + T-34-SPOOF-01 path-prefix mitigation)
  - First-ever `commit-msg:` top-level block in lefthook.yml (D-27 amendment of D-04)
  - CONTRIBUTING.md bootstrap (lefthook install + agent-commit trailer convention)
  - lefthook_self_test.sh 6th section covering bypass PASS + Claude-no-Read: FAIL paths
affects: [34-06, 34-07, 36 (agents shipping unread edits blocked mechanically), v2.9 (Claude Agent SDK PreToolUse hook = DIFF-04 replacement)]

tech-stack:
  added: []  # stdlib only per plan minimalism
  patterns:
    - "commit-msg hook as the ONLY viable mount point for commit-message lints (pre-commit too early, post-commit too late)"
    - "ALLOWED_READ_PREFIX hardcoded constant for anti-spoofing (T-34-SPOOF-01) instead of regex-based path validation"
    - "D-17 bypass: absence of Co-Authored-By trailer short-circuits lint before Read: enforcement kicks in"
    - "Self-compliance bootstrap: executor creates its own 34-05-READ.md under tmp disk before relying on the hook (chicken-and-egg solved by landing the script + tests BEFORE the lefthook wiring)"

key-files:
  created:
    - "tools/checks/proof_of_read.py"
    - "tests/checks/test_proof_of_read.py"
    - "CONTRIBUTING.md"
    - ".planning/phases/34-agent-guardrails-m-caniques/34-05-READ.md"
    - ".planning/phases/34-agent-guardrails-m-caniques/34-05-SUMMARY.md"
  modified:
    - "lefthook.yml (added top-level commit-msg: block with proof-of-read command + D-27 inline provenance)"
    - "tools/checks/lefthook_self_test.sh (6th section: proof_of_read PASS bypass + FAIL missing-trailer)"

key-decisions:
  - "D-04 AMENDED in-flight via CONTEXT D-27 — Phase 34 authorises ONE commit-msg block, dedicated to proof-of-read; no other lint migrates"
  - "T-34-SPOOF-01 mitigation via hardcoded ALLOWED_READ_PREFIX='.planning/phases/' — attacker cannot spoof /dev/null or /etc/passwd"
  - "D-17 human bypass short-circuits before Read: enforcement — no Claude trailer -> silent exit 0"
  - "First commit (RED test + READ.md) pre-dates commit-msg hook install; Task 2 commit was first real end-to-end exercise of the gate (passed)"
  - "CONTRIBUTING.md kept minimal (2 sections) — Plan 34-06 expands with LEFTHOOK_BYPASS section"
  - "Self-test 6th section only covers bypass + FAIL cases; PASS-with-Read: stays in pytest (requires tmp READ.md round-trip)"

patterns-established:
  - "commit-msg hook as surgical escape hatch from D-04 pre-commit-only rule (one block, one command, documented provenance)"
  - "Hardcoded path-prefix whitelist for anti-spoofing (cheaper and more auditable than path-canonicalisation + realpath walks)"
  - "Bullet-count format check on referenced receipt files (D-18) — mirrors the shape of READ.md convention"

requirements-completed: [GUARD-06]

duration: ~15m
completed: 2026-04-22
---

# Phase 34 Plan 05: GUARD-06 proof_of_read commit-msg hook Summary

**First-ever `commit-msg:` block in this repo — stdlib-only Python lint that blocks any Claude-coauthored commit missing a `Read: .planning/phases/…/…-READ.md` trailer referencing an existing file with at least one `- <path> - <why>` bullet, with T-34-SPOOF-01 path-prefix hardening and D-17 automatic bypass for human commits.**

## Performance

- **Duration:** ~15 minutes (1 RED + 1 GREEN + 1 wiring commit)
- **Started:** 2026-04-22T22:55Z (approx)
- **Completed:** 2026-04-22T23:10Z (approx)
- **Tasks:** 2 (Task 1 TDD lint + tests, Task 2 lefthook + self-test + CONTRIBUTING)
- **Files touched:** 5 created (proof_of_read.py + test_proof_of_read.py + CONTRIBUTING.md + 34-05-READ.md + 34-05-SUMMARY.md) + 2 modified (lefthook.yml + lefthook_self_test.sh)

## Accomplishments

- **GUARD-06 active as commit-msg gate** — any commit carrying `Co-Authored-By: Claude` must reference an on-disk `.planning/phases/<phase>/<padded>-READ.md` with at least one `- ` bullet. Enforcement happens at commit-msg time via lefthook's `{1}` COMMIT_EDITMSG placeholder. Human commits (no Claude trailer) bypass automatically per D-17.
- **D-04 AMENDED in-flight via CONTEXT D-27** — Phase 34 originally stated `pre-commit only`; this plan surgically authorises ONE `commit-msg:` block dedicated to proof-of-read. Inline YAML comment in `lefthook.yml` cites `D-04 AMENDED by CONTEXT D-27` + scope discipline ("future commit-msg lints require a new amendment on top of D-27"). No other Phase 34 lint migrates.
- **T-34-SPOOF-01 mitigation live** — hardcoded `ALLOWED_READ_PREFIX='.planning/phases/'` constant rejects any `Read:` trailer pointing outside that namespace (tested: `/dev/null` -> FAIL, `README.md` -> FAIL, `.planning/phases/34-…-READ.md` -> PASS). Cheaper and more auditable than realpath-canonicalisation.
- **12/12 pytest cases green** covering: valid Claude+Read+bullets PASS, missing Read: FAIL, missing file FAIL, human bypass PASS, T-34-SPOOF-01 absolute-path FAIL, T-34-SPOOF-01 relative-path-outside FAIL, no-bullet format FAIL, empty message PASS, 3 Wave 0 fixture cases, case-sensitivity contract.
- **Self-test 6 sections green** — memory + accent + no_bare_catch + no_hardcoded_fr + arb_parity + proof_of_read. 6th section runs human-bypass PASS + Claude-no-Read: FAIL against Wave 0 fixtures (PASS-with-Read: case stays in pytest with tmp_path to avoid on-disk state dependency).
- **End-to-end self-compliance proven live** — Task 2's own commit (`d4b5196e`) was the first real exercise of the gate after `lefthook install --force` landed. Commit message carried `Read: .planning/phases/34-…/34-05-READ.md` + Claude trailer; hook accepted; commit landed. No `--no-verify` used anywhere.
- **P95 pre-commit benchmark unchanged at 0.090s** — commit-msg runs on a separate hook, so the 5s pre-commit budget is untouched. GUARD-01 success criterion #1 uncompromised.
- **CONTRIBUTING.md bootstrap** — new file (2 sections: lefthook install + agent-commit trailer convention with example). Minimal surface; Plan 34-06 will add the LEFTHOOK_BYPASS section.

## Task Commits

1. **Task 1 (TDD RED): Add failing test for proof_of_read** — `bab21843` (test)
2. **Task 1 (TDD GREEN): Implement proof_of_read.py commit-msg hook** — `3789426a` (feat)
3. **Task 2: Wire commit-msg block + self-test + CONTRIBUTING.md** — `d4b5196e` (chore)

_Note: Task 1 is TDD so RED + GREEN committed separately per `<tdd_execution>` protocol. No REFACTOR pass needed — the initial GREEN iteration passed all 12 pytest cases and all grep acceptance criteria on first run._

## Files Created/Modified

- **`tools/checks/proof_of_read.py`** (147 LOC, NEW) — stdlib-only Python 3.9 commit-msg hook. `check_commit_msg(msg, repo_root) -> (int, List[str])` pure function for testability. `main()` wraps it with argparse (`--commit-msg-file {1}` + `--repo-root` for test harness).
- **`tests/checks/test_proof_of_read.py`** (164 LOC, NEW) — 12 pytest cases covering D-16/D-17/D-18 + T-34-SPOOF-01 (2 variants: absolute `/dev/null` + relative `README.md`) + D-18 bullet format + empty message edge case + 3 Wave 0 fixture round-trips + case-sensitivity documentation.
- **`lefthook.yml`** (+20 lines at bottom) — new top-level `commit-msg:` block with single `proof-of-read` command. Inline YAML comment documents D-04 AMENDED by CONTEXT D-27 + scope discipline. `pre-commit:` block untouched (5 Phase 34 lints + parallel:true preserved).
- **`tools/checks/lefthook_self_test.sh`** (+16 lines before the exit-0 trailer) — 6th section (Plan 05). Runs `commit_human_no_claude.txt` -> must PASS + `commit_without_read_trailer.txt` -> must FAIL. Reminder banner updated: Plan 05 commit-msg hook scans COMMIT_EDITMSG (not files) so Pitfall-7 fixture-exclusion doesn't apply to it.
- **`CONTRIBUTING.md`** (27 LOC, NEW) — 2 short sections: "Pre-commit hooks (lefthook)" + "Agent commits (proof-of-read — GUARD-06)". Example trailer block included.
- **`.planning/phases/34-agent-guardrails-m-caniques/34-05-READ.md`** (NEW) — D-18 receipts for this plan (14 files listed with `- <path> - <why>` format). Referenced by the `Read:` trailer of all 3 task commits + this SUMMARY's metadata commit.

## Decisions Made

- **D-27 amendment executed in-flight** — CONTEXT.md already carries D-27 (added in revision 1/3); this plan was the first code execution citing it. Inline YAML provenance in `lefthook.yml` cites both `D-04 AMENDED` and `D-27` so future readers can trace the rule change back to both the original decision ID and the amendment ID.
- **Hardcoded prefix whitelist over realpath canonicalisation** — `path.startswith(ALLOWED_READ_PREFIX)` is O(1), auditable, and doesn't leak filesystem information. Realpath would add a syscall per commit + open the door to symlink-traversal edge cases. The T-34-SPOOF-01 threat is "point at a real-but-irrelevant file", not "escape a chroot".
- **PASS-with-Read: case stays in pytest, not self-test** — the PASS path requires an on-disk `.planning/phases/…/…-READ.md` with bullets; asserting that in the self-test would either (a) create transient files polluting the tree, or (b) depend on the current working tree state which breaks determinism. pytest's `tmp_path` fixture is the clean solution.
- **CONTRIBUTING.md deliberately minimal** — 2 sections only. Plan 34-06 (GUARD-07 LEFTHOOK_BYPASS) will add the bypass-audit section; Plan 34-07 (GUARD-08 CI thinning) may add the CI-job reference. Cramming all 3 sections into this plan would violate scope discipline.
- **Commit-msg hook install order** — executor installed the hook AFTER shipping the script + tests (`feat` commit `3789426a`) but BEFORE the lefthook.yml wiring commit (`d4b5196e`). This means `3789426a` was NOT subject to the gate (installed hook didn't exist at that moment), but `d4b5196e` WAS and PASSED with a fresh `Read:` trailer. Proves the gate is live + self-compliant without requiring `--no-verify` gymnastics.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - doc] proof_of_read.py LOC at 147 (acceptance target 60-120)**
- **Found during:** Task 1 GREEN verification (`wc -l`)
- **Issue:** Plan acceptance criterion sets `wc -l` between 60 and 120; initial draft was 156 LOC (35 of which were docstring). Trimmed docstring to 147 LOC, still above 120.
- **Fix:** Rejected further trimming because the user explicitly stressed documenting (a) D-27 amendment live + (b) T-34-SPOOF-01 rationale inline + (c) D-17 bypass contract + (d) exit code table. Cutting those would violate the user's stated importance. Behavioural logic is ~70 LOC; the rest is substantive docstring. The `must_haves.artifacts.min_lines: 60` contract in the plan frontmatter is met.
- **Files modified:** tools/checks/proof_of_read.py
- **Commit:** 3789426a

**2. [Rule 3 - blocking] CONTRIBUTING.md didn't exist at plan start**
- **Found during:** Task 2 scoping
- **Issue:** Plan calls for adding a mention in CONTRIBUTING.md "under an existing i18n/hooks section, or create a tiny `### Agent commits` subsection". The file didn't exist in the repo.
- **Fix:** Created CONTRIBUTING.md from scratch with 2 sections (lefthook + agent commits). Kept minimal per the plan's "DO NOT write a full section — Plan 34-06 does LEFTHOOK_BYPASS" instruction.
- **Files modified:** CONTRIBUTING.md (new)
- **Commit:** d4b5196e

### None that required user decision.

No Rule 4 (architectural) deviations. No checkpoints. No authentication gates.

## Verification Trail

```bash
# Pytest
python3 -m pytest tests/checks/test_proof_of_read.py -q
# -> 12 passed in 0.02s

# Lefthook schema
lefthook validate
# -> All good

# Grep acceptance criteria (lefthook.yml)
grep -c '^commit-msg:' lefthook.yml          # -> 1
grep -c 'proof-of-read:' lefthook.yml        # -> 1
grep -c '{1}' lefthook.yml                   # -> 3
grep -c 'D-04 AMENDED' lefthook.yml          # -> 1
grep -c 'D-27' lefthook.yml                  # -> 2

# Grep acceptance criteria (proof_of_read.py)
grep -c 'Co-Authored-By' tools/checks/proof_of_read.py   # -> 2
grep -c '\.planning/phases/' tools/checks/proof_of_read.py  # -> 5
grep -c 'commit-msg' tools/checks/proof_of_read.py       # -> 7
grep -c 'D-17' tools/checks/proof_of_read.py             # -> 6
wc -l tools/checks/proof_of_read.py                      # -> 147

# Self-compliance
python3 tools/checks/accent_lint_fr.py --file tools/checks/proof_of_read.py   # -> rc=0
python3 tools/checks/accent_lint_fr.py --file lefthook.yml                    # -> rc=0
python3 tools/checks/accent_lint_fr.py --file CONTRIBUTING.md                 # -> rc=0

# Self-test
bash tools/checks/lefthook_self_test.sh
# -> 6 sections green (retention + accent + no_bare_catch + no_hardcoded_fr + arb_parity + proof_of_read)

# Lefthook install + hook registered
lefthook install --force
# -> sync hooks: pre-commit + commit-msg

# Benchmark
bash tools/checks/lefthook_benchmark.sh
# -> P95 (over last 8 runs): 0.090s (unchanged; commit-msg runs separately)

# Behavioural matrix (direct invocation)
echo "feat: x" > /tmp/msg_human.txt                                  # human only
python3 tools/checks/proof_of_read.py --commit-msg-file /tmp/msg_human.txt
# -> [proof_of_read] OK - human commit (no Claude trailer), bypass | rc=0

printf "feat: x\n\nCo-Authored-By: Claude <x@y.com>\n" > /tmp/msg_fail.txt   # Claude no Read:
python3 tools/checks/proof_of_read.py --commit-msg-file /tmp/msg_fail.txt
# -> [proof_of_read] FAIL - Claude-coauthored commit missing `Read:` trailer. | rc=1

printf "feat: x\n\nRead: /dev/null\nCo-Authored-By: Claude <x@y.com>\n" > /tmp/msg_spoof.txt   # T-34-SPOOF-01
python3 tools/checks/proof_of_read.py --commit-msg-file /tmp/msg_spoof.txt
# -> [proof_of_read] FAIL - Read: path must start with `.planning/phases/` (T-34-SPOOF-01), got: /dev/null | rc=1

# End-to-end live exercise (Task 2 commit itself)
git log -1 --format=%B d4b5196e | grep -E '^Read:|^Co-Authored-By:'
# -> Read: .planning/phases/34-agent-guardrails-m-caniques/34-05-READ.md
# -> Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
# Commit LANDED with the hook installed = live proof-of-read gate passed
```

## Threat Model Coverage

| Threat ID | Category | Disposition | Evidence |
|-----------|----------|-------------|----------|
| T-34-03 | Information Disclosure | mitigate | `proof_of_read.py` reads ONLY `Co-Authored-By:` + `Read:` trailers via narrow regexes; no shell, no eval, no arbitrary file extraction — matches D-17 exactly |
| T-34-SPOOF-01 | Tampering (Read: /dev/null) | mitigate | `ALLOWED_READ_PREFIX='.planning/phases/'` hardcoded; 2 pytest cases (`test_read_path_outside_planning_fail` + `test_read_path_relative_outside_planning_fail`) enforce |
| T-34-04 | Tampering (`proof_of_read.py` itself) | flag medium | Script tampering visible in PR diff; Plan 34-06 bypass-audit workflow rerun mitigates further; CI job in Plan 34-07 catches drift |
| T-34-08 | Spoofing (self-regression) | mitigate | `accent_lint_fr.py --file proof_of_read.py` rc=0; technical English only |

## Decision Coverage

| Decision | Status | Evidence |
|----------|--------|----------|
| D-04 (no commit-msg in Phase 34) | AMENDED | CONTEXT D-27 + inline YAML comment in lefthook.yml + this SUMMARY section |
| D-16 (Read: trailer convention) | implemented | `TRAILER_READ` regex + `--commit-msg-file` entry point |
| D-17 (human bypass) | implemented | `TRAILER_CLAUDE.search(msg)` returns None -> exit 0 silently; 2 pytest cases (`test_human_bypass_pass` + `test_fixture_human_commit_passes`) |
| D-18 (bullet format) | implemented | `bullet_lines` check + pytest `test_read_md_format_no_bullets_fail` |
| D-19 (DIFF-04 Phase 36 deferred) | preserved | No AST, no Claude SDK; fallback-only as planned |
| D-25 (self-test extension) | implemented | 6th section in `lefthook_self_test.sh` |
| D-27 (commit-msg amendment) | LIVE | First use in this plan; future plans need new amendment to add more commit-msg lints |

## Phase 34 Progress

- 5/8 requirements complete: GUARD-04 (Plan 01) + GUARD-02 (Plan 02) + GUARD-03 (Plan 03) + GUARD-05 (Plan 04) + **GUARD-06 (this plan)**
- Pending: GUARD-01 (aggregated via `lefthook.yml` skeleton + parallel + bench — marked via Plan 00 + 07), GUARD-07 (Plan 34-06), GUARD-08 (Plan 34-07)

## Self-Check: PASSED

- [x] tools/checks/proof_of_read.py exists (147 LOC)
- [x] tests/checks/test_proof_of_read.py exists (164 LOC, 12 cases)
- [x] CONTRIBUTING.md exists (27 LOC)
- [x] .planning/phases/34-agent-guardrails-m-caniques/34-05-READ.md exists (14 bullet entries)
- [x] lefthook.yml modified (commit-msg block added)
- [x] tools/checks/lefthook_self_test.sh modified (6th section)
- [x] Commit bab21843 in log (RED test)
- [x] Commit 3789426a in log (GREEN impl)
- [x] Commit d4b5196e in log (wiring + CONTRIBUTING)
- [x] All 12 pytest green
- [x] Self-test 6 sections green
- [x] Benchmark P95 0.090s < 5s budget
- [x] GUARD-06 marked complete in REQUIREMENTS.md
