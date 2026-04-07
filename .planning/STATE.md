---
gsd_state_version: 1.0
milestone: v2.1
milestone_name: Stabilisation v2.0
status: defining_requirements
stopped_at: ""
last_updated: "2026-04-07T00:00:00.000Z"
last_activity: 2026-04-07
progress:
  total_phases: 0
  completed_phases: 0
  total_plans: 0
  completed_plans: 0
  percent: 0
---

# GSD State

## Project Reference

See: .planning/PROJECT.md (updated 2026-04-07)

**Core value:** User opens MINT and within 3 minutes receives a personalized, surprising insight -- then knows exactly what to do next.
**Current focus:** v2.1 Stabilisation — defining requirements

## Current Position

Phase: Not started (defining requirements)
Plan: —
Status: Defining requirements
Last activity: 2026-04-07 — Milestone v2.1 started

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 24
- Average duration: --
- Total execution time: --

*Updated after each plan completion*

## Accumulated Context

### Decisions

- Roadmap: 6 phases derived from 7 requirement categories; strict data dependency chain (docs -> bio -> anticipation -> cards)
- bLink/Connexions Externes deferred to v3.0 (out of scope for v2.0)
- COMP requirements distributed across phases where they naturally apply (COMP-04 in Phase 2, COMP-02/03 in Phase 3, COMP-01/05 in Phase 6)
- Phase ordering follows ProfileEnrichmentDiff data dependency: document pipeline must establish the pattern first
- QA Profond is the release gate (Phase 6) -- no feature ships without 9-persona validation
- Research: document pipeline is 80% built, mostly wiring needed; FinancialBiography is net-new
- [Phase 01-le-parcours-parfait]: State widgets follow MintEmptyState API pattern (Center > Padding > Column) for consistency
- [Phase 01-le-parcours-parfait]: promise_screen simplified to single CTA (Commencer -> /login) per UI-SPEC Screen 1
- [Phase 01-le-parcours-parfait]: Magic link tokens stored as SHA-256 hash following PasswordResetTokenModel pattern
- [Phase 01-le-parcours-parfait]: Post-auth routing uses ReportPersistenceService.isMiniOnboardingCompleted (not hasCompletedOnboarding)
- [Phase 01-le-parcours-parfait]: Resend API for magic link email with graceful dev-mode fallback
- [Phase 01-le-parcours-parfait]: Onboarding completion flag moved from intent_screen to plan_screen (end of pipeline)
- [Phase 01-le-parcours-parfait]: 4-layer engine always included in coach prompt; firstJob context is conditional
- [Phase 01-le-parcours-parfait]: CoachContext.intent field added for intent-based system prompt customization
- [Phase 01-le-parcours-parfait]: Apple identity token MVP verification (issuer+expiry); production requires Apple JWKS validation
- [Phase 01-le-parcours-parfait]: Auto-create user on Apple Sign-In verify (same frictionless pattern as magic link)
- [Phase 01-le-parcours-parfait]: Golden path persona test pattern: define constants, test each pipeline stage, verify flag lifecycle
- [Phase 02-intelligence-documentaire]: Fail-open classification: API errors return is_financial=True to avoid blocking users (T-02-05)
- [Phase 02-intelligence-documentaire]: SHA-256 user_id hashing in audit logs for nLPD privacy compliance
- [Phase 02-intelligence-documentaire]: Module-import pattern for classify_document enables clean test mocking
- [Phase 02]: 1e plans suppress tauxConversion from extraction prompt to prevent hallucinated conversion rates
- [Phase 02]: Missing source_text degrades to low confidence rather than rejecting (DOC-09 user-friendly)
- [Phase 02]: Default plan type on error: surobligatoire (safest middle ground)
- [Phase 02]: Per-field thresholds: salary >= 0.90, LPP capital >= 0.95 (replaces global 0.80)
- [Phase 02]: DocumentServiceException propagated for 422 to distinguish non-financial rejection from general errors
- [Phase 02]: generate_document_insight() in documents.py (colocation); fallback uses field summary; premier eclairage replaces chiffre choc on impact screen
- [Phase 03-memoire-narrative]: Abstract BiographyDatabase interface for testability without native sqflite in flutter test
- [Phase 03-memoire-narrative]: Freshness decay uses updatedAt (when MINT confirmed) not sourceDate (document date)
- [Phase 03-02]: Whitelist anonymization: every FactType has explicit rounding rule; unknown types return [donnee confidentielle]
- [Phase 03-02]: Biography block positioned after budgetBlock before checkInBlock in memory hierarchy
- [Phase 03-02]: Backend BIOGRAPHY AWARENESS injected after anti-patterns, before language instruction in coach prompt
- [Phase 03-memoire-narrative]: Post-frame callback for loadFacts() to avoid notifyListeners during build phase
- [Phase 03-memoire-narrative]: hardDeleteFact for privacy screen delete (nLPD: user explicitly wants MINT to forget)
- [Phase 03-04]: Lazy repository init in BiographyProvider avoids async constructor requirement for MultiProvider registration
- [Phase 03-04]: _SqfliteDatabase adapter bridges sqflite.Database to abstract BiographyDatabase interface
- [Phase 04-moteur-danticipation]: AnticipationEngine follows NudgeEngine pure-static pattern (private ctor, static evaluate, injectable DateTime)
- [Phase 04-moteur-danticipation]: Cantonal tax deadlines: 26 cantons, TI/NW/OW=April 30, others=March 31, fallback for unknown
- [Phase 04-moteur-danticipation]: Salary increase dual threshold: >5% OR >2000 CHF; userEdit source filtered (correction vs real)
- [Phase 04-moteur-danticipation]: validateAlert() skips layers 3-4 (hallucination/disclaimer): alerts are template-based, not LLM-generated
- [Phase 04-moteur-danticipation]: Priority formula: timeliness*0.5 + userRelevance*0.3 + confidence*0.2 with 90-day horizon and default confidence 0.8
- [Phase 04-moteur-danticipation]: Per-trigger dismiss cooldowns (30-365d) and snooze durations (7-30d) via SharedPreferences ISO8601 timestamps
- [Phase 04-moteur-danticipation]: ComplianceGuard.validateAlert() runs in provider before card widget receives signal (T-04-08 compliance gate)
- [Phase 04-moteur-danticipation]: Post-frame callback for evaluation trigger avoids notifyListeners during build (follows BiographyProvider pattern)
- [Phase 04-moteur-danticipation]: ARB key resolver pattern: explicit switch on signal.titleKey dispatches to correct S method with params
- [Phase 05]: Sealed class card hierarchy with 5 subtypes for exhaustive pattern matching; pure static detector pattern for all contextual services
- [Phase 05]: CoachOpenerService uses 5-priority fallback chain with ComplianceGuard validation; ContextualCardProvider evaluates after AnticipationProvider; MintHomeScreen uses sealed class switch dispatch for card widgets
- [Phase 06]: Sophie stress_patrimoine rawValue can be 0 at onboarding (no patrimoine data) -- expected behavior
- [Phase 06]: IT retirement term threshold 75% (valid alternate terms like vecchiaia)
- [Phase 06]: ARB JSON quality testing pattern: load ARB as JSON in Dart tests, validate terminology + coverage programmatically
- [Phase 06]: error/warning/info colors tested at large text 3.0:1 threshold (Apple system colors used as status accents)
- [Phase 06]: Financial key empty-value test uses trim().isEmpty (not length<3) since labels like TOI/DU/vs are intentionally short
- [Phase 06]: Font warmup pattern for animated golden widgets; integration_test over patrol for dependency safety
- [Phase 06-qa-profond]: Phase 6 test dirs added to existing screens shard (not new shard) to keep CI matrix balanced
- [Phase 06-qa-profond]: TolerantGoldenFileComparator uses Flutter SDK recommended pattern (compareLists + diffPercent <= tolerance)
- [Phase 06-qa-profond]: warning (#D97706) also failed 4.5:1 at 3.19:1 -- darkened to #B45309 (5.02:1) along with derivatives

### Pending Todos

None yet.

### Blockers/Concerns

- Phase 2 (Intelligence Documentaire): document_vision_service.py exists but has no registered FastAPI endpoint -- wiring is the first task
- Phase 2: LPP caisse template coverage estimated at 60% -- actual coverage depends on real user documents
- Phase 6 (QA): Patrol integration tests require iOS 17 + Android API 34 emulator setup in CI

## Session Continuity

Last session: 2026-04-06T20:57:01.596Z
Stopped at: Completed 06-06-PLAN.md
Resume file: None
