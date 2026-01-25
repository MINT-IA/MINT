/// Multiplicateurs fiscaux moyens par canton (Canton + Commune)
/// Basé sur les chefs-lieux et moyennes 2024
/// Format: X.XX (où 1.00 = 100% de l'impôt de base cantonal)
///
/// Note: C'est une approximation. L'idéal est de charger le taux communal exact par NPA.
class AverageTaxMultipliers {
  static const Map<String, double> multiplierByCanton = {
    // Zurich (ZH City ~119% + 119% = 238%)
    'ZH': 2.38,
    // Bern (Bern ~306% total)
    'BE': 3.06,
    // Lucerne (LU City ~1.75 + 1.60 ? Low tax)
    'LU': 1.95,
    // Uri (Altdorf)
    'UR': 2.05,
    // Schwyz (Low tax)
    'SZ': 1.50,
    // Obwalden
    'OW': 2.30,
    // Nidwalden (Low tax)
    'NW': 1.60,
    // Glarus
    'GL': 2.10,
    // Zug (Very Low tax)
    'ZG': 1.15,
    // Fribourg
    'FR': 2.80,
    // Solothurn
    'SO': 2.60,
    // Basel-Stadt (Canton unique)
    'BS': 2.00, // Souvent affiché différemment, mais approx
    // Basel-Land
    'BL': 2.85,
    // Schaffhausen
    'SH': 2.20,
    // Appenzell AR
    'AR': 2.50,
    // Appenzell AI
    'AI': 1.80,
    // St. Gallen
    'SG': 2.65,
    // Graubünden
    'GR': 2.10,
    // Aargau
    'AG': 2.30,
    // Thurgau
    'TG': 2.50,
    // Ticino
    'TI': 2.20,
    // Vaud (Lausanne ~155+79 = 234% de base vaudoise)
    'VD': 2.45,
    // Valais (Sion)
    'VS': 2.35,
    // Neuchâtel (High)
    'NE': 3.00,
    // Geneva (High base)
    'GE': 2.40,
    // Jura
    'JU': 3.10,
  };

  static double get(String cantonCode) {
    return multiplierByCanton[cantonCode] ?? 2.4; // Moyenne suisse par défaut
  }
}
