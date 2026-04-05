import 'package:mint_mobile/services/tax_estimator_service.dart';

class FiscalIntelligenceService {
  /// Calcule combien de mois l'utilisateur travaille uniquement pour payer ses impôts
  static double calculateMonthsWorkedForTax({
    required double annualTax,
    required double netAnnualIncome,
  }) {
    if (netAnnualIncome == 0) return 0;
    // Revenu Net Mensuel moyen
    double monthlyIncome = netAnnualIncome / 12;
    // Combien de mois de revenu représente l'impôt ?
    return annualTax / monthlyIncome;
  }

  /// Compare l'impôt actuel avec les cantons voisins pour trouver des économies potentielles
  static Map<String, dynamic>? findBetterNeighbor({
    required String currentCanton,
    required double netMonthlyIncome,
    required String civilStatus,
    required int age,
    int childrenCount = 0,
  }) {
    final neighbors = _getNeighbors(currentCanton);
    if (neighbors.isEmpty) return null;

    final currentTax = TaxEstimatorService.estimateAnnualTax(
      netMonthlyIncome: netMonthlyIncome,
      cantonCode: currentCanton,
      civilStatus: civilStatus,
      childrenCount: childrenCount,
      age: age,
    );

    String? bestCanton;
    double maxSavings = 0;

    for (final neighbor in neighbors) {
      final neighborTax = TaxEstimatorService.estimateAnnualTax(
        netMonthlyIncome: netMonthlyIncome,
        cantonCode: neighbor,
        civilStatus: civilStatus,
        childrenCount: childrenCount,
        age: age,
      );

      final savings = currentTax - neighborTax;
      if (savings > maxSavings) {
        maxSavings = savings;
        bestCanton = neighbor;
      }
    }

    if (bestCanton != null && maxSavings > 500) {
      // On ne notifie que si l'économie est significative (> 500 CHF)
      return {
        'canton': bestCanton,
        'savings': maxSavings,
        'currentTax': currentTax,
        'neighborTax': currentTax - maxSavings,
      };
    }

    return null;
  }

  /// Cantons limitrophes (geographie suisse, 26/26).
  static List<String> _getNeighbors(String cantonCode) {
    const map = {
      'AG': ['ZH', 'BL', 'SO', 'LU', 'ZG', 'BE'],
      'AI': ['AR', 'SG'],
      'AR': ['AI', 'SG'],
      'BE': ['SO', 'FR', 'NE', 'JU', 'VS', 'LU', 'OW', 'NW', 'AG'],
      'BL': ['BS', 'SO', 'JU', 'AG'],
      'BS': ['BL', 'SO', 'AG'],
      'FR': ['VD', 'BE', 'NE'],
      'GE': ['VD'],
      'GL': ['SZ', 'GR', 'SG', 'UR'],
      'GR': ['TI', 'GL', 'SG', 'UR'],
      'JU': ['NE', 'BE', 'SO', 'BL'],
      'LU': ['ZG', 'SZ', 'OW', 'NW', 'AG', 'BE'],
      'NE': ['VD', 'FR', 'BE', 'JU'],
      'NW': ['LU', 'OW', 'UR', 'BE'],
      'OW': ['LU', 'NW', 'BE', 'UR'],
      'SG': ['TG', 'AR', 'AI', 'GR', 'GL', 'SZ', 'ZH'],
      'SH': ['ZH', 'TG'],
      'SO': ['BE', 'AG', 'BL', 'BS', 'JU'],
      'SZ': ['ZH', 'ZG', 'UR', 'GL', 'SG', 'LU'],
      'TG': ['ZH', 'SH', 'SG'],
      'TI': ['UR', 'GR', 'VS'],
      'UR': ['SZ', 'GL', 'GR', 'TI', 'BE', 'OW', 'NW', 'VS'],
      'VD': ['VS', 'GE', 'FR', 'NE'],
      'VS': ['VD', 'BE', 'UR', 'TI'],
      'ZG': ['ZH', 'LU', 'SZ', 'AG'],
      'ZH': ['ZG', 'SZ', 'AG', 'SH', 'TG', 'SG'],
    };
    return map[cantonCode] ?? [];
  }
}
