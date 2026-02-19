import 'package:mint_mobile/services/fiscal_service.dart';

// ────────────────────────────────────────────────────────────
//  WEALTH TAX + CHURCH TAX SERVICE — Chantier 1
// ────────────────────────────────────────────────────────────
//
// Pure Dart service for:
//   1. estimateWealthTax    — Wealth tax for one canton
//   2. estimateChurchTax    — Church tax for one canton
//   3. compareAllCantons    — Rank all 26 cantons by wealth tax
//
// Sources: OFS Charge Fiscale 2024, LIFD, lois fiscales cantonales.
// Rates at CHF 500'000, single, chef-lieu.
// This is an educational estimate, NOT an exact tax calculation.
// ────────────────────────────────────────────────────────────

class WealthTaxService {
  WealthTaxService._();

  // ════════════════════════════════════════════════════════════
  //  EFFECTIVE WEALTH TAX RATES (per mille of net wealth)
  //  At CHF 500'000, single, chef-lieu — Source: OFS Charge Fiscale 2024
  // ════════════════════════════════════════════════════════════

  static const Map<String, double> effectiveWealthTaxRates500k = {
    'NW': 0.75, // per mille — lowest
    'OW': 0.90,
    'AI': 1.00,
    'ZG': 1.10,
    'SZ': 1.20,
    'AR': 1.30,
    'UR': 1.40,
    'GL': 1.60,
    'LU': 1.70,
    'TG': 1.80,
    'SH': 1.90,
    'AG': 2.00,
    'GR': 2.10,
    'BL': 2.20,
    'SG': 2.30,
    'ZH': 2.50,
    'FR': 2.80,
    'SO': 2.90,
    'TI': 3.00,
    'BE': 3.40,
    'VS': 3.60,
    'NE': 3.80,
    'VD': 4.10,
    'JU': 4.30,
    'GE': 4.50,
    'BS': 5.10, // highest
  };

  // ════════════════════════════════════════════════════════════
  //  EXEMPTION THRESHOLDS (fortune below = 0 tax)
  // ════════════════════════════════════════════════════════════

  static const Map<String, double> wealthTaxExemptions = {
    'ZH': 77000,
    'BE': 97000,
    'LU': 0,
    'UR': 0,
    'SZ': 50000,
    'OW': 0,
    'NW': 35000,
    'GL': 50000,
    'ZG': 0,
    'FR': 56000,
    'SO': 55000,
    'BS': 100000,
    'BL': 75000,
    'SH': 50000,
    'AR': 50000,
    'AI': 50000,
    'SG': 75000,
    'GR': 0,
    'AG': 56000,
    'TG': 50000,
    'TI': 0,
    'VD': 58000,
    'VS': 30000,
    'NE': 50000,
    'GE': 82040,
    'JU': 50000,
  };

  // ════════════════════════════════════════════════════════════
  //  WEALTH LEVEL ADJUSTMENT (relative to 500k base)
  // ════════════════════════════════════════════════════════════

  static const Map<int, double> wealthAdjustments = {
    100000: 0.60,
    200000: 0.75,
    500000: 1.00,
    1000000: 1.15,
    2000000: 1.25,
    5000000: 1.35,
  };

  // ════════════════════════════════════════════════════════════
  //  CHURCH TAX RATES (% of impôt cantonal de base)
  //  Applied to base cantonal tax BEFORE commune multiplier.
  //  Sources: RSM Switzerland, lois fiscales cantonales.
  //  Note: rates are averages (Catholic/Reformed); actual rates
  //  vary by confession and commune. Educational estimate only.
  // ════════════════════════════════════════════════════════════

  static const Map<String, double> churchTaxRates = {
    'ZH': 0.10, 'BE': 0.15, 'LU': 0.10, 'UR': 0.12,
    'SZ': 0.10, 'OW': 0.10, 'NW': 0.10, 'GL': 0.14,
    'ZG': 0.08, 'FR': 0.12, 'SO': 0.12, 'BS': 0.08,
    'BL': 0.10, 'SH': 0.12, 'AR': 0.10, 'AI': 0.15,
    'SG': 0.12, 'GR': 0.14, 'AG': 0.10, 'TG': 0.12,
    'TI': 0.00, 'VD': 0.00, 'VS': 0.10, 'NE': 0.00,
    'GE': 0.00, 'JU': 0.10,
  };

  /// Cantons where church tax is not mandatory (separated church/state).
  static const Set<String> noMandatoryChurchTax = {'TI', 'VD', 'NE', 'GE'};

  // ════════════════════════════════════════════════════════════
  //  1. ESTIMATE WEALTH TAX
  // ════════════════════════════════════════════════════════════

  /// Estimate wealth tax for a canton.
  ///
  /// Returns a map with: canton, cantonNom, fortuneNette, fortuneImposable,
  /// impotFortune, tauxEffectifPermille.
  /// [fortune] = total net wealth (CHF).
  /// [canton] = 2-letter canton code (e.g. 'ZH').
  /// [etatCivil] = 'celibataire' or 'marie'.
  static Map<String, dynamic> estimateWealthTax({
    required double fortune,
    required String canton,
    String etatCivil = 'celibataire',
  }) {
    // 1. Get exemption
    final exemption = wealthTaxExemptions[canton] ?? 0.0;
    final effectiveExemption =
        etatCivil == 'marie' ? exemption * 2 : exemption;

    // 2. Fortune imposable
    final fortuneImposable =
        (fortune - effectiveExemption).clamp(0.0, double.infinity);
    if (fortuneImposable <= 0) return _zeroResult(canton, fortune);

    // 3. Base rate at 500k
    final baseRate = effectiveWealthTaxRates500k[canton] ?? 2.0;

    // 4. Wealth adjustment
    final adjustment = _interpolateWealthAdjustment(fortune);

    // 5. Married adjustment
    final marriedFactor = etatCivil == 'marie' ? 0.90 : 1.00;

    // 6. Calculate
    final effectiveRate = baseRate * adjustment * marriedFactor;
    final impotFortune = fortuneImposable * effectiveRate / 1000;

    return {
      'canton': canton,
      'cantonNom': FiscalService.cantonNames[canton] ?? canton,
      'fortuneNette': fortune,
      'fortuneImposable': fortuneImposable,
      'impotFortune': impotFortune,
      'tauxEffectifPermille': effectiveRate,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  2. ESTIMATE CHURCH TAX
  // ════════════════════════════════════════════════════════════

  /// Estimate church tax for a canton.
  ///
  /// [impotCantonalCommunal] = cantonal+communal income tax (CHF).
  /// [canton] = 2-letter canton code.
  /// [communeMultiplier] = total fiscal multiplier (canton + commune),
  ///   used to extract the base cantonal tax. Church tax is levied on
  ///   the impôt de base, NOT on the full cantonal+communal amount.
  ///   Source: lois fiscales cantonales, LHID art. 2.
  /// Returns: canton, isMandatory, churchTaxRate, impotEglise.
  static Map<String, dynamic> estimateChurchTax({
    required double impotCantonalCommunal,
    required String canton,
    double communeMultiplier = 1.0,
  }) {
    final rate = churchTaxRates[canton] ?? 0.0;
    final isMandatory = !noMandatoryChurchTax.contains(canton);
    // Church tax = base cantonal tax × church rate
    // base cantonal tax = impotCantonalCommunal / communeMultiplier
    final effectiveMultiplier = communeMultiplier > 0 ? communeMultiplier : 1.0;
    final baseCantonal = impotCantonalCommunal / effectiveMultiplier;
    return {
      'canton': canton,
      'isMandatory': isMandatory,
      'churchTaxRate': rate,
      'impotEglise': baseCantonal * rate,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  3. COMPARE ALL CANTONS (WEALTH TAX)
  // ════════════════════════════════════════════════════════════

  /// Compare wealth tax across all 26 cantons, sorted ascending.
  static List<Map<String, dynamic>> compareAllCantons({
    required double fortune,
    String etatCivil = 'celibataire',
  }) {
    final results = <Map<String, dynamic>>[];
    for (final canton in effectiveWealthTaxRates500k.keys) {
      results.add(estimateWealthTax(
        fortune: fortune,
        canton: canton,
        etatCivil: etatCivil,
      ));
    }
    results.sort((a, b) => (a['impotFortune'] as double)
        .compareTo(b['impotFortune'] as double));
    for (int i = 0; i < results.length; i++) {
      results[i]['rang'] = i + 1;
      results[i]['differenceVsPremier'] =
          (results[i]['impotFortune'] as double) -
              (results[0]['impotFortune'] as double);
    }
    return results;
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  /// Interpolate wealth adjustment between known brackets.
  static double _interpolateWealthAdjustment(double fortune) {
    final keys = wealthAdjustments.keys.toList()..sort();
    if (fortune <= keys.first) return wealthAdjustments[keys.first]!;
    if (fortune >= keys.last) return wealthAdjustments[keys.last]!;

    for (int i = 0; i < keys.length - 1; i++) {
      if (fortune >= keys[i] && fortune <= keys[i + 1]) {
        final ratio =
            (fortune - keys[i]) / (keys[i + 1] - keys[i]);
        return wealthAdjustments[keys[i]]! +
            ratio *
                (wealthAdjustments[keys[i + 1]]! -
                    wealthAdjustments[keys[i]]!);
      }
    }
    return 1.0;
  }

  /// Return a zero-tax result for a canton.
  static Map<String, dynamic> _zeroResult(String canton, double fortune) {
    return {
      'canton': canton,
      'cantonNom': FiscalService.cantonNames[canton] ?? canton,
      'fortuneNette': fortune,
      'fortuneImposable': 0.0,
      'impotFortune': 0.0,
      'tauxEffectifPermille': 0.0,
    };
  }
}
