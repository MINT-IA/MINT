---
phase: 34-agent-guardrails-m-caniques
verified: 2026-04-22T21:42:44Z
status: human_needed
score: 10/10 must-haves verified
re_verification:
  previous_status: none
  previous_score: n/a
  gaps_closed: []
  gaps_remaining: []
  regressions: []
human_verification:
  - test: "First real PR triggers Lefthook CI workflow green"
    expected: "`.github/workflows/lefthook-ci.yml` runs `lefthook validate` + `lefthook run pre-commit --all-files --force` + per-commit `lefthook run commit-msg` loop on next PR to dev/staging/main and all 6 steps exit 0"
    why_human: "Requires real GitHub PR traffic to exercise the workflow — workflow parses via PyYAML, `lefthook validate` is green locally, but first empirical firing can only happen on a PR. Gate-non-blocking (observation_window)."
  - test: "Weekly bypass-audit cron first firing at Monday 09:00 UTC"
    expected: "`.github/workflows/bypass-audit.yml` fires on its schedule cron and reports 0 bypass signals (or <3, below D-22 threshold) in its log. No issue created because count <= 3."
    why_human: "Cron triggers require calendar time (next Monday 09:00 UTC). Cannot be simulated from verification. `workflow_dispatch` trigger is present for manual kick per Plan 34-06 D-20 auto-fix."
  - test: "Synthetic >3 bypass detection in auto-issue"
    expected: "Manually push 4 commits to dev with `LEFTHOOK_BYPASS=1 ... [bypass: deliberate audit test]`, trigger workflow via `workflow_dispatch`, observe auto-created `bypass-audit`-labelled GitHub issue listing the 4 commits."
    why_human: "Requires hostile-scenario production of bypassed commits AND a real GitHub Issues API call. idempotency logic (listForRepo comment-or-create) needs real-world test."
  - test: "CI time reduction rolling median across 5+ post-merge PRs"
    expected: "After merging 5+ PRs post-phase-34, the rolling median duration of the `CI` workflow (GitHub Actions) drops by 15-90s per PR vs pre-merge baseline (per Plan 34-07 honest framing, NOT CONTEXT's optimistic -2min)."
    why_human: "Observation_window: requires 5+ real PRs merging to measure. Tracked as `ci-time-reduction-measured` flag."
---

# Phase 34: Agent Guardrails Mécaniques Verification Report

**Phase Goal:** Aucun commit (humain ou agent) ne peut introduire une régression accent / hardcoded-FR / bare-catch / ARB drift — lefthook 2.1.5 pre-commit parallel <5s, 5 lints mécaniques actifs, `--no-verify` banni remplacé par `LEFTHOOK_BYPASS=1` grep-able, CI thinnée (gates rapides migrent vers lefthook, CI garde les heavies).

**Verified:** 2026-04-22T21:42:44Z
**Status:** human_needed (10/10 mechanical must-haves verified; 4 observation-window items require post-merge / calendar-time / hostile-scenario exercise)
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | accent_lint_fr active pre-commit on {dart,py,arb} with 5 non-FR ARBs excluded | VERIFIED | `lefthook.yml:41-58` — glob `*.{dart,py,arb}`, excludes `app_{en,de,es,it,pt}.arb` + fixtures; 14 canonical PATTERNS reconciled in `tools/checks/accent_lint_fr.py:33-48` per CLAUDE.md §2 |
| 2 | no_hardcoded_fr active glob-scoped to widgets/screens/features, skips l10n/models/services | VERIFIED | `lefthook.yml:88-93` — glob `apps/mobile/lib/{widgets,screens,features}/**/*.dart`; `lib/l10n`, `lib/models`, `lib/services` NOT in scope; D-10 override regex in `no_hardcoded_fr.py:77-79` |
| 3 | no_bare_catch diff-only — existing 388 catches ignored, new ones caught | VERIFIED | `lefthook.yml:68-76`, `no_bare_catch.py:79-81,66-69` — `git diff --staged --unified=0 --no-renames --diff-filter=AM` state-machine parser; covers Dart + Python; `async *` + 4 exempt paths honored; `// lefthook-allow:bare-catch:` override with preceding-line lookup |
| 4 | arb_parity active across 6 ARB langs — keyset + placeholder parity | VERIFIED | `lefthook.yml:102-107`, `arb_parity.py:44` — `LANGS = ["fr","en","de","es","it","pt"]`; depth-aware ICU walker; self-test PASS on clean fixture, FAIL on de-missing `goodbye` fixture (exit 1) |
| 5 | proof_of_read active in commit-msg hook — agent commits must reference READ.md | VERIFIED | `lefthook.yml:156-163` — top-level `commit-msg:` block with ONE command (D-27 amendment of D-04); `proof_of_read.py:37-43` hardcoded `ALLOWED_READ_PREFIX = '.planning/phases/'` (T-34-SPOOF-01 mitigation); human commits bypass via absence of `Co-Authored-By: Claude` trailer |
| 6 | P95 < 5s on M-series Mac | VERIFIED | `bash tools/checks/lefthook_benchmark.sh --assert-p95=5` → rc=0, `P95 (over last 8 runs): 0.110s` — 45x under budget |
| 7 | Bypass convention enforced: --no-verify banned, LEFTHOOK_BYPASS=1 sole authorised, weekly audit + PR re-run | VERIFIED | `CONTRIBUTING.md:42-109` — §3 "Pre-commit hooks & bypass policy (GUARD-07)", `--no-verify` ban at L44-45, `LEFTHOOK_BYPASS=1` §L49, inline override §L92; `bypass-audit.yml` (D-21 secondary) + `lefthook-ci.yml` (D-24 primary) both shipped |
| 8 | CI thinned — 4 migrated lints removed, 5 heavy STAYs preserved | VERIFIED | `grep no_chiffre_choc.py\|landing_no_numbers.py\|landing_no_financial_core.py\|route_registry_parity.py ci.yml` → only comments (no active `run:` invocations); 5 STAYs verified at `ci.yml` L168, L173, L178, L183, L204 (`no_legacy_confidence_render`, `no_implicit_bloom_strategy`, `sentence_subject_arb_lint`, `no_llm_alert`, `regional_microcopy_drift`) |
| 9 | 30.5 skeleton preserved — memory-retention-gate + map-freshness-hint still wired | VERIFIED | `lefthook.yml:22-28` — both commands present; `bash tools/checks/lefthook_self_test.sh` → rc=0 (skeleton gate still fires) |
| 10 | All 8 GUARD-01..08 marked complete in REQUIREMENTS.md | VERIFIED | `grep -c "^- \[x\] \*\*GUARD-0[1-8]\*\*" .planning/REQUIREMENTS.md` → 8/8 (lines 76-83) |

**Score:** 10/10 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lefthook.yml` | Schema-valid, 10 pre-commit commands + 1 commit-msg, parallel:true, min_version 2.1.5 | VERIFIED | `lefthook validate` → "All good" rc=0; 10 pre-commit commands listed (memory-retention-gate, map-freshness-hint, accent-lint-fr, no-bare-catch, no-hardcoded-fr, arb-parity, no-chiffre-choc, landing-no-numbers, landing-no-financial-core, route-registry-parity) + 1 commit-msg (proof-of-read); `parallel: true` L17; `min_version: 2.1.5` L9 |
| `tools/checks/accent_lint_fr.py` | GUARD-04 14 canonical PATTERNS | VERIFIED | 14 patterns at lines 33-48; `from __future__ import annotations`; stdlib-only |
| `tools/checks/no_bare_catch.py` | GUARD-02 diff-only + async* + override + exempt paths | VERIFIED | `get_added_lines` at L79, EXEMPT_PATH_PREFIXES 4 entries L58-63, OVERRIDE_DART/OVERRIDE_PY regex L52-53 |
| `tools/checks/no_hardcoded_fr.py` | GUARD-03 glob-scoped + D-09 patterns + D-10 override | VERIFIED | 4 D-09 primary patterns + 2 fallbacks + 2 whitelists; D-10 override regex L77-79 |
| `tools/checks/arb_parity.py` | GUARD-05 6-lang stdlib-only ICU walker | VERIFIED | `LANGS = ["fr","en","de","es","it","pt"]` L44; depth-aware ICU walker via `extract_placeholders`; zero external deps |
| `tools/checks/proof_of_read.py` | GUARD-06 commit-msg hook Co-Authored-By + Read: trailer + prefix check | VERIFIED | TRAILER_CLAUDE + TRAILER_READ regex L37-38; ALLOWED_READ_PREFIX hardcoded L42 (T-34-SPOOF-01) |
| `tools/checks/lefthook_benchmark.sh` | P95 measurement script executable | VERIFIED | Runs, outputs `P95 (over last 8 runs): 0.110s`, `--assert-p95=5` returns rc=0 |
| `.github/workflows/lefthook-ci.yml` | D-24 primary PR re-run catcher | VERIFIED | 66 lines; triggers on `pull_request: branches: [dev, staging, main]`; 6 steps including `lefthook validate` + `lefthook run pre-commit --all-files --force` + commit-msg loop over `origin/<base>..HEAD` |
| `.github/workflows/bypass-audit.yml` | D-21 secondary weekly audit | VERIFIED | 130 lines; triggers: schedule cron `0 9 * * 1` + push:dev + workflow_dispatch; threshold 3 enforced at L58,70; idempotent issue creation via `listForRepo` L104-110 |
| `.github/workflows/ci.yml` | 4 migrations removed, 5 STAYs preserved | VERIFIED | Only comment references to migrated scripts; all 5 STAY lints still have active `run:` invocations |
| `CONTRIBUTING.md` | GUARD-07 bypass policy documented | VERIFIED | §3 at L42-109 documents `--no-verify` ban + `LEFTHOOK_BYPASS=1` sole bypass + inline override + bypass-audit reference |
| `tests/checks/test_*.py` × 5 | ~60 pytest cases covering all 5 new lints | VERIFIED | `pytest tests/checks/test_accent_lint_fr.py test_no_bare_catch.py test_no_hardcoded_fr.py test_arb_parity.py test_proof_of_read.py -q` → **62 passed in 0.92s** |
| `.planning/REQUIREMENTS.md` | All 8 GUARDs marked [x] | VERIFIED | Lines 76-83, all `- [x] **GUARD-0N**` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `lefthook.yml` pre-commit block | 5 new lint scripts + 4 migrations | `run: python3 tools/checks/<script>.py` | WIRED | All 9 script paths exist, invocation forms match plan specs |
| `lefthook.yml` commit-msg block | `proof_of_read.py` | `run: python3 tools/checks/proof_of_read.py --commit-msg-file {1}` | WIRED | Lefthook 2.1.6 `{1}` placeholder = path to `.git/COMMIT_EDITMSG`; D-17 bypass via absence of Claude trailer |
| `CONTRIBUTING.md` §3 | `bypass-audit.yml` + `lefthook-ci.yml` | cross-reference prose | WIRED | §3 L88 cites `.github/workflows/lefthook-ci.yml` as primary catcher; bypass-audit header L4-6 forward-references lefthook-ci.yml |
| `lefthook-ci.yml` | local `lefthook.yml` | `lefthook run pre-commit --all-files --force` + commit-msg loop | WIRED | Same lefthook binary runs same config on clean ubuntu-latest runner — ground-truth bypass catch |
| `ci.yml` | 5 STAY lints | `run: python3 tools/checks/<stay>.py` | WIRED | 5 active `run:` lines grepped at L168, L173, L178, L183, L204 |
| `bypass-audit.yml` | GitHub Issues API | `actions/github-script@v7` listForRepo + createComment/create | WIRED | 3 triggers (schedule + push + workflow_dispatch), threshold 3, idempotency via label `bypass-audit` |
| `lefthook.yml` accent-lint-fr exclude | 5 non-FR ARBs + fixtures + TOOL-04 tests | explicit `exclude:` array | WIRED | L49-57 — 7 entries, including Pitfall 7 fixtures and Phase 30.7 TOOL-04 test inputs |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| lefthook schema valid | `lefthook validate` | "All good", rc=0 | PASS |
| P95 under 5s budget | `bash tools/checks/lefthook_benchmark.sh --assert-p95=5` | P95 = 0.110s, rc=0 | PASS |
| Self-test green (all 6 sections) | `bash tools/checks/lefthook_self_test.sh` | 6 sections all green (accent_lint_fr FAIL+PASS, no_bare_catch FAIL+PASS, no_hardcoded_fr FAIL+PASS, arb_parity FAIL+PASS, proof_of_read human bypass + Claude-no-Read FAIL), rc=0 | PASS |
| Pytest for all 5 Phase 34 lints | `pytest tests/checks/test_{accent_lint_fr,no_bare_catch,no_hardcoded_fr,arb_parity,proof_of_read}.py -q` | 62 passed in 0.92s | PASS |
| Full tests/checks collection importable | `pytest tests/checks/ -q` | 80 passed in 1.34s (includes pre-existing test_route_registry_parity.py) | PASS |
| REQ ledger all 8 GUARDs marked | `grep -c "^- \[x\] \*\*GUARD-0[1-8]\*\*" .planning/REQUIREMENTS.md` | 8 | PASS |
| 4 migrated lints absent from CI active invocations | `grep "run: python3 tools/checks/(no_chiffre_choc\|landing_no_numbers\|landing_no_financial_core\|route_registry_parity).py" ci.yml` | no matches (only comment references) | PASS |
| 5 STAY lints preserved in CI | `grep "run: python3 tools/checks/(no_legacy_confidence_render\|no_implicit_bloom_strategy\|sentence_subject_arb_lint\|no_llm_alert\|regional_microcopy_drift).py" ci.yml` | 5 matches at L168,173,178,183,204 | PASS |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| GUARD-01 | 34-00, 34-07 | lefthook 2.1.5 installed + pre-commit parallel target <5s on M-series Mac, changed-files scope | SATISFIED | `min_version: 2.1.5` L9, `parallel: true` L17, P95 = 0.110s empirical, all commands use tight `glob:` filters or self-configured scope |
| GUARD-02 | 34-02 | no_bare_catch.py refuses Dart + Python bare-catch without log/rethrow, exempts test/ + async* | SATISFIED | Script exists; diff-only D-07; 4 exempt paths; async* exemption; override; 12/12 pytest green |
| GUARD-03 | 34-03 | no_hardcoded_fr.py scans Dart widgets for FR strings outside AppLocalizations, excludes lib/l10n | SATISFIED | Script exists; 4 D-09 primary patterns + whitelist; glob excludes l10n/services/models; 11/11 pytest green |
| GUARD-04 | 34-01 | accent_lint_fr.py ASCII-only flag on app_fr.arb + .dart + .py (14 canonical patterns per CLAUDE.md §2) | SATISFIED | PATTERNS list has all 14 canonical stems; 5 non-FR ARBs excluded via lefthook; 13/13 pytest green |
| GUARD-05 | 34-04 | arb_parity.py — 6 ARB files same keyset, fail CI on drift | SATISFIED | 6 LANGS; depth-aware ICU walker; 3 pre-existing translation drifts fixed; pytest + self-test green |
| GUARD-06 | 34-05 | proof_of_read.py agent co-author commits must reference READ.md | SATISFIED | Script at commit-msg hook; hardcoded prefix for T-34-SPOOF-01; D-17 human bypass; 14/14 pytest green; CONTRIBUTING.md §2 documents convention |
| GUARD-07 | 34-06 | --no-verify ban → LEFTHOOK_BYPASS=1 convention + CI audit + alert >3/week | SATISFIED | CONTRIBUTING.md §3 bans --no-verify, documents LEFTHOOK_BYPASS=1; bypass-audit.yml shipped with 3 triggers + threshold 3 + idempotent issue; lefthook-ci.yml is D-24 primary catcher |
| GUARD-08 | 34-07 | CI thinning — 10 grep-style gates become lefthook-first, CI keeps heavy gates | SATISFIED | 4 D-23 migrations shipped (bringing lefthook's owned count to 10); 5 STAY heavy lints preserved in CI; ci-gate needs list cleaned; net ci.yml delta -14 lines |

No orphaned requirements. All 8 GUARDs appear in plan `requirements:` frontmatter AND as `- [x]` in REQUIREMENTS.md.

### Anti-Patterns Found

None. Scans for `TODO|FIXME|PLACEHOLDER|not yet implemented` returned zero hits in Phase 34 scripts, workflows, and test fixtures. The `tests/checks/fixtures/*_bad.*` files DO contain deliberate bad patterns (bare-catches, ASCII accents, hardcoded FR), but these are explicitly excluded in `lefthook.yml` via `exclude: [tests/checks/fixtures/**]` on each relevant command — this is the D-25 / Pitfall 7 contract, not an anti-pattern.

### Human Verification Required

Four observation-window items cannot be verified from the local filesystem alone — each is mechanically wired (workflow YAML parses, lefthook validate green, bypass-audit workflow exercised via workflow_dispatch is possible) but their empirical firing requires either calendar time (Monday cron), PR traffic (lefthook-ci.yml), hostile-scenario injection (bypass audit auto-issue), or statistical aggregation across 5+ merged PRs (CI time reduction).

Per Plan 34-07 §Observation-Window Deferred Verifications and `34-VALIDATION.md` §Manual-Only these 3 items are explicitly flagged `verify_type: observation_window` and are NOT gate-blocking. The verification harness correctly marks them as deferred.

### 1. First real PR triggers Lefthook CI workflow green

**Test:** Open any PR to `dev`/`staging`/`main` after this phase merges.
**Expected:** `.github/workflows/lefthook-ci.yml` "Lefthook CI" check turns green (6 steps rc=0).
**Why human:** Requires real GitHub PR traffic; workflow file parses and `lefthook validate` is green locally.

### 2. Weekly bypass-audit cron first firing

**Test:** Wait for next Monday 09:00 UTC or trigger `workflow_dispatch` manually.
**Expected:** `bypass-audit.yml` runs, reports a count of `LEFTHOOK_BYPASS|[bypass:` references from `git log --since="7 days ago"` on dev, and opens NO issue if count <= 3.
**Why human:** Cron time-gated; one-shot verification needed.

### 3. Synthetic >3 bypass detection in auto-issue

**Test:** Land 4 commits to dev with `LEFTHOOK_BYPASS=1 git commit -m '... [bypass: deliberate audit test]'`, manually trigger `workflow_dispatch` for bypass-audit.yml.
**Expected:** Workflow opens a single `bypass-audit`-labelled GitHub issue listing all 4 commits; re-firing appends a comment rather than creating duplicate.
**Why human:** Hostile-scenario production + GitHub Issues API round-trip.

### 4. CI time reduction rolling median across 5+ post-merge PRs

**Test:** Collect CI workflow durations for 5+ PRs merged post-phase-34, compute rolling median, compare to pre-phase-34 baseline.
**Expected:** Per-PR CI time drops by 15-90s (per Plan 34-07 honest framing).
**Why human:** Requires 5+ real PRs; tracked as `ci-time-reduction-measured` flag.

### Gaps Summary

No gaps. All 10 mechanical must-haves are verified with concrete file-exists / grep / pytest / self-test / benchmark evidence. All 8 requirement IDs from PLAN frontmatter are marked `[x]` in REQUIREMENTS.md and trace to working artefacts with working tests.

Status is `human_needed` (not `passed`) because 4 observation-window items exist per the phase's own VALIDATION.md contract. These are explicitly flagged as NOT gate-blocking — they are post-merge operational metrics and hostile-scenario probes that cannot be exercised from a verification harness at this moment. The mechanical goal ("aucun commit ne peut introduire une régression...") is achieved; the empirical confirmation of the CI-side safety net requires real-world firing.

---

*Verified: 2026-04-22T21:42:44Z*
*Verifier: Claude (gsd-verifier)*
