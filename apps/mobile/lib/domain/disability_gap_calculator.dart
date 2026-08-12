import 'package:mint_mobile/constants/social_insurance.dart';

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

/// Employer coverage scales (CO art. 324a).
/// 3 scales used across 26 cantons:
///   - Échelle bernoise (22 cantons)
///   - Échelle zurichoise (1 canton: ZH)
///   - Échelle bâloise (2 cantons: BS, BL)
const Map<int, int> _echelleBernoise = {
  0: 3,   // 1st year
  1: 4,   // 2nd year
  2: 8,   // 3-4 years
  4: 8,
  5: 13,  // 5-9 years
  9: 13,
  10: 17, // 10-14 years
  14: 17,
  15: 21, // 15-19 years
  19: 21,
  20: 26, // 20+ years
  24: 26,
  25: 26,
};

const Map<int, int> _echelleZurichoise = {
  0: 3,   // 1st year
  1: 8,   // 2nd year
  2: 8,   // 3-4 years
  4: 8,
  5: 13,  // 5-9 years
  9: 13,
  10: 17, // 10-14 years
  14: 17,
  15: 21, // 15-19 years
  19: 21,
  20: 26, // 20+ years
  24: 26,
  25: 26,
};

const Map<int, int> _echelleBaloise = {
  0: 3,   // 1st year
  1: 9,   // 2nd year
  2: 9,   // 3-5 years
  5: 9,
  6: 13,  // 6-10 years
  10: 13,
  11: 17, // 11-15 years
  15: 17,
  16: 21, // 16-20 years
  20: 21,
  21: 26, // 21+ years
};

/// Employer coverage duration by canton and years of service.
/// Source: CO art. 324a + cantonal scales (bernoise, zurichoise, bâloise).
/// All 26 cantons mapped to their respective scale.
const Map<String, Map<int, int>> _employerCoverageWeeks = {
  // Échelle bernoise (22 cantons)
  'BE': _echelleBernoise,
  'VD': _echelleBernoise,
  'GE': _echelleBernoise,
  'LU': _echelleBernoise,
  'FR': _echelleBernoise,
  'NE': _echelleBernoise,
  'JU': _echelleBernoise,
  'VS': _echelleBernoise,
  'TI': _echelleBernoise,
  'SO': _echelleBernoise,
  'AG': _echelleBernoise,
  'SG': _echelleBernoise,
  'TG': _echelleBernoise,
  'SH': _echelleBernoise,
  'AR': _echelleBernoise,
  'AI': _echelleBernoise,
  'GL': _echelleBernoise,
  'OW': _echelleBernoise,
  'NW': _echelleBernoise,
  'UR': _echelleBernoise,
  'SZ': _echelleBernoise,
  'ZG': _echelleBernoise,
  'GR': _echelleBernoise,
  // Échelle zurichoise (1 canton)
  'ZH': _echelleZurichoise,
  // Échelle bâloise (2 cantons)
  'BS': _echelleBaloise,
  'BL': _echelleBaloise,
};

/// AI rente mensuelle maximale by disability degree (2025/2026 values).
/// Source: LAI art. 28 al. 1
final Map<int, double> _aiRenteByDegree = {
  40: aiRenteEntiere * 0.25, // 1/4 rente
  50: aiRenteDemi, // 1/2 rente
  60: aiRenteEntiere * 0.75, // 3/4 rente
  70: aiRenteEntiere, // full rente
  100: aiRenteEntiere, // full rente
};

/// Supported cantons for the simulator (all 26 Swiss cantons).
const List<String> supportedDisabilityCantons = [
  'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
  'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
  'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
];

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

// ═══════════════════════════════════════════════════════════════════════════
//  DisabilityService — étalon mobile UNIQUE des 3 écrans invalidité.
//
//  Fin du doublon « C5-disability à 3 têtes » (cf.
//  .planning/phases/mint-utilisable-12d-vague2/V2-2-INVENTORY.md) : avant, les
//  3 écrans (disability_gap / disability_insurance / disability_self_employed)
//  ré-implémentaient EN INLINE la rente invalidité LPP, la rente AI, le score
//  de couverture, l'échelle mois-de-réserve et le ratio de charges — avec des
//  constantes nues divergentes. Ce service centralise ces calculs, miroir de
//  l'étalon backend `services/backend/app/services/disability_gap_service.py`
//  (via `computeDisabilityGap` ci-dessus pour le gap 3-phases) et des
//  constantes `constants/social_insurance.dart`.
//
//  Verdicts actuaire/juriste (Codex borné, 2026-07-31) intégrés :
//   • Acte employeur = 100 % (CO art. 324a), PAS 80 % (l'ancien affichage était
//     FAUX ; 80 % = IJM, phase suivante).
//   • Rente invalidité LPP = PROXY éducatif (~40 % salaire coordonné), jamais un
//     droit personnalisé garanti — la rente réelle dépend de l'avoir acquis, des
//     bonifications futures, du taux de conversion et du degré (LSFin : scénario
//     sourcé + réserve de confiance, pas un montant promis).
//   • Rente AI entière = MAXIMUM légal (degré ≥ 70 %, carrière pleine), pas un dû
//     automatique.
//   • Ratio de charges 70 % = hypothèse budgétaire pédagogique nommée.
//
//  ASSIETTE (brut vs net) — le simulateur mobile raisonne sur le SALAIRE BRUT
//  mensuel (le curseur des 3 écrans est libellé « salaire brut »), tandis que
//  l'étalon backend `compute_disability_gap` prend un `revenu_mensuel_net`. Les
//  BARÈMES et COEFFICIENTS sont identiques (échelle 324a, IJM 0.80, barème AI,
//  seuils/plafonds LPP) — c'est cette parité-là que fige le fixture ; les
//  MONTANTS absolus ne sont donc PAS directement comparables (assiette
//  différente). Choix éducatif conservé (pas de re-bascule brut→net ici).
// ═══════════════════════════════════════════════════════════════════════════

/// Taux sourcés du simulateur invalidité éducatif — source of truth unique.
class DisabilityRates {
  DisabilityRates._();

  /// CO art. 324a — pendant la période légale (échelle cantonale), l'employeur
  /// maintient **100 %** du salaire. Verdict actuaire (Codex 2026-07-31, A =
  /// JUSTE) : afficher 80 % pour cet acte était FAUX — le 80 % correspond à
  /// l'IJM (phase suivante), pas à l'obligation employeur.
  static const double employerCoverage = 1.0;

  /// IJM (indemnités journalières maladie) — **80 %** du salaire assuré,
  /// 720 j / 24 mois max, SI une police est souscrite (délai d'attente selon
  /// contrat). Miroir de `IJM_COVERAGE_RATE` (disability_gap_service.py:87).
  static const double ijmCoverage = 0.80;

  /// Proxy ÉDUCATIF de la rente d'invalidité LPP : ~40 % du salaire coordonné
  /// (ordre de grandeur LPP art. 23-24). CE N'EST PAS le calcul exact ni un
  /// droit personnalisé (verdict Codex 2026-07-31, C = FAUX comme calcul
  /// personnalisé) : la rente réelle = avoir de vieillesse acquis + bonifications
  /// futures sans intérêt jusqu'à 65 ans, × taux de conversion, × degré. Affiché
  /// comme scénario sourcé avec réserve de confiance, jamais garanti (LSFin).
  static const double lppInvalidityOfCoordinated = 0.40;

  /// Hypothèse budgétaire pédagogique : dépenses ≈ **70 %** du revenu (réserve
  /// d'urgence + compte à rebours). À remplacer par les dépenses réelles quand
  /// disponibles (verdict Codex 2026-07-31, E = PROXY-ACCEPTABLE).
  static const double educationalExpenseRatio = 0.70;
}

/// Projection des trois « actes » de la falaise invalidité (revenus mensuels).
class DisabilityActProjection {
  /// Acte 1 — employeur (CO art. 324a) : 100 % du salaire.
  final double employerIncome;

  /// Acte 2 — IJM : 80 % du salaire si souscrite, sinon 0.
  final double ijmIncome;

  /// Composante rente AI de l'acte 3 (maximum légal, degré ≥ 70 %).
  final double aiRente;

  /// Composante rente invalidité LPP de l'acte 3 (proxy éducatif).
  final double lppInvalidity;

  /// Acte 3 — long terme : rente AI + rente invalidité LPP.
  final double longTermIncome;

  const DisabilityActProjection({
    required this.employerIncome,
    required this.ijmIncome,
    required this.aiRente,
    required this.lppInvalidity,
    required this.longTermIncome,
  });
}

/// Bulletin de couverture invalidité (notes lettres locale-indépendantes +
/// chiffres). Les LIBELLÉS restent composés à l'écran (i18n ARB) — le service ne
/// retourne jamais de texte FR.
class DisabilityCoverage {
  final String ijmGrade;
  final String aiGrade;
  final String lppGrade;
  final String savingsGrade;
  final String overallGrade;

  /// Mois de charges couverts par l'épargne (dépenses = 70 % du revenu).
  final double reserveMonths;

  /// Chute de revenu à long terme (%) : 1 − (AI + LPP) / salaire, borné 0-100.
  final double lifeDropPercent;

  /// Vrai si le salaire annuel atteint le seuil d'entrée LPP.
  final bool hasLpp;

  const DisabilityCoverage({
    required this.ijmGrade,
    required this.aiGrade,
    required this.lppGrade,
    required this.savingsGrade,
    required this.overallGrade,
    required this.reserveMonths,
    required this.lifeDropPercent,
    required this.hasLpp,
  });
}

/// Service invalidité mobile unique — patron `GenderGapService`.
class DisabilityService {
  DisabilityService._();

  /// Rente AI mensuelle selon le degré d'invalidité (barème LAI art. 28).
  /// Miroir de `get_ai_rente_monthly` (backend) via le barème partagé de
  /// `computeDisabilityGap`.
  static double aiRenteMonthly(int degreInvalidite) =>
      _getAiRente(degreInvalidite);

  /// Rente AI ENTIÈRE = maximum légal (degré ≥ 70 %, carrière pleine). N'est pas
  /// un dû automatique — dépend des années de cotisation et du revenu moyen
  /// (verdict Codex 2026-07-31, D). Affiché comme « maximum ».
  static double get aiRenteFullMonthly => _getAiRente(100);

  /// Rente invalidité LPP mensuelle (PROXY éducatif : ~40 % du salaire
  /// coordonné). Retourne 0 sous le seuil d'entrée LPP.
  static double lppInvalidityMonthly(double annualGross) {
    if (annualGross < lppSeuilEntree) return 0.0;
    final coordinated = (annualGross - lppDeductionCoordination)
        .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
    return coordinated * DisabilityRates.lppInvalidityOfCoordinated / 12;
  }

  /// Dépenses mensuelles estimées (hypothèse pédagogique : 70 % du revenu).
  static double monthlyExpenses(double income) =>
      income * DisabilityRates.educationalExpenseRatio;

  /// Les trois actes de la falaise (employeur 100 % → IJM 80 %/0 → AI + LPP).
  static DisabilityActProjection acts({
    required double grossMonthly,
    required bool hasIjm,
  }) {
    final employer = grossMonthly * DisabilityRates.employerCoverage;
    final ijm = hasIjm ? grossMonthly * DisabilityRates.ijmCoverage : 0.0;
    final lpp = lppInvalidityMonthly(grossMonthly * 12);
    final ai = aiRenteFullMonthly;
    return DisabilityActProjection(
      employerIncome: employer,
      ijmIncome: ijm,
      aiRente: ai,
      lppInvalidity: lpp,
      longTermIncome: ai + lpp,
    );
  }

  /// Bulletin de couverture (notes + réserve + chute de revenu). Subsume les
  /// deux variantes : `disability_gap` (sans assurance privée) et
  /// `disability_insurance` (avec `hasPrivateInsurance`).
  static DisabilityCoverage coverage({
    required double grossMonthly,
    required double savings,
    required bool hasIjm,
    bool hasPrivateInsurance = false,
  }) {
    final annualGross = grossMonthly * 12;
    final hasLpp = annualGross >= lppSeuilEntree;
    final expenses = grossMonthly * DisabilityRates.educationalExpenseRatio;
    final reserveMonths = expenses > 0 ? savings / expenses : 0.0;

    final ijmGrade = hasIjm ? 'B+' : (hasPrivateInsurance ? 'B' : 'F');
    const aiGrade = 'C';
    final lppGrade = hasLpp ? 'A-' : 'D';
    final String savingsGrade;
    if (reserveMonths >= 6) {
      savingsGrade = 'A';
    } else if (reserveMonths >= 3) {
      savingsGrade = 'C+';
    } else if (reserveMonths >= 1) {
      savingsGrade = 'D';
    } else {
      savingsGrade = 'F';
    }

    int score = 0;
    if (hasIjm || hasPrivateInsurance) score += 3;
    if (hasLpp) score += 2;
    if (reserveMonths >= 3) score += 2;
    if (reserveMonths >= 6) score += 1;
    final String overallGrade;
    if (score >= 7) {
      overallGrade = 'B+';
    } else if (score >= 5) {
      overallGrade = 'C+';
    } else if (score >= 3) {
      overallGrade = 'C-';
    } else {
      overallGrade = 'D';
    }

    final longTerm = aiRenteFullMonthly + lppInvalidityMonthly(annualGross);
    final lifeDropPercent = grossMonthly > 0
        ? ((1 - longTerm / grossMonthly) * 100).clamp(0.0, 100.0)
        : 0.0;

    return DisabilityCoverage(
      ijmGrade: ijmGrade,
      aiGrade: aiGrade,
      lppGrade: lppGrade,
      savingsGrade: savingsGrade,
      overallGrade: overallGrade,
      reserveMonths: reserveMonths,
      lifeDropPercent: lifeDropPercent,
      hasLpp: hasLpp,
    );
  }
}
