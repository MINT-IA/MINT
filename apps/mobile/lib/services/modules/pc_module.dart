class PCEligibilityResult {
  final bool isPotentiallyEligible;
  final String actionLabel;
  final String disclaimer;

  PCEligibilityResult({
    required this.isPotentiallyEligible,
    required this.actionLabel,
    required this.disclaimer,
  });
}

class PCModule {
  /// Vérification simple d'éligibilité PC (Resource Bridge).
  /// Seuils approximatifs (National/Moyen).
  static PCEligibilityResult checkEligibility({
    required double netIncome,
    required double netWealth,
    required double rent,
    required String canton,
  }) {
    // Seuils indicatifs (Hypothèse pour personne seule)
    // Revenu déterminant = Revenu + (Fortune - Franchise)/Consommation_Fortune.
    // Dépenses reconnues = Besoins vitaux (~20k) + Loyer (max ~15k).

    // Simplification MVP pédagogique :
    // Si revenus faible < (Besoins Vitaux + Loyer) => Potentiellement éligible.

    double vitalNeeds = 20100; // ~Tarif 2024 personne seule
    double maxRent = 16800; // ~1400/mois (souvent moins selon canton/zone)
    double effectiveRent = (rent * 12) > maxRent ? maxRent : (rent * 12);

    double expenses = vitalNeeds + effectiveRent + 4600; // + Prime AMAL approx

    // Prise en compte fortune (très grossier)
    // Franchise ~30k. 1/15e du reste consommé.
    double wealthIncome = 0;
    if (netWealth > 30000) {
      wealthIncome = (netWealth - 30000) / 10; // Disons 1/10e pour être large
    }

    double totalResources = (netIncome * 12) + wealthIncome;

    bool isEligible = totalResources < expenses;

    if (isEligible) {
      return PCEligibilityResult(
        isPotentiallyEligible: true,
        actionLabel:
            "Contacter l'office PC du canton $canton pour une demande formelle.",
        disclaimer:
            "Ceci n'est pas une décision officielle. Seul l'office des Prestations Complémentaires de votre canton peut déterminer votre droit final.",
      );
    } else {
      return PCEligibilityResult(
        isPotentiallyEligible: false,
        actionLabel: "",
        disclaimer: "",
      );
    }
  }
}
