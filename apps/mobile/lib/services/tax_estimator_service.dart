import 'package:mint_mobile/data/cantonal_data.dart';
import 'package:mint_mobile/services/tax_scales_loader.dart';
import 'package:mint_mobile/models/tax_scale.dart';
import 'package:mint_mobile/data/average_tax_multipliers.dart';

class TaxEstimatorService {
  /// Estime l'impôt annuel total (ICC + IFD)
  static double estimateAnnualTax({
    required double netMonthlyIncome,
    required String cantonCode,
    required String civilStatus,
    required int childrenCount,
    required int age,
    bool isSourceTaxed = false, // Impôt à la source (Permis B)
  }) {
    if (isSourceTaxed) {
      return (netMonthlyIncome * 12) * 0.12;
    }

    // 1. Reconstitution Revenu Brut Annuel Imposable (Approx)
    // On enlève charges sociales (15%) + Déductions standards (forfaitaires, transport, repas ~10%)
    // Hypothèse MVP: Net mensuel * 12 est proche du Brut Imposable après déductions de base.
    // Ou restons sur l'ancienne formule simple : Brut = Net / 0.85
    final double taxableIncomeApprox = (netMonthlyIncome * 12);

    // TENTATIVE DE CALCUL PRÉCIS (DATA RÉELLE)
    // Mapping statut
    String tariff = "Single, no children";
    if (civilStatus == 'married' || childrenCount > 0) {
      tariff = "Married/Single, with children";
    }

    final brackets = TaxScalesLoader.getBrackets(cantonCode, tariff);

    if (brackets.isNotEmpty) {
      // Calcul Impôt Cantonal de Base
      double cantonBaseTax =
          _calculateFromScales(taxableIncomeApprox, brackets);

      // Multiplicateurs (Moyennes)
      // Canton: Souvent 100% de base, mais varie (ex: VD 155%).
      // Commune: Souvent 0.6 à 1.2 du Canton.
      // Eglise: ~10%
      // IFD (Fédéral): Valeur séparée.

      // Pour MVP sans base de multiplicateurs exhaustive:
      // On assume que (Canton + Commune) ~= 2.4 x Base Cantonale (Hypothèse conservative)
      // + IFD (approximé à 10% du cantonal pour revenus moyens)

      // 3. Application du multiplicateur (Canton + Commune)
      double multiplier = AverageTaxMultipliers.get(cantonCode);
      double totalCantonCommune = cantonBaseTax * multiplier;
      double federal = _estimateFederalTax(taxableIncomeApprox, civilStatus);

      return totalCantonCommune + federal;
    }

    // FALLBACK ANCIENNE FORMULE (STATIQUE)
    final double grossAnnualIncome = (netMonthlyIncome * 12) / 0.85;
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
  }) {
    final double taxableIncome = netMonthlyIncome * 12;

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

      double multiplier = AverageTaxMultipliers.get(cantonCode);
      double totalMarginal = (marginalBaseRate / 100) * multiplier;

      // Ajouter marginal fédéral (approx)
      if (taxableIncome > 80000) totalMarginal += 0.05;
      if (taxableIncome > 120000) totalMarginal += 0.08;

      return totalMarginal.clamp(0.10, 0.45);
    }

    // Fallback
    final annualTax = estimateAnnualTax(
        netMonthlyIncome: netMonthlyIncome,
        cantonCode: cantonCode,
        civilStatus: civilStatus,
        childrenCount: 0,
        age: 30);
    final grossAnnual = (netMonthlyIncome * 12) / 0.85;
    if (grossAnnual == 0) return 0.0;
    final effectiveRate = annualTax / grossAnnual;
    return (effectiveRate * 1.4).clamp(0.10, 0.45);
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

  static double _estimateFederalTax(double income, String civilStatus) {
    // Barème IFD simplifié 2024
    // Célibataires:
    // 0-14k: 0
    // ...
    // max 11.5%
    if (income < 17000) return 0;

    // Approx progressive
    double rate = 0.0;
    if (income > 100000) rate = 0.03;
    if (income > 150000) rate = 0.06;
    if (income > 200000) rate = 0.09;

    return income * rate;
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
