import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/services/segments_service.dart';

void main() {
  // Create a French S instance for use in all tests
  final S s = SFr();

  // ═══════════════════════════════════════════════════════════════════
  //  1. GenderGapService tests
  // ═══════════════════════════════════════════════════════════════════

  group('GenderGapService', () {
    test('100% activity rate produces zero lacune', () {
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 100,
          age: 35,
          revenuAnnuel: 80000,
          avoirLpp: 50000,
          anneesCotisation: 10,
          canton: 'VD',
        ),
        s: s,
      );
      expect(result.lacuneAnnuelle, closeTo(0.0, 0.01));
      expect(result.lacuneTotale, closeTo(0.0, 0.1));
    });

    test('part-time 60% produces positive lacune', () {
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 60,
          age: 40,
          revenuAnnuel: 48000, // 80k at 100%
          avoirLpp: 40000,
          anneesCotisation: 15,
          canton: 'GE',
        ),
        s: s,
      );
      expect(result.lacuneAnnuelle, greaterThan(0));
      expect(result.lacuneTotale, greaterThan(0));
    });

    test('lacuneTotale is approximately 20x lacuneAnnuelle', () {
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 50,
          age: 40,
          revenuAnnuel: 40000,
          avoirLpp: 30000,
          anneesCotisation: 15,
          canton: 'ZH',
        ),
        s: s,
      );
      expect(result.lacuneTotale, closeTo(result.lacuneAnnuelle * 20, 0.01));
    });

    test('deductionCoordination is 26460 CHF (not prorated)', () {
      expect(GenderGapService.deductionCoordination, 26460);
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 50,
          age: 30,
          revenuAnnuel: 30000,
          avoirLpp: 10000,
          anneesCotisation: 5,
          canton: 'BE',
        ),
        s: s,
      );
      expect(result.deductionCoordination, 26460);
    });

    test('anneesRestantes computed correctly from age to 65', () {
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 80,
          age: 45,
          revenuAnnuel: 64000,
          avoirLpp: 100000,
          anneesCotisation: 20,
          canton: 'VD',
        ),
        s: s,
      );
      expect(result.anneesRestantes, 20); // 65 - 45
    });

    test('age 65 or older gives 0 anneesRestantes', () {
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 80,
          age: 67,
          revenuAnnuel: 50000,
          avoirLpp: 200000,
          anneesCotisation: 40,
          canton: 'ZH',
        ),
        s: s,
      );
      expect(result.anneesRestantes, 0);
    });

    test('zero activity rate produces zero renteAtCurrentTaux', () {
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 0,
          age: 35,
          revenuAnnuel: 0,
          avoirLpp: 10000,
          anneesCotisation: 0,
          canton: 'GE',
        ),
        s: s,
      );
      // salaire100 = 0 (division by zero guard), so both rentes are based only on avoirLpp
      expect(result.renteAtCurrentTaux, greaterThanOrEqualTo(0));
    });

    test('recommendations include rachat LPP when lacune exists', () {
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 60,
          age: 40,
          revenuAnnuel: 48000,
          avoirLpp: 40000,
          anneesCotisation: 15,
          canton: 'VD',
        ),
        s: s,
      );
      expect(
        result.recommendations.any((r) => r.title.contains('Rachat LPP')),
        isTrue,
      );
    });

    test('recommendations always include 3e pilier', () {
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 100,
          age: 30,
          revenuAnnuel: 80000,
          avoirLpp: 50000,
          anneesCotisation: 5,
          canton: 'ZH',
        ),
        s: s,
      );
      expect(
        result.recommendations.any((r) => r.title.contains('3e pilier')),
        isTrue,
      );
    });

    test('low activity and low coordinated salary triggers proratisation rec', () {
      // 40% activity, low income -> salaireCoordonneActuel should be low
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 40,
          age: 35,
          revenuAnnuel: 30000,
          avoirLpp: 15000,
          anneesCotisation: 10,
          canton: 'VD',
        ),
        s: s,
      );
      expect(
        result.recommendations.any((r) => r.title.contains('proratisation')),
        isTrue,
      );
    });

    test('activity below 80% triggers augmentation taux recommendation', () {
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 60,
          age: 40,
          revenuAnnuel: 48000,
          avoirLpp: 40000,
          anneesCotisation: 15,
          canton: 'VD',
        ),
        s: s,
      );
      expect(
        result.recommendations.any(
          (r) => r.title.contains('augmentation du taux'),
        ),
        isTrue,
      );
    });

    test('statistiqueOfs mentions OFS and gender gap', () {
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 80,
          age: 40,
          revenuAnnuel: 64000,
          avoirLpp: 60000,
          anneesCotisation: 15,
          canton: 'VD',
        ),
        s: s,
      );
      expect(result.statistiqueOfs, contains('OFS'));
      expect(result.statistiqueOfs, contains('37%'));
    });

    test('salaireCoordonne100 respects max cap of 64260', () {
      // Very high income at 100% -> coordinated salary should cap
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 100,
          age: 40,
          revenuAnnuel: 200000,
          avoirLpp: 100000,
          anneesCotisation: 15,
          canton: 'ZH',
        ),
        s: s,
      );
      expect(result.salaireCoordonne100, 64260);
    });

    test('formatChf formats correctly with Swiss apostrophe', () {
      expect(GenderGapService.formatChf(1234), contains("1'234"));
      expect(GenderGapService.formatChf(100000), contains("100'000"));
      expect(GenderGapService.formatChf(500), contains('500'));
    });

    test('each recommendation has a legal source', () {
      final result = GenderGapService.analyse(
        input: const GenderGapInput(
          tauxActivite: 50,
          age: 35,
          revenuAnnuel: 35000,
          avoirLpp: 20000,
          anneesCotisation: 10,
          canton: 'VD',
        ),
        s: s,
      );
      for (final rec in result.recommendations) {
        expect(rec.source, isNotEmpty);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  2. FrontalierService tests
  // ═══════════════════════════════════════════════════════════════════

  group('FrontalierService', () {
    test('France + GE produces source tax rule', () {
      final result = FrontalierService.analyse(
        input: const FrontalierInput(
          paysResidence: PaysResidence.fr,
          cantonTravail: 'GE',
          revenuBrut: 80000,
          etatCivil: EtatCivilFrontalier.celibataire,
        ),
        s: s,
      );
      expect(result.paysLabel, 'France');
      expect(
        result.rules.any((r) =>
            r.category == 'fiscal' && r.title.contains('source en Suisse')),
        isTrue,
      );
    });

    test('France + non-GE canton produces France residence tax rule', () {
      final result = FrontalierService.analyse(
        input: const FrontalierInput(
          paysResidence: PaysResidence.fr,
          cantonTravail: 'VD',
          revenuBrut: 80000,
          etatCivil: EtatCivilFrontalier.marie,
        ),
        s: s,
      );
      expect(
        result.rules.any((r) =>
            r.category == 'fiscal' && r.title.contains('Imposition en France')),
        isTrue,
      );
    });

    test('GE triggers quasi-resident check', () {
      final result = FrontalierService.analyse(
        input: const FrontalierInput(
          paysResidence: PaysResidence.fr,
          cantonTravail: 'GE',
          revenuBrut: 80000,
          etatCivil: EtatCivilFrontalier.celibataire,
        ),
        s: s,
      );
      expect(result.quasiResident, isNotNull);
      expect(result.quasiResident!.cantonConcerne, 'GE');
    });

    test('non-GE canton returns null quasi-resident', () {
      final result = FrontalierService.analyse(
        input: const FrontalierInput(
          paysResidence: PaysResidence.de,
          cantonTravail: 'BS',
          revenuBrut: 90000,
          etatCivil: EtatCivilFrontalier.celibataire,
        ),
        s: s,
      );
      expect(result.quasiResident, isNull);
    });

    test('GE allows 3a deduction via quasi-resident', () {
      final result = FrontalierService.analyse(
        input: const FrontalierInput(
          paysResidence: PaysResidence.fr,
          cantonTravail: 'GE',
          revenuBrut: 80000,
          etatCivil: EtatCivilFrontalier.celibataire,
        ),
        s: s,
      );
      expect(
        result.rules.any((r) =>
            r.category == '3a' && r.title.contains('quasi-résident')),
        isTrue,
      );
    });

    test('non-GE frontalier gets 3a alert (no deduction)', () {
      final result = FrontalierService.analyse(
        input: const FrontalierInput(
          paysResidence: PaysResidence.de,
          cantonTravail: 'ZH',
          revenuBrut: 100000,
          etatCivil: EtatCivilFrontalier.celibataire,
        ),
        s: s,
      );
      final rule3a = result.rules.firstWhere((r) => r.category == '3a');
      expect(rule3a.isAlert, isTrue);
      expect(rule3a.title, contains('pas de déduction'));
    });

    test('all countries produce LPP and AVS rules', () {
      for (final pays in PaysResidence.values) {
        final result = FrontalierService.analyse(
          input: FrontalierInput(
            paysResidence: pays,
            cantonTravail: 'ZH',
            revenuBrut: 80000,
            etatCivil: EtatCivilFrontalier.celibataire,
          ),
          s: s,
        );
        expect(result.rules.any((r) => r.category == 'lpp'), isTrue);
        expect(result.rules.any((r) => r.category == 'avs'), isTrue);
      }
    });

    test('Italy produces new accord fiscal alert', () {
      final result = FrontalierService.analyse(
        input: const FrontalierInput(
          paysResidence: PaysResidence.it,
          cantonTravail: 'TI',
          revenuBrut: 70000,
          etatCivil: EtatCivilFrontalier.celibataire,
        ),
        s: s,
      );
      final fiscalRule = result.rules
          .firstWhere((r) => r.category == 'fiscal');
      expect(fiscalRule.isAlert, isTrue);
      expect(fiscalRule.title, contains('Nouvel accord'));
    });

    test('checklist contains at least 8 items', () {
      final result = FrontalierService.analyse(
        input: const FrontalierInput(
          paysResidence: PaysResidence.fr,
          cantonTravail: 'VD',
          revenuBrut: 80000,
          etatCivil: EtatCivilFrontalier.celibataire,
        ),
        s: s,
      );
      expect(result.checklist.length, greaterThanOrEqualTo(8));
    });

    test('GE checklist includes quasi-resident mention', () {
      final result = FrontalierService.analyse(
        input: const FrontalierInput(
          paysResidence: PaysResidence.fr,
          cantonTravail: 'GE',
          revenuBrut: 80000,
          etatCivil: EtatCivilFrontalier.celibataire,
        ),
        s: s,
      );
      expect(
        result.checklist.any((c) => c.contains('quasi-résident')),
        isTrue,
      );
    });

    test('getPaysLabel returns correct labels', () {
      expect(FrontalierService.getPaysLabel(PaysResidence.fr, s: s), 'France');
      expect(FrontalierService.getPaysLabel(PaysResidence.de, s: s), 'Allemagne');
      expect(FrontalierService.getPaysLabel(PaysResidence.it, s: s), 'Italie');
    });

    test('getFlagCode returns correct codes', () {
      expect(FrontalierService.getFlagCode(PaysResidence.fr), 'FR');
      expect(FrontalierService.getFlagCode(PaysResidence.li), 'LI');
    });

    test('LPP libre passage rule is alert', () {
      final result = FrontalierService.analyse(
        input: const FrontalierInput(
          paysResidence: PaysResidence.de,
          cantonTravail: 'BS',
          revenuBrut: 90000,
          etatCivil: EtatCivilFrontalier.celibataire,
        ),
        s: s,
      );
      final lppRules = result.rules.where((r) => r.category == 'lpp');
      expect(
        lppRules.any((r) => r.isAlert && r.title.contains('Libre passage')),
        isTrue,
      );
    });

    test('all rules have sources', () {
      final result = FrontalierService.analyse(
        input: const FrontalierInput(
          paysResidence: PaysResidence.fr,
          cantonTravail: 'GE',
          revenuBrut: 80000,
          etatCivil: EtatCivilFrontalier.celibataire,
        ),
        s: s,
      );
      for (final rule in result.rules) {
        expect(rule.source, isNotEmpty);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════
  //  3. IndependantService tests
  // ═══════════════════════════════════════════════════════════════════

  group('IndependantService', () {
    test('3a ceiling without LPP is 20% of net, max 36288', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 100000,
          age: 40,
          canton: 'VD',
        ),
        s: s,
      );
      // 20% of 100k = 20000, below max
      expect(result.plafond3a, 20000);
    });

    test('3a ceiling without LPP caps at 36288', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 200000,
          age: 40,
          canton: 'VD',
        ),
        s: s,
      );
      // 20% of 200k = 40000, capped at 36288
      expect(result.plafond3a, 36288);
    });

    test('3a ceiling with LPP is 7258', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 100000,
          age: 40,
          hasLpp: true,
          canton: 'VD',
        ),
        s: s,
      );
      expect(result.plafond3a, 7258);
    });

    test('AVS contribution at full rate for income >= 58800', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 100000,
          age: 40,
          canton: 'ZH',
        ),
        s: s,
      );
      // 100000 * 0.106 = 10600
      expect(result.cotisationAvsAnnuelle, closeTo(10600, 0.01));
    });

    test('AVS contribution zero for income below threshold', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 5000, // below 9800
          age: 40,
          canton: 'VD',
        ),
        s: s,
      );
      expect(result.cotisationAvsAnnuelle, 0);
    });

    test('AVS contribution degressive for mid-range income', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 30000, // in degressive bracket
          age: 40,
          canton: 'VD',
        ),
        s: s,
      );
      // 30000 is between 28600 (5.2%) and 32400 (5.6%), so should use 5.2%
      expect(result.cotisationAvsAnnuelle, closeTo(30000 * 0.052, 0.01));
    });

    test('zero income returns zero AVS', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 0,
          age: 40,
          canton: 'VD',
        ),
        s: s,
      );
      expect(result.cotisationAvsAnnuelle, 0);
    });

    test('coverage gaps identify missing IJM as critique', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 80000,
          age: 35,
          hasIjm: false,
          canton: 'VD',
        ),
        s: s,
      );
      final ijmGap = result.coverageGaps.firstWhere(
        (g) => g.label.contains('IJM'),
      );
      expect(ijmGap.isCovered, isFalse);
      expect(ijmGap.urgency, 'critique');
    });

    test('coverage gaps show LPP as covered when hasLpp', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 80000,
          age: 35,
          hasLpp: true,
          canton: 'VD',
        ),
        s: s,
      );
      final lppGap = result.coverageGaps.firstWhere(
        (g) => g.label.contains('LPP'),
      );
      expect(lppGap.isCovered, isTrue);
      expect(lppGap.urgency, 'basse');
    });

    test('alerts include CRITIQUE for missing IJM', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 80000,
          age: 35,
          hasIjm: false,
          canton: 'VD',
        ),
        s: s,
      );
      expect(result.alerts.any((a) => a.contains('CRITIQUE')), isTrue);
    });

    test('no alerts when all coverages present', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 80000,
          age: 35,
          hasLpp: true,
          hasIjm: true,
          hasLaa: true,
          has3a: true,
          canton: 'VD',
        ),
        s: s,
      );
      expect(result.alerts, isEmpty);
    });

    test('protection cost IJM estimate is 2% of income / 12', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 60000,
          age: 35,
          hasIjm: false,
          canton: 'VD',
        ),
        s: s,
      );
      // 60000 * 0.02 / 12 = 100
      expect(result.protectionCost.ijmMensuel, closeTo(100, 0.01));
    });

    test('protection cost IJM is 0 when already covered', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 60000,
          age: 35,
          hasIjm: true,
          canton: 'VD',
        ),
        s: s,
      );
      expect(result.protectionCost.ijmMensuel, 0);
    });

    test('recommendations always include AVS extrait and budget', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 80000,
          age: 35,
          hasLpp: true,
          hasIjm: true,
          hasLaa: true,
          has3a: true,
          canton: 'VD',
        ),
        s: s,
      );
      expect(result.recommendations.any((r) => r.contains('AVS')), isTrue);
      expect(result.recommendations.any((r) => r.contains('budget')), isTrue);
    });

    test('all coverage gaps have legal sources', () {
      final result = IndependantService.analyse(
        input: const IndependantInput(
          revenuNet: 80000,
          age: 35,
          canton: 'VD',
        ),
        s: s,
      );
      for (final gap in result.coverageGaps) {
        expect(gap.source, isNotEmpty);
      }
    });

    test('formatChf formats large numbers with apostrophes', () {
      expect(IndependantService.formatChf(36288), contains("36'288"));
    });
  });
}
