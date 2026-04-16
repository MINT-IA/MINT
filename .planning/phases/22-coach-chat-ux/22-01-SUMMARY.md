---
phase: 22-coach-chat-ux
plan: 01
subsystem: ui
tags: [flutter_markdown, coach-chat, ux, system-prompt, i18n]

# Dependency graph
requires:
  - phase: 20-coach-conversation-context
    provides: multi-turn conversation history for coach chat
provides:
  - Markdown rendering in coach message bubbles (bold, italic, lists, headers)
  - Keyboard dismiss on send + auto-scroll to bottom
  - Concise 3-5 sentence coach responses via system prompt directive
  - Collapsible disclaimer (collapsed by default, expandable on tap)
affects: [coach-chat, backend-prompts]

# Tech tracking
tech-stack:
  added: [flutter_markdown ^0.7.6]
  patterns: [MarkdownBody for LLM output rendering, StatefulWidget for collapsible sections]

key-files:
  created: []
  modified:
    - apps/mobile/pubspec.yaml
    - apps/mobile/lib/widgets/coach/coach_message_bubble.dart
    - apps/mobile/lib/screens/coach/coach_chat_screen.dart
    - services/backend/app/services/coach/claude_coach_service.py
    - apps/mobile/lib/l10n/app_fr.arb
    - apps/mobile/lib/l10n/app_en.arb
    - apps/mobile/lib/l10n/app_de.arb
    - apps/mobile/lib/l10n/app_es.arb
    - apps/mobile/lib/l10n/app_it.arb
    - apps/mobile/lib/l10n/app_pt.arb

key-decisions:
  - "MarkdownBody (non-scrollable) over Markdown (scrollable) to fit inside bubble Column without nested scroll conflicts"
  - "AnimatedCrossFade for disclaimer collapse with 200ms duration for smooth but fast transition"
  - "Response length directive placed ABOVE existing FORMAT section to establish length limit before style rules"

patterns-established:
  - "MarkdownBody for all LLM output rendering in coach chat"
  - "Collapsible sections via StatefulWidget + AnimatedCrossFade pattern"

requirements-completed: [UX-01, UX-02, UX-03, UX-05]

# Metrics
duration: 6min
completed: 2026-04-13
---

# Phase 22 Plan 01: Coach Chat UX Summary

**flutter_markdown rendering for coach messages, keyboard dismiss on send, 3-5 sentence system prompt cap, and collapsible disclaimer**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-13T17:53:37Z
- **Completed:** 2026-04-13T18:00:05Z
- **Tasks:** 2
- **Files modified:** 17 (including generated l10n files)

## Accomplishments
- Coach messages render bold, italic, lists, and headers as formatted text -- no visible asterisks or markdown syntax
- Keyboard dismisses immediately after send via _focusNode.unfocus(), chat auto-scrolls to new response
- System prompt enforces 3-5 sentence max with "Tu veux que je detaille ?" escape hatch for complex topics
- Disclaimer collapsed by default to single expandable line with i18n in all 6 languages

## Task Commits

Each task was committed atomically:

1. **Task 1: Markdown rendering + keyboard dismiss + collapsible disclaimer** - `72daaa56` (feat)
2. **Task 2: Response length directive in system prompt** - `f998686b` (feat)

## Files Created/Modified
- `apps/mobile/pubspec.yaml` - Added flutter_markdown ^0.7.6 dependency
- `apps/mobile/lib/widgets/coach/coach_message_bubble.dart` - MarkdownBody replaces Text widget, CoachDisclaimersSection refactored to StatefulWidget
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart` - _focusNode.unfocus() added to _sendMessage
- `services/backend/app/services/coach/claude_coach_service.py` - LONGUEUR DES REPONSES section added to system prompt
- `apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb` - coachDisclaimerCollapsed key added

## Decisions Made
- Used MarkdownBody (non-scrollable) instead of Markdown (scrollable) to avoid nested scroll conflicts inside the bubble Column
- AnimatedCrossFade with 200ms for disclaimer collapse -- fast enough to feel responsive, smooth enough to not be jarring
- Response length directive placed ABOVE FORMAT DES REPONSES to establish the length constraint before style rules

## Deviations from Plan

None -- plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Coach chat now renders markdown, dismisses keyboard, enforces concise responses, and shows unobtrusive disclaimers
- Ready for device verification (flutter run --release on iPhone)
- Pre-existing warnings in coach_chat_screen.dart (duplicate import, unused fields) are out of scope

---
*Phase: 22-coach-chat-ux*
*Completed: 2026-04-13*
