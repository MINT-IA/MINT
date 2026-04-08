---
phase: 03-memoire-narrative
plan: 02
subsystem: ai-coaching
tags: [anonymization, privacy, coach-prompt, biography, freshness-decay]

# Dependency graph
requires:
  - phase: 03-01
    provides: BiographyFact model, BiographyRepository, FreshnessDecayService
provides:
  - AnonymizedBiographySummary with whitelist anonymization for LLM prompts
  - BiographyRefreshDetector for stale fact nudges
  - ContextInjectorService biography block integration
  - Backend coach BIOGRAPHY AWARENESS prompt rules
affects: [03-03-PLAN, coach-quality, privacy-screen]

# Tech tracking
tech-stack:
  added: []
  patterns: [whitelist-anonymization, graceful-degradation-biography, stale-marker-pattern]

key-files:
  created:
    - apps/mobile/lib/services/biography/anonymized_biography_service.dart
    - apps/mobile/lib/services/biography/biography_refresh_detector.dart
    - apps/mobile/test/services/biography/anonymized_biography_test.dart
    - apps/mobile/test/services/biography/biography_refresh_detector_test.dart
    - services/backend/tests/test_biography_coach_guardrails.py
  modified:
    - apps/mobile/lib/services/coach/context_injector_service.dart
    - services/backend/app/services/coach/claude_coach_service.py

key-decisions:
  - "Whitelist anonymization: every FactType has explicit rounding rule; unknown types return [donnee confidentielle]"
  - "Biography block positioned after budgetBlock and before checkInBlock in memory hierarchy"
  - "Backend BIOGRAPHY AWARENESS injected after anti-patterns, before language instruction"

patterns-established:
  - "Whitelist anonymization: explicit rule per type, default to redaction for unknown types (T-03-04)"
  - "Stale marker pattern: [DONNEE ANCIENNE] for aging data, coach instructed to mention age explicitly"
  - "Graceful degradation: try/catch around biography loading, coach works without biography context"

requirements-completed: [BIO-03, BIO-04, BIO-07, BIO-08, COMP-02, COMP-03]

# Metrics
duration: 6min
completed: 2026-04-06
---

# Phase 03 Plan 02: Anonymization Pipeline + Coach Integration Summary

**Whitelist anonymization pipeline (salary->5k, LPP/3a->10k) with coach BIOGRAPHY AWARENESS rules enforcing conditional language, source dating, and max 1 biography reference per response**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-06T15:11:41Z
- **Completed:** 2026-04-06T15:17:51Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments
- AnonymizedBiographySummary with whitelist approach: salary rounds to 5k, LPP/3a to 10k, mortgage to 50k, unknown types redacted as [donnee confidentielle]
- BiographyRefreshDetector identifies stale facts (freshness < 0.60) and generates French nudge text for coach injection
- ContextInjectorService wired to load biography from repository, anonymize, and inject into memory block with graceful degradation
- Backend coach system prompt includes BIOGRAPHY AWARENESS section with 11 rules (conditional language, source dating, max 1 ref, stale handling, privacy constraints)
- 42 total new tests (25 anonymization + 7 refresh detector + 10 backend guardrails)

## Task Commits

Each task was committed atomically:

1. **Task 1: AnonymizedBiographySummary + BiographyRefreshDetector** - `58a9719f` (feat)
2. **Task 2: ContextInjectorService integration + backend coach prompt** - `6e318c46` (feat)

_Task 1 followed TDD pattern: tests and implementation developed together, all passing._

## Files Created/Modified
- `apps/mobile/lib/services/biography/anonymized_biography_service.dart` - Privacy-safe biography summary builder with whitelist anonymization, 8000 char cap, stale markers
- `apps/mobile/lib/services/biography/biography_refresh_detector.dart` - Stale fact detection and French nudge text generation
- `apps/mobile/lib/services/coach/context_injector_service.dart` - Added biography block loading, anonymization, and injection into _buildMemoryBlock
- `services/backend/app/services/coach/claude_coach_service.py` - Added _BIOGRAPHY_AWARENESS constant and injection into system prompt
- `apps/mobile/test/services/biography/anonymized_biography_test.dart` - 25 tests: all rounding rules, filtering, format, truncation, edge cases
- `apps/mobile/test/services/biography/biography_refresh_detector_test.dart` - 7 tests: stale detection, sorting, nudge generation, limits
- `services/backend/tests/test_biography_coach_guardrails.py` - 10 tests: all required rules present in constant and assembled prompt

## Decisions Made
- **Whitelist anonymization**: Every FactType has an explicit rounding/redaction rule. Default returns "[donnee confidentielle]" for any unhandled type (T-03-04 mitigation).
- **Biography block position**: Placed after budgetBlock and before checkInBlock in memory hierarchy, so Claude sees financial context before enrichment prompts.
- **Backend injection point**: BIOGRAPHY AWARENESS added after anti-patterns, before language instruction, so it applies regardless of language setting.

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- Test for stale field sorting initially used a fact only 500 days old (~16 months), which was still fresh for annual tier. Fixed by using 800 days (~26 months) to properly cross the 0.60 threshold.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- AnonymizedBiographySummary and BiographyRefreshDetector ready for privacy screen (03-03)
- Coach now references user's financial story naturally via anonymized biography
- Full pipeline: BiographyFact -> BiographyRepository -> AnonymizedBiographySummary -> ContextInjectorService -> Coach prompt

## Self-Check: PASSED

- All 5 created files exist on disk
- Both commit hashes verified in git log (58a9719f, 6e318c46)
- 65 Flutter biography tests pass, 10 backend guardrail tests pass
- flutter analyze 0 issues

---
*Phase: 03-memoire-narrative*
*Completed: 2026-04-06*
