enum AgeBand {
  youngProfessional, // 18-25
  stabilization,     // 26-35
  peakEarnings,      // 36-49
  preRetirement,     // 50-65
  retirement,        // 65+
}

enum LifeEventType {
  // Emploi
  newJob,
  jobLoss,
  incomeReduction,
  
  // Famille
  marriage,
  separation,
  divorce,
  birth,
  adoption,
  
  // Logement
  housingPurchase,
  housingSale,
  
  // Santé
  seriousIllness,
  disability,
  workIncapacity,
  deathOfRelative,
  
  // Patrimoine
  inheritance,
  donation,
  
  // Professionnel
  selfEmployment,
  
  // Administratif
  cantonMove,
  mortgageRenewal,
  leasingEnd,
  creditEnd,
}

class AgeBandPolicy {
  final AgeBand band;
  final String label;
  final int minAge;
  final int maxAge;
  final List<String> keyQuestions;
  final List<RecurringEvent> recurringEvents;

  const AgeBandPolicy({
    required this.band,
    required this.label,
    required this.minAge,
    required this.maxAge,
    required this.keyQuestions,
    required this.recurringEvents,
  });

  static final List<AgeBandPolicy> all = [
    const AgeBandPolicy(
      band: AgeBand.youngProfessional,
      label: '18–25 (entrée vie active)',
      minAge: 18,
      maxAge: 25,
      keyQuestions: [
        'first_job_date',
        'auto_savings_setup',
        'has_debt',
        'has_3a',
      ],
      recurringEvents: [
        RecurringEvent(
          id: 'monthly_savings_check',
          label: 'Versement auto épargne',
          frequency: RecurringFrequency.monthly,
          category: 'cashflow',
        ),
        RecurringEvent(
          id: 'year_end_3a',
          label: 'Check 3a (versement annuel)',
          frequency: RecurringFrequency.yearly,
          month: 12,
          category: 'pension',
        ),
      ],
    ),
    
    const AgeBandPolicy(
      band: AgeBand.stabilization,
      label: '26–35 (stabilisation + logement + famille)',
      minAge: 26,
      maxAge: 35,
      keyQuestions: [
        'housing_purchase_project',
        'mortgage_details',
        'income_drop_parentality',
        'insurance_review',
      ],
      recurringEvents: [
        RecurringEvent(
          id: 'year_end_3a_optimization',
          label: 'Optimisation 3a',
          frequency: RecurringFrequency.yearly,
          month: 12,
          category: 'pension',
        ),
        RecurringEvent(
          id: 'mortgage_renewal_check',
          label: 'Fenêtre renégociation hypothèque (90–180 jours avant échéance)',
          frequency: RecurringFrequency.conditional,
          category: 'housing',
        ),
      ],
    ),
    
    const AgeBandPolicy(
      band: AgeBand.peakEarnings,
      label: '36–49 (pic revenus, optimisation, complexité)',
      minAge: 36,
      maxAge: 49,
      keyQuestions: [
        'lpp_buyback_considered',
        'family_charges',
        'multi_year_tax_planning',
        'diversification_vs_real_estate',
      ],
      recurringEvents: [
        RecurringEvent(
          id: 'annual_tax_strategy',
          label: 'Bilan fiscal + stratégie 3a + éventuel rachat LPP',
          frequency: RecurringFrequency.yearly,
          month: 11,
          category: 'tax',
        ),
        RecurringEvent(
          id: 'allocation_review',
          label: 'Revue allocations / risques',
          frequency: RecurringFrequency.biennial,
          category: 'assets',
        ),
      ],
    ),
    
    const AgeBandPolicy(
      band: AgeBand.preRetirement,
      label: '50–65 (pré-retraite)',
      minAge: 50,
      maxAge: 65,
      keyQuestions: [
        'retirement_target_date',
        'pension_vs_capital_preference',
        'withdrawal_plan',
        'beneficiaries_updated',
      ],
      recurringEvents: [
        RecurringEvent(
          id: 'retirement_plan_scenarios',
          label: 'Plan retraite (scénarios)',
          frequency: RecurringFrequency.conditional,
          yearsBeforeRetirement: 5,
          category: 'pension',
        ),
        RecurringEvent(
          id: 'capital_vs_pension_decision',
          label: 'Décision capital/rente + planification fiscale',
          frequency: RecurringFrequency.conditional,
          yearsBeforeRetirement: 2,
          category: 'pension',
        ),
        RecurringEvent(
          id: 'beneficiaries_update',
          label: 'Mise à jour bénéficiaires/assurances',
          frequency: RecurringFrequency.yearly,
          category: 'pension',
        ),
      ],
    ),
    
    const AgeBandPolicy(
      band: AgeBand.retirement,
      label: '65+ (retraite)',
      minAge: 65,
      maxAge: 120,
      keyQuestions: [
        'actual_vs_planned_expenses',
        'health_dependency_support',
        'administrative_simplification',
      ],
      recurringEvents: [
        RecurringEvent(
          id: 'retirement_budget_review',
          label: 'Revue budget retraite + impôts + bénéficiaires',
          frequency: RecurringFrequency.yearly,
          month: 1,
          category: 'cashflow',
        ),
      ],
    ),
  ];

  static AgeBandPolicy forAge(int age) {
    return all.firstWhere(
      (policy) => age >= policy.minAge && age <= policy.maxAge,
      orElse: () => all.first,
    );
  }
}

enum RecurringFrequency {
  monthly,
  yearly,
  biennial,
  conditional,
}

class RecurringEvent {
  final String id;
  final String label;
  final RecurringFrequency frequency;
  final int? month;
  final int? yearsBeforeRetirement;
  final String category;

  const RecurringEvent({
    required this.id,
    required this.label,
    required this.frequency,
    this.month,
    this.yearsBeforeRetirement,
    required this.category,
  });
}

class LifeEvent {
  final LifeEventType type;
  final String label;
  final String description;
  final List<String> deltaQuestions;
  final List<String> timelineItems;

  const LifeEvent({
    required this.type,
    required this.label,
    required this.description,
    required this.deltaQuestions,
    required this.timelineItems,
  });

  static final Map<LifeEventType, LifeEvent> all = {
    LifeEventType.newJob: const LifeEvent(
      type: LifeEventType.newJob,
      label: 'Nouveau job',
      description: 'Changement d\'emploi',
      deltaQuestions: [
        'new_income_net_monthly',
        'new_lpp_insured_salary',
        'has_13th_salary',
        'lpp_transfer_needed',
      ],
      timelineItems: [
        'Transfert LPP (si applicable)',
        'Mise à jour 3a (nouveau plafond)',
      ],
    ),
    
    LifeEventType.jobLoss: const LifeEvent(
      type: LifeEventType.jobLoss,
      label: 'Perte de job',
      description: 'Chômage ou fin de contrat',
      deltaQuestions: [
        'unemployment_benefits',
        'emergency_fund_status',
        'debt_repayment_plan',
      ],
      timelineItems: [
        'Activation fonds d\'urgence',
        'Suspension versements 3a (si nécessaire)',
        'Revue budget (mode survie)',
      ],
    ),
    
    LifeEventType.marriage: const LifeEvent(
      type: LifeEventType.marriage,
      label: 'Mariage',
      description: 'Union légale',
      deltaQuestions: [
        'partner_income',
        'joint_vs_separate_tax',
        'beneficiaries_update',
        'housing_project',
      ],
      timelineItems: [
        'Mise à jour bénéficiaires (LPP/3a/assurances)',
        'Optimisation fiscale couple',
      ],
    ),
    
    LifeEventType.birth: const LifeEvent(
      type: LifeEventType.birth,
      label: 'Naissance',
      description: 'Arrivée d\'un enfant',
      deltaQuestions: [
        'parental_leave_duration',
        'income_drop_amount',
        'childcare_costs',
        'insurance_coverage_review',
      ],
      timelineItems: [
        'Revue budget (nouvelles charges)',
        'Vérification couverture décès/invalidité',
        'Planification épargne enfant',
      ],
    ),
    
    LifeEventType.housingPurchase: const LifeEvent(
      type: LifeEventType.housingPurchase,
      label: 'Achat logement',
      description: 'Acquisition immobilière',
      deltaQuestions: [
        'purchase_price',
        'down_payment_source',
        '3a_withdrawal_amount',
        'mortgage_amount',
        'mortgage_rate',
        'mortgage_duration',
      ],
      timelineItems: [
        'Retrait 3a (si applicable)',
        'Signature hypothèque',
        'Échéance renouvellement taux fixe',
      ],
    ),
    
    LifeEventType.inheritance: const LifeEvent(
      type: LifeEventType.inheritance,
      label: 'Héritage',
      description: 'Réception d\'un héritage',
      deltaQuestions: [
        'inheritance_amount',
        'inheritance_type',
        'tax_implications',
        'allocation_plan',
      ],
      timelineItems: [
        'Planification fiscale héritage',
        'Stratégie d\'allocation',
      ],
    ),
    
    LifeEventType.cantonMove: const LifeEvent(
      type: LifeEventType.cantonMove,
      label: 'Déménagement de canton',
      description: 'Changement de canton de résidence',
      deltaQuestions: [
        'new_canton',
        'tax_impact_estimate',
        'moving_date',
      ],
      timelineItems: [
        'Recalcul impôts',
        'Mise à jour Plan Mint (nouveau canton)',
      ],
    ),
    
    LifeEventType.mortgageRenewal: const LifeEvent(
      type: LifeEventType.mortgageRenewal,
      label: 'Renouvellement hypothèque',
      description: 'Fin de taux fixe',
      deltaQuestions: [
        'current_rate',
        'new_rate_offers',
        'amortization_strategy',
      ],
      timelineItems: [
        'Comparaison offres',
        'Signature nouveau taux',
        'Nouvelle échéance',
      ],
    ),
  };
}
