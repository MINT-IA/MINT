---
name: MVP-B7-CASCADE-EMPTY-STATE-COACH-BRANCH — perimeter STUB
description: Superseded audit finding 2026-05-08. The old push recommendation is no longer valid for /coach/chat because Coach is a StatefulShellRoute branch. Until a root-owned Coach handoff route exists, product CTAs select Coach with context.go('/coach/chat...') so tab, URL, and visible surface stay coherent.
type: decision
date: 2026-05-09
status: SUPERSEDED_FOR_SHELL_TAB_SURFACES
related:
  - .planning/decisions/2026-05-09-perimeter-fatca-calculator-gate/STUB.md
sources:
  - PR #533 audit synthesis P1 sweep B7-cascade line item
  - 4 grep hits in `apps/mobile/lib/screens/` matching empty-state CTAs
---

# MVP-B7-CASCADE-EMPTY-STATE-COACH-BRANCH — STUB

## 2026-06-29 supersession note

This decision is superseded for `/coach/chat`.

`/coach/chat` is a `StatefulShellRoute` branch. On top-level shell surfaces
such as Aujourd'hui and Mon Argent, `context.push('/coach/chat')` can display
Coach while leaving the source tab selected. Those surfaces must use
`context.go('/coach/chat')` so the content and bottom navigation switch
together.

The original B7 stack-preservation rationale does not safely apply to the
Coach shell branch. Leaf/detail or mid-flow screens that need both a coherent
Coach tab and return state must get a dedicated root-owned Coach handoff route.
Until that route exists, product code must not `push('/coach/chat...')`.

## Goal

**Keep `/coach/chat` branch selection coherent**: product code uses
`context.go('/coach/chat...')`, and `navigation_push_doctrine_test.dart`
blocks `context.push('/coach/chat...')`.

## Background

`context.go` is GoRouter's "navigate" semantics — it REPLACES the current top-of-stack with the destination. When the user hits the OS back button or the in-app back arrow, they land back on whatever was below the source screen, NOT on the source screen itself. This is correct for top-level tab transitions and for "post-login" redirects (login screen should not be reachable via back). It is WRONG for empty-state CTAs that say « parle au coach » because the user expects to come back to the empty-state screen if the coach didn't help.

`context.push` keeps the source screen underneath for ordinary leaf routes, but
it is wrong for `/coach/chat` while Coach is a shell branch: it can desync the
selected bottom tab from the visible Coach surface.

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

- This perimeter contains the bleed for `/coach/chat` branch selection. It does
  not create the future root-owned Coach handoff route, so source-screen return
  state remains a separate design task.

## 5 gates mécaniques

| Gate | Description | Évidence |
|---|---|---|
| G1 | sim walker — open `/aujourd-hui` empty (cold profile), tap empty-state CTA, lands on coach, hits back → returns to `/aujourd-hui` (not root) | walker logs |
| G2 | device by Julien — same flow on TestFlight v2.12.2+5 | TestFlight |
| G3 | dev CI green — flutter analyze + flutter test | run green |
| G4 | navigation regression test — architecture test asserts no product code pushes `/coach/chat...` | new test exit 0 |
| G5 | LSFin/accent/ARB lint — no ARB changes ; lint clean | banned_terms_arb exit 0 |

## Tâches breakdown

| # | Action | Effort | Dépendance |
|---|---|---|---|
| 1 | Aujourdhui CTAs remain `context.go('/coach/chat...')` because they are shell branch transitions | 0.02 j | None |
| 2 | `financial_report_screen_v2.dart` empty-state CTA uses `context.go('/coach/chat')` | 0.02 j | None |
| 3 | `staggered_withdrawal_screen.dart` empty-state CTA uses `context.go('/coach/chat')` | 0.02 j | None |
| 4 | `retroactive_3a_screen.dart` empty-state CTA uses `context.go('/coach/chat')` | 0.02 j | None |
| 5 | `budget_setup_screen.dart` fallback CTA uses `context.go('/coach/chat?topic=budget')` | 0.02 j | None |
| 6 | Architecture test blocks future `context.push('/coach/chat...')` product call sites | 0.08 j | 1-5 |
| 7 | flutter analyze + targeted route/navigation tests | 0.05 j | All |

**Total estimé** : ~0.2 j.

## Counter-arguments and data gaps

- **Risk 1** : Users coming from a leaf screen lose source-screen return state
  when the CTA switches to Coach with `go`. Accepted until a root-owned Coach
  handoff route exists, because tab/URL/surface coherence is the current P0.
- **Risk 2** : Reintroducing `push('/coach/chat')` will recreate stale Coach
  tab state. Mitigation: `navigation_push_doctrine_test.dart` blocks product
  call sites.
- **Risk 3** : The test plan G4 requires a widget test for navigation depth, but `MintEmptyState` widget tests don't currently spin up a full GoRouter. Could write a minimal mock-router test or defer to manual G1 sim walker. For v1, sim walker is enough.
- **Data gap** : No telemetry on how many users hit the empty-state CTA today (vs. the populated state). Mitigation : log empty-state-cta-tap event for 1 week post-deploy ; size impact based on actual frequency.

## Approval gate

**This PR opens immediately**. The fixes are mechanical, surgical, and reverse cleanly if they cause issues.

## Order of fixes (within this perimeter)

Single commit covering all 6 call sites + STUB + analyze/test pass. No need to break it up.
