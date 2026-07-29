import 'dart:math';

import 'package:uuid/uuid.dart';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/money_truth_receipt.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

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
  final Pillar3aTaxImpactEstimate impactFiscal3a;
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
  final String premierEclairage;

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
    required this.impactFiscal3a,
    required this.economieFiscaleEstimee3a,
    required this.alerte3a,
    required this.franchiseOptions,
    required this.franchiseRecommandee,
    required this.economieAnnuelleVs300,
    required this.noteLamal,
    required this.checklist,
    required this.premierEclairage,
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

  // ── MoneyTruthReceipt v1 (PR-B) — hypothèse bornante AANP + métadonnées ──
  //
  // La classe de risque AANP dépend de l'employeur (~1.0-1.5%). Le net point
  // utilise 1.3% ; la bande d'incertitude recalcule le net avec l'AANP basse
  // (net haut) et haute (net bas). Mêmes valeurs que le producteur backend
  // (onboarding_service.py) — SPEC §4.1.

  /// AANP basse (déduction minimale) → borne HAUTE du net.
  static const double _aanpRateLow = 0.010;

  /// AANP haute (déduction maximale) → borne BASSE du net.
  static const double _aanpRateHigh = 0.015;

  /// Millésime des règles de cotisation appliquées (≠ millésime statistique).
  static const int _firstJobNetTaxYear = 2026;

  /// Version du moteur de calcul (champ `engineVersion`). Chaîne stable
  /// partagée avec le backend.
  static const String _firstJobNetEngineVersion = 'firstjob-net-receipt-v1';

  /// Champs du gate d'entrée (firstJobGateWhySalaire/Age/Canton) — base de
  /// l'axe `completeness` de la confiance.
  static const Set<String> _firstJobGateFields = {
    'salaireBrutMensuel',
    'age',
    'canton',
  };

  /// LPP maximum coordinated salary.
  /// Uses centralized constant from social_insurance.dart.
  static double get _lppMaxCoordinated =>
      reg('lpp.max_coordinated_salary', lppSalaireCoordMax);

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
    // AC : 1.1% jusqu'au plafond (148'200/an), 0% au-dela. Le pour-cent de
    // solidarite (1% sur la part > plafond) a ete ABOLI au 1.1.2023 (fonds AC
    // > 2,5 Mia CHF fin 2022 -> LACI art. 90c al. 4). Source : SECO / memento
    // ahv-iv.ch 2.08 (etat 1.1.2025). Aligne sur onboarding_service.py backend.
    final acCeil = reg('ac.max_insured_salary', acPlafondSalaireAssure);
    final acEmpRate = reg('ac.contribution_rate_employee', acCotisationSalarie);
    final ac = annuel <= acCeil
        ? brut * acEmpRate
        : (acCeil * acEmpRate) / 12; // 1.1% du plafond mensuel, 0% au-dela
    final aanp = brut * _aanpRate;

    // LPP
    double lppEmploye = 0;
    if (annuel >= reg('lpp.entry_threshold', lppSeuilEntree) && age >= 25) {
      double coordinated =
          annuel - reg('lpp.coordination_deduction', lppDeductionCoordination);
      coordinated = max(
          coordinated, reg('lpp.min_coordinated_salary', lppSalaireCoordMin));
      coordinated = min(coordinated, _lppMaxCoordinated);
      final lppRate = getLppBonificationRate(age);
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

    // 3a recommendation — keep ceiling and tax impact separate.
    final impactFiscal3a = RetirementTaxCalculator.estimate3aTaxImpact(
      grossAnnualSalary: annuel,
      canton: canton,
    );

    // LAMal franchise comparison
    final franchiseData = _calculateFranchiseOptions(age, canton);

    // Chiffre choc
    final premierEclairage =
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
      plafondAnnuel3a: impactFiscal3a.annualCeiling,
      montantMensuelSuggere3a: impactFiscal3a.annualCeiling / 12,
      impactFiscal3a: impactFiscal3a,
      economieFiscaleEstimee3a: impactFiscal3a.estimatedTaxSaving,
      alerte3a: 'Compare les types de 3a\u00a0: banque, titres, assurance-vie. '
          'Vérifie les frais, les primes et les conditions de sortie avant de signer.',
      franchiseOptions: franchiseData.$1,
      franchiseRecommandee: franchiseData.$2,
      economieAnnuelleVs300: franchiseData.$3,
      noteLamal:
          'Si tu es jeune et en bonne sante, la franchise 2500 est souvent '
          'plus avantageuse. Compare sur priminfo.admin.ch pour ton canton.',
      checklist: _buildChecklist(),
      premierEclairage: premierEclairage,
    );
  }

  // ════════════════════════════════════════════════════════════
  //  MoneyTruthReceipt v1 — producteur du claim firstjob.net_salary.v1 (PR-B)
  // ════════════════════════════════════════════════════════════

  /// Émet le MoneyTruthReceipt du net firstJob (SPEC §4).
  ///
  /// `value` = net firstJob point (= [FirstJobResult.netEstime] : le MÊME
  /// chiffre que l'écran, aucune divergence intra-écran). `range` = recalcul du
  /// net avec l'AANP basse / haute (hypothèse bornante figée). `inputsHash` =
  /// [computeInputsHash] des inputs normalisés — MÊME algorithme et MÊMES
  /// champs que le producteur backend, donc MÊME hash octet pour octet.
  ///
  /// `receiptId` / `computedAt` sont injectables pour les tests déterministes.
  static MoneyTruthReceipt buildNetSalaryReceipt({
    required double salaireBrutMensuel,
    required int age,
    required String canton,
    double tauxActivite = 100.0,
    String etatCivil = 'celibataire',
    Set<String>? userProvidedFields,
    String? receiptId,
    String? computedAt,
  }) {
    final cantonNorm = canton.toUpperCase();
    final etatNorm = etatCivil.toLowerCase();

    final result = analyzeSalary(
      salaireBrutMensuel: salaireBrutMensuel,
      age: age,
      canton: cantonNorm,
      tauxActivite: tauxActivite,
    );
    final pointNet = result.netEstime;

    // AANP est une déduction linéaire : net(aanp) = pointNet + brut*(1.3% - aanp).
    final netHigh = pointNet + salaireBrutMensuel * (_aanpRate - _aanpRateLow);
    final netLow = pointNet + salaireBrutMensuel * (_aanpRate - _aanpRateHigh);

    final inputs = <String, dynamic>{
      'salaireBrutMensuel': salaireBrutMensuel,
      'age': age,
      'canton': cantonNorm,
      'tauxActivite': tauxActivite,
      'etatCivil': etatNorm,
    };

    return MoneyTruthReceipt(
      claimId: kFirstJobNetSalaryClaimId,
      receiptId: receiptId ?? const Uuid().v4(),
      inputs: inputs,
      inputsHash: computeInputsHash(inputs),
      jurisdiction: 'CH-$cantonNorm',
      taxYear: _firstJobNetTaxYear,
      base: 'net',
      civilStatus: etatNorm,
      assumptions: [
        'AANP 1,0-1,5 % selon la classe de risque de l\'employeur (défaut 1,3 %)', // lint-ignore: no_hardcoded_fr (i18n -> PR-G ; receipt interne, non rendu en PR-B)
        'Taux d\'activité : ${tauxActivite.toStringAsFixed(0)} %', // lint-ignore: no_hardcoded_fr (i18n -> PR-G ; receipt interne, non rendu en PR-B)
        'État civil : $etatNorm', // lint-ignore: no_hardcoded_fr (i18n -> PR-G ; receipt interne, non rendu en PR-B)
        'Impôt à la source non appliqué (résident·e imposé·e ordinairement)', // lint-ignore: no_hardcoded_fr (i18n -> PR-G ; receipt interne, non rendu en PR-B)
        'Net mensuel hors 13e salaire et hors bonus', // lint-ignore: no_hardcoded_fr (i18n -> PR-G ; receipt interne, non rendu en PR-B)
      ],
      engine: 'financial_core.first_job_service',
      engineVersion: _firstJobNetEngineVersion,
      rounding: 'CHF arrondi au 1 franc',
      sources: const [
        MoneyTruthSource(
          id: 'avs',
          label: 'AVS/AI/APG (LAVS art. 5 · LAI art. 3 · LAPG art. 27)',
          vintage: _firstJobNetTaxYear,
        ),
        MoneyTruthSource(
          id: 'ac',
          label: 'AC (LACI art. 3)',
          vintage: _firstJobNetTaxYear,
        ),
        MoneyTruthSource(
          id: 'lpp',
          label: 'LPP bonifications (LPP art. 16)',
          vintage: _firstJobNetTaxYear,
        ),
        MoneyTruthSource(
          id: 'aanp',
          label: 'AANP estimation (LAA art. 91)',
          vintage: _firstJobNetTaxYear,
        ),
      ],
      value: pointNet,
      range: MoneyTruthRange(low: netLow, high: netHigh),
      confidence: _firstJobNetConfidence(userProvidedFields),
      computedAt: computedAt ?? DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// Mapping DÉCLARÉ PR-B des champs du gate vers les 4 axes
  /// [MoneyTruthConfidence] (forme fil EnhancedConfidence). Pas de nouveau
  /// scorer — mêmes valeurs que le backend (`_first_job_net_confidence`).
  static MoneyTruthConfidence _firstJobNetConfidence(
    Set<String>? userProvidedFields,
  ) {
    final provided = userProvidedFields ?? _firstJobGateFields;
    final completeness =
        provided.intersection(_firstJobGateFields).length /
            _firstJobGateFields.length;
    const accuracy = 0.90;
    const freshness = 1.00;
    const understanding = 0.50;
    final combined =
        pow(completeness * accuracy * freshness * understanding, 0.25)
            .toDouble();
    return MoneyTruthConfidence(
      completeness: completeness,
      accuracy: accuracy,
      freshness: freshness,
      understanding: understanding,
      score: combined,
    );
  }

  // _getLppRate removed — use centralized getLppBonificationRate(age)
  // from social_insurance.dart (LPP art. 16).

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
    const economieVs300 =
        (basePremium300 - (basePremium300 - (2500 - 300) * 0.06)) * 12;

    return (options, 2500, economieVs300);
  }

  /// Build the first job checklist.
  static List<String> _buildChecklist() {
    return const [
      'Comparer les types de 3a avant de signer (banque, titres, assurance-vie)',
      'Choisir ta franchise LAMal sur priminfo.admin.ch',
      'Comparer une RC privée (coût courant ~CHF 5/mois)', // lint-ignore: no_hardcoded_fr (dette i18n préexistante, LOT 3)
      'Verifier ton certificat de prévoyance LPP',
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
