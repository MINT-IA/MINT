# PR Split Readiness — 2026-04-23

## Executive summary

**Branch:** `feature/S30.7-tools-deterministes`
**Commits ahead of `origin/dev`:** 74 (NOT 76 — see §3 for correction)
**Commits ahead of local `dev`:** 76 — local `dev` is **behind origin/dev by 2** (PR #379, #380 merged upstream but not pulled locally).
**Working tree:** DIRTY (18 modified files + several untracked; see §8).
**Recommended strategy:** **Option A — clean split via cherry-pick onto fresh base**.
**Blockers for immediate PR:**
1. Local `dev` stale vs `origin/dev` — MUST `git fetch && git checkout dev && git merge --ff-only origin/dev` before any split.
2. Working tree DIRTY — 3 ARB files + 15 golden diff PNGs modified, new ADRs untracked, `services/backend/app/services/llm/tier.py` untracked. Stash or commit unrelated work before branching.
3. One real cross-phase file coupling: commit `066fb178` (Phase 34-01) mutates 3 files created by Phase 30.7. PR #1 must land first, then PR #2 rebases.

---

## 1. Commit inventory

Against the correct base `origin/dev` (not stale local `dev`):

| Phase tag | Count | SHA range | First (reverse-chrono first) | Last |
|-----------|------:|-----------|------------------------------|------|
| OTHER (`docs: map existing codebase`) | 1 | — | `1dc68eed` | `1dc68eed` |
| 30.7 (planning + chore) | 9 | `220d84ce..6f8d0882` | `220d84ce` | `6f8d0882` |
| 30.7 (wave 0-4 build) | 21 | `06436aa7..edf468b6` | `06436aa7` | `edf468b6` |
| 34 (planning) | 5 | `b7cea5b8..e6897978` | `b7cea5b8` | `e6897978` |
| 34 (wave 0-7 build) | 30 | `59c8b1a8..0a3f9ed8` | `59c8b1a8` | `0a3f9ed8` |
| 34 (wrap-up) | 2 | `6367ce36..71100dca` | `6367ce36` | `71100dca` |
| 34.1 PRE-HYGIENE (iCloud cleanup) | 1 | — | `e78f6b57` | `e78f6b57` |
| 34.1 (audit + hardening) | 5 | `431f6f40..cc3290d9` | `431f6f40` | `cc3290d9` |
| **TOTAL** | **74** | `1dc68eed..cc3290d9` | | |

**Discrepancy vs prompt numbers (22+22+7=51 ≠ 74):** the prompt's commit counts per phase were approximate. True count per exhaustive tagging is above.

### Per-phase first and last SHAs (authoritative)

- **30.7**: first `220d84ce` (`docs(30.7): smart discuss context`) → last `edf468b6` (`docs(phase-30.7): complete phase execution`). **30 commits** contiguous block.
- **34**: first `b7cea5b8` (`docs(34): capture phase context`) → last `71100dca` (`docs(phase-34): complete phase execution`). **37 commits** contiguous block.
- **34.1**: first `e78f6b57` (pre-hygiene, iCloud cleanup) → last `cc3290d9` (`docs(34.1): SUMMARY`). **6 commits** contiguous block.
- **OTHER**: single commit `1dc68eed` (`docs: map existing codebase`) is the oldest, mutates `.planning/codebase/*.md` only — belongs with Phase 30.7 (it pre-records scout artifacts before planning began).

Order on branch (oldest → newest):

```
1dc68eed  OTHER / map codebase
220d84ce..edf468b6  Phase 30.7 (30 commits, includes 7922be2f chore(gsd))
b7cea5b8..71100dca  Phase 34 (37 commits)
e78f6b57..cc3290d9  Phase 34.1 (6 commits, incl. iCloud hygiene)
```

---

## 2. Non-phase-tagged commits

| SHA | Subject | Disposition |
|-----|---------|-------------|
| `1dc68eed` | `docs: map existing codebase` | **Keep with 30.7** — edits `.planning/codebase/*.md` (scout artifacts), logical prep for 30.7. |
| `7922be2f` | `chore(gsd): integrate CONCERNS.md into autonomous + discuss-phase + record 30.7 planning` | **Keep with 30.7** — references 30.7 explicitly in message; edits `.claude/get-shit-done/workflows/*.md` + `.planning/STATE.md`. |
| `e78f6b57` | `chore: remove 28 iCloud duplicate files (...)` | **Keep with 34.1** — deletion hygiene triggered by Phase 34 audit (message says "Phase 34 audit confirmed 0..."). |

No accidental/squashable commits detected. No stray feature work.

---

## 3. `dev` state vs branch base — CRITICAL

```
$ git branch -vv
  dev                                  2c452e0d [origin/dev: behind 2] ...
* feature/S30.7-tools-deterministes    cc3290d9 [origin/feature/S30.7-tools-deterministes: ahead 42] ...
```

- `origin/dev` tip: `9c29ce1d feat(onboarding): MVP wedge storyboard v2 — 9-tour intent-led flow (#380)`
- Local `dev` tip: `2c452e0d Merge pull request #375 from MINT-IA/hotfix/sync-main-back-to-dev-374`
- 2 commits present on `origin/dev`, absent locally: **PR #379** (`9a35712b fix(coach): opener promise offensive`) and **PR #380** (`9c29ce1d feat(onboarding): MVP wedge storyboard v2`).

**Implication:** the "76 commits ahead" figure in the prompt is measured against stale local `dev`. Against the real target (`origin/dev`), the branch is **74 ahead, 0 behind**. No re-introduction of #379/#380 will occur at PR creation time.

**Merge-base:** `2c452e0d75f6e778f52a75198f76b2453dafd3f5` (= local `dev` tip). Clean ancestor — no history rewrite.

Both remote branches `feature/S77-onboarding-storyboard-v2` and `hotfix/mvp-tier-haiku-economy` also show "behind 2" — confirms whole repo owner needs to `git fetch && git merge --ff-only origin/dev` on local dev.

---

## 4. File overlap matrix

231 unique (file, commit) pairs across 74 commits. **13 files** touched by more than one phase:

### 4a. Cross-phase (30.7 ↔ 34) — the PR split risk zone

| File | Phases | Commits |
|------|--------|---------|
| `tools/checks/accent_lint_fr.py` | 30.7, 34 | `d280e168` (30.7-00 add `scan_text`) + `066fb178` (34-01 reconcile PATTERNS) |
| `tools/mcp/mint-tools/tests/test_check_accent_patterns.py` | 30.7, 34 | `614594e0` (30.7-02 create) + `066fb178` (34-01 update parametrize) |
| `tools/mcp/mint-tools/tests/test_accent_lint_scan_text.py` | 30.7, 34 | `6bbba505` (30.7-00 create) + `066fb178` (34-01 update parametrize) |
| `.planning/ROADMAP.md` | 30.7, 34 | routine planning-state edits |
| `.planning/REQUIREMENTS.md` | 30.7, 34 | routine planning-state edits |
| `.planning/STATE.md` | 30.7, 30.7-CHORE, 34 | routine planning-state edits |

**One single commit (`066fb178`)** is the ENTIRE code-side cross-phase coupling. Message: *"reconcile PATTERNS w/ CLAUDE.md §2 + wire GUARD-04 lefthook … Phase 30.7 TOOL-04 tests … parametrize cases updated in lockstep"*. Clean, intentional, documented.

### 4b. Within-phase (34 ↔ 34.1) — expected/fine

| File | Commits |
|------|---------|
| `tools/checks/proof_of_read.py` | 34 + 34.1 (34.1 hardens 4 bypasses) |
| `tools/checks/no_bare_catch.py` | 34 + 34.1 |
| `tests/checks/test_proof_of_read.py` | 34 + 34.1 |
| `tests/checks/test_no_bare_catch.py` | 34 + 34.1 |
| `CONTRIBUTING.md` | 34 + 34.1 |
| `.github/workflows/lefthook-ci.yml` | 34 + 34.1 |
| `.github/workflows/bypass-audit.yml` | 34 + 34.1 |

34.1 is intentionally a hardening follow-up to 34; bundling them in one PR is the correct call.

---

## 5. PR #1 standalone-green check

Would the 30.7 commits pass CI if landed WITHOUT Phase 34?

| Check | Answer | Evidence |
|-------|--------|----------|
| Does 30.7 depend on any `tools/checks/*` guardrail that only exists in 34? | **No** | 30.7 adds `tools/mcp/mint-tools/` subtree + modifies pre-existing `tools/checks/accent_lint_fr.py`. No dependency on 34's `no_bare_catch.py`, `no_hardcoded_fr.py`, `arb_parity.py`, `proof_of_read.py`. |
| Does CLAUDE.md trim (`43a38dff`) reference lefthook guardrails? | **No** | Trimmed CLAUDE.md only references `tools/checks/accent_lint_fr.py` (pre-existing lint tool, not a Phase 34 artifact). Verified line-by-line. |
| Does 30.7's MCP server require lefthook wiring? | **No** | MCP tools are invoked via Claude Code MCP protocol (`.mcp.json`), unrelated to git hooks. |
| Would 30.7 pytest suite pass on `dev` without 34? | **Yes (expected)** | 30.7 tests live under `tools/mcp/mint-tools/tests/` (44/44 green per commit messages). No import from 34 paths. |

**Verdict:** 30.7 is independently shippable.

## 6. PR #2 rebase-on-top-of-PR-#1 check

If PR #1 (30.7) lands first, PR #2 (34 + 34.1) needs commit `066fb178` to rebase cleanly. Risk surface:

- `tools/checks/accent_lint_fr.py`: 34-01 changes 3 stems (removed `specialistes/gerer/progres`, added `prevoyance/reperer/cle`). No line-number collision with 30.7-00's `scan_text` addition. **Low conflict risk.**
- The two MCP test files: 34-01 "updates parametrize cases in lockstep". Since PR #1 already contains the 30.7-02 version, the lockstep update will apply cleanly. **Low conflict risk.**
- Planning files (`ROADMAP.md`, `REQUIREMENTS.md`, `STATE.md`): likely conflicts on shared sections since both PRs touch the state trackers. **Medium conflict risk** — plan for 15-30 min manual resolution.

---

## 7. Commit message quality scan

- **74 total commits** ahead of `origin/dev`.
- **Co-Authored-By trailer present:** 61/74 (82%).
- **Subject > 72 chars:** 15 commits (acceptable but noisy). Longest = 100 chars (`e78f6b57` iCloud cleanup).
- **Proof-of-Read trailer (GUARD-06, enforced by Phase 34):** Phase 34.1 commits (`611c1233`, `519ebad9`, `cc3290d9`) should have it since they post-date GUARD-06 activation. Worth a spot-check before PR — if absent, `git commit --amend` them or use `--trailer` on rebase.

---

## 8. Working tree state — MUST clean before PR

```
$ git status --short | wc -l
38  (18 tracked modifications + 20 untracked)
```

### Tracked modifications (unrelated to 30.7/34)
- `apps/mobile/lib/l10n/app_localizations_{es,it,pt}.dart` — tiny 1-line drift (single `forfaitFiscalSemanticsLabel` return now includes `$savings`). Likely a `flutter gen-l10n` re-run. Unrelated to this branch's work.
- 15 goldens-failures PNG diffs under `apps/mobile/test/goldens/failures/` and `apps/mobile/test/golden_screenshots/failures/` — should never be tracked (these are test-run output). Consider `.gitignore`.

### Untracked (non-.planning, non-.lefthook)
- 5 ADRs under `decisions/` (ADR-20260415-tax-declaration-*, ADR-20260418-wave-order-daily-loop, ADR-20260419-killed-gamification-layers, ADR-20260501-tax-phase-0-wedge) + `decisions/archive/`.
- `services/backend/app/services/llm/tier.py` (new backend file, unrelated to 30.7/34).

### Numerous "Icon" dup files (`*"<space>2".md`, `*"<space>3".md`)
iCloud is STILL creating duplicates (`.claude/hooks/mint-context-injector 2.js`, etc.) — the same bug Phase 34.1 cleanup fixed. These must be deleted (untracked, safe to `rm`) OR iCloud sync must be paused for this directory before making PRs, otherwise they'll reappear and pollute any follow-up branch.

**Recommendation:** stash the ARB/golden changes + untracked ADRs + tier.py into a separate branch/stash BEFORE branching for PR #2. Do NOT include in 30.7 or 34 PRs.

---

## 9. Split strategy: Option A vs B

### Option A — Cherry-pick onto fresh base (RECOMMENDED)

**Pros:**
- Two clean history segments, each PR reviewable independently.
- PR #1 (30.7) can merge immediately without waiting for Phase 34 review.
- Clear attribution/audit trail per phase.
- Survives force-push of either branch without cross-contamination.

**Cons:**
- Requires creating a new branch for 34+34.1 and cherry-picking.
- `066fb178` + planning-file commits may need minor conflict resolution on rebase.
- 30.7 has 30 commits (not squashed) — reviewer gets verbose history. Squash-at-merge mitigates.

### Option B — Two PRs from same branch, sequential

**Pros:**
- No cherry-pick mechanics.
- Shared branch can keep all history.

**Cons:**
- GitHub PR semantics are awkward: can't easily PR only a commit range to `dev` without a separate ref. Would require marking PR #2 as draft until PR #1 merges, then rebasing.
- Reviewers might confuse scopes; hard to run targeted CI per PR.
- If PR #1 gets feedback requiring an amended commit, all of PR #2 rebases.

**Verdict:** **Option A** is cleaner and matches standard MINT flow (`feature/S{XX}` → PR → squash → cleanup).

### Option C (rejected) — Single PR for everything

Expert panel already rejected. Phase 34 introduces lefthook guardrails that block commits project-wide; bundling with 30.7 means any 30.7 review issue blocks guardrail delivery (and vice versa). Never.

---

## 10. Ready-to-run PR creation commands

**Pre-flight (MANDATORY before any branch mutations):**

```bash
cd /Users/julienbattaglia/Desktop/MINT

# 1. Refresh remotes
git fetch origin --prune

# 2. Clean working tree — pick ONE:
#    a) Stash (safest, reversible):
git stash push -u -m "pre-pr-split unrelated changes 2026-04-23" \
  apps/mobile/lib/l10n/app_localizations_es.dart \
  apps/mobile/lib/l10n/app_localizations_it.dart \
  apps/mobile/lib/l10n/app_localizations_pt.dart
#    b) Discard goldens failures (they should never be tracked):
git restore apps/mobile/test/goldens/failures/ apps/mobile/test/golden_screenshots/failures/
#    Untracked ADRs + tier.py + iCloud " 2"/" 3" dupes: leave untracked OR move to separate branch.

# 3. Sync local dev to origin
git checkout dev
git merge --ff-only origin/dev   # picks up PRs #379, #380
git checkout feature/S30.7-tools-deterministes
```

**Option A — PR #1 (Phase 30.7 ALONE):**

```bash
# Create 30.7-only branch by resetting the current branch at 30.7 tip
git checkout -b feature/S30.7-tools-deterministes-split-30.7 edf468b6
# (edf468b6 = last 30.7 commit; includes 7922be2f chore(gsd) + 1dc68eed map-codebase as ancestors)

# Sanity: confirm exactly 30 commits + 1 map-codebase = 31 ahead of origin/dev
git log --oneline origin/dev..HEAD | wc -l   # expect 31

# Push + PR
git push -u origin feature/S30.7-tools-deterministes-split-30.7

gh pr create --base dev --title "Phase 30.7 — MCP tools déterministes + CLAUDE.md -30%" --body "$(cat <<'EOF'
## Summary
- 4 deterministic MCP tools (`get_swiss_constants`, `check_banned_terms`, `validate_arb_parity`, `check_accent_patterns`)
- FastMCP stdio server wired via `.mcp.json`
- CLAUDE.md trimmed -30% (3/3 dims: lines/bytes/tokens) via tool migration
- 44/44 pytest green on `tools/mcp/mint-tools/`
- Phase execution: 11/12 auto-pass; J0 smoke deferred by plan design (HUMAN-UAT)

## Test plan
- [ ] `cd tools/mcp/mint-tools && pytest` → 44/44 green
- [ ] `python tools/mcp/mint-tools/tests/measure_context_budget.py --assert-delta 30` → exit 0
- [ ] `.mcp.json` discoverable by Claude Code `/mcp`
- [ ] CLAUDE.md TOP+BOTTOM 5 rules preserved byte-for-byte (Liu 2024)
- [ ] J0 smoke test deferred (documented in phase SUMMARY, requires Julien device)

Refs: `.planning/phases/30.7-tools-d-terministes/SUMMARY.md`
EOF
)"
```

**Option A — PR #2 (Phase 34 + 34.1, after PR #1 merges):**

```bash
# After PR #1 merges to dev, sync + branch from updated dev
git checkout dev
git pull --ff-only origin dev
git checkout -b feature/S34-agent-guardrails-mecaniques dev

# Cherry-pick Phase 34 block
git cherry-pick b7cea5b8..71100dca
# (37 commits — first=b7cea5b8 last=71100dca inclusive)

# Cherry-pick 34.1 hygiene + hardening
git cherry-pick e78f6b57..cc3290d9
# (6 commits — first=e78f6b57 last=cc3290d9 inclusive)

# EXPECTED CONFLICT ZONES (resolve manually):
# - .planning/ROADMAP.md, REQUIREMENTS.md, STATE.md: take union or rewrite based on what landed in PR #1
# - tools/checks/accent_lint_fr.py + 2 MCP test files: 066fb178 should apply cleanly since PR #1
#   already contains the 30.7 baseline. If conflict, hand-merge.

# Sanity: confirm ~43 commits ahead of origin/dev
git log --oneline origin/dev..HEAD | wc -l   # expect ~43

git push -u origin feature/S34-agent-guardrails-mecaniques

gh pr create --base dev --title "Phase 34 + 34.1 — Agent guardrails mécaniques (lefthook) + P0 hardening" --body "$(cat <<'EOF'
## Summary
**Phase 34** — 8 GUARD lints wired into lefthook 2.1 pre-commit + commit-msg:
- GUARD-02 `no_bare_catch` · GUARD-03 `no_hardcoded_fr` · GUARD-04 `accent_lint_fr` · GUARD-05 `arb_parity` · GUARD-06 `proof_of_read` · GUARD-07 bypass convention + weekly audit · GUARD-08 CI thinning + D-24 PR re-run
- P95 lint time < 5s (verified)
- 8/8 plans · 10/10 must-haves · 4 deferred to observation-window

**Phase 34.1** — deep audit + hardening after 5 parallel agents surfaced 73 findings:
- 5 P0 bypasses closed (CI workflows + bare_catch regex + proof_of_read)
- CONTRIBUTING.md documents all bypass vectors
- 88/88 pytest green · P95 still 0.100s

## Test plan
- [ ] `./lefthook_self_test.sh` → rc=0
- [ ] `pytest tests/checks/` → all green
- [ ] `lefthook validate` → All good
- [ ] Self-commit: `git commit --allow-empty -m "test"` blocked by GUARD-06 proof_of_read (expected)
- [ ] Bypass `--no-verify` logged by bypass-audit.yml (verify post-merge workflow)

Depends on: Phase 30.7 (PR #XXX merged — provides `tools/mcp/mint-tools/tests/*` baseline that GUARD-04 updates).

Refs: `.planning/phases/34-agent-guardrails-m-caniques/SUMMARY.md`, `34.1-SUMMARY.md`
EOF
)"
```

**Post-merge cleanup (after both PRs land):**

```bash
git checkout dev
git pull --ff-only origin dev
git branch -d feature/S30.7-tools-deterministes
git branch -d feature/S30.7-tools-deterministes-split-30.7
git branch -d feature/S34-agent-guardrails-mecaniques
git push origin --delete feature/S30.7-tools-deterministes feature/S30.7-tools-deterministes-split-30.7 feature/S34-agent-guardrails-mecaniques
```

---

## 11. Risks / gotchas

1. **`gh pr create` default `--base main`.** Always pass `--base dev`. This is locked project doctrine (see MEMORY.md `feedback_gh_pr_create_base_branch` — #374/2026-04-21 incident).

2. **30-commit PR visibility.** PR #1 carries 30+ commits from 30.7 plan/wave work. Use GitHub "squash and merge" at merge time to keep `dev` history clean. Do NOT let GitHub "rebase and merge" explode the history into 30 separate commits on `dev`.

3. **Squash-at-merge loses individual commit Co-Authored-By trailers.** GitHub's squash UI aggregates them but reviewers often accept the default single-author squash message. Manually edit the squash message to include all Co-Authored-By lines before confirming merge.

4. **Phase 34 self-enforcement risk on PR #2.** PR #2 introduces GUARD-06 `proof_of_read` commit-msg hook. Any further amend/force-push to PR #2 after local lefthook install will require the trailer. If reviewers ask for a fix-up commit, run it through lefthook locally first, otherwise `--no-verify` bypass will be flagged by the freshly-shipped weekly audit.

5. **iCloud duplication ongoing.** Git status shows many `Icon` "2"/"3" dupes in untracked state even after Phase 34.1 cleanup. Either pause iCloud sync on `/Users/julienbattaglia/Desktop/MINT.nosync` (already `.nosync` suffix suggests attempted — verify), or add more aggressive `.gitignore` patterns for ` [0-9]*.{md,js,mjs,sh,html,jsx,txt,png}`. This pollutes any new branch.

6. **Local `dev` drift of 2 commits** (PRs #379, #380). Trivial, but every other sibling branch in the repo shows "behind origin/dev by 1-2" — worth a broadcast message if multiple people push to this repo (safe for solo developer).

7. **Stale `origin/feature/S30.7-tools-deterministes` is 42 commits behind HEAD.** On push, GitHub will show the huge delta. Consider a `git push --force-with-lease` on this branch ONLY if nobody else is consuming it, otherwise create the new `-split-30.7` name (Option A in §10 already does this).

8. **Cherry-pick of `e78f6b57` (iCloud cleanup, 28 file deletions) onto fresh dev.** If dev has seen any iCloud re-creation since the cleanup commit was originally made, cherry-pick may report "already applied" on some deletions or fail on non-existent paths. Watch for `git cherry-pick --skip` prompts.

---

## Appendix: tagged commit list (reverse chrono)

Full inventory at `/tmp/commit-inventory.txt` (74 lines). Phase assignment in `/tmp/phase-file.txt` (169 (phase, file) pairs). Abbreviated:

```
cc3290d9  34.1   docs(34.1): SUMMARY — 5 P0 closed, 88/88 pytest, P95 0.100s
519ebad9  34.1   docs(34.1): document ALL bypass vectors in CONTRIBUTING.md (Fix #5)
611c1233  34.1   fix(34.1): harden proof_of_read — close 4 audit P0 bypasses
167738ac  34.1   fix(34.1): close 3 critical bypasses — CI workflows + bare_catch regex
431f6f40  34.1   docs(34.1): capture deep audit of Phase 34 (5 parallel agents, 73 findings)
e78f6b57  34.1   chore: remove 28 iCloud duplicate files (PRE-HYGIENE)
71100dca  34     docs(phase-34): complete phase execution (8/8 plans)
...                 (33 more Phase 34 commits b7cea5b8..0a3f9ed8)
edf468b6  30.7   docs(phase-30.7): complete phase execution
...                 (28 more Phase 30.7 commits 220d84ce..97c31822)
7922be2f  30.7   chore(gsd): integrate CONCERNS.md + record 30.7 planning
6f8d0882  30.7   docs(30.7): roadmap updated with 5-plan list
...                 (6 more 30.7 planning commits 25339d12..220d84ce)
1dc68eed  OTHER  docs: map existing codebase
```

**End of report.**
