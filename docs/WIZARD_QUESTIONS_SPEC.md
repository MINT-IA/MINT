# Spécification Complète des Questions Wizard

## Structure des Questions

Chaque question suit ce format :

```dart
WizardQuestion(
  id: 'q_canton',                    // ID stable
  type: QuestionType.canton,         // Type de widget
  category: QuestionCategory.profile, // Catégorie
  question: 'Canton d\'imposition actuel ?',
  tags: ['core', 'all'],             // Tags pour filtrage
  conditions: [],                     // Conditions d'affichage
  createsTimelineItem: false,        // Crée un item timeline ?
  sensitivity: DataSensitivity.low,  // Sensibilité données
)
```

---

## 1. Noyau Commun (Tous)

### Identité Financière Minimale

```dart
// q_canton
WizardQuestion(
  id: 'q_canton',
  type: QuestionType.canton,
  category: QuestionCategory.profile,
  question: 'Canton d\'imposition actuel ?',
  subtitle: 'La fiscalité en dépend énormément.',
  tags: ['core', 'all', 'fiscal'],
  required: true,
  allowSkip: false,
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_birth_year
WizardQuestion(
  id: 'q_birth_year',
  type: QuestionType.input,
  category: QuestionCategory.profile,
  question: 'Année de naissance ?',
  subtitle: 'Pour calculer précisément ton horizon.',
  hint: 'Ex: 1990',
  tags: ['core', 'all', 'age_band'],
  required: true,
  allowSkip: false,
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
  minValue: 1940,
  maxValue: 2010,
)

// q_household_type
WizardQuestion(
  id: 'q_household_type',
  type: QuestionType.choice,
  category: QuestionCategory.profile,
  question: 'Statut foyer ?',
  subtitle: 'Cela impacte tes charges et tes priorités.',
  tags: ['core', 'all', 'household'],
  required: true,
  allowSkip: false,
  options: [
    QuestionOption(label: 'Seul(e)', value: 'single', icon: 'person'),
    QuestionOption(label: 'Couple (marié ou non)', value: 'couple', icon: 'people'),
    QuestionOption(label: 'Famille (enfants)', value: 'family', icon: 'family_restroom'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_children_count
WizardQuestion(
  id: 'q_children_count',
  type: QuestionType.choice,
  category: QuestionCategory.profile,
  question: 'Enfants à charge ?',
  subtitle: 'Pour les déductions fiscales et les charges.',
  tags: ['household:family', 'fiscal'],
  conditions: ['q_household_type == family'],
  options: [
    QuestionOption(label: '1 enfant', value: 1),
    QuestionOption(label: '2 enfants', value: 2),
    QuestionOption(label: '3+ enfants', value: 3),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_employment_status (QUESTION PIVOT)
WizardQuestion(
  id: 'q_employment_status',
  type: QuestionType.choice,
  category: QuestionCategory.profile,
  question: 'Statut d\'emploi ?',
  subtitle: 'Crucial pour adapter la fiscalité, la prévoyance et les limites 3a.',
  tags: ['core', 'all', 'employment', 'pivot'],
  required: true,
  allowSkip: false,
  options: [
    QuestionOption(label: 'Salarié', value: 'employee', icon: 'work'),
    QuestionOption(label: 'Indépendant', value: 'self_employed', icon: 'business_center'),
    QuestionOption(label: 'Mixte (salarié + indépendant)', value: 'mixed', icon: 'work_outline'),
    QuestionOption(label: 'Étudiant', value: 'student', icon: 'school'),
    QuestionOption(label: 'Retraité', value: 'retired', icon: 'elderly'),
    QuestionOption(label: 'Autre', value: 'other', icon: 'more_horiz'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_has_2nd_pillar (QUESTION PIVOT)
WizardQuestion(
  id: 'q_has_2nd_pillar',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'As-tu une caisse de pension (LPP/2e pilier) via ton activité principale ?',
  subtitle: 'Détermine tes plafonds 3a et tes besoins de prévoyance.',
  tags: ['core', 'all', 'pension', 'pivot'],
  required: true,
  allowSkip: false,
  conditions: ['q_employment_status != student', 'q_employment_status != retired'],
  options: [
    QuestionOption(label: 'Oui', value: true, icon: 'check_circle'),
    QuestionOption(label: 'Non', value: false, icon: 'cancel'),
    QuestionOption(label: 'Je ne sais pas', value: null, icon: 'help'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)

// q_international_complexity
WizardQuestion(
  id: 'q_international_complexity',
  type: QuestionType.choice,
  category: QuestionCategory.tax,
  question: 'Revenus à l\'étranger / double résidence / nationalité US ?',
  subtitle: 'Pour activer un parcours "international" plus prudent.',
  tags: ['core', 'all', 'international', 'tax'],
  options: [
    QuestionOption(label: 'Oui', value: true, icon: 'public'),
    QuestionOption(label: 'Non', value: false, icon: 'close'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
)
```

### Objectif

```dart
// q_primary_goal
WizardQuestion(
  id: 'q_primary_goal',
  type: QuestionType.choice,
  category: QuestionCategory.objective,
  question: 'Qu\'est-ce qui te rendrait plus serein dans 6–12 mois ?',
  subtitle: 'Mint te proposera un plan adapté à cet objectif.',
  tags: ['core', 'all', 'goal'],
  required: true,
  allowSkip: false,
  options: [
    QuestionOption(label: 'Reprendre le contrôle (budget + dettes)', value: 'control'),
    QuestionOption(label: 'Construire un fonds d\'urgence', value: 'emergency_fund'),
    QuestionOption(label: 'Payer moins d\'impôts (3a + bases)', value: 'tax_optimization'),
    QuestionOption(label: 'Préparer un achat logement', value: 'housing'),
    QuestionOption(label: 'Optimiser ma prévoyance (LPP/3a)', value: 'pension'),
    QuestionOption(label: 'Investir simplement (après les bases)', value: 'invest'),
    QuestionOption(label: 'Préparer la retraite (plan clair)', value: 'retirement'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_time_horizon
WizardQuestion(
  id: 'q_time_horizon',
  type: QuestionType.choice,
  category: QuestionCategory.objective,
  question: 'Horizon principal ?',
  subtitle: 'Pour adapter les recommandations à ton rythme.',
  tags: ['core', 'all', 'goal'],
  options: [
    QuestionOption(label: '0–12 mois', value: 'short'),
    QuestionOption(label: '1–3 ans', value: 'medium'),
    QuestionOption(label: '3–10 ans', value: 'long'),
    QuestionOption(label: '10+ ans', value: 'very_long'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_risk_preference
WizardQuestion(
  id: 'q_risk_preference',
  type: QuestionType.choice,
  category: QuestionCategory.preferences,
  question: 'Préférence ?',
  subtitle: 'Pour adapter les recommandations d\'investissement.',
  tags: ['core', 'all', 'risk'],
  options: [
    QuestionOption(label: 'Stabilité', value: 'stability'),
    QuestionOption(label: 'Équilibré', value: 'balanced'),
    QuestionOption(label: 'Accepte variations', value: 'growth'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)
```

### Cashflow Minimal

```dart
// q_net_income_monthly
WizardQuestion(
  id: 'q_net_income_monthly',
  type: QuestionType.input,
  category: QuestionCategory.cashflow,
  question: 'Revenu net mensuel ?',
  subtitle: 'Approximatif OK. Cela détermine tes leviers d\'épargne.',
  hint: 'CHF (ex: 6500)',
  tags: ['core', 'all', 'cashflow'],
  required: true,
  allowSkip: false,
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
  minValue: 0,
  maxValue: 50000,
)

// q_savings_monthly
WizardQuestion(
  id: 'q_savings_monthly',
  type: QuestionType.input,
  category: QuestionCategory.cashflow,
  question: 'Épargne possible mensuelle ?',
  subtitle: 'Approximatif OK. Cela détermine ton potentiel d\'investissement.',
  hint: 'CHF (ex: 1000)',
  tags: ['core', 'all', 'cashflow'],
  required: true,
  allowSkip: false,
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
  minValue: 0,
  maxValue: 20000,
)

// q_has_13th_salary
WizardQuestion(
  id: 'q_has_13th_salary',
  type: QuestionType.choice,
  category: QuestionCategory.cashflow,
  question: 'Bonus / 13e salaire ?',
  subtitle: 'Pour planifier les versements 3a et les gros achats.',
  tags: ['core', 'all', 'cashflow'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_13th_salary_month
WizardQuestion(
  id: 'q_13th_salary_month',
  type: QuestionType.choice,
  category: QuestionCategory.cashflow,
  question: 'Mois de versement du 13e salaire ?',
  subtitle: 'Pour optimiser le timing du versement 3a.',
  tags: ['cashflow', 'timeline'],
  conditions: ['q_has_13th_salary == true'],
  options: [
    QuestionOption(label: 'Décembre', value: 12),
    QuestionOption(label: 'Juin', value: 6),
    QuestionOption(label: 'Autre', value: 0),
  ],
  createsTimelineItem: true,
  timelineRule: 'Rappel versement 3a (après 13e salaire)',
  sensitivity: DataSensitivity.low,
)
```

### Logement

```dart
// q_housing_status
WizardQuestion(
  id: 'q_housing_status',
  type: QuestionType.choice,
  category: QuestionCategory.housing,
  question: 'Logement ?',
  subtitle: 'Clé pour calculer tes charges et ton patrimoine.',
  tags: ['core', 'all', 'housing'],
  required: true,
  allowSkip: false,
  options: [
    QuestionOption(label: 'Locataire', value: 'tenant', icon: 'home'),
    QuestionOption(label: 'Propriétaire', value: 'owner', icon: 'domain'),
    QuestionOption(label: 'Projet d\'achat', value: 'project', icon: 'construction'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_rent_monthly
WizardQuestion(
  id: 'q_rent_monthly',
  type: QuestionType.input,
  category: QuestionCategory.housing,
  question: 'Loyer mensuel ?',
  subtitle: 'Pour calculer tes charges fixes.',
  hint: 'CHF (ex: 1800)',
  tags: ['housing:tenant', 'cashflow'],
  conditions: ['q_housing_status == tenant'],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
  minValue: 0,
  maxValue: 10000,
)

// q_mortgage_total
WizardQuestion(
  id: 'q_mortgage_total',
  type: QuestionType.input,
  category: QuestionCategory.housing,
  question: 'Hypothèque totale ?',
  subtitle: 'Montant total de ton prêt hypothécaire.',
  hint: 'CHF (ex: 650000)',
  tags: ['housing:owner', 'debt'],
  conditions: ['q_housing_status == owner'],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
  minValue: 0,
  maxValue: 5000000,
)

// q_mortgage_type
WizardQuestion(
  id: 'q_mortgage_type',
  type: QuestionType.choice,
  category: QuestionCategory.housing,
  question: 'Type d\'hypothèque ?',
  subtitle: 'Pour anticiper les renouvellements.',
  tags: ['housing:owner', 'timeline'],
  conditions: ['q_housing_status == owner'],
  options: [
    QuestionOption(label: 'Taux fixe', value: 'fixed'),
    QuestionOption(label: 'Taux variable', value: 'variable'),
    QuestionOption(label: 'Je ne sais pas', value: null),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_mortgage_fixed_end_date
WizardQuestion(
  id: 'q_mortgage_fixed_end_date',
  type: QuestionType.date,
  category: QuestionCategory.housing,
  question: 'Échéance du taux fixe ?',
  subtitle: 'Mint te rappellera 120 jours avant pour renégocier.',
  hint: 'Mois/Année (ex: 06/2027)',
  tags: ['housing:owner', 'timeline'],
  conditions: ['q_mortgage_type == fixed'],
  createsTimelineItem: true,
  timelineRule: 'Rappel 120 jours avant: renégociation hypothèque',
  sensitivity: DataSensitivity.medium,
)
```

### Dettes & Stress (Safe Mode Triggers)

```dart
// q_has_leasing
WizardQuestion(
  id: 'q_has_leasing',
  type: QuestionType.choice,
  category: QuestionCategory.debt,
  question: 'Leasing véhicule ?',
  subtitle: 'Pour évaluer ton score de risque.',
  tags: ['core', 'all', 'debt', 'safe_mode'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)

// q_leasing_monthly
WizardQuestion(
  id: 'q_leasing_monthly',
  type: QuestionType.input,
  category: QuestionCategory.debt,
  question: 'Montant mensuel du leasing ?',
  hint: 'CHF (ex: 450)',
  tags: ['debt', 'cashflow', 'safe_mode'],
  conditions: ['q_has_leasing == true'],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
  minValue: 0,
  maxValue: 3000,
)

// q_leasing_end_date
WizardQuestion(
  id: 'q_leasing_end_date',
  type: QuestionType.date,
  category: QuestionCategory.debt,
  question: 'Fin de contrat leasing ?',
  subtitle: 'Mint te rappellera pour planifier la suite.',
  hint: 'Mois/Année (ex: 12/2026)',
  tags: ['debt', 'timeline'],
  conditions: ['q_has_leasing == true'],
  createsTimelineItem: true,
  timelineRule: 'Rappel 60 jours avant: fin leasing',
  sensitivity: DataSensitivity.low,
)

// q_has_consumer_credit
WizardQuestion(
  id: 'q_has_consumer_credit',
  type: QuestionType.choice,
  category: QuestionCategory.debt,
  question: 'Crédit conso / prêt personnel ?',
  subtitle: 'Pour évaluer ton score de risque.',
  tags: ['core', 'all', 'debt', 'safe_mode'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
)

// q_consumer_credit_monthly
WizardQuestion(
  id: 'q_consumer_credit_monthly',
  type: QuestionType.input,
  category: QuestionCategory.debt,
  question: 'Mensualité du crédit ?',
  hint: 'CHF (ex: 350)',
  tags: ['debt', 'cashflow', 'safe_mode'],
  conditions: ['q_has_consumer_credit == true'],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
  minValue: 0,
  maxValue: 5000,
)

// q_consumer_credit_balance
WizardQuestion(
  id: 'q_consumer_credit_balance',
  type: QuestionType.input,
  category: QuestionCategory.debt,
  question: 'Solde restant du crédit ?',
  hint: 'CHF (ex: 8000)',
  tags: ['debt', 'safe_mode'],
  conditions: ['q_has_consumer_credit == true'],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
  minValue: 0,
  maxValue: 100000,
)

// q_consumer_credit_end_date
WizardQuestion(
  id: 'q_consumer_credit_end_date',
  type: QuestionType.date,
  category: QuestionCategory.debt,
  question: 'Fin du crédit (estimée) ?',
  subtitle: 'Pour planifier la libération de ce budget.',
  hint: 'Mois/Année (ex: 03/2028)',
  tags: ['debt', 'timeline'],
  conditions: ['q_has_consumer_credit == true'],
  createsTimelineItem: true,
  timelineRule: 'Rappel 30 jours avant: fin crédit',
  sensitivity: DataSensitivity.medium,
)

// q_credit_card_minimum
WizardQuestion(
  id: 'q_credit_card_minimum',
  type: QuestionType.choice,
  category: QuestionCategory.debt,
  question: 'Carte de crédit souvent "au minimum" / découvert régulier ?',
  subtitle: 'Signal de tension financière.',
  tags: ['debt', 'safe_mode'],
  options: [
    QuestionOption(label: 'Jamais', value: 'never'),
    QuestionOption(label: 'Parfois', value: 'sometimes'),
    QuestionOption(label: 'Souvent', value: 'often'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
)

// q_late_payments
WizardQuestion(
  id: 'q_late_payments',
  type: QuestionType.choice,
  category: QuestionCategory.debt,
  question: 'Paiements en retard ces 6 derniers mois ?',
  subtitle: 'Pour activer le mode protection si besoin.',
  tags: ['debt', 'safe_mode'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
)

// q_gambling_trading
WizardQuestion(
  id: 'q_gambling_trading',
  type: QuestionType.choice,
  category: QuestionCategory.debt,
  question: 'Jeux / paris / trading très spéculatif "qui te stresse" ?',
  subtitle: 'Optionnel. Pour détecter les comportements à risque.',
  tags: ['debt', 'safe_mode'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
    QuestionOption(label: 'Préférer ne pas répondre', value: null),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
)
```

### Prévoyance & Protection (Light)

```dart
// q_has_3a
WizardQuestion(
  id: 'q_has_3a',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'As-tu un 3a ?',
  subtitle: dynamicSubtitle3a(), // Fonction qui retourne le plafond selon le statut
  tags: ['core', 'all', 'pension'],
  required: true,
  allowSkip: false,
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// Note: dynamicSubtitle3a() retourne:
// - Si salarié avec LPP: "Le 3a te permet de déduire jusqu'à CHF 7'258/an (2025) de tes impôts."
// - Si indépendant sans LPP: "Le 3a te permet de déduire jusqu'à 20% de ton revenu net (max CHF 36'288/an, 2025)."
// - Sinon: "Le 3a te permet de déduire une partie de tes impôts (plafond selon ton statut)."

// q_3a_type
WizardQuestion(
  id: 'q_3a_type',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'Type de 3a ?',
  subtitle: 'Banque (compte/titres) ou Assurance (contrat).',
  tags: ['pension'],
  conditions: ['q_has_3a == true'],
  options: [
    QuestionOption(label: 'Bancaire', value: 'bank'),
    QuestionOption(label: 'Assurance', value: 'insurance'),
    QuestionOption(label: 'Je ne sais pas', value: null),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_3a_annual_contribution
WizardQuestion(
  id: 'q_3a_annual_contribution',
  type: QuestionType.input,
  category: QuestionCategory.pension,
  question: 'Versement annuel approximatif ?',
  subtitle: 'Pour vérifier si tu maximises la déduction.',
  hint: 'CHF (ex: 7258)',
  tags: ['pension', 'fiscal'],
  conditions: ['q_has_3a == true'],
  createsTimelineItem: true,
  timelineRule: 'Rappel annuel (décembre): optimiser versement 3a',
  sensitivity: DataSensitivity.medium,
  minValue: 0,
  maxValue: 7258,
)

// q_has_lpp_certificate
WizardQuestion(
  id: 'q_has_lpp_certificate',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'Certificat LPP (2e pilier) disponible pour upload ?',
  subtitle: 'Pour calculer précisément ton potentiel de rachat.',
  tags: ['pension'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_has_life_insurance
WizardQuestion(
  id: 'q_has_life_insurance',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'Assurance vie / invalidité / perte de gain ?',
  subtitle: 'Pour évaluer ta couverture en cas de coup dur.',
  tags: ['pension', 'insurance'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
    QuestionOption(label: 'Je ne sais pas', value: null),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)
```

---

## 1B. Branches Spécifiques par Statut d'Emploi

### A) Salarié avec LPP

```dart
// q_employee_lpp_certificate
WizardQuestion(
  id: 'q_employee_lpp_certificate',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'As-tu ton certificat LPP disponible pour upload ?',
  subtitle: 'Pour calculer précisément ton potentiel de rachat et optimiser ta prévoyance.',
  tags: ['employment:employee', 'pension'],
  conditions: ['q_employment_status == employee', 'q_has_2nd_pillar == true'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_employee_job_change_planned
WizardQuestion(
  id: 'q_employee_job_change_planned',
  type: QuestionType.choice,
  category: QuestionCategory.profile,
  question: 'Changement d\'employeur prévu dans les 12 prochains mois ?',
  subtitle: 'Pour planifier le transfert LPP et adapter ton plan.',
  tags: ['employment:employee', 'timeline'],
  conditions: ['q_employment_status == employee'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
    QuestionOption(label: 'Incertain', value: null),
  ],
  createsTimelineItem: true,
  timelineRule: 'Delta session "nouveau job" si changement confirmé',
  sensitivity: DataSensitivity.medium,
)

// q_employee_job_change_date
WizardQuestion(
  id: 'q_employee_job_change_date',
  type: QuestionType.date,
  category: QuestionCategory.profile,
  question: 'Date prévue du changement ?',
  subtitle: 'Mint te rappellera pour gérer le transfert LPP.',
  hint: 'Mois/Année (ex: 06/2026)',
  tags: ['employment:employee', 'timeline'],
  conditions: ['q_employee_job_change_planned == true'],
  createsTimelineItem: true,
  timelineRule: 'Rappel 30 jours avant: préparer transfert LPP + mise à jour 3a',
  sensitivity: DataSensitivity.medium,
)

// Note: q_has_13th_salary et q_13th_salary_month sont déjà dans le noyau commun
// mais sont particulièrement pertinents pour les salariés
```

### B) Indépendant sans LPP

```dart
// q_self_employed_legal_form
WizardQuestion(
  id: 'q_self_employed_legal_form',
  type: QuestionType.choice,
  category: QuestionCategory.profile,
  question: 'Forme juridique de ton activité ?',
  subtitle: 'Pour adapter les conseils fiscaux et de prévoyance.',
  tags: ['employment:self_employed', 'tax'],
  conditions: ['q_employment_status == self_employed'],
  options: [
    QuestionOption(label: 'Raison individuelle', value: 'sole_proprietorship'),
    QuestionOption(label: 'Sàrl', value: 'sarl'),
    QuestionOption(label: 'SA', value: 'sa'),
    QuestionOption(label: 'Autre', value: 'other'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_self_employed_net_income
WizardQuestion(
  id: 'q_self_employed_net_income',
  type: QuestionType.input,
  category: QuestionCategory.cashflow,
  question: 'Revenu net annuel issu de l\'activité indépendante (approximatif) ?',
  subtitle: 'Pour calculer ton plafond 3a (20% du revenu net, max CHF 36\'288).',
  hint: 'CHF (ex: 80000)',
  tags: ['employment:self_employed', 'cashflow', 'pension'],
  conditions: ['q_employment_status == self_employed', 'q_has_2nd_pillar == false'],
  required: true,
  allowSkip: false,
  createsTimelineItem: true,
  timelineRule: 'Rappel annuel (décembre): optimiser montant 3a (20% net, plafond)',
  sensitivity: DataSensitivity.high,
  minValue: 0,
  maxValue: 500000,
)

// q_self_employed_voluntary_lpp
WizardQuestion(
  id: 'q_self_employed_voluntary_lpp',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'As-tu rejoint une solution LPP via une association ou fondation ?',
  subtitle: 'Certains indépendants peuvent s\'affilier volontairement à une caisse LPP.',
  tags: ['employment:self_employed', 'pension'],
  conditions: ['q_employment_status == self_employed', 'q_has_2nd_pillar == false'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
    QuestionOption(label: 'Je ne sais pas', value: null),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)

// q_self_employed_protection_gap
WizardQuestion(
  id: 'q_self_employed_protection_gap',
  type: QuestionType.info,
  category: QuestionCategory.pension,
  question: 'Important : Sans LPP, tu n\'as pas de couverture automatique décès/invalidité.',
  subtitle: 'Mint te recommandera des solutions de protection adaptées.',
  tags: ['employment:self_employed', 'pension', 'insurance'],
  conditions: ['q_employment_status == self_employed', 'q_has_2nd_pillar == false', 'q_self_employed_voluntary_lpp == false'],
  createsTimelineItem: true,
  timelineRule: 'Rappel: évaluer couverture protection (décès/invalidité)',
  sensitivity: DataSensitivity.medium,
)
```

### C) Mixte (Salarié + Indépendant)

```dart
// q_mixed_primary_activity
WizardQuestion(
  id: 'q_mixed_primary_activity',
  type: QuestionType.choice,
  category: QuestionCategory.profile,
  question: 'Quelle est ton activité principale ?',
  subtitle: 'Pour déterminer ton statut fiscal et tes plafonds 3a.',
  tags: ['employment:mixed', 'tax'],
  conditions: ['q_employment_status == mixed'],
  required: true,
  allowSkip: false,
  options: [
    QuestionOption(label: 'Activité salariée', value: 'employee'),
    QuestionOption(label: 'Activité indépendante', value: 'self_employed'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)

// q_mixed_employee_has_lpp
WizardQuestion(
  id: 'q_mixed_employee_has_lpp',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'As-tu une caisse LPP via ton activité salariée ?',
  subtitle: 'Détermine ton plafond 3a (CHF 7\'258 si oui, 20% revenu net si non).',
  tags: ['employment:mixed', 'pension'],
  conditions: ['q_employment_status == mixed'],
  required: true,
  allowSkip: false,
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)

// q_mixed_self_employed_net_income
WizardQuestion(
  id: 'q_mixed_self_employed_net_income',
  type: QuestionType.input,
  category: QuestionCategory.cashflow,
  question: 'Revenu net annuel de l\'activité indépendante (approximatif) ?',
  subtitle: 'Pour calculer correctement ton plafond 3a global.',
  hint: 'CHF (ex: 30000)',
  tags: ['employment:mixed', 'cashflow'],
  conditions: ['q_employment_status == mixed'],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
  minValue: 0,
  maxValue: 300000,
)

// q_mixed_3a_calculation_note
WizardQuestion(
  id: 'q_mixed_3a_calculation_note',
  type: QuestionType.info,
  category: QuestionCategory.pension,
  question: 'Note : Ton plafond 3a dépend de ton activité principale et de ta LPP.',
  subtitle: 'Mint calculera le plafond correct selon ta situation.',
  tags: ['employment:mixed', 'pension'],
  conditions: ['q_employment_status == mixed'],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)
```

---

## 2. Branches par Situation du Foyer

### A) Personne Seule

```dart
// q_single_dependents
WizardQuestion(
  id: 'q_single_dependents',
  type: QuestionType.choice,
  category: QuestionCategory.profile,
  question: 'Qui dépend de toi financièrement ?',
  subtitle: 'Pour évaluer tes besoins de protection.',
  tags: ['household:single'],
  conditions: ['q_household_type == single'],
  options: [
    QuestionOption(label: 'Personne', value: 'none'),
    QuestionOption(label: 'Parents', value: 'parents'),
    QuestionOption(label: 'Enfants', value: 'children'),
    QuestionOption(label: 'Autre', value: 'other'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)

// q_single_emergency_fund
WizardQuestion(
  id: 'q_single_emergency_fund',
  type: QuestionType.choice,
  category: QuestionCategory.cashflow,
  question: 'As-tu un plan "filet de sécurité" (épargne d\'urgence) ?',
  subtitle: 'Recommandé : 3-6 mois de charges.',
  tags: ['household:single', 'safe_mode'],
  conditions: ['q_household_type == single'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)

// q_single_owner_insurance
WizardQuestion(
  id: 'q_single_owner_insurance',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'As-tu une assurance risque pur (décès/invalidité) liée à ton logement ?',
  subtitle: 'Recommandé si propriétaire seul.',
  tags: ['household:single', 'housing:owner', 'insurance'],
  conditions: ['q_household_type == single', 'q_housing_status == owner'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
    QuestionOption(label: 'Je ne sais pas', value: null),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)
```

**Échéances créées :**
- Bilan annuel (date inscription + 12 mois, récurrent)
- Fin leasing/crédit (si applicable)
- Échéance hypothèque fixe + rappel 120 jours avant

### B) Couple

```dart
// q_couple_status
WizardQuestion(
  id: 'q_couple_status',
  type: QuestionType.choice,
  category: QuestionCategory.profile,
  question: 'Statut du couple ?',
  subtitle: 'Pour adapter les conseils fiscaux et de protection.',
  tags: ['household:couple'],
  conditions: ['q_household_type == couple'],
  options: [
    QuestionOption(label: 'Marié', value: 'married'),
    QuestionOption(label: 'Partenariat enregistré', value: 'partnership'),
    QuestionOption(label: 'Concubinage', value: 'cohabitation'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_couple_accounts
WizardQuestion(
  id: 'q_couple_accounts',
  type: QuestionType.choice,
  category: QuestionCategory.profile,
  question: 'Comptes ?',
  subtitle: 'Pour adapter les conseils de gestion.',
  tags: ['household:couple'],
  conditions: ['q_household_type == couple'],
  options: [
    QuestionOption(label: 'Séparés', value: 'separate'),
    QuestionOption(label: 'Communs', value: 'joint'),
    QuestionOption(label: 'Mixte', value: 'mixed'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_couple_common_goals
WizardQuestion(
  id: 'q_couple_common_goals',
  type: QuestionType.multiChoice,
  category: QuestionCategory.objective,
  question: 'Objectifs communs ?',
  subtitle: 'Pour prioriser le plan.',
  tags: ['household:couple', 'goal'],
  conditions: ['q_household_type == couple'],
  options: [
    QuestionOption(label: 'Logement', value: 'housing'),
    QuestionOption(label: 'Enfants', value: 'children'),
    QuestionOption(label: 'Retraite', value: 'retirement'),
    QuestionOption(label: 'Dettes', value: 'debt'),
    QuestionOption(label: 'Impôts', value: 'tax'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_couple_income_asymmetry
WizardQuestion(
  id: 'q_couple_income_asymmetry',
  type: QuestionType.choice,
  category: QuestionCategory.cashflow,
  question: 'Répartition revenus ?',
  subtitle: 'Pour détecter les besoins de protection asymétriques.',
  tags: ['household:couple', 'cashflow'],
  conditions: ['q_household_type == couple'],
  options: [
    QuestionOption(label: 'Similaire', value: 'similar'),
    QuestionOption(label: 'Très asymétrique', value: 'asymmetric'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)
```

**Échéances créées :**
- Revue couverture couple (annuelle)
- Delta session parentalité (si projet enfant)

### C) Famille (Enfants)

```dart
// q_family_children_ages
WizardQuestion(
  id: 'q_family_children_ages',
  type: QuestionType.multiChoice,
  category: QuestionCategory.profile,
  question: 'Âges des enfants (tranches) ?',
  subtitle: 'Pour adapter les conseils de charges et d\'épargne.',
  tags: ['household:family'],
  conditions: ['q_household_type == family'],
  options: [
    QuestionOption(label: '0–3 ans', value: '0-3'),
    QuestionOption(label: '4–6 ans', value: '4-6'),
    QuestionOption(label: '7–12 ans', value: '7-12'),
    QuestionOption(label: '13–18 ans', value: '13-18'),
    QuestionOption(label: '18+ ans', value: '18+'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_family_childcare_costs
WizardQuestion(
  id: 'q_family_childcare_costs',
  type: QuestionType.choice,
  category: QuestionCategory.cashflow,
  question: 'Garde / charges enfants : "frais mensuels significatifs" ?',
  subtitle: 'Pour calculer tes charges fixes.',
  tags: ['household:family', 'cashflow'],
  conditions: ['q_household_type == family'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)

// q_family_income_drop
WizardQuestion(
  id: 'q_family_income_drop',
  type: QuestionType.choice,
  category: QuestionCategory.cashflow,
  question: 'Baisse revenu probable (temps partiel/congé) 12–24 mois ?',
  subtitle: 'Pour adapter le plan de trésorerie.',
  tags: ['household:family', 'cashflow'],
  conditions: ['q_household_type == family'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
    QuestionOption(label: 'Incertain', value: null),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)
```

**Échéances créées :**
- Budget famille (revue trimestrielle légère)
- Assurances & bénéficiaires (revue annuelle)
- Plan logement (si locataire + objectif achat)

---

## 3. Branches par Tranche d'Âge

### 18–25 (Entrée Vie Active)

```dart
// q_young_first_job_date
WizardQuestion(
  id: 'q_young_first_job_date',
  type: QuestionType.date,
  category: QuestionCategory.profile,
  question: '1er emploi : date de début ?',
  subtitle: 'Pour calculer tes lacunes AVS/LPP.',
  hint: 'Mois/Année (ex: 09/2022)',
  tags: ['age_band:18-25', 'employment'],
  conditions: ['age >= 18', 'age <= 25'],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_young_study_years
WizardQuestion(
  id: 'q_young_study_years',
  type: QuestionType.choice,
  category: QuestionCategory.profile,
  question: 'Études / années "sans cotisation" ?',
  subtitle: 'Pour détecter les lacunes AVS.',
  tags: ['age_band:18-25', 'pension'],
  conditions: ['age >= 18', 'age <= 25'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_young_auto_savings
WizardQuestion(
  id: 'q_young_auto_savings',
  type: QuestionType.choice,
  category: QuestionCategory.cashflow,
  question: 'Tu veux automatiser l\'épargne ?',
  subtitle: 'Recommandé pour construire de bonnes habitudes.',
  tags: ['age_band:18-25', 'cashflow'],
  conditions: ['age >= 18', 'age <= 25'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: true,
  timelineRule: 'Rappel mensuel: vérifier versement auto épargne',
  sensitivity: DataSensitivity.low,
)
```

**Échéances créées :**
- Mensuel : "Mettre en place / vérifier versement auto"
- Décembre : "Optimiser versement 3a"
- Changement d'emploi : "Delta session: nouveau job"

### 26–35 (Logement + Structuration)

```dart
// q_mid_housing_purchase_project
WizardQuestion(
  id: 'q_mid_housing_purchase_project',
  type: QuestionType.choice,
  category: QuestionCategory.housing,
  question: 'Projet achat logement < 36 mois ?',
  subtitle: 'Pour adapter la stratégie 3a et épargne.',
  tags: ['age_band:26-35', 'housing'],
  conditions: ['age >= 26', 'age <= 35'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_mid_housing_purchase_date
WizardQuestion(
  id: 'q_mid_housing_purchase_date',
  type: QuestionType.date,
  category: QuestionCategory.housing,
  question: 'Date cible achat logement ?',
  subtitle: 'Mint te rappellera pour planifier l\'apport.',
  hint: 'Mois/Année (ex: 06/2026)',
  tags: ['age_band:26-35', 'housing', 'timeline'],
  conditions: ['q_mid_housing_purchase_project == true'],
  createsTimelineItem: true,
  timelineRule: 'Rappel 12 mois avant: planifier apport logement',
  sensitivity: DataSensitivity.low,
)

// q_mid_down_payment
WizardQuestion(
  id: 'q_mid_down_payment',
  type: QuestionType.choice,
  category: QuestionCategory.housing,
  question: 'Apport disponible (tranches) ?',
  subtitle: 'Pour évaluer la faisabilité.',
  tags: ['age_band:26-35', 'housing'],
  conditions: ['q_mid_housing_purchase_project == true'],
  options: [
    QuestionOption(label: 'Moins de CHF 20\'000', value: '0-20k'),
    QuestionOption(label: 'CHF 20\'000 – 50\'000', value: '20k-50k'),
    QuestionOption(label: 'CHF 50\'000 – 100\'000', value: '50k-100k'),
    QuestionOption(label: 'Plus de CHF 100\'000', value: '100k+'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
)
```

**Échéances créées :**
- 90–180 jours avant échéance hypothèque fixe : "renégociation"
- Fin d'année : "3a + plan fiscal"
- Delta session : naissance (si événement)

### 36–49 (Optimisation Multi-Leviers)

```dart
// q_peak_lpp_buyback
WizardQuestion(
  id: 'q_peak_lpp_buyback',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'Rachat LPP déjà envisagé / possible ?',
  subtitle: 'Pour optimiser la fiscalité et la retraite.',
  tags: ['age_band:36-49', 'pension', 'fiscal'],
  conditions: ['age >= 36', 'age <= 49'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
    QuestionOption(label: 'Je ne sais pas', value: null),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_peak_variable_income
WizardQuestion(
  id: 'q_peak_variable_income',
  type: QuestionType.choice,
  category: QuestionCategory.cashflow,
  question: 'Revenus variables / bonus importants ?',
  subtitle: 'Pour planifier les versements 3a et rachat LPP.',
  tags: ['age_band:36-49', 'cashflow'],
  conditions: ['age >= 36', 'age <= 49'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)

// q_peak_rental_property
WizardQuestion(
  id: 'q_peak_rental_property',
  type: QuestionType.choice,
  category: QuestionCategory.assets,
  question: 'Immobilier locatif / 2e bien ?',
  subtitle: 'Complexité fiscale à gérer.',
  tags: ['age_band:36-49', 'assets', 'tax'],
  conditions: ['age >= 36', 'age <= 49'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
)
```

**Échéances créées :**
- Annuel : "bilan fiscal + stratégie 3a + éventuel rachat LPP"
- Tous les 2 ans : "revue allocation / risques"

### 50–65 (Pré-Retraite)

```dart
// q_preretire_target_age
WizardQuestion(
  id: 'q_preretire_target_age',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'Âge cible retraite ?',
  subtitle: 'Pour planifier le retrait et la fiscalité.',
  tags: ['age_band:50-65', 'pension'],
  conditions: ['age >= 50', 'age <= 65'],
  options: [
    QuestionOption(label: '60 ans', value: 60),
    QuestionOption(label: '62 ans', value: 62),
    QuestionOption(label: '65 ans', value: 65),
    QuestionOption(label: '67 ans', value: 67),
    QuestionOption(label: 'Autre', value: 0),
  ],
  createsTimelineItem: true,
  timelineRule: 'Rappel 10 ans avant: plan retraite complet',
  sensitivity: DataSensitivity.low,
)

// q_preretire_pension_vs_capital
WizardQuestion(
  id: 'q_preretire_pension_vs_capital',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'Préférence rente / capital ?',
  subtitle: 'Pour simuler les scénarios.',
  tags: ['age_band:50-65', 'pension'],
  conditions: ['age >= 50', 'age <= 65'],
  options: [
    QuestionOption(label: 'Rente', value: 'pension'),
    QuestionOption(label: 'Capital', value: 'capital'),
    QuestionOption(label: 'Je ne sais pas', value: null),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_preretire_early_retirement
WizardQuestion(
  id: 'q_preretire_early_retirement',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'Départ anticipé possible ?',
  subtitle: 'Pour simuler l\'impact financier.',
  tags: ['age_band:50-65', 'pension'],
  conditions: ['age >= 50', 'age <= 65'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.low,
)

// q_preretire_succession
WizardQuestion(
  id: 'q_preretire_succession',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'Succession : testament / bénéficiaires à jour ?',
  subtitle: 'Recommandé de vérifier régulièrement.',
  tags: ['age_band:50-65', 'pension'],
  conditions: ['age >= 50', 'age <= 65'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
    QuestionOption(label: 'Je ne sais pas', value: null),
  ],
  createsTimelineItem: true,
  timelineRule: 'Rappel annuel: vérifier bénéficiaires/assurances',
  sensitivity: DataSensitivity.high,
)
```

**Échéances créées :**
- 10 ans avant retraite cible : "plan retraite complet"
- 3 ans avant : "décision rente/capital + planification fiscale"
- Annuel : "bénéficiaires/assurances"

### 65+ (Retraite)

```dart
// q_retired_expenses_vs_planned
WizardQuestion(
  id: 'q_retired_expenses_vs_planned',
  type: QuestionType.choice,
  category: QuestionCategory.cashflow,
  question: 'Dépenses réelles vs prévues ?',
  subtitle: 'Pour ajuster le plan de retrait.',
  tags: ['age_band:65+', 'cashflow'],
  conditions: ['age >= 65'],
  options: [
    QuestionOption(label: 'Au-dessus', value: 'above'),
    QuestionOption(label: 'Conforme', value: 'as_planned'),
    QuestionOption(label: 'En-dessous', value: 'below'),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.medium,
)

// q_retired_capital_withdrawals
WizardQuestion(
  id: 'q_retired_capital_withdrawals',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'Retraits du capital planifiés ?',
  subtitle: 'Pour optimiser la fiscalité.',
  tags: ['age_band:65+', 'pension', 'fiscal'],
  conditions: ['age >= 65'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
)

// q_retired_health_concerns
WizardQuestion(
  id: 'q_retired_health_concerns',
  type: QuestionType.choice,
  category: QuestionCategory.pension,
  question: 'Préoccupation santé / dépendance ?',
  subtitle: 'Pour adapter les conseils de couverture (avec prudence).',
  tags: ['age_band:65+', 'insurance'],
  conditions: ['age >= 65'],
  options: [
    QuestionOption(label: 'Oui', value: true),
    QuestionOption(label: 'Non', value: false),
  ],
  createsTimelineItem: false,
  sensitivity: DataSensitivity.high,
)
```

**Échéances créées :**
- Annuel : "bilan budget retraite + impôts + bénéficiaires"
- Événement santé : delta session "dépenses & couverture"

---

## 4. Événements de Vie (Déclencheurs Delta-Session)

```dart
enum LifeEventType {
  newJob,
  salaryIncrease,
  jobLoss,
  marriage,
  separation,
  divorce,
  birth,
  adoption,
  housingPurchase,
  housingSale,
  cantonMove,
  deathOfRelative,
  disability,
  workIncapacity,
  seriousIllness,
  inheritance,
  donation,
  selfEmployment,              // ⭐ NOUVEAU : Début activité indépendante
  employmentStatusChange,      // ⭐ NOUVEAU : Changement de statut (salarié → indépendant ou inverse)
  lppAffiliation,              // ⭐ NOUVEAU : Affiliation à une caisse LPP (volontaire ou via emploi)
  lppDisaffiliation,           // ⭐ NOUVEAU : Sortie d'une caisse LPP
  leasingEnd,
  creditEnd,
  mortgageRenewal,
}
```

Chaque événement déclenche une **mini-session delta** (3-6 questions max) et crée des **timeline items**.

### Événements Liés au Statut d'Emploi (Détails)

#### 1. Nouveau Job (newJob)
**Questions delta** :
- Nouveau revenu net mensuel
- Certificat LPP disponible ?
- Date de début
- Transfert LPP à planifier ?

**Timeline items créés** :
- "Transférer LPP de l'ancien employeur" (dans les 30 jours)
- "Vérifier mise à jour 3a" (dans les 60 jours)
- "Mettre à jour bénéficiaires assurances" (dans les 90 jours)

#### 2. Début Activité Indépendante (selfEmployment)
**Questions delta** :
- Forme juridique
- Revenu net estimé
- As-tu quitté une caisse LPP ?
- Solution LPP volontaire envisagée ?
- Couverture décès/invalidité en place ?

**Timeline items créés** :
- "Mettre à jour prévoyance (LPP/3a) suite changement de statut" (dans les 30 jours)
- "Évaluer couverture protection (décès/invalidité)" (dans les 60 jours)
- "Rappel annuel (décembre) : optimiser montant 3a (20% net, plafond)" (récurrent)

#### 3. Changement de Statut d'Emploi (employmentStatusChange)
**Questions delta** :
- Nouveau statut (salarié → indépendant ou inverse)
- Date effective du changement
- Impact sur LPP ?
- Impact sur revenus ?

**Timeline items créés** :
- "Mettre à jour prévoyance (LPP/3a)" (dans les 30 jours)
- "Revoir couverture assurances" (dans les 60 jours)
- "Bilan fiscal suite changement statut" (dans les 90 jours)

#### 4. Affiliation LPP (lppAffiliation)
**Questions delta** :
- Type d'affiliation (employeur / volontaire)
- Date d'affiliation
- Certificat LPP reçu ?

**Timeline items créés** :
- "Mettre à jour plafond 3a (passage à CHF 7'258)" (immédiat)
- "Upload certificat LPP" (dans les 30 jours)

#### 5. Sortie LPP (lppDisaffiliation)
**Questions delta** :
- Raison de la sortie
- Capital LPP à transférer ?
- Nouvelle activité ?

**Timeline items créés** :
- "Mettre à jour plafond 3a (passage à 20% revenu net)" (immédiat)
- "Évaluer couverture protection" (dans les 30 jours)

---

## 5. Règles de Timeline

### Dates Explicites à Collecter

- `q_13th_salary_month` → Rappel versement 3a
- `q_mortgage_fixed_end_date` → Rappel 120 jours avant
- `q_leasing_end_date` → Rappel 60 jours avant
- `q_consumer_credit_end_date` → Rappel 30 jours avant
- `q_mid_housing_purchase_date` → Rappel 12 mois avant
- `q_preretire_target_age` → Rappel 10 ans avant
- `q_employee_job_change_date` → Rappel 30 jours avant (transfert LPP)

### Rappels Récurrents

#### Pour Tous
- **Décembre** : rappel 3a / bilan fiscal
- **Annuel** : revue plan + bénéficiaires/assurances
- **Trimestriel** : budget famille (si enfants + safe mode)

#### Spécifiques aux Salariés avec LPP
- **Annuel (après réception certificat LPP)** : "Évaluer potentiel rachat LPP"
- **Avant changement d'emploi** : "Planifier transfert LPP"

#### Spécifiques aux Indépendants sans LPP
- **Annuel (décembre)** : "Optimiser montant 3a (20% net, plafond)"
- **Annuel** : "Revoir couverture protection (décès/invalidité)"
- **Tous les 2 ans** : "Évaluer opportunité affiliation LPP volontaire"

#### Spécifiques aux Mixtes
- **Annuel (novembre)** : "Vérifier calcul correct plafond 3a (statut mixte)"
- **Annuel** : "Bilan fiscal complexe (revenus multiples)"


---

## Format JSON (Exemple)

```json
{
  "id": "q_canton",
  "type": "canton",
  "category": "profile",
  "question": "Canton d'imposition actuel ?",
  "subtitle": "La fiscalité en dépend énormément.",
  "tags": ["core", "all", "fiscal"],
  "required": true,
  "allowSkip": false,
  "conditions": [],
  "createsTimelineItem": false,
  "sensitivity": "low"
}
```

---

**Cette spec est prête à coder** ! 🎯
