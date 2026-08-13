import 'package:mint_mobile/models/mint_next_domicile_fact.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/domain/budget/budget_inputs.dart';
import 'package:mint_mobile/domain/budget/budget_service.dart';
import 'package:mint_mobile/domain/budget/present_budget_builder.dart';
import 'package:mint_mobile/models/goal_template.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/models/session.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/wizard_service.dart';
import 'package:mint_mobile/data/cantonal_data.dart';

class ReportBuilder {
  final Map<String, dynamic> answers;

  ReportBuilder(this.answers);

  SessionReport build() {
    final now = DateTime.now();
    final budgetInputs = BudgetInputs.fromMap(answers);
    final budgetService = BudgetService();
    final budgetPlan = budgetService.computePlan(budgetInputs);
    final presentBudget = PresentBudgetBuilder.fromInputs(
      inputs: budgetInputs,
      plan: budgetPlan,
    );

    final hasDebt = (answers['q_has_consumer_credit'] == 'yes') ||
        (answers['q_has_consumer_debt'] == 'yes') ||
        (answers['q_has_leasing'] == 'yes') ||
        budgetInputs.debtPayments > 0;

    final isSafeModeActive = WizardService.isSafeModeActive(answers);

    // === EXPERTISE SUISSE : CALCUL FISCAL ===
    final hasSwissDomicile =
        MintNextDomicileFact.hasSwissTaxDomicileIn(answers);
    // « CH » n'est pas un canton. Quand il manque, on ne le remplace par rien :
    // les surfaces qui l'affichent doivent montrer une absence, pas un
    // pseudo-code qui a l'air d'en être un.
    final cantonCode = answers['q_canton'] ?? (hasSwissDomicile ? 'CH' : '');
    final estimatedTaxMonthly = budgetInputs.taxProvision;
    // L'économie d'impôt d'un versement 3a se calcule sur un barème
    // cantonal. Sans canton, il n'y a pas de barème — et un chiffre produit
    // sur le pseudo-canton « CH » serait faux tout en ayant l'air vrai.
    final first3aTaxImpact = hasSwissDomicile
        ? _estimateRemaining3aTaxImpact(
            budgetInputs: budgetInputs,
            cantonCode: cantonCode.toString(),
          )
        : 0.0;

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
      final raw3aTotal = answers['q_3a_total'];
      final raw3aAnnual = answers['q_3a_annual_contribution'];
      final rawCoachTotal3a = answers['_coach_total_3a'];
      final has3a = answers['q_has_3a'] == true ||
          answers['q_has_3a'] == 'yes' ||
          (_parseDouble(raw3aTotal) ?? 0) > 0 ||
          (_parseDouble(raw3aAnnual) ?? 0) > 0 ||
          (_parseDouble(rawCoachTotal3a) ?? 0) > 0;
      if (!has3a) {
        recommendations.add(Recommendation(
          id: 'reco_3a_generic',
          kind: 'tax_optimization',
          title: 'Envisager un 3e pilier', // lint-ignore: no_hardcoded_fr (dette i18n préexistante, LOT 3)
          summary: 'Estime ta marge 3a avec ton revenu et ton canton.',
          why: [
            first3aTaxImpact > 0
                ? 'Impact fiscal estimé avec le calculateur fiscal Mint.'
                : 'Impact fiscal à confirmer quand le revenu imposable est disponible.'
          ],
          assumptions: ['Revenu imposable et affiliation LPP à vérifier'],
          impact: Impact(amountCHF: first3aTaxImpact, period: Period.yearly),
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
          summary: 'Vérifie tes frais, ton risque et ta marge déductible.',
          why: ['Les frais mangent la performance sur le long terme.'],
          assumptions: [],
          impact: const Impact(amountCHF: 0, period: Period.yearly),
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
        value: "CHF ${presentBudget.monthlyFree.toStringAsFixed(0)}",
        note: "Reste à vivre",
      ),
      ScoreboardItem(
        label: "Impôts Estimés",
        value: "CHF ${estimatedTaxMonthly.toStringAsFixed(0)}",
        note: "Prov. ${CantonalDataService.getByCode(cantonCode).name}",
      ),
      ScoreboardItem(
        label: "Taux d'épargne",
        // Savings rate is conventionally monthly savings over net income.
        // Do not divide by BudgetPlan.available: it is clamped allocation room.
        value: presentBudget.monthlyNet > 0
            ? "${((presentBudget.monthlySavings / presentBudget.monthlyNet) * 100).toStringAsFixed(0)}%"
            : "0%",
        note: "Objectif: 20%",
      ),
      ScoreboardItem(
        label: "Score Protection",
        value: isSafeModeActive ? "Faible" : "Bon",
        note: hasDebt
            ? "Dettes actives"
            : isSafeModeActive
                ? "Réserve à renforcer"
                : "Serein",
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
        'Vérifie toujours tes capacités de remboursement avant de t\'engager dans un crédit.', // lint-ignore: no_hardcoded_fr (dette i18n préexistante, LOT 3)
      ],
      generatedAt: now,
    );
  }

  double _estimateRemaining3aTaxImpact({
    required BudgetInputs budgetInputs,
    required String cantonCode,
  }) {
    if (budgetInputs.netIncome <= 0) return 0;

    final children = _parseInt(answers['q_children']) ?? 0;
    final civilStatus =
        (answers['q_civil_status']?.toString() ?? 'single').toLowerCase();
    final isMarried = civilStatus == 'married' ||
        civilStatus == 'marie' ||
        civilStatus == 'marié';
    final age = CoachProfile.fromWizardAnswers(answers).ageOrNull;
    if (age == null) return 0;
    final employmentStatus =
        answers['q_employment_status']?.toString().toLowerCase() ?? 'employee';
    final isIndependent = {
      'independant',
      'independent',
      'self_employed',
      'self-employed',
    }.contains(employmentStatus);
    final independentProfessionalAnnual =
        _parseDouble(answers['q_self_employed_net_income_annual_chf']);

    final grossAnnualSalary = NetIncomeBreakdown.estimateBrutFromNet(
      budgetInputs.netIncome * 12,
      age: age,
      canton: cantonCode.isNotEmpty ? cantonCode : 'ZH',
      etatCivil: isMarried ? 'marie' : 'celibataire',
      nombreEnfants: children,
    );
    if (grossAnnualSalary <= 0) return 0;

    final hasLpp = !isIndependent &&
        grossAnnualSalary >= reg('lpp.entry_threshold', lppSeuilEntree);
    final annualIncomeFor3a = isIndependent &&
            independentProfessionalAnnual != null &&
            independentProfessionalAnnual.isFinite &&
            independentProfessionalAnnual > 0
        ? independentProfessionalAnnual
        : grossAnnualSalary;
    final annualCeiling = hasLpp
        ? reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp)
        : (annualIncomeFor3a * pilier3aTauxRevenuSansLpp)
            .clamp(0.0, pilier3aPlafondSansLpp);
    final alreadyContributed = _current3aContribution();
    final remainingContribution = annualCeiling - alreadyContributed;
    if (remainingContribution <= 0) return 0;

    final impact = RetirementTaxCalculator.estimate3aTaxImpact(
      grossAnnualSalary: annualIncomeFor3a,
      canton: cantonCode.isNotEmpty ? cantonCode : 'ZH',
      isMarried: isMarried,
      children: children,
      hasLpp: hasLpp,
      contribution: remainingContribution,
    );
    return impact.estimatedTaxSaving > 0 ? impact.estimatedTaxSaving : 0;
  }

  double _current3aContribution() {
    const keys = [
      'q_3a_annual_contribution',
      'q_3a_annual_amount',
      'q_3a_current_year_paid_chf',
      'pillar3aAnnual',
    ];
    for (final key in keys) {
      final parsed = _parseDouble(answers[key]);
      if (parsed != null && parsed > 0) return parsed;
    }
    return 0;
  }

  int? _parseInt(dynamic raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      return int.tryParse(raw.trim().replaceAll('+', ''));
    }
    return null;
  }

  double? _parseDouble(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) {
      return double.tryParse(
        raw.trim().replaceAll("'", '').replaceAll(',', '.'),
      );
    }
    return null;
  }
}
