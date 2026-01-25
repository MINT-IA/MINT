import 'package:mint_mobile/widgets/educational_explanation_widget.dart';

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
        title: '🎯 Stratégie optimale',
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
  ) {
    final realCost = annualContribution - taxSavings;
    final realReturn = ((annualContribution * investmentReturn) / realCost) - 1;

    return [
      ExplanationSection(
        title: '🎁 Le secret du 3a : Double rendement',
        content:
            'Le 3a n\'est pas juste un compte d\'épargne. C\'est un LEVIER FISCAL qui te donne un rendement bien supérieur à ce que tu vois.',
      ),
      ExplanationSection(
        title: '💰 Rendement réel (avec fiscal)',
        content:
            'Chaque année, tu verses CHF ${annualContribution.toStringAsFixed(0)} et tu économises CHF ${taxSavings.toStringAsFixed(0)} d\'impôts.',
        example:
            'Coût réel = ${annualContribution.toStringAsFixed(0)} - ${taxSavings.toStringAsFixed(0)} = CHF ${realCost.toStringAsFixed(0)}\n\n'
            'Rendement investissement : ${(investmentReturn * 100).toStringAsFixed(1)}%\n'
            'Rendement fiscal : ${((taxSavings / annualContribution) * 100).toStringAsFixed(0)}%\n'
            '→ Rendement réel total : ~${(realReturn * 100).toStringAsFixed(0)}% !',
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
            '3a VIAC : ${(realReturn * 100).toStringAsFixed(0)}% de rendement RÉEL (avec fiscal)',
          ),
        ],
      ),
    ];
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
        title: '⏰ Le temps est ton meilleur allié',
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
}
