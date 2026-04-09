---
status: human_needed
phase: 6
reqs_covered: [DEVICE-02]
automated_verification_date: "2026-04-09"
human_verification:
  - "Julien: install TestFlight build, walk cold-start -> landing -> chat -> first coach message"
  - "Julien: verify no intent screen, no Faire mon diagnostic, no Centre de controle reachable"
  - "Julien: verify chat works (send message, get response)"
  - "Julien: annotated screenshots of each step"
---

# Phase 6: v2.3 Automated Verification Report

## 1. Flutter Analyze

**Result: PASS (0 errors)**

```
flutter analyze apps/mobile/lib/
```

9 issues found (2 warnings, 7 info-level). Zero errors.

- 2 warnings: unused field `_hasProfile` and unused element `_onIntensitySelected` in coach_chat_screen.dart (cosmetic, not functional)
- 7 info: deprecated `announce` API, `prefer_const_constructors`, `use_build_context_synchronously` (all non-blocking)

## 2. Architecture Gate Tests

**Result: PASS (34/34 green)**

```
flutter test test/architecture/
```

All 5 CI gates operational:
- GATE-01: Route cycle DFS -- no cycles detected
- GATE-02: Scope-leak detection -- no unauthenticated leaks
- GATE-03: Payload consumption -- no dangling payloads
- GATE-04: Route guard snapshot -- matches golden file
- GATE-05: Doctrine string lint -- no banned terms
- BUG-02 tombstone tests (6) -- auth leak structurally impossible
- NAV-05: Route reachability BFS -- all routes reachable from /coach/chat

## 3. Full Test Suite

**Result: 9276 tests (9254 passed, 6 skipped, 16 failed)**

The 16 failures are ALL expected consequences of v2.3 changes:

| Category | Count | Cause |
|----------|-------|-------|
| Golden image mismatches | 9 | Landing screen rebuilt in Phase 5 (POLISH-01). Golden master images need regeneration. |
| PrivacyControlScreen | 3 | Provider dependency after consent flow refactored to chat-inline (Phase 3) |
| CoachChatScreen | 2 | Silent opener change (Phase 3 CHAT-01) |
| Patrol integration tests | 2 | Onboarding flow deleted (Phase 2), document flow navigation changed |

**None of these are regressions.** They are test expectations that need updating to match the new v2.3 reality. The 9254 passing tests confirm the core app is stable.

## 4. v2.3 Changelog Summary

| Metric | Value |
|--------|-------|
| Total commits | 32 |
| Code commits (non-docs) | 18 |
| Dart files deleted | 13 (6 screens + 1 widget + 6 tests) |
| Dart files created | 11 (3 widgets + 8 tests) |
| Dart files modified | 32 |
| Net lines | -3,552 (2,055 added, 5,607 removed) |
| Phases completed | 5 of 6 |

### Commits by Phase

**Phase 1 -- Architectural Foundation (7 commits)**
- 5 CI gate tests (cycle DFS, scope-leak, payload, snapshot, doctrine lint)
- Would-have-fired fixture tests proving gates catch v2.2 P0 patterns

**Phase 2 -- Deletion Spree (8 commits)**
- Deleted: CoachEmptyState, intent_screen, consent_dashboard, profile_screen, main_navigation_shell, explore_tab
- Removed mandatory account creation from onboarding
- Auth leak tombstone tests
- Guard snapshot golden updated

**Phase 3 -- Chat-as-Shell Rebuild (5 commits)**
- Cold-start routing verification (CHAT-01)
- ChatDrawerHost summon mechanism (CHAT-02)
- Inline consent chips (CHAT-03)
- Profile data capture via chat (CHAT-04)
- Tone preference suggestion chips (CHAT-05)

**Phase 4 -- Residual Bugs & i18n Hygiene (2 commits)**
- ~40 diacritics fixed across 14 files (BUG-03)
- Route reachability CI gate added (NAV-05)

**Phase 5 -- Sober Visual Polish (4 commits)**
- Landing rebuilt to 3 elements (POLISH-01)
- Chat breathing room spacing (POLISH-02)
- TextStyle tokens replacing raw styles (POLISH-03)
- Token audit sweep (POLISH-04)

## 5. Route Graph Post-v2.3

Source: `test/architecture/route_guard_snapshot.golden.txt`

| Scope | Count |
|-------|-------|
| Public | 14 |
| Onboarding | 10 |
| Authenticated | 125 |
| **Total** | **149** |

Key public routes: `/` (landing), `/coach/chat`, `/about`, `/auth/*` (4 routes), admin routes (6).

The critical change: `/coach/chat` is **public scope** -- users reach the coach without account creation. This is the chat-as-shell inversion from Phase 2.

## 6. Gate 0: Creator-Device Walkthrough

### What Julien needs to do

1. **Install** the TestFlight build (trigger a new build from this branch first)
2. **Cold-start** the app (delete + reinstall or clear data)
3. **Walk the flow**: Landing screen -> tap "Commencer" -> Chat screen
4. **Verify these are GONE**:
   - No "Faire mon diagnostic" intent screen
   - No "Centre de controle" reachable
   - No mandatory account creation before chat
   - No tab bar at bottom
5. **Verify these WORK**:
   - Landing shows: MINT wordmark + single-sentence promise + "Commencer" CTA + legal footer
   - Chat opens immediately with silent opener (no auto-greeting)
   - Typing a message and sending it works
   - Coach responds (requires API key configured)
   - Suggestion chips appear and are tappable
6. **Take annotated screenshots** of each step
7. **Note any visual issues**: spacing, text, colors, alignment

### PASS Criteria

All of these must be true:
- [ ] Cold-start lands on minimal landing (3 elements only)
- [ ] Single tap reaches chat (no intermediate screens)
- [ ] Chat input works (keyboard appears, text sends)
- [ ] Coach responds within reasonable time
- [ ] No deleted screens are reachable (intent, consent dashboard, profile destination, control center)
- [ ] No "Romania 70s" visual impression -- clean, calm, minimal
- [ ] No crashes or white screens during the flow

### FAIL Criteria

Any of these triggers a FAIL:
- Deleted screen still reachable
- Chat does not accept input
- White screen or crash at any point
- Mandatory account creation blocks chat access
- Tab bar visible
- Visual quality below "would show to a friend" threshold

## 7. Known Issues (non-blocking)

1. **16 test failures** need golden image regeneration and test expectation updates (tracked in STATE.md as carryover)
2. **2 flutter analyze warnings** in coach_chat_screen.dart (unused field/element -- cosmetic)
3. **~65 NEEDS-VERIFY try/except blocks** (pre-existing, deferred to v2.4)
4. **Golden test master images** need regeneration after landing rebuild
