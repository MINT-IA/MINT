---
phase: 01-pre-refactor-cleanup
verified: 2026-04-05T16:00:00Z
status: gaps_found
score: 4/6 must-haves verified
gaps:
  - truth: "Each of the 3 duplicate service pairs has exactly one surviving canonical file"
    status: failed
    reason: "2 of 3 planned deletions were not performed. apps/mobile/lib/services/gamification/community_challenge_service.dart (301 lines, separate implementation) and apps/mobile/lib/services/memory/goal_tracker_service.dart (21-line re-export shim) both still exist on disk. The executor's commit message claimed they were 'already absent' — they were not. They existed in HEAD before phase 1 and remain in HEAD after phase 1."
    artifacts:
      - path: "apps/mobile/lib/services/gamification/community_challenge_service.dart"
        issue: "Should have been deleted per plan acceptance criteria. Still exists (301 lines). Has 0 lib/ importers. Only imported by its own test file."
      - path: "apps/mobile/lib/services/memory/goal_tracker_service.dart"
        issue: "Should have been deleted per plan acceptance criteria. Still exists (21-line re-export shim). Has 0 lib/ importers. Only imported by its own re-export test."
    missing:
      - "Delete apps/mobile/lib/services/gamification/community_challenge_service.dart"
      - "Delete apps/mobile/lib/services/memory/goal_tracker_service.dart (re-export shim — canonical is coach/goal_tracker_service.dart)"
      - "Update or remove apps/mobile/test/services/gamification/community_challenge_service_test.dart (imports deleted path)"
      - "Update or remove apps/mobile/test/services/memory/goal_tracker_service_test.dart (imports deleted path, tests the shim)"
      - "Verify flutter analyze stays clean after deletion"
  - truth: "A grep for each of the three duplicate service pairs returns exactly one canonical import path across the entire codebase"
    status: failed
    reason: "community_challenge_service has two distinct import paths in the codebase (coach/ imported by its own file, gamification/ imported by test). goal_tracker_service has two import paths (coach/ imported by 5 lib/ files, memory/ imported by 1 test file). The roadmap SC-1 requires exactly one canonical import path per pair across the entire codebase — test imports of non-canonical paths violate this."
    artifacts:
      - path: "apps/mobile/test/services/gamification/community_challenge_service_test.dart"
        issue: "Imports non-canonical gamification/ path. Should import coach/ canonical or be deleted."
      - path: "apps/mobile/test/services/memory/goal_tracker_service_test.dart"
        issue: "Imports non-canonical memory/ re-export shim path. Should import coach/ canonical directly."
    missing:
      - "After deleting gamification/community_challenge_service.dart, update or remove its test"
      - "After deleting memory/goal_tracker_service.dart, update its test to import from coach/ path"
---

# Phase 01: Pre-Refactor Cleanup Verification Report

**Phase Goal:** The codebase has no duplicate service copies, no orphan routes, and a verified route table — safe to build on
**Verified:** 2026-04-05T16:00:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Each of the 3 duplicate service pairs has exactly one surviving canonical file | ✗ FAILED | Pair 1 (coach_narrative_service): VERIFIED — coach/ copy deleted, root canonical exists. Pair 2 (community_challenge_service): FAILED — gamification/ copy still exists (301 lines). Pair 3 (goal_tracker_service): FAILED — memory/ re-export shim still exists (21 lines). |
| 2 | No Dart file in lib/ imports a deleted service path | ✓ VERIFIED | grep for coach/coach_narrative_service, gamification/community_challenge, memory/goal_tracker in lib/: all return 0 results. |
| 3 | flutter analyze reports 0 errors after all deletions | ✓ VERIFIED | `flutter analyze --no-pub` returns "No issues found!" |
| 4 | Every GoRoute entry in app.dart is live, redirected, or explicitly archived | ✓ VERIFIED | All 7 Wire Spec V2 P4 redirects present (/ask-mint, /tools, /coach/cockpit, /coach/checkin, /coach/refresh, /onboarding/smart, /advisor). flutter analyze clean confirms no broken builder references. |
| 5 | Stale "4 tabs" comment in app.dart updated to reflect 3 tabs + drawer | ✓ VERIFIED | Line 245: `// -- Main Shell (3 tabs: Aujourd'hui, Coach, Explorer + ProfileDrawer) --` |
| 6 | A grep for each of the 3 duplicate service pairs returns exactly one canonical import path across the entire codebase | ✗ FAILED | community_challenge_service: two import paths exist (coach/ in service file, gamification/ in test). goal_tracker_service: two import paths exist (coach/ in 5 lib files, memory/ in test). This fails Roadmap SC-1. |

**Score:** 4/6 truths verified

### Deferred Items

None. No later phases in the roadmap address duplicate service cleanup — this is Phase 1's explicit scope.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `apps/mobile/lib/services/coach_narrative_service.dart` | Canonical narrative service (root, 1457 lines) | ✓ VERIFIED | File exists, imported by retirement_dashboard_screen.dart and coach_briefing_card.dart |
| `apps/mobile/lib/services/coach/community_challenge_service.dart` | Canonical community challenge service (536 lines) | ✓ VERIFIED | File exists, 0 lib/ importers (community feature not yet wired) |
| `apps/mobile/lib/services/coach/goal_tracker_service.dart` | Canonical goal tracker service (273 lines) | ✓ VERIFIED | File exists, imported by 5 lib/ files (all canonical path) |
| `apps/mobile/lib/services/coach/coach_narrative_service.dart` | Should NOT exist (deleted duplicate) | ✓ VERIFIED ABSENT | File absent — correctly deleted in commit 1872a9b3 |
| `apps/mobile/lib/services/gamification/community_challenge_service.dart` | Should NOT exist (deleted duplicate) | ✗ STILL EXISTS | 301-line file present on disk, 0 lib/ importers, 1 test importer |
| `apps/mobile/lib/services/memory/goal_tracker_service.dart` | Should NOT exist (deleted re-export shim) | ✗ STILL EXISTS | 21-line re-export shim present on disk, 0 lib/ importers, 1 test importer |
| `apps/mobile/lib/app.dart` | Clean route table with stale comment fixed | ✓ VERIFIED | Comment updated, 7 Wire Spec V2 redirects intact, 146 GoRoute entries |
| `apps/mobile/test/screens/core_app_screens_smoke_test.dart` | Updated test without AskMintScreen references | ✓ VERIFIED | No AskMintScreen references found |
| `apps/mobile/lib/services/navigation_shell_state.dart` | Extracted NavigationShellState (from pulse_screen deletion) | ✓ VERIFIED | File exists — extracted before pulse_screen.dart was deleted |

### Dead Screen Deletions

All 15 dead screen files were correctly deleted:

| Screen File | Status |
|-------------|--------|
| `screens/ask_mint_screen.dart` | ✓ ABSENT |
| `screens/coach/annual_refresh_screen.dart` | ✓ ABSENT |
| `screens/coach/coach_checkin_screen.dart` | ✓ ABSENT |
| `screens/coach/cockpit_detail_screen.dart` | ✓ ABSENT |
| `screens/tools_library_screen.dart` | ✓ ABSENT |
| `screens/pulse/pulse_screen.dart` | ✓ ABSENT |
| `screens/onboarding/smart_onboarding_screen.dart` | ✓ ABSENT |
| `screens/onboarding/smart_onboarding_viewmodel.dart` | ✓ ABSENT |
| `screens/onboarding/steps/step_chiffre_choc.dart` | ✓ ABSENT |
| `screens/onboarding/steps/step_jit_explanation.dart` | ✓ ABSENT |
| `screens/onboarding/steps/step_next_step.dart` | ✓ ABSENT |
| `screens/onboarding/steps/step_ocr_upload.dart` | ✓ ABSENT |
| `screens/onboarding/steps/step_questions.dart` | ✓ ABSENT |
| `screens/onboarding/steps/step_stress_selector.dart` | ✓ ABSENT |
| `screens/onboarding/steps/step_top_actions.dart` | ✓ ABSENT |

budget_screen.dart was correctly preserved — the plan's research had flagged it as dead, but pre-deletion analysis revealed it is live (imported by budget_container_screen.dart).

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `screens/coach/retirement_dashboard_screen.dart` | `services/coach_narrative_service.dart` | `import package:mint_mobile/services/coach_narrative_service.dart` | ✓ WIRED | Import confirmed present |
| `widgets/coach/coach_briefing_card.dart` | `services/coach_narrative_service.dart` | `import package:mint_mobile/services/coach_narrative_service.dart` | ✓ WIRED | Import confirmed present |
| `app.dart` | deleted screen files | No builder import | ✓ WIRED | flutter analyze clean; no broken builder references to deleted screens |
| `screens/main_navigation_shell.dart` | `services/navigation_shell_state.dart` | import | ✓ WIRED | NavigationShellState extracted and imported |
| `widgets/pulse/cap_card.dart` | `services/navigation_shell_state.dart` | import | ✓ WIRED | Importer updated after pulse_screen.dart deletion |

### Data-Flow Trace (Level 4)

Not applicable. Phase 1 is a deletion/cleanup phase — no new components with data rendering were introduced.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| flutter analyze: 0 errors after deletions | `flutter analyze --no-pub` | "No issues found!" | ✓ PASS |
| Wire Spec V2 redirects intact | grep for all 7 redirect paths in app.dart | All 7 present: /ask-mint, /tools, /coach/cockpit, /coach/checkin, /coach/refresh, /onboarding/smart, /advisor | ✓ PASS |
| Stale comment fixed | grep for "3 tabs" in app.dart L245 | `// -- Main Shell (3 tabs: Aujourd'hui, Coach, Explorer + ProfileDrawer) --` | ✓ PASS |
| lib/ code imports only canonical service paths | grep for non-canonical paths in lib/ | 0 results for gamification/ or memory/ imports in lib/ | ✓ PASS |
| Duplicate service files deleted | File existence checks | Pair 2 (gamification/) and Pair 3 (memory/) still exist on disk | ✗ FAIL |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CLN-01 | 01-01-PLAN.md | Duplicate service pairs resolved (canonical imports only, no re-exports masquerading as separate services) | ✗ PARTIAL | 1 of 3 duplicate pairs resolved. gamification/community_challenge_service.dart and memory/goal_tracker_service.dart still exist on disk and are testable via non-canonical import paths. |
| CLN-02 | 01-02-PLAN.md | Orphan routes triaged — each of 67 canonical routes is live, redirected, or explicitly archived | ✓ SATISFIED | flutter analyze clean, 7 Wire Spec V2 redirects present, no builder references to deleted screens. Route table audited per plan. |
| CLN-03 | 01-02-PLAN.md | Dead screens removed (screens with no route pointing to them) | ✓ SATISFIED | All 15 targeted dead screen files deleted. budget_screen.dart correctly preserved (it is live). flutter analyze: 0 errors. |

### Anti-Patterns Found

| File | Pattern | Severity | Impact |
|------|---------|----------|--------|
| `lib/services/gamification/community_challenge_service.dart` | Duplicate service file — separate implementation of CommunityChallengeService should have been deleted | ⚠️ Warning | Not a runtime blocker (0 lib/ importers) but represents undone cleanup work. Two implementations of the same concept create divergence risk in future phases. |
| `lib/services/memory/goal_tracker_service.dart` | Re-export shim should have been deleted | ⚠️ Warning | Not a runtime blocker (0 lib/ importers) but creates a non-canonical import path that test files use. Shim pattern was explicitly targeted for removal in the plan. |

### Human Verification Required

None. All verification was achievable programmatically for this deletion/cleanup phase.

### Gaps Summary

Phase 1 successfully completed the route audit, dead screen deletion, and stale comment fix (CLN-02, CLN-03). However, CLN-01 is only partially satisfied: only 1 of the 3 planned service deduplication deletions was performed.

**Root cause of gaps:** The executor ran pre-deletion grep checks for lib/ importers and found 0 results for the gamification/ and memory/ files. It then incorrectly concluded the files were "already absent" from the codebase. In reality, the files existed on disk with 0 lib/ importers — the executor confused "no importers" with "file not present." The commit message reinforced this error.

**Impact on next phases:** The two surviving duplicate files have 0 lib/ importers and flutter analyze is clean, so they pose no immediate runtime risk. However, they leave the codebase with two non-canonical service paths that test files depend on, which contradicts the phase goal of "import-clean" and Roadmap SC-1.

**Fix scope:** Small — 2 file deletions + 2 test file updates (either update import paths or remove test files for the re-export shim). Estimated effort: < 15 minutes.

---

_Verified: 2026-04-05T16:00:00Z_
_Verifier: Claude (gsd-verifier)_
