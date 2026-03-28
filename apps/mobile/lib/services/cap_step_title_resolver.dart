/// Centralized resolver for CapStep ARB title keys → localized strings.
///
/// This is the SINGLE source of truth for resolving cap step title keys.
/// All consumers (DataDrivenOpenerService, context_injector_service,
/// CapSequenceCard) must use this instead of maintaining their own switch.
///
/// When new steps are added to CapSequenceEngine, add them HERE — one place,
/// not three fragile switches.
library;

import 'package:mint_mobile/l10n/app_localizations.dart';

/// Resolve a CapStep [titleKey] to its localized label.
///
/// Returns null if the key is not recognized — callers should handle
/// the null case (e.g. fall back to step.id or titleKey itself).
String? resolveCapStepTitle(String titleKey, S l) {
  switch (titleKey) {
    // ── Retirement (10 steps) ──
    case 'capStepRetirement01Title': return l.capStepRetirement01Title;
    case 'capStepRetirement02Title': return l.capStepRetirement02Title;
    case 'capStepRetirement03Title': return l.capStepRetirement03Title;
    case 'capStepRetirement04Title': return l.capStepRetirement04Title;
    case 'capStepRetirement05Title': return l.capStepRetirement05Title;
    case 'capStepRetirement06Title': return l.capStepRetirement06Title;
    case 'capStepRetirement07Title': return l.capStepRetirement07Title;
    case 'capStepRetirement08Title': return l.capStepRetirement08Title;
    case 'capStepRetirement09Title': return l.capStepRetirement09Title;
    case 'capStepRetirement10Title': return l.capStepRetirement10Title;
    // ── Budget (6 steps) ──
    case 'capStepBudget01Title': return l.capStepBudget01Title;
    case 'capStepBudget02Title': return l.capStepBudget02Title;
    case 'capStepBudget03Title': return l.capStepBudget03Title;
    case 'capStepBudget04Title': return l.capStepBudget04Title;
    case 'capStepBudget05Title': return l.capStepBudget05Title;
    case 'capStepBudget06Title': return l.capStepBudget06Title;
    // ── Housing (7 steps) ──
    case 'capStepHousing01Title': return l.capStepHousing01Title;
    case 'capStepHousing02Title': return l.capStepHousing02Title;
    case 'capStepHousing03Title': return l.capStepHousing03Title;
    case 'capStepHousing04Title': return l.capStepHousing04Title;
    case 'capStepHousing05Title': return l.capStepHousing05Title;
    case 'capStepHousing06Title': return l.capStepHousing06Title;
    case 'capStepHousing07Title': return l.capStepHousing07Title;
    default: return null;
  }
}
