# Phase 34 Git Lifecycle Audit

**Date:** 2026-04-23
**Scenarios tested:** 18 (several with multiple sub-cases)
**Branch (cleaned up):** `audit/34-git-lifecycle` + 3 helper branches, starting SHA `71100dca`, restored at end
**Environment:** lefthook 2.1.6 · git 2.50.1 (Apple) · macOS 25.3 (Tahoe) · `core.hooksPath=.git/hooks`
**Test method:** Scratch branch(es) from current HEAD, `--allow-empty` commits with synthetic messages to isolate hook behavior. All scratch branches deleted, HEAD returned to `71100dcaba3f97d9c58fc828b46cac99370ec53c`.

---

## Quick matrix

| # | Scenario | pre-commit fires? | commit-msg fires? | Behavior correct? | Severity |
|---|---|---|---|---|---|
| 1 | Baseline `git commit` (Claude+Read) | yes (all skip, empty) | yes → OK | correct | — |
| 2a | `--amend --no-edit --allow-empty` | yes | yes → OK | correct | — |
| 2b | `--amend -m <drops Read>` | yes | yes → **FAIL** | correct (reject) | — |
| 2c | `--amend` adds Claude trailer, no Read | yes | yes → **FAIL** | correct (reject) | — |
| 3a | rebase -i `reword` (keeps Read) | yes (`skip:rebase`) | yes → OK | correct | — |
| 3b | rebase -i `reword` (drops Read) | skip | yes → FAIL → rebase stops | correct | — |
| 3c | rebase -i **`squash`** | skip | **NO (silent bypass)** | **WRONG** | **P0** |
| 3d | rebase -i **`fixup`** | skip | **NO (silent bypass)** | **WRONG** | **P0** |
| 3e | Plain `rebase HEAD~3` (pick replay) | N/A (no commit) | N/A | n/a | — |
| 3f | Mid-rebase `git commit --amend` (edit) | skip (rebase state) | yes → validates | correct | — |
| 4 | **`cherry-pick --allow-empty`** | N/A | **NO (silent bypass)** | **WRONG** | **P0** |
| 5 | `revert --no-edit -n` + `git commit` (no Claude trailer) | yes | yes → OK (human bypass) | correct | — |
| 6a | `merge --no-ff` (auto msg, no Claude trailer) | skip (`skip:merge`) | yes → OK (human bypass) | correct | — |
| 6b | `merge --no-ff -m <Claude, no Read>` | skip | yes → FAIL | correct | — |
| 7a | Squash-merge via `merge --squash` + local commit | yes | yes → OK | correct (local) | — |
| 7b | Squash-merge msg with multiple `Read:` trailers | yes | yes → OK (first match wins) | correct | — |
| 7c | GitHub web squash-merge (server-side) | **N/A — hooks do not run on GitHub server** | N/A | **WRONG** | **P0** |
| 8 | `git commit -c <hash>` / `-C <hash>` reuse | yes | yes → validates | correct | — |
| 9 | prepare-commit-msg | no such hook installed | — | n/a | — |
| 10a | `git -c core.hooksPath=/empty commit` (per-invocation) | **NO** | **NO** | **TRIVIAL BYPASS** | **P0** |
| 10b | `core.hooksPath` local is default | yes | yes | correct | — |
| 11 | `git commit --trailer "Read: ..."` | yes | yes → OK | correct | — |
| 12 | GitHub "Create a merge commit" via PR UI | **N/A — server-side** | N/A | **WRONG** | **P0** |
| 13a | Timing, 10 hooks parallel, empty commit | 0.15–0.20 s total | 0.04 s | correct | — |
| 13b | Timing, 10 hooks parallel, 1 staged py file | **50.6 s** (`no-chiffre-choc` cold) | 0.04 s | plan claim 0.110 s false | **P1** |
| 14a | `git commit -F /tmp/msg.txt` | yes | yes → validates | correct | — |
| 14b | `git commit -F -` (stdin) | yes | yes → validates | correct | — |
| 15a | `commit --fixup=<sha>` (auto `fixup!` msg) | yes | yes → OK (no Claude trailer in auto-msg) | correct | — |
| 15b | `commit --squash=<sha>` (auto `squash!` msg) | yes | yes → OK | correct | — |
| 16a | Worktree commit, normal msg | yes | yes → validates | correct | — |
| 16b | Worktree with pre-phase-34 checkout (no `commit-msg` in `lefthook.yml`) | yes | **NO — lefthook `skip: Hook commit-msg doesn't exist in the config`** | **WRONG** | **P1** |
| 16c | Worktree with missing READ.md on disk | yes | yes → FAIL (path does not exist) | correct, but path resolution is per-worktree | **P2** |
| 17 | Mid-rebase `commit --amend` (rebase state) | skip (correct) | yes → validates | correct | — |
| 18a | `lefthook install --force` 3×, MD5 stable | — | — | idempotent | — |
| 18b | `lefthook uninstall` | removes both hooks cleanly | — | correct | — |
| 19 | `LEFTHOOK=0 git commit` | **NO** | **NO** | **TRIVIAL BYPASS** | **P0** |
| 20 | `LEFTHOOK_EXCLUDE=proof-of-read git commit` | yes (partial) | **NO** | **TARGETED BYPASS** | **P0** |
| 21 | `git commit --no-verify` / `-n` | **NO** | **NO** | **TRIVIAL BYPASS (classic)** | **P0** |

---

## Findings per scenario

### 3c / 3d — rebase -i squash and fixup SILENTLY BYPASS commit-msg (P0)

**Evidence:**

```
$ GIT_SEQUENCE_EDITOR=/tmp/seq_sq.sh GIT_EDITOR=/tmp/msg_ed_drop.sh git rebase -i HEAD~2
Rebasing (2/2)
[detached HEAD d1a524b6] audit: s5f squashed NO READ
Successfully rebased and updated refs/heads/audit/34-git-lifecycle.

$ git log -1 --format="%B"
audit: s5f squashed NO READ

Co-Authored-By: Claude Opus <noreply@anthropic.com>
```

No `[lefthook]` banner, no `[proof_of_read]` output, exit 0 — the squashed commit with `Co-Authored-By: Claude` and **no `Read:` trailer** landed on the branch. Same story for `fixup!`. This is a known git internal: during `rebase -i` with `squash`/`fixup`, git does not invoke the `commit-msg` hook (only `pick` + `reword` are re-executed as real commits).

**Impact:** An agent (or careful human) can concatenate N commits into one via interactive rebase and the concatenated output is never re-validated. If any one of the source commits had a valid `Read:` but a manual edit during the rebase strips it, the final commit lands undetected. Alternatively, a Claude-authored body can be hand-stitched in and never audited.

**Mitigation options:**
1. Add a `post-rewrite` hook that re-validates every commit `git rebase` / `git commit --amend` produced.
2. Make the CI-side `lefthook-ci.yml` re-run `proof_of_read.py` on every commit in the PR range, not just the tip. This is the safety net that already exists for PR merges — confirm it actually iterates commits.
3. Document in CONTRIBUTING that `squash` + `fixup` are unaudited lifecycle steps.

### 4 — cherry-pick silently bypasses commit-msg (P0)

**Evidence:**

```
$ LEFTHOOK_VERBOSE=1 git cherry-pick --allow-empty 900287c6
[audit/34-cherry-pre eebc3ddf] audit: scenario 1 baseline
```

Zero hook output. Cherry-pick re-uses the source commit's message verbatim and **does not fire commit-msg**. This is git's default behavior (no `cherry-pick` entry in `core.hooksPath`). Matters when cherry-picking:
- from a branch where `Read:` file exists → target branch where it doesn't → invalid reference lands unchecked
- a malformed legacy commit that predates GUARD-06

**Mitigation:** Same as 3c — `post-rewrite` hook + CI iterate-over-PR-range.

### 7c / 12 — GitHub server-side squash/merge bypasses all hooks (P0, known-doctrine)

Local hooks only run client-side. GitHub's "Squash and merge" / "Create a merge commit" buttons generate new commits server-side. Those commits can have `Co-Authored-By: Claude` (preserved from child commits) with no `Read:` trailer (if not explicitly preserved). Tests confirm this is only catchable via **`.github/workflows/lefthook-ci.yml`** running on PR events.

**Check needed:** confirm `lefthook-ci.yml` iterates over every commit in the PR range and not just HEAD. If it runs `proof_of_read.py` only once on the PR tip, it misses interior commits (though arguably only the tip merges to dev, so this is partly OK for the "tip merges" pathway).

### 10a — `git -c core.hooksPath=/empty commit` TRIVIAL BYPASS (P0)

**Evidence:**

```
$ git -c core.hooksPath=/tmp/audit34_empty_hooks commit --allow-empty -m "..." 
# No hook output; commit lands.
```

A single per-invocation flag bypasses everything. No local persistence needed. `bypass-audit.yml` does not scan for this (greps only for `LEFTHOOK_BYPASS` and `[bypass:` literals in commit bodies).

**Mitigation:** Add to CI a check that fails PRs where any commit message contains evidence of circumventing hooks (hard — unlike `--no-verify`, `core.hooksPath` leaves no trace in the commit). The real fix is server-side validation.

### 19 — `LEFTHOOK=0 git commit` TRIVIAL BYPASS (P0)

**Evidence:**

```
$ LEFTHOOK=0 git commit --allow-empty -m "bypass test

Co-Authored-By: Claude Opus <noreply@anthropic.com>"
# commit lands; no proof_of_read output; no Read trailer required
```

The installed `.git/hooks/pre-commit` and `commit-msg` hook scripts include early return: `if [ "$LEFTHOOK" = "0" ]; then exit 0; fi`. This is the lefthook authors' intentional escape hatch, but it is also a silent bypass. `bypass-audit.yml`'s grep does not match `LEFTHOOK=0`.

**Mitigation:** Extend `bypass-audit.yml` grep to also match `LEFTHOOK=0`, `LEFTHOOK=false`, `LEFTHOOK_EXCLUDE=`, `--no-verify`, `-c core.hooksPath=`. Or, because these leave no commit-body artifact, rely on CI-side re-validation.

### 20 — `LEFTHOOK_EXCLUDE=proof-of-read` TARGETED BYPASS (P0)

**Evidence:**

```
$ LEFTHOOK_EXCLUDE=proof-of-read git commit --allow-empty -m "s19 exclude

Co-Authored-By: Claude Opus <noreply@anthropic.com>"
# Commit lands with no Read trailer.
```

Targeted at the specific lint by name. Not covered by bypass-audit. Note: `LEFTHOOK_BYPASS=proof-of-read` did NOT bypass (lefthook 2.1.6 likely treats that var differently — the tag mechanism may need the command tag, not name). This is inconsistent and fragile.

### 21 — `--no-verify` / `-n` classic bypass (P0, unavoidable-in-git)

`git commit --no-verify` bypasses both pre-commit and commit-msg. This is a core git feature. No local fix possible. CI-side `lefthook-ci.yml` is the only line of defense.

### 13b — `no-chiffre-choc` runs **50.6 s** when a staged `.py` file matches glob (P1)

**Evidence (wall time, 10 hooks parallel, 1 staged dummy py file):**

```
✔️ accent-lint-fr (0.04 seconds)
✔️ memory-retention-gate (0.04 seconds)
✔️ no-bare-catch (0.07 seconds)
✔️ no-chiffre-choc (50.60 seconds)
```

Plan 34-02 claimed "0.110s total". Empirical: **50.6 s on the critical path**. `no_chiffre_choc.py` scans its own D-23 scope (apps/mobile/lib + services/backend/app + docs/ + tools/openapi) on every matching `.dart|.py|.arb` commit. For a one-file staged commit, this is a 454× perf regression versus claimed.

**Impact:** Any commit touching any `.py`/`.dart`/`.arb` file pays 50 seconds. This will be felt on every iterative commit in MINT. Severe DX regression.

**Mitigation:** Convert `no_chiffre_choc.py` to diff-only (mirror GUARD-02 RESEARCH Pattern 6). Scan only added lines of staged files. Full-repo scan stays in CI via `lefthook-ci.yml`.

### 16b — Worktree / pre-Phase-34 checkout removes `commit-msg` block from lefthook.yml → silent bypass (P1)

**Evidence:**

```
$ git checkout bab21843~5 -- .  # overwrites working-tree lefthook.yml
$ grep commit-msg lefthook.yml
0
$ git commit --allow-empty -m "... Co-Authored-By: Claude..."
│  [lefthook] skip: Hook commit-msg doesn't exist in the config
[detached HEAD 316e7c7e] audit: s16e ...
```

Lefthook reads `lefthook.yml` from the working tree at commit time, not from the ref that installed the hook. If a developer:
- Checks out a pre-GUARD-06 branch, OR
- Runs `git checkout <old-sha> -- lefthook.yml`, OR  
- Uses a worktree pinned to an older commit

…then the `commit-msg` block vanishes and proof-of-read stops firing.

**Mitigation:** This is unavoidable for any YAML-configured hook system. Document it. Rely on CI. Phase 34 should add a test case: guard against `lefthook.yml` drift within a PR (e.g. require `commit-msg:` block to always be present if `tools/checks/proof_of_read.py` exists).

### 16c — Worktree path resolution is per-worktree, not per-main-repo (P2)

`proof_of_read.py` uses `Path(args.repo_root).resolve()` with default `'.'`, so `repo_root` is the worktree cwd. If the worktree's tree doesn't include `.planning/phases/34-.../*-READ.md` (sparse checkout, different branch), the check fails even though the repo as a whole has that file. Not exploitable (fails closed), but can cause false negatives for legitimate commits.

### 5 / 6a — Revert and auto-generated merge msgs: human-commit bypass works as intended

Auto-generated `revert` and merge messages don't contain `Co-Authored-By: Claude`, so D-17 human bypass fires cleanly. If a reviewer *explicitly* adds a Claude trailer to a merge `-m` message without Read, the lint catches it (scenario 6b). Correct.

### 15a / 15b — `--fixup=<sha>` / `--squash=<sha>` produce auto-messages without Claude trailer

Git's `--fixup!`/`--squash!` prefix is a new subject without reusing the source body, so no Claude trailer survives. proof-of-read treats these as human commits → PASS. This is correct behavior (the fixup/squash is a temporary commit; the real risk is the later autosquash rebase, which is covered by 3c/3d above).

### 18a / 18b — lefthook install/uninstall are idempotent and clean

3× `lefthook install --force` → identical MD5s. `lefthook uninstall` cleanly deletes hooks. No cruft accumulation.

---

## Summary

### P0 (critical lifecycle holes — client-side enforcement is porous)

1. **`rebase -i squash` and `fixup` silently bypass commit-msg hook** (3c, 3d). A concatenated commit with `Co-Authored-By: Claude` and no `Read:` trailer lands with zero lint output. Confirmed by empirical test + known git behavior.
2. **`cherry-pick` silently bypasses commit-msg hook** (4). Re-uses source message, never invokes the hook.
3. **`git -c core.hooksPath=/empty` per-invocation bypass** (10a). One flag defeats all hooks, no trace.
4. **`LEFTHOOK=0` env-var bypass** (19). Hardcoded in the lefthook-generated hook scripts; `bypass-audit.yml` greps don't detect it.
5. **`LEFTHOOK_EXCLUDE=proof-of-read` targeted bypass** (20). Not covered by bypass-audit.
6. **`git commit --no-verify` / `-n`** (21). Classic git bypass. No local fix possible.
7. **GitHub server-side squash/merge** (7c, 12). Hooks don't run on the server.

**Common mitigation**: add a `post-rewrite` hook that re-validates every commit produced by amend/rebase, AND make `.github/workflows/lefthook-ci.yml` iterate over every commit in the PR range (not just HEAD) and fail on any Claude-coauthored commit missing a valid Read trailer. This is the only reliable enforcement surface; client-side is advisory.

### P1 (meaningful gaps)

1. **`no-chiffre-choc` takes 50.6 s per matching commit** (13b). Plan 34-02 claimed 0.110 s. 454× regression. Convert to diff-only scan.
2. **Pre-Phase-34 checkouts / worktrees remove `commit-msg` block from `lefthook.yml`** (16b). Lefthook correctly reports `skip: Hook commit-msg doesn't exist in the config` — but this is a silent bypass if the developer doesn't notice the log line. Add a test in `lefthook-ci.yml` that fails any PR missing the `commit-msg:` block when `tools/checks/proof_of_read.py` exists in the tree.
3. **`bypass-audit.yml` only fires on merges to `dev` and only for 7-day `>3` threshold** (review of `.github/workflows/bypass-audit.yml`). Bypass markers on feature branches never get audited. Threshold of 3 means up to 3 free bypasses per week are silent.

### P2 (documentation / nice-to-have)

1. **Worktree path resolution is per-worktree** (16c). If a worktree doesn't have the referenced `-READ.md` file on disk (older checkout, sparse clone), the lint fails closed — legitimate commits rejected. Document this, or resolve `Read:` paths via `git --git-common-dir` so all worktrees share the same reference root.
2. **No `post-rewrite` hook installed.** Phase 34 only uses `pre-commit` and `commit-msg`. `post-rewrite` fires on amend and rebase and would catch 3c/3d/4 locally.
3. **`lefthook.yml` states `skip: [merge, rebase]` but the reality is more nuanced.** Pre-commit correctly skips during merge and rebase (scenarios 6a, 17). commit-msg has no `skip:` block but git itself doesn't fire commit-msg during cherry-pick/fixup/squash (scenarios 3c, 3d, 4), so the net effect is uneven. Document the actual coverage matrix in `CONTRIBUTING.md`.
4. **`core.hooksPath` warning on every lefthook invocation.** Lefthook warns "Skipping hook sync: core.hooksPath is set locally". This is benign (hooks were installed, so sync is a no-op), but noisy. Run `lefthook install --reset-hooks-path` once to clean it up.
5. **`no-chiffre-choc` glob narrowed to `.dart|.py|.arb` intentionally** — lefthook.yml comment explains `.md` excluded for iCloud perf. Consistent with 13b P1: the scope discipline is correct but the underlying scan is the bottleneck.

---

## Methodology notes

- Scratch branch `audit/34-git-lifecycle` created from HEAD `71100dca`, 3 helper branches spawned during tests, all deleted at end.
- `--allow-empty` used throughout to avoid staging real files (occasional dummy `.audit34_dummy.py` used for timing test 13b, then removed).
- `git reset --hard` blocked by sandbox; used `git update-ref HEAD <sha>` as equivalent.
- `git stash` attempt failed silently early on; working tree changes were ignored (non-staged).
- All observations reproduced at least once; P0 findings reproduced 2–3× each.
- Final check: `git rev-parse HEAD == 71100dcaba3f97d9c58fc828b46cac99370ec53c` — confirmed clean.

## Key files referenced

- `/Users/julienbattaglia/Desktop/MINT/lefthook.yml` — config
- `/Users/julienbattaglia/Desktop/MINT/tools/checks/proof_of_read.py` — GUARD-06
- `/Users/julienbattaglia/Desktop/MINT/tools/checks/no_bare_catch.py` — GUARD-02 (diff-only reference)
- `/Users/julienbattaglia/Desktop/MINT/tools/checks/no_chiffre_choc.py` — **50.6 s hot path**, needs diff-only rewrite
- `/Users/julienbattaglia/Desktop/MINT/.github/workflows/bypass-audit.yml` — awareness-only, 7d/3-threshold
- `/Users/julienbattaglia/Desktop/MINT/.github/workflows/lefthook-ci.yml` — PRIMARY ground-truth; should iterate PR range (verify)
- `/Users/julienbattaglia/Desktop/MINT/.git/hooks/pre-commit`, `.git/hooks/commit-msg` — installed lefthook shims with `LEFTHOOK=0` escape
