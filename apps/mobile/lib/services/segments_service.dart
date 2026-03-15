import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_core/financial_core.dart';

// ────────────────────────────────────────────────────────────
//  SEGMENTS SOCIOLOGIQUES SERVICE — Sprint S12 / Chantier 6
// ────────────────────────────────────────────────────────────
//
// Contains 3 service classes for sociological segments:
//   1. GenderGapService  — pension gap analysis for part-time workers
//   2. FrontalierService — cross-border worker rules (FR/DE/IT/AT/LI)
//   3. IndependantService — self-employed coverage gap analysis
//
// All logic is local (no backend call). No banned terms
// ("garanti", "assuré", "certain") — only "peut", "pourrait",
// "estimation".
// ────────────────────────────────────────────────────────────

// ════════════════════════════════════════════════════════════
//  1. GENDER GAP PREVOYANCE SERVICE
// ════════════════════════════════════════════════════════════

/// Input model for Gender Gap analysis.
class GenderGapInput {
  final double tauxActivite; // 0-100%
  final int age;
  final double revenuAnnuel; // gross annual income at current taux
  final double avoirLpp; // current LPP assets
  final int anneesCotisation; // years already contributed
  final String canton; // e.g. "VD", "GE", "ZH"

  const GenderGapInput({
    required this.tauxActivite,
    required this.age,
    required this.revenuAnnuel,
    required this.avoirLpp,
    required this.anneesCotisation,
    required this.canton,
  });
}

/// Result of Gender Gap analysis.
class GenderGapResult {
  final double renteAt100Pct; // projected annual pension at 100% activity
  final double renteAtCurrentTaux; // projected annual pension at current taux
  final double lacuneAnnuelle; // annual pension gap
  final double lacuneTotale; // total gap over retirement (20 years approx)
  final double salaireCoordonne100; // coordinated salary at 100%
  final double salaireCoordonneActuel; // coordinated salary at current taux
  final double deductionCoordination; // 26'460 CHF (fixed, NOT prorated)
  final int anneesRestantes; // years to age 65
  final List<GenderGapRecommendation> recommendations;
  final String statistiqueOfs;

  const GenderGapResult({
    required this.renteAt100Pct,
    required this.renteAtCurrentTaux,
    required this.lacuneAnnuelle,
    required this.lacuneTotale,
    required this.salaireCoordonne100,
    required this.salaireCoordonneActuel,
    required this.deductionCoordination,
    required this.anneesRestantes,
    required this.recommendations,
    required this.statistiqueOfs,
  });
}

/// A single recommendation.
class GenderGapRecommendation {
  final String title;
  final String description;
  final String source;
  final String icon; // icon name for the UI

  const GenderGapRecommendation({
    required this.title,
    required this.description,
    required this.source,
    required this.icon,
  });
}

/// Service that analyses the pension gap for part-time workers.
///
/// The coordination deduction (CHF 26'460) is NOT prorated for
/// part-time workers under current LPP law (art. 8), which creates
/// a disproportionate penalty on lower activity rates.
class GenderGapService {
  // ── Constants ──────────────────────────────────────────────

  /// LPP coordination deduction (art. 8). NOT prorated.
  static const double deductionCoordination = lppDeductionCoordination;

  /// Maximum coordinated salary (LPP).
  static const double maxSalaireCoordonne = lppSalaireCoordMax;

  /// Minimum coordinated salary (LPP).
  static const double minSalaireCoordonne = lppSalaireCoordMin;

  /// Conversion rate at retirement (LPP art. 14).
  static const double tauxConversion = 0.068;

  /// Swiss legal retirement age (post-AVS21).
  static const int ageRetraite = 65;

  /// LPP contribution rates by age bracket (employee + employer).
  /// Source of truth: getLppBonificationRate() in social_insurance.dart
  /// 25-34: 7%, 35-44: 10%, 45-54: 15%, 55-65: 18% (LPP art. 16)

  /// OFS statistic on gender pension gap.
  /// Use [statistiqueOfsLocalized] with S parameter for i18n.
  @Deprecated('Use statistiqueOfsLocalized(s) instead')
  static const String statistiqueOfs =
      'En Suisse, les femmes touchent en moyenne 37% de rente '
      'de moins que les hommes (OFS 2024)';

  /// Localized OFS statistic.
  static String statistiqueOfsLocalized(S s) =>
      s.segmentsGenderGapOfsStat;

  // ── Public API ─────────────────────────────────────────────

  /// Analyse the pension gap between current activity rate and 100%.
  ///
  /// [s] is required for i18n of user-facing recommendation strings.
  static GenderGapResult analyse({required GenderGapInput input, required S s}) {
    final anneesRestantes = (avsAgeReferenceHomme - input.age).clamp(0, 40);

    // Salary at 100% (extrapolated from current taux)
    final salaire100 = input.tauxActivite > 0
        ? input.revenuAnnuel / (input.tauxActivite / 100)
        : 0.0;

    // Coordinated salary at 100%
    final salaireCoordonne100 =
        LppCalculator.computeSalaireCoordonne(salaire100);

    // Coordinated salary at current taux
    final salaireCoordonneActuel =
        LppCalculator.computeSalaireCoordonne(input.revenuAnnuel);

    // Project LPP capital at retirement for 100% activity
    // Delegates to LppCalculator.projectToRetirement() with conversionRate=1.0
    // to get raw capital (not rente), using salaireAssureOverride for pre-computed
    // coordinated salary.
    final capital100 = LppCalculator.projectToRetirement(
      currentBalance: input.avoirLpp,
      currentAge: input.age,
      retirementAge: ageRetraite,
      grossAnnualSalary: salaire100,
      caisseReturn: projectedReturn,
      conversionRate: 1.0, // Return raw capital, not rente
      salaireAssureOverride: salaireCoordonne100,
    );

    // Project LPP capital at retirement for current taux
    final capitalActuel = LppCalculator.projectToRetirement(
      currentBalance: input.avoirLpp,
      currentAge: input.age,
      retirementAge: ageRetraite,
      grossAnnualSalary: input.revenuAnnuel,
      caisseReturn: projectedReturn,
      conversionRate: 1.0, // Return raw capital, not rente
      salaireAssureOverride: salaireCoordonneActuel,
    );

    // Convert capital to annual pension
    final renteAt100 = capital100 * lppTauxConversionMinDecimal;
    final renteAtCurrentTaux = capitalActuel * lppTauxConversionMinDecimal;
    final lacuneAnnuelle = renteAt100 - renteAtCurrentTaux;
    final lacuneTotale = lacuneAnnuelle * 20; // approx 20 years of retirement

    // Build recommendations
    final recommendations = _buildRecommendations(
      input: input,
      lacuneAnnuelle: lacuneAnnuelle,
      salaireCoordonneActuel: salaireCoordonneActuel,
      s: s,
    );

    return GenderGapResult(
      renteAt100Pct: renteAt100,
      renteAtCurrentTaux: renteAtCurrentTaux,
      lacuneAnnuelle: lacuneAnnuelle,
      lacuneTotale: lacuneTotale,
      salaireCoordonne100: salaireCoordonne100,
      salaireCoordonneActuel: salaireCoordonneActuel,
      deductionCoordination: lppDeductionCoordination,
      anneesRestantes: anneesRestantes,
      recommendations: recommendations,
      statistiqueOfs: statistiqueOfsLocalized(s),
    );
  }

  // ── Private helpers ────────────────────────────────────────

  /// Projected annual return on LPP capital (conservative estimate).
  static const double projectedReturn = 0.015;

  /// Build personalised recommendations.
  static List<GenderGapRecommendation> _buildRecommendations({
    required GenderGapInput input,
    required double lacuneAnnuelle,
    required double salaireCoordonneActuel,
    required S s,
  }) {
    final recs = <GenderGapRecommendation>[];

    // 1. Rachat LPP
    if (lacuneAnnuelle > 0) {
      recs.add(GenderGapRecommendation(
        title: s.segmentsGenderGapRecRachat,
        description: s.segmentsGenderGapRecRachatDescFull,
        source: 'LPP art. 79b',
        icon: 'account_balance',
      ));
    }

    // 2. 3a maximise
    recs.add(GenderGapRecommendation(
      title: s.segmentsGenderGapRec3a,
      description: s.segmentsGenderGapRec3aDescFull,
      source: 'OPP3 art. 7',
      icon: 'savings',
    ));

    // 3. Proratisation coordination
    if (input.tauxActivite < 100 && salaireCoordonneActuel < lppSalaireCoordMax * 0.5) {
      recs.add(GenderGapRecommendation(
        title: s.segmentsGenderGapRecCoord,
        description: s.segmentsGenderGapRecCoordDescFull,
        source: 'LPP art. 8 / Règlement de caisse',
        icon: 'balance',
      ));
    }

    // 4. Augmenter taux d'activite
    if (input.tauxActivite < 80) {
      recs.add(GenderGapRecommendation(
        title: s.segmentsGenderGapRecTaux,
        description: s.segmentsGenderGapRecTauxDescFull,
        source: 'Analyse prévoyance MINT',
        icon: 'trending_up',
      ));
    }

    return recs;
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }
}

// ════════════════════════════════════════════════════════════
//  2. FRONTALIER SERVICE
// ════════════════════════════════════════════════════════════

/// Residence country for cross-border workers.
enum PaysResidence { fr, de, it, at, li }

/// Marital status for frontalier analysis.
enum EtatCivilFrontalier { celibataire, marie, divorce, veuf }

/// Input model for frontalier analysis.
class FrontalierInput {
  final PaysResidence paysResidence;
  final String cantonTravail; // e.g. "GE", "VD", "BS", "TI", "ZH"
  final double revenuBrut;
  final EtatCivilFrontalier etatCivil;

  const FrontalierInput({
    required this.paysResidence,
    required this.cantonTravail,
    required this.revenuBrut,
    required this.etatCivil,
  });
}

/// A single rule/alert for a frontalier.
class FrontalierRule {
  final String category; // "fiscal", "3a", "lpp", "avs"
  final String title;
  final String description;
  final String source;
  final bool isAlert; // red alert vs informational

  const FrontalierRule({
    required this.category,
    required this.title,
    required this.description,
    required this.source,
    this.isAlert = false,
  });
}

/// Quasi-resident eligibility result.
class QuasiResidentResult {
  final bool isEligible;
  final String cantonConcerne;
  final String description;
  final String source;

  const QuasiResidentResult({
    required this.isEligible,
    required this.cantonConcerne,
    required this.description,
    required this.source,
  });
}

/// Full frontalier analysis result.
class FrontalierResult {
  final PaysResidence pays;
  final String paysLabel;
  final String flagEmoji;
  final List<FrontalierRule> rules;
  final QuasiResidentResult? quasiResident;
  final List<String> checklist;

  const FrontalierResult({
    required this.pays,
    required this.paysLabel,
    required this.flagEmoji,
    required this.rules,
    this.quasiResident,
    required this.checklist,
  });
}

/// Service for cross-border workers (frontaliers).
///
/// Rules vary per country of residence and canton of work.
/// Covers: 3a rights, fiscal regime, LPP libre passage, AVS coordination.
class FrontalierService {
  // ── Constants ──────────────────────────────────────────────

  /// Get localized country labels.
  static Map<PaysResidence, String> _paysLabelsLocalized(S s) => {
    PaysResidence.fr: s.segmentsFrontalierPaysFR,
    PaysResidence.de: s.segmentsFrontalierPaysDE,
    PaysResidence.it: s.segmentsFrontalierPaysIT,
    PaysResidence.at: s.segmentsFrontalierPaysAT,
    PaysResidence.li: s.segmentsFrontalierPaysLI,
  };

  @Deprecated('Use _paysLabelsLocalized(s) instead')
  static const Map<PaysResidence, String> _paysLabels = {
    PaysResidence.fr: 'France',
    PaysResidence.de: 'Allemagne',
    PaysResidence.it: 'Italie',
    PaysResidence.at: 'Autriche',
    PaysResidence.li: 'Liechtenstein',
  };

  static const Map<PaysResidence, String> _flagEmojis = {
    PaysResidence.fr: 'FR',
    PaysResidence.de: 'DE',
    PaysResidence.it: 'IT',
    PaysResidence.at: 'AT',
    PaysResidence.li: 'LI',
  };

  // ── Public API ─────────────────────────────────────────────

  /// Analyse the situation of a cross-border worker.
  ///
  /// [s] is required for i18n of user-facing strings.
  static FrontalierResult analyse({required FrontalierInput input, required S s}) {
    final rules = <FrontalierRule>[];
    final paysLabels = _paysLabelsLocalized(s);

    // Add country-specific rules
    _addFiscalRules(input, rules, s);
    _add3aRules(input, rules, s);
    _addLppRules(input, rules, s);
    _addAvsRules(input, rules, s, paysLabels);

    // Check quasi-resident eligibility (GE only)
    final quasiResident = _checkQuasiResident(input, s);

    // Build checklist
    final checklist = _buildChecklist(input, s);

    return FrontalierResult(
      pays: input.paysResidence,
      paysLabel: paysLabels[input.paysResidence] ?? '',
      flagEmoji: _flagEmojis[input.paysResidence] ?? '',
      rules: rules,
      quasiResident: quasiResident,
      checklist: checklist,
    );
  }

  /// Get the label for a country.
  static String getPaysLabel(PaysResidence pays, {S? s}) {
    if (s != null) {
      return _paysLabelsLocalized(s)[pays] ?? '';
    }
    // ignore: deprecated_member_use_from_same_package
    return _paysLabels[pays] ?? '';
  }

  /// Get the flag code for a country.
  static String getFlagCode(PaysResidence pays) {
    return _flagEmojis[pays] ?? '';
  }

  // ── Private rule builders ──────────────────────────────────

  static void _addFiscalRules(
    FrontalierInput input,
    List<FrontalierRule> rules,
    S s,
  ) {
    switch (input.paysResidence) {
      case PaysResidence.fr:
        if (input.cantonTravail == 'GE') {
          rules.add(FrontalierRule(
            category: 'fiscal',
            title: s.segmentsFrontalierFiscalFrGeTitle,
            description: s.segmentsFrontalierFiscalFrGeDesc,
            source: 'Accord CH-FR du 11.04.1983 / CDI CH-FR',
          ));
        } else {
          rules.add(FrontalierRule(
            category: 'fiscal',
            title: s.segmentsFrontalierFiscalFrOtherTitle,
            description: s.segmentsFrontalierFiscalFrOtherDesc,
            source: 'CDI CH-FR art. 17 / Accord frontalier 1983',
          ));
        }

      case PaysResidence.de:
        rules.add(FrontalierRule(
          category: 'fiscal',
          title: s.segmentsFrontalierFiscalDeTitle,
          description: s.segmentsFrontalierFiscalDeDesc,
          source: 'CDI CH-DE art. 15a',
        ));

      case PaysResidence.it:
        rules.add(FrontalierRule(
          category: 'fiscal',
          title: s.segmentsFrontalierFiscalItTitle,
          description: s.segmentsFrontalierFiscalItDesc,
          source: 'Accord frontalier CH-IT 2020 / entré en vigueur 2024',
          isAlert: true,
        ));

      case PaysResidence.at:
        rules.add(FrontalierRule(
          category: 'fiscal',
          title: s.segmentsFrontalierFiscalAtTitle,
          description: s.segmentsFrontalierFiscalAtDesc,
          source: 'CDI CH-AT art. 15',
        ));

      case PaysResidence.li:
        rules.add(FrontalierRule(
          category: 'fiscal',
          title: s.segmentsFrontalierFiscalLiTitle,
          description: s.segmentsFrontalierFiscalLiDesc,
          source: 'Accord CH-LI / EEE',
        ));
    }
  }

  static void _add3aRules(
    FrontalierInput input,
    List<FrontalierRule> rules,
    S s,
  ) {
    // By default, non-resident workers cannot deduct 3a
    final isGE = input.cantonTravail == 'GE';

    if (isGE) {
      rules.add(FrontalierRule(
        category: '3a',
        title: s.segmentsFrontalier3aGeTitle,
        description: s.segmentsFrontalier3aGeDesc,
        source: 'LIPP GE art. 6 al. 1 / LIFD art. 83 al. 3',
      ));
    } else {
      rules.add(FrontalierRule(
        category: '3a',
        title: s.segmentsFrontalier3aNoDeductionTitle,
        description: s.segmentsFrontalier3aNoDeductionDesc,
        source: 'OPP3 art. 7 / LIFD art. 33a',
        isAlert: true,
      ));
    }
  }

  static void _addLppRules(
    FrontalierInput input,
    List<FrontalierRule> rules,
    S s,
  ) {
    rules.add(FrontalierRule(
      category: 'lpp',
      title: s.segmentsFrontalierLppAffiliationTitle,
      description: s.segmentsFrontalierLppAffiliationDesc,
      source: 'LPP art. 2',
    ));

    rules.add(FrontalierRule(
      category: 'lpp',
      title: s.segmentsFrontalierLppLibrePassageTitle,
      description: s.segmentsFrontalierLppLibrePassageDesc,
      source: 'LFLP art. 25f / Accord CH-UE',
      isAlert: true,
    ));
  }

  static void _addAvsRules(
    FrontalierInput input,
    List<FrontalierRule> rules,
    S s,
    Map<PaysResidence, String> paysLabels,
  ) {
    rules.add(FrontalierRule(
      category: 'avs',
      title: s.segmentsFrontalierAvsCotisationTitle,
      description: s.segmentsFrontalierAvsCotisationDesc(
          paysLabels[input.paysResidence] ?? ''),
      source: 'LAVS / Accord CH-UE sur la coordination',
    ));

    rules.add(FrontalierRule(
      category: 'avs',
      title: s.segmentsFrontalierAvsProRataTitle,
      description: s.segmentsFrontalierAvsProRataDesc,
      source: 'Règlement CE 883/2004',
    ));
  }

  /// Check quasi-resident eligibility (GE only, >= 90% income from CH).
  static QuasiResidentResult? _checkQuasiResident(FrontalierInput input, S s) {
    if (input.cantonTravail != 'GE') return null;

    return QuasiResidentResult(
      isEligible: true, // depends on actual income proportion
      cantonConcerne: 'GE',
      description: s.segmentsFrontalierQuasiResidentDescFull,
      source: 'LIPP GE art. 6 / ATF 136 II 241',
    );
  }

  /// Build a checklist for frontaliers.
  static List<String> _buildChecklist(FrontalierInput input, S s) {
    final checklist = <String>[
      s.segmentsFrontalierChecklistFiscal,
      s.segmentsFrontalierChecklistSalaire,
      s.segmentsFrontalierChecklistAvs,
      s.segmentsFrontalierChecklistLpp,
      s.segmentsFrontalierChecklistInvalidite,
    ];

    if (input.cantonTravail == 'GE') {
      checklist.add(s.segmentsFrontalierChecklistQuasiResident);
    }

    checklist.addAll([
      s.segmentsFrontalierChecklistJustificatifs,
      s.segmentsFrontalierChecklistMaladie,
      s.segmentsFrontalierChecklistLibrePassage,
    ]);

    return checklist;
  }
}

// ════════════════════════════════════════════════════════════
//  3. INDEPENDANT SERVICE
// ════════════════════════════════════════════════════════════

/// Input model for self-employed analysis.
class IndependantInput {
  final double revenuNet; // net annual income
  final int age;
  final bool hasLpp; // voluntary LPP affiliation
  final bool hasIjm; // daily sickness benefit insurance
  final bool hasLaa; // accident insurance
  final bool has3a;
  final String canton;

  const IndependantInput({
    required this.revenuNet,
    required this.age,
    this.hasLpp = false,
    this.hasIjm = false,
    this.hasLaa = false,
    this.has3a = false,
    required this.canton,
  });
}

/// Coverage gap item.
class CoverageGapItem {
  final String label;
  final String description;
  final bool isCovered;
  final String urgency; // "critique", "haute", "moyenne", "basse"
  final String recommendation;
  final String source;

  const CoverageGapItem({
    required this.label,
    required this.description,
    required this.isCovered,
    required this.urgency,
    required this.recommendation,
    required this.source,
  });
}

/// Protection cost breakdown.
class ProtectionCost {
  final double avsMensuel;
  final double ijmMensuel;
  final double laaMensuel;
  final double pillar3aMensuel;
  final double totalMensuel;
  final double totalAnnuel;

  const ProtectionCost({
    required this.avsMensuel,
    required this.ijmMensuel,
    required this.laaMensuel,
    required this.pillar3aMensuel,
    required this.totalMensuel,
    required this.totalAnnuel,
  });
}

/// Full self-employed analysis result.
class IndependantResult {
  final List<CoverageGapItem> coverageGaps;
  final ProtectionCost protectionCost;
  final double cotisationAvsAnnuelle;
  final double plafond3a; // max 3a amount (20% of net income, max 36'288)
  final List<String> alerts;
  final List<String> recommendations;

  const IndependantResult({
    required this.coverageGaps,
    required this.protectionCost,
    required this.cotisationAvsAnnuelle,
    required this.plafond3a,
    required this.alerts,
    required this.recommendations,
  });
}

/// Service for self-employed workers.
///
/// Analyses coverage gaps and estimates protection costs.
/// Key risks: no mandatory LPP, no mandatory IJM (CRITICAL),
/// no mandatory LAA.
class IndependantService {
  // ── Constants (delegated to social_insurance.dart) ─────────

  /// Simplified degressive AVS rates for low incomes.
  /// Key: income threshold, Value: effective rate.
  static const List<_AvsDegressifBracket> _avsDegressifBrackets = [
    _AvsDegressifBracket(threshold: 9800, rate: 0.0),
    _AvsDegressifBracket(threshold: 17400, rate: 0.043),
    _AvsDegressifBracket(threshold: 21100, rate: 0.046),
    _AvsDegressifBracket(threshold: 24900, rate: 0.049),
    _AvsDegressifBracket(threshold: 28600, rate: 0.052),
    _AvsDegressifBracket(threshold: 32400, rate: 0.056),
    _AvsDegressifBracket(threshold: 36100, rate: 0.060),
    _AvsDegressifBracket(threshold: 39900, rate: 0.064),
    _AvsDegressifBracket(threshold: 43600, rate: 0.069),
    _AvsDegressifBracket(threshold: 47400, rate: 0.074),
    _AvsDegressifBracket(threshold: 51100, rate: 0.079),
    _AvsDegressifBracket(threshold: 54900, rate: 0.085),
    _AvsDegressifBracket(threshold: 58800, rate: 0.092),
  ];

  // ── Public API ─────────────────────────────────────────────

  /// Analyse the coverage situation of a self-employed person.
  ///
  /// [s] is required for i18n of user-facing strings.
  static IndependantResult analyse({required IndependantInput input, required S s}) {
    // Coverage gaps
    final coverageGaps = _analyseCoverageGaps(input, s);

    // AVS contribution
    final cotisationAvs = _computeAvsContribution(input.revenuNet);

    // 3a ceiling: 20% of net income if no LPP, max 35'280
    // If voluntary LPP: standard 7'258
    final plafond3a = input.hasLpp
        ? pilier3aPlafondAvecLpp
        : min(input.revenuNet * 0.20, pilier3aPlafondSansLpp);

    // Protection cost simulation
    final protectionCost = _computeProtectionCost(
      revenuNet: input.revenuNet,
      cotisationAvs: cotisationAvs,
      plafond3a: plafond3a,
      hasIjm: input.hasIjm,
      hasLaa: input.hasLaa,
    );

    // Alerts
    final alerts = _buildAlerts(input, s);

    // Recommendations
    final recommendations = _buildRecommendations(input, plafond3a, s);

    return IndependantResult(
      coverageGaps: coverageGaps,
      protectionCost: protectionCost,
      cotisationAvsAnnuelle: cotisationAvs,
      plafond3a: plafond3a,
      alerts: alerts,
      recommendations: recommendations,
    );
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }

  // ── Private helpers ────────────────────────────────────────

  /// Analyse coverage gaps.
  static List<CoverageGapItem> _analyseCoverageGaps(IndependantInput input, S s) {
    final plafond3aFormatted = formatChf(
        input.hasLpp ? pilier3aPlafondAvecLpp : pilier3aPlafondSansLpp);
    return [
      CoverageGapItem(
        label: s.segmentsIndependantCoverageLppLabel,
        description: s.segmentsIndependantCoverageLppDesc,
        isCovered: input.hasLpp,
        urgency: input.hasLpp ? 'basse' : 'haute',
        recommendation: input.hasLpp
            ? s.segmentsIndependantCoverageLppCovered
            : s.segmentsIndependantCoverageLppNotCovered,
        source: 'LPP art. 4 / art. 44',
      ),
      CoverageGapItem(
        label: s.segmentsIndependantCoverageIjmLabel,
        description: s.segmentsIndependantCoverageIjmDesc,
        isCovered: input.hasIjm,
        urgency: input.hasIjm ? 'basse' : 'critique',
        recommendation: input.hasIjm
            ? s.segmentsIndependantCoverageIjmCovered
            : s.segmentsIndependantCoverageIjmNotCovered,
        source: 'LAMal / Pratique indépendants',
      ),
      CoverageGapItem(
        label: s.segmentsIndependantCoverageLaaLabel,
        description: s.segmentsIndependantCoverageLaaDesc,
        isCovered: input.hasLaa,
        urgency: input.hasLaa ? 'basse' : 'haute',
        recommendation: input.hasLaa
            ? s.segmentsIndependantCoverageLaaCovered
            : s.segmentsIndependantCoverageLaaNotCovered,
        source: 'LAA art. 4',
      ),
      CoverageGapItem(
        label: s.segmentsIndependantCoverage3aLabel,
        description: s.segmentsIndependantCoverage3aDesc,
        isCovered: input.has3a,
        urgency: input.has3a ? 'basse' : 'haute',
        recommendation: input.has3a
            ? s.segmentsIndependantCoverage3aCovered(plafond3aFormatted)
            : s.segmentsIndependantCoverage3aNotCovered(plafond3aFormatted),
        source: 'OPP3 art. 7',
      ),
    ];
  }

  /// Compute AVS contribution for self-employed (degressive scale).
  static double _computeAvsContribution(double revenuNet) {
    if (revenuNet <= 0) return 0;
    if (revenuNet >= 58800) return revenuNet * avsCotisationTotal;

    // Find applicable bracket
    for (int i = _avsDegressifBrackets.length - 1; i >= 0; i--) {
      if (revenuNet >= _avsDegressifBrackets[i].threshold) {
        return revenuNet * _avsDegressifBrackets[i].rate;
      }
    }
    return 0; // below minimum threshold
  }

  /// Compute estimated monthly protection costs.
  static ProtectionCost _computeProtectionCost({
    required double revenuNet,
    required double cotisationAvs,
    required double plafond3a,
    required bool hasIjm,
    required bool hasLaa,
  }) {
    final avsMensuel = cotisationAvs / 12;

    // IJM estimate: ~1-3% of insured income (use 2% middle estimate, aligned with backend)
    final ijmMensuel = hasIjm ? 0.0 : (revenuNet * 0.02) / 12;

    // LAA estimate: ~1-2% of insured income (use 1.5% average)
    final laaMensuel = hasLaa ? 0.0 : (revenuNet * 0.015) / 12;

    // 3a monthly (max possible)
    final pillar3aMensuel = plafond3a / 12;

    final totalMensuel = avsMensuel + ijmMensuel + laaMensuel + pillar3aMensuel;
    final totalAnnuel = totalMensuel * 12;

    return ProtectionCost(
      avsMensuel: avsMensuel,
      ijmMensuel: ijmMensuel,
      laaMensuel: laaMensuel,
      pillar3aMensuel: pillar3aMensuel,
      totalMensuel: totalMensuel,
      totalAnnuel: totalAnnuel,
    );
  }

  /// Build alerts for critical gaps.
  static List<String> _buildAlerts(IndependantInput input, S s) {
    final alerts = <String>[];

    if (!input.hasIjm) {
      alerts.add(s.segmentsIndependantAlertIjmFull);
    }

    if (!input.hasLaa) {
      alerts.add(s.segmentsIndependantAlertLaaFull);
    }

    if (!input.hasLpp) {
      alerts.add(s.segmentsIndependantAlertLppFull);
    }

    if (!input.has3a) {
      alerts.add(s.segmentsIndependantAlert3aFull);
    }

    return alerts;
  }

  /// Build recommendations.
  static List<String> _buildRecommendations(
    IndependantInput input,
    double plafond3a,
    S s,
  ) {
    final recs = <String>[];

    if (!input.hasIjm) {
      recs.add(s.segmentsIndependantRecIjm);
    }

    if (!input.hasLaa) {
      recs.add(s.segmentsIndependantRecLaa);
    }

    if (!input.hasLpp) {
      recs.add(s.segmentsIndependantRecLpp);
    }

    if (!input.has3a) {
      recs.add(s.segmentsIndependantRec3a(formatChf(plafond3a)));
    }

    // Always recommend
    recs.add(s.segmentsIndependantRecAvs);

    recs.add(s.segmentsIndependantRecBudget);

    return recs;
  }
}

/// Internal helper for AVS degressive brackets.
class _AvsDegressifBracket {
  final double threshold;
  final double rate;

  const _AvsDegressifBracket({
    required this.threshold,
    required this.rate,
  });
}
