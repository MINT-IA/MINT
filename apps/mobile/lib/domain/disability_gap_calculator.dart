// Pure Dart calculator for disability gap simulation.
//
// Computes the financial gap if the user can't work due to disability,
// across 3 phases:
// - Phase 1: Employer coverage (CO art. 324a)
// - Phase 2: IJM (indemnités journalières maladie) if applicable
// - Phase 3: AI (assurance invalidité) + LPP disability rente
//
// Sources:
// - CO art. 324a (employer obligation to maintain salary during illness)
// - LAI art. 28 al. 1 (AI disability rente)
// - LPP art. 23 (disability benefits from pension fund)

enum EmploymentStatusType {
  employee,
  selfEmployed,
  mixed,
  unemployed,
  student,
}

/// Employer coverage duration by canton and years of service.
/// Source: CO art. 324a + cantonal scales (bernoise, zurichoise, bâloise).
const Map<String, Map<int, int>> _employerCoverageWeeks = {
  // Échelle bernoise (BE, VD, GE, LU)
  'BE': {
    0: 3, // 1st year
    1: 4, // 2nd year
    2: 8, // 3-4 years
    4: 8,
    5: 13, // 5-9 years
    9: 13,
    10: 17, // 10-14 years
    14: 17,
    15: 21, // 15-19 years
    19: 21,
    20: 26, // 20-24 years
    24: 26,
    25: 26, // 25+ years
  },
  'VD': {
    0: 3,
    1: 4,
    2: 8,
    4: 8,
    5: 13,
    9: 13,
    10: 17,
    14: 17,
    15: 21,
    19: 21,
    20: 26,
    24: 26,
    25: 26,
  },
  'GE': {
    0: 3,
    1: 4,
    2: 8,
    4: 8,
    5: 13,
    9: 13,
    10: 17,
    14: 17,
    15: 21,
    19: 21,
    20: 26,
    24: 26,
    25: 26,
  },
  'LU': {
    0: 3,
    1: 4,
    2: 8,
    4: 8,
    5: 13,
    9: 13,
    10: 17,
    14: 17,
    15: 21,
    19: 21,
    20: 26,
    24: 26,
    25: 26,
  },
  // Échelle zurichoise (ZH)
  'ZH': {
    0: 3, // 1st year
    1: 8, // 2nd year
    2: 8, // 3-4 years
    4: 8,
    5: 13, // 5-9 years
    9: 13,
    10: 17, // 10-14 years
    14: 17,
    15: 21, // 15-19 years
    19: 21,
    20: 26, // 20-24 years
    24: 26,
    25: 26, // 25+ years
  },
  // Échelle bâloise (BS)
  'BS': {
    0: 3, // 1st year
    1: 9, // 2nd year
    2: 9, // 3-5 years
    5: 9,
    6: 13, // 6-10 years
    10: 13,
    11: 17, // 11-15 years
    15: 17,
    16: 21, // 16-20 years
    20: 21,
    21: 26, // 21+ years
  },
};

/// AI rente mensuelle maximale by disability degree (2025/2026 values).
/// Source: LAI art. 28 al. 1
const Map<int, double> _aiRenteByDegree = {
  40: 630.0, // 1/4 rente
  50: 1260.0, // 1/2 rente
  60: 1890.0, // 3/4 rente
  70: 2520.0, // full rente
  100: 2520.0, // full rente
};

/// Supported cantons for the simulator.
const List<String> supportedDisabilityCantons = ['ZH', 'BE', 'VD', 'GE', 'LU', 'BS'];

class DisabilityGapResult {
  /// Current net monthly income.
  final double revenuActuel;

  // Phase 1: Employer coverage (CO art. 324a)
  final double phase1DurationWeeks;
  final double phase1MonthlyBenefit;
  final double phase1Gap;

  // Phase 2: IJM (daily indemnity insurance)
  final double phase2DurationMonths;
  final double phase2MonthlyBenefit;
  final double phase2Gap;

  // Phase 3: AI + LPP
  final double phase3MonthlyBenefit;
  final double phase3Gap;

  // Summary
  final String riskLevel; // critical, high, medium, low
  final List<String> alerts;
  final double aiRenteMensuelle;
  final double lppDisabilityBenefit;

  const DisabilityGapResult({
    required this.revenuActuel,
    required this.phase1DurationWeeks,
    required this.phase1MonthlyBenefit,
    required this.phase1Gap,
    required this.phase2DurationMonths,
    required this.phase2MonthlyBenefit,
    required this.phase2Gap,
    required this.phase3MonthlyBenefit,
    required this.phase3Gap,
    required this.riskLevel,
    required this.alerts,
    required this.aiRenteMensuelle,
    required this.lppDisabilityBenefit,
  });
}

/// Get employer coverage duration in weeks based on canton and years of service.
int _getEmployerCoverageWeeks(String canton, int anneesAnciennete) {
  final cantonTable = _employerCoverageWeeks[canton];
  if (cantonTable == null) {
    throw ArgumentError('Canton non supporté: $canton');
  }

  // Find the matching bracket
  int weeks = 3; // default 1st year
  for (final entry in cantonTable.entries) {
    if (anneesAnciennete >= entry.key) {
      weeks = entry.value;
    }
  }
  return weeks;
}

/// Get AI rente mensuelle based on disability degree.
double _getAiRente(int degreInvalidite) {
  // Find the closest bracket
  if (degreInvalidite < 40) return 0.0;
  if (degreInvalidite >= 40 && degreInvalidite < 50) return _aiRenteByDegree[40]!;
  if (degreInvalidite >= 50 && degreInvalidite < 60) return _aiRenteByDegree[50]!;
  if (degreInvalidite >= 60 && degreInvalidite < 70) return _aiRenteByDegree[60]!;
  return _aiRenteByDegree[70]!; // 70-100% = full rente
}

/// Compute disability gap across 3 phases.
///
/// Throws [ArgumentError] if canton is not supported.
DisabilityGapResult computeDisabilityGap({
  required double revenuMensuelNet,
  required EmploymentStatusType statutProfessionnel,
  required String canton,
  required int anneesAnciennete,
  required bool hasIjmCollective,
  required int degreInvalidite,
  double lppDisabilityBenefit = 0.0,
}) {
  if (!supportedDisabilityCantons.contains(canton)) {
    throw ArgumentError('Canton non supporté: $canton');
  }

  final alerts = <String>[];

  // Phase 1: Employer coverage
  double phase1DurationWeeks = 0;
  double phase1MonthlyBenefit = 0;
  if (statutProfessionnel == EmploymentStatusType.employee) {
    phase1DurationWeeks = _getEmployerCoverageWeeks(canton, anneesAnciennete).toDouble();
    phase1MonthlyBenefit = revenuMensuelNet; // 100% salary
  } else {
    alerts.add('Indépendant: aucune couverture employeur (CO art. 324a non applicable)');
  }
  final phase1Gap = revenuMensuelNet - phase1MonthlyBenefit;

  // Phase 2: IJM (daily indemnity insurance)
  double phase2DurationMonths = 24.0; // up to 720 days = 24 months
  double phase2MonthlyBenefit = 0;
  if (statutProfessionnel == EmploymentStatusType.employee && hasIjmCollective) {
    phase2MonthlyBenefit = revenuMensuelNet * 0.8; // 80% coverage
  } else if (statutProfessionnel == EmploymentStatusType.selfEmployed && hasIjmCollective) {
    // Self-employed can have their own IJM
    phase2MonthlyBenefit = revenuMensuelNet * 0.8;
  } else {
    alerts.add('Aucune IJM: après la période employeur, tu ne reçois plus rien jusqu\'à l\'AI');
  }
  final phase2Gap = revenuMensuelNet - phase2MonthlyBenefit;

  // Phase 3: AI + LPP
  final aiRenteMensuelle = _getAiRente(degreInvalidite);
  final phase3MonthlyBenefit = aiRenteMensuelle + lppDisabilityBenefit;
  final phase3Gap = revenuMensuelNet - phase3MonthlyBenefit;

  // Risk level determination
  String riskLevel = 'low';
  if (statutProfessionnel == EmploymentStatusType.selfEmployed && !hasIjmCollective) {
    riskLevel = 'critical';
    alerts.add('CRITIQUE: Indépendant sans IJM = aucune couverture pendant 24 mois');
  } else if (statutProfessionnel == EmploymentStatusType.employee && !hasIjmCollective) {
    riskLevel = 'high';
    alerts.add('HAUT RISQUE: Après ${phase1DurationWeeks.toInt()} semaines, tu n\'as plus rien');
  } else if (phase3Gap > 3000) {
    riskLevel = 'medium';
    alerts.add('Gap important à long terme (AI + LPP insuffisants)');
  } else {
    riskLevel = 'low';
  }

  return DisabilityGapResult(
    revenuActuel: revenuMensuelNet,
    phase1DurationWeeks: phase1DurationWeeks,
    phase1MonthlyBenefit: phase1MonthlyBenefit,
    phase1Gap: phase1Gap,
    phase2DurationMonths: phase2DurationMonths,
    phase2MonthlyBenefit: phase2MonthlyBenefit,
    phase2Gap: phase2Gap,
    phase3MonthlyBenefit: phase3MonthlyBenefit,
    phase3Gap: phase3Gap,
    riskLevel: riskLevel,
    alerts: alerts,
    aiRenteMensuelle: aiRenteMensuelle,
    lppDisabilityBenefit: lppDisabilityBenefit,
  );
}
