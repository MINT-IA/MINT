import 'package:mint_mobile/models/wizard_question.dart';
import 'package:mint_mobile/data/cantonal_data.dart';

/// Questions du wizard réorganisées selon la logique des cercles
/// ORDRE : Profil → Budget → Prévoyance → Patrimoine
class WizardQuestionsV2 {
  static List<WizardQuestion> get questions => [
        // ═══════════════════════════════════════════════════════════
        // SECTION 1 : PROFIL (8 questions - 2 minutes)
        // Objectif : Contexte minimal pour personnaliser le reste
        // Note: Stress check removed — redundant with q_main_goal
        // and already captured by mini-onboarding flow.
        // ═══════════════════════════════════════════════════════════

        const WizardQuestion(
          id: 'q_firstname',
          title: 'Comment t\'appelles-tu ?',
          subtitle: 'Optionnel - Pour personnaliser ton expérience',
          type: QuestionType.text,
          tags: ['profil'],
        ),

        const WizardQuestion(
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

        const WizardQuestion(
          id: 'q_residence_permit',
          title: 'Quel est ton permis de séjour ?',
          subtitle:
              'Impact fiscal majeur : Permis B = impôt à la source (LIFD art. 83-86).\n'
              'Permis C/Suisse = déclaration ordinaire.',
          type: QuestionType.choice,
          options: [
            QuestionOption(
                label: 'Nationalité suisse', value: 'swiss', icon: 'flag'),
            QuestionOption(
                label: 'Permis C (établissement)', value: 'permit_c', icon: 'verified'),
            QuestionOption(
                label: 'Permis B (séjour)', value: 'permit_b', icon: 'badge'),
            QuestionOption(
                label: 'Permis G (frontalier)', value: 'permit_g', icon: 'commute'),
          ],
          tags: ['profil'],
        ),

        const WizardQuestion(
          id: 'q_civil_status',
          title: 'Quelle est ta situation familiale ?',
          subtitle:
              'Impact fiscal majeur : Marie = Splitting. '
              'Concubinage = ZERO avantage legal (pas de solidarite, pas de succession, pas de rente survivant).',
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
            QuestionOption(
                label: 'Veuf/Veuve', value: 'widowed', icon: 'sentiment_very_dissatisfied'),
            QuestionOption(
                label: 'Partenariat enregistré', value: 'registered_partner', icon: 'diversity_1'),
          ],
          tags: ['profil'],
        ),

        const WizardQuestion(
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

        const WizardQuestion(
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
                label: 'Étudiant(e)',
                value: 'student',
                icon: 'school'),
            QuestionOption(
                label: 'Sans emploi', value: 'unemployed', icon: 'person_off'),
            QuestionOption(
                label: 'Retraité(e)', value: 'retired', icon: 'elderly'),
          ],
          tags: ['profil'],
        ),

        WizardQuestion(
          id: 'q_activity_rate',
          title: 'Ton taux d\'activité ?',
          subtitle:
              'Affecte ta déduction de coordination LPP (art. 8 al. 1).\n'
              'À 80%, ta couverture LPP est réduite proportionnellement.',
          type: QuestionType.choice,
          options: [
            const QuestionOption(label: '100%', value: '100'),
            const QuestionOption(label: '80%', value: '80'),
            const QuestionOption(label: '60%', value: '60'),
            const QuestionOption(label: 'Moins de 60%', value: 'other'),
          ],
          tags: ['profil'],
          condition: (answers) => answers['q_employment_status'] == 'employee',
        ),

        // ═══════════════════════════════════════════════════════════
        // SECTION 2 : CERCLE 1 - BUDGET & PROTECTION (9 questions - 3 min)
        // Objectif : Calculer la capacité d'épargne AVANT de parler d'investissement
        // ═══════════════════════════════════════════════════════════

        const WizardQuestion(
          id: 'q_net_income_period_chf',
          title: 'Ton revenu net mensuel ?',
          subtitle:
              'Ce que tu reçois sur ton compte chaque mois.\nSi marié·e, indique le revenu total du ménage.',
          type: QuestionType.number,
          tags: ['budget', 'sensitive'],
          minValue: 0,
        ),

        WizardQuestion(
          id: 'q_gross_income',
          title: 'Ton salaire brut mensuel ?',
          subtitle:
              'Ligne "Salaire brut" sur ta fiche de paie.\n'
              'Permet de vérifier tes cotisations AVS/LPP/AC.',
          type: QuestionType.number,
          tags: ['budget', 'income'],
          minValue: 0,
          condition: (answers) => answers['q_employment_status'] == 'employee',
        ),

        const WizardQuestion(
          id: 'q_housing_status',
          title: 'Quel est ton statut de logement ?',
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

        const WizardQuestion(
          id: 'q_housing_cost_period_chf',
          title: 'Coût logement par mois ?',
          subtitle: 'Loyer ou hypothèque + charges.',
          type: QuestionType.number,
          tags: ['budget', 'housing'],
          minValue: 0,
        ),

        const WizardQuestion(
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

        // Follow-up: montant mensuel des remboursements
        WizardQuestion(
          id: 'q_debt_payments_period_chf',
          title: 'Combien rembourses-tu par mois ?',
          subtitle:
              'Total de tous tes remboursements mensuels\n(leasing, petit crédit, cartes de crédit…)',
          type: QuestionType.number,
          tags: ['budget', 'debt'],
          minValue: 0,
          condition: (answers) => answers['q_has_consumer_debt'] == 'yes',
        ),

        // Follow-up: solde total restant
        WizardQuestion(
          id: 'q_total_debt_balance_chf',
          title: 'Quel est le solde total de tes dettes ?',
          subtitle:
              'Montant total restant à rembourser (tous crédits confondus).\nNécessaire pour calculer un plan de sortie.',
          type: QuestionType.number,
          tags: ['budget', 'debt'],
          minValue: 0,
          condition: (answers) => answers['q_has_consumer_debt'] == 'yes',
        ),

        const WizardQuestion(
          id: 'q_lamal_franchise',
          title: 'Quelle est ta franchise LAMal ?',
          subtitle:
              'Franchise haute (2500 CHF) = primes basses mais risque élevé en cas de maladie.\n'
              'Franchise basse (300 CHF) = primes hautes mais protection maximale.',
          type: QuestionType.choice,
          options: [
            QuestionOption(label: 'CHF 300 (minimum)', value: '300'),
            QuestionOption(label: 'CHF 500', value: '500'),
            QuestionOption(label: 'CHF 1\'000', value: '1000'),
            QuestionOption(label: 'CHF 1\'500', value: '1500'),
            QuestionOption(label: 'CHF 2\'000', value: '2000'),
            QuestionOption(label: 'CHF 2\'500 (maximum)', value: '2500'),
          ],
          tags: ['budget', 'lamal'],
        ),

        // q_emergency_fund REMOVED — deduced from q_cash_total / monthly expenses
        // q_savings_monthly REMOVED — deduced from income - total expenses

        WizardQuestion(
          id: 'q_savings_allocation',
          title: 'Où va ton épargne mensuelle ?',
          subtitle:
              'Sélectionne tous les postes vers lesquels tu diriges ton épargne chaque mois.\n'
              'Tu pourras ajuster les montants ensuite.',
          type: QuestionType.multiChoice,
          options: [
            const QuestionOption(
                label: '💰 Pilier 3a',
                value: '3a',
                icon: 'savings'),
            const QuestionOption(
                label: '🏛️ Rachat LPP',
                value: 'lpp_buyback',
                icon: 'account_balance'),
            const QuestionOption(
                label: '📈 Investissements (ETF, actions...)',
                value: 'investissement',
                icon: 'trending_up'),
            const QuestionOption(
                label: '🏦 Épargne libre (compte épargne)',
                value: 'epargne_libre',
                icon: 'wallet'),
          ],
          tags: ['budget', 'savings', 'allocation'],
          condition: (answers) {
            // Compute savings from income - ALL expenses (q_savings_monthly removed)
            double parse(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
            final income = parse(answers['q_net_income_period_chf']);
            final housing = parse(answers['q_housing_cost_period_chf']);
            final debt = parse(answers['q_debt_payments_period_chf']);
            final tax = parse(answers['q_tax_provision_monthly_chf']);
            final lamal = parse(answers['q_lamal_premium_monthly_chf']);
            final other = parse(answers['q_other_fixed_costs_monthly_chf']);
            final surplus = income - housing - debt - tax - lamal - other;
            return surplus > 0;
          },
        ),

        // ═══════════════════════════════════════════════════════════
        // SECTION 3 : CERCLE 2 - PRÉVOYANCE FISCALE (12 questions - 4 min)
        // Objectif : Optimiser la prévoyance MAINTENANT qu'on connaît le budget
        // ═══════════════════════════════════════════════════════════

        const WizardQuestion(
          id: 'q_has_pension_fund',
          title: 'Es-tu affilié à une caisse de pension (LPP) ?',
          subtitle: 'Si salarié avec salaire >22k CHF = Oui automatiquement',
          type: QuestionType.choice,
          options: [
            const QuestionOption(label: 'Oui', value: 'yes', icon: 'verified'),
            const QuestionOption(label: 'Non', value: 'no', icon: 'cancel'),
            const QuestionOption(
                label: 'Je ne sais pas', value: 'unknown', icon: 'help'),
          ],
          tags: ['prevoyance', 'lpp'],
        ),

        const WizardQuestion(
          id: 'q_lpp_buyback_available',
          title: 'Peux-tu racheter ta LPP ?',
          subtitle:
              'Regarde ton certificat LPP → Ligne "Montant rachetable"\nSi rien inscrit = 0',
          type: QuestionType.number,
          minValue: 0,
          tags: ['prevoyance', 'lpp'],
        ),

        const WizardQuestion(
          id: 'q_lpp_current_capital',
          title: 'Quel est ton avoir de vieillesse LPP actuel ?',
          subtitle:
              'Ligne "Avoir de vieillesse" sur ton certificat de prévoyance.\n'
              'Inclut la part obligatoire et surobligatoire.',
          type: QuestionType.number,
          tags: ['prevoyance', 'lpp'],
          minValue: 0,
        ),

        const WizardQuestion(
          id: 'q_has_3a',
          title: 'As-tu déjà ouvert un compte 3e pilier (3a) ?',
          subtitle: 'C\'est l\'un des outils fiscaux les plus avantageux en Suisse.',
          type: QuestionType.choice,
          options: [
            const QuestionOption(label: 'Oui', value: 'yes', icon: 'verified'),
            const QuestionOption(label: 'Non', value: 'no', icon: 'cancel'),
          ],
          tags: ['prevoyance', '3a'],
        ),

        const WizardQuestion(
          id: 'q_3a_accounts_count',
          title: 'Combien de comptes 3a as-tu ?',
          subtitle:
              '💡 Recommandé : 2-3 comptes pour répartir la fiscalité au retrait',
          type: QuestionType.choice,
          options: [
            const QuestionOption(label: 'Aucun', value: '0'),
            const QuestionOption(label: '1 compte', value: '1'),
            const QuestionOption(label: '2 comptes', value: '2'),
            const QuestionOption(label: '3 comptes ou plus', value: '3'),
          ],
          tags: ['prevoyance', '3a'],
        ),

        // q_3a_providers REMOVED — low value, zero calculation impact

        const WizardQuestion(
          id: 'q_3a_annual_contribution',
          title: 'Combien verses-tu par an dans ton/tes 3a ?',
          subtitle:
              'Max salarié : 7\'258 CHF\nMax indépendant : 36\'288 CHF (20% revenu)',
          type: QuestionType.number,
          minValue: 0,
          tags: ['prevoyance', '3a'],
        ),

        // AVS — Détection intelligente des lacunes de cotisation
        // L'échelle complète = 44 ans (LAVS art. 29ter) dès 21 ans.
        // On déduit les années théoriques depuis q_birth_year, puis on demande les lacunes.
        const WizardQuestion(
          id: 'q_avs_lacunes_status',
          title: 'As-tu des lacunes de cotisation AVS ?',
          subtitle:
              'Échelle complète = 44 ans de cotisation (dès 21 ans, LAVS art. 29ter).\n'
              'Chaque année manquante = −2.3% de rente à vie.',
          type: QuestionType.choice,
          options: [
            const QuestionOption(
                label: 'Non, j\'ai toujours cotisé en Suisse',
                value: 'no_gaps',
                icon: 'verified'),
            const QuestionOption(
                label: 'Arrivé·e en Suisse après 20 ans',
                value: 'arrived_late',
                icon: 'flight_land'),
            const QuestionOption(
                label: 'Période(s) à l\'étranger',
                value: 'lived_abroad',
                icon: 'public'),
            const QuestionOption(
                label: 'Je ne sais pas',
                value: 'unknown',
                icon: 'help'),
          ],
          tags: ['prevoyance', 'avs'],
        ),

        const WizardQuestion(
          id: 'q_avs_arrival_year',
          title: 'En quelle année es-tu arrivé·e en Suisse ?',
          subtitle:
              'Les années avant ton arrivée sont des lacunes AVS.\n'
              'Tu peux racheter les 5 dernières années manquantes (LAVS art. 16).',
          type: QuestionType.number,
          minValue: 1960,
          maxValue: 2026,
          tags: ['prevoyance', 'avs'],
        ),

        const WizardQuestion(
          id: 'q_avs_years_abroad',
          title: 'Combien d\'années as-tu passé hors de Suisse (après 20 ans) ?',
          subtitle:
              'Études, travail à l\'étranger, voyage... chaque année sans cotisation CH compte.\n'
              'Tes cotisations de jeunesse (18-20 ans) peuvent combler jusqu\'à 3 ans (RAVS art. 52b).',
          type: QuestionType.number,
          minValue: 0,
          maxValue: 40,
          tags: ['prevoyance', 'avs'],
        ),

        // Conjoint — même logique AVS
        // Condition : marié ou partenariat enregistré (CC art. 65a)
        // Concubinage EXCLU : pas de rente de couple AVS (LAVS art. 35)
        WizardQuestion(
          id: 'q_spouse_avs_lacunes_status',
          title: 'Et ton/ta conjoint·e, a-t-il/elle des lacunes AVS ?',
          subtitle: 'Impact direct sur la rente AVS de couple (plafond 150%, LAVS art. 35).',
          type: QuestionType.choice,
          options: [
            const QuestionOption(
                label: 'Non, toujours cotisé en Suisse',
                value: 'no_gaps',
                icon: 'verified'),
            const QuestionOption(
                label: 'Arrivé·e après 20 ans',
                value: 'arrived_late',
                icon: 'flight_land'),
            const QuestionOption(
                label: 'Période(s) à l\'étranger',
                value: 'lived_abroad',
                icon: 'public'),
            const QuestionOption(
                label: 'Je ne sais pas',
                value: 'unknown',
                icon: 'help'),
          ],
          tags: ['prevoyance', 'avs'],
          condition: (answers) {
            final civil = answers['q_civil_status'];
            return civil == 'married' || civil == 'registered_partner';
          },
        ),

        WizardQuestion(
          id: 'q_spouse_avs_arrival_year',
          title: 'En quelle année ton/ta conjoint·e est-il/elle arrivé·e en Suisse ?',
          subtitle: 'Pour estimer ses lacunes de cotisation AVS.',
          type: QuestionType.number,
          minValue: 1960,
          maxValue: 2026,
          tags: ['prevoyance', 'avs'],
          condition: (answers) {
            final civil = answers['q_civil_status'];
            return civil == 'married' || civil == 'registered_partner';
          },
        ),

        WizardQuestion(
          id: 'q_spouse_avs_years_abroad',
          title: 'Combien d\'années ton/ta conjoint·e a-t-il/elle passé hors de Suisse ?',
          subtitle: 'Après 20 ans — chaque année = lacune de cotisation.',
          type: QuestionType.number,
          minValue: 0,
          maxValue: 40,
          tags: ['prevoyance', 'avs'],
          condition: (answers) {
            final civil = answers['q_civil_status'];
            return civil == 'married' || civil == 'registered_partner';
          },
        ),

        // ═══════════════════════════════════════════════════════════
        // SECTION 4 : CERCLE 3 - CROISSANCE & PATRIMOINE (7 questions - 3 min)
        // Objectif : Investissements et patrimoine (uniquement si cercles 1-2 OK)
        // ═══════════════════════════════════════════════════════════

        const WizardQuestion(
          id: 'q_has_investments',
          title: 'As-tu des investissements hors-pilier ?',
          subtitle: 'Actions, ETF, Crypto, Fonds... (hors 3a et LPP)',
          type: QuestionType.choice,
          options: [
            const QuestionOption(label: 'Non', value: 'no'),
            const QuestionOption(label: 'Oui', value: 'yes'),
          ],
          tags: ['patrimoine', 'investments'],
        ),

        const WizardQuestion(
          id: 'q_has_life_insurance',
          title: 'As-tu une assurance vie ou décès ?',
          subtitle:
              'Assurance risque pur (décès/invalidité) ou mixte (3b).\n'
              'Essentiel pour protéger tes proches, surtout en concubinage.',
          type: QuestionType.choice,
          options: [
            const QuestionOption(label: 'Non', value: 'no', icon: 'cancel'),
            const QuestionOption(label: 'Oui, risque pur (décès)', value: 'yes_risk', icon: 'shield'),
            const QuestionOption(label: 'Oui, mixte (3b)', value: 'yes_3b', icon: 'savings'),
            const QuestionOption(label: 'Je ne sais pas', value: 'unknown', icon: 'help'),
          ],
          tags: ['patrimoine', 'insurance'],
        ),

        const WizardQuestion(
          id: 'q_real_estate_project',
          title: 'Projet immobilier dans les 3 ans ?',
          subtitle:
              '⚠️ Important : Si rachat LPP + achat immo proche = Incompatible légalement',
          type: QuestionType.choice,
          options: [
            const QuestionOption(label: 'Non', value: 'no'),
            const QuestionOption(
                label: 'Oui, achat résidence principale', value: 'yes_main'),
            const QuestionOption(
                label: 'Oui, investissement locatif', value: 'yes_rental'),
          ],
          tags: ['patrimoine', 'real_estate'],
        ),

        WizardQuestion(
          id: 'q_property_value',
          title: 'Valeur estimée de ton bien immobilier ?',
          subtitle:
              'Valeur vénale actuelle de ta résidence principale.\n'
              'Taxée comme fortune immobilière par le canton.',
          type: QuestionType.number,
          tags: ['patrimoine', 'real_estate'],
          minValue: 0,
          condition: (answers) => answers['q_housing_status'] == 'owner',
        ),

        WizardQuestion(
          id: 'q_mortgage_balance',
          title: 'Solde hypothécaire restant ?',
          subtitle:
              'Total de ta dette hypothécaire (1er + 2e rang).\n'
              'Les intérêts sont déductibles fiscalement (LIFD art. 33).',
          type: QuestionType.number,
          tags: ['patrimoine', 'real_estate'],
          minValue: 0,
          condition: (answers) => answers['q_housing_status'] == 'owner',
        ),

        const WizardQuestion(
          id: 'q_main_goal',
          title: 'Ton objectif financier principal ?',
          subtitle: 'Ce qui te motive à optimiser ta situation',
          type: QuestionType.choice,
          options: [
            const QuestionOption(
                label: 'Retraite confortable',
                value: 'retirement',
                icon: 'beach_access'),
            const QuestionOption(
                label: 'Achat immobilier', value: 'real_estate', icon: 'house'),
            const QuestionOption(
                label: 'Indépendance financière',
                value: 'independence',
                icon: 'flight_takeoff'),
            const QuestionOption(
                label: 'Sortir de l\'endettement',
                value: 'debt_free',
                icon: 'money_off'),
            const QuestionOption(
                label: 'Transmettre un héritage',
                value: 'inheritance',
                icon: 'family_restroom'),
            const QuestionOption(
                label: 'Voyage/Projet personnel',
                value: 'project',
                icon: 'luggage'),
          ],
          tags: ['patrimoine', 'goals'],
        ),

        const WizardQuestion(
          id: 'q_risk_tolerance',
          title: 'Face aux fluctuations de marché, tu es plutôt :',
          subtitle: 'Ton niveau de confort avec le risque',
          type: QuestionType.choice,
          options: [
            const QuestionOption(
                label: 'Prudent - Je dors mal si ça baisse de 10%',
                value: 'conservative'),
            const QuestionOption(
                label: 'Équilibré - J\'accepte du risque mesuré',
                value: 'balanced'),
            const QuestionOption(
                label: 'Dynamique - Je vise le long terme',
                value: 'aggressive'),
          ],
          tags: ['patrimoine', 'risk'],
        ),
      ];

  /// Retourne un subtitle adapté au profil pour certaines questions
  static String? getDynamicSubtitle(String questionId, Map<String, dynamic> answers) {
    if (questionId == 'q_net_income_period_chf') {
      // Concubinage: revenu individuel (pas de revenu du ménage)
      final civil = answers['q_civil_status'];
      if (civil == 'cohabiting') {
        return 'TON revenu personnel uniquement. '
            'En concubinage, chacun est impose individuellement (LIFD art. 9).';
      }
      final status = answers['q_employment_status'];
      switch (status) {
        case 'retired':
          return 'Tes rentes totales (AVS + LPP + éventuels 3a)';
        case 'unemployed':
          return 'Tes indemnités chômage nettes';
        case 'student':
          return 'Ton revenu (job étudiant, bourse, soutien familial)';
        case 'self_employed':
          return 'Ton revenu net après charges professionnelles';
        default:
          return null; // Use default subtitle
      }
    }
    // Context-aware subtitles for LPP buyback
    if (questionId == 'q_lpp_buyback_available') {
      final canton = answers['q_canton'] as String?;
      final income = answers['q_net_income_period_chf'];
      if (canton != null && income != null) {
        final monthlyIncome = double.tryParse(income.toString()) ?? 0;
        if (monthlyIncome > 0) {
          return 'Avec un revenu de CHF ${monthlyIncome.round()}/mois en $canton — '
              'vérifie ton certificat LPP, ligne "Montant rachetable". '
              'Déduction fiscale à 100% (LIFD art. 33 al. 1 let. d).';
        }
      }
    }

    // Context-aware subtitles for AVS gaps
    if (questionId == 'q_avs_lacunes_status') {
      final birthYear = answers['q_birth_year'];
      if (birthYear != null) {
        final by = birthYear is int ? birthYear : int.tryParse(birthYear.toString()) ?? 0;
        final expectedYears = (DateTime.now().year - by - 21).clamp(0, 44);
        return 'À ton âge, tu devrais avoir ~$expectedYears années de cotisation '
            '(échelle complète = 44 ans, LAVS art. 29ter). '
            'Chaque année manquante = -2.3% de rente à vie.';
      }
    }

    // Source taxation context
    if (questionId == 'q_residence_permit') {
      final canton = answers['q_canton'] as String?;
      if (canton != null) {
        return 'En $canton, le barème d\'impôt à la source (Permis B) peut '
            'différer significativement de la déclaration ordinaire (LIFD art. 83-86).';
      }
    }

    // Gross income context
    if (questionId == 'q_gross_income') {
      final net = answers['q_net_income_period_chf'];
      if (net != null) {
        final netIncome = double.tryParse(net.toString()) ?? 0;
        if (netIncome > 0) {
          final estimatedGross = (netIncome / 0.85).round(); // ~15% social charges
          return 'Ton net est CHF ${netIncome.round()}/mois. '
              'Le brut est généralement ~15% plus élevé (~CHF $estimatedGross). '
              'Vérifie sur ta fiche de paie.';
        }
      }
    }

    // LAMal franchise context
    if (questionId == 'q_lamal_franchise') {
      final canton = answers['q_canton'] as String?;
      if (canton != null) {
        return 'En $canton, passer de CHF 300 à CHF 2\'500 de franchise '
            'peut économiser CHF 100-200/mois de primes. '
            'Règle : si tu as >CHF 5\'000 d\'épargne disponible, la franchise haute est souvent rentable.';
      }
    }

    // LPP current capital context
    if (questionId == 'q_lpp_current_capital') {
      final birthYear = answers['q_birth_year'];
      if (birthYear != null) {
        final by = birthYear is int ? birthYear : int.tryParse(birthYear.toString()) ?? 0;
        final age = DateTime.now().year - by;
        final yearsContributing = (age - 25).clamp(0, 40);
        return 'À $age ans avec ~$yearsContributing ans de cotisation, '
            'ton avoir LPP devrait être entre CHF ${(yearsContributing * 5000).toString()} '
            'et CHF ${(yearsContributing * 12000).toString()} selon ton salaire et ta caisse.';
      }
    }

    // Life insurance — critical for concubinage
    if (questionId == 'q_has_life_insurance') {
      final civil = answers['q_civil_status'];
      if (civil == 'cohabiting') {
        return 'CRITIQUE en concubinage : ton/ta partenaire n\'a AUCUN droit '
            'à une rente de survivant AVS (LAVS art. 23) ni LPP automatique. '
            'Une assurance décès croisée est le minimum vital.';
      }
      final children = answers['q_children'];
      if (children != null && children != '0' && children != 0) {
        return 'Avec des enfants à charge, une assurance décès protège '
            'leur niveau de vie en cas de disparition d\'un parent. '
            'Capital recommandé : 3-5x le revenu annuel.';
      }
    }

    // Property value context
    if (questionId == 'q_property_value') {
      final canton = answers['q_canton'] as String?;
      if (canton != null) {
        return 'En $canton, la valeur fiscale est souvent 60-80% de la valeur vénale. '
            'Cette valeur entre dans ta fortune imposable (LHID art. 14).';
      }
    }

    // Mortgage balance context
    if (questionId == 'q_mortgage_balance') {
      final propertyValue = answers['q_property_value'];
      if (propertyValue != null) {
        final value = double.tryParse(propertyValue.toString()) ?? 0;
        if (value > 0) {
          final maxDebt = value * 0.80;
          final twoThirds = value * 0.67;
          return 'Valeur du bien : CHF ${value.round()}. '
              'Hypothèque max autorisée : CHF ${maxDebt.round()} (80%). '
              'Amortissement obligatoire jusqu\'aux 2/3 : CHF ${twoThirds.round()} '
              'en 15 ans max (directive ASB).';
        }
      }
    }

    return null;
  }
}
