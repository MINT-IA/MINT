import 'package:intl/intl.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/anticipation/anticipation_signal.dart';
import 'package:mint_mobile/services/anticipation/anticipation_trigger.dart';
import 'package:mint_mobile/services/anticipation/cantonal_deadlines.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';

// ────────────────────────────────────────────────────────────
//  ANTICIPATION ENGINE — Phase 04 / Moteur d'Anticipation
// ────────────────────────────────────────────────────────────
//
// Pure, stateless engine. No SharedPreferences, no Flutter UI,
// no async, no LLM, no network (ANT-08).
//
// Evaluates all AnticipationTrigger conditions and returns
// applicable AnticipationSignal objects (unranked — ranking
// is handled by Plan 02).
//
// Pattern: Follows NudgeEngine from S61.
//
// Callers must filter dismissed signals before rendering:
//   final dismissed = await persistence.getDismissedIds();
//   final signals = AnticipationEngine.evaluate(
//     profile: profile,
//     facts: facts,
//     now: DateTime.now(),
//     dismissedIds: dismissed,
//   );
// ────────────────────────────────────────────────────────────

/// Pure evaluation engine for proactive anticipation signals.
///
/// All public methods are static. No side effects.
/// Zero async, zero LLM, zero network calls (ANT-08).
class AnticipationEngine {
  AnticipationEngine._();

  // ── Configuration ────────────────────────────────────────

  /// LPP bonification bracket boundaries where rate changes.
  static const _lppBracketBoundaries = [35, 45, 55];

  /// LPP bonification rates by bracket (percentage as int).
  static const Map<int, _LppBracketRate> _lppBracketRates = {
    35: _LppBracketRate(oldRate: 7, newRate: 10),
    45: _LppBracketRate(oldRate: 10, newRate: 15),
    55: _LppBracketRate(oldRate: 15, newRate: 18),
  };

  /// Minimum salary increase percentage to trigger alert.
  static const double _salaryIncreasePctThreshold = 0.05;

  /// Minimum salary increase in CHF to trigger alert.
  static const double _salaryIncreaseAbsThreshold = 2000.0;

  /// Days before cantonal deadline to start alerting.
  static const int _cantonalAlertDaysBefore = 45;

  // ── Public API ───────────────────────────────────────────

  /// Evaluate all triggers and return applicable signals.
  ///
  /// **Pure function** — no side effects. All persistence (dismiss)
  /// is passed in by the caller via [dismissedIds].
  ///
  /// Returns signals unranked (ranking is Plan 02).
  /// Dismissed signals (id in [dismissedIds]) are excluded.
  /// Expired signals are excluded.
  ///
  /// [profile] — current user CoachProfile.
  /// [facts]   — user's BiographyFact list (for salary detection).
  /// [now]     — current datetime (injectable for tests).
  /// [dismissedIds] — ids of previously dismissed signals.
  static List<AnticipationSignal> evaluate({
    required CoachProfile profile,
    required List<BiographyFact> facts,
    required DateTime now,
    required List<String> dismissedIds,
  }) {
    final candidates = <AnticipationSignal>[];

    _check3aDeadline(candidates, now, profile);
    _checkCantonalTaxDeadline(candidates, now, profile);
    _checkLppRachatWindow(candidates, now, profile);
    _checkSalaryIncrease(candidates, now, profile, facts);
    _checkAgeMilestone(candidates, now, profile);

    // Filter dismissed and expired
    final active = candidates.where((s) {
      if (dismissedIds.contains(s.id)) return false;
      if (s.expiresAt.isBefore(now) || s.expiresAt.isAtSameMomentAs(now)) {
        return false;
      }
      return true;
    }).toList();

    return active;
  }

  // ── Trigger implementations ──────────────────────────────

  /// 3a versement deadline: fires in December only.
  /// Uses archetype-aware plafond (7'258 vs 36'288).
  static void _check3aDeadline(
    List<AnticipationSignal> signals,
    DateTime now,
    CoachProfile profile,
  ) {
    if (now.month != 12) return;

    final daysLeft = 31 - now.day;
    final isIndependentNoLpp =
        profile.archetype == FinancialArchetype.independentNoLpp;
    final plafond = isIndependentNoLpp ? "36'288" : "7'258";

    final id = _id(AnticipationTrigger.fiscal3aDeadline, now);
    signals.add(AnticipationSignal(
      id: id,
      template: AlertTemplate.fiscal3aDeadline,
      titleKey: 'anticipation3aDeadlineTitle',
      factKey: 'anticipation3aDeadlineFact',
      sourceRef: 'OPP3 art.\u00a07',
      simulatorLink: '/pilier-3a',
      priorityScore: 0.0,
      expiresAt: DateTime(now.year + 1, 1, 1),
      params: {
        'days': daysLeft.toString(),
        'limit': plafond,
        'year': now.year.toString(),
      },
    ));
  }

  /// Cantonal tax declaration deadline: fires 45 days before.
  /// Respects canton-specific deadlines (TI = April 30, etc.).
  static void _checkCantonalTaxDeadline(
    List<AnticipationSignal> signals,
    DateTime now,
    CoachProfile profile,
  ) {
    final canton = profile.canton;
    if (canton.isEmpty) return;

    final deadline = getCantonalDeadline(canton);
    final deadlineDate = DateTime(now.year, deadline.month, deadline.day);
    final alertStart = deadlineDate
        .subtract(const Duration(days: _cantonalAlertDaysBefore));

    // Fire only if now is within [alertStart, deadlineDate)
    if (now.isBefore(alertStart) || !now.isBefore(deadlineDate)) return;

    final formattedDeadline =
        '${deadline.day.toString().padLeft(2, '0')}.${deadline.month.toString().padLeft(2, '0')}';

    final id = _id(AnticipationTrigger.cantonalTaxDeadline, now);
    signals.add(AnticipationSignal(
      id: id,
      template: AlertTemplate.cantonalTaxDeadline,
      titleKey: 'anticipationTaxDeadlineTitle',
      factKey: 'anticipationTaxDeadlineFact',
      sourceRef: 'LIFD art.\u00a0166',
      simulatorLink: '/fiscal',
      priorityScore: 0.0,
      expiresAt: deadlineDate,
      params: {
        'canton': canton,
        'deadline': formattedDeadline,
      },
    ));
  }

  /// LPP rachat (buyback) window: fires in Q4 (Oct-Dec).
  /// Only for users with LPP capital or rachat potential.
  static void _checkLppRachatWindow(
    List<AnticipationSignal> signals,
    DateTime now,
    CoachProfile profile,
  ) {
    if (now.month < 10) return;

    final hasLppCapital = (profile.prevoyance.avoirLppTotal ?? 0) > 0;
    final hasRachatMax = (profile.prevoyance.rachatMaximum ?? 0) > 0;
    if (!hasLppCapital && !hasRachatMax) return;

    final id = _id(AnticipationTrigger.lppRachatWindow, now);
    signals.add(AnticipationSignal(
      id: id,
      template: AlertTemplate.lppRachatWindow,
      titleKey: 'anticipationLppRachatTitle',
      factKey: 'anticipationLppRachatFact',
      sourceRef: 'LPP art.\u00a079b',
      simulatorLink: '/lpp-rachat',
      priorityScore: 0.0,
      expiresAt: DateTime(now.year + 1, 1, 1),
      params: {'year': now.year.toString()},
    ));
  }

  /// Salary increase detection: >5% OR >2'000 CHF.
  /// Skips userEdit source (correction, not real increase).
  static void _checkSalaryIncrease(
    List<AnticipationSignal> signals,
    DateTime now,
    CoachProfile profile,
    List<BiographyFact> facts,
  ) {
    // Find salary facts sorted by updatedAt descending
    final salaryFacts = facts
        .where((f) => f.factType == FactType.salary && !f.isDeleted)
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

    if (salaryFacts.length < 2) return;

    final latest = salaryFacts[0];
    final previous = salaryFacts[1];

    // Skip if latest is a correction (userEdit), not a real change
    if (latest.source == FactSource.userEdit) return;

    final newSalary = double.tryParse(latest.value) ?? 0;
    final oldSalary = double.tryParse(previous.value) ?? 0;
    if (oldSalary <= 0 || newSalary <= oldSalary) return;

    final delta = newSalary - oldSalary;
    final pctIncrease = delta / oldSalary;

    if (pctIncrease < _salaryIncreasePctThreshold &&
        delta < _salaryIncreaseAbsThreshold) {
      return;
    }

    final isIndependentNoLpp =
        profile.archetype == FinancialArchetype.independentNoLpp;
    final plafond = isIndependentNoLpp ? "36'288" : "7'258";

    final id = _id(AnticipationTrigger.salaryIncrease3aRecalc, now);
    signals.add(AnticipationSignal(
      id: id,
      template: AlertTemplate.salaryIncrease3aRecalc,
      titleKey: 'anticipationSalaryIncreaseTitle',
      factKey: 'anticipationSalaryIncreaseFact',
      sourceRef: 'OPP3 art.\u00a07',
      simulatorLink: '/pilier-3a',
      priorityScore: 0.0,
      expiresAt: now.add(const Duration(days: 30)),
      params: {'newMax': plafond},
    ));
  }

  /// Age milestone: LPP bonification bracket boundary (35, 45, 55).
  /// Fires only if age == boundary year (first year in new bracket).
  static void _checkAgeMilestone(
    List<AnticipationSignal> signals,
    DateTime now,
    CoachProfile profile,
  ) {
    final age = now.year - profile.birthYear;

    if (!_lppBracketBoundaries.contains(age)) return;

    final rates = _lppBracketRates[age]!;

    final id = _id(AnticipationTrigger.ageMilestoneLppBonification, now);
    signals.add(AnticipationSignal(
      id: id,
      template: AlertTemplate.ageMilestoneLppBonification,
      titleKey: 'anticipationAgeMilestoneTitle',
      factKey: 'anticipationAgeMilestoneFact',
      sourceRef: 'LPP art.\u00a016',
      simulatorLink: '/lpp-deep',
      priorityScore: 0.0,
      expiresAt: DateTime(now.year + 1, 1, 1),
      params: {
        'age': age.toString(),
        'oldRate': rates.oldRate.toString(),
        'newRate': rates.newRate.toString(),
      },
    ));
  }

  // ── Helpers ──────────────────────────────────────────────

  /// Generate signal id: `{trigger}_{yyyyMMdd}`.
  static String _id(AnticipationTrigger trigger, DateTime now) {
    final date = DateFormat('yyyyMMdd').format(now);
    return '${trigger.name}_$date';
  }
}

/// Internal helper for LPP bracket rate transitions.
class _LppBracketRate {
  final int oldRate;
  final int newRate;
  const _LppBracketRate({required this.oldRate, required this.newRate});
}
