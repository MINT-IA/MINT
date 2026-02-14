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

  // Mapping simplifié des voisins (Top Cantons pour commencer)
  static List<String> _getNeighbors(String cantonCode) {
    const map = {
      'ZH': ['ZG', 'SZ', 'AG', 'SH', 'TG'],
      'VD': ['VS', 'GE', 'FR', 'NE'], // Berceau de la fiscalité romande
      'GE': ['VD'],
      'BS': ['BL', 'SO', 'AG'],
      'BE': ['SO', 'FR', 'NE', 'JU'],
      'FR': ['VD', 'BE', 'NE'],
      'NE': ['VD', 'FR', 'BE', 'JU'],
      'JU': ['NE', 'BE', 'SO', 'BL'],
      'VS': ['VD', 'BE', 'UR'], // UR pour le fun (souvent moins cher)
      'TI': ['UR', 'GR'],
      'GR': ['TI', 'GL', 'SG'],
      'SG': ['TG', 'AR', 'AI'],
      'LU': ['ZG', 'SZ', 'OW', 'NW', 'AG'],
      'ZG': ['ZH', 'LU', 'SZ', 'AG'],
      'SZ': ['ZH', 'ZG', 'UR', 'GL', 'SG'],
      'AG': ['ZH', 'BL', 'SO', 'LU', 'ZG'],
    };
    return map[cantonCode] ?? [];
  }
}
