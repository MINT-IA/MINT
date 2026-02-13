import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/models/profile.dart';

/// Service de génération de recommandations personnalisées
///
/// Génère des recommandations financières basées sur :
/// - Le profil utilisateur (revenus, statut emploi, objectifs)
/// - L'état actuel (dettes, épargne, LPP)
/// - Les opportunités fiscales (3a, LPP, etc.)
///
/// Utilisé dans NowTab pour afficher les actions recommandées
class RecommendationsService {
  RecommendationsService._();

  static const String disclaimer =
      'Suggestions pédagogiques basées sur ton profil — outil éducatif '
      'qui ne constitue pas un conseil financier personnalisé au sens de la LSFin. '
      'Consultez un·e spécialiste pour une analyse adaptée à ta situation.';

  static const List<String> sources = [
    'LSFin art. 3 (Définition du conseil en placement)',
    'OPP3 — plafonds 3a 2025/2026',
    'LPP art. 79b (Rachat de prestations)',
    'LIFD art. 33 al. 1 let. e (Déduction 3a)',
  ];

  /// Génère les recommandations pour un profil donné
  ///
  /// Retourne une liste de recommandations triées par priorité :
  /// 1. Protection (si dettes ou pas de fonds d'urgence)
  /// 2. Optimisation fiscale (3a, LPP)
  /// 3. Croissance (investissements)
  static List<Recommendation> generateRecommendations({
    required Profile? profile,
    int maxRecommendations = 3,
  }) {
    final recommendations = <Recommendation>[];

    // Si pas de profil, recommandations génériques
    if (profile == null) {
      return _getGenericRecommendations();
    }

    // 1. Protection : Fonds d'urgence si dettes ou revenus faibles
    if (profile.hasDebt || (profile.totalSavings ?? 0) < 3000) {
      recommendations.add(_buildEmergencyFundRecommendation(profile));
    }

    // 2. Optimisation fiscale : 3a si éligible
    if (_isEligibleFor3a(profile)) {
      recommendations.add(_build3aRecommendation(profile));
    }

    // 3. LPP : Rachat si salarié avec LPP
    if (_isEligibleForLppBuyback(profile)) {
      recommendations.add(_buildLppBuybackRecommendation(profile));
    }

    // 4. Croissance : Intérêts composés si épargne régulière
    if ((profile.savingsMonthly ?? 0) > 0) {
      recommendations.add(_buildCompoundInterestRecommendation(profile));
    }

    // Limiter au nombre max et trier par priorité
    return recommendations.take(maxRecommendations).toList();
  }

  /// Vérifie si le profil est éligible au 3a
  static bool _isEligibleFor3a(Profile profile) {
    // Éligible si :
    // - A des revenus
    // - Pas en mode protection (dettes)
    // - Statut emploi connu
    return (profile.incomeGrossYearly ?? 0) > 0 &&
        !profile.hasDebt &&
        profile.employmentStatus != null;
  }

  /// Vérifie si éligible au rachat LPP
  static bool _isEligibleForLppBuyback(Profile profile) {
    // Éligible si :
    // - Salarié avec LPP
    // - Revenus suffisants
    return profile.employmentStatus == EmploymentStatus.employee &&
        (profile.has2ndPillar ?? false) &&
        (profile.incomeGrossYearly ?? 0) > 80000;
  }

  /// Recommandation : Fonds d'urgence
  static Recommendation _buildEmergencyFundRecommendation(Profile profile) {
    final currentSavings = profile.totalSavings ?? 0;
    final target = 3000.0;
    final remaining = target - currentSavings;

    return Recommendation(
      id: 'emergency_fund',
      kind: 'protection',
      title: 'Constituer un fonds d\'urgence',
      summary:
          'CHF ${remaining.toStringAsFixed(0)} restants pour sécuriser ton budget.',
      why: [
        'Protection contre les imprévus',
        'Évite de s\'endetter en cas de coup dur',
        'Recommandé : 3 mois de dépenses',
      ],
      assumptions: ['Objectif : CHF 3\'000', 'Épargne progressive'],
      impact: Impact(amountCHF: remaining, period: Period.oneoff),
      risks: ['Inflation réduit la valeur'],
      alternatives: ['Compte épargne', '3a (moins liquide)'],
      evidenceLinks: [],
      nextActions: [
        const NextAction(
          type: NextActionType.simulate,
          label: 'Calculer mon plan d\'épargne',
        ),
      ],
    );
  }

  /// Recommandation : Pilier 3a
  static Recommendation _build3aRecommendation(Profile profile) {
    // Estimation économie fiscale (taux marginal ~25%)
    final limit = pilier3aPlafondAvecLpp; // Limite 2025 avec LPP
    final taxSavings = limit * 0.25;

    return Recommendation(
      id: 'pillar3a',
      kind: 'pillar3a',
      title: 'Optimiser avec le 3a',
      summary:
          'Économise jusqu\'à CHF ${taxSavings.toStringAsFixed(0)}/an d\'impôts.',
      why: [
        'Déduction fiscale immédiate',
        'Rendement supérieur au compte épargne',
        'Préparation retraite',
      ],
      assumptions: [
        'Taux marginal 25%',
        'Versement maximal CHF ${limit.toStringAsFixed(0)}',
      ],
      impact: Impact(amountCHF: taxSavings, period: Period.yearly),
      risks: ['Capital bloqué jusqu\'à la retraite'],
      alternatives: ['3a bancaire', '3a assurance', '3a titres'],
      evidenceLinks: [],
      nextActions: [
        const NextAction(
          type: NextActionType.simulate,
          label: 'Calculer mon économie 3a',
        ),
      ],
    );
  }

  /// Recommandation : Rachat LPP
  static Recommendation _buildLppBuybackRecommendation(Profile profile) {
    final estimatedSavings = 850.0; // Estimation conservative

    return Recommendation(
      id: 'lpp_buyback',
      kind: 'lpp',
      title: 'Simuler un rachat LPP',
      summary:
          'Potentiel : CHF ${estimatedSavings.toStringAsFixed(0)}/an d\'économie fiscale.',
      why: [
        'Déduction fiscale importante',
        'Améliore ta rente future',
        'Stratégie avancée d\'optimisation',
      ],
      assumptions: [
        'Lacune de prévoyance existante',
        'Taux marginal 25%',
      ],
      impact: Impact(amountCHF: estimatedSavings, period: Period.yearly),
      risks: [
        'Capital bloqué dans la LPP',
        'Nécessite liquidités disponibles',
      ],
      alternatives: ['3a d\'abord', 'Investissement libre'],
      evidenceLinks: [],
      nextActions: [
        const NextAction(
          type: NextActionType.simulate,
          label: 'Simuler mon rachat LPP',
        ),
      ],
    );
  }

  /// Recommandation : Intérêts composés
  static Recommendation _buildCompoundInterestRecommendation(Profile profile) {
    final monthlySavings = profile.savingsMonthly ?? 500;
    final years = 20;
    final rate = 0.05; // 5% annuel

    // Calcul intérêts composés
    final futureValue =
        monthlySavings * 12 * ((pow(1 + rate, years) - 1) / rate) * (1 + rate);
    final totalInvested = monthlySavings * 12 * years;
    final interestGained = futureValue - totalInvested;

    return Recommendation(
      id: 'compound_interest',
      kind: 'compound_interest',
      title: 'Le pouvoir du temps',
      summary:
          'CHF ${monthlySavings.toStringAsFixed(0)}/mois à 5% = CHF ${futureValue.toStringAsFixed(0)} en $years ans.',
      why: [
        'Les intérêts composés travaillent pour toi',
        'Commencer tôt maximise l\'effet',
        'Croissance exponentielle',
      ],
      assumptions: [
        'Rendement 5%/an',
        'Versements réguliers CHF ${monthlySavings.toStringAsFixed(0)}/mois',
      ],
      impact: Impact(amountCHF: interestGained, period: Period.oneoff),
      risks: ['Volatilité du marché', 'Rendement non garanti'],
      alternatives: ['Compte épargne', 'Pilier 3a', 'ETF'],
      evidenceLinks: [],
      nextActions: [
        const NextAction(
          type: NextActionType.simulate,
          label: 'Simuler mes intérêts',
        ),
      ],
    );
  }

  /// Recommandations génériques (si pas de profil)
  static List<Recommendation> _getGenericRecommendations() {
    return [
      Recommendation(
        id: 'start_advisor',
        kind: 'onboarding',
        title: 'Commence ton diagnostic',
        summary: 'Découvre ta situation en 5 minutes.',
        why: [
          'Comprends ta situation financière',
          'Reçois des recommandations personnalisées',
          'Gratuit et confidentiel',
        ],
        assumptions: [],
        impact: const Impact(amountCHF: 0, period: Period.oneoff),
        risks: [],
        alternatives: [],
        evidenceLinks: [],
        nextActions: [
          const NextAction(
            type: NextActionType.checklist,
            label: 'Lancer ma session',
          ),
        ],
      ),
    ];
  }
}
