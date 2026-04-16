---
phase: 03-chat-as-shell-rebuild
plan: 02
subsystem: coach-chat
tags: [consent, data-capture, tone, voice-preference]
dependency_graph:
  requires: [ChatDrawerHost]
  provides: [ChatConsentChip, ChatDataCaptureHandler, tone-preference-flow]
  affects: [coach_chat_screen, consent_manager, coach_profile_provider]
tech_stack:
  added: []
  patterns: [inline-consent-chips, data-capture-parser, tone-preference-once]
key_files:
  created:
    - apps/mobile/lib/widgets/coach/chat_consent_chip.dart
    - apps/mobile/lib/widgets/coach/chat_data_capture.dart
    - apps/mobile/test/screens/coach/chat_inline_consent_test.dart
    - apps/mobile/test/screens/coach/chat_data_capture_test.dart
    - apps/mobile/test/screens/coach/chat_tone_preference_test.dart
  modified:
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart
decisions:
  - "Consent sentences hardcoded in French (not ARB) for Phase 3 — Phase 4 i18n hygiene extracts"
  - "ChatDataCaptureHandler is pure utility (no widget, no state) — parsing only"
  - "Tone preference replaces 4-level intensity with 3 VoicePreference values"
  - "Tone chips shown below silent opener, not after first message (simpler UX)"
metrics:
  duration: ~20min
  completed: "2026-04-09"
  tasks: 3
  tests_added: 33
---

# Phase 3 Plan 02: Consent + Data Capture + Tone Summary

Inline consent chips, profile data capture parser, and tone preference flow — all operating through the chat conversation, not standalone screens.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 3 | CHAT-03: Inline consent | 08f5e68b | chat_consent_chip.dart, chat_inline_consent_test.dart |
| 4 | CHAT-04: Data capture | a2994a73 | chat_data_capture.dart, chat_data_capture_test.dart |
| 5 | CHAT-05: Tone preference | 904e1909 | coach_chat_screen.dart, chat_tone_preference_test.dart |

## Key Changes

### CHAT-03: Inline consent via chips
- `ChatConsentChip` renders human sentence + accept/decline chips for any ConsentType
- 7 distinct French sentences (one per ConsentType) — warm, zero-jargon, no nLPD references
- Accept/decline chips equally prominent (T-03-05: no dark pattern)
- Wired to existing `ConsentManager` for persistence via SharedPreferences

### CHAT-04: Profile data capture via chat
- `ChatDataCaptureHandler` — pure utility with `parseAge`, `parseCanton`, `parseSalary`
- T-03-04: age validated 16-120, salary >= 0, canton against Swiss canton list
- `missingFields()` respects pre-fill rule — only asks for unknown data
- French question and gentle re-ask messages for invalid input
- Canton matching: abbreviation, full name, accent-insensitive, partial match

### CHAT-05: Tone preference via suggestion chips
- Replaced 4-level intensity chips (Tranquille/Clair/Direct/Cash) with 3 VoicePreference chips
- "Doux" -> VoicePreference.soft (cashLevel=1)
- "Direct" -> VoicePreference.direct (cashLevel=3)
- "Sans filtre" -> VoicePreference.unfiltered (cashLevel=5)
- Chips shown below silent opener on first conversation, hidden when preference set
- Stored via `CoachProfileProvider.setVoiceCursorPreference`
- Confirmation message adapts to chosen tone

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing functionality] Tone chips not visible during silent opener**
- **Found during:** Task 5 (test failure)
- **Issue:** Tone chips were only rendered inside message list, but silent opener replaces the message list
- **Fix:** Added `_buildSilentOpenerWithTone()` wrapper that shows chips below the opener
- **Files modified:** coach_chat_screen.dart
- **Commit:** 904e1909

## Known Stubs

- Consent chip sentences are hardcoded French strings (not in ARB files) — Phase 4 i18n hygiene will extract
- Tone preference question text is hardcoded French — same Phase 4 extraction
- `ChatDataCaptureHandler` is not yet wired into the chat message flow (parser ready, integration in Phase 4)
- `ChatConsentChip` is not yet triggered automatically by BYOK flow (widget ready, wiring in Phase 4)
- `ChatDrawerHost.resolveDrawerWidget` returns Container placeholders, not actual screen widgets

## Decisions Made

1. Consent sentences hardcoded for Phase 3 speed — i18n extraction deferred to Phase 4
2. Data capture handler is pure utility — no widget/state, just parsing functions
3. Replaced 4-level intensity system with 3 VoicePreference values for simplicity
4. Tone chips positioned below silent opener (not after first message exchange)
