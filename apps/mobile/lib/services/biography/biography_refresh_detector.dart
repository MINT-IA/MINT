import 'package:mint_mobile/services/biography/biography_fact.dart';
import 'package:mint_mobile/services/biography/freshness_decay_service.dart';

// ────────────────────────────────────────────────────────────
//  BIOGRAPHY REFRESH DETECTOR — Phase 03 / Memoire Narrative
// ────────────────────────────────────────────────────────────
//
// Detects stale biography facts and generates French-language
// refresh nudge text for coach injection.
//
// When a fact's freshness weight drops below 0.60 (BIO-08),
// a refresh nudge is generated suggesting the user re-scan
// or re-enter the relevant document/data.
//
// See: BIO-08 requirement.
// ────────────────────────────────────────────────────────────

/// A stale field detected by the refresh detector.
class StaleField {
  /// The type of fact that is stale.
  final FactType factType;

  /// The field path mapping (e.g., 'prevoyance.avoirLppTotal').
  final String? fieldPath;

  /// How many months old the data is (approximate).
  final int monthsOld;

  /// Suggested user action to refresh this data.
  final String suggestedAction;

  const StaleField({
    required this.factType,
    this.fieldPath,
    required this.monthsOld,
    required this.suggestedAction,
  });
}

/// Detects stale biography facts and generates refresh nudges.
///
/// All methods are static pure functions for testability.
class BiographyRefreshDetector {
  BiographyRefreshDetector._();

  /// Detect stale fields from a list of biography facts.
  ///
  /// Returns [StaleField] entries for facts where
  /// [FreshnessDecayService.needsRefresh] returns true.
  /// Results are sorted by staleness (most stale first).
  static List<StaleField> detectStaleFields(
    List<BiographyFact> facts, {
    DateTime? now,
  }) {
    final effectiveNow = now ?? DateTime.now();

    final staleFields = <StaleField>[];
    for (final fact in facts) {
      if (fact.isDeleted) continue;
      if (!FreshnessDecayService.needsRefresh(fact, effectiveNow)) continue;

      final monthsOld =
          (effectiveNow.difference(fact.updatedAt).inDays / 30.44).round();

      staleFields.add(StaleField(
        factType: fact.factType,
        fieldPath: fact.fieldPath,
        monthsOld: monthsOld,
        suggestedAction: _suggestedAction(fact.factType),
      ));
    }

    // Sort by most stale first
    staleFields.sort((a, b) => b.monthsOld.compareTo(a.monthsOld));

    return staleFields;
  }

  /// Build a French-language refresh nudge text for coach injection.
  ///
  /// Lists up to 3 stale fields (most stale first) with suggested
  /// actions. Returns empty string if no stale fields.
  static String buildRefreshNudge(List<StaleField> staleFields) {
    if (staleFields.isEmpty) return '';

    final lines = <String>['DONNEES A ACTUALISER\u00a0:'];

    for (final field in staleFields.take(3)) {
      final label = _factTypeLabel(field.factType);
      lines.add(
        '- $label\u00a0: donnees de ${field.monthsOld} mois. '
        'Suggestion\u00a0: ${field.suggestedAction}',
      );
    }

    return lines.join('\n');
  }

  /// Get a suggested refresh action for a given fact type.
  static String _suggestedAction(FactType type) {
    switch (type) {
      case FactType.salary:
        return 'Rescanner ta fiche de salaire';
      case FactType.lppCapital:
        return 'Rescanner ton certificat LPP';
      case FactType.lppRachatMax:
        return 'Verifier ton potentiel de rachat LPP';
      case FactType.threeACapital:
        return 'Mettre a jour ton solde 3a';
      case FactType.avsContributionYears:
        return 'Commander un extrait de compte AVS';
      case FactType.taxRate:
        return 'Verifier avec ta derniere declaration fiscale';
      case FactType.mortgageDebt:
        return 'Verifier ton solde hypothecaire actuel';
      case FactType.canton:
        return 'Confirmer ton canton de residence';
      case FactType.civilStatus:
        return 'Mettre a jour ton etat civil';
      case FactType.employmentStatus:
        return 'Confirmer ta situation professionnelle';
      case FactType.lifeEvent:
        return 'Verifier si cet evenement est toujours pertinent';
      case FactType.userDecision:
      case FactType.coachPreference:
        return 'Reconfirmer cette preference';
    }
  }

  /// Human-readable French label for a fact type.
  static String _factTypeLabel(FactType type) {
    switch (type) {
      case FactType.salary:
        return 'Salaire';
      case FactType.lppCapital:
        return 'Capital LPP';
      case FactType.lppRachatMax:
        return 'Rachat max LPP';
      case FactType.threeACapital:
        return 'Capital 3a';
      case FactType.avsContributionYears:
        return 'Annees AVS';
      case FactType.taxRate:
        return 'Taux fiscal';
      case FactType.mortgageDebt:
        return 'Dette hypothecaire';
      case FactType.canton:
        return 'Canton';
      case FactType.civilStatus:
        return 'Etat civil';
      case FactType.employmentStatus:
        return 'Statut professionnel';
      case FactType.lifeEvent:
        return 'Evenement de vie';
      case FactType.userDecision:
        return 'Decision utilisateur';
      case FactType.coachPreference:
        return 'Preference coach';
    }
  }
}
