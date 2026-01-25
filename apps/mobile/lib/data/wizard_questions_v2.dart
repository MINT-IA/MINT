import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/data/cantonal_data.dart';

/// Questions du wizard réorganisées selon la logique des cercles
/// ORDRE : Profil → Budget → Prévoyance → Patrimoine
class WizardQuestionsV2 {
  static List<WizardQuestion> get questions => [
        // ═══════════════════════════════════════════════════════════
        // SECTION 1 : PROFIL (5 questions - 2 minutes)
        // Objectif : Contexte minimal pour personnaliser le reste
        // ═══════════════════════════════════════════════════════════

        WizardQuestion(
          id: 'q_firstname',
          title: 'Comment t\'appelles-tu ?',
          subtitle: 'Optionnel - Pour personnaliser ton expérience',
          type: QuestionType.text,
          tags: ['profil'],
        ),

        WizardQuestion(
          id: 'q_birth_year',
          title: 'Ton année de naissance',
          subtitle: 'Pour calculer ton horizon retraite et tes options',
          type: QuestionType.number,
          minValue: 1940,
          maxValue: 2010,
          tags: ['profil'],
        ),

        WizardQuestion(
          id: 'q_canton',
          title: 'Dans quel canton habites-tu ?',
          subtitle: 'La fiscalité change radicalement selon le canton',
          type: QuestionType.choice,
          options: CantonalDataService.cantons.values
              .map((c) =>
                  QuestionOption(label: '${c.name} (${c.code})', value: c.code))
              .toList()
            ..sort((a, b) => a.label.compareTo(b.label)),
          tags: ['profil'],
        ),

        WizardQuestion(
          id: 'q_civil_status',
          title: 'Quelle est ta situation familiale ?',
          subtitle:
              'Impact fiscal majeur : Marié = Splitting, Concubinage = Aucun avantage',
          type: QuestionType.choice,
          options: [
            QuestionOption(
                label: 'Célibataire', value: 'single', icon: 'person'),
            QuestionOption(
                label: 'Concubinage', value: 'cohabiting', icon: 'group'),
            QuestionOption(
                label: 'Marié(e)', value: 'married', icon: 'favorite'),
            QuestionOption(
                label: 'Divorcé(e)', value: 'divorced', icon: 'person_remove'),
          ],
          tags: ['profil'],
        ),

        WizardQuestion(
          id: 'q_children',
          title: 'Combien d\'enfants à charge as-tu ?',
          subtitle: 'Chaque enfant = déduction fiscale ~6\'500-9\'000 CHF',
          type: QuestionType.choice,
          options: [
            QuestionOption(label: 'Aucun', value: '0'),
            QuestionOption(label: '1 enfant', value: '1'),
            QuestionOption(label: '2 enfants', value: '2'),
            QuestionOption(label: '3 enfants ou plus', value: '3'),
          ],
          tags: ['profil'],
        ),

        WizardQuestion(
          id: 'q_employment_status',
          title: 'Quelle est ta situation professionnelle ?',
          subtitle:
              'Salarié = LPP obligatoire + 3a max 7\'258 CHF\nIndépendant = Pas de LPP + 3a max 36\'288 CHF',
          type: QuestionType.choice,
          options: [
            QuestionOption(
                label: 'Salarié(e)', value: 'employee', icon: 'work'),
            QuestionOption(
                label: 'Indépendant(e)',
                value: 'self_employed',
                icon: 'business'),
            QuestionOption(
                label: 'Sans emploi', value: 'unemployed', icon: 'person_off'),
            QuestionOption(
                label: 'Retraité(e)', value: 'retired', icon: 'elderly'),
          ],
          tags: ['profil'],
        ),

        // ═══════════════════════════════════════════════════════════
        // SECTION 2 : CERCLE 1 - BUDGET & PROTECTION (6 questions - 3 min)
        // Objectif : Calculer la capacité d'épargne AVANT de parler d'investissement
        // ═══════════════════════════════════════════════════════════

        WizardQuestion(
          id: 'q_pay_frequency',
          title: 'À quelle fréquence reçois-tu ton salaire ?',
          subtitle: 'Pour calculer ton revenu mensuel précisément',
          type: QuestionType.choice,
          options: [
            QuestionOption(
                label: 'Mensuel', value: 'monthly', icon: 'calendar_month'),
            QuestionOption(
                label: 'Bimensuel (2x/mois)',
                value: 'biweekly',
                icon: 'timelapse'),
            QuestionOption(
                label: 'Hebdomadaire', value: 'weekly', icon: 'view_week'),
          ],
          tags: ['budget'],
        ),

        WizardQuestion(
          id: 'q_net_income_period_chf',
          title: 'Revenu net par période ?',
          subtitle:
              'Ce que tu reçois sur ton compte. Si marié(e), indique le revenu total du ménage.',
          type: QuestionType.number,
          tags: ['budget', 'sensitive'],
          minValue: 0,
        ),

        WizardQuestion(
          id: 'q_housing_status',
          title: 'Tu es... ?',
          subtitle: 'Ton type de logement',
          type: QuestionType.choice,
          options: [
            QuestionOption(label: 'Locataire', value: 'renter', icon: 'home'),
            QuestionOption(
                label: 'Propriétaire', value: 'owner', icon: 'house'),
            QuestionOption(
                label: 'Chez famille/parents',
                value: 'family',
                icon: 'family_restroom'),
          ],
          tags: ['budget', 'housing'],
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
          id: 'q_has_consumer_debt',
          title: 'As-tu des dettes de consommation ?',
          subtitle:
              'Crédit, leasing voiture/meubles (hors hypothèque)\n⚠️ Priorité : Rembourser avant d\'investir !',
          type: QuestionType.choice,
          options: [
            QuestionOption(label: 'Non', value: 'no', icon: 'check_circle'),
            QuestionOption(label: 'Oui', value: 'yes', icon: 'warning'),
          ],
          tags: ['budget', 'debt'],
        ),

        WizardQuestion(
          id: 'q_emergency_fund',
          title: 'As-tu un fonds d\'urgence ?',
          subtitle:
              'Argent liquide (pas bloqué) pour couvrir 3-6 mois de charges en cas de coup dur',
          type: QuestionType.choice,
          options: [
            QuestionOption(
                label: 'Oui, 6+ mois', value: 'yes_6months', icon: 'shield'),
            QuestionOption(
                label: 'Oui, 3-6 mois', value: 'yes_3months', icon: 'verified'),
            QuestionOption(label: 'Non, < 3 mois', value: 'no', icon: 'error'),
          ],
          tags: ['budget', 'protection'],
        ),

        WizardQuestion(
          id: 'q_savings_monthly',
          title: 'Combien arrives-tu à épargner par mois ?',
          subtitle:
              'En moyenne, une fois toutes tes charges payées (Loyer, Impôts, Assurances...)',
          type: QuestionType.number,
          minValue: 0,
          tags: ['budget', 'savings'],
        ),

        // ═══════════════════════════════════════════════════════════
        // SECTION 3 : CERCLE 2 - PRÉVOYANCE FISCALE (7 questions - 4 min)
        // Objectif : Optimiser la prévoyance MAINTENANT qu'on connaît le budget
        // ═══════════════════════════════════════════════════════════

        WizardQuestion(
          id: 'q_has_pension_fund',
          title: 'Es-tu affilié à une caisse de pension (LPP) ?',
          subtitle: 'Si salarié avec salaire >22k CHF = Oui automatiquement',
          type: QuestionType.choice,
          options: [
            QuestionOption(label: 'Oui', value: 'yes', icon: 'verified'),
            QuestionOption(label: 'Non', value: 'no', icon: 'cancel'),
            QuestionOption(
                label: 'Je ne sais pas', value: 'unknown', icon: 'help'),
          ],
          tags: ['prevoyance', 'lpp'],
        ),

        WizardQuestion(
          id: 'q_lpp_buyback_available',
          title: 'Peux-tu racheter ta LPP ?',
          subtitle:
              'Regarde ton certificat LPP → Ligne "Montant rachetable"\nSi rien inscrit = 0',
          type: QuestionType.number,
          minValue: 0,
          tags: ['prevoyance', 'lpp'],
        ),

        WizardQuestion(
          id: 'q_has_3a',
          title: 'As-tu déjà ouvert un compte 3e pilier (3a) ?',
          subtitle: 'C\'est le meilleur outil fiscal en Suisse.',
          type: QuestionType.choice,
          options: [
            QuestionOption(label: 'Oui', value: 'yes', icon: 'verified'),
            QuestionOption(label: 'Non', value: 'no', icon: 'cancel'),
          ],
          tags: ['prevoyance', '3a'],
        ),

        WizardQuestion(
          id: 'q_3a_accounts_count',
          title: 'Combien de comptes 3a as-tu ?',
          subtitle:
              '💡 Optimal : 2-3 comptes pour optimiser la fiscalité au retrait',
          type: QuestionType.choice,
          options: [
            QuestionOption(label: 'Aucun', value: '0'),
            QuestionOption(label: '1 compte', value: '1'),
            QuestionOption(label: '2 comptes', value: '2'),
            QuestionOption(label: '3 comptes ou plus', value: '3'),
          ],
          tags: ['prevoyance', '3a'],
        ),

        WizardQuestion(
          id: 'q_3a_providers',
          title: 'Où sont tes 3a actuellement ?',
          subtitle: 'Tu peux sélectionner plusieurs si tu as plusieurs comptes',
          type: QuestionType.multiChoice,
          options: [
            QuestionOption(
                label: '🏦 Banque (UBS, CS, Raiffeisen...)', value: 'bank'),
            QuestionOption(
                label: '🛡️ Assurance (AXA, Zurich, SwissLife...)',
                value: 'insurance'),
            QuestionOption(
                label: '🔀 Mixte (Banque + Assurance)', value: 'mixed'),
            QuestionOption(
                label: '📱 Fintech (VIAC, Finpension...)', value: 'fintech'),
          ],
          tags: ['prevoyance', '3a'],
        ),

        WizardQuestion(
          id: 'q_3a_annual_contribution',
          title: 'Combien verses-tu par an dans ton/tes 3a ?',
          subtitle:
              'Max salarié : 7\'258 CHF\nMax indépendant : 36\'288 CHF (20% revenu)',
          type: QuestionType.number,
          minValue: 0,
          tags: ['prevoyance', '3a'],
        ),

        WizardQuestion(
          id: 'q_avs_gaps',
          title: 'As-tu des lacunes dans ton compte AVS ?',
          subtitle:
              'Commande ton extrait gratuit sur ahv-iv.ch\nChaque année manquante = -2.3% de rente AVS à vie',
          type: QuestionType.choice,
          options: [
            QuestionOption(
                label: 'Non, tout complet', value: 'no', icon: 'check_circle'),
            QuestionOption(
                label: 'Oui, j\'ai des lacunes', value: 'yes', icon: 'warning'),
            QuestionOption(
                label: 'Je ne sais pas', value: 'unknown', icon: 'help'),
          ],
          tags: ['prevoyance', 'avs'],
        ),

        // ═══════════════════════════════════════════════════════════
        // SECTION 4 : CERCLE 3 - CROISSANCE & PATRIMOINE (4 questions - 3 min)
        // Objectif : Investissements et patrimoine (uniquement si cercles 1-2 OK)
        // ═══════════════════════════════════════════════════════════

        WizardQuestion(
          id: 'q_has_investments',
          title: 'As-tu des investissements hors-pilier ?',
          subtitle: 'Actions, ETF, Crypto, Fonds... (hors 3a et LPP)',
          type: QuestionType.choice,
          options: [
            QuestionOption(label: 'Non', value: 'no'),
            QuestionOption(label: 'Oui', value: 'yes'),
          ],
          tags: ['patrimoine', 'investments'],
        ),

        WizardQuestion(
          id: 'q_real_estate_project',
          title: 'Projet immobilier dans les 3 ans ?',
          subtitle:
              '⚠️ Important : Si rachat LPP + achat immo proche = Incompatible légalement',
          type: QuestionType.choice,
          options: [
            QuestionOption(label: 'Non', value: 'no'),
            QuestionOption(
                label: 'Oui, achat résidence principale', value: 'yes_main'),
            QuestionOption(
                label: 'Oui, investissement locatif', value: 'yes_rental'),
          ],
          tags: ['patrimoine', 'real_estate'],
        ),

        WizardQuestion(
          id: 'q_main_goal',
          title: 'Ton objectif financier principal ?',
          subtitle: 'Ce qui te motive à optimiser ta situation',
          type: QuestionType.choice,
          options: [
            QuestionOption(
                label: 'Retraite confortable',
                value: 'retirement',
                icon: 'beach_access'),
            QuestionOption(
                label: 'Achat immobilier', value: 'real_estate', icon: 'house'),
            QuestionOption(
                label: 'Indépendance financière',
                value: 'independence',
                icon: 'flight_takeoff'),
            QuestionOption(
                label: 'Transmettre un héritage',
                value: 'inheritance',
                icon: 'family_restroom'),
            QuestionOption(
                label: 'Voyage/Projet personnel',
                value: 'project',
                icon: 'luggage'),
          ],
          tags: ['patrimoine', 'goals'],
        ),

        WizardQuestion(
          id: 'q_risk_tolerance',
          title: 'Face aux fluctuations de marché, tu es plutôt :',
          subtitle: 'Ton niveau de confort avec le risque',
          type: QuestionType.choice,
          options: [
            QuestionOption(
                label: 'Prudent - Je dors mal si ça baisse de 10%',
                value: 'conservative'),
            QuestionOption(
                label: 'Équilibré - J\'accepte du risque mesuré',
                value: 'balanced'),
            QuestionOption(
                label: 'Dynamique - Je vise le long terme',
                value: 'aggressive'),
          ],
          tags: ['patrimoine', 'risk'],
        ),
      ];
}
