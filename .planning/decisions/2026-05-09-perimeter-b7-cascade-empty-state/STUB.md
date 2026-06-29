---
name: MVP-B7-CASCADE-EMPTY-STATE-PUSH — perimeter STUB
description: Audit finding 2026-05-08 (PR #533 P1 sweep) — 4 screens use context.go('/coach/chat') from empty-state CTAs. context.go REPLACES the navigation stack so the user lands on the coach without a back-button to the source screen ; if they hit back from coach they end up at the root, losing the screen they came from. Fix is mechanical : convert each empty-state CTA to context.push so the source screen stays underneath. Effort ~0.2 j.
type: decision
date: 2026-05-09
status: SUPERSEDED_FOR_SHELL_TAB_SURFACES
related:
  - .planning/decisions/2026-05-09-perimeter-fatca-calculator-gate/STUB.md
sources:
  - PR #533 audit synthesis P1 sweep B7-cascade line item
  - 4 grep hits in `apps/mobile/lib/screens/` matching empty-state CTAs
---

# MVP-B7-CASCADE-EMPTY-STATE-PUSH — STUB

## 2026-06-29 supersession note

This decision is no longer universal for `/coach/chat`.

`/coach/chat` is a `StatefulShellRoute` branch. On top-level shell surfaces
such as Aujourd'hui and Mon Argent, `context.push('/coach/chat')` can display
Coach while leaving the source tab selected. Those surfaces must use
`context.go('/coach/chat')` so the content and bottom navigation switch
together.

The original B7 rationale still applies to leaf/detail or mid-flow screens
where preserving the source stack is more important until MINT has a
root-owned Coach handoff route that can preserve both tab selection and return
state.

## Goal

**Convert 4 empty-state CTAs from `context.go('/coach/chat')` to `context.push('/coach/chat')`** so the user can back-out of the coach without losing the source screen.

## Background

`context.go` is GoRouter's "navigate" semantics — it REPLACES the current top-of-stack with the destination. When the user hits the OS back button or the in-app back arrow, they land back on whatever was below the source screen, NOT on the source screen itself. This is correct for top-level tab transitions and for "post-login" redirects (login screen should not be reachable via back). It is WRONG for empty-state CTAs that say « parle au coach » because the user expects to come back to the empty-state screen if the coach didn't help.

`context.push` keeps the source screen underneath ; the back button comes back to it.

The 4 specific call sites identified by the audit :

| File | Line | CTA |
|---|---|---|
| `aujourdhui/aujourdhui_screen.dart` | 137 | `FinancialPlanCard.onRecalculate` (stale-plan recalc) |
| `aujourdhui/aujourdhui_screen.dart` | 144 | `ConfidenceScoreCard.onEnrichmentTap` (axis prompt) |
| `aujourdhui/aujourdhui_screen.dart` | 197 | empty-tension-screen GestureDetector (cold profile) |
| `advisor/financial_report_screen_v2.dart` | 78 | `MintEmptyState.onCta` (no wizard answers yet) |
| `pillar_3a_deep/staggered_withdrawal_screen.dart` | 184 | `MintEmptyState.onCta` (no LPP data) |
| `pillar_3a_deep/retroactive_3a_screen.dart` | 215 | `MintEmptyState.onCta` (no 3a data) |

(6 total call sites across 4 files — audit counted screens not call sites.)

## Out of scope

- `financial_report_screen_v2.dart:70 + 96` — these are AppBar back-arrow `IconButton.onPressed` callbacks. They're a different bug pattern (back arrow should `pop` not `go`/`push`), and they're NOT empty-state CTAs. Filed as MVP-BACK-ARROW-POP future perimeter.
- `cantonal_benchmark_screen.dart:79` — already uses the canonical `canPop ? pop : go` fallback pattern, no fix needed.
- `login_screen.dart:63 + 65 + 119` (`register_screen.dart`) — post-auth redirects. `go` is intentional here (login should not be reachable via back). NO change.
- `coach_chat_screen` and `conversation_history_screen` — internal coach navigation. `go` is the right semantics for routing-within-coach.

## Truth-in-claim

- This perimeter contains the bleed at the 4 audited surfaces. It does NOT add a lint rule against `context.go('/coach/...')` from empty-state widgets, so the same anti-pattern can be reintroduced. A future perimeter MVP-NAVIGATION-LINTS could add a `prefer_push_for_empty_state_cta` lint based on widget-tree heuristic.

## 5 gates mécaniques

| Gate | Description | Évidence |
|---|---|---|
| G1 | sim walker — open `/aujourd-hui` empty (cold profile), tap empty-state CTA, lands on coach, hits back → returns to `/aujourd-hui` (not root) | walker logs |
| G2 | device by Julien — same flow on TestFlight v2.12.2+5 | TestFlight |
| G3 | dev CI green — flutter analyze + flutter test | run green |
| G4 | navigation regression test — widget test asserts back-stack depth after empty-state CTA = 2 (source + coach), not 1 (coach only) | new test exit 0 |
| G5 | LSFin/accent/ARB lint — no ARB changes ; lint clean | banned_terms_arb exit 0 |

## Tâches breakdown

| # | Action | Effort | Dépendance |
|---|---|---|---|
| 1 | aujourdhui_screen.dart L137 — `context.go` → `context.push` (FinancialPlanCard.onRecalculate) | 0.02 j | None |
| 2 | aujourdhui_screen.dart L144 — `context.go` → `context.push` (ConfidenceScoreCard.onEnrichmentTap) | 0.02 j | None |
| 3 | aujourdhui_screen.dart L197 — `context.go` → `context.push` (cold-profile GestureDetector) | 0.02 j | None |
| 4 | financial_report_screen_v2.dart L78 — `context.go` → `context.push` (MintEmptyState.onCta) | 0.02 j | None |
| 5 | staggered_withdrawal_screen.dart L184 — `context.go` → `context.push` (MintEmptyState.onCta) | 0.02 j | None |
| 6 | retroactive_3a_screen.dart L215 — `context.go` → `context.push` (MintEmptyState.onCta) | 0.02 j | None |
| 7 | flutter analyze + flutter test for regression | 0.05 j | All |

**Total estimé** : ~0.2 j.

## Counter-arguments and data gaps

- **Risk 1** : If a deep-link pre-loads `/aujourd-hui` and the user tapped through to coach via the empty-state CTA, then back-arrow returns to the deep-link source instead of the app root. Acceptable — that's the better UX (the user was IN the empty-state, and back should bring them back).
- **Risk 2** : `context.push` to a route that already exists in the stack can create duplicates if the user repeatedly taps. Mitigation : the receiving route `coach_chat_screen` does its own state checks. If duplicates become a problem in observability logs, add a `pushReplacement` semantics behind a feature flag. Not needed for v1.
- **Risk 3** : The test plan G4 requires a widget test for navigation depth, but `MintEmptyState` widget tests don't currently spin up a full GoRouter. Could write a minimal mock-router test or defer to manual G1 sim walker. For v1, sim walker is enough.
- **Data gap** : No telemetry on how many users hit the empty-state CTA today (vs. the populated state). Mitigation : log empty-state-cta-tap event for 1 week post-deploy ; size impact based on actual frequency.

## Approval gate

**This PR opens immediately**. The fixes are mechanical, surgical, and reverse cleanly if they cause issues.

## Order of fixes (within this perimeter)

Single commit covering all 6 call sites + STUB + analyze/test pass. No need to break it up.
