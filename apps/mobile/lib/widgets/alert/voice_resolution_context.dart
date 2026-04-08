import 'package:flutter/foundation.dart';

import '../../services/voice/voice_cursor_contract.dart';

/// Immutable bundle of the caller-side inputs required by
/// [resolveLevel] from `voice_cursor_contract.dart`.
///
/// Phase 9 Plan 09-01 decision D-01: [MintAlertObject] reuses the generated
/// `Gravity` enum and delegates N-level routing to `resolveLevel(...)`.
/// To keep the widget API tight, callers pass a single
/// [VoiceResolutionContext] instead of five individual fields.
///
/// All fields are captured from application state by the feeder (Plan 09-02),
/// NOT by the widget itself, so the widget remains a pure function of its
/// inputs:
///   * [relation] comes from `BiographyProvider.currentRelation`.
///   * [preference] comes from `CoachProfile.voiceCursorPreference`.
///   * [sensitiveFlag] is the already-classified topic flag.
///   * [fragileFlag] is `CoachProfile.fragileModeEnteredAt != null`.
///   * [n5Budget] is `n5PerWeekMax - CoachProfile.n5IssuedThisWeek`.
///
/// The widget calls [resolveLevel] with the carried [Gravity] to compute a
/// [VoiceLevel]; today that level is used only as a semantic hint. Plan 09-02
/// wires it into the visual rendering matrix for calibration passes.
@immutable
class VoiceResolutionContext {
  const VoiceResolutionContext({
    required this.relation,
    required this.preference,
    required this.sensitiveFlag,
    required this.fragileFlag,
    required this.n5Budget,
  });

  final Relation relation;
  final VoicePreference preference;
  final bool sensitiveFlag;
  final bool fragileFlag;
  final int n5Budget;

  /// Neutral default useful for smoke tests / default stories only. Real
  /// callers MUST pass a context sourced from `BiographyProvider` and
  /// `CoachProfile` — see Plan 09-02.
  static const VoiceResolutionContext neutral = VoiceResolutionContext(
    relation: Relation.established,
    preference: VoicePreference.direct,
    sensitiveFlag: false,
    fragileFlag: false,
    n5Budget: 1,
  );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VoiceResolutionContext &&
          other.relation == relation &&
          other.preference == preference &&
          other.sensitiveFlag == sensitiveFlag &&
          other.fragileFlag == fragileFlag &&
          other.n5Budget == n5Budget;

  @override
  int get hashCode => Object.hash(
        relation,
        preference,
        sensitiveFlag,
        fragileFlag,
        n5Budget,
      );
}

/// Placeholder for Phase 12+ partner routing. Info-only by default (D-12).
///
/// The type exists today so callers can wire the argument now and the
/// Phase 12 unlock is a field-flip rather than an API migration. Calling
/// [execute] today throws [UnimplementedError] — see `PHASE_12.md`.
@immutable
class ExternalActionStub {
  const ExternalActionStub({required this.label});

  /// Human-readable action label (localized by the feeder, not the widget).
  final String label;

  /// Always throws [UnimplementedError] until Phase 12+ partner routing
  /// is signed. The constructor + field are deliberately usable so Plan
  /// 09-02 can wire them into [MintAlertObject] without breaking later.
  Never execute() {
    throw UnimplementedError(
      'Partner routing not signed — see PHASE_12.md (D-12 G3 politique).',
    );
  }
}
