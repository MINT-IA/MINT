import '../models/circle_score.dart';

/// Service de calcul du score de santé financière par cercles
class CircleScoringService {
  /// Calcule le score global à partir des réponses du wizard
  FinancialHealthScore calculateScore(Map<String, dynamic> answers) {
    final circle1 = _scoreCircle1Protection(answers);
    final circle2 = _scoreCircle2Prevoyance(answers);
    final circle3 = _scoreCircle3Croissance(answers);
    final circle4 = _scoreCircle4Optimisation(answers);

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
  CircleScore _scoreCircle1Protection(Map<String, dynamic> answers) {
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
      label: 'Fonds d\'urgence',
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
      label: 'Dettes',
      status: debtStatus,
      detail: hasDebt ? 'Crédits en cours' : 'Aucune dette',
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
      label: 'Revenu',
      status: incomeStatus,
      detail: income != null ? 'CHF ${income.toStringAsFixed(0)}/mois' : null,
      weight: 1.0,
    ));
    totalWeight += 1.0;
    totalScore += incomeStatus.scoreValue * 1.0;

    // 4. Assurances de base (LAMal obligatoire en Suisse)
    items.add(const ScoreItem(
      label: 'Assurances obligatoires',
      status: ItemStatus.perfect,
      detail: 'LAMal active',
      weight: 1.0,
    ));
    totalWeight += 1.0;
    totalScore += 1.0;

    final percentage = (totalScore / totalWeight) * 100;

    return CircleScore(
      circleName: 'Protection & Sécurité',
      circleNumber: 1,
      percentage: percentage,
      level: _percentageToLevel(percentage),
      items: items,
      recommendations: _circle1Recommendations(answers, items),
    );
  }

  /// CERCLE 2 : PRÉVOYANCE
  CircleScore _scoreCircle2Prevoyance(Map<String, dynamic> answers) {
    final items = <ScoreItem>[];
    double totalWeight = 0;
    double totalScore = 0;

    // 1. 3a - Nombre de comptes
    final nb3aAccounts = _parseInt(answers['q_3a_accounts_count']) ?? 0;
    ItemStatus accountStatus;
    String accountDetail;
    if (nb3aAccounts >= 2) {
      accountStatus = ItemStatus.perfect;
      accountDetail = '$nb3aAccounts comptes (optimal)';
    } else if (nb3aAccounts == 1) {
      accountStatus = ItemStatus.warning;
      accountDetail = '1 seul compte (sous-optimal)';
    } else {
      accountStatus = ItemStatus.critical;
      accountDetail = 'Aucun 3a';
    }
    items.add(ScoreItem(
      label: '3a - Optimisation',
      status: accountStatus,
      detail: accountDetail,
      weight: 2.0,
    ));
    totalWeight += 2.0;
    totalScore += accountStatus.scoreValue * 2.0;

    // 2. 3a - Versement maximum
    final contribution3a = _parseDouble(answers['q_3a_annual_contribution']);
    final isSalaried = answers['q_employment_status'] == 'employee';
    final maxContribution = isSalaried ? 7258.0 : 36288.0;

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
      label: '3a - Versement',
      status: contributionStatus,
      detail: contribution3a != null
          ? 'CHF ${contribution3a.toStringAsFixed(0)}/an (max: ${maxContribution.toStringAsFixed(0)})'
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
      label: 'LPP - Rachat',
      status: lppStatus,
      detail: lppBuyback != null && lppBuyback > 0
          ? 'CHF ${lppBuyback.toStringAsFixed(0)} disponibles'
          : 'Aucune lacune',
      weight: 2.0,
    ));
    totalWeight += 2.0;
    totalScore += lppStatus.scoreValue * 2.0;

    // 4. AVS - Lacunes
    final hasAvsGaps = answers['q_avs_gaps'];
    ItemStatus avsStatus;
    if (hasAvsGaps == 'no') {
      avsStatus = ItemStatus.perfect;
    } else if (hasAvsGaps == 'yes') {
      avsStatus = ItemStatus.warning;
    } else {
      avsStatus = ItemStatus.unknown;
    }
    items.add(ScoreItem(
      label: 'AVS',
      status: avsStatus,
      detail: avsStatus == ItemStatus.perfect ? 'Aucune lacune' : 'À vérifier',
      weight: 1.0,
    ));
    totalWeight += 1.0;
    totalScore += avsStatus.scoreValue * 1.0;

    final percentage = (totalScore / totalWeight) * 100;

    return CircleScore(
      circleName: 'Prévoyance Fiscale',
      circleNumber: 2,
      percentage: percentage,
      level: _percentageToLevel(percentage),
      items: items,
      recommendations: _circle2Recommendations(answers, items),
    );
  }

  /// CERCLE 3 : CROISSANCE
  CircleScore _scoreCircle3Croissance(Map<String, dynamic> answers) {
    final items = <ScoreItem>[];
    double totalWeight = 0;
    double totalScore = 0;

    // 1. Investissements hors-pilier
    final hasInvestments = answers['q_has_investments'] == 'yes';
    final investStatus = hasInvestments ? ItemStatus.good : ItemStatus.warning;
    items.add(ScoreItem(
      label: 'Investissements',
      status: investStatus,
      detail: hasInvestments ? 'Actif' : 'Non diversifié',
      weight: 1.0,
    ));
    totalWeight += 1.0;
    totalScore += investStatus.scoreValue * 1.0;

    // 2. Immobilier
    final isOwner = answers['q_housing_status'] == 'owner';
    final ownerStatus = isOwner ? ItemStatus.good : ItemStatus.warning;
    items.add(ScoreItem(
      label: 'Patrimoine immobilier',
      status: ownerStatus,
      detail: isOwner ? 'Propriétaire' : 'Locataire',
      weight: 1.0,
    ));
    totalWeight += 1.0;
    totalScore += ownerStatus.scoreValue * 1.0;

    final percentage = (totalScore / totalWeight) * 100;

    return CircleScore(
      circleName: 'Croissance',
      circleNumber: 3,
      percentage: percentage,
      level: _percentageToLevel(percentage),
      items: items,
      recommendations: _circle3Recommendations(answers, items),
    );
  }

  /// CERCLE 4 : OPTIMISATION
  CircleScore _scoreCircle4Optimisation(Map<String, dynamic> answers) {
    // Simplifié pour l'instant
    return const CircleScore(
      circleName: 'Optimisation & Transmission',
      circleNumber: 4,
      percentage: 20,
      level: ScoreLevel.needsImprovement,
      items: [],
      recommendations: ['Cercles 1-3 à compléter en priorité'],
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
    if (nb3a < 2) {
      reco.add(
          '🚀 Ouvre un 2e compte 3a chez VIAC pour optimiser le retrait futur');
    }

    final lppBuyback = _parseDouble(answers['q_lpp_buyback_available']);
    if (lppBuyback != null && lppBuyback > 50000) {
      reco.add(
          '💰 Planifie un rachat LPP échelonné (économie fiscale majeure)');
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
}
