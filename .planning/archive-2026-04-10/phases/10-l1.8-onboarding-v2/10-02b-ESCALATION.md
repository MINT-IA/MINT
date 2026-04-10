# 10-02b ESCALATION — STOP before deletion

**Date:** 2026-04-07
**Branch:** feature/v2.2-p0a-code-unblockers
**Phase:** 10-02b (split 2 of 3 — delete 5 onboarding screens + routes)
**Status:** HALTED before any file modification. Nothing committed. Nothing deleted.

## Why stopped

The prompt's PreserveStill check requires:
> Every match outside the file itself must be either the route declaration in
> app.dart, the registry entry, or the co-located test. If any other consumer
> survived 10-02a (e.g., a navigation call somewhere unexpected), STOP and escalate.

Ran `git grep` on each target. Four of the five screens (`quick_start`,
`promise`, `plan`, `premier_eclairage`, `instant_premier_eclairage`) are
clean — their references live only inside the onboarding folder, app.dart,
screen_registry, their co-located tests, and each other. Those four would
delete cleanly.

**But the route `/onboarding/quick` is load-bearing across the app.** The
route itself is one of the five targeted for deletion (it's the `QuickStartScreen`
route). Surviving consumers that `context.push`/`context.go` to it:

### Live `lib/` call sites (13, outside onboarding folder)

| File | Line | Call |
|------|------|------|
| `lib/app.dart` | 919 | `GoRoute('/advisor', redirect → '/onboarding/quick')` |
| `lib/app.dart` | 923 | `/advisor/wizard` redirect → `/onboarding/quick` |
| `lib/app.dart` | 927 | `/onboarding/smart` redirect → `/onboarding/quick` |
| `lib/app.dart` | 928 | `/onboarding/minimal` redirect → `/onboarding/quick` |
| `lib/screens/arbitrage/arbitrage_bilan_screen.dart` | 53 | `context.push('/onboarding/quick')` CTA |
| `lib/screens/budget/budget_screen.dart` | 200, 241 | `EmptyState` CTA route + onCta push |
| `lib/screens/coach/retirement_dashboard_screen.dart` | 916 | CTA button |
| `lib/screens/explore/retraite_hub_screen.dart` | 73 | Hub tile route |
| `lib/screens/onboarding/data_block_enrichment_screen.dart` | 383 | `revenu` block → `/onboarding/quick` (the screen we are told to PRESERVE still links to the deleted route) |
| `lib/screens/pillar_3a_deep/retroactive_3a_screen.dart` | 213 | CTA |
| `lib/screens/pillar_3a_deep/staggered_withdrawal_screen.dart` | 183 | CTA |
| `lib/screens/profile/financial_summary_screen.dart` | 326 | CTA |
| `lib/screens/profile_screen.dart` | 926 | Identity completion tap → `/onboarding/quick` (asserted by `core_app_screens_smoke_test.dart`) |
| `lib/screens/pulse/pulse_screen.dart` | 738 | CTA |
| `lib/screens/timeline_screen.dart` | 253 | Timeline tile route |
| `lib/services/navigation/screen_registry.dart` | 354, 749 | `fallbackRoute: '/onboarding/quick'` on `_budgetOverview` and `_debtRatio` |

### Live widget with `/onboarding/quick-start` CTA

- `lib/widgets/onboarding/premier_eclairage_card.dart:137` — `onNavigate('/onboarding/quick-start')`. This widget is rendered from **10 surfaces** including `mint_home_screen.dart`, multiple arbitrage screens, multiple mortgage screens, and `retroactive_3a_screen`. Deleting the route will silently kill this card's CTA everywhere.

### Test file impact

- `apps/mobile/test/screens/core_app_screens_smoke_test.dart:180-254` — asserts that tapping the profile identity row lands on `QuickStartScreen`. Rewriting requires deciding the replacement destination.
- `apps/mobile/test/screens/onboarding/quick_start_screen_test.dart` — co-located, delete.
- `apps/mobile/test/golden_screenshots/quick_start_screen_golden_test.dart` — delete + bake new golden if replacement exists.
- `apps/mobile/test/i18n/hardcoded_string_audit_test.dart` — static list of audited files; drop the three deleted entries.
- `apps/mobile/test/patrol/onboarding_patrol_test.dart` — references `QuickStartScreen` in a patrol flow.

## The decision that is not mine to make

Every one of those 14+ call sites navigates the user to a *data collection*
surface (age/salaire/canton etc.) when MINT needs more information to serve a
specific feature. That intent does not disappear with 10-02. The app still needs
a "fill in this missing data" surface. **10-02a rewired `intent_screen` →
`/coach/chat` but it did not provide a universal data-capture replacement for
these 14 legacy CTAs.**

Three possible paths, each with different scope and risk:

1. **Add a catch-all redirect `/onboarding/quick → /coach/chat`** (and
   `/onboarding/quick-start`, `/onboarding/premier-eclairage`,
   `/onboarding/promise`, `/onboarding/plan` likewise). Smallest diff. Means
   every legacy CTA silently lands in the coach with no payload context —
   degraded UX for every surface listed above. The 10-02-PLAN.md frontmatter
   explicitly says "no redirect shims unless PRE_AUDIT Section 4 marked SHIMS
   NEEDED" (D-06). PRE_AUDIT was not loadable in my short context; the user
   should confirm whether D-06 permits the shims in light of this surviving
   consumer set.

2. **Migrate every CTA to a new canonical "need-data" destination** (probably
   `/coach/chat` with a `CoachEntrySource.dataCapture` payload, or the
   surviving `data_block_enrichment_screen` which D-02 says to preserve).
   Touches 14 screens. Each CTA carries a different semantic ("missing revenu"
   vs "missing canton" vs "complete profile"), so the replacement payload is
   not mechanical. This is a 10-02d-sized plan, not a 60-minute split.

3. **Defer the deletion of `quick_start_screen` and its route to a later
   plan** and execute 10-02b only on the four clean screens (`promise`,
   `plan`, `premier_eclairage`, `instant_premier_eclairage`). This ships
   partial value now, leaves `QuickStartScreen` in place, and defers the hard
   call-site migration to 10-02c or 10-02d. 10-02-PLAN.md's success criteria
   ("screens-before-first-insight = 2") would not be met by 10-02b alone, but
   the plan was already split into three parts so that's expected.

Also note `data_block_enrichment_screen.dart:383` is itself a forward to
`/onboarding/quick` for the `revenu` block. Since D-02 preserves
data_block_enrichment but the prompt says not to touch it, that line becomes
a broken link under option 1 and a rewrite target under options 2/3.

## What I did NOT do

- No files deleted.
- No routes removed.
- No commits made.
- No `git rm`.
- Working tree is identical to session start for all tracked files.

## Recommended next action

User chooses between options 1/2/3 above, or reads PRE_AUDIT.md Section 4
(which I did not load — my context budget flagged after gathering the
`git grep` evidence above) to see whether the shim question was already
answered there. If PRE_AUDIT Section 4 says "SHIMS NEEDED" then option 1 is
authorised and 10-02b can resume immediately with added redirect routes. If
PRE_AUDIT Section 4 says "NO SHIMS" then option 2 or 3 is required and 10-02b
as currently scoped cannot land.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>
