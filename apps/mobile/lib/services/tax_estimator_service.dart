import 'package:mint_mobile/data/cantonal_data.dart';
import 'package:mint_mobile/data/commune_data.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';
import 'package:mint_mobile/models/tax_scale.dart';
import 'package:mint_mobile/data/average_tax_multipliers.dart';

class TaxEstimatorService {
  // --- Constantes nommées ---
  /// Taux moyen d'impôt à la source pour permis B (estimation simplifiée)
  static const double _sourceTaxRate = 0.12;

  /// Facteur net → brut (hypothèse: charges sociales ~15%)
  /// Utilisé uniquement dans le fallback statique.
  static const double _netToGrossFactor = 0.85;

  /// Multiplicateur pour estimer le taux marginal à partir du taux effectif
  static const double _marginalMultiplier = 1.4;

  static const String disclaimer =
      'Estimation approximative de l\'impôt (ICC + IFD) — outil éducatif '
      'qui ne constitue pas un conseil fiscal. Les montants réels dépendent '
      'de ta commune, de ta situation familiale et de tes déductions effectives. '
      'Consultez un·e spécialiste fiscal·e pour un calcul personnalisé.';

  static const List<String> sources = [
    'LIFD art. 36 (Barèmes de l\'impôt fédéral direct)',
    'LHID (Loi sur l\'harmonisation des impôts directs des cantons et des communes)',
    'Lois cantonales sur les impôts directs (26 cantons)',
    'LIFD art. 33 (Déductions générales)',
    'LIFD art. 9 al. 1 (Imposition commune des époux)',
  ];

  /// Estime l'impôt annuel total (ICC + IFD)
  static double estimateAnnualTax({
    required double netMonthlyIncome,
    required String cantonCode,
    required String civilStatus,
    required int childrenCount,
    required int age,
    bool isSourceTaxed = false, // Impôt à la source (Permis B)
    String? communeName, // Commune pour multiplicateur précis
  }) {
    if (isSourceTaxed) {
      return (netMonthlyIncome * 12) * _sourceTaxRate;
    }

    // 1. Revenu net annuel → Revenu imposable (après déductions forfaitaires)
    // netMonthlyIncome est le salaire net (après charges sociales).
    // Déductions standards suisses (LIFD art. 26, 33, 33a):
    //   - Frais professionnels forfaitaires: ~4'000 CHF
    //   - Assurances/prévoyance (LIFD art. 33): ~2'600 (célibataire) / ~5'200 (marié)
    //   - 3a éventuel: jusqu'à 7'258 CHF
    // Simplification: déduction forfaitaire identique de 15% (LIFD art. 26, 33, 33a).
    // L'avantage marié vient des barèmes séparés ou du splitting (cantons "All").
    final double netAnnual = netMonthlyIncome * 12;
    const double deductionRate = 0.15;
    final double taxableIncomeApprox = netAnnual * (1 - deductionRate);

    // TENTATIVE DE CALCUL PRÉCIS (DATA RÉELLE)
    // Mapping statut
    String tariff = "Single, no children";
    if (civilStatus == 'married' || childrenCount > 0) {
      tariff = "Married/Single, with children";
    }

    final brackets = TaxScalesLoader.getBrackets(cantonCode, tariff);

    if (brackets.isNotEmpty) {
      // Splitting pour cantons à tarif unique "All" + mariés (ex: GE — LIPP art. 41 al. 2)
      final bool useSplitting = _usesSplitting(cantonCode) &&
          (civilStatus == 'married');
      final double incomeForScales =
          useSplitting ? taxableIncomeApprox / 2 : taxableIncomeApprox;

      // Calcul Impôt Cantonal de Base
      double cantonBaseTax = _calculateFromScales(incomeForScales, brackets);
      if (useSplitting) cantonBaseTax *= 2;

      // Application du multiplicateur (Canton + Commune)
      double multiplier;
      if (communeName != null) {
        multiplier = CommuneData.getCommuneMultiplier(cantonCode, communeName)
            ?? AverageTaxMultipliers.get(cantonCode);
      } else {
        multiplier = AverageTaxMultipliers.get(cantonCode);
      }
      double totalCantonCommune = cantonBaseTax * multiplier;
      double federal = estimateFederalTax(taxableIncomeApprox, civilStatus,
          childrenCount: childrenCount);

      return totalCantonCommune + federal;
    }

    // FALLBACK ANCIENNE FORMULE (STATIQUE)
    // ⚠️ Estimation approximative — utilise un facteur brut/net de 0.85
    // (hypothèse: charges sociales ~15%). Résultat indicatif uniquement.
    // Ce chemin est emprunté si TaxScalesLoader n'a pas de données pour ce canton.
    final double grossAnnualIncome = (netMonthlyIncome * 12) / _netToGrossFactor;
    double baseRate = _getBaseProgressiveRate(grossAnnualIncome);
    final cantonProfile = CantonalDataService.getByCode(cantonCode);
    double cantonFactor = _getCantonFactor(cantonProfile.taxPressureIncome);
    double familyFactor = _getFamilyFactor(civilStatus, childrenCount);
    return grossAnnualIncome * baseRate * cantonFactor * familyFactor;
  }

  static double estimateMonthlyProvision(double annualTax) {
    return annualTax / 12;
  }

  /// Estime le taux marginal (pour calculer les économies fiscales)
  static double estimateMarginalTaxRate({
    required double netMonthlyIncome,
    required String cantonCode,
    required String civilStatus,
    String? communeName, // Commune pour multiplicateur précis
  }) {
    // Apply same deductions as estimateAnnualTax (LIFD art. 26, 33, 33a)
    const double deductionRate = 0.15;
    final double taxableIncome = netMonthlyIncome * 12 * (1 - deductionRate);

    // Mapping statut
    String tariff = "Single, no children";
    if (civilStatus == 'married') {
      tariff = "Married/Single, with children";
    }

    final brackets = TaxScalesLoader.getBrackets(cantonCode, tariff);

    if (brackets.isNotEmpty) {
      // Calcul précis du marginal sur la base cantonale
      // On regarde le taux du dernier bracket touché
      double marginalBaseRate = _getMarginalBaseRate(taxableIncome, brackets);

      // On multiplie par les facteurs communaux/cantonaux (~2.4)
      // + IFD marginal (~1-3% -> +0.01 à 0.11 effectif local)
      // Le marginal total est souvent ~3x à 4x le marginal de base ?
      // Non, car les brackets sont en Taux.
      // Si bracket dit "5%", et multiplicateurs totaux = 240%, alors marginal = 12%.

      double multiplier;
      if (communeName != null) {
        multiplier = CommuneData.getCommuneMultiplier(cantonCode, communeName)
            ?? AverageTaxMultipliers.get(cantonCode);
      } else {
        multiplier = AverageTaxMultipliers.get(cantonCode);
      }
      double totalMarginal = (marginalBaseRate / 100) * multiplier;

      // Ajouter marginal fédéral (LIFD art. 36)
      totalMarginal += _getIfdMarginalRate(taxableIncome, civilStatus);

      return totalMarginal.clamp(0.05, 0.45);
    }

    // Fallback
    final annualTax = estimateAnnualTax(
        netMonthlyIncome: netMonthlyIncome,
        cantonCode: cantonCode,
        civilStatus: civilStatus,
        childrenCount: 0,
        age: 30);
    final grossAnnual = (netMonthlyIncome * 12) / _netToGrossFactor;
    if (grossAnnual == 0) return 0.0;
    final effectiveRate = annualTax / grossAnnual;
    return (effectiveRate * _marginalMultiplier).clamp(0.05, 0.45);
  }

  static double calculateTaxSavings(
      double deductionAmount, double marginalTaxRate) {
    return deductionAmount * marginalTaxRate;
  }

  // --- Helpers Real Data ---

  static double _calculateFromScales(double income, List<TaxScale> brackets) {
    double tax = 0.0;
    double remainingIncome = income;

    for (var bracket in brackets) {
      if (remainingIncome <= 0) break;

      double taxableInBracket = bracket.incomeThreshold; // "6900"
      if (remainingIncome < taxableInBracket) {
        taxableInBracket = remainingIncome;
      }

      // Bracket.rate est en % (ex: 2.0 pour 2%)
      tax += taxableInBracket * (bracket.rate / 100);

      remainingIncome -= taxableInBracket;
    }

    // Si revenu dépasse le dernier bracket (souvent infini ou max)
    // Le dernier bracketjson a souvent un gros montant
    return tax;
  }

  static double _getMarginalBaseRate(double income, List<TaxScale> brackets) {
    double currentPos = 0.0;
    for (var bracket in brackets) {
      if (income >= currentPos &&
          income < (currentPos + bracket.incomeThreshold)) {
        return bracket.rate;
      }
      currentPos += bracket.incomeThreshold;
    }
    // Si au delà du dernier bracket
    return brackets.isNotEmpty ? brackets.last.rate : 0.0;
  }

  /// Calcul progressif de l'IFD (impôt fédéral direct).
  /// Barèmes 2024 (LIFD art. 36 al. 1 célibataires, al. 2 mariés).
  /// Déduction par enfant : 259 CHF (LIFD art. 36 al. 2bis).
  static double estimateFederalTax(double income, String civilStatus,
      {int childrenCount = 0}) {
    // Barèmes IFD 2024 (LIFD art. 36)
    // Format: [seuil_cumulé, taux_marginal_en_pourcent]
    final List<List<double>> brackets = (civilStatus == 'married')
        ? [
            [28300, 0.00],
            [50900, 1.00],
            [58400, 2.00],
            [75300, 3.00],
            [90300, 4.00],
            [103400, 5.00],
            [114700, 6.00],
            [124200, 7.00],
            [131700, 8.00],
            [137300, 9.00],
            [141200, 10.00],
            [143100, 11.00],
            [145000, 12.00],
            [895900, 13.00],
            [double.infinity, 11.50],
          ]
        : [
            [14500, 0.00],
            [31600, 0.77],
            [41400, 0.88],
            [55200, 2.60],
            [72500, 2.90],
            [78100, 5.10],
            [103600, 6.40],
            [134600, 6.80],
            [176000, 8.90],
            [755200, 11.00],
            [double.infinity, 11.50],
          ];

    double tax = 0.0;
    double previousThreshold = 0.0;
    for (final bracket in brackets) {
      final threshold = bracket[0];
      final rate = bracket[1];
      if (income <= previousThreshold) break;
      final taxableInBracket =
          (income < threshold ? income : threshold) - previousThreshold;
      tax += taxableInBracket * (rate / 100);
      previousThreshold = threshold;
    }

    // Déduction enfants (LIFD art. 36 al. 2bis)
    tax -= childrenCount * 259;
    return tax < 0 ? 0 : tax;
  }

  /// Cantons à tarif unique "All" qui utilisent le splitting (revenu / 2)
  /// pour les couples mariés car ils n'ont pas de barème marié séparé.
  /// Sources: LIPP art. 41 al. 2 (GE), StG §§ correspondants par canton.
  /// Liste alignée avec TaxScalesLoader.getBrackets() fallback "All".
  static bool _usesSplitting(String cantonCode) {
    const splittingCantons = {
      'GE', 'Geneva',
      'UR', 'Uri',
      'OW', 'Obwalden',
      'NW', 'Nidwalden',
      'GL', 'Glarus',
      'SO', 'Solothurn',
      'AR', 'Appenzell Ausserrhoden',
      'AI', 'Appenzell Innerrhoden',
      'SH', 'Schaffhausen',
      'GR', 'Graubünden',
      'AG', 'Aargau',
      'TG', 'Thurgau',
      'VS', 'Valais',
      'NE', 'Neuchâtel',
    };
    return splittingCantons.contains(cantonCode);
  }

  /// Retourne le taux marginal IFD (en décimal, ex: 0.066 pour 6.6%)
  /// pour le dernier bracket atteint par le revenu.
  static double _getIfdMarginalRate(double income, String civilStatus) {
    final List<List<double>> brackets = (civilStatus == 'married')
        ? [
            [28300, 0.00],
            [50900, 1.00],
            [58400, 2.00],
            [75300, 3.00],
            [90300, 4.00],
            [103400, 5.00],
            [114700, 6.00],
            [124200, 7.00],
            [131700, 8.00],
            [137300, 9.00],
            [141200, 10.00],
            [143100, 11.00],
            [145000, 12.00],
            [895900, 13.00],
            [double.infinity, 11.50],
          ]
        : [
            [14500, 0.00],
            [31600, 0.77],
            [41400, 0.88],
            [55200, 2.60],
            [72500, 2.90],
            [78100, 5.10],
            [103600, 6.40],
            [134600, 6.80],
            [176000, 8.90],
            [755200, 11.00],
            [double.infinity, 11.50],
          ];

    double previousThreshold = 0.0;
    double marginalRatePct = 0.0;
    for (final bracket in brackets) {
      if (income <= previousThreshold) break;
      marginalRatePct = bracket[1];
      previousThreshold = bracket[0];
    }
    return marginalRatePct / 100;
  }

  // --- Helpers Legacy (Rest of file kept minimal or removed if unused, but kept for fallback) ---

  static double _getBaseProgressiveRate(double grossIncome) {
    if (grossIncome <= 25000) return 0.02;
    if (grossIncome <= 50000) return 0.08;
    if (grossIncome <= 80000) return 0.11;
    if (grossIncome <= 120000) return 0.15;
    if (grossIncome <= 180000) return 0.20;
    if (grossIncome <= 250000) return 0.25;
    return 0.30;
  }

  static double _getCantonFactor(TaxPressure pressure) {
    switch (pressure) {
      case TaxPressure.low:
        return 0.75;
      case TaxPressure.medium:
        return 1.0;
      case TaxPressure.high:
        return 1.15;
      case TaxPressure.veryHigh:
        return 1.30;
    }
  }

  static double _getFamilyFactor(String civilStatus, int children) {
    double factor = 1.0;
    if (civilStatus == 'married') factor = 0.85;
    if (children > 0) factor = factor * (1.0 - (children * 0.08));
    return factor < 0.5 ? 0.5 : factor;
  }
}
