# Phase 2 Verification: Deletion Spree

**Date:** 2026-04-09
**Status:** PASSED

## Requirements Verification

| Requirement | Status | Evidence |
|-------------|--------|----------|
| KILL-01 | PASSED | `intent_screen.dart` deleted. `/onboarding/intent` redirects to `/coach/chat`. |
| KILL-02 | PASSED | `coach_empty_state.dart` deleted. Zero imports remain. BUG-01 loop structurally impossible. |
| KILL-03 | PASSED | `consent_dashboard_screen.dart` deleted. `/profile/consent` route removed. CGU links go to `/about`. |
| KILL-04 | PASSED | `profile_screen.dart` deleted. Gamification (0%, badges) eliminated. `/profile` redirects to `/coach/chat`. |
| KILL-05 | PASSED | Landing CTA goes directly to `/coach/chat`. Account creation optional. `/coach/chat` is `RouteScope.public`. |
| KILL-06 | PASSED | No N1/N2/N3/Tranquille/Clair/Direct labels found on user-facing surfaces. |
| KILL-07 | PASSED | `main_navigation_shell.dart` + `explore_tab.dart` deleted. 7 hub routes redirect to `/coach/chat`. `/home` redirects to `/coach/chat`. |
| BUG-01 | PASSED | CoachEmptyState widget does not exist. Build method never short-circuits to empty state. |
| BUG-02 | PASSED | 6 tombstone tests prove unauthenticated users cannot reach authenticated routes. |

## Test Results

- **flutter analyze lib/**: 0 new errors (pre-existing issues in legacy duplicate files and ton_chooser only)
- **Architecture tests**: 31/31 passed (including 6 new tombstone tests + 4 guard snapshot tests)
- **Full test suite**: 9236 passed, 6 skipped, 8 failed (all 8 failures pre-existing -- verified by running on stashed pre-change code)

### Pre-existing failures (NOT caused by Phase 2)

1. `coach_chat_test.dart` x2 -- locale-dependent text assertions (pre-existing)
2. `navigation_route_integrity_test.dart` x1 -- legacy duplicate files with spaces (pre-existing)
3. `onboarding_patrol_test.dart` x2 -- patrol device test (pre-existing)
4. `document_patrol_test.dart` x1 -- patrol device test (pre-existing)
5. `golden_screenshot_test.dart` x2 -- golden pixel comparison (pre-existing)
6. `ton_chooser_test.dart` -- missing i18n getters (pre-existing)

## Files Deleted

| File | Requirement |
|------|-------------|
| `lib/widgets/coach/coach_empty_state.dart` | KILL-02 |
| `lib/screens/onboarding/intent_screen.dart` | KILL-01 |
| `lib/screens/consent_dashboard_screen.dart` | KILL-03 |
| `lib/screens/profile_screen.dart` | KILL-04 |
| `lib/screens/main_navigation_shell.dart` | KILL-07 |
| `lib/screens/main_tabs/explore_tab.dart` | KILL-07 |
| `test/screens/onboarding/intent_screen_test.dart` | KILL-01 |
| `test/screens/consent_dashboard_test.dart` | KILL-03 |
| `test/screens/cta_navigation_regression_test.dart` | KILL-04 |
| `test/screens/coach/navigation_shell_test.dart` | KILL-07 |
| `test/screens/coach/tab_deep_link_test.dart` | KILL-07 |
| `test/screens/main_tabs/explore_tab_test.dart` | KILL-07 |
| `test/screens/main_tabs/explore_tab_readiness_test.dart` | KILL-07 |
| `integration_test/onboarding_v2_golden_path_test.dart` | KILL-01 |

**Total files deleted: 14**

## Routes Modified

| Route | Change |
|-------|--------|
| `/onboarding/intent` | Builder -> redirect to `/coach/chat` |
| `/profile` | Builder -> redirect to `/coach/chat` (sub-routes preserved) |
| `/profile/consent` | Removed entirely |
| `/home` | Builder -> redirect to `/coach/chat` |
| `/explore/retraite` | Builder -> redirect to `/coach/chat` |
| `/explore/famille` | Builder -> redirect to `/coach/chat` |
| `/explore/travail` | Builder -> redirect to `/coach/chat` |
| `/explore/logement` | Builder -> redirect to `/coach/chat` |
| `/explore/fiscalite` | Builder -> redirect to `/coach/chat` |
| `/explore/patrimoine` | Builder -> redirect to `/coach/chat` |
| `/explore/sante` | Builder -> redirect to `/coach/chat` |
| `/coach/chat` | Scope changed: authenticated -> public |

**Routes removed: 1** (consent)
**Routes redirected: 11**

## What Survived

- All services, providers, calculators, models
- Hub screen FILES (Phase 3 makes them chat-summoned drawers)
- `/profile/byok`, `/profile/slm`, `/profile/bilan`, `/profile/privacy-control`, `/profile/admin-*`
- Auth service + register_screen.dart (for optional account creation)
- consent_manager service (for Phase 3 inline consent)
- Guard snapshot golden file (updated to reflect new state)
