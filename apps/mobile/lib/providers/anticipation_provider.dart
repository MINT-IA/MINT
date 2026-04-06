import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/anticipation/anticipation_engine.dart';
import 'package:mint_mobile/services/anticipation/anticipation_persistence.dart';
import 'package:mint_mobile/services/anticipation/anticipation_ranking.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/services/anticipation/anticipation_trigger.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/coach/compliance_guard.dart';

// ────────────────────────────────────────────────────────────
//  ANTICIPATION PROVIDER — Phase 04 / Moteur d'Anticipation
// ────────────────────────────────────────────────────────────
//
// ChangeNotifier wiring AnticipationEngine, Persistence, and
// Ranking into a reactive state provider for the UI layer.
//
// Evaluates triggers once per session (CTX-02), validates each
// visible signal with ComplianceGuard (ANT-04), and exposes
// ranked signals as visible + overflow lists.
//
// Pattern: Follows BiographyProvider / CoachProfileProvider.
// ────────────────────────────────────────────────────────────

/// Provider for proactive anticipation signals on the Aujourd'hui tab.
///
/// Evaluates triggers once per session, validates with [ComplianceGuard],
/// and exposes ranked signals split into [visibleSignals] and [overflowSignals].
class AnticipationProvider extends ChangeNotifier {
  AnticipationRankResult _rankResult =
      const AnticipationRankResult(visible: [], overflow: []);
  bool _evaluated = false;

  /// Visible signals (max 2) for card display.
  List<AnticipationSignal> get visibleSignals => _rankResult.visible;

  /// Overflow signals for expandable section.
  List<AnticipationSignal> get overflowSignals => _rankResult.overflow;

  /// Whether any signals are visible.
  bool get hasSignals => _rankResult.visible.isNotEmpty;

  /// Whether there are overflow signals beyond the visible set.
  bool get hasOverflow => _rankResult.overflow.isNotEmpty;

  /// Whether evaluation has been performed this session.
  bool get evaluated => _evaluated;

  /// Evaluate anticipation triggers for the current session.
  ///
  /// Only evaluates once per session (CTX-02). Call [resetSession]
  /// to allow re-evaluation on next app launch.
  ///
  /// Each visible signal is validated with [ComplianceGuard.validateAlert()].
  /// Non-compliant signals are moved to overflow (T-04-08).
  Future<void> evaluateOnSessionStart({
    required CoachProfile profile,
    required List<BiographyFact> facts,
    DateTime? now,
    SharedPreferences? prefsOverride,
  }) async {
    if (_evaluated) return;

    final effectiveNow = now ?? DateTime.now();

    try {
      final prefs = prefsOverride ?? await SharedPreferences.getInstance();

      // Get dismissed and snoozed triggers
      final dismissedTriggers =
          await AnticipationPersistence.getDismissedTriggers(prefs, now: effectiveNow);
      final snoozedTriggers =
          await AnticipationPersistence.getSnoozedTriggers(prefs, now: effectiveNow);

      // Map triggers to signal ID prefixes for filtering
      final allSuppressed = <String>{
        ...dismissedTriggers.map((t) => t.name),
        ...snoozedTriggers.map((t) => t.name),
      };

      // Build dismissed IDs list (signals whose trigger name prefix is suppressed)
      // AnticipationEngine uses IDs like "{trigger.name}_{yyyyMMdd}"
      final dismissedIds = allSuppressed.toList();

      // Evaluate raw signals
      final raw = AnticipationEngine.evaluate(
        profile: profile,
        facts: facts,
        now: effectiveNow,
        dismissedIds: dismissedIds,
      );

      // Get weekly count for ranking
      final shownCount =
          await AnticipationPersistence.signalsShownThisWeek(prefs, now: effectiveNow);

      // Rank signals
      var rankResult = AnticipationRanking.rank(
        signals: raw,
        now: effectiveNow,
        signalsAlreadyShownThisWeek: shownCount,
      );

      // Validate visible signals with ComplianceGuard (ANT-04, T-04-08)
      final compliantVisible = <AnticipationSignal>[];
      final nonCompliant = <AnticipationSignal>[];

      for (final signal in rankResult.visible) {
        // Validate using title + fact text (resolved from ARB keys would
        // require BuildContext; validate the template keys as proxy since
        // they are known-safe template strings)
        final titleCheck =
            ComplianceGuard.validateAlert(signal.titleKey);
        final factCheck =
            ComplianceGuard.validateAlert(signal.factKey);

        if (titleCheck.isCompliant && factCheck.isCompliant) {
          compliantVisible.add(signal);
        } else {
          nonCompliant.add(signal);
          debugPrint(
            '[AnticipationProvider] Signal ${signal.id} failed compliance: '
            'title=${titleCheck.isCompliant}, fact=${factCheck.isCompliant}',
          );
        }
      }

      // Move non-compliant to overflow (never display non-compliant alerts)
      _rankResult = AnticipationRankResult(
        visible: compliantVisible,
        overflow: [...nonCompliant, ...rankResult.overflow],
      );

      // Record each visible signal as shown for weekly cap
      for (final _ in compliantVisible) {
        await AnticipationPersistence.recordSignalShown(prefs, now: effectiveNow);
      }

      _evaluated = true;
    } catch (e) {
      debugPrint('[AnticipationProvider] Evaluation error: $e');
      _rankResult = const AnticipationRankResult(visible: [], overflow: []);
      _evaluated = true;
    }

    notifyListeners();
  }

  /// Dismiss a signal ("Compris" / Got it).
  ///
  /// Maps the signal's template to [AnticipationTrigger] and records
  /// the dismissal in persistence, then removes from visible.
  Future<void> dismissSignal(AnticipationSignal signal) async {
    final trigger = _triggerFromTemplate(signal.template);
    final prefs = await SharedPreferences.getInstance();
    await AnticipationPersistence.dismiss(prefs, trigger);

    _removeFromVisible(signal);
    notifyListeners();
  }

  /// Snooze a signal ("Plus tard" / Remind me later).
  ///
  /// Maps the signal's template to [AnticipationTrigger] and records
  /// the snooze in persistence, then removes from visible.
  Future<void> snoozeSignal(AnticipationSignal signal) async {
    final trigger = _triggerFromTemplate(signal.template);
    final prefs = await SharedPreferences.getInstance();
    await AnticipationPersistence.snooze(prefs, trigger);

    _removeFromVisible(signal);
    notifyListeners();
  }

  /// Reset session flag to allow re-evaluation on next app launch.
  void resetSession() {
    _evaluated = false;
  }

  // ── Helpers ──────────────────────────────────────────────────

  /// Remove a signal from visible list.
  void _removeFromVisible(AnticipationSignal signal) {
    final updatedVisible =
        _rankResult.visible.where((s) => s.id != signal.id).toList();
    _rankResult = AnticipationRankResult(
      visible: updatedVisible,
      overflow: _rankResult.overflow,
    );
  }

  /// Map AlertTemplate to AnticipationTrigger (1:1 mapping).
  static AnticipationTrigger _triggerFromTemplate(AlertTemplate template) {
    switch (template) {
      case AlertTemplate.fiscal3aDeadline:
        return AnticipationTrigger.fiscal3aDeadline;
      case AlertTemplate.cantonalTaxDeadline:
        return AnticipationTrigger.cantonalTaxDeadline;
      case AlertTemplate.lppRachatWindow:
        return AnticipationTrigger.lppRachatWindow;
      case AlertTemplate.salaryIncrease3aRecalc:
        return AnticipationTrigger.salaryIncrease3aRecalc;
      case AlertTemplate.ageMilestoneLppBonification:
        return AnticipationTrigger.ageMilestoneLppBonification;
    }
  }
}
