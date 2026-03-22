/// ReadinessGate — checks if a CoachProfile satisfies a ScreenEntry's
/// data requirements before the RoutePlanner opens the surface.
///
/// See docs/CHAT_TO_SCREEN_ORCHESTRATION_STRATEGY.md §5
library;

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/navigation/readiness_result.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';

export 'package:mint_mobile/services/navigation/readiness_result.dart'
    show ReadinessLevel, ReadinessResult;

// ════════════════════════════════════════════════════════════════
//  READINESS GATE
// ════════════════════════════════════════════════════════════════

/// Stateless gate that determines readiness for a [ScreenEntry] given a
/// [CoachProfile].
///
/// ## Field resolution
///
/// Named field keys are resolved against the profile using a fixed mapping.
/// Supported keys:
///   - `age`                 — profile.age > 0
///   - `canton`              — profile.canton.isNotEmpty
///   - `salaireBrut`         — profile.salaireBrutMensuel > 0
///   - `netIncome`           — profile.salaireBrutMensuel > 0 (derived)
///   - `employmentStatus`    — profile.employmentStatus.isNotEmpty
///   - `civilStatus`         — profile.etatCivil (always set; non-blocking)
///   - `avoirLpp`            — profile.prevoyance.avoirLppTotal != null
///   - `rachatMaximum`       — profile.prevoyance.rachatMaximum != null
///   - `epargne3a`           — profile.prevoyance.totalEpargne3a > 0
///   - `epargne`             — profile.patrimoine.epargneLiquide > 0
///   - `conjoint`            — profile.conjoint != null
///
/// ## Blocking heuristic
///
/// Fields in [_criticalFields] are always blocking; others produce [partial].
/// The per-screen blocking logic will be refined in S57.
class ReadinessGate {
  const ReadinessGate();

  /// Static entry point — evaluate readiness for [entry] against [profile].
  ///
  /// Equivalent to `const ReadinessGate().evaluate(entry, profile)`.
  static ReadinessResult check(ScreenEntry entry, CoachProfile profile) =>
      const ReadinessGate().evaluate(entry, profile);

  /// Evaluate readiness for [entry] against [profile].
  ///
  /// If [entry.customGate] is set, it takes full control of the result.
  /// Otherwise the generic field-checking heuristic runs.
  ReadinessResult evaluate(ScreenEntry entry, CoachProfile profile) {
    // Custom gate — surface-specific logic overrides generic heuristic.
    if (entry.customGate != null) {
      return entry.customGate!(profile);
    }

    if (entry.requiredFields.isEmpty) return const ReadinessResult.ready();

    final missing = <String>[];
    for (final field in entry.requiredFields) {
      if (!_isPresent(field, profile)) {
        missing.add(field);
      }
    }

    if (missing.isEmpty) return const ReadinessResult.ready();

    final critical = missing.where((f) => _isCritical(f)).toList();
    if (critical.isNotEmpty) {
      return ReadinessResult.blocked(missing, critical);
    }
    return ReadinessResult.partial(missing);
  }

  // ── Field presence check ────────────────────────────────────────

  bool _isPresent(String fieldKey, CoachProfile profile) {
    final value = _resolveField(fieldKey, profile);
    if (value == null) return false;
    if (value is String) return value.isNotEmpty;
    if (value is double) return value > 0;
    if (value is int) return value > 0;
    if (value is List) return value.isNotEmpty;
    return true; // non-null, non-empty object is present
  }

  /// Resolves a named field key from [CoachProfile].
  ///
  /// Returns null for unknown keys — treated as missing (safe default).
  dynamic _resolveField(String key, CoachProfile profile) {
    switch (key) {
      // Identity
      case 'age':
        return profile.age > 0 ? profile.age : null;
      case 'canton':
        return profile.canton.isNotEmpty ? profile.canton : null;
      case 'nationality':
        return profile.nationality;
      case 'employmentStatus':
        return profile.employmentStatus.isNotEmpty
            ? profile.employmentStatus
            : null;
      case 'civilStatus':
        // etatCivil always has a value (default: celibataire)
        return profile.etatCivil.name;
      case 'residencePermit':
        return profile.residencePermit;

      // Income
      case 'salaireBrut':
      case 'salaireBrutMensuel':
        return profile.salaireBrutMensuel > 0
            ? profile.salaireBrutMensuel
            : null;
      case 'netIncome':
        // Derived: net income is available when gross salary is set
        return profile.salaireBrutMensuel > 0
            ? profile.salaireBrutMensuel
            : null;

      // Prevoyance
      case 'avoirLpp':
        return profile.prevoyance.avoirLppTotal;
      case 'rachatMaximum':
        return profile.prevoyance.rachatMaximum;
      case 'epargne3a':
        return profile.prevoyance.totalEpargne3a > 0
            ? profile.prevoyance.totalEpargne3a
            : null;

      // Patrimoine
      case 'epargne':
        return profile.patrimoine.epargneLiquide > 0
            ? profile.patrimoine.epargneLiquide
            : null;

      // Household
      case 'conjoint':
        return profile.conjoint;

      // Depenses
      case 'totalCharges':
      case 'totalMensuel':
        return profile.depenses.totalMensuel > 0
            ? profile.depenses.totalMensuel
            : null;
      case 'loyer':
        return profile.depenses.loyer > 0 ? profile.depenses.loyer : null;

      // Other profile fields (non-blocking extras)
      case 'riskTolerance':
        return profile.riskTolerance;
      case 'housingStatus':
        return profile.housingStatus;
      case 'nombreEnfants':
        return profile.nombreEnfants > 0 ? profile.nombreEnfants : null;

      default:
        // Unknown key — treat as missing (safe default)
        return null;
    }
  }

  // ── Blocking heuristic ──────────────────────────────────────────

  /// Fields that are always critical: without them the screen has no content.
  ///
  /// Salary (or derived net income) and age are the foundational inputs for
  /// every financial calculation in MINT. Canton is required for tax logic.
  static const _criticalFields = {
    'salaireBrut',
    'salaireBrutMensuel',
    'netIncome',
    'age',
    'canton',
  };

  bool _isCritical(String field) => _criticalFields.contains(field);
}
