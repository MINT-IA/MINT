// Données de référence cantonales pour MINT (MVP)
// Sources approximatives basées sur statistiques AFC 2024/2025
// Permet de donner un "Forecast" réaliste sans connecter une API fiscale lourde.

enum TaxPressure { low, medium, high, veryHigh }

class CantonProfile {
  final String code;
  final String name;
  final TaxPressure taxPressureIncome; // Pression fiscale Revenu
  final TaxPressure taxPressureWealth; // Pression fiscale Fortune
  final double
      averageMarginalRate; // Estimation taux marginal revenu moyen (100k)
  final double divorceComplexity; // 1.0 = Standard, 1.5 = Complexe (simulateur)
  final List<String> specificAdvantages;

  const CantonProfile({
    required this.code,
    required this.name,
    required this.taxPressureIncome,
    required this.taxPressureWealth,
    required this.averageMarginalRate,
    this.divorceComplexity = 1.0,
    this.specificAdvantages = const [],
  });
}

class CantonalDataService {
  static const Map<String, CantonProfile> cantons = {
    // === LOW TAX HAVENS (ZG, SZ) ===
    'ZG': CantonProfile(
      code: 'ZG',
      name: 'Zoug',
      taxPressureIncome: TaxPressure.low,
      taxPressureWealth: TaxPressure.low,
      averageMarginalRate: 0.22,
      specificAdvantages: [
        'Fiscalité crypto friendly',
        'Déductions frais élevées'
      ],
    ),
    'SZ': CantonProfile(
      code: 'SZ',
      name: 'Schwyz',
      taxPressureIncome: TaxPressure.low,
      taxPressureWealth: TaxPressure.low,
      averageMarginalRate: 0.24,
    ),

    // === METROPOLES (ZH, GE, BS) ===
    'ZH': CantonProfile(
      code: 'ZH',
      name: 'Zurich',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.30,
      specificAdvantages: ['Marché immo très liquide'],
    ),
    'GE': CantonProfile(
      code: 'GE',
      name: 'Genève',
      taxPressureIncome: TaxPressure.veryHigh,
      taxPressureWealth: TaxPressure.veryHigh,
      averageMarginalRate: 0.42, // Très progressif
      specificAdvantages: [
        'Subsides assurance maladie élevés',
        'Déductions frais garde'
      ],
    ),
    'BS': CantonProfile(
      code: 'BS',
      name: 'Bâle-Ville',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.high,
      averageMarginalRate: 0.32,
    ),

    // === ROMANDIE (VD, VS, NE, FR, JU) ===
    'VD': CantonProfile(
      code: 'VD',
      name: 'Vaud',
      taxPressureIncome: TaxPressure.veryHigh,
      taxPressureWealth: TaxPressure.veryHigh,
      averageMarginalRate: 0.41,
      divorceComplexity: 1.2, // Jurisprudence parfois stricte
      specificAdvantages: [
        'Splitting familial avantageux (quotient)',
        'Subsides aggressifs'
      ],
    ),
    'VS': CantonProfile(
      code: 'VS',
      name: 'Valais',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.34,
      specificAdvantages: ['Déductions trajet (montagne)', 'Immo bon marché'],
    ),
    'NE': CantonProfile(
      code: 'NE',
      name: 'Neuchâtel',
      taxPressureIncome: TaxPressure.high,
      taxPressureWealth: TaxPressure.high,
      averageMarginalRate: 0.39,
      specificAdvantages: ['Harmonisation récente'],
    ),
    'FR': CantonProfile(
      code: 'FR',
      name: 'Fribourg',
      taxPressureIncome: TaxPressure.high,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.37,
    ),
    'JU': CantonProfile(
      code: 'JU',
      name: 'Jura',
      taxPressureIncome: TaxPressure.veryHigh,
      taxPressureWealth: TaxPressure.high,
      averageMarginalRate: 0.40,
    ),

    // === ESPACE MITTELLAND (BE) ===
    'BE': CantonProfile(
      code: 'BE',
      name: 'Berne',
      taxPressureIncome: TaxPressure.high,
      taxPressureWealth: TaxPressure.high,
      averageMarginalRate: 0.38,
      specificAdvantages: ['Déductions garde enfants'],
    ),
  };

  /// Retourne le profil cantonal ou un profil moyen par défaut
  static CantonProfile getByCode(String? code) {
    if (code == null) return _statsSuisseAverage;
    return cantons[code.toUpperCase()] ?? _statsSuisseAverage;
  }

  /// Profil moyen "Suisse" pour fallback
  static const CantonProfile _statsSuisseAverage = CantonProfile(
    code: 'CH',
    name: 'Moyenne Suisse',
    taxPressureIncome: TaxPressure.medium,
    taxPressureWealth: TaxPressure.medium,
    averageMarginalRate: 0.33,
  );

  /// Calcule un score d'opportunité de rachat LPP (0.0 à 1.0)
  /// Basé sur le levier fiscal du canton
  static double calculateLppBuybackOpportunityAuth(String cantonCode) {
    final profile = getByCode(cantonCode);
    // Plus le taux marginal est haut, plus le Rachat est "rentable" immédiatement
    if (profile.averageMarginalRate > 0.38) return 1.0; // GE, VD, JU
    if (profile.averageMarginalRate > 0.30) return 0.8; // BE, FR, VS, NE
    return 0.5; // ZG, SZ (Moins intéressant fiscalement, mais toujours bon pour rendement sûr)
  }
}
