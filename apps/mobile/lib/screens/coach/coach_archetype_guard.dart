/// Coach archetype gate — Sub-phase 01.5 Wave 02 Plan 03 Task 4.
///
/// Pure decision helper that the [_CoachChatScreenState] reads BEFORE
/// constructing a [CoachContext]. Profiles whose archetype falls
/// outside the route-accessible set are redirected to /waitlist. Calibrated
/// profiles fall through to the normal coach build path; narrowly
/// route-accessible profiles may still be hard-gated by the orchestrator.
///
/// The calibrated set remains `{FinancialArchetype.swissNative}`.
/// `FinancialArchetype.independentNoLpp` is route-accessible only so the
/// audited deterministic no-LPP/3a fallback can build a real CoachContext;
/// generic questions and streaming remain blocked at the orchestrator.
/// Couple status stays within swissNative; it does NOT extend the enum.
///
/// Defense-in-depth: this is the primary route-layer gate. The
/// orchestrator carries the secondary refusal layer
/// (`coach_orchestrator.dart` Task 5) in case a deep-link / notification
/// handler / stale cache bypasses the route guard.
///
/// References:
/// - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-MAPPER-archetype-detection.md §7.2 / §7.4
/// - .planning/phases/01.5-archetype-hard-gate-fatca/01.5-CONTEXT.md §0
library;

import 'package:flutter/foundation.dart';

import 'package:mint_mobile/models/coach_profile.dart';

/// Verdict returned by [evaluateCoachArchetypeGate]: whether to block
/// (route to /waitlist) and the archetype slug to forward as
/// `WaitlistArgs.archetype` (null when archetype is unknown so the
/// consent payload coerces to 'other' at submit time).
@immutable
class CoachArchetypeGateVerdict {
  const CoachArchetypeGateVerdict({
    required this.shouldBlock,
    required this.archetypeSlug,
  });

  /// True when the profile is not allowed to render the coach shell and must
  /// redirect to /waitlist before building a [CoachContext].
  final bool shouldBlock;

  /// snake_case archetype slug (e.g. 'expat_us', 'cross_border',
  /// 'independent_no_lpp'). Null when archetype is
  /// `FinancialArchetype.unknown` — the consent payload coerces null
  /// to 'other' (see [WaitlistService.submit]).
  final String? archetypeSlug;
}

/// Evaluate whether a [CoachProfile] should be allowed into the coach
/// shell. This is a route decision only; the orchestrator remains the
/// authority for LLM/fallback eligibility.
CoachArchetypeGateVerdict evaluateCoachArchetypeGate(CoachProfile profile) {
  final archetype = profile.archetype;

  // Calibrated set = {swissNative}. Couple status does NOT change the gate
  // decision because the typed getter returns swissNative for nationality=CH.
  if (archetype == FinancialArchetype.swissNative) {
    return const CoachArchetypeGateVerdict(
      shouldBlock: false,
      archetypeSlug: null,
    );
  }

  // Row 23 / CJT-063: independent/no-LPP is not broadly calibrated, but it
  // has one audited deterministic local FR path for no-LPP 3a guidance. Let
  // the chat shell build a real CoachContext so the orchestrator can apply
  // its narrower safe-local-only guard. Do not extend this to FATCA,
  // cross-border, unknown, or other unsupported archetypes.
  if (archetype == FinancialArchetype.independentNoLpp) {
    return const CoachArchetypeGateVerdict(
      shouldBlock: false,
      archetypeSlug: 'independent_no_lpp',
    );
  }

  // Any other archetype is gated. WaitlistArgs slug = null for
  // unknown (so submit coerces to 'other'), otherwise the canonical
  // snake_case slug exposed by FinancialArchetype.backendName.
  final slug =
      archetype == FinancialArchetype.unknown ? null : archetype.backendName;
  return CoachArchetypeGateVerdict(
    shouldBlock: true,
    archetypeSlug: slug,
  );
}
