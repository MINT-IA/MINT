/// Coach archetype gate — Sub-phase 01.5 Wave 02 Plan 03 Task 4.
///
/// Pure decision helper that the [_CoachChatScreenState] reads BEFORE
/// constructing a [CoachContext]. Profiles whose archetype falls
/// outside the calibrated set are redirected to /waitlist; calibrated
/// profiles fall through to the normal coach build path.
///
/// The calibrated set is currently `{FinancialArchetype.swissNative}`
/// (irrespective of `profile.isCouple` — CONTEXT §0 resolved-blocker:
/// swissNative+couple = read `isCouple` at the gate site, do NOT
/// extend the enum).
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

  /// True when the profile is NOT calibrated and the coach entry must
  /// redirect to /waitlist before building a [CoachContext].
  final bool shouldBlock;

  /// snake_case archetype slug (e.g. 'expat_us', 'cross_border',
  /// 'independent_no_lpp'). Null when archetype is
  /// `FinancialArchetype.unknown` — the consent payload coerces null
  /// to 'other' (see [WaitlistService.submit]).
  final String? archetypeSlug;
}

/// Evaluate whether a [CoachProfile] should be allowed into the coach
/// entry. Returns a [CoachArchetypeGateVerdict] with shouldBlock=true
/// for any archetype outside the calibrated set, paired with the
/// archetype slug to forward as `WaitlistArgs.archetype`.
CoachArchetypeGateVerdict evaluateCoachArchetypeGate(CoachProfile profile) {
  final archetype = profile.archetype;

  // Calibrated set = {swissNative}. isCouple is read at this site (per
  // CONTEXT §0) but does NOT change the gate decision — swissNative
  // covers couples implicitly because the typed getter returns
  // swissNative for nationality=CH regardless of etatCivil.
  if (archetype == FinancialArchetype.swissNative) {
    return const CoachArchetypeGateVerdict(
      shouldBlock: false,
      archetypeSlug: null,
    );
  }

  // Any other archetype is gated. WaitlistArgs slug = null for
  // unknown (so submit coerces to 'other'), otherwise the canonical
  // snake_case slug exposed by FinancialArchetype.backendName.
  final slug = archetype == FinancialArchetype.unknown
      ? null
      : archetype.backendName;
  return CoachArchetypeGateVerdict(
    shouldBlock: true,
    archetypeSlug: slug,
  );
}
