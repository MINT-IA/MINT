---
phase: 12-l1.6c-ton-ux-ship-gate
type: context
milestone: v2.2 La Beauté de Mint
locked: true
date: 2026-04-07
---

# Phase 12 — L1.6c "Ton" UX Setting + Ship Gate (CONTEXT)

> This is the last phase of v2.2. It is the ship gate: "is MINT ready to be shown to a real human?" — NOT "is MINT ready for TestFlight global release". Scope is frozen here.

## Mission

1. Expose the user-facing **"Ton"** chooser (`soft` / `direct` (default) / `unfiltered`) wired to `CoachProfile.voiceCursorPreference`, in both first launch (`intent_screen.dart`) and settings (`ProfileDrawer`).
2. Close every remaining v2.2 CI gate.
3. Run the deferred-from-Phase-1 human gates (STAB-18 walkthrough, PERF-01..04 Galaxy A14 baseline) and the deferred-from-Phase-8b live a11y sessions.
4. Decide ship-or-descope.

## Prerequisite surfaced by Phase 8b STATUS

**ACCESS-01 email send is a HARD PREREQUISITE for Phase 12 execution.**
As of 2026-04-08, `docs/ACCESSIBILITY_TEST_LAYER1.md` still shows 6 PENDING rows with no contact names, no send dates, no replies. Phase 8b-04 deferred its live session to Phase 12 on the assumption that emails would be sent before Phase 12 opens. Plan 12-06 Task 0 re-checks this and, if still not sent, escalates immediately.

This is also the scope concern raised to the orchestrator in the return summary.

## Locked Decisions

### D-01 — Ton chooser visual: **segmented control** (Linear/Things 3 style)
Three horizontally-laid pill cells, equal width, selected cell fills with `MintColors.accent` at full opacity, unselected cells use surface tint. Not cards (too heavy for a 3-choice), not a dropdown (hides options, wrong affordance for a one-shot identity choice). Tap target ≥ 48dp per cell (ACCESS-03). Each cell shows the label ("Doux" / "Direct" / "Cru") and an `@meta level:` localized micro-example under it (one line, ≤ 60 chars, Flesch-Kincaid ≤ B1). Wrapped in a `Semantics(container: true, label: ...)` for TalkBack (ACCESS-05 trap sweep item for DropdownMenu → now segmented control).

### D-02 — First-launch invocation: **post-CTA, pre-chat, standalone sheet**
On `intent_screen.dart`, after the user taps the intent CTA ("Je veux commencer"), before routing to the first coach message, we push a full-screen modal sheet titled "Choisis le ton de Mint". Three reasons: (1) the intent CTA is the commitment moment, so Ton comes immediately after and before the first voice-bearing message; (2) pre-CTA would bloat the landing and fight the Aesop minimalism direction from Phase 7; (3) standalone sheet forces a conscious choice and lets us log the selection as an analytics event (`voice_ton_set_first_launch`). Skippable via a small "Plus tard" text link in the corner → writes `direct` (default). In `ProfileDrawer`, the chooser lives inline under a "Voix" section heading (no sheet), tapping a cell writes immediately.

### D-03 — Profile sync: **optimistic local update + async backend save, with rollback toast on failure**
Tap → local `CoachProfile.voiceCursorPreference` updated via `CoachProfileProvider` and persisted to secure storage → UI reflects the new state in ≤ 16ms → backend `PATCH /api/v1/profile` fires in background → on 4xx/5xx, local state rolls back to previous value and a neutral `MintAlertObject` toast surfaces ("Ton non enregistré — on réessaiera."). No banned terms, no shame, no retry button (MINT retries silently on next profile sync tick). This matches the Phase 2 `ProfileProvider` pattern already used for other fields.

### D-04 — WCAG 2.1 AA gate scope: **every Dart file under `apps/mobile/lib/screens/`, `apps/mobile/lib/widgets/`, and `apps/mobile/lib/l10n/` that was touched in v2.2 (any commit between the milestone branch-off and Phase 12)**
Enumerated via `git diff --name-only origin/main...HEAD -- apps/mobile/lib/screens/ apps/mobile/lib/widgets/ apps/mobile/lib/l10n/` at Phase 12 start, committed as `docs/WCAG_AA_SURFACE_LIST.md`. The existing AAA gate on S0-S5 stays AAA; this AA gate is the **floor** for everything else. CI runs `flutter test test/accessibility/wcag_aa_all_touched_test.dart` which loads the surface list at test time and calls `meetsGuideline(textContrastGuideline, androidTapTargetGuideline)` on each surface via a widget harness. Surfaces that cannot be harnessed (deep-nav stateful widgets) get an explicit skip with a comment and a tracking row in the surface list. No silent skips.

### D-05 — BloomStrategy lint: **Dart `custom_lint` package**
Not a Python grep gate. The rule checks for `MintTypewriterController(...)` or `MTC(...)` instantiations and requires a named `strategy:` argument. Default rule: feed contexts (any file whose path contains `main_tabs`, `feed`, `aujourdhui`, or `home`) must use `BloomStrategy.onlyIfTopOfList`, standalone contexts (everything else) must use `BloomStrategy.firstAppearance`. Rule file: `apps/mobile/custom_lint/lib/bloom_strategy_rule.dart`. CI wiring: `dart run custom_lint` after `flutter analyze`. Existing MTC callsites enumerated in Plan 12-03 task 1; retrofit in task 2; CI gate in task 3.

### D-06 — ComplianceGuard regression scope: **enumerated-list approach, not pattern-matched**
The "every output channel" list is authored as `docs/COMPLIANCE_REGRESSION_v2.2.md` section "Channels Under Test", one row per channel, each row has (id, channel, entry point file, test fixture). Authored from grep of `ComplianceGuard.check(` + manual audit of v2.0/v2.1/v2.2 SUMMARYs. Canonical channels: (1) alerts (MintAlertObject), (2) biography/narrative, (3) openers/greetings, (4) extraction (data reader), (5) all 30 rewritten L1.6b coach phrases, (6) voice cursor outputs at N1-N5 (5 rows), (7) Ton chooser micro-examples (3 rows: soft/direct/unfiltered), (8) regional voice overlays per canton group, (9) landing v2 copy, (10) onboarding v2 copy. Total ~50 rows. Each row runs via a single parameterized `test/compliance/regression_v2_2_test.dart`. Zero violations = ship gate B4 green.

### D-07 — A14 perf gate: **reuse Phase 10.5 `tools/scripts/build_a14.sh`, extend the recording protocol**
Same APK build, same device id env var, same frame dump folder convention. Protocol extension: in addition to the Phase 10.5 cold-start + golden-path recording, Phase 12 captures three named runs per metric: `cold_start_1/2/3` (median taken), `scroll_aujourdhui_10s` (10s sustained scroll, median frame time), `bloom_s0_s5` (per-surface bloom capture, count dropped frames). Results appended to a NEW file `.planning/perf/A14_BASELINE.md` (NOT `docs/A14_BASELINE.md` per REQUIREMENTS PERF-01 canonical path). Targets per REQ: cold start < 2500ms, scroll median ≥ 55fps p95 ≥ 50fps, bloom 0 dropped frames across 16-frame budget.

### D-08 — Live a11y session enforcement: **deterministic decision tree in Plan 12-06**
Trigger evaluation happens at Plan 12-06 Task 0 (prerequisite check) AND Task 7 (final sign-off):

- **Happy path (3 sessions landed):** AAA honesty gate = MET, ship as AAA on S0-S5.
- **Partial (2 sessions landed, 1 partner ghosted despite 2 email sends and > 14 days since last ping):** Commit `decisions/ADR-20260XXX-access-09-aa-descope.md` per ACCESS-09, ship with "AAA descoped to AA + documented gaps" note in `docs/ACCESSIBILITY_TEST_LAYER1.md`, append gap list.
- **Not enough (≤ 1 session landed OR ≥ 2 partners ghosted OR ACCESS-01 emails still not sent at Phase 12 open):** **Phase 12 BLOCKS.** Ship gate fails. Orchestrator escalates to Julien: either (a) wait on sessions (milestone waits — doctrine from Phase 1 SC 1), or (b) explicit scope carve to a Phase 12.5. No silent drop. No unilateral Claude descope.

### D-09 — Analytics on Ton chooser
Two events: `voice_ton_set_first_launch` (fired once from `intent_screen` sheet) and `voice_ton_changed_settings` (fired each time from `ProfileDrawer`). Payload: `{from: <prev>, to: <new>, source: 'first_launch'|'settings'}`. No PII. Wired through existing `AnalyticsService` (same pattern as Phase 2 profile events).

### D-10 — Word "curseur" grep gate
CI gate `tools/ci/grep_no_user_facing_curseur.sh`: `git grep -niE '\bcurseur' apps/mobile/lib/l10n/*.arb` must return 0 rows outside of `@meta` metadata keys. Label is always "Ton". Internal code keeps `voiceCursorPreference` unchanged — grep is scoped to ARB files only.

## Deferred Ideas (MUST NOT appear in plans)

- Focus mode (ambient dim at N4/N5, Reichenstein pattern) — open question Q4 in REQUIREMENTS, still deferred; A14 baseline headroom will NOT be used this milestone to promote it, document as "post-v2.2" in ship gate report.
- TestFlight global release — this phase is "ready for humans", not "ready for stores".
- Post-milestone editorial cadence setup — queued for v2.3 kickoff.
- Any AAA expansion beyond S0-S5.

## Claude's Discretion

- Exact copy of the 3 Ton micro-examples (subject to D-06 compliance regression and @meta level tagging).
- Layout of the "Plus tard" skip affordance in the first-launch sheet.
- Exact CI file path layout under `tools/ci/` as long as gates are invoked from the main CI config.
- Internal structure of `docs/SHIP_GATE_v2.2.md` matrix as long as all 13 checklist items appear.

## Ship Gate Criteria (13 items — this is the checklist Plan 12-05 verifies)

From ROADMAP §Phase 12 SC 7 expanded + SC 1-6 collapsed to single items:

1. `flutter analyze lib/` → 0
2. `flutter test` → all green
3. `pytest tests/ -q` (services/backend) → all green
4. `ruff check` → 0
5. Codegen drift guards (OpenAPI + freezed + VoiceCursorContract) → clean
6. Contrast matrix (ACCESS-03 WCAG AA + ACCESS-04 AAA S0-S5) → green
7. Flesch-Kincaid ARB gate → green
8. `chiffre_choc` grep gate in `lib/`, `app/`, `l10n/` → 0
9. `REGIONAL_MAP` grep gate → green
10. `no_legacy_confidence_render` grep gate → green
11. `no_llm_alert` grep gate → green
12. Banned-terms grep gate (garanti, optimal, meilleur, etc.) → 0
13. Sentence-subject ARB lint + `@meta level:` lint + `curseur` user-facing grep (D-10) → 0

Plus the human gates handled in Plan 12-06:
- A14 cold start < 2500ms (PERF-01)
- A14 scroll fps targets (PERF-02)
- A14 bloom 0 dropped frames (PERF-03)
- STAB-18 walkthrough signed
- Live a11y sessions decision tree (D-08) resolved
- ComplianceGuard regression report committed with 0 violations (B4)

## Plan Map (decision coverage matrix)

| D-XX | Plan | Task | Full |
|------|------|------|------|
| D-01 | 12-01 | 1,2 | Full |
| D-02 | 12-01 | 1,3 | Full |
| D-03 | 12-01 | 2 | Full |
| D-04 | 12-02 | 1,2 | Full |
| D-05 | 12-03 | 1,2,3 | Full |
| D-06 | 12-04 | 1,2 | Full |
| D-07 | 12-06 | 2 | Full |
| D-08 | 12-06 | 0,7 | Full |
| D-09 | 12-01 | 2 | Full |
| D-10 | 12-01 | 3, 12-05 | Full |

## Plans

- `12-01-PLAN.md` — Ton chooser (intent_screen sheet + ProfileDrawer inline + 6-lang ARB + analytics + optimistic sync)
- `12-02-PLAN.md` — WCAG 2.1 AA CI gate across touched surfaces (ACCESS-03)
- `12-03-PLAN.md` — BloomStrategy custom lint (PERF-05)
- `12-04-PLAN.md` — Final ComplianceGuard regression run + `docs/COMPLIANCE_REGRESSION_v2.2.md` (B4)
- `12-05-PLAN.md` — All-gates-green sweep + `docs/SHIP_GATE_v2.2.md` 13-item matrix
- `12-06-PLAN.md` — **Human-gated:** STAB-18 walkthrough (T5) + A14 perf baseline (T6) + live session decision tree (T7) + ship-or-descope sign-off
