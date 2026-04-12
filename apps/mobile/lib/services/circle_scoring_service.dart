import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';

import 'package:mint_mobile/utils/chf_formatter.dart';

import '../models/circle_score.dart';

/// Service de calcul du score de santé financière par cercles
class CircleScoringService {
  static const String disclaimer =
      'Score indicatif de santé financière — outil éducatif qui ne constitue '
      'pas un conseil financier. Ce score repose sur une approche propriétaire MINT '
      'et ne remplace pas l\'avis d\'un·e spécialiste. '
      'Consultez un·e spécialiste pour une analyse personnalisée.';

  static const List<String> sources = [
    'Approche propriétaire MINT — scoring par cercles concentriques',
    'LPP art. 79b (Rachat de prestations — Cercle 2)',
    'OPP3 — plafonds 3a 2025/2026 (Cercle 2)',
    'LAVS art. 29 (Durée de cotisation AVS — Cercle 2)',
    'LAMal art. 61 (Primes et franchise — Cercle 1)',
  ];
  /// Calcule le score global à partir des réponses du wizard.
  /// [l] — optional localizations; when null (e.g. in tests) French fallbacks are used.
  FinancialHealthScore calculateScore(Map<String, dynamic> answers, {S? l}) {
    final circle1 = _scoreCircle1Protection(answers, l);
    final circle2 = _scoreCircle2Prevoyance(answers, l);
    final circle3 = _scoreCircle3Croissance(answers, l);
    final circle4 = _scoreCircle4Optimisation(l);

    // Score global = moyenne pondérée (Cercles 1-2 plus importants)
    final overall = (circle1.percentage * 0.35) +
        (circle2.percentage * 0.35) +
        (circle3.percentage * 0.20) +
        (circle4.percentage * 0.10);

    final priorities =
        _generateTopPriorities([circle1, circle2, circle3, circle4]);

    return FinancialHealthScore(
      circle1Protection: circle1,
      circle2Prevoyance: circle2,
      circle3Croissance: circle3,
      circle4Optimisation: circle4,
      overallScore: overall,
      topPriorities: priorities,
    );
  }

  /// CERCLE 1 : PROTECTION
  CircleScore _scoreCircle1Protection(Map<String, dynamic> answers, S? l) {
    final items = <ScoreItem>[];
    double totalWeight = 0;
    double totalScore = 0;

    // 1. Fonds d'urgence
    final hasEmergencyFund = answers['q_emergency_fund'] as String?;
    ItemStatus fundStatus;
    if (hasEmergencyFund == 'yes_6months') {
      fundStatus = ItemStatus.perfect;
    } else if (hasEmergencyFund == 'yes_3months') {
      fundStatus = ItemStatus.good;
    } else {
      fundStatus = ItemStatus.critical;
    }
    items.add(ScoreItem(
      label: l?.circleLabelEmergencyFund ?? 'Fonds d\'urgence',
      status: fundStatus,
      detail: _emergencyFundDetail(hasEmergencyFund),
      weight: 2.0, // Double importance
    ));
    totalWeight += 2.0;
    totalScore += fundStatus.scoreValue * 2.0;

    // 2. Dettes de consommation
    final hasDebt = answers['q_has_consumer_debt'] == 'yes';
    final debtStatus = hasDebt ? ItemStatus.critical : ItemStatus.perfect;
    items.add(ScoreItem(
      label: l?.circleLabelDettes ?? 'Dettes',
      status: debtStatus,
      detail: hasDebt ? 'Crédits en cours' : 'Aucune dette', // Internal detail — not extracted
      weight: 1.5,
    ));
    totalWeight += 1.5;
    totalScore += debtStatus.scoreValue * 1.5;

    // 3. Revenu stable
    final income = answers['q_net_income_period_chf'] as num?;
    final incomeStatus = (income != null && income > 0)
        ? ItemStatus.perfect
        : ItemStatus.unknown;
    items.add(ScoreItem(
      label: l?.circleLabelRevenu ?? 'Revenu',
      status: incomeStatus,
      detail: income != null ? '${formatChfWithPrefix(income.toDouble())}/mois' : null, // Formatted number — not extracted
      weight: 1.0,
    ));
    totalWeight += 1.0;
    totalScore += incomeStatus.scoreValue * 1.0;

    // 4. Assurances de base (LAMal obligatoire en Suisse)
    items.add(ScoreItem(
      label: l?.circleLabelAssurancesObligatoires ?? 'Assurances obligatoires',
      status: ItemStatus.perfect,
      detail: 'LAMal active', // Legal identifier — not extracted
      weight: 1.0,
    ));
    totalWeight += 1.0;
    totalScore += 1.0;

    final percentage = (totalScore / totalWeight) * 100;

    return CircleScore(
      circleName: l?.circleNameProtection ?? 'Protection & Sécurité',
      circleNumber: 1,
      percentage: percentage,
      level: _percentageToLevel(percentage),
      items: items,
      recommendations: _circle1Recommendations(answers, items),
    );
  }

  /// CERCLE 2 : PRÉVOYANCE
  CircleScore _scoreCircle2Prevoyance(Map<String, dynamic> answers, S? l) {
    final items = <ScoreItem>[];
    double totalWeight = 0;
    double totalScore = 0;

    // 1. 3a - Nombre de comptes
    final nb3aAccounts = _parseInt(answers['q_3a_accounts_count']) ?? 0;
    ItemStatus accountStatus;
    String accountDetail;
    if (nb3aAccounts >= 2) {
      accountStatus = ItemStatus.perfect;
      accountDetail = '$nb3aAccounts comptes (adapte)';
    } else if (nb3aAccounts == 1) {
      accountStatus = ItemStatus.warning;
      accountDetail = '1 seul compte (a diversifier)';
    } else {
      accountStatus = ItemStatus.critical;
      accountDetail = 'Aucun 3a';
    }
    items.add(ScoreItem(
      label: l?.circleLabelTroisaOptimisation ?? '3a - Optimisation',
      status: accountStatus,
      detail: accountDetail,
      weight: 2.0,
    ));
    totalWeight += 2.0;
    totalScore += accountStatus.scoreValue * 2.0;

    // 2. 3a - Versement maximum
    final contribution3a = _parseDouble(answers['q_3a_annual_contribution']);
    final isSalaried = answers['q_employment_status'] == 'employee';
    final maxContribution = isSalaried ? reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp) : reg('pillar3a.max_without_lpp', pilier3aPlafondSansLpp);

    ItemStatus contributionStatus;
    if (contribution3a != null && contribution3a >= maxContribution * 0.9) {
      contributionStatus = ItemStatus.perfect;
    } else if (contribution3a != null &&
        contribution3a >= maxContribution * 0.5) {
      contributionStatus = ItemStatus.good;
    } else if (contribution3a != null && contribution3a > 0) {
      contributionStatus = ItemStatus.warning;
    } else {
      contributionStatus = ItemStatus.critical;
    }
    items.add(ScoreItem(
      label: l?.circleLabelTroisaVersement ?? '3a - Versement',
      status: contributionStatus,
      detail: contribution3a != null
          ? '${formatChfWithPrefix(contribution3a)}/an (max: ${formatChf(maxContribution)})'
          : 'Non renseigné',
      weight: 1.5,
    ));
    totalWeight += 1.5;
    totalScore += contributionStatus.scoreValue * 1.5;

    // 3. LPP - Rachat
    final lppBuyback = _parseDouble(answers['q_lpp_buyback_available']);
    ItemStatus lppStatus;
    if (lppBuyback != null && lppBuyback > 0) {
      lppStatus =
          ItemStatus.good; // Opportunité disponible mais pas encore exploitée
    } else if (lppBuyback == 0) {
      lppStatus = ItemStatus.perfect; // Pas de lacune = parfait
    } else {
      lppStatus = ItemStatus.unknown;
    }
    items.add(ScoreItem(
      label: l?.circleLabelLppRachat ?? 'LPP - Rachat',
      status: lppStatus,
      detail: lppBuyback != null && lppBuyback > 0
          ? '${formatChfWithPrefix(lppBuyback)} disponibles'
          : 'Aucune lacune',
      weight: 2.0,
    ));
    totalWeight += 2.0;
    totalScore += lppStatus.scoreValue * 2.0;

    // 4. AVS - Lacunes (logique experte : triage + calcul intelligent)
    // CHAOS-78: Never default to 1990 — unknown birthYear = null, skip AVS gap calc.
    final birthYear = _parseInt(answers['q_birth_year']);
    final civilStatus = answers['q_civil_status'];
    final avsGapYears = birthYear != null ? _calculateAvsGaps(answers, birthYear) : null;

    // Fallback vers les réponses legacy (q_first_employment_year, q_avs_gaps)
    final legacyFirstEmployment = _parseInt(answers['q_first_employment_year']);
    final legacyAvsYears = _parseInt(answers['q_avs_contribution_years']);
    final legacyHasGaps = answers['q_avs_gaps'];

    ItemStatus avsStatus;
    String avsDetail;

    if (avsGapYears != null) {
      // Nouvelle logique experte
      final gap = avsGapYears;
      final theoreticalYears = _theoreticalAvsYears(birthYear!);
      final contributionYears = (theoreticalYears - gap).clamp(0, 44);
      if (gap <= 0) {
        avsStatus = ItemStatus.perfect;
        avsDetail = 'Cotisation complète ($contributionYears ans)';
      } else if (gap <= 2) {
        avsStatus = ItemStatus.good;
        avsDetail = 'Lacune mineure ($gap ans — rente -${AvsCalculator.reductionPercentageFromGap(gap).toStringAsFixed(1)}%)';
      } else {
        avsStatus = ItemStatus.warning;
        avsDetail = 'Lacune de $gap ans (rente -${AvsCalculator.reductionPercentageFromGap(gap).toStringAsFixed(1)}%)';
      }
    } else if (legacyFirstEmployment != null) {
      // Fallback legacy : q_first_employment_year
      final startYear = birthYear != null
          ? [legacyFirstEmployment, birthYear + 21].reduce((a, b) => a > b ? a : b)
          : legacyFirstEmployment;
      final years = (DateTime.now().year - startYear).clamp(0, 44);
      final gap = 44 - years;
      if (gap <= 0) {
        avsStatus = ItemStatus.perfect;
        avsDetail = 'Cotisation complète ($years ans)';
      } else if (gap <= 2) {
        avsStatus = ItemStatus.good;
        avsDetail = 'Lacune mineure ($gap ans)';
      } else {
        avsStatus = ItemStatus.warning;
        avsDetail = 'Lacune de $gap ans (rente -${AvsCalculator.reductionPercentageFromGap(gap).toStringAsFixed(1)}%)';
      }
    } else if (legacyAvsYears != null) {
      final gap = 44 - legacyAvsYears;
      if (gap <= 0) {
        avsStatus = ItemStatus.perfect;
        avsDetail = 'Cotisation complète ($legacyAvsYears ans)';
      } else {
        avsStatus = ItemStatus.warning;
        avsDetail = 'Lacune de $gap ans';
      }
    } else if (legacyHasGaps == 'no') {
      avsStatus = ItemStatus.perfect;
      avsDetail = 'Aucune lacune déclarée';
    } else if (legacyHasGaps == 'yes' || legacyHasGaps == 'maybe') {
      avsStatus = ItemStatus.warning;
      avsDetail = legacyHasGaps == 'yes' ? 'Lacunes confirmées' : 'Lacunes possibles';
    } else if (answers['q_avs_lacunes_status'] == 'unknown') {
      avsStatus = ItemStatus.warning;
      avsDetail = 'Lacunes possibles — commande ton extrait CI';
    } else {
      avsStatus = ItemStatus.unknown;
      avsDetail = 'À vérifier';
    }

    // Conjoint — même logique experte
    if (civilStatus == 'married') {
      final spouseGapYears = birthYear != null ? _calculateSpouseAvsGaps(answers, birthYear) : null;

      // Fallback legacy conjoint
      final legacySpouseFirstEmployment = _parseInt(answers['q_spouse_first_employment_year']);
      final legacySpouseAvsYears = _parseInt(answers['q_spouse_avs_contribution_years']);

      int? spouseGap;
      if (spouseGapYears != null) {
        spouseGap = spouseGapYears;
      } else if (legacySpouseFirstEmployment != null) {
        final spouseStart = birthYear != null
            ? [legacySpouseFirstEmployment, birthYear + 21].reduce((a, b) => a > b ? a : b)
            : legacySpouseFirstEmployment;
        final years = (DateTime.now().year - spouseStart).clamp(0, 44);
        spouseGap = 44 - years;
      } else if (legacySpouseAvsYears != null) {
        spouseGap = 44 - legacySpouseAvsYears;
      }

      if (spouseGap != null && spouseGap > 0) {
        avsDetail += ' | Conjoint·e : lacune $spouseGap ans';
        if (avsStatus == ItemStatus.perfect || avsStatus == ItemStatus.good) {
          avsStatus = ItemStatus.warning;
        }
      }
    }

    items.add(ScoreItem(
      label: l?.circleLabelAvs ?? 'AVS',
      status: avsStatus,
      detail: avsDetail,
      weight: 1.0,
    ));
    totalWeight += 1.0;
    totalScore += avsStatus.scoreValue * 1.0;

    final percentage = (totalScore / totalWeight) * 100;

    return CircleScore(
      circleName: l?.circleNamePrevoyance ?? 'Prévoyance Fiscale',
      circleNumber: 2,
      percentage: percentage,
      level: _percentageToLevel(percentage),
      items: items,
      recommendations: _circle2Recommendations(answers, items),
    );
  }

  /// CERCLE 3 : CROISSANCE
  CircleScore _scoreCircle3Croissance(Map<String, dynamic> answers, S? l) {
    final items = <ScoreItem>[];
    double totalWeight = 0;
    double totalScore = 0;

    // 1. Investissements hors-pilier
    final hasInvestments = answers['q_has_investments'] == 'yes';
    final investStatus = hasInvestments ? ItemStatus.good : ItemStatus.warning;
    items.add(ScoreItem(
      label: l?.circleLabelInvestissements ?? 'Investissements',
      status: investStatus,
      detail: hasInvestments ? 'Actif' : 'Non diversifié', // Internal detail — not extracted
      weight: 1.0,
    ));
    totalWeight += 1.0;
    totalScore += investStatus.scoreValue * 1.0;

    // 2. Immobilier
    final isOwner = answers['q_housing_status'] == 'owner';
    final ownerStatus = isOwner ? ItemStatus.good : ItemStatus.warning;
    items.add(ScoreItem(
      label: l?.circleLabelPatrimoineImmobilier ?? 'Patrimoine immobilier',
      status: ownerStatus,
      detail: isOwner ? 'Propriétaire' : 'Locataire', // Internal detail — not extracted
      weight: 1.0,
    ));
    totalWeight += 1.0;
    totalScore += ownerStatus.scoreValue * 1.0;

    final percentage = (totalScore / totalWeight) * 100;

    return CircleScore(
      circleName: l?.circleNameCroissance ?? 'Croissance',
      circleNumber: 3,
      percentage: percentage,
      level: _percentageToLevel(percentage),
      items: items,
      recommendations: _circle3Recommendations(answers, items),
    );
  }

  /// CERCLE 4 : OPTIMISATION
  CircleScore _scoreCircle4Optimisation(S? l) {
    // Simplifié pour l'instant
    return CircleScore(
      circleName: l?.circleNameOptimisation ?? 'Optimisation & Transmission',
      circleNumber: 4,
      percentage: 20,
      level: ScoreLevel.needsImprovement,
      items: const [],
      recommendations: const ['Cercles 1-3 à compléter en priorité'], // Internal — not extracted
    );
  }

  /// Helpers
  ScoreLevel _percentageToLevel(double percentage) {
    if (percentage >= 90) return ScoreLevel.excellent;
    if (percentage >= 70) return ScoreLevel.good;
    if (percentage >= 50) return ScoreLevel.adequate;
    if (percentage >= 30) return ScoreLevel.needsImprovement;
    return ScoreLevel.critical;
  }

  String _emergencyFundDetail(String? answer) {
    switch (answer) {
      case 'yes_6months':
        return '6+ mois de charges';
      case 'yes_3months':
        return '3-6 mois de charges';
      default:
        return 'Moins de 3 mois';
    }
  }

  List<String> _circle1Recommendations(
      Map<String, dynamic> answers, List<ScoreItem> items) {
    final reco = <String>[];

    final hasEmergencyFund = answers['q_emergency_fund'];
    if (hasEmergencyFund != 'yes_6months') {
      reco.add('Constitue un fonds d\'urgence de 6 mois de charges');
    }

    if (answers['q_has_consumer_debt'] == 'yes') {
      reco.add('⚠️ PRIORITÉ : Rembourse tes dettes avant d\'investir');
    }

    return reco;
  }

  List<String> _circle2Recommendations(
      Map<String, dynamic> answers, List<ScoreItem> items) {
    final reco = <String>[];

    final nb3a = _parseInt(answers['q_3a_accounts_count']) ?? 0;
    if (nb3a == 0) {
      reco.add(
          'Ouvre ton premier compte 3a pour profiter de la déduction fiscale');
    } else if (nb3a == 1) {
      reco.add(
          '🚀 Ouvre un 2e compte 3a auprès d\u2019un prestataire fintech pour optimiser le retrait futur');
    }

    final lppBuyback = _parseDouble(answers['q_lpp_buyback_available']);
    if (lppBuyback != null && lppBuyback > 50000) {
      reco.add(
          '💰 Planifie un rachat LPP échelonné (économie fiscale majeure)');
    }

    // Recommandations AVS basées sur la nouvelle logique de lacunes
    final avsStatus = answers['q_avs_lacunes_status'];
    if (avsStatus == 'unknown') {
      reco.add(
          'Commande ton extrait de compte individuel (CI) gratuit sur inforegister.ch pour vérifier tes lacunes AVS');
    }
    // CHAOS-78: Never default to 1990 — skip AVS gap calc if birth year unknown.
    final birthYear = _parseInt(answers['q_birth_year']);
    final gapYears = birthYear != null ? _calculateAvsGaps(answers, birthYear) : null;
    if (gapYears != null && gapYears > 0) {
      reco.add(
          'Tu peux racheter les 5 dernières années de lacune AVS auprès de ta caisse cantonale (LAVS art. 16)');
    }

    return reco;
  }

  List<String> _circle3Recommendations(
      Map<String, dynamic> answers, List<ScoreItem> items) {
    return [
      'Développe ta stratégie d\'investissement une fois Cercles 1-2 optimisés'
    ];
  }

  List<String> _generateTopPriorities(List<CircleScore> circles) {
    final priorities = <String>[];

    // Extraire les recommandations de chaque cercle
    for (final circle in circles) {
      priorities.addAll(circle.recommendations);
    }

    // Limiter aux 3 plus importantes
    return priorities.take(3).toList();
  }

  int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Années théoriques de cotisation AVS depuis l'âge de 21 ans.
  /// Échelle complète = 44 ans (LAVS art. 29ter).
  int _theoreticalAvsYears(int birthYear) {
    return (DateTime.now().year - (birthYear + 21)).clamp(0, 44);
  }

  /// Calcule le nombre d'années de lacune AVS depuis les nouvelles questions.
  /// Retourne null si les nouvelles questions n'ont pas été répondues (fallback legacy).
  int? _calculateAvsGaps(Map<String, dynamic> answers, int birthYear) =>
      calculateAvsGapsFromAnswers(answers, birthYear);

  int? _calculateSpouseAvsGaps(Map<String, dynamic> answers, int birthYear) =>
      calculateSpouseAvsGapsFromAnswers(answers, birthYear);

  // ── Shared AVS gap helpers (used by CircleScoringService + FinancialReportService) ──

  /// Calculates AVS gap years from triage answers (LAVS art. 29ter).
  /// Public static so FinancialReportService can reuse without duplication.
  static int? calculateAvsGapsFromAnswers(
      Map<String, dynamic> answers, int birthYear) {
    final status = answers['q_avs_lacunes_status'];
    if (status == null) return null;

    switch (status) {
      case 'no_gaps':
        return 0;
      case 'arrived_late':
        final arrivalYear = _parseIntStatic(answers['q_avs_arrival_year']);
        if (arrivalYear == null) return null;
        // Lacunes = années entre 21 ans et l'arrivée en Suisse
        final avsStartAge21 = birthYear + 21;
        return (arrivalYear - avsStartAge21).clamp(0, 44);
      case 'lived_abroad':
        return _parseIntStatic(answers['q_avs_years_abroad']) ?? 0;
      case 'unknown':
        // On ne peut pas calculer précisément, mais on signale le risque
        return null;
      default:
        return null;
    }
  }

  /// Same logic for spouse.
  static int? calculateSpouseAvsGapsFromAnswers(
      Map<String, dynamic> answers, int birthYear) {
    final status = answers['q_spouse_avs_lacunes_status'];
    if (status == null) return null;

    switch (status) {
      case 'no_gaps':
        return 0;
      case 'arrived_late':
        final arrivalYear =
            _parseIntStatic(answers['q_spouse_avs_arrival_year']);
        if (arrivalYear == null) return null;
        final avsStartAge21 = birthYear + 21;
        return (arrivalYear - avsStartAge21).clamp(0, 44);
      case 'lived_abroad':
        return _parseIntStatic(answers['q_spouse_avs_years_abroad']) ?? 0;
      case 'unknown':
        return null;
      default:
        return null;
    }
  }

  static int? _parseIntStatic(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    return null;
  }
}
