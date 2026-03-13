import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';

// ────────────────────────────────────────────────────────────
//  FIRST JOB SERVICE — Sprint S19 / Chomage (LACI) + Premier emploi
// ────────────────────────────────────────────────────────────
//
// Pure Dart service for first job salary analysis:
//   1. analyzeSalary — full salary breakdown, 3a, LAMal, checklist
//
// All constants match the backend exactly.
// No banned terms ("garanti", "certain", "assuré", "sans risque").
// ────────────────────────────────────────────────────────────

/// A single deduction line in the salary breakdown.
class SalaryDeductionItem {
  final String label;
  final double montant;
  final double pourcentage;
  final String color; // hex color for the chart segment

  const SalaryDeductionItem({
    required this.label,
    required this.montant,
    required this.pourcentage,
    required this.color,
  });
}

/// A single LAMal franchise option.
class FranchiseOption {
  final int franchise;
  final double primeMensuelle;
  final double coutAnnuelMax;

  const FranchiseOption({
    required this.franchise,
    required this.primeMensuelle,
    required this.coutAnnuelMax,
  });
}

/// Result of salary analysis.
class FirstJobResult {
  // Decomposition
  final double brut;
  final double avsAiApg;
  final double ac;
  final double aanp;
  final double lppEmploye;
  final double totalDeductions;
  final double netEstime;
  final double cotisationsEmployeur;
  final List<SalaryDeductionItem> deductionItems;

  // 3a
  final bool eligible3a;
  final double plafondAnnuel3a;
  final double montantMensuelSuggere3a;
  final double economieFiscaleEstimee3a;
  final String alerte3a;

  // LAMal
  final List<FranchiseOption> franchiseOptions;
  final int franchiseRecommandee;
  final double economieAnnuelleVs300;
  final String noteLamal;

  // Checklist
  final List<String> checklist;

  // Chiffre choc
  final String chiffreChoc;

  const FirstJobResult({
    required this.brut,
    required this.avsAiApg,
    required this.ac,
    required this.aanp,
    required this.lppEmploye,
    required this.totalDeductions,
    required this.netEstime,
    required this.cotisationsEmployeur,
    required this.deductionItems,
    required this.eligible3a,
    required this.plafondAnnuel3a,
    required this.montantMensuelSuggere3a,
    required this.economieFiscaleEstimee3a,
    required this.alerte3a,
    required this.franchiseOptions,
    required this.franchiseRecommandee,
    required this.economieAnnuelleVs300,
    required this.noteLamal,
    required this.checklist,
    required this.chiffreChoc,
  });
}

/// Service for first job salary analysis.
///
/// All constants match the backend exactly.
class FirstJobService {
  FirstJobService._();

  static const String disclaimer =
      'Simulation du premier salaire — outil éducatif qui ne constitue pas '
      'un conseil en matière de rémunération ou de prévoyance. '
      'Les montants sont des estimations basées sur des taux moyens. '
      'Consultez un·e spécialiste pour une analyse adaptée à ta situation.';

  static const List<String> sources = [
    'CO art. 322 (Obligation de payer le salaire)',
    'LAVS art. 3, 5 (Cotisations AVS employé·e / employeur)',
    'LAMal art. 61-65 (Primes et franchises)',
    'LPP art. 2, 7 (Assujettissement LPP — seuil d\'entrée)',
    'LACI art. 3 (Cotisations assurance-chômage)',
    'OPP3 — plafonds 3a 2025/2026',
  ];

  // ════════════════════════════════════════════════════════════
  //  CONSTANTS (centralized in social_insurance.dart)
  // ════════════════════════════════════════════════════════════

  /// AVS/AI/APG employee share rate.
  static const double _avsAiApgRate = 0.053;

  /// AANP (accident non-professionnel) rate.
  static const double _aanpRate = 0.013;

  /// LPP maximum coordinated salary.
  /// Uses centralized constant from social_insurance.dart.
  static const double _lppMaxCoordinated = lppSalaireCoordMax;

  /// LAMal franchise options.
  static const List<int> _lamalFranchises = [300, 500, 1000, 1500, 2000, 2500];

  /// LAMal quote-part maximum.
  static const double _lamalQuotePartMax = 700.0;

  // ════════════════════════════════════════════════════════════
  //  CALCULATION
  // ════════════════════════════════════════════════════════════

  /// Analyze first job salary breakdown.
  static FirstJobResult analyzeSalary({
    required double salaireBrutMensuel,
    required int age,
    required String canton,
    double tauxActivite = 100.0,
  }) {
    final brut = salaireBrutMensuel;
    final annuel = brut * 12 * (tauxActivite / 100);

    // Deductions
    final avs = brut * _avsAiApgRate;
    // AC: standard rate up to ceiling, solidarity 0.5% on excess (LACI art. 3)
    final ac = annuel <= acPlafondSalaireAssure
        ? brut * acCotisationSalarie
        : (acPlafondSalaireAssure * acCotisationSalarie +
              (annuel - acPlafondSalaireAssure) * 0.005) /
            12;
    final aanp = brut * _aanpRate;

    // LPP
    double lppEmploye = 0;
    if (annuel >= lppSeuilEntree && age >= 25) {
      double coordinated = annuel - lppDeductionCoordination;
      coordinated = max(coordinated, lppSalaireCoordMin);
      coordinated = min(coordinated, _lppMaxCoordinated);
      final lppRate = _getLppRate(age);
      lppEmploye = (coordinated * lppRate) / 12 / 2; // employee half
    }

    final totalDeductions = avs + ac + aanp + lppEmploye;
    final netEstime = brut - totalDeductions;

    // Employer contributions (invisible)
    final employeurAvs = avs; // employer matches
    final employeurLpp = lppEmploye; // employer matches
    final employeurTotal =
        employeurAvs + employeurLpp + brut * 0.017; // LAA etc

    // Build deduction items for visualization
    final deductionItems = <SalaryDeductionItem>[
      SalaryDeductionItem(
        label: 'AVS/AI/APG',
        montant: avs,
        pourcentage: _avsAiApgRate * 100,
        color: '#FF453A', // error red
      ),
      SalaryDeductionItem(
        label: 'Chomage (AC)',
        montant: ac,
        pourcentage: (ac / brut) * 100,
        color: '#FF9F0A', // warning orange
      ),
      SalaryDeductionItem(
        label: 'AANP',
        montant: aanp,
        pourcentage: _aanpRate * 100,
        color: '#007AFF', // info blue
      ),
      if (lppEmploye > 0)
        SalaryDeductionItem(
          label: 'LPP (2e pilier)',
          montant: lppEmploye,
          pourcentage: (lppEmploye / brut) * 100,
          color: '#6E6E73', // muted grey
        ),
    ];

    // 3a recommendation
    final economie3a = pilier3aPlafondAvecLpp * 0.25; // ~25% marginal tax estimate

    // LAMal franchise comparison
    final franchiseData = _calculateFranchiseOptions(age, canton);

    // Chiffre choc
    final chiffreChoc =
        'Ton employeur paie ~${formatChf(employeurTotal)}/mois '
        'en plus de ton salaire — des charges que tu ne vois jamais';

    return FirstJobResult(
      brut: brut,
      avsAiApg: avs,
      ac: ac,
      aanp: aanp,
      lppEmploye: lppEmploye,
      totalDeductions: totalDeductions,
      netEstime: netEstime,
      cotisationsEmployeur: employeurTotal,
      deductionItems: deductionItems,
      eligible3a: true,
      plafondAnnuel3a: pilier3aPlafondAvecLpp,
      montantMensuelSuggere3a: pilier3aPlafondAvecLpp / 12,
      economieFiscaleEstimee3a: economie3a,
      alerte3a: 'Évite les 3a liés à une assurance-vie\u00a0! '
          'Privilégie un 3a fintech avec frais < 0,5\u00a0%.',
      franchiseOptions: franchiseData.$1,
      franchiseRecommandee: franchiseData.$2,
      economieAnnuelleVs300: franchiseData.$3,
      noteLamal:
          'Si tu es jeune et en bonne sante, la franchise 2500 est souvent '
          'plus avantageuse. Compare sur priminfo.admin.ch pour ton canton.',
      checklist: _buildChecklist(),
      chiffreChoc: chiffreChoc,
    );
  }

  /// Get LPP bonification rate by age.
  static double _getLppRate(int age) {
    if (age < 25) return 0.0;
    if (age <= 34) return 0.07;
    if (age <= 44) return 0.10;
    if (age <= 54) return 0.15;
    return 0.18;
  }

  /// Calculate LAMal franchise options.
  /// Returns (options, recommended franchise, annual savings vs 300).
  static (List<FranchiseOption>, int, double) _calculateFranchiseOptions(
      int age, String canton) {
    // Base premium estimate (young adult, ZH average)
    const basePremium300 = 380.0;

    final options = <FranchiseOption>[];
    for (final franchise in _lamalFranchises) {
      // Higher franchise -> lower premium (roughly)
      final reduction = (franchise - 300) * 0.06;
      final primeMensuelle = basePremium300 - reduction;
      final coutAnnuelMax =
          primeMensuelle * 12 + franchise + _lamalQuotePartMax;

      options.add(FranchiseOption(
        franchise: franchise,
        primeMensuelle: primeMensuelle,
        coutAnnuelMax: coutAnnuelMax,
      ));
    }

    // Recommend 2500 for young healthy person
    final economieVs300 =
        (basePremium300 - (basePremium300 - (2500 - 300) * 0.06)) * 12;

    return (options, 2500, economieVs300);
  }

  /// Build the first job checklist.
  static List<String> _buildChecklist() {
    return const [
      'Ouvrir un compte 3a fintech (pas une assurance-vie !)',
      'Choisir ta franchise LAMal sur priminfo.admin.ch',
      'Souscrire une RC privee (~CHF 5/mois)',
      'Verifier ton certificat de prevoyance LPP',
      'Preparer ta premiere declaration fiscale',
      'Mettre en place un virement epargne automatique (10-20% du net)',
      'Demander ton attestation de salaire pour les impots',
    ];
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  /// Format a number with Swiss apostrophe separators.
  static String _formatNumber(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return '${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    return 'CHF\u00A0${_formatNumber(value)}';
  }
}
