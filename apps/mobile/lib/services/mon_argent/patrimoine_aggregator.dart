import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/data_spine_snapshot.dart';

/// Aggregated patrimoine snapshot with source tracking.
///
/// Each field records the value and its data source so the UI can
/// display timestamps and confidence levels per field.
class PatrimoineField {
  final double value;
  final String source; // 'userInput', 'certificate', 'estimated'
  final DateTime? lastUpdated;

  const PatrimoineField({
    required this.value,
    required this.source,
    this.lastUpdated,
  });
}

class PatrimoineSummary {
  final PatrimoineField? lpp;
  final PatrimoineField? pillar3a;
  final PatrimoineField? epargneLiquide;
  final PatrimoineField? investissements;
  final PatrimoineField? dettes;

  const PatrimoineSummary({
    this.lpp,
    this.pillar3a,
    this.epargneLiquide,
    this.investissements,
    this.dettes,
  });

  double get totalActifs =>
      (lpp?.value ?? 0) +
      (pillar3a?.value ?? 0) +
      (epargneLiquide?.value ?? 0) +
      (investissements?.value ?? 0);

  double get totalDettes => dettes?.value ?? 0;

  double get net => totalActifs - totalDettes;

  bool get isEmpty =>
      lpp == null &&
      pillar3a == null &&
      epargneLiquide == null &&
      investissements == null &&
      dettes == null;

  bool get isPartial =>
      !isEmpty &&
      (lpp == null ||
          pillar3a == null ||
          epargneLiquide == null ||
          investissements == null);

  /// Ratio of known fields (0.0 to 1.0) for the pulse circle.
  double get completionRatio {
    int known = 0;
    int total = 4; // lpp, 3a, epargne, investissements
    if (lpp != null) known++;
    if (pillar3a != null) known++;
    if (epargneLiquide != null) known++;
    if (investissements != null) known++;
    return known / total;
  }

  /// Most recent update date across all fields.
  DateTime? get lastUpdated {
    final dates = [
      lpp?.lastUpdated,
      pillar3a?.lastUpdated,
      epargneLiquide?.lastUpdated,
      investissements?.lastUpdated,
      dettes?.lastUpdated,
    ].whereType<DateTime>();
    if (dates.isEmpty) return null;
    return dates.reduce((a, b) => a.isAfter(b) ? a : b);
  }

  /// Human-readable source of the most recent update.
  String? get lastUpdateSource {
    final latest = lastUpdated;
    if (latest == null) return null;
    for (final field in [
      lpp,
      pillar3a,
      epargneLiquide,
      investissements,
      dettes,
    ]) {
      if (field?.lastUpdated == latest) return field?.source;
    }
    return null;
  }
}

/// Pure service that aggregates patrimoine from CoachProfile.
///
/// Confidence hierarchy (aligned with confidence_scorer.dart):
///   certificate (0.95) > crossValidated (0.70) > userInput (0.60) > estimated (0.25)
///
/// When two sources exist for the same field, the higher-confidence source wins.
/// This service does NOT manage acquisition — it only reads and assembles.
class PatrimoineAggregator {
  const PatrimoineAggregator._();

  /// Compute a PatrimoineSummary from the current CoachProfile.
  ///
  /// Returns a summary with available fields. Missing fields are null.
  static PatrimoineSummary compute(CoachProfile? profile) {
    if (profile == null) return const PatrimoineSummary();

    final prevoyance = profile.prevoyance;
    final patrimoine = profile.patrimoine;
    final dettes = profile.dettes;

    // LPP: certificate data (avoirLppObligatoire present) wins over total
    final lppSource =
        prevoyance.avoirLppObligatoire != null ? 'certificate' : 'userInput';

    return PatrimoineSummary(
      lpp: _fieldOrNull(prevoyance.avoirLppTotal, lppSource),
      pillar3a: prevoyance.totalEpargne3a > 0
          ? PatrimoineField(
              value: prevoyance.totalEpargne3a,
              source: 'userInput',
            )
          : null,
      epargneLiquide: patrimoine.epargneLiquide > 0
          ? PatrimoineField(
              value: patrimoine.epargneLiquide,
              source: 'userInput',
            )
          : null,
      investissements: patrimoine.investissements > 0
          ? PatrimoineField(
              value: patrimoine.investissements,
              source: 'userInput',
            )
          : null,
      dettes: dettes.totalDettes > 0
          ? PatrimoineField(
              value: dettes.totalDettes,
              source: 'userInput',
            )
          : null,
    );
  }

  /// Compute a PatrimoineSummary from the unified data spine read model.
  static PatrimoineSummary computeFromDataSpine(DataSpineSnapshot? spine) {
    if (spine == null) return const PatrimoineSummary();

    return PatrimoineSummary(
      lpp: _pillarFieldOrNull(spine.pillars.lpp.totalBalance),
      pillar3a: _pillarFieldOrNull(spine.pillars.pillar3a.totalBalance),
      epargneLiquide: _spineFieldOrNull(spine.situation.liquidSavings),
      investissements: _spineFieldOrNull(spine.situation.investments),
      dettes: _spineFieldOrNull(spine.situation.totalDebt),
    );
  }

  static PatrimoineField? _fieldOrNull(double? value, String source) {
    if (value == null || value <= 0) return null;
    return PatrimoineField(value: value, source: source);
  }

  static PatrimoineField? _pillarFieldOrNull(PillarFact<double> fact) {
    final value = fact.value;
    if (value == null || value <= 0 || fact.state == PillarFactState.missing) {
      return null;
    }
    return PatrimoineField(
      value: value,
      source: _sourceName(fact.meta.source),
      lastUpdated: fact.meta.updatedAt,
    );
  }

  static PatrimoineField? _spineFieldOrNull(SpineValue<double> field) {
    final value = field.value;
    if (value == null || value <= 0) return null;
    return PatrimoineField(
      value: value,
      source: _sourceName(field.meta.source),
      lastUpdated: field.meta.updatedAt,
    );
  }

  static String _sourceName(ProfileDataSource? source) {
    return switch (source) {
      ProfileDataSource.certificate => 'certificate',
      ProfileDataSource.openBanking => 'openBanking',
      ProfileDataSource.crossValidated => 'crossValidated',
      ProfileDataSource.userInput => 'userInput',
      ProfileDataSource.estimated => 'estimated',
      null => 'dataSpine',
    };
  }
}
