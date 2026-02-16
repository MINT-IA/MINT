import 'package:flutter/material.dart';
import 'package:mint_mobile/widgets/educational/educational_widgets.dart';

/// Service de mapping entre les questions wizard et les inserts didactiques
/// Implémente le pattern "just-in-time information" (OECD/INFE)
class EducationalInsertService {
  static const String disclaimer =
      'Contenu pédagogique à caractère informatif — outil éducatif '
      'qui ne constitue pas un conseil financier, fiscal ou juridique. '
      'Les informations sont fournies à titre indicatif. '
      'Consultez un·e spécialiste pour une analyse adaptée à ta situation.';

  static const List<String> sources = [
    'LPP (Loi sur la prévoyance professionnelle)',
    'LAVS (Loi sur l\'AVS)',
    'OPP3 (Ordonnance sur le 3e pilier)',
    'LIFD (Loi sur l\'impôt fédéral direct)',
    'LAMal (Loi sur l\'assurance-maladie)',
    'LSFin art. 3 (Définition du conseil en placement)',
    'CC art. 159-251 (Régime matrimonial)',
    'FINMA circ. 2017/7 (Normes minimales hypothécaires)',
  ];
  /// Questions qui ont un insert didactique associé
  static const Set<String> questionsWithInserts = {
    // Inserts existants (S16-S19)
    'q_financial_stress_check',
    'q_has_pension_fund',
    'q_has_3a',
    'q_3a_annual_amount',
    'q_mortgage_type',
    'q_has_consumer_credit',
    'q_has_leasing',
    'q_emergency_fund',
    // Nouveaux inserts S27 — Niveau 1
    'q_civil_status',
    'q_employment_status',
    'q_housing_status',
    'q_canton',
    // Nouveaux inserts S27 — Niveau 2
    'q_lpp_buyback_available',
    'q_3a_accounts_count',
    'q_has_investments',
    'q_real_estate_project',
  };

  /// Vérifie si une question a un insert didactique
  static bool hasInsert(String questionId) {
    return questionsWithInserts.contains(questionId);
  }

  /// Retourne le widget d'insert pour une question donnée
  /// Returns null si aucun insert n'est disponible
  static Widget? getInsertWidget({
    required String questionId,
    required Map<String, dynamic> answers,
    VoidCallback? onLearnMore,
    Function(dynamic)? onAnswer,
  }) {
    switch (questionId) {
      case 'q_financial_stress_check':
        return StressCheckInsertWidget(
          onLearnMore: onLearnMore,
          onAction: (route) => debugPrint('Navigate to $route'),
        );

      case 'q_has_pension_fund':
        return LppPivotInsertWidget(
          hasPensionFund: answers['q_has_pension_fund'] == 'yes',
          onLearnMore: onLearnMore,
          onChanged: (val) => onAnswer?.call(val ? 'yes' : 'no'),
        );

      case 'q_has_3a':
      case 'q_3a_annual_amount':
        // 1. Income Resolution
        double monthlyIncome = 6000;

        final periodIncome = _parseDouble(answers['q_net_income_period_chf']);
        final monthlyDirect =
            _parseDouble(answers['q_income_net_monthly']); // Fallback key

        if (periodIncome != null) {
          final payFreq = answers['q_pay_frequency'] as String?;
          if (payFreq == 'weekly') {
            monthlyIncome = periodIncome * 4.33;
          } else if (payFreq == 'biweekly') {
            monthlyIncome = periodIncome * 2.17;
          } else {
            monthlyIncome = periodIncome;
          }
        } else if (monthlyDirect != null) {
          monthlyIncome = monthlyDirect;
        }

        // 2. Pension Fund Logic (Crucial Fix for Salaried employees)
        // If employee -> Default to Yes (Small 3a limit)
        // If self employed -> Default to No (Large 3a limit), unless explicit Yes
        final status = answers['q_employment_status'] as String?;
        final explicitLpp = answers['q_has_pension_fund'] == 'yes';

        bool hasPensionFund = explicitLpp;
        if (status == 'employee') {
          hasPensionFund =
              true; // Salaried employees almost always have LPP implies 7k limit
        }

        return TaxSavingsInsertWidget(
          initialIncome: monthlyIncome,
          hasPensionFund: hasPensionFund,
          onLearnMore: onLearnMore,
        );

      case 'q_mortgage_type':
        return MortgageComparisonInsertWidget(
          currentType: answers['q_mortgage_type'] as String?,
          onLearnMore: onLearnMore,
        );

      case 'q_has_consumer_credit':
        return CreditCostInsertWidget(
          creditAmount: _parseDouble(answers['q_credit_amount']),
          interestRate: _parseDouble(answers['q_credit_rate']),
          durationMonths: _parseInt(answers['q_credit_duration']),
          onLearnMore: onLearnMore,
        );

      case 'q_has_leasing':
        return LeasingCostInsertWidget(
          monthlyPayment: _parseDouble(answers['q_leasing_monthly']),
          remainingMonths: _parseInt(answers['q_leasing_remaining_months']),
          onLearnMore: onLearnMore,
        );

      case 'q_emergency_fund':
        return EmergencyFundInsertWidget(
          monthlyExpenses: _parseDouble(answers['q_expenses_fixed_monthly']),
          currentSavings: _parseDouble(answers['q_cash_total']),
          onLearnMore: onLearnMore,
        );

      // ── Nouveaux inserts S27 — Niveau 1 ──

      case 'q_civil_status':
        return GenericInfoInsertWidget(
          title: 'Ton état civil, ses impacts financiers',
          subtitle: 'Impôts, succession, prévoyance',
          chiffreChoc:
              'Un couple marié peut économiser jusqu\'à 6\'000 CHF/an '
              'd\'impôts par rapport à deux concubins dans certains cantons '
              '— mais dans d\'autres c\'est l\'inverse (pénalité du mariage).',
          learningGoals: const [
            'Le mariage implique un régime matrimonial (participation aux acquêts par défaut, CC art. 181).',
            'Le concubinage n\'offre aucune protection légale automatique (pas de part réservataire, pas de droit aux acquêts).',
            'Le divorce entraîne un partage du 2e pilier imposé par la loi (LPP art. 22).',
            'Le mariage entraîne une imposition commune (LIFD art. 9 al. 1) — avantage ou pénalité selon les revenus.',
            'Le PACS (partenariat enregistré) donne les mêmes droits fiscaux et successoraux que le mariage (LPart art. 1).',
          ],
          disclaimer:
              'Information à caractère éducatif. Chaque situation familiale est unique. '
              'Consulte un\u00b7e spécialiste en droit de la famille pour un conseil personnalisé.',
          sources: const [
            'CC art. 159-251 (Régime matrimonial)',
            'CC art. 470-471 (Réserves héréditaires, révision 2023)',
            'LPP art. 22 (Partage LPP en cas de divorce)',
            'LIFD art. 9 al. 1 (Imposition commune des époux)',
            'LPart art. 1ss (Partenariat enregistré)',
          ],
          actionLabel: 'Simuler l\'impact financier de mon état civil',
          actionRoute: '/mariage',
          onLearnMore: onLearnMore,
        );

      case 'q_employment_status':
        return GenericInfoInsertWidget(
          title: 'Ton statut professionnel, tes droits',
          subtitle: 'Prévoyance, 3a, couvertures sociales',
          chiffreChoc:
              'Un indépendant sans LPP volontaire peut cotiser jusqu\'à '
              '36\'288 CHF/an au 3a — soit 5x plus qu\'un salarié (7\'258 CHF). '
              'Mais il perd l\'assurance invalidité LPP.',
          learningGoals: const [
            'Les 3 régimes : salarié (employé), indépendant, sans activité lucrative.',
            'Le salarié bénéficie automatiquement de l\'AVS (LAVS art. 3), du LPP (LPP art. 2) et de l\'assurance accident (LAA art. 1a).',
            'L\'indépendant doit tout organiser lui-même : AVS, LPP volontaire, IJM, assurance accident.',
            'Le chômage donne droit à l\'AC (LACI art. 8) et maintient la couverture LPP pendant 2 ans max.',
            'Le sans-activité lucrative cotise quand même à l\'AVS (LAVS art. 10).',
          ],
          disclaimer:
              'Information à caractère éducatif. Le régime de prévoyance '
              'dépend de ta situation spécifique. Consulte ta caisse de compensation ou un\u00b7e spécialiste.',
          sources: const [
            'LAVS art. 3, 10 (Cotisations AVS)',
            'LPP art. 2, 4, 7 (Assujettissement LPP)',
            'LAA art. 1a (Assurance accident)',
            'LACI art. 8 (Droit aux indemnités de chômage)',
            'OPP3 art. 7 (3a indépendant sans LPP)',
          ],
          actionLabel: 'Explorer les outils adaptés à mon statut',
          actionRoute: '/tools',
          onLearnMore: onLearnMore,
        );

      case 'q_housing_status':
        return GenericInfoInsertWidget(
          title: 'Locataire ou propriétaire ?',
          subtitle: 'Fiscalité, EPL et capacité d\'emprunt',
          chiffreChoc:
              'En Suisse, seuls 36% des ménages sont propriétaires — '
              'le taux le plus bas d\'Europe. Pourtant, un propriétaire paie '
              'en moyenne 15-25% de moins par mois qu\'un locataire équivalent '
              'après 15 ans d\'amortissement.',
          learningGoals: const [
            'La propriété en Suisse implique un apport minimum de 20% (max 10% du 2e pilier, FINMA circ. 2017/7).',
            'Le propriétaire paie l\'impôt sur la valeur locative (LIFD art. 21 al. 1 let. b) mais peut déduire les intérêts hypothécaires et les frais d\'entretien.',
            'Le mécanisme de l\'EPL : retrait LPP + 3a pour financer l\'apport (LPP art. 30c).',
            'Le calcul de la capacité d\'emprunt (Tragbarkeit) : charges max 1/3 du revenu brut, au taux théorique de 5%.',
            'Le locataire n\'a aucune déduction fiscale liée au logement mais conserve sa flexibilité et sa liquidité.',
          ],
          disclaimer:
              'Information à caractère éducatif. L\'achat immobilier dépend de nombreux '
              'facteurs personnels. Consulte un\u00b7e spécialiste en financement immobilier.',
          sources: const [
            'FINMA circ. 2017/7 (Normes minimales hypothécaires)',
            'LIFD art. 21 al. 1 let. b (Valeur locative)',
            'LIFD art. 32 (Déduction des frais d\'entretien)',
            'LPP art. 30c (EPL)',
            'OPP2 art. 30d-30g (Modalités EPL)',
          ],
          actionLabel: 'Simuler ma capacité d\'emprunt',
          actionRoute: '/mortgage/affordability',
          onLearnMore: onLearnMore,
        );

      case 'q_canton':
        return GenericInfoInsertWidget(
          title: 'Ton canton, ton impôt',
          subtitle: 'Le 1er levier fiscal en Suisse',
          chiffreChoc:
              'Pour un revenu de 100\'000 CHF, l\'impôt varie de ~8% à Zoug '
              'à ~30% à Genève — soit une différence de plus de 22\'000 CHF par an. '
              'Ton canton est le premier levier fiscal en Suisse.',
          learningGoals: const [
            'La Suisse a 3 niveaux d\'imposition : fédéral (fixe), cantonal et communal (variables).',
            'Le taux effectif d\'imposition varie énormément d\'un canton à l\'autre (et même d\'une commune à l\'autre).',
            'Les déductions (3a, LPP, frais médicaux, enfants) varient aussi par canton.',
            'La fortune est imposée annuellement au niveau cantonal (pas au niveau fédéral).',
            'Les 26 cantons ont leurs propres barèmes, allocations familiales et primes LAMal.',
          ],
          disclaimer:
              'Information à caractère éducatif. Les taux d\'imposition dépendent de la commune, '
              'du revenu et de la situation familiale. Consulte l\'administration fiscale de ton canton pour un calcul précis.',
          sources: const [
            'LIFD (Impôt fédéral direct)',
            'LHID (Loi sur l\'harmonisation des impôts directs)',
            'Lois cantonales sur les impôts directs (26 lois)',
            'OFS Statistique fiscale de la Suisse',
          ],
          actionLabel: 'Comparer la fiscalité des 26 cantons',
          actionRoute: '/fiscal',
          onLearnMore: onLearnMore,
        );

      // ── Nouveaux inserts S27 — Niveau 2 ──

      case 'q_lpp_buyback_available':
        return GenericInfoInsertWidget(
          title: 'Rachat LPP : ton levier fiscal',
          subtitle: 'Rendement immédiat de 25 à 40%',
          chiffreChoc:
              'Un rachat LPP de 20\'000 CHF peut te faire économiser entre '
              '5\'000 et 8\'000 CHF d\'impôts l\'année même — c\'est un rendement '
              'fiscal immédiat de 25 à 40%.',
          learningGoals: const [
            'Le rachat LPP est déductible à 100% du revenu imposable (LPP art. 79b).',
            'Le montant maximum de rachat figure sur le certificat de prévoyance (demande à ta caisse de pension).',
            'La stratégie d\'échelonnement : répartir les rachats sur 3-5 ans pour maximiser l\'économie grâce à la progressivité.',
            'Le blocage EPL : après un rachat, tu ne peux pas retirer de l\'EPL pendant 3 ans (LPP art. 79b al. 3).',
            'Le rachat augmente aussi ta rente future (ou ton capital de retrait).',
          ],
          disclaimer:
              'Information à caractère éducatif. Le potentiel de rachat dépend de ta situation '
              'individuelle. Consulte ton certificat de prévoyance ou un\u00b7e spécialiste LPP.',
          sources: const [
            'LPP art. 79b (Rachat de prestations)',
            'LPP art. 79b al. 3 (Blocage EPL 3 ans)',
            'LIFD art. 33 al. 1 let. d (Déduction des cotisations LPP)',
            'OPP2 art. 60a (Calcul du potentiel de rachat)',
          ],
          actionLabel: 'Simuler l\'économie fiscale de mon rachat',
          actionRoute: '/lpp-deep/rachat',
          onLearnMore: onLearnMore,
        );

      case 'q_3a_accounts_count':
        return GenericInfoInsertWidget(
          title: 'Nombre de comptes 3a : la stratégie',
          subtitle: 'Échelonner pour payer moins d\'impôts',
          chiffreChoc:
              'Avec 5 comptes 3a retirés sur 5 ans au lieu d\'un seul, '
              'tu peux économiser entre 8\'000 et 25\'000 CHF d\'impôts sur '
              'le retrait — car chaque retrait est imposé séparément et à un taux plus bas.',
          learningGoals: const [
            'Le retrait du 3a est imposé comme un revenu (taux progressif, LIFD art. 38).',
            'Les retraits de la même année sont additionnés pour le calcul du taux (impôt progressif).',
            'La stratégie d\'échelonnement : ouvrir 4-5 comptes dès le départ et les retirer sur 4-5 années différentes (à partir de 59/60 ans).',
            'Les retraits 3a et LPP en capital de la même année se cumulent pour l\'imposition.',
            'L\'âge de retrait anticipé est 59 ans (femmes) / 60 ans (hommes) sans condition (OPP3 art. 3 al. 1).',
          ],
          disclaimer:
              'Information à caractère éducatif. L\'économie d\'impôt dépend du canton '
              'et du montant total. Consulte un\u00b7e spécialiste fiscal\u00b7e pour optimiser ta stratégie.',
          sources: const [
            'OPP3 art. 3 (Retrait du 3a)',
            'LIFD art. 38 (Imposition séparée des prestations en capital)',
            'Lois cantonales sur l\'imposition des prestations en capital',
            'OPP3 art. 2 (Plafond annuel 3a)',
          ],
          actionLabel: 'Simuler l\'économie avec l\'échelonnement 3a',
          actionRoute: '/3a-deep/staggered-withdrawal',
          onLearnMore: onLearnMore,
        );

      case 'q_has_investments':
        return GenericInfoInsertWidget(
          title: 'Placements : le régime fiscal suisse',
          subtitle: 'Gains en capital, dividendes, fortune',
          chiffreChoc:
              'En Suisse, les gains en capital privés sont exonérés d\'impôt '
              '(LIFD art. 16 al. 3) — mais les dividendes et intérêts sont '
              'imposés à 100%. Placer 100\'000 CHF en valeurs mobilières plutôt '
              'que sur un compte d\'épargne peut générer 3\'000 à 5\'000 CHF/an '
              'de rendement supplémentaire.',
          learningGoals: const [
            'Les gains en capital privés ne sont PAS imposés en Suisse (LIFD art. 16 al. 3) — un avantage unique.',
            'Les dividendes et intérêts sont imposables comme revenu ordinaire (LIFD art. 20).',
            'La fortune (patrimoine net) est imposée chaque année (impôt cantonal sur la fortune).',
            'Risque vs rendement : historiquement, les valeurs mobilières suisses (SPI) ont rendu ~7%/an sur 20 ans, mais avec des baisses temporaires possibles.',
            'MINT ne donne pas de conseil en investissement (LSFin art. 3) — seuls des intermédiaires autorisés FINMA peuvent le faire.',
          ],
          disclaimer:
              'MINT est un outil éducatif et ne constitue pas un conseil en investissement '
              'au sens de la LSFin. Les rendements passés ne présagent pas des rendements futurs. '
              'Consulte un\u00b7e spécialiste autorisé\u00b7e FINMA.',
          sources: const [
            'LIFD art. 16 al. 3 (Exonération gains en capital privés)',
            'LIFD art. 20 (Imposition des rendements de fortune)',
            'LSFin art. 3 (Conseil en investissement)',
            'FINMA circ. 2018/3 (Règles de conduite)',
          ],
          actionLabel: 'Découvrir les bases de la diversification',
          actionRoute: '/education/hub',
          onLearnMore: onLearnMore,
        );

      case 'q_real_estate_project':
        return GenericInfoInsertWidget(
          title: 'Projet immobilier : par où commencer',
          subtitle: 'Apport, capacité d\'emprunt, sources',
          chiffreChoc:
              'Pour un bien à 800\'000 CHF, il te faut 160\'000 CHF d\'apport '
              'personnel — dont maximum 80\'000 CHF de ton 2e pilier. '
              'Tes charges mensuelles théoriques seront d\'environ 4\'670 CHF, '
              'soit un revenu brut minimum de 14\'000 CHF/mois.',
          learningGoals: const [
            'La règle des 20% d\'apport : minimum 10% en cash ou 3a, max 10% du 2e pilier (FINMA circ. 2017/7).',
            'Calculer la capacité d\'emprunt : charges (5% intérêt théorique + 1% amortissement + 1% frais) max 1/3 du revenu brut.',
            'Les 3 sources d\'apport : épargne, 3a (retrait intégral possible), LPP (EPL, max 50% ou 50\'000 CHF après 50 ans, LPP art. 30c).',
            'La différence entre hypothèque 1er rang (max 65% de la valeur) et 2e rang (à amortir en 15 ans).',
            'L\'achat déclenche des frais uniques : notaire (~1-3%), droits de mutation (selon canton), frais bancaires.',
          ],
          disclaimer:
              'Information à caractère éducatif. Les conditions d\'emprunt dépendent de ta '
              'situation et de l\'établissement financier. Consulte un\u00b7e spécialiste en financement immobilier.',
          sources: const [
            'FINMA circ. 2017/7 (Normes minimales hypothécaires)',
            'ASB Directives relatives aux exigences minimales pour les financements hypothécaires',
            'LPP art. 30c (EPL — encouragement à la propriété)',
            'OPP2 art. 30d-30g (Modalités EPL)',
            'LIFD art. 21 al. 1 let. b (Valeur locative)',
          ],
          actionLabel: 'Simuler ma capacité d\'emprunt',
          actionRoute: '/mortgage/affordability',
          onLearnMore: onLearnMore,
        );

      default:
        return null;
    }
  }

  /// Retourne le titre du modal "En savoir plus"
  static String? getLearnMoreTitle(String questionId) {
    switch (questionId) {
      case 'q_financial_stress_check':
        return 'Ton stress financier, en clair';
      case 'q_has_pension_fund':
        return 'Comprendre le 2e pilier (LPP)';
      case 'q_has_3a':
      case 'q_3a_annual_amount':
        return 'Le 3e pilier en détail';
      case 'q_mortgage_type':
        return 'Types d\'hypothèques en Suisse';
      case 'q_has_consumer_credit':
        return 'Le crédit à la consommation';
      case 'q_has_leasing':
        return 'Leasing vs achat';
      case 'q_emergency_fund':
        return 'Pourquoi un fonds d\'urgence ?';
      // Nouveaux inserts S27 — Niveau 1
      case 'q_civil_status':
        return 'État civil et finances en Suisse';
      case 'q_employment_status':
        return 'Statut professionnel et prévoyance';
      case 'q_housing_status':
        return 'Locataire ou propriétaire ?';
      case 'q_canton':
        return 'Fiscalité cantonale en Suisse';
      // Nouveaux inserts S27 — Niveau 2
      case 'q_lpp_buyback_available':
        return 'Le rachat LPP, comment ça marche ?';
      case 'q_3a_accounts_count':
        return 'Stratégie multi-comptes 3a';
      case 'q_has_investments':
        return 'Placements et fiscalité suisse';
      case 'q_real_estate_project':
        return 'Financer un achat immobilier';
      default:
        return null;
    }
  }

  /// Parse helper pour double
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Parse helper pour int
  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }
}
