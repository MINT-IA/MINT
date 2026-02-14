import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/data/cantonal_data.dart';

class WizardQuestions {
  static List<WizardQuestion> get questions => [
        // === 1. IDENTITÉ & LOCALISATION (LE CADRE SUISSE) ===
        WizardQuestion(
          id: 'q_firstname',
          title: 'Comment t\'appelles-tu ?',
          type: QuestionType.text,
        ),
        WizardQuestion(
          id: 'q_birth_year',
          title: 'Ton année de naissance',
          type: QuestionType.number,
          minValue: 1940,
          maxValue: 2010,
        ),
        WizardQuestion(
          id: 'q_canton',
          title: 'Dans quel canton habites-tu ?',
          subtitle:
              'La fiscalité et les aides changent radicalement selon le canton (et même la commune !).',
          type: QuestionType.choice,
          options: CantonalDataService.cantons.values
              .map((c) =>
                  QuestionOption(label: '${c.name} (${c.code})', value: c.code))
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label)),
        ),

        // === 2. SITUATION FAMILIALE (LE RISQUE JURIDIQUE) ===
        WizardQuestion(
          id: 'q_civil_status',
          title: 'Quelle est ta situation familiale ?',
          subtitle:
              'En Suisse, le "Concubinage" n\'offre presque aucune protection juridique comparé au Mariage.',
          type: QuestionType.choice,
          options: [
            QuestionOption(
                label: 'Célibataire', value: 'single', icon: 'person'),
            QuestionOption(
                label: 'Concubinage (Vie commune)',
                value: 'cohabiting',
                icon: 'group'),
            QuestionOption(
                label: 'Marié(e) / Pacsé(e)',
                value: 'married',
                icon: 'favorite'),
            QuestionOption(
                label: 'Divorcé(e) / Séparé(e)',
                value: 'divorced',
                icon: 'broken_image'),
            QuestionOption(
                label: 'Veuf / Veuve', value: 'widowed', icon: 'church'),
          ],
        ),
        WizardQuestion(
          id: 'q_children',
          title: 'As-tu des enfants à charge ?',
          type: QuestionType.choice,
          options: [
            QuestionOption(label: 'Non', value: 'no', icon: 'close'),
            QuestionOption(label: '1 enfant', value: '1', icon: 'child_care'),
            QuestionOption(label: '2 enfants', value: '2', icon: 'child_care'),
            QuestionOption(
                label: '3 enfants ou plus',
                value: '3+',
                icon: 'escalator_warning'),
          ],
        ),

        // === 3. EMPLOI & REVENUS (LE CASHFLOW) ===
        WizardQuestion(
          id: 'q_employment_status',
          title: 'Quel est ton statut professionnel ?',
          subtitle: 'Cela détermine tes droits LPP, Chômage et tes déductions.',
          type: QuestionType.choice,
          options: [
            QuestionOption(
                label: 'Salarié(e)', value: 'employee', icon: 'work'),
            QuestionOption(
                label: 'Indépendant(e)',
                value: 'self_employed',
                icon: 'business_center'),
            QuestionOption(
                label: 'Sans emploi / Formation',
                value: 'unemployed',
                icon: 'school'),
            QuestionOption(
                label: 'Retraité(e)', value: 'retired', icon: 'elderly'),
          ],
        ),
        // Budget Section
        WizardQuestion(
          id: 'q_pay_frequency',
          title: 'Fréquence de tes revenus ?',
          type: QuestionType.choice,
          tags: ['budget'],
          options: [
            QuestionOption(
                label: 'Mensuel', value: 'monthly', icon: 'calendar_month'),
            QuestionOption(
                label: 'Bi-mensuel (2 sem.)',
                value: 'biweekly',
                icon: 'timelapse'),
            QuestionOption(
                label: 'Hebdomadaire', value: 'weekly', icon: 'view_week'),
          ],
        ),
        WizardQuestion(
          id: 'q_net_income_period_chf',
          title: 'Revenu net par période ?',
          subtitle:
              'Ce que tu reçois sur ton compte (individuel ou du ménage si en couple).',
          type: QuestionType.number,
          tags: ['budget', 'sensitive'],
          minValue: 0,
        ),
        WizardQuestion(
          id: 'q_housing_cost_period_chf',
          title: 'Coût logement par période ?',
          subtitle: 'Loyer ou Hypothèque + Charges.',
          type: QuestionType.number,
          tags: ['budget', 'housing'],
          minValue: 0,
        ),
        WizardQuestion(
          id: 'q_debt_payments_period_chf',
          title: 'Remboursements dettes par période ?',
          subtitle: 'Leasing, crédits (hors hypothèque).',
          hint: 'Mettre 0 si aucune dette.',
          type: QuestionType.number,
          tags: ['budget', 'debt'],
          minValue: 0,
        ),
        WizardQuestion(
          id: 'q_budget_style',
          title: 'Comment veux-tu gérer ton budget ?',
          type: QuestionType.choice,
          tags: ['budget'],
          options: [
            QuestionOption(
                label: 'Juste le disponible',
                value: 'just_available',
                icon: 'visibility'),
            QuestionOption(
                label: 'Enveloppes (3)',
                value: 'envelopes_3',
                icon: 'pie_chart'),
          ],
        ),

        // === 4. PRÉVOYANCE (LE FUTUR) ===
        WizardQuestion(
          id: 'q_has_pension_fund',
          title: 'Es-tu affilié à un 2e pilier (LPP) ?',
          subtitle: 'Indispensable pour connaître ta limite 3a.',
          type: QuestionType.choice,
          // L'auto-skip pour salarié n'est pas géré ici mais dans le service,
          // mais on garde la question pour les cas ambigus.
          options: [
            QuestionOption(label: 'Oui', value: 'yes', icon: 'check'),
            QuestionOption(label: 'Non', value: 'no', icon: 'close'),
            QuestionOption(
                label: 'Je ne sais pas', value: 'unknown', icon: 'help'),
          ],
        ),
        WizardQuestion(
          id: 'q_has_3a',
          title: 'As-tu déjà un 3a ?',
          subtitle: 'Le plafond déductible 2025 est de CHF 7\'258 (salariés).',
          type: QuestionType.choice,
          options: [
            QuestionOption(label: 'Oui', value: 'yes', icon: 'savings'),
            QuestionOption(
                label: 'Non', value: 'no', icon: 'add_circle_outline'),
          ],
        ),

        // === 5. OBJECTIFS (L'INTENTION) ===
        WizardQuestion(
          id: 'q_goal_template',
          title: 'Objectif prioritaire actuel ?',
          type: QuestionType.choice,
          options: [
            QuestionOption(
                label: 'Réduire mes dettes',
                value: 'control_debts',
                icon: 'money_off'),
            QuestionOption(
                label: 'Fonds d\'urgence',
                value: 'emergency_fund',
                icon: 'savings'),
            QuestionOption(
                label: 'Moins d\'impôts',
                value: 'tax_basic',
                icon: 'receipt_long'),
            QuestionOption(
                label: 'Achat immobilier', value: 'house', icon: 'home'),
          ],
        ),
      ];

  // Alias for backward compatibility
  static List<WizardQuestion> get all => questions;
}
