---
phase: 01-le-parcours-parfait
plan: 03
subsystem: ui
tags: [flutter, onboarding, gorouter, cupertino-picker, coach, 4-layer-engine, i18n, fastapi]

# Dependency graph
requires:
  - phase: 01-le-parcours-parfait/01-01
    provides: MintLoadingState, MintErrorState, i18n keys
  - phase: 01-le-parcours-parfait/01-02
    provides: Post-auth routing to /onboarding/intent
provides:
  - Rewired 4-screen onboarding pipeline (intent -> quick-start -> chiffre-choc -> plan -> coach)
  - PlanScreen with firstJob financial steps and coach entry payload
  - Modern inputs on quick_start (CupertinoPicker for age, tap-to-type for salary, dropdown for canton)
  - 4-layer insight engine in backend coach system prompt
  - firstJob-specific context injection in backend coach
  - Canton-based regional voice injection in coach prompt
  - 12 backend tests for coach firstJob prompt
  - 11 new i18n keys in 6 languages
affects: [01-04, 01-05]

# Tech tracking
tech-stack:
  added: []
  patterns: [onboarding-pipeline-linear-flow, 4-layer-insight-engine, intent-based-context-injection]

key-files:
  created:
    - apps/mobile/lib/screens/onboarding/plan_screen.dart
    - services/backend/tests/test_coach_firstjob.py
  modified:
    - apps/mobile/lib/screens/onboarding/intent_screen.dart
    - apps/mobile/lib/screens/onboarding/quick_start_screen.dart
    - apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart
    - apps/mobile/lib/app.dart
    - services/backend/app/services/coach/claude_coach_service.py
    - services/backend/app/services/coach/coach_models.py
    - apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb

key-decisions:
  - "Onboarding completion flag (setMiniOnboardingCompleted) moved from intent_screen to plan_screen (end of pipeline)"
  - "intent_screen preserves legacy behavior for non-onboarding contexts via fromOnboarding flag"
  - "Salary input changed from MintPremiumSlider to tap-to-type TextField (per CLAUDE.md modern inputs rule)"
  - "4-layer engine always included in system prompt (not conditional on intent)"
  - "firstJob context injected only for firstJob/premierEmploi intents"
  - "Regional voice injected via COULEUR REGIONALE section based on canton resolution"

patterns-established:
  - "Pipeline navigation pattern: each screen passes data forward via GoRouter extra map"
  - "Intent-based context injection: CoachContext.intent drives system prompt customization"
  - "fromOnboarding flag pattern: backward-compatible routing based on entry context"

requirements-completed: [PATH-01, PATH-03, PATH-04]

# Metrics
duration: 13min
completed: 2026-04-06
---

# Phase 01 Plan 03: Onboarding Pipeline Wiring Summary

**4-screen onboarding pipeline (intent -> quick-start -> chiffre-choc -> plan -> coach) with modern inputs, 4-layer insight engine in backend coach prompt, and 12 firstJob backend tests**

## Performance

- **Duration:** 13 min
- **Started:** 2026-04-06T12:11:33Z
- **Completed:** 2026-04-06T12:24:25Z
- **Tasks:** 2
- **Files modified:** 22

## Accomplishments
- Rewired intent_screen to route to /onboarding/quick-start (golden path) instead of computing and going to /home
- Moved setMiniOnboardingCompleted from intent_screen to plan_screen (end of pipeline, per Research Pitfall 3)
- Replaced MintPremiumSlider with tap-to-type TextField for salary input in quick_start_screen
- Created plan_screen with 4 firstJob financial steps, MintLoadingState/MintErrorState, and CTA to coach
- Added 4-layer insight engine (FACTUAL/HUMAN/PERSONAL/QUESTIONS) to backend coach system prompt
- Added firstJob-specific context section and canton-based regional voice injection
- Created 12 backend tests covering 4-layer engine, firstJob context, and regional voice isolation
- Added 11 i18n keys to all 6 ARB files (plan steps, coach check-in welcome)
- flutter analyze 0 errors, all backend tests pass

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewire onboarding pipeline with modern inputs** - `55b4ebf6` (feat)
2. **Task 2: Plan screen + coach check-in + 4-layer engine + backend test** - `6b039ad7` (feat)

## Files Created/Modified
- `apps/mobile/lib/screens/onboarding/intent_screen.dart` - Rewired to /onboarding/quick-start, removed premature completion flag
- `apps/mobile/lib/screens/onboarding/quick_start_screen.dart` - Replaced slider with tap-to-type, navigates to /onboarding/chiffre-choc
- `apps/mobile/lib/screens/onboarding/chiffre_choc_screen.dart` - Added Continue CTA to /onboarding/plan
- `apps/mobile/lib/screens/onboarding/plan_screen.dart` - New: 4 firstJob plan steps, sets onboarding completion, navigates to coach
- `apps/mobile/lib/app.dart` - Added /onboarding/quick-start and /onboarding/plan routes
- `services/backend/app/services/coach/claude_coach_service.py` - 4-layer engine + firstJob context + regional voice
- `services/backend/app/services/coach/coach_models.py` - Added intent field to CoachContext
- `services/backend/tests/test_coach_firstjob.py` - 12 tests for firstJob coach prompt
- `apps/mobile/lib/l10n/app_{fr,en,de,es,it,pt}.arb` - 11 new i18n keys each

## Decisions Made
- Moved onboarding completion flag to plan_screen (end of pipeline) to prevent partial onboarding marking
- Preserved legacy intent_screen behavior for non-onboarding contexts via fromOnboarding flag
- 4-layer engine is always included in system prompt (benefits all intents, not just firstJob)
- firstJob context is conditional (only for firstJob/premierEmploi intents)
- Added intent field to CoachContext dataclass rather than extra function parameter

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed const lint warning on CoachEntryPayload**
- **Found during:** Task 2 (plan_screen verification)
- **Issue:** flutter analyze flagged prefer_const_constructors on CoachEntryPayload instantiation
- **Fix:** Changed `final` to `const` for the payload declaration
- **Files modified:** plan_screen.dart
- **Verification:** flutter analyze 0 issues
- **Committed in:** 6b039ad7 (Task 2 commit)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Minor lint fix, no scope change.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Known Stubs
None - all screens are functional with parameterized inputs. Plan steps are currently the same for all intents (firstJob-focused). Future plans may customize steps per intent.

## Next Phase Readiness
- Full onboarding pipeline ready for end-to-end testing (Plan 01-04/05)
- Coach system prompt includes 4-layer engine for all conversations
- Regional voice injection working for all Swiss cantons
- CoachContext.intent field available for future intent-based customizations

---
*Phase: 01-le-parcours-parfait*
*Completed: 2026-04-06*
