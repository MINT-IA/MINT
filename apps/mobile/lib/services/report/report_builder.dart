import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_service.dart';
import 'package:mint_mobile/models/goal_template.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/services/wizard_service.dart';
import 'package:mint_mobile/data/cantonal_data.dart';
import 'package:mint_mobile/services/tax_estimator_service.dart';

class ReportBuilder {
  final Map<String, dynamic> answers;

  ReportBuilder(this.answers);

  SessionReport build() {
    final now = DateTime.now();
    final budgetInputs = BudgetInputs.fromMap(answers);
    final budgetService = BudgetService();
    final budgetPlan = budgetService.computePlan(budgetInputs);

    final hasDebt = (answers['q_has_consumer_credit'] == 'yes') ||
        (answers['q_has_leasing'] == 'yes') ||
        ((answers['q_debt_payments_period_chf'] as num?)?.toDouble() ?? 0) >
            0 ||
        WizardService.isSafeModeActive(answers);

    final isSafeModeActive = WizardService.isSafeModeActive(answers);

    // === EXPERTISE SUISSE : CALCUL FISCAL ===
    final cantonCode = answers['q_canton'] ?? 'CH';
    final netIncome = WizardService.getMonthlyIncome(answers);
    final civilStatus = answers['q_civil_status'] ?? 'single';

    int childrenCount = 0;
    try {
      final childrenStr = answers['q_children'] as String? ?? '0';
      childrenCount = int.parse(childrenStr.replaceAll('+', ''));
    } catch (_) {}

    final estimatedTaxMonthly = TaxEstimatorService.estimateMonthlyProvision(
        TaxEstimatorService.estimateAnnualTax(
      netMonthlyIncome: netIncome,
      cantonCode: cantonCode,
      civilStatus: civilStatus,
      childrenCount: childrenCount,
      age: 35,
      isSourceTaxed: false,
    ));

    // === RECOMMANDATIONS ===
    final recommendations = <Recommendation>[];

    // 1. Budget Recommendation
    recommendations.add(Recommendation(
      id: 'reco_budget_mvp',
      kind: 'budget_tool',
      title: 'Maîtriser le Cashflow',
      summary: 'Ton budget disponible pour le mois.',
      why: [
        'Savoir ce qui est vraiment disponible permet d\'éviter le stress.'
      ],
      assumptions: ['Revenus réguliers', 'Charges fixes déclarées exactes'],
      impact: const Impact(amountCHF: 0, period: Period.monthly),
      risks: ['Sous-estimer les dépenses variables'],
      alternatives: [],
      evidenceLinks: [],
      nextActions: [
        const NextAction(
          label: 'Configurer mon Budget',
          type: NextActionType.simulate,
          deepLink: '/budget',
        )
      ],
    ));

    // 2. Debt Recommendation (Safe Mode)
    if (hasDebt) {
      recommendations.insert(
          0,
          Recommendation(
            id: 'reco_debt_safe',
            kind: 'debt_management',
            title: 'Plan de désendettement',
            summary: 'Priorité absolue : réduire la dette.',
            why: [
              'Les intérêts composés jouent contre toi.',
              'Réduit le stress mental'
            ],
            assumptions: [],
            impact: const Impact(amountCHF: 0, period: Period.oneoff),
            risks: ['Intérêts élevés si retard'],
            alternatives: [],
            evidenceLinks: [],
            nextActions: [
              const NextAction(
                  label: 'Lire le guide "Sortir du rouge"',
                  type: NextActionType.learn,
                  deepLink: '/debt/repayment')
            ],
          ));
    }

    // 3. Filler Recommendations
    if (recommendations.length < 3) {
      if (answers['q_has_3a'] != 'yes') {
        recommendations.add(Recommendation(
          id: 'reco_3a_generic',
          kind: 'tax_optimization',
          title: 'Ouvrir un 3e pilier',
          summary: 'Réduis tes impôts dès maintenant.',
          why: ['Économie d\'impôts immédiate (jusqu\'à 2000 CHF/an).'],
          assumptions: ['Revenu imposable suffisant'],
          impact: const Impact(amountCHF: 1500, period: Period.yearly),
          risks: ['Argent bloqué jusqu\'à la retraite'],
          alternatives: ['Compte épargne (fiscalisé)', 'Assurance vie 3b'],
          evidenceLinks: [],
          nextActions: [
            const NextAction(
                label: 'Comparer les offres',
                type: NextActionType.partnerHandoff,
                deepLink: '/pilier-3a')
          ],
        ));
      } else {
        recommendations.add(Recommendation(
          id: 'reco_3a_opt',
          kind: 'tax_optimization',
          title: 'Optimiser ton 3a',
          summary: 'Vérifie tes frais et rendements.',
          why: ['Les frais mangent la performance sur le long terme.'],
          assumptions: [],
          impact: const Impact(amountCHF: 500, period: Period.yearly),
          risks: ['Volatilité des marchés'],
          alternatives: [],
          evidenceLinks: [],
          nextActions: [
            const NextAction(
                label: 'Checklist frais',
                type: NextActionType.checklist,
                deepLink: '/3a-deep/comparator')
          ],
        ));
      }
    }

    // === TOP ACTIONS ===
    final topActions = <TopAction>[];

    // Warning Concubinage (Expert Juridique)
    final isCohabiting = answers['q_civil_status'] == 'cohabiting';
    if (isCohabiting) {
      topActions.add(TopAction(
        effortTag: 'Critique',
        label: 'Protéger ton/ta conjoint·e',
        why: 'En concubinage, 0% protection décès/héritage par défaut.',
        ifThen: 'SI décès ALORS partenaire sans droits.',
        nextAction: const NextAction(
            label: 'Lire guide "Concubinage"',
            type: NextActionType.learn,
            deepLink: '/concubinage'),
      ));
    }

    // Action 1: Debt or Budget
    if (hasDebt) {
      topActions.add(TopAction(
        effortTag: 'Priorité',
        label: 'Stopper l’hémorragie',
        why: 'Tes dettes te coûtent trop cher.',
        ifThen: 'SI dette > 0 ALORS rembourser avant d\'investir.',
        nextAction: const NextAction(
            label: 'Stratégie Avalanche',
            type: NextActionType.simulate,
            deepLink: '/debt/repayment'),
      ));
    } else if (!isCohabiting) {
      // Si pas de warning concubinage, on met le budget en top
      topActions.add(TopAction(
        effortTag: 'Fondation',
        label: 'Sécuriser le Fonds d’Urgence',
        why: 'Pour dormir tranquille.',
        ifThen: 'SI réserve < 3 mois ALORS épargner 10% du revenu.',
        nextAction: const NextAction(
            label: 'Définir montant',
            type: NextActionType.simulate,
            deepLink: '/budget'),
      ));
    }

    // Action 2: Budget Control
    topActions.add(TopAction(
      effortTag: 'Habitude',
      label: 'Ajuster tes enveloppes',
      why: 'Savoir où va l\'argent.',
      ifThen: 'SI dépenses > budget ALORS ajuster lifestyle.',
      nextAction: const NextAction(
          label: 'Voir mon Budget',
          type: NextActionType.simulate,
          deepLink: '/budget'),
    ));

    // Limit to 3
    if (topActions.length > 3) {
      topActions.length = 3;
    }

    // Scoreboard items
    final scoreboard = [
      ScoreboardItem(
        label: "Disponible / mois",
        value: "CHF ${budgetPlan.available.toStringAsFixed(0)}",
        note: "Reste à vivre",
      ),
      ScoreboardItem(
        label: "Impôts Estimés",
        value: "CHF ${estimatedTaxMonthly.toStringAsFixed(0)}",
        note: "Prov. ${CantonalDataService.getByCode(cantonCode).name}",
      ),
      ScoreboardItem(
        label: "Taux d'épargne",
        value:
            "${((budgetPlan.future / (budgetPlan.available > 0 ? budgetPlan.available : 1)) * 100).toStringAsFixed(0)}%",
        note: "Objectif: 20%",
      ),
      ScoreboardItem(
        label: "Score Protection",
        value: isSafeModeActive ? "Faible" : "Bon",
        note: hasDebt ? "Dettes actives" : "Serein",
      ),
    ];

    return SessionReport(
      id: 'local_${now.millisecondsSinceEpoch}',
      sessionId: 'local_session',
      precisionScore: 0.85,
      title: 'Ton Bilan Flash',
      overview: SessionReportOverview(
        canton: answers['q_canton'] ?? 'CH',
        householdType: answers['q_civil_status'] ?? 'Inconnu',
        goalRecommendedLabel: 'Santé Financière',
      ),
      mintRoadmap: MintRoadmap(
        mentorshipLevel: 'Bootcamp',
        natureOfService: 'Éducatif (MVP)',
        limitations: [
          'Basé uniquement sur le déclaratif',
          'Estimation fiscale approximative'
        ],
        assumptions: ['Revenus stables', 'Dépenses lissées'],
        conflicts: [],
      ),
      scoreboard: scoreboard,
      recommendedGoal:
          const GoalTemplate(id: 'financial_health', label: 'Santé Financière'),
      alternativeGoals: [],
      topActions: topActions,
      recommendations: recommendations,
      disclaimers: [
        'Ceci n\'est pas un conseil financier personnalisé.',
        'Les performances passées ne préjugent pas des performances futures.',
        'Vérifie toujours tes capacités de remboursement avant de souscrire un crédit.',
      ],
      generatedAt: now,
    );
  }
}
