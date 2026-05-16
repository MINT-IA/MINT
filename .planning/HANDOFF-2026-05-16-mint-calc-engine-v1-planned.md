---
name: handoff-2026-05-16-mint-calc-engine-v1-planned
description: Session handoff 2026-05-16 evening → next session (execute-phase). Phase mint-calc-engine-v1 fully planned and verified (plan-checker iter-2 VERIFICATION PASSED). State after CONTEXT + RESEARCH + VALIDATION + 20 PLAN.md committed to dev + pushed to origin. A3 PR #643 status pending CI green + merge. First action for next session = `/gsd-execute-phase mint-calc-engine-v1`.
---

# Session handoff — 2026-05-16 evening → next session (execute-phase)

## TLDR (read this first)

- **Phase mint-calc-engine-v1 PLANNED** : 20 PLAN.md files across W0 (DONE) / W1 / W2 / W3 / W4. Plan-checker iter-2 VERIFICATION PASSED 2026-05-16. 20/20 D-CE-XX requirement coverage. Phase status `Ready to execute`.
- **State pushed to origin/dev** at sha `67fd3432` (12 commits rebased on top of `c235e865` PR #642 merge). Branch state clean.
- **A3 PR #643** still OPEN against dev — 5/5 panel CLEAN, CI was running at planning time, NOT yet shipped per 0-TRUST §9. Plan 01 Task 0 absorbs the dependency via Path A (verify import if merged) or Path B (cherry-pick `_response.py` per D-CE-19 Parallel Change ≤80 LOC).
- **First command for next session** : `/gsd-execute-phase mint-calc-engine-v1` (after /clear).
- **All HARD work done** : decisions locked (20 D-CE-XX), research depth (1707 lines), validation contract (38 verify rows), executable plans with deep_work compliance + STRIDE threat models per plan + LSFin lint discipline. The next session is mechanical execution.

## State of the branch (dev) at handoff time

Latest commits on `origin/dev` :

```
67fd3432 docs(state): record mint-calc-engine-v1 planning complete — 20 plans, Ready to execute
bae996f1 docs(mint-calc-engine-v1): plan-checker iter-1 fixes — M-1 + M-2 + m-3/m-4
6fa4c220 docs(mint-calc-engine-v1): 20 PLAN.md across W1-W4 + ROADMAP + STATE
d80c8e7e docs(mint-calc-engine-v1): VALIDATION.md — Nyquist validation contract
6e8d36f2 docs(mint-calc-engine-v1): RESEARCH.md — HOW-to-implement W1-W4 mechanics
c8847795 docs(mint-calc-engine-v1): CONTEXT.md — 20 D-CE-XX locked from 6-panel synthesis
b3f5fa11 docs(handoff): session 2026-05-16 → next session resume brief
3c5d2bbb docs(calc-engine-v1): W0 audit complete — hypothesis C confirmed 86%, Wave 1 scope locks
9efe9bbd docs(calc-engine-v1): D-CE-01 refinement — vendor-agnostic ToolRegistryAdapter
a4c2c5b7 docs(calc-engine-v1): 6-panel synthesis — 11 overrides + 6 critical findings
8acdbd76 docs(calc-engine-v1): KILL Phase 96 chat-as-verb + open mint-calc-engine-v1 discuss-phase
3da30bae docs(wave-1c-A3): lock missing-fields handshake PLAN.md (7 tasks, 2 revision iters green)
c235e865 Merge pull request #642 from MINT-IA/dev   ← prior session tip
```

*Note : shas shifted after `git pull --rebase origin dev` integrated `c235e865`. The pre-rebase shas mentioned in commit messages of `c49460f8 / 2607d1df / 3a073a7c / a6253b29 / bb505875` refer to local-only commits that were rebased into the post-rebase shas above.*

`feature/wave-1c-A3-missing-fields-handshake` branch : local + origin tip both at `4684835b`. (Earlier in this session a stale local commit `3d754f87` on this branch was discarded via `git branch -f` against origin tip — its content is preserved on dev as the CONTEXT.md commit.)

## Phase artifacts (the canonical wiki for next session)

Read in this order if resuming cold :

1. **`.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-CONTEXT.md`** (THE source — 20 D-CE-XX locked decisions, 5 waves, code_context block with file:line for all touchpoints, 4-level lucidité framework, latency contracts, memory contract).
2. **`.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-RESEARCH.md`** (1707-line HOW-to-implement with Anthropic Tool Search patterns, `_resolve_defaults` Pydantic v2 mechanics, discriminated unions, Alembic `autocommit_block`, BackgroundTasks lifecycle, bundle_compiler extension, AST scanner, Prometheus vs Sentry, Validation Architecture section, 6 Open Questions all marked RESOLVED with per-Plan routing).
3. **`.planning/phases/mint-calc-engine-v1/mint-calc-engine-v1-VALIDATION.md`** (Nyquist contract — 38 verify rows per D-CE-XX, 14+ Wave-0 file dependencies, 5 manual-only behaviors, 6 carried Open Questions with default-if-unresolved).
4. **`.planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md`** (49/57 hypothesis C confirmed, 12 sev-3 + 23 sev-2 endpoints, Recommended Fix Priority Order — Plan 02/03/06 follow this verbatim).
5. **20 PLAN.md files** : `mint-calc-engine-v1-{01..20}-*-PLAN.md` with frontmatter (wave, depends_on, files_modified, autonomous, requirements, estimated_duration), XML tasks with `<read_first>` + `<acceptance_criteria>` + `<action>`, STRIDE threat models, must_haves.

Plus the source-of-truth ADRs (frozen, do NOT re-litigate per founder-delegated decision 2026-05-16) :

6. `.planning/decisions/2026-05-16-calc-engine-v1-panel-synthesis.md` — the 20 D-CE-XX verdicts table, 11 overrides, 6 critical findings.
7. `.planning/decisions/2026-05-16-calc-engine-matrix.md` — 11-domain coverage (57 ✅ + 4 ⚠️ + 3 ❌) + hypothesis C audit plan + 4-level lucidité framework.
8. `.planning/decisions/2026-05-16-phase-96-killed.md` — chat-as-verb pivot killed ; what survived (Phases 91/93.5/94/95) and what died.

## Wave structure (mechanical execution order)

| Wave | Plans | Foundation / depends_on | Estimated | Notes |
|---|---|---|---|---|
| W0 | done | DONE 2026-05-16 (W0 matrix shipped) | — | nothing to execute |
| W1 | 01, 02, 03, 04, 05, 06 | 01 first (foundation) ; 02-06 depend on 01 SUMMARY | ~5-7 d | Plan 01 → 02 (Priority-1 sev-3) → 03 (Priority-2 sev-3) → 04 (lucidity payloads, L4 wedge FIRST per Finding 5) → 05 (auto-registry) → 06 (sev-2 batch grounding) |
| W2 | 07, 08, 09, 10, 11 | depends_on 01 + 05 | ~5-7 d | 07 ToolRegistryAdapter → 08 bundles → 09 description rewrite (G2 device) → 10 CoachToolResponseV2 Parallel Change → 11 deprecation shims |
| W3 | 12, 13, 14, 15, 16 | depends_on 05 + 12 + 13 + 14 | ~4-5 d | 12 composite index FIRST (Phase 95 critical gap) → 13 cache reader/writer + singleflight → 14 reverse-dep-map → 15 BackgroundTasks pre-compute → 16 GC (Railway cron, G2 operator) |
| W4 | 17, 18, 19, 20 | depends_on 01 + 13 + 15 | ~3-4 d | 17 metrics (Q1 prom vs sentry decision, G2) → 18 banned-verb lint + runtime gate (BEFORE Phase 94, Q5 resolved) → 19 parity lint → 20 wave-close engram doctrine (5-gate phase close, G2 device) |

**Critical path** : ~3-4 weeks if waves run sequentially. Some W2/W3 plans can overlap once W2 Plan 07 + W3 Plan 12 lands.

## Hard dependencies + risks the executor MUST surface

1. **A3 envelope dependency** (Plan 01 Task 0) :
   - If A3 PR #643 merged to dev by exec time → Path A (verify `from app.models.coach_tools._response import CoachToolResponse, CoachToolOk, CoachToolIncomplete, CoachToolPolicyBlocked` succeeds).
   - If A3 PR #643 still open → Path B (cherry-pick `services/backend/app/models/coach_tools/_response.py` from `feature/wave-1c-A3-missing-fields-handshake` to dev as a single docs+models commit per D-CE-19 Parallel Change, ≤80 LOC).
   - Check status : `gh pr view 643 --json mergedAt,state,statusCheckRollup` before starting Plan 01.

2. **D-CE-08 `PROFILE_GROUNDING_STRICT_MODE` flag rollout** (Plans 01-02-03-06) :
   - Plan 01 declares the flag with default `"false"` (non-strict). raise_incomplete_as_422 dual-path : strict → 422, non-strict → log warning + return body.
   - Plans 02/03/06 parametrize contract tests over both strict modes.
   - Rollout : staging strict=true (initial deploy of W1 PR-1) → prod strict=false (1 release safety net) → prod strict=true (full enforcement at W4 close per Plan 20 G2 checkpoint).

3. **W3 composite index migration** (Plan 12) :
   - MUST use `with op.get_context().autocommit_block():` — `CREATE INDEX CONCURRENTLY` cannot run inside a transaction. Without this, the migration fails with `cannot run inside a transaction block`. Precedent : `p95_dag_invalidation.py`.
   - DEFAULT scenarios table size : ~5.8M rows/year @ 100 DAU. Backfill strategy : start with empty table on staging, measure index build time before applying to prod.

4. **W4 banned-verb runtime gate placement** (Plan 18) :
   - Placement = BEFORE Phase 94 citation gate (Q5 resolved per RESEARCH.md). Catch ranking words on naked text before citation substitution to avoid double-template fallback.

5. **W4 Q1 Prometheus vs Sentry decision** (Plan 17 G2 checkpoint) :
   - Default if no Julien preference = Sentry custom metrics (no new dep, custom tags on `coach_breadcrumbs.py`).
   - Prometheus path requires adding `prometheus-client` to `services/backend/pyproject.toml` + `/metrics` route + Grafana panel access.

6. **Plan 06 scope dette (m-5 from plan-checker)** : Plan 06 declares ~19 files modified + parametrized test on ~25-30 endpoints. Threshold-high. Executor MAY split into Plan 06a + 06b if pre-flight grep shows >25 endpoints. Documented escape-hatch in plan body.

## Pre-execute checklist (FIRST 3 steps of execute-phase)

```bash
# 1. Verify branch state clean
git status  # expect clean working tree
git log --oneline -3  # expect 67fd3432 at HEAD

# 2. Verify Wave 1c-A3 PR #643 status
gh pr view 643 --json mergedAt,state,statusCheckRollup

# 3. Spot-check W0 audit matrix is still accurate (per D-CE-20 per-wave deepening)
# Read .planning/phases/mint-calc-engine-v1/W0-AUDIT-MATRIX.md
# Then `grep -l "_user.profile" services/backend/app/api/v1/endpoints/{arbitrage,mortgage,fiscal,family,lpp_deep}/*.py`
# Expect : 0 hits at planning time. If hits appear, some endpoints have been patched since W0 audit and that's GOOD — exclude from W1 scope.
```

## Engram observations to recall (for next session)

Search keys for `mem_search` :
- `calc_engine:v1:context_md_synthesized_2026_05_16` (obs #117 — CONTEXT.md mechanical synthesis pattern)
- `calc_engine:v1:planning_complete_2026_05_16` (obs #118 — 20 plans + verification PASSED + wave shape)
- `calc_engine:v1:profile_grounding_strict_mode_pattern` (obs #119 — D-CE-08 feature flag dual-path pattern, canonical for future MINT feature-flag wiring)
- Prior session obs (still valid) :
  - `calc_engine:hypothesis_c:audit_confirmed_2026_05_16` (obs #108 — Wave 1 scope locks ALL endpoints)
  - `calc_engine:tool_registry:vendor_agnostic_adapter` (obs #103 — Anthropic decoupling pattern)
  - `calc_engine:panel_synthesis:2026_05_16` (obs ~#102 — panel verdicts source)
  - `coach:tool_use:missing_fields_handshake:wave_a3:pr_opened` (obs #116 — A3 PR #643 OPEN + 5/5 panel CLEAN)
  - `milestone:v2_9:phase_96_status` (obs #95 — Phase 96 KILL)

## Hard constraints (CLAUDE.md repeats — for the executor)

- LSFin banned terms (« garanti / optimal / meilleur / certain / assuré / sans risque / parfait »).
- D-CE-16(b) extended banned verbs (« le plus pertinent », « plus avantageux », « nettement plus », « clairement supérieur », « tu devrais », « il faut », « recommandé »...).
- 100% French accents mandatory (`creer → créer`, `eclairage → éclairage`).
- financial_core SoT (`apps/mobile/lib/services/financial_core/`) — never re-implement `_calculate*()` in services.
- D-CE-09 strangler fig — Plan 05 registry does NOT physically move files. Plan 11 deprecation shims keep canonical paths.
- D-CE-19 Parallel Change — Plan 10 V2 envelope ships ALONGSIDE V1, NEVER modifies V1 classes.
- 0-TRUST § 9 — every wave PR must cite deterministic evidence (sim describe-all, idb snapshot, pytest exit 0, EXPLAIN ANALYZE Index Scan) in the PR body. PR opened ≠ shipped. Tests passing ≠ feature working.
- Conventional commits (feat / fix / docs / chore) + squash merge per CLAUDE.md §4.
- Lefthook gates : memory-retention + wiki-lint + banned-terms + arb-parity not bypassed.

## Counter-arguments and data gaps

**Counter-argument 1** : « 20 plans for a single phase is too many. Why not consolidate to 5-6 « PR-N » plans? »
- Rebuttal : the granularity is 1 plan = 1 PR (Wave 1c-A3 precedent ; memory `feedback_perimeter_5_gates` « 1 perimeter at a time »). Each plan ships independently with its own pre-push panel + Maestro G1 + Julien G2 where applicable. Consolidating would bloat individual PRs beyond reviewer cognitive load.

**Counter-argument 2** : « Plan 01 Task 0 cherry-pick depends on A3 PR #643. If A3 takes 1+ week to merge, Plan 01 blocks indefinitely. »
- Rebuttal : Path B (cherry-pick `_response.py` ≤80 LOC) is a deterministic 30-min operation. The envelope is panel-verified stable per D-CE-19 Option B in progress (engram obs #116). Migration cost ≤200 LOC if W1 demands envelope evolution post-cherry-pick. No indefinite block.

**Counter-argument 3** : « What if Anthropic deprecates the Tool Search Tool beta `tool-search-tool-2025-10-19` mid-phase ? »
- Rebuttal : D-CE-01 ToolRegistryAdapter ships 3 concrete adapters from day 1 — `SkillBundleOnlyAdapter` fallback + `ManualSubsetAdapter` backup are deployable via env-flag flip. Vendor-agnostic by design.

**Data gaps** :
- Did NOT measure baseline calc latency p95 for the 5 chip-emitters. D-CE-12 SLO targets (60 → 80% cache hit rate) are panel-extrapolated. Mitigation : Plan 13 ships pytest-benchmark baseline before locking the SLO.
- Did NOT verify the 12 severity-3 endpoints are ALL still in production today vs. some being deprecated. Mitigation : Plan 02 first task = spot-check `app/api/v1/routes.py` registration before opening the grounding-fix PR.
- Q1 (Prometheus vs Sentry) routing default = Sentry, but Julien G2 checkpoint can flip to Prometheus + Grafana setup. If Prometheus path chosen, Plan 17 estimated_duration grows by ~1 day.

## What's running in background

Nothing currently. All work in this session was synchronous. A3 PR #643 CI was running at planning time — by next-session start it should be green or have surfaced a failure to address.

## FIRST COMMAND to type in next session

```
/clear
/gsd-execute-phase mint-calc-engine-v1
```

The execute-phase workflow will :
1. Read STATE.md (Ready to execute, plan count = 20).
2. Read PHASE_DIR (CONTEXT + RESEARCH + VALIDATION + 20 plans).
3. Group plans by wave for parallel execution.
4. Spawn `gsd-executor` agent per plan in dependency order.
5. Each plan executor opens its own feature branch + commits + opens a PR with the pre-push 5-agent panel per `feedback_design_panel_before_push`.

## Session-end checklist (this session)

- [x] CONTEXT.md generated mechanically from panel synthesis (committed at bb505875 → rebased to c8847795 on origin/dev).
- [x] RESEARCH.md 1707 lines (Open Questions all marked RESOLVED) — committed at a6253b29 → 6e8d36f2 on origin/dev.
- [x] VALIDATION.md Nyquist contract (38 verify rows + 14+ Wave-0 deps) — committed at 3a073a7c → d80c8e7e on origin/dev.
- [x] 20 PLAN.md files across W1-W4 — committed at 2607d1df → 6fa4c220 on origin/dev.
- [x] Plan-checker iter-1 verdict (2 MAJORS + 3 MINORS) → 4 surgical fixes applied at c49460f8 → bae996f1 on origin/dev.
- [x] Plan-checker iter-2 VERIFICATION PASSED — all fixes closed, 0 regressions.
- [x] STATE.md updated (`milestone: v2.10`, `status: Ready to execute`, plan count = 20) — committed at 15b4bfd9 → 67fd3432 on origin/dev.
- [x] Local dev rebased on origin/dev (integrating c235e865 PR #642 merge commit).
- [x] origin/dev pushed (12 commits).
- [x] A3 branch local `3d754f87` duplicate discarded via `git branch -f origin/...` (zero remote impact, content preserved on dev).
- [x] 3 engram observations saved (#117 architecture, #118 decision, #119 pattern).
- [x] HANDOFF.md (this file) written.
- [ ] HANDOFF.md committed + pushed to origin/dev (will follow this file write).
- [ ] mem_session_summary saved (final action).

