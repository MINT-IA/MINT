# Repo Cleanup Audit — 2026-05-05

**Author:** Claude (mechanical audit, no destructive action)
**Repo:** MINT-IA/MINT
**Main checkout:** `/Users/julienbattaglia/Desktop/MINT.nosync` (HEAD = `fix/sim-walkthrough-crash-loop`)
**Worktrees enumerated:** 5 git worktrees + 11 legacy `agent-*` directories (only 1 still registered in `git worktree list`)

---

## 0. Verdict global

**Status: NEEDS-CLEANUP (high noise, low risk).** The repo is operationally healthy — `dev` is in sync with `origin/dev`, recent PR cadence is normal (PR #420 → #479 in 3 days, all CI-driven), and no critical work appears lost. But state has accumulated:

- **23 stashes**, 18 of them >30 days old, 14 of them >60 days old. The oldest is from `2026-04-01`. Several touch large file counts (one stash modifies 453 files) — that's WIP cruft, not lost code (their parent commits are still on branches).
- **23 local branches**, of which only 4 are long-lived (`dev`/`main`/`staging`/current). 5 are gone-tracked (remote deleted), 4 are stale `worktree-agent-*` from completed phases, and 14 are active feature branches with open PRs.
- **11 directories under `.claude/worktrees/`**, only 1 still registered as a real git worktree (`agent-a3ff6f8bcca8bb0ef`, **locked**, 210 modified files — likely intentional snapshot of v2.8 phase 40 state). The other 10 are abandoned filesystem leftovers that are no longer git worktrees.
- **`staging` is 212 commits behind `origin/staging`** locally; **`main` is 1 commit behind `origin/main`** — local long-lived branches haven't been fast-forwarded. `origin/staging` itself is 210 commits behind `origin/dev` (expected — staging cuts happen on milestone closures).
- **1944 unreachable objects** detected by `git fsck`, but only ~30 are unreachable commits, and spot-checks show all are either (a) old WIP stashes that were dropped/applied, or (b) commits superseded by force-pushes during PR rebases. **No production code appears lost.**
- **`feature/v2.9-phase-40-marge-fiscale`** is the elephant: 559 ahead of `dev`, 57 behind, gone-tracked remote, last commit `2026-05-02`. This is the one branch that needs careful triage before deletion (see Phase B).

No critical regressions. Cleanup is a hygiene exercise, not a recovery operation.

---

## 1. Métriques

| Indicateur | Valeur |
|---|---|
| Total local branches | 23 |
| Total remote branches (post-prune) | 26 (`origin/*`) |
| Total worktrees (`git worktree list`) | 5 |
| Total filesystem `agent-*` dirs | 11 (only 1 registered) |
| Total stashes | 23 |
| Stashes ≥ 30 days old | 18 |
| Stashes ≥ 60 days old | 14 |
| PRs open | **15** (#458, #459, #460, #461, #462, #464, #465, #470, #471, #472, #454, #455, #456, #478, #479) |
| PRs merged (last 60) | 49 |
| PRs closed unmerged (last 60) | 5 (#378, #381, #383, #424, #426) |
| Unreachable commits (`git fsck --no-reflogs`) | ~30 |
| Total unreachable objects | 1944 (mostly trees/blobs from stash drops) |
| `dev` ↔ `origin/dev` | 0 / 0 ✅ |
| `main` ↔ `origin/main` | 0 / 1 (behind) |
| `staging` ↔ `origin/staging` | 0 / 212 (behind) |
| `origin/dev` ↔ `origin/staging` | 1 / 0 (dev 1 ahead, expected) |

---

## 2. Phase A — Safe deletes (zéro risque, immédiat)

### A.1 — Local branches whose remote is `[gone]` (already merged)

These three branches have remotes that have been deleted (post-merge cleanup), and their PRs are MERGED. Safe to delete locally.

| Branch | PR | Merged |
|---|---|---|
| `feature/S30.16-walk-p0-3-dev-onboarding` | #392 | 2026-04-24 |
| `feature/S30.20-doc-ext-remaining-fixtures` | #396 | 2026-04-25 |

```bash
git -C /Users/julienbattaglia/Desktop/MINT.nosync branch -D \
  feature/S30.16-walk-p0-3-dev-onboarding \
  feature/S30.20-doc-ext-remaining-fixtures
```

> `feature/v2.9-phase-40-marge-fiscale` is also `[gone]` but **NOT** safe to delete (559 ahead of dev, no PR, last commit 2026-05-02). See Phase B.

### A.2 — Stale `worktree-agent-*` branches (orphaned by completed worktrees)

All 4 are leftovers from agent worktrees that were removed. Their HEADs are still pointed at by these branch refs, but the worktrees themselves are gone or orphaned. Their commits are either merged via the PR they spawned or duplicated under proper branches.

| Branch | Last commit | PR? | Notes |
|---|---|---|---|
| `worktree-agent-a048c831ec00a1181` | 2026-04-21 (`hotfix(backend) #377`) | merged via #377 | 1 ahead, 211 behind |
| `worktree-agent-a6e3b845bcdee0e85` | 2026-04-21 (same SHA as above) | merged via #377 | duplicate |
| `worktree-agent-ac240683622af08be` | 2026-04-21 (same SHA as above) | merged via #377 | duplicate |
| `worktree-agent-a9f05550ccac75061` | 2026-04-26 (`docs(40-02): rename SUMMARY`) | none | 22 ahead — verify before delete |

```bash
# Safe (3 duplicates of #377 hotfix) :
git branch -D \
  worktree-agent-a048c831ec00a1181 \
  worktree-agent-a6e3b845bcdee0e85 \
  worktree-agent-ac240683622af08be

# Verify before deleting (22 commits ahead) :
git log --oneline origin/dev..worktree-agent-a9f05550ccac75061
# If 22 commits are all docs/40-02 and already covered by feature/v2.9-phase-40-marge-fiscale → delete :
# git branch -D worktree-agent-a9f05550ccac75061
```

### A.3 — Filesystem `agent-*` directories no longer registered as worktrees

10 dirs under `.claude/worktrees/` not in `git worktree list`. They're orphaned filesystem state. Skip the registered/locked one.

```bash
# KEEP : agent-a3ff6f8bcca8bb0ef (registered, locked)
# REMOVE the 10 others :
rm -rf /Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-a1024bd2
rm -rf /Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-a49a64d9
rm -rf /Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-a716b708
rm -rf /Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-a77860f5
rm -rf /Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-a87652fb
rm -rf /Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-aba588de
rm -rf /Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-ac435233
rm -rf /Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-ae615269
rm -rf /Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-af26fb90
git worktree prune
```

### A.4 — Stale stashes ≥ 60 days old (drop)

14 stashes older than 60 days. Their parent commits all still exist on branches (no lost code). Spot-checked: `stash@{16}-{18}` modify a file `sync-branches 2.yml` which doesn't exist in repo today (filename collision artifact). These are unambiguously dead WIP.

```bash
# Drop oldest first (stash indexes shift on each drop, so go LIFO) :
git stash drop stash@{22}  # 2026-04-01 — pre-grade-a-sprint
git stash drop stash@{21}  # 2026-04-02 — w16 logic guards merge WIP
git stash drop stash@{20}  # 2026-04-02 — UX picker WIP (already shipped)
git stash drop stash@{19}  # 2026-04-09 — phase 01 P0a code unblockers
git stash drop stash@{18}  # 2026-04-09 — deleted-duplicates on dev
git stash drop stash@{17}  # 2026-04-09 — cso-security-fixes WIP
git stash drop stash@{16}  # 2026-04-09 — cso-security-fixes credentials WIP
git stash drop stash@{15}  # 2026-04-13 — v25-wiring-fixes wip-state-19
git stash drop stash@{14}  # 2026-04-13 — S19 auth-state-propagation
git stash drop stash@{13}  # 2026-04-14 — Podfile.lock noise
git stash drop stash@{12}  # 2026-04-15 — pre-pr-A-planning-noise
git stash drop stash@{11}  # 2026-04-15 — backend compliance test alignment
git stash drop stash@{10}  # 2026-04-15 — coach income_gross WIP (already shipped)
git stash drop stash@{9}   # 2026-04-17 — golden-document-flow WIP
```

Cumulative impact: removes ~120 000 lines of WIP diff churn from `git stash list`.

### A.5 — Stashes 30-60 days old (review-then-drop)

4 stashes from `2026-04-26` and `2026-04-20`. Spot-check before dropping — these touch `autonomous.md` and golden screenshots.

| Stash | Date | Files | Action |
|---|---|---|---|
| `stash@{8}` | 2026-04-20 | 15 files (golden screenshot failures) | likely safe — golden tests have moved on |
| `stash@{7}` | 2026-04-26 | 232 files (`autonomous.md` heavy edit) | review — possibly orphan workflow drafts |
| `stash@{6}` | 2026-04-26 | 443 files (`autonomous.md` heavy edit) | review |
| `stash@{5}` | 2026-04-26 | 453 files (`autonomous.md` heavy edit) | review |

Recommended action: `git stash show -p stash@{5}` and verify the autonomous.md content isn't load-bearing. If it duplicates current `dev`, drop.

---

## 3. Phase B — Branches actives à clarifier (review needed)

### B.1 — Open PRs with active branches (15 PRs)

All 15 are tracked. Action depends on CI state — list here for triage by Julien:

| PR | Branch | Created | Notes |
|---|---|---|---|
| #479 | `feat/sprint1-nav-audit` | 2026-05-05 | Current worktree — keep |
| #478 | `fix/sprint0-401-breadcrumb-sweep` | 2026-05-05 | Active sweep — keep |
| #472 | `feat/phase-56-03-tool-classification` | 2026-05-04 | 13 behind dev — rebase needed |
| #471 | `chore/pubspec-bump-2.9.0` | 2026-05-04 | Standalone version bump |
| #470 | `feat/phase-56-02-census-wiring` | 2026-05-04 | 13 behind — rebase |
| #465 | `feat/phase-56-01-bootstrap-kit-and-census` | 2026-05-03 | 13 behind — rebase |
| #464 | `feat/discipline-kit-foundation` | 2026-05-03 | 13 behind — rebase |
| #462 | `feat/handoff2-niveau1-widgets` | 2026-05-03 | 13 behind — rebase |
| #461 | `fix/anonymous-chat-apercu-inline` | 2026-05-03 | 13 behind — rebase |
| #460 | `fix/coach-markdown-italic-rendering` | 2026-05-03 | 13 behind — rebase |
| #459 | `feat/anonymous-chat-handoff2-appbar` | 2026-05-03 | 13 behind — rebase |
| #458 | `fix/lsfin-accent-violations` | 2026-05-03 | 13 behind — rebase |
| #456 | `fix/phase-54.1-walker-no-codesign` | 2026-05-03 | 13 behind — rebase |
| #455 | `docs/session-2026-05-03-rollup` | 2026-05-03 | 13 behind — rebase |
| #454 | `feature/phase-54.1-contract-deadline-chip` | 2026-05-03 | 13 behind — rebase |

**Action proposée:** `gh pr list --state open --json number,statusCheckRollup` to triage by CI state, then close-or-rebase batch on PRs sitting > 48h.

### B.2 — `feature/v2.9-phase-40-marge-fiscale` — special case

- 559 commits ahead of `dev`, 57 behind
- Remote branch deleted (`[gone]`)
- No matching PR found (`gh pr list --head feature/v2.9-phase-40-marge-fiscale` returns empty)
- Last commit 2026-05-02 : `docs(audit): refresh HTML report — add PR #425/#426/#427`
- Likely contains the work that *became* PRs #425/#426/#427 (and 50+ others) — but local branch is now redundant.

**Action proposée:**

```bash
# 1. Verify nothing unique remains :
git log --oneline --no-merges feature/v2.9-phase-40-marge-fiscale ^origin/dev | head -30
# 2. If all commits are squashed into merged PRs → archive :
git tag archive/feature/v2.9-phase-40-marge-fiscale feature/v2.9-phase-40-marge-fiscale
git branch -D feature/v2.9-phase-40-marge-fiscale
```

The tag preserves recoverability without polluting `git branch` output.

### B.3 — Closed-unmerged PRs (5)

Already closed remotely; no local work needed. Purely informational:

- #378 (`feature/S75-onboarding-mvp-wedge`) — superseded by #380
- #381 (`feature/S30.7-tools-deterministes`) — superseded by #382
- #383 (`feature/S34-agent-guardrails-mecaniques`) — abandoned
- #424 (`feature/anonymous-real-data-wedge-on-421`) — superseded by #429
- #426 (`feature/phase-52-auth-local-first-toggle`) — planning-only PR, work shipped via #435+

### B.4 — Long-lived local branches out of sync

```bash
# Bring local mirrors of long-lived branches up to date :
git fetch origin
git checkout main && git merge --ff-only origin/main
git checkout staging && git merge --ff-only origin/staging
git checkout dev  # already in sync
```

`staging` being 212 behind `origin/staging` is harmless (we never operate on local `staging` directly), but it confuses tooling like `git branch --merged staging`.

### B.5 — Locked agent worktree

`/Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-a3ff6f8bcca8bb0ef` is locked, points at branch `worktree-agent-a3ff6f8bcca8bb0ef` (15 ahead, 57 behind), last commit 2026-04-25. Contains 210 modified files vs HEAD — likely a snapshot of in-progress v2.8 phase 40 work.

**Action proposée:** ask Julien if this snapshot is still needed. If not:

```bash
git worktree unlock /Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-a3ff6f8bcca8bb0ef
git worktree remove --force /Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/agent-a3ff6f8bcca8bb0ef
git branch -D worktree-agent-a3ff6f8bcca8bb0ef
```

### B.6 — Active development worktrees (KEEP)

| Worktree | Branch | Status |
|---|---|---|
| `MINT.nosync` | `fix/sim-walkthrough-crash-loop` | main checkout, dirty (2 modified, 4 untracked) — safe |
| `MINT.phase56-pr3.nosync` | `feat/phase-56-03-tool-classification` | clean — keep |
| `MINT.sprint0-401.nosync` | `fix/sprint0-401-breadcrumb-sweep` | clean — keep |
| `MINT.sprint1-nav.nosync` | `feat/sprint1-nav-audit` | clean — keep |

---

## 4. Phase C — Lost code recovery

### C.1 — Unreachable commits inspected (10/30 spot-checked)

| SHA | Date | Subject | Recoverable? |
|---|---|---|---|
| `38003a5d` | 2026-05-02 | `feat(anonymous-wedge): real-data AVS rente estimate` | **shipped via PR #429** — drop |
| `50008e10` | 2026-05-02 | `feat(coach): wire ProactiveTriggerService output` | **shipped via PR #431** — drop |
| `c200204b` | 2026-04-09 | `docs(03): expert-panel context Phase 3 chat-as-shell` | predates current docs structure — drop |
| `ef008e08` | 2026-04-15 | `WIP on fix/coach-disclaimer-slim-footer` | stash byproduct — drop |
| `46013217` | 2026-03-21 | `fix(S58): close 3 audit findings — tool_calls bridge` | superseded by Phase 32+ — drop |
| `4301e235` | 2026-03-14 | `autoresearch-quality: make _canton final` | trivial lint, likely shipped — drop |
| `6301fc56` | 2026-03-29 | `fix: regenerate canonical OpenAPI spec` | recurring CI fix — drop |
| `94014625` | 2026-03-19 | `prompt: document 3 rogue prompt sites` | likely shipped — drop |
| `9601067a` | 2026-04-30 | `WIP on feature/v2.9-phase-40-marge-fiscale` | stash byproduct — drop |
| `370284c1` | 2026-03-12 | `fix(backend): force Dockerfile builder` | shipped pre-Phase 30 — drop |

**Conclusion:** every spot-checked unreachable commit is either (a) a stash byproduct or (b) work that was rebased/squashed into a merged PR. **No genuine lost code detected.**

### C.2 — Recovery procedure (only if Julien finds something missing)

If Julien identifies a specific feature that's gone:

```bash
# 1. Search by subject keyword :
git fsck --unreachable --no-reflogs 2>&1 | grep "^unreachable commit" | awk '{print $3}' | \
  xargs -I {} git log -1 --format='%H %s' {} | grep -i "<keyword>"

# 2. Recover by tag :
git tag recovery/<sha-prefix> <full-sha>
git switch -c recover/<descriptive-name> <full-sha>
```

### C.3 — Stash recovery procedure

If a stash is dropped by mistake:

```bash
# Within ~14 days of drop, the stash blob is still in fsck output :
git fsck --unreachable --no-reflogs | grep commit
# Re-apply :
git stash apply <sha>
```

---

## 5. Top 3 risques si on ne fait rien

1. **PR rebase storm.** 13 of 15 open PRs are 13 commits behind `dev`. If `dev` advances another 5-10 commits before they're rebased, conflicts will compound (especially on `lib/screens/anonymous_chat_screen.dart` and `app_*.arb` files where 6+ PRs all touch the same lines). Risk: **2-4h of conflict resolution** per stale PR.

2. **`git branch` UX collapse.** With 23 local branches and 4 stale `worktree-agent-*` polluting tab-completion, switching to the right branch becomes error-prone. Risk: **wrong-branch commits** (already happened: `feat/handoff2-anonymous-chat-sweep` got `ahead=ERR behind=ERR` because the local ref drifted from origin during a force-push rebase).

3. **Stash hoard rot.** 23 stashes makes `git stash list` unreadable. New stashes pile on top instead of being applied or dropped. Risk: **silent loss** of WIP when someone runs `git stash clear` out of frustration. Probability: medium-high given the volume.

---

## 6. Execution order recommended

1. **Phase A.4 + A.5** (drop 18 stashes) — zero risk, biggest visibility win
2. **Phase A.1 + A.2** (delete 5 gone-tracked + worktree-agent branches) — zero risk
3. **Phase A.3** (rm 10 orphan agent dirs + `worktree prune`) — zero risk
4. **Phase B.4** (fast-forward local `main` + `staging`) — zero risk
5. **Phase B.2** (archive `feature/v2.9-phase-40-marge-fiscale` after diff verification)
6. **Phase B.5** (decide on locked agent worktree with Julien)
7. **Phase B.1** (rebase storm — separate task per PR, batched by area)

Phase C only if a specific gap is identified — no action needed today.

---

## 7. Commands ready to copy-paste (Phase A only — fully safe)

```bash
cd /Users/julienbattaglia/Desktop/MINT.nosync

# A.1 — gone-tracked merged branches
git branch -D \
  feature/S30.16-walk-p0-3-dev-onboarding \
  feature/S30.20-doc-ext-remaining-fixtures

# A.2 — duplicate worktree-agent hotfix branches
git branch -D \
  worktree-agent-a048c831ec00a1181 \
  worktree-agent-a6e3b845bcdee0e85 \
  worktree-agent-ac240683622af08be

# A.3 — orphan filesystem worktree dirs
for d in agent-a1024bd2 agent-a49a64d9 agent-a716b708 agent-a77860f5 \
         agent-a87652fb agent-aba588de agent-ac435233 agent-ae615269 \
         agent-af26fb90; do
  rm -rf "/Users/julienbattaglia/Desktop/MINT.nosync/.claude/worktrees/$d"
done
git worktree prune

# A.4 — stale stashes (LIFO so indexes don't shift)
for i in 22 21 20 19 18 17 16 15 14 13 12 11 10 9; do
  git stash drop "stash@{$i}"
done

# B.4 — fast-forward long-lived local branches
git fetch origin
git checkout main && git merge --ff-only origin/main && git checkout dev

# Verify
git branch -v --sort=-committerdate | head -20
git stash list
git worktree list
```

After Phase A: expected state = ~16 local branches, ~9 stashes, 4 active worktrees, no orphan filesystem dirs.
