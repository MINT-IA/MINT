// Données de référence cantonales pour MINT (MVP)
// Sources: statistiques AFC 2024/2025, chef-lieu, célibataire, 100k CHF imposable
// averageMarginalRate = taux MARGINAL réel (dernier franc gagné, cantonal+communal+IFD)
// Utilisé pour évaluer l'opportunité de rachat LPP et déductions fiscales.
// Note: le taux effectif (impôt total / revenu) est calculé via TaxEstimatorService.

enum TaxPressure { low, medium, high, veryHigh }

class CantonProfile {
  final String code;
  final String name;
  final TaxPressure taxPressureIncome; // Pression fiscale Revenu
  final TaxPressure taxPressureWealth; // Pression fiscale Fortune
  final double
      averageMarginalRate; // Taux marginal réel (cantonal+communal+IFD) sur 100k
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
    // Taux marginaux AFC 2024: ZG ~22%, SZ ~24%
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
    // ZH ~30%, GE ~36% (LIPP très progressif), BS ~32%
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
      averageMarginalRate: 0.36, // LIPP très progressif
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
    // VD ~35%, VS ~27%, NE ~33%, FR ~31%, JU ~34%
    'VD': CantonProfile(
      code: 'VD',
      name: 'Vaud',
      taxPressureIncome: TaxPressure.veryHigh,
      taxPressureWealth: TaxPressure.veryHigh,
      averageMarginalRate: 0.35,
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
      averageMarginalRate: 0.27,
      specificAdvantages: ['Déductions trajet (montagne)', 'Immo bon marché'],
    ),
    'NE': CantonProfile(
      code: 'NE',
      name: 'Neuchâtel',
      taxPressureIncome: TaxPressure.high,
      taxPressureWealth: TaxPressure.high,
      averageMarginalRate: 0.33,
      specificAdvantages: ['Harmonisation récente'],
    ),
    'FR': CantonProfile(
      code: 'FR',
      name: 'Fribourg',
      taxPressureIncome: TaxPressure.high,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.31,
    ),
    'JU': CantonProfile(
      code: 'JU',
      name: 'Jura',
      taxPressureIncome: TaxPressure.veryHigh,
      taxPressureWealth: TaxPressure.high,
      averageMarginalRate: 0.34,
    ),

    // === ESPACE MITTELLAND (BE) ===
    // BE ~33%
    'BE': CantonProfile(
      code: 'BE',
      name: 'Berne',
      taxPressureIncome: TaxPressure.high,
      taxPressureWealth: TaxPressure.high,
      averageMarginalRate: 0.33,
      specificAdvantages: ['Déductions garde enfants'],
    ),

    // === SUISSE CENTRALE (LU, OW, NW, UR) ===
    // LU ~26%, OW ~23%, NW ~22%, UR ~24%
    'LU': CantonProfile(
      code: 'LU',
      name: 'Lucerne',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.low,
      averageMarginalRate: 0.26,
      specificAdvantages: ['Forfaits fiscaux attractifs'],
    ),
    'OW': CantonProfile(
      code: 'OW',
      name: 'Obwald',
      taxPressureIncome: TaxPressure.low,
      taxPressureWealth: TaxPressure.low,
      averageMarginalRate: 0.23,
    ),
    'NW': CantonProfile(
      code: 'NW',
      name: 'Nidwald',
      taxPressureIncome: TaxPressure.low,
      taxPressureWealth: TaxPressure.low,
      averageMarginalRate: 0.22,
    ),
    'UR': CantonProfile(
      code: 'UR',
      name: 'Uri',
      taxPressureIncome: TaxPressure.low,
      taxPressureWealth: TaxPressure.low,
      averageMarginalRate: 0.24,
    ),

    // === APPENZELL + SUISSE ORIENTALE (AI, AR, SG, GL, GR, TG, SH) ===
    // AI ~23%, AR ~28%, SG ~29%, GL ~27%, GR ~28%, TG ~27%, SH ~28%
    'AI': CantonProfile(
      code: 'AI',
      name: 'Appenzell Rh.-Int.',
      taxPressureIncome: TaxPressure.low,
      taxPressureWealth: TaxPressure.low,
      averageMarginalRate: 0.23,
    ),
    'AR': CantonProfile(
      code: 'AR',
      name: 'Appenzell Rh.-Ext.',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.28,
    ),
    'SG': CantonProfile(
      code: 'SG',
      name: 'Saint-Gall',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.29,
    ),
    'GL': CantonProfile(
      code: 'GL',
      name: 'Glaris',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.27,
    ),
    'GR': CantonProfile(
      code: 'GR',
      name: 'Grisons',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.28,
    ),
    'TG': CantonProfile(
      code: 'TG',
      name: 'Thurgovie',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.27,
    ),
    'SH': CantonProfile(
      code: 'SH',
      name: 'Schaffhouse',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.28,
    ),

    // === SUISSE DU NORD-OUEST + MITTELLAND (AG, BL, SO) ===
    // AG ~29%, BL ~31%, SO ~30%
    'AG': CantonProfile(
      code: 'AG',
      name: 'Argovie',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.29,
    ),
    'BL': CantonProfile(
      code: 'BL',
      name: 'Bâle-Campagne',
      taxPressureIncome: TaxPressure.high,
      taxPressureWealth: TaxPressure.medium,
      averageMarginalRate: 0.31,
    ),
    'SO': CantonProfile(
      code: 'SO',
      name: 'Soleure',
      taxPressureIncome: TaxPressure.medium,
      taxPressureWealth: TaxPressure.high,
      averageMarginalRate: 0.30,
    ),

    // === TESSIN (TI) ===
    // TI ~31%
    'TI': CantonProfile(
      code: 'TI',
      name: 'Tessin',
      taxPressureIncome: TaxPressure.high,
      taxPressureWealth: TaxPressure.high,
      averageMarginalRate: 0.31,
      specificAdvantages: ['Impôt forfait pour étrangers'],
    ),
  };

  /// Retourne le profil cantonal ou un profil moyen par défaut
  static CantonProfile getByCode(String? code) {
    if (code == null) return _statsSuisseAverage;
    return cantons[code.toUpperCase()] ?? _statsSuisseAverage;
  }

  /// Profil moyen "Suisse" pour fallback (taux marginal pondéré population)
  static const CantonProfile _statsSuisseAverage = CantonProfile(
    code: 'CH',
    name: 'Moyenne Suisse',
    taxPressureIncome: TaxPressure.medium,
    taxPressureWealth: TaxPressure.medium,
    averageMarginalRate: 0.30,
  );

  /// Calcule un score d'opportunité de rachat LPP (0.0 à 1.0)
  /// Basé sur le levier fiscal (taux marginal) du canton
  static double calculateLppBuybackOpportunityAuth(String cantonCode) {
    final profile = getByCode(cantonCode);
    // Plus le taux marginal est haut, plus le rachat est "rentable" immédiatement
    if (profile.averageMarginalRate > 0.33) return 1.0; // GE, VD, JU
    if (profile.averageMarginalRate > 0.27) return 0.8; // ZH, BS, FR, NE, BE, VS
    return 0.5; // ZG, SZ (moins intéressant fiscalement)
  }
}
