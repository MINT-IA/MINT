---
phase: 03-chat-as-shell-rebuild
plan: 01
subsystem: coach-chat
tags: [chat, drawer, cold-start, navigation]
dependency_graph:
  requires: []
  provides: [ChatDrawerHost, showChatDrawer, cold-start-opener]
  affects: [coach_chat_screen, lightning_menu]
tech_stack:
  added: []
  patterns: [bottom-sheet-as-drawer, route-to-widget-resolver]
key_files:
  created:
    - apps/mobile/lib/widgets/coach/chat_drawer_host.dart
    - apps/mobile/test/screens/coach/cold_start_chat_test.dart
    - apps/mobile/test/services/coach/chat_drawer_summon_test.dart
  modified:
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart
decisions:
  - "Drawer uses DraggableScrollableSheet (0.5-0.95 range) for natural dismiss gesture"
  - "Route resolver uses lazy Container placeholders keyed by screen name (Phase 5 wires actual screens)"
  - "Anonymous users get minimal profile on first message (data capture fills details later)"
metrics:
  duration: ~15min
  completed: "2026-04-09"
  tasks: 2
  tests_added: 13
---

# Phase 3 Plan 01: Cold-start + Drawer Summon Summary

ChatDrawerHost bottom-sheet mechanism replaces full-page navigation from tool calls; cold-start verified for anonymous and profiled users.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | CHAT-01: Cold-start routing | 532095e0 | coach_chat_screen.dart, cold_start_chat_test.dart |
| 2 | CHAT-02: ChatDrawerHost | 6c210442 | chat_drawer_host.dart, coach_chat_screen.dart, chat_drawer_summon_test.dart |

## Key Changes

### CHAT-01: Cold-start routing verified
- Landing CTA routes to `/coach/chat` (confirmed at landing_screen.dart:150)
- Fixed anonymous user path: `_showSilentOpener` now set to true for users without profile
- Anonymous users see `coachSilentOpenerQuestion` text (warm, inviting)
- Minimal profile created on first message so `_sendMessage` doesn't crash on null profile

### CHAT-02: ChatDrawerHost summon mechanism
- Created `showChatDrawer()` — modal bottom sheet with DraggableScrollableSheet
- `ChatDrawerHost.resolveDrawerWidget()` maps route strings to widgets via whitelist
- Rewired LightningMenu `onNavigate` from `context.push(route)` to `showChatDrawer()`
- Rewired `_handleActionTap` suggestion chips from `context.push(route)` to `showChatDrawer()`
- Unknown routes silently dropped (T-03-01 mitigation)

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Anonymous user crash on null profile**
- **Found during:** Task 1
- **Issue:** `_sendMessage` called `_buildCoachContext(_profile!)` which crashes for anonymous users
- **Fix:** Added guard that creates minimal profile via `mergeAnswers` on first message
- **Files modified:** coach_chat_screen.dart
- **Commit:** 532095e0

## Decisions Made

1. Drawer uses `DraggableScrollableSheet` with 0.5-0.95 range — standard Material pattern, dismissible by drag
2. Route resolver uses keyed `Container` placeholders — actual screen widgets will be wired in Phase 5
3. Anonymous users get a minimal placeholder profile (age 35, VD, salary 0) on first message to prevent crashes
