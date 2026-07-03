import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/property_transmission_calculator.dart';

void main() {
  test(
      'French succession and donation ARB strings contain no LSFin banned terms',
      () {
    final coveredStrings = _coveredFrenchSuccessionAndDonationStrings();

    expect(
        coveredStrings.keys.any((key) => key.startsWith('succession')), isTrue);
    expect(
        coveredStrings.keys.any((key) => key.startsWith('donation')), isTrue);

    const bannedTokens = <String>{
      'garanti',
      'garantie',
      'garantis',
      'garanties',
      'certain',
      'certaine',
      'certains',
      'certaines',
      'assure',
      'assuree',
      'assures',
      'assurees',
      'optimal',
      'optimale',
      'optimaux',
      'optimales',
      'meilleur',
      'meilleure',
      'meilleurs',
      'meilleures',
      'parfait',
      'parfaite',
      'parfaits',
      'parfaites',
    };
    const bannedPhrases = <String>{
      'sans risque',
      'conseil financier',
      'recommandation personnalisee',
    };

    final violations = <String>[];
    for (final entry in coveredStrings.entries) {
      final normalized = _normalizeComplianceText(entry.value);
      final tokens =
          normalized.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
      for (final token in tokens) {
        if (bannedTokens.contains(token)) {
          violations.add('${entry.key}: $token');
        }
      }
      for (final phrase in bannedPhrases) {
        if (normalized.contains(phrase)) {
          violations.add('${entry.key}: $phrase');
        }
      }
    }

    expect(violations, isEmpty);
  });

  test(
      'French succession and donation ARB strings use non-breaking spaces before punctuation',
      () {
    final coveredStrings = _coveredFrenchSuccessionAndDonationStrings();
    final violations = <String>[];
    final regularSpaceBeforeFrenchPunctuation = RegExp(r' (?=[:;?!%])');

    for (final entry in coveredStrings.entries) {
      if (regularSpaceBeforeFrenchPunctuation.hasMatch(entry.value)) {
        violations.add(entry.key);
      }
    }

    expect(violations, isEmpty);
  });

  test('property transmission calculator localization keys exist in all ARBs',
      () {
    final requiredKeys = _propertyTransmissionCalculatorLocalizationKeys();
    final missingByLocale = <String, List<String>>{};

    for (final locale in const ['fr', 'en', 'de', 'es', 'it', 'pt']) {
      final arb =
          jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync())
              as Map<String, dynamic>;
      final missing =
          requiredKeys.where((key) => !arb.containsKey(key)).toList();
      if (missing.isNotEmpty) {
        missingByLocale[locale] = missing;
      }
    }

    expect(missingByLocale, isEmpty);
  });
}

Map<String, String> _coveredFrenchSuccessionAndDonationStrings() {
  final arb = jsonDecode(File('lib/l10n/app_fr.arb').readAsStringSync())
      as Map<String, dynamic>;
  return <String, String>{
    for (final entry in arb.entries)
      if ((entry.key.startsWith('succession') ||
              entry.key.startsWith('donation')) &&
          entry.value is String)
        entry.key: entry.value as String,
  };
}

String _normalizeComplianceText(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
      .replaceAll('à', 'a')
      .replaceAll('â', 'a')
      .replaceAll('ä', 'a')
      .replaceAll('á', 'a')
      .replaceAll('ã', 'a')
      .replaceAll('å', 'a')
      .replaceAll('æ', 'ae')
      .replaceAll('ç', 'c')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ë', 'e')
      .replaceAll('í', 'i')
      .replaceAll('î', 'i')
      .replaceAll('ï', 'i')
      .replaceAll('ñ', 'n')
      .replaceAll('ô', 'o')
      .replaceAll('ö', 'o')
      .replaceAll('ó', 'o')
      .replaceAll('õ', 'o')
      .replaceAll('œ', 'oe')
      .replaceAll('ù', 'u')
      .replaceAll('û', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ú', 'u')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ');
}

Set<String> _propertyTransmissionCalculatorLocalizationKeys() {
  final completeResult = PropertyTransmissionCalculator.compute(
    const PropertyTransmissionInputs(
      propertyMarketValue: 900000,
      mortgageBalance: 200000,
      parentLiquidAssets: 120000,
      parentAnnualRetirementIncome: 60000,
      parentAnnualLivingCosts: 76000,
      heirsCount: 3,
      retainedRight: 'habitation',
    ),
  );
  final missingResult = PropertyTransmissionCalculator.compute(
    const PropertyTransmissionInputs(propertyMarketValue: 900000),
  );
  final usufructResult = PropertyTransmissionCalculator.compute(
    const PropertyTransmissionInputs(
      propertyMarketValue: 900000,
      mortgageBalance: 200000,
      parentLiquidAssets: 250000,
      parentAnnualRetirementIncome: 90000,
      parentAnnualLivingCosts: 70000,
      heirsCount: 2,
      retainedRight: 'usufruct',
      avancementHoirie: false,
    ),
  );
  final noRightResult = PropertyTransmissionCalculator.compute(
    const PropertyTransmissionInputs(
      propertyMarketValue: 900000,
      mortgageBalance: 200000,
      parentLiquidAssets: 250000,
      parentAnnualRetirementIncome: 90000,
      parentAnnualLivingCosts: 70000,
      heirsCount: 0,
    ),
  );

  return <String>{
    completeResult.articleThesis,
    ...completeResult.scenarioConfidenceRationale.limits,
    ...completeResult.modelScope.unmodelledLegalFactors,
    ...completeResult.retirementAffordability.reasons,
    ...missingResult.retirementAffordability.reasons,
    ...completeResult.familyEqualization.notes,
    ...missingResult.familyEqualization.notes,
    ...usufructResult.familyEqualization.notes,
    ...completeResult.cantonalTax.notes,
    completeResult.retainedRight.label,
    ...completeResult.retainedRight.notes,
    usufructResult.retainedRight.label,
    ...usufructResult.retainedRight.notes,
    noRightResult.retainedRight.label,
    ...noRightResult.retainedRight.notes,
    for (final variant in completeResult.variants) ...[
      variant.label,
      variant.mainTradeoff,
    ],
    ...completeResult.formalities,
  };
}
