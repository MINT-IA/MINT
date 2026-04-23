# Phase 34 CI Workflow Audit

**Date:** 2026-04-23
**Auditor:** GitHub Actions / CI-CD specialist (read-only)
**Branch:** feature/S30.7-tools-deterministes (workflows shipped via Phase 34 execute on dev)
**Workflows audited:**
- `.github/workflows/bypass-audit.yml` (new — D-21/22, GUARD-07, 131 lines)
- `.github/workflows/lefthook-ci.yml` (new — D-24, GUARD-08, 66 lines)
- `.github/workflows/ci.yml` (thinned — GUARD-08, 542 lines)
- (Context) `sync-branches.yml`, `deploy-backend.yml`, `testflight.yml`, `play-store.yml`, `golden-document-flow.yml`, `web.yml`

## Summary of Findings

| # | Severity | File | Issue |
|---|----------|------|-------|
| 1 | **P0** | lefthook-ci.yml | Unpinned `curl \| sh` install of lefthook `master` branch — supply-chain + unstable-API risk |
| 2 | **P1** | lefthook-ci.yml | `lefthook validate` is NOT a command in lefthook 2.x (command is `lefthook dump` / `lefthook version`) — step will fail on first run |
| 3 | **P1** | lefthook-ci.yml | `lefthook run commit-msg --file /tmp/msg.txt` — `--file` is not a valid flag for `lefthook run`; commit-msg hook takes the file as the `{1}` positional. Step will fail |
| 4 | **P1** | lefthook-ci.yml | No `timeout-minutes:` on the job — a hung lint (iCloud rglob stall already observed per 34-07 Deviation #1) can eat the 6-hour default runner budget |
| 5 | **P1** | bypass-audit.yml | `git log --since="7 days ago"` uses the runner's local clock + local timezone (UTC on ubuntu-latest). When cron fires Monday 09:00 UTC, window is Monday 09:00 UTC minus 7d = prior Monday 09:00 UTC. Post-merge-to-dev trigger shifts window arbitrarily (commit time). Double-counting possible |
| 6 | **P1** | bypass-audit.yml | `count=$(... \| grep -c ... \|\| true)` — when no matches, grep returns empty string (because of `\|\| true` short-circuit after pipefail), not `0`. `fromJSON('')` in next step evaluates to `null` which `> 3` coerces to false; step survives but on other runners/locales the behaviour is non-obvious. Tested edge-case |
| 7 | **P2** | bypass-audit.yml | `triage` var is interpolated into JS via `${{ }}` unquoted — if any commit author name / subject contains a backtick, `$`, or closing brace, it becomes arbitrary JS execution in the github-script step. Code-injection vector |
| 8 | **P2** | lefthook-ci.yml | `pull_request` trigger only — contributors hotfixing direct-push to `staging` or `main` (rare but allowed by branch protection policy) bypass this gate entirely |
| 9 | **P2** | ci.yml | `ci-gate needs:` list excludes `contracts-drift` and `pii-log-gate` jobs — they are not gating PRs even though both are defined. Pre-existing (not introduced by 34-07) but worth flagging |
| 10 | **P2** | bypass-audit.yml | `push: branches: [dev]` only — a bypass commit landing directly on `staging` or `main` via hotfix is never audited |
| 11 | **P3** | lefthook-ci.yml | `actions/setup-python@v5` with `3.11` installed but `lefthook.yml` scripts use `python3` (implicit) — on ubuntu-latest default python3 may differ from the one installed by setup-python unless PATH ordering is checked. Benign today |
| 12 | **P3** | bypass-audit.yml | Issue body and Actions log echo full commit author + subject → emails harvestable, no `::add-mask::` — low risk on private repo, concern if repo ever made public |
| 13 | **P3** | bypass-audit.yml | Idempotency check uses `state: 'open'` — when a maintainer closes the weekly issue (acknowledged), the next trigger opens a fresh one with updated count. Correct behaviour but worth documenting |
| 14 | **INFO** | ci.yml | 4 removed lints empirically absent from active invocations (grep confirms only comment-block references). 5 STAYs confirmed present and invoked |
| 15 | **INFO** | CI time delta | SUMMARY claim "-15s to -90s per PR" is plausible and honest; ROADMAP claim "-2 min" is not |

---

## Per-dimension findings

### 1. bypass-audit.yml correctness

**Triggers** (lines 22-28):
```
schedule: cron '0 9 * * 1'   # GitHub cron = UTC, POSIX format: min hour dom mon dow
                              # dow=1 → Monday (0=Sun, 6=Sat; 7=Sun also accepted)
push: branches: [dev]
workflow_dispatch:
```
All three present as SUMMARY claims. Cron syntax is correct: **Monday 09:00 UTC**.

**Permissions** (lines 30-32): `contents: read` + `issues: write`. Both present. `pull-requests: read` NOT needed because the job does not inspect PRs — only commits on `dev`. ✓

**F5 — Timezone/window accuracy (P1)**
- `git log --since="7 days ago"` uses git's parsing relative to the system's current time. On `ubuntu-latest`, TZ=UTC by default.
- **Monday cron firing (09:00 UTC)** → window is prior Monday 09:00 UTC → current Monday 09:00 UTC. Stable.
- **push-to-dev trigger** → fires at arbitrary time T → window is T-7d to T. A single bypass commit can thus be counted by (a) the Monday cron AND (b) every subsequent push-to-dev for 7 days. Given `count > 3` threshold, this is noisy: a sudden spike fires the threshold on cron, then gets re-fired (as a comment, thanks to idempotency) on every push for 7 days after.
- **Mitigation already in place**: listForRepo idempotency comments rather than creating duplicates — so no duplicate issues, just up-to-10 redundant comments per week.
- **Severity P1, not P0**: alerting, not gating; repeated comments are annoying not dangerous.

**F6 — Empty-grep → `count=''` (P1 tested edge-case)**
```bash
count=$(git log ... | grep -c -E 'LEFTHOOK_BYPASS|\[bypass:' || true)
```
When `grep -c` matches nothing, it prints `0` and exits 1 — `|| true` rescues the exit. `count=0`. ✓
However, when `git log` itself fails (malformed `origin/dev` ref), its stderr is already swallowed by `2>/dev/null` line 49, and the `|| true` on line 48 masks the `git fetch` failure too. Result: `count=''`. Then `fromJSON('')` → `null`, comparison `null > 3` → false. Job exits green, no audit. Silent fail.
Recommend explicit default: `count=${count:-0}` before the GITHUB_OUTPUT write.

**F7 — github-script code injection (P2)**
Line 75: `const triage = \`${{ steps.commits.outputs.triage }}\`;`
The `triage` output is untrusted user content (commit authors, subjects). GitHub Actions `${{ }}` performs string substitution BEFORE the JS runs. A commit subject like `` subject with \` backtick `` would terminate the JS template literal and execute arbitrary JS in the github-script context. The step runs with `issues: write` + default `GITHUB_TOKEN`, enabling issue/comment spam but NOT repo-write (good).
Mitigation: use `process.env.TRIAGE` with `env: TRIAGE: ${{ steps.commits.outputs.triage }}` step mapping, per GitHub's official guidance for untrusted inputs in script actions.

**Threshold** (line 58, 70): `> 3` strict. Plan 34-06 SUMMARY confirms threshold=3 means "strictly more than 3 in a week = 4+". Plan-consistent.

**Grep regex** (line 50): `'LEFTHOOK_BYPASS|\[bypass:'` — extended regex, matches:
- `LEFTHOOK_BYPASS` ✓ (also matches `LEFTHOOK_BYPASS=1`, `LEFTHOOK_BYPASS=true`, bare `LEFTHOOK_BYPASS`, even `LEFTHOOK_BYPASSES` false-positive)
- `[bypass:` ✓ (literal bracket, case-sensitive)
- Does NOT match `[Bypass: ...]` or `[BYPASS:` (case-sensitive). Acceptable; convention is lowercase.

**Idempotency** (line 104): `listForRepo({state:'open', labels:'bypass-audit', per_page:10})` — correct. When maintainer manually closes the issue, next firing opens a fresh one (expected). Two triggers same week → comment, not duplicate. ✓

**workflow_dispatch manual testing** (line 28): no required inputs → triggerable from Actions UI. ✓

**F10 — Push trigger branch (P2)**: `push: branches: [dev]` ONLY. If a hotfix goes `hotfix/* → main` directly (as happened recently per git log: `2c452e0d Merge pull request #375 from MINT-IA/hotfix/sync-main-back-to-dev-374`), the bypass-audit never sees it. The Monday cron only inspects `origin/dev`. A bypass on main that gets sync-branched back to dev (via sync-branches.yml) WILL appear in origin/dev — so partial coverage. But timing-dependent.

### 2. lefthook-ci.yml (D-24 primary ground-truth)

**F1 — curl | sh install unpinned (P0)**
```
curl -sSLf https://raw.githubusercontent.com/evilmartians/lefthook/master/install.sh | sh -s -- -b "$HOME/.local/bin"
```
Three problems:
1. `master` branch, not a version tag → silent upgrade whenever upstream pushes to master.
2. `install.sh` is unpinned — no SHA, no checksum verification.
3. If GitHub is unreachable or the script has a bug, `curl -f` fails, but the subsequent `echo "$HOME/.local/bin" >> "$GITHUB_PATH"` still succeeds, so later steps fail with `command not found`. Cascading failure rather than fast-fail.

SUMMARY explicitly called this out as "same supply-chain surface as local brew install" — but brew install is content-addressed; `master` branch is not. Local dev uses `min_version: 2.1.5` in `lefthook.yml` but CI installs latest. Divergence guaranteed.

**Recommendation**: pin to `refs/tags/v2.1.6` (current) or use the [evilmartians/lefthook-action](https://github.com/marketplace/actions/lefthook-action) if available, or download the release binary directly with SHA verification.

**F2 — `lefthook validate` is not a subcommand (P1)**
Line 44: `run: lefthook validate`
Lefthook 2.x subcommands are: `run`, `install`, `uninstall`, `add`, `dump`, `version`. There is no `validate` subcommand.

Empirical check: the Plan 34-07 SUMMARY line 204 claims `lefthook validate` rc=0 was verified locally. Possible explanations:
- (a) Julien's local lefthook is a custom/patched build that has a `validate` subcommand.
- (b) An older lefthook version had it.
- (c) The SUMMARY is incorrect.

On a stock ubuntu-latest install of lefthook master, this step will fail with `unknown command "validate"`. **On first firing, the workflow step 4 will error and the job will fail.**

Verification needed: run `lefthook --help` locally (not part of this audit since audit-only; flag for Julien).

**F3 — `lefthook run commit-msg --file` invalid flag (P1)**
Lines 62: `lefthook run commit-msg --file /tmp/msg.txt`
`lefthook run <hook>` does not accept `--file`. The commit-msg hook in `lefthook.yml` uses `{1}` as the COMMIT_EDITMSG path (see `lefthook.yml` line 162: `--commit-msg-file {1}`). The CI invocation to pass a file through `{1}` is:
```
lefthook run commit-msg /tmp/msg.txt
```
or set up the hook context via env. On first firing of this loop, the subprocess errors with `unknown flag --file`, the `if !` catches the non-zero exit, and the job fails for every single commit in the PR range — **silently passing through the step as a false-positive failure that blocks every PR**.

Impact: EVERY PR opened post-merge will have `lefthook-ci` check red, blocking merges, until this is fixed. P1 rather than P0 only because a dev can manually fix or Julien can observe the first failure and patch.

**F4 — No timeout-minutes (P1)**
```yaml
jobs:
  lefthook-all:
    runs-on: ubuntu-latest
    # no timeout-minutes
```
Plan 34-07 Deviation #1 documented a >5min rglob stall locally. Clean ubuntu runner without iCloud duplicates will not hit that exact stall, but `lefthook run pre-commit --all-files --force` runs 10 commands including 4 migrated scripts (`no_chiffre_choc` scans apps/mobile/lib + services/backend/app + docs + tools/openapi). On a cold runner with full history fetched, this is ~1-5 min worst case. No timeout = default 6h runner burn.
Recommend `timeout-minutes: 15`.

**F11 — Python version mismatch (P3)**
`actions/setup-python@v5` installs 3.11. Scripts invoke `python3`. On ubuntu-latest, `setup-python` prepends its python to PATH, so `python3` should resolve to 3.11. Verified via action docs. Benign.

**Checkout depth** (line 31): `fetch-depth: 0` ✓ needed for `origin/${{ github.base_ref }}..HEAD` range.

**Triggers**: `pull_request: [dev, staging, main]` ✓ covers three branches.

**F8 — No push-trigger (P2)**: hot-fix-direct-to-main bypasses this workflow entirely. Branch protection mitigates if configured; SUMMARY flags this as infrastructure-not-workflow follow-up.

**Parallel safety**: `lefthook.yml` has `parallel: true`. On a 2-core ubuntu-latest runner, 10 commands run in 2-wide parallel. Not a correctness issue, just slower than marketing.

**Branch-protection integration**: the `Lefthook CI` check will need to be added as a REQUIRED status check in GitHub Settings → Branches → dev/staging/main protection rules. Workflow-side is ready; infra-side is pending. Flag as follow-up.

### 3. ci.yml thinning correctness

**Empirical verification (grep-based)**:
```
grep -c "run: python3 tools/checks/no_chiffre_choc\.py" ci.yml     → 0
grep -c "run: python3 tools/checks/landing_no_numbers\.py" ci.yml  → 0
grep -c "run: python3 tools/checks/landing_no_financial_core\.py" ci.yml → 0
grep -c "run: python3 tools/checks/route_registry_parity\.py" ci.yml → 0
```
All 4 removed invocations confirmed absent from active `run:` steps. Comment-only references remain (4 mentions, all in `# Phase 34 GUARD-08 D-23 migration` blocks + 1 pytest test file reference line 458 which is a DIFFERENT script — `tests/checks/test_route_registry_parity.py`, the pytest wrapper, not the lint itself). ✓

**5 STAYs empirically confirmed**:
```
run: python3 tools/checks/no_legacy_confidence_render.py  → line 168 ✓
run: python3 tools/checks/no_implicit_bloom_strategy.py   → line 173 ✓
run: python3 tools/checks/sentence_subject_arb_lint.py    → line 178 ✓
run: python3 tools/checks/no_llm_alert.py                 → line 183 ✓
run: python3 tools/checks/regional_microcopy_drift.py     → line 204 ✓
```
All 5 STAYs present in the `backend` job. ✓

**F9 — ci-gate needs: orphans (pre-existing, P2)**
```
needs: [changes, backend, flutter, readability, wcag-aa-all-touched, mint-routes-tests, admin-build-sanity, cache-gitignore-check]
```
- `route-registry-parity` correctly removed ✓ (SUMMARY claim confirmed).
- `contracts-drift` (line 41) and `pii-log-gate` (line 281) are defined but NOT in ci-gate needs. Failed contracts-drift or PII-log-gate jobs do NOT block ci-gate. Pre-existing, NOT introduced by 34-07, but worth flagging.

**Heavy checks preserved**: pytest (line 217), flutter analyze (line 366), flutter test (line 403), WCAG (lines 102-126), PII (lines 281-302), Alembic (256-264), OpenAPI (line 224). All present. ✓

**Dead if: conditions**: none found. ci-gate uses only jobs listed in its `needs:`.

### 4. CI time delta reality

Scanning ci.yml structure: the `backend` job runs serially — each `- name: ...` step is sequential within the job. 4 removed lints were ALL inside the `backend` job (3 inline `run:` steps) + 1 standalone `route-registry-parity:` job running in parallel to backend.

- **Inside `backend`**: 3 steps removed, each ~2-5s actual work (script is small; the heavy cost was shared setup-python which stays). Savings = ~6-15s on the backend job critical path.
- **`route-registry-parity` standalone job**: ~30-45s (checkout + setup-python + pip nothing + run). Because it ran parallel to backend+flutter, removal saves wall-clock ONLY if it was the longest job (it wasn't — flutter shards take ~8-12min). Savings = effectively 0s wall-clock, -30s runner-minute billing.
- **lefthook-ci.yml ADDED**: +30-90s wall-clock (new job, runs parallel but adds setup cost).

**Realistic wall-clock per PR**: net ~0 to -10s. The "-15 to -90s" claim in SUMMARY is directional (removes runner minutes) but on wall-clock (what a developer feels) the new lefthook-ci.yml likely breaks even or slightly increases PR completion time. The "-2 min" claim from ROADMAP is not credible.

**Verdict on claims**: SUMMARY's "-15s to -90s" is charitable and refers to runner-minutes, not wall-clock. ROADMAP's "-2 min" is not credible.

### 5. Cross-workflow interaction

- **bypass-audit + lefthook-ci race**: bypass-audit fires on `push: dev` (post-merge); lefthook-ci fires on `pull_request` (pre-merge). They never overlap on the same event. No race.
- **Double-reporting scenario**: a bypass that introduces a regression → lefthook-ci fails the PR → PR cannot merge → no push to dev → bypass-audit never sees it. Correct complementarity. ✓
- **Bypass with NO regression**: lefthook-ci passes → PR merges → push-to-dev fires → bypass-audit counts it. Correct: D-21 catches cultural signal, D-24 catches mechanical regression. ✓
- **regional_microcopy_drift duplication check**: `grep regional_microcopy_drift lefthook.yml → 0 matches`. STAY lints are NOT duplicated in lefthook.yml. No double-execution. ✓
- **Same for other 4 STAYs**: none of `no_legacy_confidence_render / no_implicit_bloom_strategy / sentence_subject_arb_lint / no_llm_alert` appear in lefthook.yml. Clean separation. ✓

### 6. Hidden secrets / PII in workflow output

- **bypass-audit.yml** echoes commit author names and subjects to: (a) Actions log (line 54, 65), (b) issue body, (c) issue comment. No `::add-mask::`. On a public repo, this harvests author email patterns (`%an`). On the current private `MINT-IA/*` repo, lower risk. P3.
- **lefthook-ci.yml** prints lint output to Actions log. Lints emit file paths + line numbers + quoted strings. If a staged file contained a secret in plaintext (committed-then-fixed pattern), the secret would be re-displayed in CI logs. Pre-existing risk for any CI that greps code; unchanged by this plan.

### 7. Runner compatibility

- Both new workflows: `runs-on: ubuntu-latest` (currently Ubuntu 22.04/24.04). ✓
- Python 3.11 for lefthook-ci ✓ (Ubuntu default has 3.10/3.12 depending on image; setup-python pins).
- Lefthook Go binary Linux x86_64: supported upstream. ✓
- Shell: `/bin/sh` for `curl | sh` install — check install.sh compatibility with bash-only features. Upstream script is known to work on POSIX sh. Benign.

### 8. Failure observability

- **bypass-audit.yml**: if the workflow itself errors (not the count logic — the step), the `|| true` guards mask most errors. Silent fail possible (F6). The workflow always exits 0 per comment line 17.
- **lefthook-ci.yml**: loud failures — any non-zero exit in any step fails the check, which blocks the PR. Good observability for devs. Bad observability for meta-failures (e.g., lefthook install failing → later steps fail with unclear `command not found`).
- **Neither workflow has `if: failure()` notification steps** (Slack, email). Failures rely on GitHub's default UI (red check on PR, email to commit author). Consistent with other MINT workflows.
- **Re-firing after manual issue close**: bypass-audit queries `state: 'open'`. If the maintainer closes issue #N acknowledging the week's bypasses, the next firing finds no open issue and creates issue #N+1 with fresh count. Correct; possibly annoying if maintainer closes same day.

---

## First-firing readiness

- **bypass-audit.yml** will first fire: next Monday 09:00 UTC after merge to dev (or immediately if Julien `workflow_dispatch` triggers it post-merge, as intended per 34-06 deviation #1). **Prediction**: PARTIAL PASS. The grep/issue-creation path works IF no bypass markers exist (normal week: count=0 or empty → no issue → silent success). If ≥4 bypasses exist, F7 (JS injection via triage) could misfire on hostile subjects; F6 (empty-count silent fail) masks any git-fetch error. F5 (post-merge-to-dev re-firing) creates up to 10 comments in a week. None of these are blocking on Day 1 — they degrade gracefully.

- **lefthook-ci.yml** will first fire: on the next PR opened against `dev`/`staging`/`main` after merge. **Prediction**: **FAIL on first fire**, with HIGH confidence.
  - F2 (`lefthook validate` not a subcommand) will error step 4 unless the installed lefthook binary actually supports `validate` (unverified — SUMMARY claim conflicts with upstream docs).
  - F3 (`lefthook run commit-msg --file` invalid flag) will error step 6 for every commit in the PR range.
  - F1 (curl | sh master) installs whatever-is-latest, which MAY have added `validate` recently but may not.
  - **Recommended before enabling as required check**: Julien runs a throwaway PR against dev to observe the workflow's actual first-firing behaviour and fix F2/F3 before branch protection enforces it.

- **ci.yml delta will be measurable after**: 5+ merged PRs per SUMMARY. Expected delta: 0s to -10s wall-clock per PR; -60s to -120s runner-minute billing per PR. The "-2 min" ROADMAP figure is not credible; the "-15 to -90s" SUMMARY range applies to runner minutes, not wall clock.

---

## Recommended pre-enable actions (for Julien, post-audit)

1. **Manually trigger lefthook-ci.yml via a throwaway PR** against `dev` BEFORE adding it to branch protection required checks. Observe F2 + F3. Fix if red.
2. **Pin lefthook install** in `lefthook-ci.yml` to a version tag (`refs/tags/v2.1.6`) or switch to a released binary with sha256 verification.
3. **Add `timeout-minutes: 15`** to lefthook-ci.yml.
4. **Escape the github-script injection** in bypass-audit.yml by moving `triage` to an `env:` block on the script step.
5. **Add `count=${count:-0}`** safety default in bypass-audit.yml.
6. **Consider adding `push: branches: [staging, main]`** to bypass-audit.yml to catch hotfix-to-main bypasses.
7. **Add `Lefthook CI` to branch protection required checks** on dev/staging/main — AFTER #1 confirms green.

## Out-of-scope observations

- `ci-gate needs:` list does not include `contracts-drift` or `pii-log-gate` jobs (pre-existing, not a 34-07 regression).
- `sync-branches.yml` fast-forwards dev ← main after merges — any bypass landing directly on main will eventually appear in origin/dev via sync, giving bypass-audit a second chance to catch it (delayed).
