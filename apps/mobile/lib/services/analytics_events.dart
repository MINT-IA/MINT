/// Centralised analytics event constants for MINT.
///
/// Single source of truth for all event names used with [AnalyticsService].
/// Avoids magic strings and typo-induced silent tracking failures.
///
/// Sprint P8-2 — Flow Unifié.
library;

// ════════════════════════════════════════════════════════════════
//  ONBOARDING
// ════════════════════════════════════════════════════════════════

/// User lands on the first onboarding screen.
const String kEventOnboardingStarted = 'onboarding_started';

/// User selects a stress type on the stress selector page.
const String kEventOnboardingStressSelected = 'onboarding_stress_selected';

/// User completes the 3-question step.
const String kEventOnboardingQuestionsCompleted =
    'onboarding_questions_completed';

/// User reaches the end of the onboarding flow (all 5 steps).
const String kEventOnboardingCompleted = 'onboarding_completed';

// ════════════════════════════════════════════════════════════════
//  CHIFFRE CHOC
// ════════════════════════════════════════════════════════════════

/// Chiffre choc reveal animation played.
const String kEventPremierEclairageViewed = 'premier_eclairage_viewed';

/// User taps the share button on the premier éclairage card.
const String kEventPremierEclairageShared = 'premier_eclairage_shared';

// ════════════════════════════════════════════════════════════════
//  JIT EXPLANATION
// ════════════════════════════════════════════════════════════════

/// User views the JIT explanation page.
const String kEventJitExplanationViewed = 'jit_explanation_viewed';

// ════════════════════════════════════════════════════════════════
//  TOP ACTIONS
// ════════════════════════════════════════════════════════════════

/// User taps one of the top-3 action cards.
const String kEventTopActionTapped = 'top_action_tapped';

// ════════════════════════════════════════════════════════════════
//  ENRICHMENT
// ════════════════════════════════════════════════════════════════

/// User enters the enrichment flow from onboarding CTA.
const String kEventEnrichmentStarted = 'enrichment_started';

/// User completes the enrichment flow (all optional questions answered).
const String kEventEnrichmentCompleted = 'enrichment_completed';

// ════════════════════════════════════════════════════════════════
//  NAVIGATION
// ════════════════════════════════════════════════════════════════

/// Generic screen view event (use with screenName param).
const String kEventScreenView = 'screen_view';

/// User switches between main tabs.
const String kEventTabSwitched = 'tab_switched';

/// User taps a CTA button.
const String kEventCtaClicked = 'cta_clicked';
