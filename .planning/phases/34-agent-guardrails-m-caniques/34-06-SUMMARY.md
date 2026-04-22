---
phase: 34-agent-guardrails-m-caniques
plan: 06
subsystem: infra
tags: [lefthook, bypass-convention, ci, github-actions, contributing-doc, guard-07]

# Dependency graph
requires:
  - phase: 34
    provides: "Plans 00-05 lefthook foundation (5 pre-commit lints + 1 commit-msg hook) that this plan's convention documentation describes"
provides:
  - "CONTRIBUTING.md §3 bypass policy — LEFTHOOK_BYPASS=1 as SOLE authorised bypass, --no-verify banned, [bypass: <reason>] marker convention"
  - ".github/workflows/bypass-audit.yml — weekly Monday 09:00 UTC + post-merge-to-dev GitHub Actions workflow grepping commit bodies for bypass signals"
  - "D-22 threshold enforcement (>3/week) with auto-issue creation + label bypass-audit + idempotent re-firing (comment vs duplicate)"
  - "Traceability table in CONTRIBUTING.md mapping 7 active lints to GUARD-01..06 requirements"
affects: [34-07, 36, v2.8-guardrails]

# Tech tracking
tech-stack:
  added:
    - "GitHub Actions `actions/github-script@v7` (no new deps; listForRepo idempotency pattern introduced)"
    - "Workflow triggers: schedule cron + push branches + workflow_dispatch (first MINT workflow combining all 3)"
  patterns:
    - "Bypass convention doc pattern: env-var (ephemeral) + commit-body marker (persisted) → both needed for runtime enforcement + post-hoc audit"
    - "Idempotent issue creation: listForRepo(state=open,label) then comment-or-create branch, prevents duplicate noise when cron + push both fire in the same week"
    - "Secondary-audit positioning: every artefact (CONTRIBUTING §3, bypass-audit.yml header + issue body) explicitly points to D-24 lefthook-ci.yml (Plan 34-07) as the PRIMARY ground-truth catcher"

key-files:
  created:
    - ".github/workflows/bypass-audit.yml — 130 lines, 4 steps, 2 permissions, 3 triggers"
    - ".planning/phases/34-agent-guardrails-m-caniques/34-06-READ.md — 11 files receipt (pre-created for commit-msg hook compliance)"
  modified:
    - "CONTRIBUTING.md — bootstrap 34-05 extended from 2 sections → 6 sections (155 lines, +143 lines)"

key-decisions:
  - "D-20 (convention ban on --no-verify) + D-21 (weekly cron + post-merge trigger) + D-22 (threshold 3/week) shipped as an inseparable triplet. CONTRIBUTING.md §3 documents the policy; bypass-audit.yml enforces the detection; issue-body wording ties them together."
  - "D-21 positioned as SECONDARY awareness tool — every surface (doc + workflow header + issue body) cites D-24 (Plan 34-07 lefthook-ci.yml) as the PRIMARY regression catcher. Resolves RESEARCH Open Question 6 by making the complementarity explicit to any operator reading the audit issue."
  - "Voluntary signal design (operator types [bypass: <reason>] in commit body) accepted over mechanical enforcement because --no-verify itself leaves no trace — there is NO way to mechanically force LEFTHOOK_BYPASS usage. The weekly audit catches awareness, the lefthook-ci job (Plan 07) catches regression."
  - "Idempotent issue creation via listForRepo(state=open,labels=bypass-audit) — prevents Monday cron + same-day push-to-dev from opening 2 issues for the same week. Appends comment on re-fire with updated count."
  - "workflow_dispatch added beyond plan scope (Rule 3 blocking auto-fix) — needed so Julien can manually trigger the workflow once during the observation-window validation without waiting 7 days for the first real Monday firing."
  - "Inline override (// lefthook-allow:<lint>:<reason>) preferred over LEFTHOOK_BYPASS documented — Phase 34 established preceding-line convention (34-02, 34-03) is surfaced in §3 as the first-choice escape hatch."

patterns-established:
  - "Pattern A: voluntary commit-body marker for audit — format `[bypass: <three-word-reason-minimum>]`. Grep-able via git log --pretty=%B. Reusable for any future opt-out convention requiring post-hoc traceability."
  - "Pattern B: workflow triggers schedule + push + workflow_dispatch — first MINT workflow combining all 3. Precedent for any future scheduled audit that also benefits from post-merge amendment + manual override."
  - "Pattern C: issue-creation idempotency via listForRepo — preferable to GitHub's native dedup (which is per-title only). Enables dynamic titles (e.g., week-tag in this case) without duplicate noise."

requirements-completed: [GUARD-07]

# Metrics
duration: 3min
completed: 2026-04-22
---

# Phase 34 Plan 06: GUARD-07 bypass convention + weekly audit Summary

**CONTRIBUTING.md §3 locks LEFTHOOK_BYPASS=1 as the SOLE authorised bypass (D-20); bypass-audit.yml workflow audits `dev` commit bodies weekly + post-merge and opens a labelled GitHub issue when usage exceeds 3/week (D-21/D-22), explicitly positioned as SECONDARY to Plan 34-07's lefthook-ci.yml ground-truth catcher.**

## Performance

- **Duration:** 3 min
- **Started:** 2026-04-22T21:08:14Z
- **Completed:** 2026-04-22T21:11:30Z
- **Tasks:** 2
- **Files created:** 2 (`bypass-audit.yml`, `34-06-READ.md`)
- **Files modified:** 1 (`CONTRIBUTING.md` — bootstrap 34-05 extended)

## Accomplishments

- CONTRIBUTING.md extended from 31 lines (34-05 bootstrap) → 155 lines with 6 sections: first-time setup, lefthook table, bypass policy, proof-of-read, benchmark, CI-split pointer.
- LEFTHOOK_BYPASS=1 env-var + [bypass: <reason>] commit-body marker documented as a complementary pair (runtime + persisted signals) — the ONLY authorised bypass path.
- `--no-verify` explicitly banned with rationale (no trace in commit object = defeats audit).
- `.github/workflows/bypass-audit.yml` shipped: schedule (Monday 09:00 UTC) + push (dev) + workflow_dispatch triggers; grep scope covers BOTH `LEFTHOOK_BYPASS` env-var mentions AND `[bypass:` commit-body markers over 7-day window; issue auto-created with label `bypass-audit` when count > 3 (D-22).
- Idempotent issue creation via `listForRepo` pre-check → comment on existing weekly issue rather than opening a duplicate when cron + post-merge fire the same week.
- Triage body includes short hashes + authors + subjects via secondary `git log --pretty='- %h %an — %s'` pass, giving the maintainer enough context to act without re-running git manually.
- Every audit surface (CONTRIBUTING §3, workflow file header, GitHub issue body) cites Plan 34-07 `lefthook-ci.yml` (D-24) as the PRIMARY regression catcher — resolves RESEARCH Open Question 6 on complementarity.
- GUARD-07 marked complete in REQUIREMENTS.md (6/8 Phase 34 requirements done; Plans 34-07 pending for GUARD-08).

## Task Commits

Each task was committed atomically and passed the commit-msg hook (proof-of-read):

1. **Task 1: Create CONTRIBUTING.md extended with GUARD-07 bypass policy** — `75e1d6d7` (docs)
2. **Task 2: Create .github/workflows/bypass-audit.yml** — `ba9cf0a3` (feat)

## Files Created/Modified

- `CONTRIBUTING.md` (155 lines) — extended bootstrap with §1 first-time setup, §2 pre-commit lint table, §3 bypass policy (D-20/D-21/D-22), §4 proof-of-read, §5 benchmark, §6 CI-split pointer. 7 `LEFTHOOK_BYPASS` mentions, 9 `GUARD-` references, 2 `--no-verify` mentions (both in ban context), 3 `bypass-audit` references.
- `.github/workflows/bypass-audit.yml` (130 lines) — 4 steps: checkout@v4 (fetch-depth: 0) → count grep → triage collect → issue create/comment. Permissions: `contents: read` + `issues: write`. Triggers: `schedule: cron '0 9 * * 1'` + `push: branches: [dev]` + `workflow_dispatch`.
- `.planning/phases/34-agent-guardrails-m-caniques/34-06-READ.md` (11 files receipt) — referenced by both task commits via `Read:` trailer.

## Decisions Made

- **D-20/D-21/D-22 inseparable triplet**: convention ban, detection workflow, and threshold shipped together. Rationale: operators learning the convention from CONTRIBUTING.md need to know the audit exists (§3 mentions both); the audit issue body needs the convention to reference when explaining WHY it fires; the threshold is meaningless without both halves of the grep pattern (`LEFTHOOK_BYPASS` OR `[bypass:`).
- **Voluntary signal design accepted** (per RESEARCH Pitfall 6 + Open Question 6): there is NO way to mechanically force operators to use `LEFTHOOK_BYPASS=1` instead of `--no-verify`. The weekly audit measures AWARENESS (did the operator voluntarily signal the bypass?); the ground-truth REGRESSION detector is Plan 34-07 lefthook-ci.yml.
- **D-21 grep pattern expanded beyond plan literal**: plan said grep for `LEFTHOOK_BYPASS` only; workflow greps for `LEFTHOOK_BYPASS|\[bypass:` because CONTRIBUTING.md §3 recommends operators type `[bypass: <reason>]` in the commit body (RESEARCH Open Question 6 recommendation). Both signals on the same grep OR ensures any voluntary signal lands in the count.
- **Idempotency via listForRepo** rather than relying on GitHub's native title dedup: titles include `week of YYYY-MM-DD` tag, so naive dedup would miss re-fires on the same week. `state=open,labels=bypass-audit` lookup always returns the current-week issue.
- **workflow_dispatch added** (Rule 3 blocking auto-fix from plan): without it, observation-window validation would require waiting for Monday 09:00 UTC for the first real firing. Manual trigger lets Julien sanity-check the plumbing immediately post-merge.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing critical functionality] Added `workflow_dispatch` trigger**
- **Found during:** Task 2 (bypass-audit.yml authoring)
- **Issue:** Plan spec + RESEARCH Example 5 skeleton both only listed `schedule` + `push` triggers. Without `workflow_dispatch`, there is no way to manually validate the workflow during the observation-window gap — Julien would have to wait for the first Monday 09:00 UTC firing OR force a post-merge event on `dev`, both of which defer verification beyond this plan's merge window.
- **Fix:** Added `workflow_dispatch:` alongside `schedule:` and `push:` under `on:`. Zero additional permissions needed.
- **Files modified:** .github/workflows/bypass-audit.yml
- **Verification:** PyYAML safe_load parses the 3-trigger block cleanly; grep structural tokens present.
- **Committed in:** `ba9cf0a3` (Task 2 commit)

**2. [Rule 2 - Missing critical functionality] Added idempotent issue creation via listForRepo**
- **Found during:** Task 2 (drafting the `actions/github-script@v7` step)
- **Issue:** RESEARCH Example 5 skeleton (and plan spec) used `issues.create()` unconditionally. Both `schedule` and `push: branches: [dev]` can fire within the same week — the first would create issue #N, the second would create duplicate issue #N+1 the next day. GitHub's native title dedup would not help because I chose to include the week-tag `YYYY-MM-DD` in titles for maintainer readability.
- **Fix:** Before the `issues.create()` branch, query `listForRepo({state: 'open', labels: 'bypass-audit'})`. If any exist, append a comment with updated count; else create a fresh issue. Preserves audit trail within a week, prevents noise.
- **Files modified:** .github/workflows/bypass-audit.yml
- **Verification:** grep `listForRepo` present; 2 code branches in the script step (comment vs create).
- **Committed in:** `ba9cf0a3` (Task 2 commit)

**3. [Rule 2 - Missing critical functionality] Added triage body with commit hashes + authors + subjects**
- **Found during:** Task 2 (considering what a maintainer opening the auto-created issue would actually need)
- **Issue:** Plan + RESEARCH Example 5 body text only included count + a manual triage command. An operator opening the issue would then have to run `git log --since="7 days ago" --grep=...` themselves to see WHICH commits triggered the audit. Low-friction triage requires the list IN the issue body.
- **Fix:** Added a second git log pass with `--pretty='- %h %an — %s'` piped through `grep -E 'LEFTHOOK_BYPASS|\[bypass:'`, captured to a step output via heredoc-style GITHUB_OUTPUT, embedded in the issue body.
- **Files modified:** .github/workflows/bypass-audit.yml
- **Verification:** grep structural tokens for `triage<<TRIAGE_EOF` heredoc, 2 `git log` invocations in the workflow.
- **Committed in:** `ba9cf0a3` (Task 2 commit)

**4. [Rule 1 - Bug] D-21 grep pattern expanded to cover both signals**
- **Found during:** Task 2 (cross-referencing RESEARCH Open Question 6 recommendation)
- **Issue:** Plan literal grep was `LEFTHOOK_BYPASS` only. But CONTRIBUTING.md §3 (Task 1, already shipped) recommends operators type `[bypass: <reason>]` in commit body as the PERSISTED audit signal — the env var itself never touches the commit object. Using grep-for-env-var-only would under-count every well-behaved bypass that followed the §3 convention.
- **Fix:** Expanded count regex to `LEFTHOOK_BYPASS|\[bypass:` so either signal increments the count. Documented in the step's inline comment.
- **Files modified:** .github/workflows/bypass-audit.yml
- **Verification:** Verified CONTRIBUTING.md §3 example matches the regex by eye; both patterns are in `grep -E` form (extended regex, safe bracket literal).
- **Committed in:** `ba9cf0a3` (Task 2 commit)

---

**Total deviations:** 4 auto-fixed (3 missing-critical-functionality under Rule 2, 1 bug under Rule 1).
**Impact on plan:** All 4 deviations strictly additive to shipped surface; zero scope creep. Each addresses a gap between the plan literal and the plan's stated intent (operational usability of the weekly audit).

## Observation-Window Deferred Verifications

Per VALIDATION.md §Manual-Only and plan `<important_notes>`, 3 success criteria CANNOT be verified inside a PR merge window and must NOT block `/gsd-verify-work`:

| Flag | Description | `verify_type` | Gate-blocking? |
|------|-------------|---------------|----------------|
| bypass-audit-cron-fires | Monday 09:00 UTC cron actually executes once | observation_window (7d) | NO — plumbing verified, observation is post-merge operational validation |
| synthetic-bypass-detected-in-issue | With ≥4 LEFTHOOK_BYPASS / [bypass:] commits in a week, issue is auto-created with label `bypass-audit` | observation_window (requires deliberate bypasses over a week) | NO — logic asserted via PyYAML parse + code-path grep; end-to-end requires live cron firing |
| lefthook-ci-complementarity | Plan 34-07 lefthook-ci.yml catches regressions that bypass-audit would miss | observation_window (requires Plan 07 shipped + PRs through both gates) | NO — Plan 34-07 is future work; positioning (CONTRIBUTING §3, workflow header, issue body) already cites it |

`/gsd-verify-work 34-06` should confirm the 2 automated success criteria (Task 1 + Task 2 grep/parse green) and mark these 3 observation-window items as deferred (flag `verify_type: observation_window`).

## Threat Flags

None — this plan adds documentation (CONTRIBUTING.md) and a CI workflow (bypass-audit.yml). No new network endpoints, no new auth paths, no file-access patterns, no schema changes. `permissions: issues: write` is the only delta vs baseline workflows and is scoped to the default GitHub Actions token (A9).

## Known Stubs

None — both deliverables are load-bearing and fully wired:
- CONTRIBUTING.md §3 documents convention that operators can action today.
- bypass-audit.yml runs on its schedule + push triggers from merge.

The 3 observation-window items above are NOT stubs — they are inherently time-gated and correctly flagged as post-merge operational validation, not pre-merge automated gates.

## Issues Encountered

None — both tasks executed cleanly. Commit-msg hook (GUARD-06, shipped Plan 34-05) validated both commits' `Read:` trailer on first try; pre-commit gates skipped (no matching globs). Total lefthook overhead across 2 commits: 0.14s (0.07 + 0.07 per commit per the hook stderr banners).

## User Setup Required

None — workflow uses only default `GITHUB_TOKEN` (A9 confirmed: default token has `issues: write` on both public and private repos). No external secrets, no dashboard configuration needed beyond the pre-existing "Allow GitHub Actions to create and approve pull requests" setting already used by `sync-branches.yml`.

## Self-Check: PASSED

**Files verified:**
- `CONTRIBUTING.md` — FOUND (155 lines; grep LEFTHOOK_BYPASS=7, lefthook install=2, bypass-audit=3, --no-verify=2, GUARD-=9 all ≥ acceptance thresholds)
- `.github/workflows/bypass-audit.yml` — FOUND (PyYAML safe_load passes; 4 steps; permissions `contents: read` + `issues: write`; schedule cron `0 9 * * 1`; push branches `[dev]`; grep `LEFTHOOK_BYPASS|\[bypass:` patterns both present)
- `.planning/phases/34-agent-guardrails-m-caniques/34-06-READ.md` — FOUND (11 bullet files, `- <path> — <why>` format per D-18)

**Commits verified:**
- `75e1d6d7` — FOUND in git log (`docs(34-06): extend CONTRIBUTING.md with GUARD-07 bypass policy (D-20)`)
- `ba9cf0a3` — FOUND in git log (`feat(34-06): add bypass-audit.yml weekly + post-merge workflow (D-21/D-22)`)

**Lints verified:**
- `python3 tools/checks/accent_lint_fr.py --file CONTRIBUTING.md` — rc=0
- `python3 tools/checks/accent_lint_fr.py --file .github/workflows/bypass-audit.yml` — rc=0
- `grep -iE "garanti|optimal|meilleur|certain|assuré|sans risque|parfait" CONTRIBUTING.md` — 0 matches (LSFin compliance)

**Requirements ledger:**
- `node gsd-tools.cjs requirements mark-complete GUARD-07` — updated=true, marked_complete=[GUARD-07]

## Next Phase Readiness

- **Plan 34-07 (GUARD-08 CI thinning + lefthook-ci.yml) unblocked.** This plan's CONTRIBUTING §6 and bypass-audit.yml file header already cite Plan 34-07 `lefthook-ci.yml` as the PRIMARY regression catcher — when Plan 07 lands, the cross-references resolve transparently without editing this plan's deliverables.
- **6/8 Phase 34 requirements now complete** (GUARD-02, GUARD-03, GUARD-04, GUARD-05, GUARD-06, GUARD-07). Only GUARD-01 (lefthook foundation, implicitly shipped 34-00) and GUARD-08 (CI thinning) remain — both owned by Plan 34-07.
- **Observation-window items (3)** documented as deferred; `/gsd-verify-work 34-06` should NOT block on them.

---
*Phase: 34-agent-guardrails-m-caniques*
*Completed: 2026-04-22*
