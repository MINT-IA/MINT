/// Data models for arbitrage comparisons (rente vs capital, allocation annuelle).
///
/// Sprint S32 — Arbitrage Phase 1.
/// These models hold year-by-year trajectories and comparison results.
/// Used by ArbitrageEngine and displayed by arbitrage screens.
library;

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/generated/regulatory_constants.g.dart';
import 'package:mint_mobile/utils/chf_formatter.dart' as chf;

/// A single year snapshot in a trajectory projection.
class YearlySnapshot {
  final int year;
  final double netPatrimony;
  final double annualCashflow;
  final double cumulativeTaxDelta;

  const YearlySnapshot({
    required this.year,
    required this.netPatrimony,
    required this.annualCashflow,
    required this.cumulativeTaxDelta,
  });
}

/// One option (trajectory) in an arbitrage comparison.
class TrajectoireOption {
  /// Unique ID: "full_rente", "full_capital", "mixed", "3a", "rachat_lpp",
  /// "amort_indirect", "invest_libre".
  final String id;

  /// User-facing label (French).
  final String label;

  /// Year-by-year trajectory snapshots.
  final List<YearlySnapshot> trajectory;

  /// Net patrimony at end of horizon.
  final double terminalValue;

  /// Cumulative tax impact over the horizon.
  final double cumulativeTaxImpact;

  const TrajectoireOption({
    required this.id,
    required this.label,
    required this.trajectory,
    required this.terminalValue,
    required this.cumulativeTaxImpact,
  });
}

/// A retirement asset for withdrawal calendar optimization.
///
/// Sprint S33 — Arbitrage Phase 2.
/// Represents a single LPP, 3a, or libre passage account to be withdrawn.
class RetirementAsset {
  /// Type identifier: "3a", "lpp", "libre_passage".
  final String type;

  /// Amount in CHF.
  final double amount;

  /// Earliest age at which this asset can be withdrawn.
  final int earliestWithdrawalAge;

  const RetirementAsset({
    required this.type,
    required this.amount,
    required this.earliestWithdrawalAge,
  });
}

/// Calculation receipt required before visible RvC figures can be rendered.
class ArbitrageCalculationReceipt {
  static const _requiredRvcAssumptionKeys = <String>{
    'safe_withdrawal_rate',
    'expected_return',
    'inflation',
    'horizon_years',
    'canton',
    'conversion_rate_obligatory',
    'conversion_rate_surobligatory',
    'current_age',
  };

  final String calculationOrigin;
  final String calculationVersion;
  final String constantsVersionHash;
  final String unit;
  final Map<String, Object?> assumptions;
  final List<String> sources;
  final String readiness;
  final double confidenceScore;
  final List<String> missingRequiredInputs;
  final bool hasMissingRequiredInputsMetadata;

  const ArbitrageCalculationReceipt({
    required this.calculationOrigin,
    required this.calculationVersion,
    required this.constantsVersionHash,
    required this.unit,
    required this.assumptions,
    required this.sources,
    required this.readiness,
    required this.confidenceScore,
    required this.missingRequiredInputs,
    this.hasMissingRequiredInputsMetadata = true,
  });

  /// Fail-closed: stale constants or omitted backend metadata hide RvC figures.
  bool get isComplete =>
      calculationOrigin.isNotEmpty &&
      calculationVersion.isNotEmpty &&
      constantsVersionHash == regulatoryConstantsVersionHash &&
      unit.isNotEmpty &&
      unit.contains('CHF/mois') &&
      _hasRequiredRvcAssumptions &&
      _containsSource('LPP art. 14') &&
      _containsSource('LIFD art. 22') &&
      _containsSource('LIFD art. 38') &&
      readiness == 'ready' &&
      confidenceScore.isFinite &&
      confidenceScore >= 0 &&
      confidenceScore <= 100 &&
      hasMissingRequiredInputsMetadata &&
      missingRequiredInputs.isEmpty;

  bool get _hasRequiredRvcAssumptions {
    if (!assumptions.keys.toSet().containsAll(_requiredRvcAssumptionKeys)) {
      return false;
    }

    for (final key in _requiredRvcAssumptionKeys) {
      final value = assumptions[key];
      if (key == 'canton') {
        if (value is! String || value.trim().isEmpty) return false;
        continue;
      }
      if (value is! num || !value.isFinite) return false;
      if (!_isRvcAssumptionInDomain(key, value.toDouble())) return false;
    }

    return true;
  }

  static bool _isRvcAssumptionInDomain(String key, double value) {
    return switch (key) {
      'safe_withdrawal_rate' => value > 0 && value <= 1,
      'expected_return' || 'inflation' => value > -1 && value <= 1,
      'horizon_years' => value > 0,
      'conversion_rate_obligatory' => value > 0 && value <= 1,
      'conversion_rate_surobligatory' => value >= 0 && value <= 1,
      'current_age' => value > 0 && value < 120,
      _ => true,
    };
  }

  static ArbitrageCalculationReceipt? fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return null;
    final assumptions = data['assumptions'];
    final sources = data['sources'];
    final missingInputs =
        data['missingRequiredInputs'] ?? data['missing_required_inputs'];
    final hasMissingRequiredInputsMetadata = missingInputs is List;

    return ArbitrageCalculationReceipt(
      calculationOrigin:
          _readString(data, const ['calculationOrigin', 'calculation_origin']),
      calculationVersion: _readString(
        data,
        const ['calculationVersion', 'calculation_version'],
      ),
      constantsVersionHash: _readString(
        data,
        const [
          'constantsVersionHash',
          'constantVersion',
          'constant_version',
          'constants_version_hash',
          'regulatoryConstantsVersionHash',
          'regulatory_constants_version_hash',
        ],
      ),
      unit: _readString(data, const ['unit']),
      assumptions: assumptions is Map
          ? Map<String, Object?>.from(assumptions)
          : const <String, Object?>{},
      sources:
          sources is List ? sources.whereType<String>().toList() : const [],
      readiness: _readString(data, const ['readiness']),
      confidenceScore: _readDouble(
        data,
        const ['confidenceScore', 'confidence_score', 'confidence'],
      ),
      missingRequiredInputs: missingInputs is List
          ? missingInputs.whereType<String>().toList()
          : const [],
      hasMissingRequiredInputsMetadata: hasMissingRequiredInputsMetadata,
    );
  }

  bool _containsSource(String expected) {
    return sources.any((source) => source.contains(expected));
  }

  static String _readString(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String) return value;
    }
    return '';
  }

  static double _readDouble(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
    }
    return double.nan;
  }
}

/// Full result of an arbitrage comparison.
class ArbitrageResult {
  /// Available options (2-4 trajectories).
  final List<TrajectoireOption> options;

  /// Year when trajectories cross (null if they never cross within horizon).
  final int? breakevenYear;

  /// One impactful number with context.
  final String premierEclairage;

  /// Summary text for display.
  final String displaySummary;

  /// List of assumptions used in the simulation.
  final List<String> hypotheses;

  /// Legal disclaimer (always present).
  final String disclaimer;

  /// Legal source references.
  final List<String> sources;

  /// Confidence score (0-100).
  final double confidenceScore;

  /// Sensitivity analysis: key → delta value.
  final Map<String, double> sensitivity;

  // ── Hero + educational card data (rente vs capital only) ──

  /// Net monthly rente after income tax (year 1 nominal).
  final double renteNetMensuelle;

  /// Monthly capital withdrawal (year 1, SWR-based).
  final double capitalRetraitMensuel;

  /// Age at which capital is exhausted (null if never on horizon).
  final int? capitalEpuiseAge;

  /// Cumulative income taxes paid on rente over the full horizon.
  final double impotCumulRente;

  /// One-time capital withdrawal tax (LIFD art. 38).
  final double impotRetraitCapital;

  /// Real purchasing power of rente at year 20 (annual, deflated).
  final double renteReelleAn20;

  /// 60% survivor rente for spouse (LPP art. 19), annual. 0 if unmarried.
  final double renteSurvivant;

  /// Projected capital at retirement (if projection was used).
  final double capitalProjecte;

  /// True if capital was projected from current age (vs direct certificate).
  final bool isProjected;

  /// Protection-first alertes: structural traps surfaced to the user above
  /// the trade-off (e.g. rachat + EPL within 3 years → tax deduction
  /// reversal per ATF 142 II 399 / 148 II 189). Empty by default; when
  /// populated, UI MUST render before any projection figure.
  final List<String> alertes;

  /// Receipt proving where the visible financial figures came from.
  final ArbitrageCalculationReceipt? calculationReceipt;

  const ArbitrageResult({
    required this.options,
    required this.breakevenYear,
    required this.premierEclairage,
    required this.displaySummary,
    required this.hypotheses,
    required this.disclaimer,
    required this.sources,
    required this.confidenceScore,
    required this.sensitivity,
    this.renteNetMensuelle = 0,
    this.capitalRetraitMensuel = 0,
    this.capitalEpuiseAge,
    this.impotCumulRente = 0,
    this.impotRetraitCapital = 0,
    this.renteReelleAn20 = 0,
    this.renteSurvivant = 0,
    this.capitalProjecte = 0,
    this.isProjected = false,
    this.alertes = const [],
    this.calculationReceipt,
  });
}

/// A normalized Tornado variable parsed from `ArbitrageResult.sensitivity`.
class ArbitrageTornadoVariable {
  final String key;
  final String label;
  final String category;
  final double baseValue;
  final double lowValue;
  final double highValue;
  final double swing;
  final String lowLabel;
  final String highLabel;

  const ArbitrageTornadoVariable({
    required this.key,
    required this.label,
    required this.category,
    required this.baseValue,
    required this.lowValue,
    required this.highValue,
    required this.swing,
    required this.lowLabel,
    required this.highLabel,
  });
}

extension ArbitrageTornadoParsing on ArbitrageResult {
  /// Returns tornado variables with French fallback labels.
  /// For localized labels, call [parseArbitrageTornado] directly with [S].
  List<ArbitrageTornadoVariable> get tornadoVariables =>
      parseArbitrageTornado(sensitivity);

  /// Returns tornado variables with localized labels.
  List<ArbitrageTornadoVariable> tornadoVariablesLocalized(S? l) =>
      parseArbitrageTornado(sensitivity, l: l);
}

class _TornadoMeta {
  final String label;
  final String category;
  final String Function(double)? assumptionFormatter;

  const _TornadoMeta({
    required this.label,
    required this.category,
    this.assumptionFormatter,
  });
}

/// Parse tornado variables from sensitivity map.
/// [l] — optional localizations; when null, French fallbacks are used.
List<ArbitrageTornadoVariable> parseArbitrageTornado(Map<String, double> input,
    {S? l}) {
  final grouped = <String, Map<String, double>>{};

  for (final entry in input.entries) {
    if (!entry.key.startsWith('tornado_')) continue;
    final raw = entry.key.substring('tornado_'.length);
    final metric = _metricSuffix(raw);
    if (metric == null) continue;
    final variableKey = raw.substring(0, raw.length - metric.length - 1);
    grouped.putIfAbsent(variableKey, () => <String, double>{})[metric] =
        entry.value;
  }

  final result = <ArbitrageTornadoVariable>[];
  final metadata = _buildTornadoMetadata(l);
  final defaultLow = l?.tornadoLabelBas ?? 'Bas';
  final defaultHigh = l?.tornadoLabelHaut ?? 'Haut';

  for (final entry in grouped.entries) {
    final key = entry.key;
    final values = entry.value;
    final base = values['base'];
    final low = values['low'];
    final high = values['high'];
    if (base == null || low == null || high == null) continue;

    final meta = metadata[key] ??
        const _TornadoMeta(label: 'Variable', category: 'strategy');

    final lowAssumption = values['assumption_low'];
    final highAssumption = values['assumption_high'];
    final lowLabel = lowAssumption != null
        ? (meta.assumptionFormatter?.call(lowAssumption) ?? defaultLow)
        : defaultLow;
    final highLabel = highAssumption != null
        ? (meta.assumptionFormatter?.call(highAssumption) ?? defaultHigh)
        : defaultHigh;

    result.add(ArbitrageTornadoVariable(
      key: key,
      label: meta.label,
      category: meta.category,
      baseValue: base,
      lowValue: low,
      highValue: high,
      swing: values['swing'] ?? (high - low).abs(),
      lowLabel: lowLabel,
      highLabel: highLabel,
    ));
  }

  result.sort((a, b) => b.swing.compareTo(a.swing));
  return result;
}

String? _metricSuffix(String raw) {
  const metrics = <String>[
    'assumption_low',
    'assumption_high',
    'base',
    'low',
    'high',
    'swing',
  ];
  for (final metric in metrics) {
    if (raw.endsWith('_$metric')) return metric;
  }
  return null;
}

String _formatPercent(double value) => '${(value * 100).toStringAsFixed(1)}%';
String _formatAge(double value) => '${value.round()} ans';
String _formatChf(double value) => chf.formatChfWithPrefix(value);

/// Build tornado metadata map with optional localized labels.
/// [l] — when null, French fallback labels are used.
Map<String, _TornadoMeta> _buildTornadoMetadata(S? l) => {
      'rendement_capital': _TornadoMeta(
        label: l?.tornadoLabelRendementCapital ?? 'Ce que ton capital rapporte',
        category: 'libre',
        assumptionFormatter: _formatPercent,
      ),
      'taux_retrait': _TornadoMeta(
        label: l?.tornadoLabelTauxRetrait ?? 'Retrait annuel du capital',
        category: 'strategy',
        assumptionFormatter: _formatPercent,
      ),
      'taux_conversion_obligatoire': _TornadoMeta(
        label: l?.tornadoLabelConversionOblig ?? 'Conversion LPP obligatoire',
        category: 'lpp',
        assumptionFormatter: _formatPercent,
      ),
      'taux_conversion_surobligatoire': _TornadoMeta(
        label: l?.tornadoLabelConversionSurob ?? 'Conversion LPP suroblig.',
        category: 'lpp',
        assumptionFormatter: _formatPercent,
      ),
      'rendement_marche': _TornadoMeta(
        label: l?.tornadoLabelRendementMarche ?? 'Rendement de tes placements',
        category: 'libre',
        assumptionFormatter: _formatPercent,
      ),
      'taux_marginal': _TornadoMeta(
        label: l?.tornadoLabelTauxMarginal ?? 'Ton taux d\'imposition',
        category: 'strategy',
        assumptionFormatter: _formatPercent,
      ),
      'rendement_3a': _TornadoMeta(
        label: l?.tornadoLabelRendement3a ?? 'Rendement de ton 3e pilier',
        category: '3a',
        assumptionFormatter: _formatPercent,
      ),
      'rendement_lpp': _TornadoMeta(
        label: l?.tornadoLabelRendementLpp ?? 'Rendement de ta caisse LPP',
        category: 'lpp',
        assumptionFormatter: _formatPercent,
      ),
      'taux_hypothecaire': _TornadoMeta(
        label: l?.tornadoLabelTauxHypothecaire ?? 'Taux hypothécaire',
        category: 'depenses',
        assumptionFormatter: _formatPercent,
      ),
      'appreciation_immo': _TornadoMeta(
        label: l?.tornadoLabelAppreciationImmo ?? 'Appréciation immo',
        category: 'strategy',
        assumptionFormatter: _formatPercent,
      ),
      'loyer_mensuel': _TornadoMeta(
        label: l?.tornadoLabelLoyerMensuel ?? 'Loyer mensuel',
        category: 'depenses',
        assumptionFormatter: _formatChf,
      ),
      'taux_impot_capital': _TornadoMeta(
        label: l?.tornadoLabelTauxImpotCapital ?? 'Taux impôt capital',
        category: 'strategy',
        assumptionFormatter: _formatPercent,
      ),
      'age_retraite': _TornadoMeta(
        label: l?.tornadoLabelAgeRetraite ?? 'Âge de retraite',
        category: 'strategy',
        assumptionFormatter: _formatAge,
      ),
      'capital_total': _TornadoMeta(
        label: l?.tornadoLabelCapitalTotal ?? 'Capital total',
        category: 'strategy',
        assumptionFormatter: _formatChf,
      ),
      'annees_avant_retraite': _TornadoMeta(
        label: l?.tornadoLabelAnneesAvantRetraite ?? 'Années avant retraite',
        category: 'strategy',
        assumptionFormatter: _formatAge,
      ),
    };
