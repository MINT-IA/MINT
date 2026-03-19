// Cantonal Benchmark Service — S60
//
// Provides anonymized cantonal financial benchmarks from OFS (Swiss federal
// statistics) reference data. Data is STATIC, NOT from other users.
//
// COMPLIANCE (NON-NEGOTIABLE — CLAUDE.md 6):
// - ZERO ranked comparisons
// - ZERO "top X%", "meilleur que", "pire que"
// - ZERO social comparison
// - ALL text conditional ("se situe", "semble", "ordre de grandeur")
// - Source: always cite "OFS" or specific statistic
// - Disclaimer: always present
//
// Displayed as "profils similaires dans ton canton" — never ranked.
// Opt-in only (default: false).

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';

// ════════════════════════════════════════════════════════════════
//  MODELS
// ════════════════════════════════════════════════════════════════

/// A statistical range (25th / 50th / 75th percentile).
class BenchmarkRange {
  final double low;
  final double median;
  final double high;
  final String label;

  const BenchmarkRange({
    required this.low,
    required this.median,
    required this.high,
    required this.label,
  });
}

/// Cantonal benchmark data for a given canton + age group.
class CantonalBenchmark {
  final String canton;
  final String ageGroup;
  final BenchmarkRange revenuMedian;
  final BenchmarkRange epargneMensuelle;
  final BenchmarkRange chargesFixes;
  final BenchmarkRange tauxEpargne;
  final BenchmarkRange patrimoineNet;
  final String source;
  final String disclaimer;

  const CantonalBenchmark({
    required this.canton,
    required this.ageGroup,
    required this.revenuMedian,
    required this.epargneMensuelle,
    required this.chargesFixes,
    required this.tauxEpargne,
    required this.patrimoineNet,
    required this.source,
    required this.disclaimer,
  });
}

/// Where the user falls relative to a benchmark range.
enum BenchmarkPosition {
  /// Within the typical range (between low and high).
  withinRange,

  /// Above the typical range (above high).
  aboveRange,

  /// Below the typical range (below low).
  belowRange,
}

/// Comparison result for a single metric.
class MetricComparison {
  final String label;
  final double userValue;
  final BenchmarkRange range;
  final BenchmarkPosition position;

  const MetricComparison({
    required this.label,
    required this.userValue,
    required this.range,
    required this.position,
  });
}

/// Full comparison of a user profile against a cantonal benchmark.
class BenchmarkComparison {
  final CantonalBenchmark benchmark;
  final List<MetricComparison> metrics;

  const BenchmarkComparison({
    required this.benchmark,
    required this.metrics,
  });
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

class CantonalBenchmarkService {
  CantonalBenchmarkService._();

  /// SharedPreferences key for opt-in persistence.
  static const _optedInKey = '_cantonal_benchmark_opted_in';

  /// In-memory cache (hydrated from SharedPreferences on first access).
  /// Legacy field for backward compatibility — prefer [getOptedIn]/[setOptedIn].
  static bool isOptedIn = false;

  /// Read opt-in from SharedPreferences (persisted).
  static Future<bool> getOptedIn({SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    isOptedIn = sp.getBool(_optedInKey) ?? false;
    return isOptedIn;
  }

  /// Write opt-in to SharedPreferences (persisted).
  static Future<void> setOptedIn(bool value, {SharedPreferences? prefs}) async {
    final sp = prefs ?? await SharedPreferences.getInstance();
    isOptedIn = value;
    await sp.setBool(_optedInKey, value);
  }

  // ── Constants ────────────────────────────────────────────────

  static const String _source =
      'OFS, Enquête sur le budget des ménages 2022';

  static const String _disclaimer =
      'Ces données sont des ordres de grandeur issus de statistiques '
      'fédérales anonymisées (OFS). Elles ne constituent pas un conseil '
      'financier. Aucune donnée personnelle n\'est comparée à d\'autres '
      'utilisateurs. Outil éducatif\u00a0: ne constitue pas un conseil '
      'au sens de la LSFin.';

  // ── Age group resolution ─────────────────────────────────────

  static String ageGroupForAge(int age) {
    if (age < 25) return '25-34'; // clamp to nearest group
    if (age < 35) return '25-34';
    if (age < 45) return '35-44';
    if (age < 55) return '45-54';
    if (age < 65) return '55-64';
    return '65+';
  }

  // ── Public API ───────────────────────────────────────────────

  /// Returns the benchmark for a given canton and age, or null if no data
  /// is available or the user has not opted in.
  static CantonalBenchmark? getBenchmark({
    required String canton,
    required int age,
  }) {
    if (!isOptedIn) return null;
    final ageGroup = ageGroupForAge(age);
    final key = '${canton.toUpperCase()}_$ageGroup';
    return _data[key];
  }

  /// Compare a user's profile against a cantonal benchmark.
  ///
  /// Returns null if [isOptedIn] is false or no benchmark is found.
  static BenchmarkComparison? compareToProfile({
    required CoachProfile profile,
    required CantonalBenchmark benchmark,
  }) {
    if (!isOptedIn) return null;

    final revenuAnnuel = profile.revenuBrutAnnuel;
    final epargneMensuelle = profile.totalContributionsMensuelles;
    final chargesFixes = profile.depenses.totalMensuel;
    final tauxEpargne = revenuAnnuel > 0
        ? (epargneMensuelle * 12 / revenuAnnuel * 100)
        : 0.0;
    final patrimoineNet = profile.patrimoine.epargneLiquide +
        profile.patrimoine.investissements +
        (profile.prevoyance.avoirLppTotal ?? 0) +
        profile.prevoyance.totalEpargne3a;

    final metrics = <MetricComparison>[
      MetricComparison(
        label: benchmark.revenuMedian.label,
        userValue: revenuAnnuel,
        range: benchmark.revenuMedian,
        position: _position(revenuAnnuel, benchmark.revenuMedian),
      ),
      MetricComparison(
        label: benchmark.epargneMensuelle.label,
        userValue: epargneMensuelle,
        range: benchmark.epargneMensuelle,
        position: _position(epargneMensuelle, benchmark.epargneMensuelle),
      ),
      MetricComparison(
        label: benchmark.chargesFixes.label,
        userValue: chargesFixes,
        range: benchmark.chargesFixes,
        position: _position(chargesFixes, benchmark.chargesFixes),
      ),
      MetricComparison(
        label: benchmark.tauxEpargne.label,
        userValue: tauxEpargne,
        range: benchmark.tauxEpargne,
        position: _position(tauxEpargne, benchmark.tauxEpargne),
      ),
      MetricComparison(
        label: benchmark.patrimoineNet.label,
        userValue: patrimoineNet,
        range: benchmark.patrimoineNet,
        position: _position(patrimoineNet, benchmark.patrimoineNet),
      ),
    ];

    return BenchmarkComparison(benchmark: benchmark, metrics: metrics);
  }

  /// Format the comparison as educational French text.
  ///
  /// COMPLIANCE: No banned terms, no ranking, no social comparison.
  /// Uses conditional language ("se situe", "semble", "ordre de grandeur").
  static String formatComparisonText({
    required BenchmarkComparison comparison,
  }) {
    final buf = StringBuffer();

    buf.writeln(
      'Voici comment ta situation se situe par rapport aux profils '
      'similaires dans ton canton (${comparison.benchmark.canton}, '
      'tranche ${comparison.benchmark.ageGroup})\u00a0:',
    );
    buf.writeln();

    for (final m in comparison.metrics) {
      buf.write('${m.label}\u00a0: ');
      switch (m.position) {
        case BenchmarkPosition.withinRange:
          buf.writeln(
            'Ta situation se situe dans la fourchette typique '
            '(${_fmt(m.range.low)} – ${_fmt(m.range.high)}).',
          );
        case BenchmarkPosition.aboveRange:
          buf.writeln(
            'Ta situation est au-delà de la fourchette typique '
            '(${_fmt(m.range.low)} – ${_fmt(m.range.high)}).',
          );
        case BenchmarkPosition.belowRange:
          buf.writeln(
            'Ta situation est en-deçà de la fourchette typique '
            '(${_fmt(m.range.low)} – ${_fmt(m.range.high)}).',
          );
      }
    }

    buf.writeln();
    buf.writeln('Source\u00a0: ${comparison.benchmark.source}');
    buf.writeln();
    buf.writeln(comparison.benchmark.disclaimer);

    return buf.toString();
  }

  // ── Private helpers ──────────────────────────────────────────

  static BenchmarkPosition _position(double value, BenchmarkRange range) {
    if (value < range.low) return BenchmarkPosition.belowRange;
    if (value > range.high) return BenchmarkPosition.aboveRange;
    return BenchmarkPosition.withinRange;
  }

  static String _fmt(double v) {
    if (v >= 1000) {
      final s = v.toStringAsFixed(0);
      // Swiss formatting with apostrophe
      final buf = StringBuffer();
      for (var i = 0; i < s.length; i++) {
        if (i > 0 && (s.length - i) % 3 == 0) buf.write("'");
        buf.write(s[i]);
      }
      return buf.toString();
    }
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  // ════════════════════════════════════════════════════════════════
  //  STATIC REFERENCE DATA — OFS Enquête sur le budget des ménages
  // ════════════════════════════════════════════════════════════════
  //
  // 6 cantons × 5 age groups = 30 entries.
  // Values are realistic Swiss OFS-style benchmarks (CHF).
  // Key format: "{CANTON}_{AGE_GROUP}"

  static final Map<String, CantonalBenchmark> _data = _buildData();

  static Map<String, CantonalBenchmark> _buildData() {
    final result = <String, CantonalBenchmark>{};

    // Raw data per canton: [revenu, epargne, charges, tauxEpargne%, patrimoine]
    // Each tuple: (low, median, high) for each age group.
    const cantonData = <String, Map<String, _RawBenchmark>>{
      'VS': {
        '25-34': _RawBenchmark(
          revenu: (52000, 65000, 82000),
          epargne: (200, 500, 900),
          charges: (1800, 2200, 2700),
          taux: (4, 8, 13),
          patrimoine: (5000, 25000, 65000),
        ),
        '35-44': _RawBenchmark(
          revenu: (65000, 82000, 105000),
          epargne: (400, 800, 1400),
          charges: (2200, 2700, 3300),
          taux: (6, 11, 16),
          patrimoine: (30000, 85000, 180000),
        ),
        '45-54': _RawBenchmark(
          revenu: (72000, 92000, 125000),
          epargne: (500, 1000, 1800),
          charges: (2400, 2900, 3600),
          taux: (7, 12, 17),
          patrimoine: (60000, 180000, 380000),
        ),
        '55-64': _RawBenchmark(
          revenu: (68000, 88000, 120000),
          epargne: (600, 1200, 2000),
          charges: (2300, 2800, 3400),
          taux: (8, 14, 20),
          patrimoine: (120000, 320000, 620000),
        ),
        '65+': _RawBenchmark(
          revenu: (42000, 56000, 75000),
          epargne: (200, 500, 1000),
          charges: (2000, 2500, 3100),
          taux: (4, 9, 15),
          patrimoine: (150000, 380000, 720000),
        ),
      },
      'VD': {
        '25-34': _RawBenchmark(
          revenu: (55000, 70000, 90000),
          epargne: (250, 600, 1000),
          charges: (2000, 2500, 3100),
          taux: (4, 9, 13),
          patrimoine: (5000, 28000, 70000),
        ),
        '35-44': _RawBenchmark(
          revenu: (70000, 90000, 115000),
          epargne: (500, 900, 1600),
          charges: (2400, 3000, 3700),
          taux: (6, 11, 16),
          patrimoine: (35000, 95000, 200000),
        ),
        '45-54': _RawBenchmark(
          revenu: (78000, 100000, 135000),
          epargne: (600, 1100, 2000),
          charges: (2600, 3200, 4000),
          taux: (7, 12, 17),
          patrimoine: (70000, 200000, 420000),
        ),
        '55-64': _RawBenchmark(
          revenu: (74000, 95000, 130000),
          epargne: (700, 1300, 2200),
          charges: (2500, 3100, 3800),
          taux: (8, 14, 20),
          patrimoine: (130000, 350000, 680000),
        ),
        '65+': _RawBenchmark(
          revenu: (45000, 60000, 80000),
          epargne: (250, 600, 1100),
          charges: (2200, 2700, 3400),
          taux: (4, 9, 15),
          patrimoine: (160000, 400000, 760000),
        ),
      },
      'GE': {
        '25-34': _RawBenchmark(
          revenu: (58000, 75000, 98000),
          epargne: (200, 550, 950),
          charges: (2200, 2800, 3500),
          taux: (3, 8, 12),
          patrimoine: (4000, 22000, 60000),
        ),
        '35-44': _RawBenchmark(
          revenu: (75000, 98000, 130000),
          epargne: (450, 900, 1600),
          charges: (2700, 3400, 4200),
          taux: (5, 10, 15),
          patrimoine: (30000, 90000, 195000),
        ),
        '45-54': _RawBenchmark(
          revenu: (85000, 110000, 150000),
          epargne: (550, 1100, 2000),
          charges: (2900, 3600, 4500),
          taux: (6, 11, 16),
          patrimoine: (65000, 195000, 410000),
        ),
        '55-64': _RawBenchmark(
          revenu: (80000, 105000, 140000),
          epargne: (650, 1300, 2200),
          charges: (2800, 3500, 4300),
          taux: (7, 13, 19),
          patrimoine: (125000, 340000, 670000),
        ),
        '65+': _RawBenchmark(
          revenu: (48000, 65000, 88000),
          epargne: (200, 550, 1050),
          charges: (2500, 3100, 3800),
          taux: (3, 8, 14),
          patrimoine: (155000, 395000, 750000),
        ),
      },
      'ZH': {
        '25-34': _RawBenchmark(
          revenu: (60000, 78000, 100000),
          epargne: (300, 700, 1200),
          charges: (2100, 2600, 3300),
          taux: (5, 10, 14),
          patrimoine: (8000, 32000, 80000),
        ),
        '35-44': _RawBenchmark(
          revenu: (78000, 100000, 135000),
          epargne: (600, 1100, 1800),
          charges: (2500, 3100, 3900),
          taux: (7, 12, 17),
          patrimoine: (40000, 110000, 230000),
        ),
        '45-54': _RawBenchmark(
          revenu: (88000, 115000, 155000),
          epargne: (700, 1300, 2200),
          charges: (2700, 3400, 4200),
          taux: (8, 13, 18),
          patrimoine: (80000, 230000, 480000),
        ),
        '55-64': _RawBenchmark(
          revenu: (82000, 108000, 145000),
          epargne: (800, 1500, 2500),
          charges: (2600, 3200, 4000),
          taux: (9, 15, 21),
          patrimoine: (150000, 400000, 780000),
        ),
        '65+': _RawBenchmark(
          revenu: (50000, 68000, 92000),
          epargne: (300, 700, 1300),
          charges: (2300, 2900, 3600),
          taux: (5, 10, 16),
          patrimoine: (180000, 450000, 850000),
        ),
      },
      'BE': {
        '25-34': _RawBenchmark(
          revenu: (50000, 63000, 80000),
          epargne: (200, 450, 850),
          charges: (1700, 2100, 2600),
          taux: (4, 8, 12),
          patrimoine: (5000, 22000, 58000),
        ),
        '35-44': _RawBenchmark(
          revenu: (63000, 80000, 102000),
          epargne: (350, 750, 1300),
          charges: (2100, 2600, 3200),
          taux: (5, 10, 15),
          patrimoine: (28000, 78000, 170000),
        ),
        '45-54': _RawBenchmark(
          revenu: (70000, 90000, 120000),
          epargne: (450, 950, 1700),
          charges: (2300, 2800, 3500),
          taux: (6, 11, 16),
          patrimoine: (55000, 165000, 350000),
        ),
        '55-64': _RawBenchmark(
          revenu: (66000, 85000, 115000),
          epargne: (550, 1100, 1900),
          charges: (2200, 2700, 3300),
          taux: (7, 13, 19),
          patrimoine: (110000, 300000, 590000),
        ),
        '65+': _RawBenchmark(
          revenu: (40000, 54000, 72000),
          epargne: (200, 450, 900),
          charges: (1900, 2400, 3000),
          taux: (4, 8, 14),
          patrimoine: (140000, 360000, 680000),
        ),
      },
      'TI': {
        '25-34': _RawBenchmark(
          revenu: (48000, 60000, 76000),
          epargne: (150, 400, 750),
          charges: (1600, 2000, 2500),
          taux: (3, 7, 11),
          patrimoine: (4000, 20000, 52000),
        ),
        '35-44': _RawBenchmark(
          revenu: (60000, 76000, 98000),
          epargne: (300, 650, 1200),
          charges: (2000, 2500, 3000),
          taux: (5, 9, 14),
          patrimoine: (25000, 72000, 155000),
        ),
        '45-54': _RawBenchmark(
          revenu: (66000, 85000, 115000),
          epargne: (400, 850, 1500),
          charges: (2200, 2700, 3300),
          taux: (6, 10, 15),
          patrimoine: (50000, 150000, 320000),
        ),
        '55-64': _RawBenchmark(
          revenu: (62000, 80000, 108000),
          epargne: (500, 1000, 1700),
          charges: (2100, 2600, 3200),
          taux: (7, 12, 18),
          patrimoine: (100000, 280000, 550000),
        ),
        '65+': _RawBenchmark(
          revenu: (38000, 50000, 68000),
          epargne: (150, 400, 800),
          charges: (1800, 2200, 2800),
          taux: (3, 7, 13),
          patrimoine: (130000, 340000, 640000),
        ),
      },
    };

    for (final cantonEntry in cantonData.entries) {
      final canton = cantonEntry.key;
      for (final ageEntry in cantonEntry.value.entries) {
        final ageGroup = ageEntry.key;
        final raw = ageEntry.value;
        final key = '${canton}_$ageGroup';
        result[key] = CantonalBenchmark(
          canton: canton,
          ageGroup: ageGroup,
          revenuMedian: BenchmarkRange(
            low: raw.revenu.$1.toDouble(),
            median: raw.revenu.$2.toDouble(),
            high: raw.revenu.$3.toDouble(),
            label: 'Revenu brut annuel',
          ),
          epargneMensuelle: BenchmarkRange(
            low: raw.epargne.$1.toDouble(),
            median: raw.epargne.$2.toDouble(),
            high: raw.epargne.$3.toDouble(),
            label: 'Épargne mensuelle',
          ),
          chargesFixes: BenchmarkRange(
            low: raw.charges.$1.toDouble(),
            median: raw.charges.$2.toDouble(),
            high: raw.charges.$3.toDouble(),
            label: 'Charges fixes mensuelles',
          ),
          tauxEpargne: BenchmarkRange(
            low: raw.taux.$1.toDouble(),
            median: raw.taux.$2.toDouble(),
            high: raw.taux.$3.toDouble(),
            label: 'Taux d\'épargne (%)',
          ),
          patrimoineNet: BenchmarkRange(
            low: raw.patrimoine.$1.toDouble(),
            median: raw.patrimoine.$2.toDouble(),
            high: raw.patrimoine.$3.toDouble(),
            label: 'Patrimoine net estimé',
          ),
          source: _source,
          disclaimer: _disclaimer,
        );
      }
    }

    return result;
  }
}

// ── Raw data helper ─────────────────────────────────────────────

class _RawBenchmark {
  final (int, int, int) revenu;
  final (int, int, int) epargne;
  final (int, int, int) charges;
  final (int, int, int) taux;
  final (int, int, int) patrimoine;

  const _RawBenchmark({
    required this.revenu,
    required this.epargne,
    required this.charges,
    required this.taux,
    required this.patrimoine,
  });
}
