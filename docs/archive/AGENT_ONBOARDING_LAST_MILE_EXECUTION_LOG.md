# Agent Execution Log — Onboarding Last Mile

Date: 2026-02-21
Owner: Senior audit/execution
Scope: Onboarding UX coherence and transition clarity

## Step 1 — Remove legacy "cercles" wording and unstable auto-advance

### Why
- Users still see onboarding language that no longer matches product intent ("Cercle 1/3").
- Transition screen auto-advances after 2.6s, creating a rushed and confusing experience.
- Current target is a clear, coach-like step flow, not an abstract circle model.

### What changed
- `apps/mobile/lib/screens/advisor/advisor_wizard_screen_v2.dart`
  - Replaced section progress labels:
    - `Cercle 1/3` -> `Étape 2/4`
    - `Cercle 2/3` -> `Étape 3/4`
    - `Cercle 3/3` -> `Étape 4/4`
  - Disabled auto-advance on section transition by passing `autoAdvanceAfter: null`.

- `apps/mobile/lib/widgets/circle_transition_widget.dart`
  - `autoAdvanceAfter` is now nullable (`Duration?`).
  - Timer is only started when `autoAdvanceAfter != null`.
  - This allows explicit user-driven transition ("Continuer") and avoids forced jumps.

### UX impact
- Progress wording now reflects onboarding steps and is consistent with the mini-onboarding framing.
- Transition timing is user-controlled, reducing cognitive pressure and accidental progression.

### Audit notes
- This is a tactical correction, not a full replacement of circle semantics across the whole codebase.
- Remaining technical debt:
  - Class name `CircleTransitionWidget` is legacy naming and should be renamed in a later cleanup pass.
  - Hardcoded strings in this widget should be moved to i18n keys before multilingual rollout.

### Verification checklist (to run after each step)
- `flutter test test/screens/core_screens_smoke_test.dart`
- `flutter test test/screens/core_app_screens_smoke_test.dart`
- `flutter test test/services/wizard_service_test.dart`
- `flutter analyze`

### Verification results (executed)
- `flutter test test/screens/core_screens_smoke_test.dart` -> PASS
- `flutter test test/screens/core_app_screens_smoke_test.dart` -> PASS
- `flutter test test/services/wizard_service_test.dart` -> PASS
- `flutter analyze lib/screens/advisor/advisor_wizard_screen_v2.dart lib/widgets/circle_transition_widget.dart lib/screens/advisor/advisor_onboarding_screen.dart` -> 0 errors, info-level lints only

## Step 2 — Planned (next execution block)

Goal: remove residual ambiguity between mini-onboarding and full diagnostic.

Planned checks:
- Audit all CTA paths to onboarding/wizard from Dashboard, Plan 30 jours, Profil.
- Ensure every CTA opens the intended target with optional section context.
- Add deterministic regression tests for:
  - `/advisor/plan-30-days` -> "Compléter mon diagnostic" -> `/advisor/wizard`
  - Profile section tap -> `/advisor/wizard` with `extra.section`
- No route should land on a blank/grey scaffold.

## Step 2 — Executed

### Why
- The budget empty state CTA sent users to the generic wizard start, even though intent is budget completion.
- This increases cognitive load and contributes to "onboarding feels messy" feedback.

### What changed
- `apps/mobile/lib/screens/budget/budget_container_screen.dart`
  - Updated CTA navigation:
    - Before: `context.push('/advisor/wizard')`
    - After: `context.push('/advisor/wizard', extra: {'section': 'budget'})`

### UX impact
- Users coming from Budget now land directly in the relevant diagnostic section.
- Reduces route ambiguity and improves task continuity ("I clicked budget, I arrive in budget questions").

## Step 3 — P0 Trust Gate (budget data quality transparency)

### Why
- Users reported that budget numbers did not clearly indicate what is entered vs estimated.
- This creates trust issues and makes the coach feel "opaque".

### What changed
- `apps/mobile/lib/domain/budget/budget_inputs.dart`
  - Added quality metadata:
    - `isTaxEstimated`
    - `isHealthEstimated`
    - `isOtherFixedMissing`
  - Added derived helpers:
    - `hasEstimatedValues`
    - `hasMissingValues`
  - Flags are now set in both builders:
    - `fromMap(...)` (wizard/local answers)
    - `fromCoachProfile(...)` (profile-driven sync)
  - Metadata is persisted in `toMap()` and restored in `fromMap()` via:
    - `meta_tax_estimated`
    - `meta_health_estimated`
    - `meta_other_fixed_missing`

- `apps/mobile/lib/screens/budget/budget_screen.dart`
  - Added data-quality banner when values are estimated/missing.
  - Added per-row quality chips in breakdown:
    - `saisi`
    - `estimé`
    - `manquant`
  - Applied to taxes, LAMal, and other fixed costs.

### UX impact
- Budget screen now explicitly communicates confidence level of each critical line item.
- Reduces false precision and aligns with fintech transparency expectations.

### Verification results (executed)
- `flutter test test/screens/budget_screen_smoke_test.dart` -> PASS
- `flutter test test/screens/cta_navigation_regression_test.dart` -> PASS
- `flutter test test/domain/budget_service_test.dart` -> PASS
- `flutter analyze` (touched files) -> 0 errors, info-level lints only
- `flutter test test/screens` (full screens suite) -> PASS

## Step 4 — A-ha trust layer (Dashboard + Profile)

### Why
- Users need immediate trust cues on core screens, not only in Budget.
- "Coach feel" requires explicit differentiation between entered vs estimated data.

### What changed
- `apps/mobile/lib/screens/coach/coach_dashboard_screen.dart`
  - Added a new trust card in partial dashboard right below precision badge:
    - title: `Qualite des donnees`
    - explanation: how many data points are entered and that remaining fields are estimated
    - visual chips: `saisi`, `estime`, `a completer`

- `apps/mobile/lib/screens/profile_screen.dart`
  - Added a new relationship/trust card under precision:
    - title: `Ce que MINT sait de toi`
    - profile state summary (`Profil partiel/complet`)
    - precision, check-in count, estimated score
    - same 3 data-quality chips for consistency with dashboard

### UX impact
- Creates a clearer "A-ha" transparency moment when users open Dashboard/Profile.
- Reinforces confidence that MINT is explicit about data confidence, not pretending precision.

### Verification results (executed)
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter test test/screens/core_app_screens_smoke_test.dart` -> PASS
- `flutter test test/screens/cta_navigation_regression_test.dart` -> PASS
- `flutter analyze` (Dashboard/Profile/Budget touched files) -> 0 errors, info-level lints only

## Step 5 — "Coach soul" layer (A-ha emotional UX)

### Why
- The app needs a visible coaching voice, not only calculators and cards.
- We need a clear "living coach" feeling both after onboarding and in daily dashboard usage.

### What changed
- `apps/mobile/lib/screens/coach/coach_dashboard_screen.dart`
  - Added `Coach Pulse` card (partial + full dashboard states).
  - Uses `_narrative?.scoreSummary` when available (LLM/BYOK path).
  - Static fallback text based on score bands for non-BYOK mode.
  - Includes a small "personnalise" badge when LLM narrative is active.

- `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - Added `Ton coach MINT` block to completion sheet.
  - Shows immediate priorities (3 bullets) derived from stress/goal choices.
  - Creates a clearer transition from "questionnaire" to "coach relationship".

### UX impact
- Stronger first emotional hook at onboarding completion.
- Dashboard now feels like an active coach, even without BYOK.

### Verification results (executed)
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter test test/screens/core_screens_smoke_test.dart` -> PASS
- `flutter test test/screens/onboarding_steps_test.dart` -> PASS
- `flutter analyze` (touched files) -> 0 errors, info-level lints only

## Step 6 — Static scenario narration hardening + regression pass

### Why
- The new static scenario narration block introduced a Dart typing issue (`num` passed where `double` was expected).
- This blocked `coach_narrative_service_test.dart` and could break CI.

### What changed
- `apps/mobile/lib/services/coach_narrative_service.dart`
  - Fixed monthly retirement amount fallback to remain `double`:
    - Before fallback literal: `0`
    - After fallback literal: `0.0`
  - Ensures compatibility with `ForecasterService.formatChf(double)`.

### UX impact
- Restores deterministic rendering of the static T7 fallback narratives (Prudent/Base/Optimiste) when BYOK is disabled.
- Prevents silent disappearance/failure of scenario text in dashboard narrative flows.

### Verification results (executed)
- `flutter test test/services/coach_narrative_service_test.dart` -> PASS
- `flutter test test/screens/coach/coach_agir_test.dart` -> PASS
- `flutter test test/screens/onboarding_steps_test.dart` -> PASS
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter test test/screens/budget_screen_smoke_test.dart` -> PASS
- `flutter test test/screens/coach/navigation_shell_test.dart` -> PASS
- `flutter test test/screens/core_app_screens_smoke_test.dart` -> PASS
- `flutter analyze` (targeted touched files) -> 0 errors, info-level lints only

## Step 7 — Coach Soul wiring (dashboard/check-in/onboarding)

### Why
- Final UX gap: coaching narratives existed but some were not surfaced strongly enough in critical moments.
- Goal: strengthen “coach relationship” without architectural refactor.

### What changed
- `apps/mobile/lib/screens/coach/coach_dashboard_screen.dart`
  - Added visual milestone narrative chip (`_buildMilestoneNarrativeChip`) when `CoachNarrative.milestoneMessage` exists.
  - Added score summary strip below score gauge (narrative fallback for context).
  - Scenario narration badge now reflects source:
    - `Coach IA` when LLM narrative is active
    - `Coach` for static fallback

- `apps/mobile/lib/screens/coach/coach_checkin_screen.dart`
  - Added BYOK milestone enrichment flow before celebration sheet:
    - `_enrichMilestonesIfByok(...)`
    - `_sanitizeNarrative(...)` compliance cleanup
  - Uses `RagService` + `ByokProvider` when available.
  - Keeps graceful fallback to static milestone description if BYOK absent/fails.

- `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - Reinforced completion coach intro wording.
  - Priorities in completion sheet now shown as numbered action sequence (1..3) for clearer “first week plan”.

### UX impact
- Dashboard now feels more “alive” and connected to achievements.
- Check-in celebrations become personalized when BYOK is active.
- Onboarding completion better frames a concrete coaching sequence, not just form completion.

### Verification results (executed)
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter test test/screens/coach/coach_checkin_test.dart` -> PASS
- `flutter test test/screens/onboarding_steps_test.dart` -> PASS
- `flutter test test/services/coach_narrative_service_test.dart` -> PASS
- `flutter analyze` (targeted files) -> 0 errors, info-level lints only

## Step 8 — Next-level UX loop (Agir + Onboarding A/B + Check-in reason)

### What changed
- `apps/mobile/lib/screens/coach/coach_agir_screen.dart`
  - Added `Scenarios de retraite en bref` card (profile-based, no mock) with CTA to `/retirement/projection`.

- `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - Added completion-sheet A/B behavior:
    - challenge variant CTA copy differs (`Lancer ma semaine 1`)
    - challenge intro wording focuses on immediate action
  - Added metrics:
    - `completion_sheet_shown`
    - `completion_sheet_shown_<variant>`
    - `completion_action_wizard|plan30|dashboard`

- `apps/mobile/lib/screens/coach/coach_checkin_screen.dart`
  - Added explicit score-delta explanation (`_scoreDeltaReason`) in success card.
  - Improved impact wording when monthly delta is near zero (`Impact en cours de calcul`).
- Kept BYOK milestone narrative enrichment + static fallback.

## Step 9 — Couple onboarding integrity gate (single/couple data correctness)

### Why
- Step 3 allowed progression for couple/family without partner data, producing weak or misleading household projections.
- Partner drafts could remain persisted even after switching back to `single`, creating stale profile pollution.

### What changed
- `apps/mobile/lib/providers/onboarding_provider.dart`
  - Added derived guards:
    - `isHouseholdWithPartner`
    - `hasPartnerRequiredData`
  - Hardened `canAdvanceFromStep3`:
    - `single`: income + employment + household
    - `couple/family`: requires civil status + partner income + partner birth year + partner employment status
  - `setHouseholdType('single')` now clears partner/civil fields and drafts.
  - `buildAnswersSnapshot()` now persists partner fields only for partner households.

- `apps/mobile/lib/screens/advisor/onboarding/onboarding_step_income.dart`
  - Continue button now uses `provider.canAdvanceFromStep3` (single source of truth).
  - Added explicit info card when partner data is incomplete.

- `apps/mobile/test/providers/onboarding_provider_test.dart`
  - Added test: couple requires partner data before step 3 can continue.
  - Added test: switching to single clears partner fields from snapshot.

### UX impact
- Household projections become materially more reliable for couple personas.
- Reduces false confidence by blocking progression until critical partner context is captured.
- Eliminates stale partner data leaks when user changes household mode.

### Verification results (executed)
- `flutter analyze lib/providers/onboarding_provider.dart lib/screens/advisor/onboarding/onboarding_step_income.dart test/providers/onboarding_provider_test.dart` -> PASS (0 issues)
- `flutter test test/providers/onboarding_provider_test.dart` -> PASS
- `flutter test test/screens/onboarding_steps_test.dart` -> PASS

## Step 10 — Persona coverage upgrade (single parent + i18n completion)

### Why
- Household modeling still missed a core Swiss persona: single parent.
- Some onboarding fields for partner/civil status were hardcoded in French.

### What changed
- `apps/mobile/lib/providers/onboarding_provider.dart`
  - Added `single_parent` support in household inference and mapping:
    - fallback hydration maps `single + children > 0` to `single_parent`
    - `civilStatusForHousehold(single_parent) = single`
    - `childrenCountForHousehold(single_parent) = 1`
    - `adultCountForHousehold(single_parent) = 1`
  - Switching to `single_parent` now clears irrelevant partner fields (same safety as `single`).

- `apps/mobile/lib/screens/advisor/onboarding/onboarding_step_income.dart`
  - Added fourth household card: `single_parent`.
  - Localized partner/civil-status labels and “partner required” guidance.

- `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - Coach intro priorities now include household persona:
    - couple/family -> household alignment priority
    - single parent -> protection + emergency buffer priority
  - Replaced hardcoded intro title/body with i18n keys.

- ARB locale files updated:
  - `apps/mobile/lib/l10n/app_fr.arb`
  - `apps/mobile/lib/l10n/app_en.arb`
  - `apps/mobile/lib/l10n/app_de.arb`
  - `apps/mobile/lib/l10n/app_es.arb`
  - `apps/mobile/lib/l10n/app_it.arb`
  - `apps/mobile/lib/l10n/app_pt.arb`
  - Added keys for:
    - single parent household label/description
    - partner/civil-status onboarding fields
    - coach intro title and persona-aware priorities

- `apps/mobile/test/providers/onboarding_provider_test.dart`
  - Added assertion for `single_parent` mapping (`single` civil status + 1 child).

### UX impact
- Onboarding now covers single, couple, family and single-parent personas with coherent data requirements.
- Messaging is less generic and more “coach-like” by household context.
- i18n structure remains ready for multilingual rollout (no new hardcoded FR-only copy in the flow).

## Step 11 — Smart enrichment guidance (Dashboard + Agir)

### Why
- Partial-profile UX still pushed generic CTA (“compléter mon diagnostic”) without explaining what to complete next.
- “Coach feel” requires contextual next-step guidance per persona.

### What changed
- `apps/mobile/lib/providers/coach_profile_provider.dart`
  - Added dynamic guidance signals from last wizard answers:
    - `personaKey` (`single`, `couple`, `family`, `single_parent`)
    - `onboardingQualityScore`
    - `onboardingAnsweredSignals` / `onboardingTotalSignals`
    - `recommendedWizardSection` (`identity`, `income`, `pension`, `property`)
  - Persisted `_lastAnswers` context on load/update to compute signal quality from real answered keys.
  - Kept legacy `profileCompleteness` unchanged for backward compatibility.

- `apps/mobile/lib/screens/coach/coach_dashboard_screen.dart`
  - Added persona guidance card in partial dashboard:
    - persona-aware title
    - quality score %
    - next section recommendation
  - Replaced static enrich CTA copy with dynamic section-specific guidance.
  - Wizard navigation now opens recommended section via `extra: {'section': ...}`.

- `apps/mobile/lib/screens/coach/coach_agir_screen.dart`
  - Added dedicated partial-profile state (instead of showing full Agir workflow too early):
    - “Plan en construction” with quality %
    - section-specific completion CTA
    - direct route to wizard section

- Tests
  - `apps/mobile/test/screens/cta_navigation_regression_test.dart`
    - Added assertions for dynamic quality score + section recommendation.
  - `apps/mobile/test/screens/coach/coach_agir_test.dart`
    - Added partial-profile rendering test for Agir guidance state.

### Verification results (executed)
- `flutter test test/screens/cta_navigation_regression_test.dart test/screens/coach/coach_agir_test.dart` -> PASS
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter analyze` (targeted files) -> 0 errors, info-level lints only

## Step 12 — Profile guidance + live debug quality (real-time)

### Why
- Profile still showed useful cards but lacked a direct “next best section” CTA.
- Debug panel needed a true live onboarding quality view based on current step data, not only persisted profile state.

### What changed
- `apps/mobile/lib/screens/profile_screen.dart`
  - Added `Section recommandee` guidance card:
    - shows onboarding quality score
    - shows section label from `recommendedWizardSection`
    - CTA opens wizard directly on recommended section.

- `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - Added live quality card to metrics panel using current `OnboardingProvider` state:
    - current step
    - live quality score
    - recommended next section from mini-onboarding progression
  - Added internal helpers:
    - `_computeLiveMiniQualityScore(...)`
    - `_recommendedSectionFromMini(...)`

### UX impact
- Profile now acts as a coach navigator, not only a status sheet.
- Internal metrics/debug now reflects real-time onboarding quality while user is still in the flow.

## Step 13 — i18n hardening for new coach guidance strings

### Why
- New persona guidance texts introduced FR hardcoded copy in Dashboard/Agir/Profile.
- Needed to preserve multilingual readiness.

### What changed
- Added localization keys (FR/EN/DE/ES/IT/PT) for:
  - Profile guidance title/body/cta
  - Onboarding metrics live labels
  - Persona priority labels
  - Wizard section labels (coach guidance context)
  - Persona-specific guidance body
  - Dynamic enrich banner title/body/action
  - Agir partial-profile title/body/action

- Updated screens to consume i18n keys:
  - `apps/mobile/lib/screens/coach/coach_dashboard_screen.dart`
  - `apps/mobile/lib/screens/coach/coach_agir_screen.dart`
  - `apps/mobile/lib/screens/profile_screen.dart`

### Verification results (executed)
- Locale parity script (FR as source):
  - `app_de.arb missing 0`
  - `app_en.arb missing 0`
  - `app_es.arb missing 0`
  - `app_it.arb missing 0`
  - `app_pt.arb missing 0`
- `flutter gen-l10n` -> PASS
- `flutter test test/screens/cta_navigation_regression_test.dart` -> PASS
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter test test/screens/coach/coach_agir_test.dart` -> PASS
- `flutter analyze` (targeted files) -> 0 errors, info-level lints only

## Step 9 — Shared narrative mode + cross-screen score attribution

### Why
- Dashboard/Agir needed the same narrative density control (`Court` vs `Détail`) to avoid cognitive overload.
- Score explanation from Check-in had to persist and remain visible after navigation.
- Onboarding debug panel needed an immediate A/B winner readout for operational steering.

### What changed
- `apps/mobile/lib/services/report_persistence_service.dart`
  - Added coach UX persistence:
    - `saveCoachNarrativeMode()` / `loadCoachNarrativeMode()`
    - `saveLastScoreAttribution()` / `loadLastScoreAttribution()`
  - Cleans these keys on `clearCoachHistory()` and `clearDiagnostic()`.

- `apps/mobile/lib/services/coach_narrative_service.dart`
  - Added shared rendering mode:
    - `enum CoachNarrativeMode { concise, detailed }`
    - `applyDetailMode(text, mode)` helper for concise vs detailed display.

- `apps/mobile/lib/screens/coach/coach_checkin_screen.dart`
  - Persists score attribution reason + delta at submit:
    - `ReportPersistenceService.saveLastScoreAttribution(...)`

- `apps/mobile/lib/screens/coach/coach_dashboard_screen.dart`
  - Loads persisted coach UX prefs (mode + score attribution reason).
  - Added `SegmentedButton` toggle (`Court` / `Détail`), persisted globally.
  - Applies mode to:
    - Coach Pulse text
    - Score summary strip
    - Scenario narrations
    - Score attribution explanation text

- `apps/mobile/lib/screens/coach/coach_agir_screen.dart`
  - Loads shared coach UX prefs.
  - Added same `Court` / `Détail` segmented control.
  - Applies mode to pulse “Pourquoi maintenant” + scenario brief text.
  - Surfaces persisted score attribution reason inside Coach Pulse card.

- `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - Debug metrics panel now shows live A/B winner + uplift points when sample size is comparable.

### Verification results (executed)
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter test test/screens/coach/coach_agir_test.dart` -> PASS
- `flutter test test/screens/coach/coach_checkin_test.dart` -> PASS
- `flutter test test/screens/onboarding_steps_test.dart` -> PASS
- `flutter analyze` (targeted files) -> 0 errors, info-level lints only

## Step 10 — i18n hardening + debug A/B labels

### Why
- New coach controls (`Court/Detail`) and debug winner labels must not stay hardcoded.
- We need clean keys for multi-language rollout and agent traceability.

### What changed
- Added locale keys in:
  - `apps/mobile/lib/l10n/app_fr.arb`
  - `apps/mobile/lib/l10n/app_en.arb`
  - `apps/mobile/lib/l10n/app_de.arb`
  - `apps/mobile/lib/l10n/app_es.arb`
  - `apps/mobile/lib/l10n/app_it.arb`
  - `apps/mobile/lib/l10n/app_pt.arb`
- New keys:
  - `coachNarrativeModeConcise`
  - `coachNarrativeModeDetailed`
  - `advisorMiniMetricsWinnerLive`
  - `advisorMiniMetricsUplift`
  - `advisorMiniMetricsSignal`
  - `advisorMiniMetricsSignalInsufficient`
- Wired these keys in:
  - `apps/mobile/lib/screens/coach/coach_dashboard_screen.dart`
  - `apps/mobile/lib/screens/coach/coach_agir_screen.dart`
  - `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`

## Step 11 — Wizard UX cleanup: remove full-screen "circle" transition

### Why
- Full-screen section transition was still perceived as noisy/legacy in onboarding.
- Goal: keep users in one continuous diagnostic flow.

### What changed
- `apps/mobile/lib/screens/advisor/advisor_wizard_screen_v2.dart`
  - Removed dependency on `CircleTransitionWidget`.
  - Replaced route push transition with inline section change + short snackbar:
    - format: `Étape X/4 • {section}`
  - Keeps section-awareness while removing disruptive interstitial screen.

### Verification results (executed)
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter test test/screens/coach/coach_agir_test.dart` -> PASS
- `flutter test test/screens/coach/coach_checkin_test.dart` -> PASS
- `flutter test test/screens/onboarding_steps_test.dart` -> PASS
- `flutter test test/services/report_persistence_service_test.dart` -> PASS
- `flutter test test/screens/advisor_banking_smoke_test.dart --plain-name "AdvisorWizardScreenV2"` -> PASS
- `flutter test test/screens/cta_navigation_regression_test.dart` -> PASS

## Step 12 — Profile monthly coach summary + cross-screen persistence E2E

### Why
- Profile still lacked a clear monthly coaching narrative despite score/check-in history.
- We needed explicit validation that score-attribution context survives app restart and tab changes.

### What changed
- `apps/mobile/lib/screens/profile_screen.dart`
  - Added `Resume coach du mois` card under the coach-knowledge block.
  - Computes:
    - monthly trend (up/down/flat/insufficient history)
    - next best action (complete diagnostic / do check-in / execute Agir action)
  - Uses real profile/check-in/score-history state from `CoachProfileProvider`.

- `apps/mobile/test/screens/coach/coach_cross_screen_persistence_test.dart` (new)
  - E2E-style widget test:
    - seed SharedPreferences with concise mode + score reason
    - render Dashboard, assert concise reason visible
    - simulate restart, render Agir, assert same concise reason visible

- `apps/mobile/test/screens/cta_navigation_regression_test.dart`
  - Added regression test for Profile monthly summary card rendering.

### i18n additions
- Added monthly summary keys to all locales (`fr/en/de/es/it/pt`):
  - `profileCoachMonthlyTitle`
  - `profileCoachMonthlyTrendInsufficient`
  - `profileCoachMonthlyTrendUp`
  - `profileCoachMonthlyTrendDown`
  - `profileCoachMonthlyTrendFlat`
  - `profileCoachMonthlyActionComplete`
  - `profileCoachMonthlyActionCheckin`
  - `profileCoachMonthlyActionAgir`

### Verification results (executed)
- `flutter test test/screens/coach/coach_cross_screen_persistence_test.dart` -> PASS
- `flutter test test/screens/cta_navigation_regression_test.dart` -> PASS
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter test test/screens/coach/coach_agir_test.dart` -> PASS

## Step 13 — i18n debt closure (25 missing keys) + warning cleanup

### Why
- Flutter warned `25 untranslated message(s)` for `de/en/es/it/pt`.
- This blocked clean localization validation and masked real i18n regressions.

### What changed
- Added the 25 missing keys to all non-FR locales:
  - auth reset/verify flow keys
  - admin observability export keys
  - common utility keys (`commonRetry`, `commonDays`)
- Updated files:
  - `apps/mobile/lib/l10n/app_en.arb`
  - `apps/mobile/lib/l10n/app_de.arb`
  - `apps/mobile/lib/l10n/app_es.arb`
  - `apps/mobile/lib/l10n/app_it.arb`
  - `apps/mobile/lib/l10n/app_pt.arb`

### Verification results (executed)
- Scripted parity check vs template (`app_fr.arb`):
  - `app_de.arb 0 missing`
  - `app_en.arb 0 missing`
  - `app_es.arb 0 missing`
  - `app_it.arb 0 missing`
  - `app_pt.arb 0 missing`
- `flutter test` no longer emits the previous 25-untranslated warning block.

### Verification results (executed)
- `flutter test test/screens/coach/coach_agir_test.dart` -> PASS
- `flutter test test/screens/coach/coach_checkin_test.dart` -> PASS
- `flutter test test/screens/onboarding_steps_test.dart` -> PASS
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS

## Step 11 — Sprint 1 close-out (clarity + CTA confidence)

### What changed
- `apps/mobile/lib/screens/coach/coach_dashboard_screen.dart`
  - Localized key labels for:
    - Data quality card
    - Chiffre-choc section
    - Scenario narration header and coach badge
    - Coach Pulse title

- `apps/mobile/lib/screens/coach/coach_agir_screen.dart`
  - Localized action roadmap section header/subtitle.
  - Keeps T7 scenario brief + Coach Pulse with i18n-first copy.

- `apps/mobile/lib/screens/profile_screen.dart`
  - Localized journey card title, profile state labels, chips and summary line.

- `apps/mobile/lib/l10n/app_fr.arb`
- `apps/mobile/lib/l10n/app_en.arb`
- `apps/mobile/lib/l10n/app_de.arb`
- `apps/mobile/lib/l10n/app_es.arb`
- `apps/mobile/lib/l10n/app_it.arb`
- `apps/mobile/lib/l10n/app_pt.arb`
  - Added missing keys for the new coach-story copy and profile journey card.

### Verification results (executed)
- `flutter test test/screens/coach/coach_agir_test.dart` -> PASS
- `flutter test test/screens/coach/coach_checkin_test.dart` -> PASS
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter test test/screens/core_app_screens_smoke_test.dart` -> PASS
- `flutter test test/screens/cta_navigation_regression_test.dart` -> PASS

## Step 10 — Story layer hardening + i18n readiness

### What changed
- `apps/mobile/lib/screens/coach/coach_agir_screen.dart`
  - Added scenario narration loader from `CoachNarrativeService` (same source of truth as Dashboard).
  - Added BYOK-safe fallback when `ByokProvider` is absent in tests/legacy wrappers.
  - `Coach Pulse` and scenario brief texts now consume i18n keys first.
  - Scenario card can display LLM-first narration when available.

- `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - Completion challenge copy now localized via i18n keys.
  - Onboarding quality score card now includes a quality status tag.

- `apps/mobile/lib/screens/coach/coach_checkin_screen.dart`
  - Delta reason + pending impact labels routed through i18n keys.

- `apps/mobile/lib/l10n/app_fr.arb`
- `apps/mobile/lib/l10n/app_en.arb`
- `apps/mobile/lib/l10n/app_de.arb`
- `apps/mobile/lib/l10n/app_es.arb`
- `apps/mobile/lib/l10n/app_it.arb`
- `apps/mobile/lib/l10n/app_pt.arb`
  - Added keys for coach pulse/scenario brief/onboarding challenge/check-in delta reasons.

### Verification results (executed)
- `flutter test test/screens/coach/coach_agir_test.dart` -> PASS
- `flutter test test/screens/coach/coach_checkin_test.dart` -> PASS
- `flutter test test/screens/onboarding_steps_test.dart` -> PASS
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS

## Step 9 — i18n + T7 in Agir + onboarding quality uplift

### What changed
- `apps/mobile/lib/screens/coach/coach_agir_screen.dart`
  - Added T7 scenario narrative loading via `CoachNarrativeService` (BYOK if available, static fallback otherwise).
  - Added safe fallback when `ByokProvider` is not present (tests and legacy contexts).
  - Localized newly added coach strings (pulse/scenario card).
  - Scenario brief card now shows `Coach IA` badge when narration is LLM-generated.

- `apps/mobile/lib/screens/coach/coach_checkin_screen.dart`
  - Localized score-delta reason messages and pending impact label.

- `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - Localized challenge completion CTA copy.
  - Added explicit quality label (`Excellent / Solide / Moyen / Fragile`) next to onboarding quality score in debug metrics panel.

- `apps/mobile/lib/l10n/app_fr.arb`
- `apps/mobile/lib/l10n/app_en.arb`
- `apps/mobile/lib/l10n/app_de.arb`
- `apps/mobile/lib/l10n/app_es.arb`
- `apps/mobile/lib/l10n/app_it.arb`
- `apps/mobile/lib/l10n/app_pt.arb`
  - Added localization keys for Coach Pulse, Agir scenario brief, onboarding challenge copy, and check-in score-reason messages.

### Verification results (executed)
- `flutter test test/screens/coach/coach_agir_test.dart` -> PASS
- `flutter test test/screens/coach/coach_checkin_test.dart` -> PASS
- `flutter test test/screens/onboarding_steps_test.dart` -> PASS
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS

## Step 12 — Coach AI consolidation (Dashboard cost/latency hardening)

### Problem found in senior audit
- Dashboard triggered 3 separate async AI flows on every profile reload:
  - `_loadCoachNarrative()`
  - `_loadEnrichedTips()`
  - `_loadChiffreChocNarratives()`
- With BYOK enabled, this created redundant LLM calls and avoidable latency/cost spikes.

### What changed
- `apps/mobile/lib/screens/coach/coach_dashboard_screen.dart`
  - Added `_loadCoachAiLayer(ByokProvider byok)` orchestration method.
  - New sequence:
    1. Load global narrative first (`_loadCoachNarrative`).
    2. If narrative is LLM-generated, stop there (single-call path).
    3. Only if narrative is static fallback, run extra enrichers (`tips + chiffre choc`) in parallel.
  - Replaced 3 independent `unawaited(...)` calls in `didChangeDependencies()` with a single `unawaited(_loadCoachAiLayer(...))`.

### Why this is safer for production
- Keeps UX coherent: one narrative source drives pulse/greeting/summary.
- Reduces BYOK token burn and call volume in normal success path.
- Preserves resilience: fallback path still enriches when primary narrative is not LLM.

### Verification results (executed)
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter test test/screens/coach/coach_agir_test.dart` -> PASS
- `flutter test test/screens/onboarding_steps_test.dart` -> PASS
- `flutter test test/providers/onboarding_provider_test.dart` -> PASS

## Step 13 — Check-in impact consistency (monthly delta fix)

### Problem found in senior audit
- `ForecasterService.calculateMonthlyDelta()` returned a compounded future value, while UI copy says `+CHF X ce mois`.
- This created semantic mismatch in the check-in card and broke non-regression expectation.

### What changed
- `apps/mobile/lib/services/forecaster_service.dart`
  - Reframed `calculateMonthlyDelta()` as a monthly validated-effort KPI.
  - New behavior: returns the finite sum of current month validated versements.
  - Keeps signature stable for backward compatibility.

### Why this is safer for production
- The number shown in check-in now matches the user mental model (`ce mois`).
- Avoids mixing two different concepts in one KPI (monthly effort vs retraite future value).
- Projection engine still handles long-term compounding separately.

### Verification results (executed)
- `flutter test test/services/forecaster_service_test.dart --plain-name "calculateMonthlyDelta returns sum of versements"` -> PASS
- `flutter test test/screens/coach/coach_checkin_test.dart` -> PASS
- `flutter test test/services/wizard_conditions_service_test.dart test/services/wizard_service_test.dart test/services/coach_profile_wizard_test.dart test/services/forecaster_service_test.dart` -> PASS

## Step 14 — Profile coach-voice uplift (state-of-the-art UX continuity)

### Problem found in senior audit
- Profile screen had coach labels but no real dynamic narrative layer.
- Result: weaker "coach relationship" feel compared to Dashboard.

### What changed
- `apps/mobile/lib/screens/profile_screen.dart`
  - Added dynamic coach narrative loading in profile monthly summary card.
  - Uses `CoachNarrativeService.generate(...)` with dual mode:
    - BYOK configured -> LLM narrative path
    - no BYOK -> static fallback path
  - Keeps concise rendering via `CoachNarrativeService.applyDetailMode(..., concise)`.
  - Reuses existing score history + generated tips as context for coherent cross-screen storytelling.

### Why this is safer for production
- Preserves existing architecture (no screen rewrite, no routing change).
- Reuses 24h narrative cache and guardrails from coach narrative service.
- Adds narrative continuity without introducing fragile custom logic.

### Verification results (executed)
- `flutter analyze lib/screens/profile_screen.dart` -> PASS
- `flutter test test/screens/core_app_screens_smoke_test.dart` -> PASS
- `flutter test test/screens/coach/navigation_shell_test.dart` -> PASS
- `flutter test test/screens/cta_navigation_regression_test.dart` -> PASS

## Step 15 — TestFlight hardening (auth fallback + test stability)

### What changed
- `apps/mobile/lib/screens/auth/login_screen.dart`
  - Added explicit CTA `Continuer en mode local` (same local-first pattern as register).
- `apps/mobile/lib/providers/auth_provider.dart`
  - Normalized startup auth errors through `_toUserFriendlyAuthError()` to avoid raw technical strings.
- `apps/mobile/test/services/auth_service_test.dart`
  - Migrated test setup to `flutter_secure_storage` channel mock + `TestWidgetsFlutterBinding.ensureInitialized()`.
  - Removes flaky binding failures in isolated test runs.
- `docs/TESTFLIGHT_COACH_QA_CHECKLIST.md`
  - Added end-to-end QA checklist focused on "MINT as coach" flows.

### Verification results (executed)
- `flutter analyze lib/providers/auth_provider.dart lib/screens/auth/login_screen.dart` -> PASS
- `flutter test test/services/auth_service_test.dart test/auth/auth_service_test.dart` -> PASS
- `flutter test test/screens/auth_screens_smoke_test.dart` -> PASS
- `flutter test test/screens/core_app_screens_smoke_test.dart test/screens/coach/navigation_shell_test.dart` -> PASS

## Step 9 — Onboarding Step 3 lock + Profile wizard navigation hardening

### Why
- Production symptom reported on TestFlight:
  - Step 3 showed a green validation hint ("Profil minimum prêt") while CTA "Voir ma projection" stayed disabled.
  - Profile FactFind CTAs perceived as non-functional with grey destination.
- Root cause audit identified a validation mismatch in Step 3:
  - Hint used local, incomplete conditions.
  - CTA used provider-level conditions (including couple partner required fields).

### What changed
- `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - Step 3 readiness hint now uses `OnboardingProvider.canAdvanceFromStep3` (same source as CTA enabled state).
  - Result: no contradictory UX state ("ready" + disabled button).

- `apps/mobile/test/screens/core_screens_smoke_test.dart`
  - Added scenario test:
    - Couple flow blocks on Step 3 until partner required fields are complete.
    - After filling partner civil status + income + birth year + employment status, navigation to Step 4 succeeds.

- `apps/mobile/test/screens/core_app_screens_smoke_test.dart`
  - Added navigation regression test:
    - Profile FactFind tap (`Identité & Foyer`) opens `/advisor/wizard`.
    - Asserts no fallback/grey error page.

### Scenario matrix executed (simple -> complex)
1. Mini-onboarding single user (baseline): Step 1 -> 4 progression.
2. Mini-onboarding couple, partner data missing: Step 3 remains blocked (expected).
3. Mini-onboarding couple, partner data complete: Step 3 -> Step 4 progression (expected).
4. Profile FactFind tap -> Wizard route: opens `AdvisorWizardScreenV2` (no error fallback).
5. Plan 30 jours CTA -> Wizard route: still green (non-regression).

### Verification results
- `flutter test test/screens/core_screens_smoke_test.dart test/screens/core_app_screens_smoke_test.dart test/screens/cta_navigation_regression_test.dart` -> PASS
- `flutter analyze` on touched files -> 0 errors (info-level lints only, pre-existing style hints)

### Residual risk notes
- If users select couple/family, partner fields are intentionally mandatory for projection reliability.
- UX copy should explicitly indicate mandatory partner block near CTA in Step 3 (future polish), even though technical gating is now consistent.

## Step 10 — P0 TestFlight hotfixes (onboarding/profil/navigation)

### Why
- TestFlight feedback reported 5 blockers:
  1) couple fields hard to read
  2) completion sheet cropped on iPhone mini
  3) several CTAs leading to grey screen
  4) absurd replacement rate (e.g. 4455%)
  5) top/bottom bars too thick on small devices

### What changed
- `apps/mobile/lib/app.dart`
  - `/advisor/wizard` now supports both `extra['section']` and `?section=` query param.

- `apps/mobile/lib/screens/profile_screen.dart`
  - FactFind CTAs now use robust query routing (`/advisor/wizard?section=...`).
  - App bar compact/pinned on small screens to avoid overlap/clipping.

- `apps/mobile/lib/screens/budget/budget_container_screen.dart`
  - Empty-state CTA now routes with query section (`/advisor/wizard?section=budget`).

- `apps/mobile/lib/screens/advisor/onboarding_30_day_plan_screen.dart`
  - "Compléter mon diagnostic" now routes to `/advisor/wizard?section=identity`.

- `apps/mobile/lib/screens/advisor/advisor_onboarding_screen.dart`
  - Completion sheet made scroll-safe on small devices:
    - `isScrollControlled: true`
    - max height 90% viewport
    - internal `SingleChildScrollView`
  - Step-1 diagnostic CTAs normalized to identity section.

- `apps/mobile/lib/screens/advisor/onboarding/onboarding_step_income.dart`
  - Added explicit partner section header card for better readability in couple/family flow.

- `apps/mobile/lib/services/forecaster_service.dart`
  - Added `_safeReplacementRate(...)` guard:
    - invalid/incomplete income => 0
    - low annual income floor (< 12k) => 0
    - clamp replacement rate to [0, 200]

- `apps/mobile/lib/widgets/coach/mint_trajectory_chart.dart`
  - UI display clamps replacement rate to avoid absurd values.

- `apps/mobile/lib/screens/main_navigation_shell.dart`
  - Bottom nav compact mode for small screens (iPhone mini): reduced paddings, icon/text sizes.

- `apps/mobile/lib/screens/coach/coach_dashboard_screen.dart`
  - Top app bars compact mode for small screens: reduced expanded/toolbar heights and title size.

### Verification results (executed)
- `flutter test test/screens/core_app_screens_smoke_test.dart` -> PASS
- `flutter test test/screens/onboarding_steps_test.dart` -> PASS
- `flutter test test/screens/coach/coach_dashboard_test.dart` -> PASS
- `flutter test test/screens/coach/navigation_shell_test.dart` -> PASS
- `flutter test test/screens/core_app_screens_smoke_test.dart --plain-name "navigates to wizard from FactFind CTAs (no grey error screen)"` -> PASS
- `flutter test test/screens/core_screens_smoke_test.dart --plain-name "step 3 couple blocks progression until partner required fields are complete"` -> PASS

### Notes
- `flutter analyze` on touched files: 0 errors, info/warnings non-blocking only.
- This patch is intentionally surgical (route robustness + mobile layout hardening) to avoid regression risk.
