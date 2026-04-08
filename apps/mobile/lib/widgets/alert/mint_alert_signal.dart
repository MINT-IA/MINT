import 'package:mint_mobile/services/voice/voice_cursor_contract.dart';

/// MintAlertSignal — Phase 9 D-09 typed feeder data class.
///
/// Plain immutable value object emitted by the three rule-based feeders
/// (`AnticipationProvider`, `NudgeEngine`, `ProactiveTriggerService`) and
/// consumed by S5 widgets that build a [MintAlertObject] from ARB keys.
///
/// **Sourcing rule (NON-NEGOTIABLE — D-07):** instances of this class
/// must NEVER be constructed inside a `claude_*_service.dart` file. The
/// `tools/checks/no_llm_alert.py` grep gate (Plan 09-03) enforces this.
///
/// Fields are ARB **keys**, not resolved strings, so the consuming widget
/// can localize at the latest possible moment via [BuildContext].
class MintAlertSignal {
  /// Severity from the generated voice cursor contract.
  final Gravity gravity;

  /// ARB key for the "fact" line of the MintAlertObject grammar
  /// (MINT-as-subject — see D-03).
  final String factKey;

  /// ARB key for the "cause" line.
  final String causeKey;

  /// ARB key for the "next moment" line (invitation, never imperative).
  final String nextMomentKey;

  /// Topic tag used by the sensitive-topic classifier in [resolveLevel]
  /// (e.g. `'debt'`, `'fiscal'`, `'lpp'`).
  final String topicTag;

  /// Deterministic content hash used for ack persistence (Plan 09-04).
  /// Convention: `'{feeder}:{template}:{yyyyMMdd}'`.
  final String alertId;

  const MintAlertSignal({
    required this.gravity,
    required this.factKey,
    required this.causeKey,
    required this.nextMomentKey,
    required this.topicTag,
    required this.alertId,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MintAlertSignal &&
          runtimeType == other.runtimeType &&
          gravity == other.gravity &&
          factKey == other.factKey &&
          causeKey == other.causeKey &&
          nextMomentKey == other.nextMomentKey &&
          topicTag == other.topicTag &&
          alertId == other.alertId;

  @override
  int get hashCode => Object.hash(
        gravity,
        factKey,
        causeKey,
        nextMomentKey,
        topicTag,
        alertId,
      );

  @override
  String toString() =>
      'MintAlertSignal(gravity: $gravity, alertId: $alertId, topic: $topicTag)';
}
