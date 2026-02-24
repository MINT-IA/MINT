/// Data models for arbitrage comparisons (rente vs capital, allocation annuelle).
///
/// Sprint S32 — Arbitrage Phase 1.
/// These models hold year-by-year trajectories and comparison results.
/// Used by ArbitrageEngine and displayed by arbitrage screens.
library;

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

/// Full result of an arbitrage comparison.
class ArbitrageResult {
  /// Available options (2-4 trajectories).
  final List<TrajectoireOption> options;

  /// Year when trajectories cross (null if they never cross within horizon).
  final int? breakevenYear;

  /// One impactful number with context.
  final String chiffreChoc;

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

  const ArbitrageResult({
    required this.options,
    required this.breakevenYear,
    required this.chiffreChoc,
    required this.displaySummary,
    required this.hypotheses,
    required this.disclaimer,
    required this.sources,
    required this.confidenceScore,
    required this.sensitivity,
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
  List<ArbitrageTornadoVariable> get tornadoVariables =>
      parseArbitrageTornado(sensitivity);
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

List<ArbitrageTornadoVariable> parseArbitrageTornado(Map<String, double> input) {
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

  for (final entry in grouped.entries) {
    final key = entry.key;
    final values = entry.value;
    final base = values['base'];
    final low = values['low'];
    final high = values['high'];
    if (base == null || low == null || high == null) continue;

    final meta = _tornadoMetadata[key] ??
        const _TornadoMeta(label: 'Variable', category: 'strategy');

    final lowAssumption = values['assumption_low'];
    final highAssumption = values['assumption_high'];
    final lowLabel = lowAssumption != null
        ? (meta.assumptionFormatter?.call(lowAssumption) ?? 'Bas')
        : 'Bas';
    final highLabel = highAssumption != null
        ? (meta.assumptionFormatter?.call(highAssumption) ?? 'Haut')
        : 'Haut';

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
String _formatChf(double value) {
  final intVal = value.round().abs();
  final str = intVal.toString();
  final buffer = StringBuffer();
  for (int i = 0; i < str.length; i++) {
    if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
    buffer.write(str[i]);
  }
  return 'CHF ${value < 0 ? '-' : ''}${buffer.toString()}';
}

const Map<String, _TornadoMeta> _tornadoMetadata = {
  'rendement_capital': _TornadoMeta(
    label: 'Rendement du capital',
    category: 'libre',
    assumptionFormatter: _formatPercent,
  ),
  'taux_retrait': _TornadoMeta(
    label: 'Taux de retrait (SWR)',
    category: 'strategy',
    assumptionFormatter: _formatPercent,
  ),
  'taux_conversion_obligatoire': _TornadoMeta(
    label: 'Conversion LPP obligatoire',
    category: 'lpp',
    assumptionFormatter: _formatPercent,
  ),
  'taux_conversion_surobligatoire': _TornadoMeta(
    label: 'Conversion LPP suroblig.',
    category: 'lpp',
    assumptionFormatter: _formatPercent,
  ),
  'rendement_marche': _TornadoMeta(
    label: 'Rendement marche',
    category: 'libre',
    assumptionFormatter: _formatPercent,
  ),
  'taux_marginal': _TornadoMeta(
    label: 'Taux marginal',
    category: 'strategy',
    assumptionFormatter: _formatPercent,
  ),
  'rendement_3a': _TornadoMeta(
    label: 'Rendement 3a',
    category: '3a',
    assumptionFormatter: _formatPercent,
  ),
  'rendement_lpp': _TornadoMeta(
    label: 'Rendement LPP',
    category: 'lpp',
    assumptionFormatter: _formatPercent,
  ),
  'taux_hypothecaire': _TornadoMeta(
    label: 'Taux hypothecaire',
    category: 'depenses',
    assumptionFormatter: _formatPercent,
  ),
  'appreciation_immo': _TornadoMeta(
    label: 'Appreciation immo',
    category: 'strategy',
    assumptionFormatter: _formatPercent,
  ),
  'loyer_mensuel': _TornadoMeta(
    label: 'Loyer mensuel',
    category: 'depenses',
    assumptionFormatter: _formatChf,
  ),
  'taux_impot_capital': _TornadoMeta(
    label: 'Taux impot capital',
    category: 'strategy',
    assumptionFormatter: _formatPercent,
  ),
  'age_retraite': _TornadoMeta(
    label: 'Age de retraite',
    category: 'strategy',
    assumptionFormatter: _formatAge,
  ),
  'capital_total': _TornadoMeta(
    label: 'Capital total',
    category: 'strategy',
    assumptionFormatter: _formatChf,
  ),
  'annees_avant_retraite': _TornadoMeta(
    label: 'Annees avant retraite',
    category: 'strategy',
    assumptionFormatter: _formatAge,
  ),
};
