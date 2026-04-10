# Phase 8c: Polish Pass #1 - SUMMARY

**Completed:** 2026-04-07
**Status:** GREEN — supervision-only pass, single deliverable shipped, zero code touched
**Branch:** `feature/v2.2-p0a-code-unblockers`

## Plans

| # | Plan | Commits | Outcome |
|---|---|---:|---|
| 08c (no separate plan) | Cross-surface aesthetic delta review | 1 | `docs/POLISH_PASS_1.md` shipped, 13 proposals tagged |

## Deliverables shipped

- `docs/POLISH_PASS_1.md` — 8-section delta report (executive summary, per-surface S0-S5 review, 4 cross-surface coherence tables, element count delta vs Phase 3 baseline, tagged proposal master table, visual benchmarks reminder, anti-shame audit, conclusion + next actions).
- `.planning/phases/08c-polish-pass-1/08c-CONTEXT.md` — phase scope anchor (no separate planner ran).
- `.planning/phases/08c-polish-pass-1/08c-SUMMARY.md` — this file.

## Findings (count by tag)

| Tag | Count | Surfaces affected |
|---|---:|---|
| `hot-fix-now` | **5** | S1 (×1), S2 (×2), S3 (×2) |
| `defer-to-post-milestone` | **6** | S0 (×2), S1 (×1), S2 (×2), S3 (×1) |
| `deferred-to-phase-9` | **2** | S4 (×1), S5 (×1) |
| **Total** | **13** | — |

## Top findings (the 5 hot-fixes)

1. **P-S1-01** — Delete 3 chips on S1 (`intentChipBilan` curriculum framing, `intentChipPrevoyance` retirement-default, `intentChipNouvelEmploi` redundancy). 2 anti-shame trips + 1 redundancy. `intent_screen.dart:66-99`.
2. **P-S2-01** — Delete `StreakBadgeWidget` on S2 Plan Reality card. **Single explicit doctrine-ban-list violation** ("streaks tied to knowledge"). `mint_home_screen.dart:382`.
3. **P-S2-02** — Delete `mintHomeConfidence` + `mintHomeNoActionProjection` suggestion chips. Anti-shame checkpoints 2/3/6. `mint_home_screen.dart:737,765`.
4. **P-S3-01** — Remove `CoachAvatar` (24px gradient dot + "M" letter) from S3 bubble render. Decorative ornament in coach reading zone. `coach_message_bubble.dart:55`.
5. **P-S3-02** — Remove `CoachTierBadge` (SLM/BYOK/Fallback) from S3 bubble render. Developer-metadata leakage. `coach_message_bubble.dart:108-116`.

## Cross-surface coherence verdict

| Axis | Grade |
|---|---|
| Typography scale | A- |
| Spacing rhythm | B+ |
| Chromatic palette | A |
| MTC bloom timing | A |
| Motion curves | A- |

**Overall:** B+, trending A- after the 5 hot-fixes land.

## Element count delta vs Phase 3 baseline

| Surface | Phase 3 pre | Phase 3 post (planned) | HEAD est. | Delta |
|---|---:|---:|---:|---:|
| S0 | 37 | 26 | ~5 | **−21 better** (Phase 7 rebuild) |
| S1 | 13 | 9 | ~13 | **+4 worse** (DELETEs not applied) |
| S2 | 45 | 33 | ~45 | **+12 worse** (DELETEs not applied) |
| S3 | 18 | 13 | ~18 | **+5 worse** (DELETEs not applied) |
| S4 | 24 | 18 | ~18 | **0** (Phase 4 + 8b applied) |
| S5 | 8 | 5 | ~7 | **+2** (legacy, Phase 9) |
| **Aggregate** | **145** | **104** | **~106** | **+2** (S0 over-compensates S1/S2/S3 misses) |

**Root cause:** Phase 3 was scoped audit-only; Phases 8a/8b focused on MTC migration + AAA tokens + microtypo, not the Phase 3 DELETE list for S1/S2/S3. Phase 8c surfaces the gap. The 5 hot-fixes close it.

## Anti-shame audit

- 3 hot-fix anti-shame items (P-S1-01, P-S2-01, P-S2-02) — must land before Phase 10.5 "très belle avant les humains" gate.
- 1 deferred-correctly to Phase 10 (S2 empty state CTA, Phase 10 onboarding rewrite owns it).
- 2 deferred-correctly to Phase 9 (S5 imperative copy + "plan de sortie" → MintAlertObject).
- 1 borderline not flagged (S2 Journey Steps fraction `N/M` — under "personal plan progression" exception).

**Highest gravity:** S2 `StreakBadgeWidget` is the single finding tripping the explicit doctrine ban list. Must not be live at Phase 10.5 or first live a11y session.

## Recommended next actions

1. Open mini-phase `08d-phase-3-delete-enforcement` (or fold into Phase 9 as prerequisite plan) — execute the 5 hot-fixes in one commit sequence.
2. Route the 6 defer items into a Phase 12 `POLISH_PASS_2.md` backlog so they're not lost.
3. Keep P-S4-01 + P-S5-01 as Phase 9 prerequisites — they are *why* MintAlertObject exists.
4. Do NOT open Phase 9 until the 5 hot-fixes land — Phase 9 adds to S5 but does not clean S2.

## Deviations

1. **No screenshot diff for S1/S2/S3** — only landing (4 masters) and MTC (3 masters) have golden masters at HEAD. Source-read + grep-audit substituted for the missing visual diff per Phase 3 D-08 fallback clause. Documented in the report.
2. **Julien sign-off removed** per orchestrator brief (T3 out of touch budget). Replaces ROADMAP §8c success criterion 5 — Claude reviews goldens via Read tool and reports.
3. **Phase 8b re-touch deemed not needed** — `refine-in-8b` proposal count is 0. All findings either land in a hot-fix mini-phase, defer to Phase 12, or are Phase 9 prerequisites.

## Gate results

- `git diff --stat HEAD~1 -- apps/mobile/lib/ services/backend/app/` → empty (verified post-commit, no code touched). ✅
- `docs/POLISH_PASS_1.md` exists with all 8 sections. ✅
- All 13 proposals tagged. ✅

## Branch state

`feature/v2.2-p0a-code-unblockers` — +1 commit from this phase.

## Next

Per recommendation: open mini-phase `08d-phase-3-delete-enforcement` (5 hot-fixes) OR fold those into Phase 9 as a prerequisite cleanup plan. Either way, the StreakBadgeWidget removal is the single non-negotiable item before any "très belle avant les humains" gate runs.
