import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/dach/country_pension_service.dart';
import 'package:mint_mobile/services/dach/germany_pension.dart';
import 'package:mint_mobile/services/dach/austria_pension.dart';
import 'package:mint_mobile/services/dach/multi_country_lifecycle_service.dart';

void main() {
  // ════════════════════════════════════════════════════════════
  // CountryPensionService — 10 tests
  // ════════════════════════════════════════════════════════════

  group('CountryPensionService', () {
    test('Switzerland system has 3 pillars (AVS, LPP, 3a)', () {
      final system = CountryPensionService.getSystem(DachCountry.switzerland);

      expect(system.pillars.length, 3);
      expect(system.pillars[0].name, 'AVS');
      expect(system.pillars[1].name, 'LPP');
      expect(system.pillars[2].name, '3a');
      expect(system.country, DachCountry.switzerland);
    });

    test('Germany system has 4 pillars (GRV, bAV, Riester, Rürup)', () {
      final system = CountryPensionService.getSystem(DachCountry.germany);

      expect(system.pillars.length, 4);
      expect(system.pillars[0].name, 'GRV');
      expect(system.pillars[1].name, 'bAV');
      expect(system.pillars[2].name, 'Riester');
      expect(system.pillars[3].name, 'Rürup');
      expect(system.country, DachCountry.germany);
    });

    test('Austria system has 3 pillars (PV, Betriebspension, Zukunftsvorsorge)',
        () {
      final system = CountryPensionService.getSystem(DachCountry.austria);

      expect(system.pillars.length, 3);
      expect(system.pillars[0].name, 'PV');
      expect(system.pillars[1].name, 'Betriebspension');
      expect(system.pillars[2].name, 'Zukunftsvorsorge');
      expect(system.country, DachCountry.austria);
    });

    test('Retirement ages correct (CH=65, DE=67, AT=65)', () {
      expect(
        CountryPensionService.getSystem(DachCountry.switzerland).retirementAge,
        65,
      );
      expect(
        CountryPensionService.getSystem(DachCountry.germany).retirementAge,
        67,
      );
      expect(
        CountryPensionService.getSystem(DachCountry.austria).retirementAge,
        65,
      );
    });

    test('Compare CH→DE shows key differences', () {
      final comparison = CountryPensionService.compare(
        DachCountry.switzerland,
        DachCountry.germany,
      );

      expect(comparison.from.country, DachCountry.switzerland);
      expect(comparison.to.country, DachCountry.germany);
      expect(comparison.differences, isNotEmpty);

      // Should contain retirement age, currency, pillar, tax differences
      final categories = comparison.differences.map((d) => d.category).toList();
      expect(categories, contains('Âge de la retraite'));
      expect(categories, contains('Devise'));
      expect(categories, contains('Structure des piliers'));
      expect(categories, contains('Système fiscal'));

      // Should mention Riester/Rürup distinction
      final descriptions =
          comparison.differences.map((d) => d.description).join(' ');
      expect(descriptions, contains('Riester'));

      // Legal sources present
      expect(comparison.sources, isNotEmpty);
    });

    test('Compare CH→AT shows key differences', () {
      final comparison = CountryPensionService.compare(
        DachCountry.switzerland,
        DachCountry.austria,
      );

      expect(comparison.from.country, DachCountry.switzerland);
      expect(comparison.to.country, DachCountry.austria);
      expect(comparison.differences, isNotEmpty);

      // Should mention Pensionskonto
      final descriptions =
          comparison.differences.map((d) => d.description).join(' ');
      expect(descriptions, contains('Pensionskonto'));

      expect(comparison.sources, isNotEmpty);
    });

    test('Cross-border CH-resident/DE-worker analysis', () {
      final analysis = CountryPensionService.analyzeCrossBorder(
        residence: DachCountry.switzerland,
        work: DachCountry.germany,
        age: 40,
      );

      expect(analysis.residence, DachCountry.switzerland);
      expect(analysis.work, DachCountry.germany);
      expect(analysis.age, 40);
      expect(analysis.applicableSystems, isNotEmpty);
      expect(analysis.taxConsiderations, isNotEmpty);

      // Should mention retirement age difference (65 vs 67)
      expect(analysis.alertes, isNotEmpty);
      expect(analysis.alertes.first, contains('67'));

      // Disclaimer present
      expect(analysis.disclaimer, isNotEmpty);
      expect(analysis.sources, isNotEmpty);
    });

    test('Lifecycle phases adapted per country', () {
      final chPhases =
          CountryPensionService.getLifecyclePhases(DachCountry.switzerland);
      final dePhases =
          CountryPensionService.getLifecyclePhases(DachCountry.germany);
      final atPhases =
          CountryPensionService.getLifecyclePhases(DachCountry.austria);

      // All countries have phases
      expect(chPhases, isNotEmpty);
      expect(dePhases, isNotEmpty);
      expect(atPhases, isNotEmpty);

      // Each country's phases reference different products
      final chProducts = chPhases.expand((p) => p.relevantProducts).toSet();
      final deProducts = dePhases.expand((p) => p.relevantProducts).toSet();
      expect(chProducts, contains('AVS'));
      expect(chProducts, contains('LPP'));
      expect(deProducts, contains('GRV'));
      expect(deProducts, contains('Riester'));
    });

    test('Currency correct (CHF vs EUR)', () {
      expect(
        CountryPensionService.getSystem(DachCountry.switzerland).currencyCode,
        'CHF',
      );
      expect(
        CountryPensionService.getSystem(DachCountry.germany).currencyCode,
        'EUR',
      );
      expect(
        CountryPensionService.getSystem(DachCountry.austria).currencyCode,
        'EUR',
      );
    });

    test('Legal references present on all pillars', () {
      for (final country in DachCountry.values) {
        final system = CountryPensionService.getSystem(country);
        for (final pillar in system.pillars) {
          expect(
            pillar.legalReference,
            isNotNull,
            reason:
                '${country.name} pillar ${pillar.name} missing legal reference',
          );
          expect(
            pillar.legalReference!.isNotEmpty,
            isTrue,
            reason:
                '${country.name} pillar ${pillar.name} has empty legal reference',
          );
        }
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  // Germany/Austria specific — 10 tests
  // ════════════════════════════════════════════════════════════

  group('Germany specific', () {
    test('Riester max contribution = 2100 EUR', () {
      expect(GermanyPension.riesterMaxBeitrag, 2100);
      expect(GermanyPension.riester.maxContribution, 2100);
    });

    test('Rürup max deductible = 27566 EUR', () {
      expect(GermanyPension.ruerupMaxAbzug, 27566);
      expect(GermanyPension.ruerup.maxContribution, 27566);
    });

    test('GRV Beitragsbemessungsgrenze = 90600 EUR', () {
      expect(GermanyPension.beitragsbemessungsgrenze, 90600);
    });

    test('Riester Grundzulage = 175 EUR', () {
      expect(GermanyPension.riesterGrundzulage, 175);
    });

    test('Educational descriptions present for all German pillars', () {
      for (final pillar in GermanyPension.pillars) {
        expect(
          pillar.description.isNotEmpty,
          isTrue,
          reason: '${pillar.name} missing description',
        );
      }
    });
  });

  group('Austria specific', () {
    test('Austria women retirement age transition', () {
      // 2023 and before: 60
      expect(AustriaPension.womenRetirementAgeForYear(2023), 60);
      // 2025: should be ~61
      expect(AustriaPension.womenRetirementAgeForYear(2025), 61);
      // 2033+: 65
      expect(AustriaPension.womenRetirementAgeForYear(2033), 65);
      expect(AustriaPension.womenRetirementAgeForYear(2040), 65);
      // Monotonically increasing
      for (int y = 2024; y < 2033; y++) {
        expect(
          AustriaPension.womenRetirementAgeForYear(y + 1),
          greaterThanOrEqualTo(AustriaPension.womenRetirementAgeForYear(y)),
        );
      }
    });

    test('Pensionskonto feature flag is true', () {
      expect(AustriaPension.pensionskontoAvailable, isTrue);
    });

    test('No banned terms in any text', () {
      // Check all system descriptions for banned terms
      const bannedTerms = [
        'garanti',
        'certain',
        'assuré',
        'sans risque',
        'optimal',
        'meilleur',
        'parfait',
      ];

      for (final country in DachCountry.values) {
        final system = CountryPensionService.getSystem(country);
        final allText = [
          system.name,
          system.disclaimer,
          ...system.pillars.map((p) => p.description),
          ...system.pillars.map((p) => p.localName),
        ].join(' ').toLowerCase();

        for (final term in bannedTerms) {
          expect(
            allText.contains(term),
            isFalse,
            reason: 'Banned term "$term" found in ${country.name} system text',
          );
        }
      }
    });

    test('French text with accents (éducatif, prévoyance, etc.)', () {
      for (final country in DachCountry.values) {
        final system = CountryPensionService.getSystem(country);
        // Disclaimer should contain accented French
        expect(system.disclaimer, contains('éducatif'));
        expect(system.disclaimer, contains('spécialiste'));
      }
    });

    test('Cross-border taxation rules include legal sources', () {
      // CH→DE cross-border
      final chDe = CountryPensionService.analyzeCrossBorder(
        residence: DachCountry.switzerland,
        work: DachCountry.germany,
        age: 35,
      );
      expect(chDe.sources, isNotEmpty);
      expect(chDe.taxConsiderations, isNotEmpty);

      // DE→CH cross-border
      final deCh = CountryPensionService.analyzeCrossBorder(
        residence: DachCountry.germany,
        work: DachCountry.switzerland,
        age: 35,
      );
      expect(deCh.sources.join(' '), contains('CH-DE'));

      // DE→AT cross-border (EU internal)
      final deAt = CountryPensionService.analyzeCrossBorder(
        residence: DachCountry.germany,
        work: DachCountry.austria,
        age: 35,
      );
      expect(deAt.sources.join(' '), contains('883/2004'));
    });

    test('Source references for all constants', () {
      // Germany has SGB VI reference
      expect(GermanyPension.grv.legalReference, 'SGB VI');
      expect(GermanyPension.riester.legalReference, contains('EStG'));
      expect(GermanyPension.ruerup.legalReference, contains('EStG'));
      expect(GermanyPension.bav.legalReference, 'BetrAVG');

      // Austria has ASVG reference
      expect(AustriaPension.pv.legalReference, 'ASVG');
      expect(AustriaPension.betriebspension.legalReference, 'PKG');
      expect(AustriaPension.zukunftsvorsorge.legalReference, contains('EStG'));
    });
  });

  // ════════════════════════════════════════════════════════════
  // MultiCountryLifecycle — 5 tests
  // ════════════════════════════════════════════════════════════

  group('MultiCountryLifecycleService', () {
    test('Germany lifecycle phases differ from CH', () {
      final chPhases =
          MultiCountryLifecycleService.getPhasesForCountry(DachCountry.switzerland);
      final dePhases =
          MultiCountryLifecycleService.getPhasesForCountry(DachCountry.germany);

      // Both have phases
      expect(chPhases, isNotEmpty);
      expect(dePhases, isNotEmpty);

      // German transition phase ends at 67 (not 65 like CH)
      final deTransition = dePhases.firstWhere((p) => p.name == 'Transition');
      final chTransition = chPhases.firstWhere((p) => p.name == 'Transition');
      expect(deTransition.ageTo, 67);
      expect(chTransition.ageTo, 65);

      // German retraite starts at 67
      final deRetraite = dePhases.firstWhere((p) => p.name == 'Retraite');
      expect(deRetraite.ageFrom, 67);
    });

    test('Austria lifecycle phases differ from CH', () {
      final chPhases =
          MultiCountryLifecycleService.getPhasesForCountry(DachCountry.switzerland);
      final atPhases =
          MultiCountryLifecycleService.getPhasesForCountry(DachCountry.austria);

      expect(atPhases, isNotEmpty);

      // Austrian phases mention Pensionskonto
      final atActions =
          atPhases.expand((p) => p.keyActions).join(' ');
      expect(atActions, contains('Pensionskonto'));

      // CH phases mention AVS/LPP/3a, not Pensionskonto
      final chActions =
          chPhases.expand((p) => p.keyActions).join(' ');
      expect(chActions, contains('AVS'));
      expect(chActions, contains('LPP'));
      expect(chActions, contains('3a'));
    });

    test('Cross-border scenario generates combined analysis', () {
      final analysis = MultiCountryLifecycleService.analyzeCrossBorder(
        residence: DachCountry.switzerland,
        work: DachCountry.germany,
      );

      expect(analysis.residence, DachCountry.switzerland);
      expect(analysis.work, DachCountry.germany);
      expect(analysis.workPhases, isNotEmpty);
      expect(analysis.residenceConsiderations, isNotEmpty);
      expect(analysis.retirementNote, isNotEmpty);

      // Work phases should be German
      for (final phase in analysis.workPhases) {
        expect(phase.country, DachCountry.germany);
      }

      // Retirement note should mention different ages
      expect(analysis.retirementNote, contains('67'));
      expect(analysis.retirementNote, contains('65'));
    });

    test('Lifecycle adapts to country-specific retirement age', () {
      // DE: transition goes to 67, retraite starts at 67
      final dePhase40 =
          MultiCountryLifecycleService.getPhaseForAge(DachCountry.germany, 40);
      expect(dePhase40, isNotNull);
      expect(dePhase40!.country, DachCountry.germany);

      // At age 66, DE is still in transition (retires at 67)
      final dePhase66 =
          MultiCountryLifecycleService.getPhaseForAge(DachCountry.germany, 66);
      expect(dePhase66, isNotNull);
      expect(dePhase66!.name, 'Transition');

      // At age 66, CH is already in retraite (retires at 65)
      final chPhase66 =
          MultiCountryLifecycleService.getPhaseForAge(DachCountry.switzerland, 66);
      expect(chPhase66, isNotNull);
      expect(chPhase66!.name, 'Retraite');
    });

    test('No social comparison between countries', () {
      // Compare should never use ranking language
      final comparison = CountryPensionService.compare(
        DachCountry.switzerland,
        DachCountry.germany,
      );

      final allText = [
        comparison.disclaimer,
        ...comparison.differences.map((d) => d.description),
      ].join(' ').toLowerCase();

      // No ranking/comparison words
      expect(allText, isNot(contains('meilleur')));
      expect(allText, isNot(contains('pire')));
      expect(allText, isNot(contains('supérieur')));
      expect(allText, isNot(contains('inférieur')));

      // Disclaimer present
      expect(comparison.disclaimer, contains('éducative'));
    });
  });
}
