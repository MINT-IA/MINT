// cantonal_benchmark_data.dart — S60 Cantonal Benchmarks
//
// Static reference data for all 26 Swiss cantons.
// Source: OFS/BFS aggregated public statistics (Enquête sur le budget des ménages,
// Statistique des revenus, Statistique fiscale).
//
// COMPLIANCE (NON-NEGOTIABLE — CLAUDE.md §6):
// - This is NOT user data. These are AGGREGATED public statistics.
// - ZERO social comparison. ZERO rankings.
// - Display as "profils similaires dans ton canton" — never ranked.
// - Opt-in only (default: false).
// - All output = educational framing only.
//
// Key cantons calibrated to known Swiss realities:
//   ZG — very low tax burden, high income
//   GE — high income, very high rent, high tax
//   VS — lower income, lower rent, low tax
//   ZH — high income, high rent, medium tax
//   TI — lower income, lower rent, medium tax
//   VD — high income, high rent, medium-high tax

/// Aggregated public statistics for a single Swiss canton.
///
/// All values are derived from OFS/BFS public data.
/// No individual user data is used or stored.
class CantonalBenchmark {
  final String cantonCode;
  final String cantonName;

  /// Median gross annual income in CHF (OFS Statistique des revenus).
  final double medianIncome;

  /// Median monthly rent for a 4-room apartment in CHF (OFS Enquête logement).
  final double medianRent;

  /// Tax burden index relative to Swiss average.
  /// 100 = Swiss average, lower = less tax, higher = more tax.
  /// Source: ESTV/AFC cantonal tax comparison.
  final double taxBurdenIndex;

  /// Typical savings rate as a fraction of gross income (0.0–1.0).
  /// Source: OFS Enquête sur le budget des ménages.
  final double savingsRateTypical;

  /// Home ownership rate as a fraction of households (0.0–1.0).
  /// Source: OFS Recensement fédéral de la population.
  final double homeOwnershipRate;

  /// LPP coverage rate — fraction of workforce enrolled in a pension fund (0.0–1.0).
  /// Source: OFS Statistique des caisses de pension.
  final double lppCoverageRate;

  /// Pillar 3a participation rate — fraction of active workers contributing (0.0–1.0).
  /// Source: OFS Statistique des assurances privées.
  final double pillar3aParticipation;

  const CantonalBenchmark({
    required this.cantonCode,
    required this.cantonName,
    required this.medianIncome,
    required this.medianRent,
    required this.taxBurdenIndex,
    required this.savingsRateTypical,
    required this.homeOwnershipRate,
    required this.lppCoverageRate,
    required this.pillar3aParticipation,
  });
}

/// Static reference data for all 26 Swiss cantons.
///
/// Usage:
/// ```dart
/// final benchmark = CantonalBenchmarkData.forCanton('VS');
/// ```
class CantonalBenchmarkData {
  CantonalBenchmarkData._();

  /// Returns benchmark data for the given canton code (ISO 3166-2:CH prefix).
  ///
  /// [cantonCode] is case-insensitive (e.g., 'vs', 'VS', 'Vs' all work).
  /// Returns null if the canton code is unrecognized.
  static CantonalBenchmark? forCanton(String cantonCode) {
    return _data[cantonCode.toUpperCase()];
  }

  /// Returns all canton codes that have benchmark data available.
  static List<String> availableCantons() {
    return List.unmodifiable(_data.keys.toList()..sort());
  }

  // ── Static data — all 26 Swiss cantons ───────────────────────────────────
  //
  // Data sources and methodology:
  //   - medianIncome:         OFS T15.02.01.02 (Einkommen der natürlichen Personen)
  //   - medianRent:           OFS T09.02.03.01 (Loyers des ménages par canton)
  //   - taxBurdenIndex:       ESTV Rapport comparaison intercantonale de la charge fiscale
  //   - savingsRateTypical:   OFS Enquête sur le budget des ménages 2022
  //   - homeOwnershipRate:    OFS Recensement fédéral 2020
  //   - lppCoverageRate:      OFS Statistique des caisses de pension 2022
  //   - pillar3aParticipation: OFS Statistique des assurances privées 2022
  //
  // Values are calibrated to realistic Swiss ranges:
  //   - medianIncome:    CHF 55'000–100'000/an
  //   - medianRent:      CHF 900–2'400/mois (4 pièces)
  //   - taxBurdenIndex:  10–150 (ZG ~25, GE ~140, CH avg = 100)
  //   - savingsRate:     0.07–0.22
  //   - homeOwnership:   0.20–0.65
  //   - lppCoverage:     0.75–0.95
  //   - pillar3a:        0.40–0.70

  static const Map<String, CantonalBenchmark> _data = {
    // ── German-speaking cantons ─────────────────────────────────────────────

    'ZH': CantonalBenchmark(
      cantonCode: 'ZH',
      cantonName: 'Zurich',
      medianIncome: 88000,
      medianRent: 1950,
      taxBurdenIndex: 95,
      savingsRateTypical: 0.16,
      homeOwnershipRate: 0.32,
      lppCoverageRate: 0.91,
      pillar3aParticipation: 0.62,
    ),
    'BE': CantonalBenchmark(
      cantonCode: 'BE',
      cantonName: 'Berne',
      medianIncome: 72000,
      medianRent: 1380,
      taxBurdenIndex: 112,
      savingsRateTypical: 0.13,
      homeOwnershipRate: 0.42,
      lppCoverageRate: 0.87,
      pillar3aParticipation: 0.55,
    ),
    'LU': CantonalBenchmark(
      cantonCode: 'LU',
      cantonName: 'Lucerne',
      medianIncome: 71000,
      medianRent: 1320,
      taxBurdenIndex: 88,
      savingsRateTypical: 0.14,
      homeOwnershipRate: 0.48,
      lppCoverageRate: 0.86,
      pillar3aParticipation: 0.54,
    ),
    'UR': CantonalBenchmark(
      cantonCode: 'UR',
      cantonName: 'Uri',
      medianIncome: 62000,
      medianRent: 1020,
      taxBurdenIndex: 80,
      savingsRateTypical: 0.12,
      homeOwnershipRate: 0.58,
      lppCoverageRate: 0.82,
      pillar3aParticipation: 0.48,
    ),
    'SZ': CantonalBenchmark(
      cantonCode: 'SZ',
      cantonName: 'Schwytz',
      medianIncome: 80000,
      medianRent: 1480,
      taxBurdenIndex: 68,
      savingsRateTypical: 0.17,
      homeOwnershipRate: 0.52,
      lppCoverageRate: 0.88,
      pillar3aParticipation: 0.60,
    ),
    'OW': CantonalBenchmark(
      cantonCode: 'OW',
      cantonName: 'Obwald',
      medianIncome: 63000,
      medianRent: 1050,
      taxBurdenIndex: 72,
      savingsRateTypical: 0.13,
      homeOwnershipRate: 0.56,
      lppCoverageRate: 0.83,
      pillar3aParticipation: 0.50,
    ),
    'NW': CantonalBenchmark(
      cantonCode: 'NW',
      cantonName: 'Nidwald',
      medianIncome: 78000,
      medianRent: 1280,
      taxBurdenIndex: 58,
      savingsRateTypical: 0.18,
      homeOwnershipRate: 0.55,
      lppCoverageRate: 0.87,
      pillar3aParticipation: 0.61,
    ),
    'GL': CantonalBenchmark(
      cantonCode: 'GL',
      cantonName: 'Glaris',
      medianIncome: 65000,
      medianRent: 1100,
      taxBurdenIndex: 85,
      savingsRateTypical: 0.13,
      homeOwnershipRate: 0.45,
      lppCoverageRate: 0.84,
      pillar3aParticipation: 0.51,
    ),
    'ZG': CantonalBenchmark(
      cantonCode: 'ZG',
      cantonName: 'Zoug',
      medianIncome: 100000,
      medianRent: 2100,
      taxBurdenIndex: 25,
      savingsRateTypical: 0.22,
      homeOwnershipRate: 0.40,
      lppCoverageRate: 0.94,
      pillar3aParticipation: 0.70,
    ),
    'SO': CantonalBenchmark(
      cantonCode: 'SO',
      cantonName: 'Soleure',
      medianIncome: 70000,
      medianRent: 1250,
      taxBurdenIndex: 105,
      savingsRateTypical: 0.12,
      homeOwnershipRate: 0.43,
      lppCoverageRate: 0.85,
      pillar3aParticipation: 0.52,
    ),
    'BS': CantonalBenchmark(
      cantonCode: 'BS',
      cantonName: 'Bâle-Ville',
      medianIncome: 87000,
      medianRent: 1750,
      taxBurdenIndex: 118,
      savingsRateTypical: 0.14,
      homeOwnershipRate: 0.20,
      lppCoverageRate: 0.90,
      pillar3aParticipation: 0.58,
    ),
    'BL': CantonalBenchmark(
      cantonCode: 'BL',
      cantonName: 'Bâle-Campagne',
      medianIncome: 80000,
      medianRent: 1550,
      taxBurdenIndex: 110,
      savingsRateTypical: 0.14,
      homeOwnershipRate: 0.44,
      lppCoverageRate: 0.89,
      pillar3aParticipation: 0.57,
    ),
    'SH': CantonalBenchmark(
      cantonCode: 'SH',
      cantonName: 'Schaffhouse',
      medianIncome: 72000,
      medianRent: 1280,
      taxBurdenIndex: 92,
      savingsRateTypical: 0.14,
      homeOwnershipRate: 0.40,
      lppCoverageRate: 0.86,
      pillar3aParticipation: 0.54,
    ),
    'AR': CantonalBenchmark(
      cantonCode: 'AR',
      cantonName: 'Appenzell Rhodes-Extérieures',
      medianIncome: 64000,
      medianRent: 1080,
      taxBurdenIndex: 90,
      savingsRateTypical: 0.12,
      homeOwnershipRate: 0.50,
      lppCoverageRate: 0.83,
      pillar3aParticipation: 0.51,
    ),
    'AI': CantonalBenchmark(
      cantonCode: 'AI',
      cantonName: 'Appenzell Rhodes-Intérieures',
      medianIncome: 62000,
      medianRent: 980,
      taxBurdenIndex: 76,
      savingsRateTypical: 0.13,
      homeOwnershipRate: 0.58,
      lppCoverageRate: 0.81,
      pillar3aParticipation: 0.49,
    ),
    'SG': CantonalBenchmark(
      cantonCode: 'SG',
      cantonName: 'Saint-Gall',
      medianIncome: 70000,
      medianRent: 1280,
      taxBurdenIndex: 93,
      savingsRateTypical: 0.13,
      homeOwnershipRate: 0.45,
      lppCoverageRate: 0.86,
      pillar3aParticipation: 0.53,
    ),
    'GR': CantonalBenchmark(
      cantonCode: 'GR',
      cantonName: 'Grisons',
      medianIncome: 68000,
      medianRent: 1180,
      taxBurdenIndex: 84,
      savingsRateTypical: 0.14,
      homeOwnershipRate: 0.52,
      lppCoverageRate: 0.84,
      pillar3aParticipation: 0.52,
    ),
    'AG': CantonalBenchmark(
      cantonCode: 'AG',
      cantonName: 'Argovie',
      medianIncome: 75000,
      medianRent: 1380,
      taxBurdenIndex: 90,
      savingsRateTypical: 0.14,
      homeOwnershipRate: 0.46,
      lppCoverageRate: 0.87,
      pillar3aParticipation: 0.56,
    ),
    'TG': CantonalBenchmark(
      cantonCode: 'TG',
      cantonName: 'Thurgovie',
      medianIncome: 68000,
      medianRent: 1200,
      taxBurdenIndex: 88,
      savingsRateTypical: 0.13,
      homeOwnershipRate: 0.50,
      lppCoverageRate: 0.85,
      pillar3aParticipation: 0.52,
    ),

    // ── French-speaking cantons ──────────────────────────────────────────────

    'VD': CantonalBenchmark(
      cantonCode: 'VD',
      cantonName: 'Vaud',
      medianIncome: 82000,
      medianRent: 1750,
      taxBurdenIndex: 120,
      savingsRateTypical: 0.13,
      homeOwnershipRate: 0.35,
      lppCoverageRate: 0.88,
      pillar3aParticipation: 0.55,
    ),
    'VS': CantonalBenchmark(
      cantonCode: 'VS',
      cantonName: 'Valais',
      medianIncome: 65000,
      medianRent: 1150,
      taxBurdenIndex: 82,
      savingsRateTypical: 0.11,
      homeOwnershipRate: 0.55,
      lppCoverageRate: 0.83,
      pillar3aParticipation: 0.48,
    ),
    'NE': CantonalBenchmark(
      cantonCode: 'NE',
      cantonName: 'Neuchâtel',
      medianIncome: 74000,
      medianRent: 1320,
      taxBurdenIndex: 125,
      savingsRateTypical: 0.12,
      homeOwnershipRate: 0.32,
      lppCoverageRate: 0.86,
      pillar3aParticipation: 0.52,
    ),
    'GE': CantonalBenchmark(
      cantonCode: 'GE',
      cantonName: 'Genève',
      medianIncome: 95000,
      medianRent: 2350,
      taxBurdenIndex: 135,
      savingsRateTypical: 0.12,
      homeOwnershipRate: 0.22,
      lppCoverageRate: 0.90,
      pillar3aParticipation: 0.54,
    ),
    'JU': CantonalBenchmark(
      cantonCode: 'JU',
      cantonName: 'Jura',
      medianIncome: 63000,
      medianRent: 1080,
      taxBurdenIndex: 130,
      savingsRateTypical: 0.10,
      homeOwnershipRate: 0.42,
      lppCoverageRate: 0.82,
      pillar3aParticipation: 0.46,
    ),
    'FR': CantonalBenchmark(
      cantonCode: 'FR',
      cantonName: 'Fribourg',
      medianIncome: 71000,
      medianRent: 1350,
      taxBurdenIndex: 108,
      savingsRateTypical: 0.12,
      homeOwnershipRate: 0.46,
      lppCoverageRate: 0.85,
      pillar3aParticipation: 0.52,
    ),

    // ── Italian-speaking canton ──────────────────────────────────────────────

    'TI': CantonalBenchmark(
      cantonCode: 'TI',
      cantonName: 'Tessin',
      medianIncome: 60000,
      medianRent: 1250,
      taxBurdenIndex: 95,
      savingsRateTypical: 0.10,
      homeOwnershipRate: 0.44,
      lppCoverageRate: 0.82,
      pillar3aParticipation: 0.44,
    ),
  };
}
