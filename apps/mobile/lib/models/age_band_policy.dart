enum AgeBand {
  youngProfessional, // 18-25
  stabilization,     // 26-35
  peakEarnings,      // 36-49
  preRetirement,     // 50-65
  retirement,        // 65+
}

enum LifeEventType {
  // Famille (5)
  marriage,
  divorce,
  birth,
  concubinage,
  deathOfRelative,

  // Professionnel (5)
  firstJob,
  newJob,
  selfEmployment,
  jobLoss,
  retirement,

  // Patrimoine (4)
  housingPurchase,
  housingSale,
  inheritance,
  donation,

  // Santé (1)
  disability,

  // Mobilité (2)
  cantonMove,
  countryMove,

  // Crise (1)
  debtCrisis,
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
    
    LifeEventType.divorce: const LifeEvent(
      type: LifeEventType.divorce,
      label: 'Divorce',
      description: 'Séparation légale',
      deltaQuestions: [
        'matrimonial_regime',
        'partner_income',
        'housing_situation',
        'children_custody',
        'pension_split',
      ],
      timelineItems: [
        'Partage LPP (CC 122 ss)',
        'Mise à jour bénéficiaires',
        'Revue couverture assurances',
        'Adaptation budget (revenu unique)',
      ],
    ),

    LifeEventType.concubinage: const LifeEvent(
      type: LifeEventType.concubinage,
      label: 'Concubinage',
      description: 'Vie en union libre',
      deltaQuestions: [
        'partner_income',
        'shared_expenses',
        'testament_exists',
        'beneficiaries_updated',
      ],
      timelineItems: [
        'Rédiger testament (concubin hérite de RIEN sans)',
        'Désigner bénéficiaire LPP/3a',
        'Vérifier couverture décès',
      ],
    ),

    LifeEventType.deathOfRelative: const LifeEvent(
      type: LifeEventType.deathOfRelative,
      label: 'Décès d\'un proche',
      description: 'Perte d\'un membre de la famille',
      deltaQuestions: [
        'relationship_to_deceased',
        'inheritance_expected',
        'survivor_pension_eligible',
        'administrative_steps_done',
      ],
      timelineItems: [
        'Demande rentes de survivant AVS',
        'Déclaration succession',
        'Mise à jour bénéficiaires propres',
      ],
    ),

    LifeEventType.firstJob: const LifeEvent(
      type: LifeEventType.firstJob,
      label: 'Premier emploi',
      description: 'Entrée dans la vie active',
      deltaQuestions: [
        'first_salary_net',
        'employer_lpp_plan',
        'savings_target',
        'has_debt_student',
      ],
      timelineItems: [
        'Ouvrir compte 3a (dès le 1er salaire)',
        'Comprendre fiche de salaire (AVS/LPP/LAA)',
        'Mettre en place épargne automatique',
      ],
    ),

    LifeEventType.selfEmployment: const LifeEvent(
      type: LifeEventType.selfEmployment,
      label: 'Indépendant',
      description: 'Passage au statut indépendant',
      deltaQuestions: [
        'business_revenue',
        'avs_affiliation',
        'ijm_coverage',
        'pension_solution',
      ],
      timelineItems: [
        'Affiliation AVS indépendant',
        'Souscrire IJM (URGENCE: 0 couverture sans)',
        'Choisir solution prévoyance (3a étendu)',
        'Planification fiscale acomptes',
      ],
    ),

    LifeEventType.retirement: const LifeEvent(
      type: LifeEventType.retirement,
      label: 'Retraite',
      description: 'Départ à la retraite',
      deltaQuestions: [
        'retirement_date',
        'pension_vs_capital',
        'avs_amount_estimated',
        'lpp_capital_available',
        'budget_retirement',
      ],
      timelineItems: [
        'Demande rente AVS (3 mois avant)',
        'Décision capital/rente LPP',
        'Retrait échelonné 3a',
        'Budget retraite réaliste',
      ],
    ),

    LifeEventType.housingSale: const LifeEvent(
      type: LifeEventType.housingSale,
      label: 'Vente logement',
      description: 'Vente d\'un bien immobilier',
      deltaQuestions: [
        'sale_price',
        'mortgage_outstanding',
        'capital_gains_tax',
        'reinvestment_plan',
      ],
      timelineItems: [
        'Calcul impôt sur gain immobilier',
        'Remboursement hypothèque',
        'Réinjection 3a/LPP si retrait EPL',
        'Stratégie réallocation du produit',
      ],
    ),

    LifeEventType.disability: const LifeEvent(
      type: LifeEventType.disability,
      label: 'Invalidité',
      description: 'Incapacité de travail ou invalidité',
      deltaQuestions: [
        'disability_degree',
        'ai_rente_requested',
        'lpp_disability_coverage',
        'laa_coverage_if_accident',
      ],
      timelineItems: [
        'Demande rente AI',
        'Activer couverture LPP invalidité',
        'Vérifier LAA si accident',
        'Adapter budget (revenu réduit)',
      ],
    ),

    LifeEventType.countryMove: const LifeEvent(
      type: LifeEventType.countryMove,
      label: 'Départ à l\'étranger',
      description: 'Émigration hors de Suisse',
      deltaQuestions: [
        'destination_country',
        'departure_date',
        'lpp_transfer_or_keep',
        '3a_withdrawal_planned',
      ],
      timelineItems: [
        'Transfert ou maintien LPP (libre passage)',
        'Retrait 3a (possible si départ définitif UE/AELE)',
        'Annonce départ commune',
        'Clôture assurances suisses',
      ],
    ),

    LifeEventType.debtCrisis: const LifeEvent(
      type: LifeEventType.debtCrisis,
      label: 'Crise de dette',
      description: 'Surendettement ou poursuites',
      deltaQuestions: [
        'total_debt_amount',
        'debt_types',
        'monthly_income',
        'minimum_vital_check',
      ],
      timelineItems: [
        'Contacter Dettes Conseils Suisse (gratuit)',
        'Établir budget minimum vital (LP art. 93)',
        'Plan de remboursement structuré',
        'Activer Safe Mode MINT',
      ],
    ),

    LifeEventType.donation: const LifeEvent(
      type: LifeEventType.donation,
      label: 'Donation',
      description: 'Don ou avancement d\'hoirie',
      deltaQuestions: [
        'donation_amount',
        'recipient_relationship',
        'donation_type',
        'tax_canton',
      ],
      timelineItems: [
        'Calcul impôt donation (varie par canton)',
        'Vérifier impact sur réserves héréditaires',
        'Documentation légale',
      ],
    ),
  };
}
