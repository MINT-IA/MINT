import 'package:mint_mobile/widgets/educational_explanation_widget.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'dart:math' as math;

/// Librairie d'explications pédagogiques pour le rapport financier
class FinancialExplanations {
  /// Explication détaillée du rachat LPP échelonné
  static List<ExplanationSection> lppBuybackExplanation(
    double totalAmount,
    double marginalRate,
  ) {
    final singleYearTax = totalAmount * marginalRate;
    final spreadTax =
        totalAmount * (marginalRate * 0.85); // Taux moyen plus bas
    final saving = singleYearTax - spreadTax;

    return [
      ExplanationSection(
        title: '💡 Comment ça marche ?',
        content:
            'Quand tu rachètes ta LPP, tu DÉDUIS ce montant de ton revenu imposable. Plus ton revenu est élevé, plus tu économises (taux marginal).',
        example:
            'Revenu : CHF 93\'600\nRachat : CHF 50\'000\n→ Nouveau revenu imposable : CHF 43\'600\nTaux marginal : ${(marginalRate * 100).toStringAsFixed(0)}%\n→ Économie : 50\'000 × ${(marginalRate * 100).toStringAsFixed(0)}% = CHF ${(50000 * marginalRate).toStringAsFixed(0)}',
      ),
      ExplanationSection(
        title: '📌 Pourquoi échelonner ?',
        content:
            'Si tu rachètes tout d\'un coup, ton revenu chute trop bas et tu perds l\'avantage du taux marginal élevé.',
        keyPoints: [
          const KeyPoint(
            'Rachat en 1x : Ton revenu tombe trop bas, taux marginal effectif plus faible',
            isPositive: false,
          ),
          const KeyPoint(
            'Rachat échelonné : Tu restes dans ta tranche optimale, taux marginal constant',
          ),
          KeyPoint(
            'Gain supplémentaire : +CHF ${saving.toStringAsFixed(0)} juste en échelonnant !',
          ),
        ],
      ),
      ExplanationSection(
        title: '⚠️ Règle des 3 ans',
        content:
            'Si tu veux retirer ton 2e pilier en CAPITAL à la retraite (et pas en rente), tu dois finir tous tes rachats AU MINIMUM 3 ans avant le retrait.',
        keyPoints: [
          const KeyPoint(
            'Rachat aujourd\'hui → Capital bloqué pendant 3 ans minimum',
            isPositive: false,
          ),
          const KeyPoint(
            'Si tu veux retirer à 65 ans en capital → dernier rachat au plus tard à 62 ans',
          ),
        ],
      ),
      ExplanationSection(
        title: '🎯 Stratégie adaptée',
        content:
            'Pour maximiser l\'économie fiscale, il faut racheter dans les dernières années pré-retraite (quand ton salaire est au plus haut).',
        keyPoints: [
          const KeyPoint(
            'Timing idéal : 3-5 ans avant la retraite',
          ),
          const KeyPoint(
            'Salaire au maximum = taux marginal au maximum = économie maximum',
          ),
          const KeyPoint(
            'Respecter la règle des 3 ans si retrait capital prévu',
          ),
        ],
      ),
    ];
  }

  /// Explication du rendement 3a réel (avec économie fiscale)
  static List<ExplanationSection> pillar3aRealReturnExplanation(
    double annualContribution,
    double taxSavings,
    double investmentReturn,
    int yearsUntilRetirement,
  ) {
    final realCost = annualContribution - taxSavings;

    // Calcul du capital final (Brut) avec intérêts composés
    double targetCapital = 0;
    if (investmentReturn == 0) {
      targetCapital = annualContribution * yearsUntilRetirement;
    } else {
      targetCapital = annualContribution *
          ((math.pow(1 + investmentReturn, yearsUntilRetirement) - 1) /
              investmentReturn);
    }

    // Calcul du rendement équivalent sur le coût net (IRR)
    // On cherche 'r' tel que realCost * ((1+r)^n - 1) / r = targetCapital
    double effectiveYield = _solveForRate(
      targetCapital: targetCapital,
      annualPayment: realCost,
      years: yearsUntilRetirement,
      initialGuess: investmentReturn + 0.05,
    );

    return [
      ExplanationSection(
        title: '🎁 Le secret du 3a : Double rendement',
        content:
            'Le 3a n\'est pas juste un compte d\'épargne. C\'est un LEVIER FISCAL qui te donne un rendement bien supérieur à ce que tu vois.',
      ),
      ExplanationSection(
        title: '💰 Rendement réel (avec fiscal)',
        content:
            'Chaque année, tu ne payes réellement que CHF ${realCost.toStringAsFixed(0)} (après déduction fiscale) pour investir CHF ${annualContribution.toStringAsFixed(0)}.',
        example:
            'Coût réel = ${annualContribution.toStringAsFixed(0)} - ${taxSavings.toStringAsFixed(0)} = CHF ${realCost.toStringAsFixed(0)}\n\n'
            'Rendement investissement : ${(investmentReturn * 100).toStringAsFixed(1)}%\n'
            '→ Rendement réel total : ~${(effectiveYield * 100).toStringAsFixed(1)}% !\n\n'
            'C\'est le taux qu\'il te faudrait sur un placement non-déductible pour arriver au même capital final.',
      ),
      ExplanationSection(
        title: '📈 Indexation et Inflation',
        content:
            'Le plafond du 3a est lié à l\'AVS et est généralement indexé tous les 2 ans. Cela signifie que ta capacité d\'épargne fiscale augmente avec le temps !',
        keyPoints: [
          const KeyPoint(
            'Bonus Indexation : Ton économie fiscale grandit tous les 2 ans',
          ),
          const KeyPoint(
            'Protection Inflation : Investir en actions (via VIAC) protège ton pouvoir d\'achat',
          ),
        ],
      ),
      ExplanationSection(
        title: '✨ Impossible à battre',
        content:
            'Aucun autre placement (sauf immobilier avec EPL) ne te donne un rendement aussi élevé avec si peu de risque.',
        keyPoints: [
          const KeyPoint(
            'Compte épargne : 0.5-1% de rendement',
            isPositive: false,
          ),
          const KeyPoint(
            'Obligations : 2-3% de rendement',
            isPositive: false,
          ),
          KeyPoint(
            '3a VIAC : ${(effectiveYield * 100).toStringAsFixed(1)}% de rendement RÉEL (avec fiscal)',
          ),
        ],
      ),
    ];
  }

  /// Résout l'équation de la valeur future pour trouver le taux (Newton-Raphson simplifié)
  static double _solveForRate({
    required double targetCapital,
    required double annualPayment,
    required int years,
    required double initialGuess,
  }) {
    if (years <= 0) return 0;

    double r = initialGuess;
    for (int i = 0; i < 20; i++) {
      double powR = math.pow(1 + r, years).toDouble();
      double f = annualPayment * (powR - 1) / r - targetCapital;
      double df = annualPayment *
          (years * math.pow(1 + r, years - 1) * r - (powR - 1)) /
          (r * r);

      double nextR = r - f / df;
      if ((nextR - r).abs() < 0.0001) return nextR;
      r = nextR;
    }
    return r;
  }

  /// Explication des intérêts composés
  static List<ExplanationSection> compoundInterestExplanation() {
    return [
      const ExplanationSection(
        title: '📈 La magie des intérêts composés',
        content:
            'Les intérêts composés, c\'est quand tes gains génèrent eux-mêmes des gains. Plus le temps passe, plus l\'effet est puissant.',
        example: 'Année 1 : 7\'258 CHF → +4.5% → 7\'585 CHF\n'
            'Année 2 : 7\'585 + 7\'258 → +4.5% → 15\'542 CHF\n'
            '...\n'
            'Année 16 : 116\'000 CHF → +4.5% → 165\'000 CHF\n\n'
            'Les DERNIÈRES années font +50% du gain total !',
      ),
      const ExplanationSection(
        title: '⏰ Le temps est un allié puissant',
        keyPoints: [
          KeyPoint(
            'Commencer tôt = Effet décuplé',
          ),
          KeyPoint(
            'Chaque année de retard = Perte exponentielle',
            isPositive: false,
          ),
          KeyPoint(
            'Régularité > Montant ponctuel',
          ),
        ],
      ),
    ];
  }

  /// Explication des lacunes AVS (1/44)
  static List<ExplanationSection> avsGapExplanation(
    int contributionYears,
    bool isMarried,
    int? spouseYears,
  ) {
    final gap = 44 - contributionYears;
    final reductionPct = AvsCalculator.reductionPercentageFromGap(gap).toStringAsFixed(1);

    final sections = [
      ExplanationSection(
        title: '📉 L\'impact des lacunes AVS',
        content:
            'Le système AVS suisse est basé sur 44 années de cotisation (de 21 à 65 ans). Chaque année manquante réduit ta rente de façon proportionnelle et définitive.',
        keyPoints: [
          KeyPoint(
            'Rente complète = 44 années de cotisation non-interrompues',
          ),
          KeyPoint(
            '1 année manquante = -1/44e de rente (~2.3% en moins)',
            isPositive: false,
          ),
          if (gap > 0)
            KeyPoint(
              'Ton impact : -$reductionPct% sur ta future rente AVS',
              isPositive: false,
            ),
        ],
      ),
      ExplanationSection(
        title: '🌍 Séjours à l\'étranger',
        content:
            'Partir à l\'étranger sans cotiser au moins le minimum AVS (env. CHF 514/an) crée une lacune irrécupérable après 5 ans.',
        keyPoints: [
          const KeyPoint(
            'Chaque année à l\'étranger sans cotisation = -2.3% de rente AVS à vie',
            isPositive: false,
          ),
          const KeyPoint(
            'Solution : Cotiser à l\'AVS facultative ou compenser par un 3e pilier plus fort',
          ),
        ],
      ),
    ];

    if (isMarried && spouseYears != null) {
      final spouseGap = 44 - spouseYears;
      if (spouseGap > 0) {
        final spouseReduction = AvsCalculator.reductionPercentageFromGap(spouseGap).toStringAsFixed(1);
        sections.add(ExplanationSection(
          title: '💍 Impact sur le couple',
          content:
              'Pour les couples mariés, les rentes sont plafonnées à 150% d\'une rente simple (max CHF 3\'675). Les lacunes de l\'un ou l\'autre réduisent ce plafond.',
          keyPoints: [
            KeyPoint(
              'Lacune conjoint : -$spouseReduction% sur sa part de rente',
              isPositive: false,
            ),
          ],
        ));
      }
    }

    sections.add(ExplanationSection(
      title: '✅ Que faire ?',
      content:
          'Il est possible de racheter les 5 dernières années manquantes si tu étais domicilié en Suisse.',
      keyPoints: [
        const KeyPoint(
          'Commande un extrait de compte individuel (CI) gratuit',
        ),
        const KeyPoint(
          'Vérifie les années avec ta caisse de compensation',
        ),
        const KeyPoint(
          'Rachète les lacunes récentes (< 5 ans) si possible',
        ),
      ],
    ));

    return sections;
  }

  /// Explication des subsides d'assurance maladie (Lien Groupe Mutuel)
  static List<ExplanationSection> healthInsuranceSubsidyExplanation(
    double netIncome,
    String canton,
  ) {
    return [
      ExplanationSection(
        title: '💸 Les Subsides : L\'aide invisible',
        content:
            'En Suisse, si ton revenu est modeste, l\'État paye une partie de tes primes d\'assurance maladie. C\'est ce qu\'on appelle les subsides.',
      ),
      ExplanationSection(
        title: '🎯 Es-tu éligible ?',
        content:
            'Les seuils d\'éligibilité varient énormément d\'un canton à l\'autre. En général, si ton revenu net est inférieur à un certain seuil (ex: CHF 60\'000 pour un célibataire à VD), tu as droit à une réduction.',
        keyPoints: [
          const KeyPoint(
            'Réduction immédiate du coût de la vie',
          ),
          const KeyPoint(
            'Demande souvent non-automatique (il faut la faire !)',
            isPositive: false,
          ),
          KeyPoint(
            'Canton de $canton : Les barèmes sont réactualisés chaque année',
          ),
        ],
      ),
      const ExplanationSection(
        title: '💡 Le Conseil Mint',
        content:
            'Même si tu gagnes "bien" ta vie, des changements (mariage, enfants, baisse de temps de travail) peuvent t\'ouvrir des droits. Ne laisse pas cet argent sur la table.',
      ),
    ];
  }
}
