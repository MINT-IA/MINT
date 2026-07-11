import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/donation_service.dart';

/// Unit tests for DonationService.
///
/// These tests deliberately avoid validating fake precision. Gift tax is
/// cantonal/communal and depends on the exact relationship, canton, commune,
/// exemptions and asset type. Without an authoritative tariff table, MINT must
/// return a confirmation state instead of inventing a CHF amount.
void main() {
  group('DonationService - Swiss gift tax boundaries', () {
    test('spouse uses usual exemption, not fake tax', () {
      for (final canton in DonationService.swissCantons) {
        final result = DonationService.calculate(
          montant: 100000,
          donateurAge: 50,
          lienParente: 'conjoint',
          canton: canton,
        );

        expect(result.taxRequiresCantonalConfirmation, isFalse);
        expect(result.tauxImposition, 0.0);
        expect(result.impotDonation, 0.0);
        expect(
          result.premierEclairage,
          DonationMessageCode.insightUsualExemption,
        );
      }
    });

    test('descendants require cantonal confirmation in every canton', () {
      for (final canton in DonationService.swissCantons) {
        final result = DonationService.calculate(
          montant: 500000,
          donateurAge: 50,
          lienParente: 'descendant',
          canton: canton,
        );

        expect(result.taxRequiresCantonalConfirmation, isTrue);
        expect(result.tauxImposition, 0.0);
        expect(result.impotDonation, 0.0);
        expect(result.taxStatus, DonationMessageCode.taxDescendantConfirm);
        expect(result.alerts, contains(DonationMessageCode.alertTaxConfirm));
      }
    });

    test('non-exempt relationships require cantonal confirmation', () {
      for (final lien in ['parent', 'fratrie', 'concubin', 'tiers']) {
        final result = DonationService.calculate(
          montant: 100000,
          donateurAge: 50,
          lienParente: lien,
          canton: 'GE',
        );

        expect(result.taxRequiresCantonalConfirmation, isTrue);
        expect(result.tauxImposition, 0.0);
        expect(result.impotDonation, 0.0);
        expect(result.premierEclairage, DonationMessageCode.insightTaxConfirm);
        expect(result.alerts, contains(DonationMessageCode.alertTaxConfirm));
      }
    });

    test('unknown canton never falls back silently to Vaud', () {
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'XX',
      );

      expect(result.taxRequiresCantonalConfirmation, isTrue);
      expect(result.tauxImposition, 0.0);
      expect(result.impotDonation, 0.0);
      expect(result.alerts, contains(DonationMessageCode.alertUnknownCanton));
    });
  });

  group('DonationService - hereditary reserve', () {
    test('2023 law: parents no longer have a compulsory portion', () {
      expect(DonationService.reserves['parent'], 0.0);
    });

    test('single donor with children: descendants reserve is 50 percent', () {
      final result = DonationService.calculate(
        montant: 50000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        civilStatus: 'celibataire',
        nbEnfants: 2,
        fortuneTotaleDonateur: 1000000,
      );

      expect(result.reserveHereditaireTotale, 500000.0);
      expect(result.quotiteDisponible, 500000.0);
    });

    test('married donor with children: spouse and children are reserved heirs',
        () {
      final result = DonationService.calculate(
        montant: 50000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        civilStatus: 'marie',
        nbEnfants: 2,
        fortuneTotaleDonateur: 1000000,
      );

      expect(result.reserveHereditaireTotale, 500000.0);
      expect(result.quotiteDisponible, 500000.0);
      expect(result.quotiteRequiresSpecialistConfirmation, isTrue);
      expect(
        result.alerts,
        contains(DonationMessageCode.alertMatrimonialRegime),
      );
    });

    test('married donor does not flag reduction before matrimonial liquidation',
        () {
      final result = DonationService.calculate(
        montant: 900000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        civilStatus: 'marie',
        nbEnfants: 2,
        fortuneTotaleDonateur: 1000000,
        avancementHoirie: false,
      );

      expect(result.quotiteRequiresSpecialistConfirmation, isTrue);
      expect(result.donationDepasseQuotite, isFalse);
      expect(result.montantDepassement, 0.0);
      expect(
        result.alerts,
        contains(DonationMessageCode.alertMatrimonialRegime),
      );
      expect(
        result.alerts,
        contains(DonationMessageCode.alertSpouseLargeGift),
      );
      expect(
        result.alerts,
        isNot(contains(DonationMessageCode.alertReductionRisk)),
      );
    });

    test('single donor without children: no compulsory portion is estimated',
        () {
      final result = DonationService.calculate(
        montant: 50000,
        donateurAge: 50,
        lienParente: 'fratrie',
        canton: 'ZH',
        civilStatus: 'celibataire',
        nbEnfants: 0,
        fortuneTotaleDonateur: 800000,
      );

      expect(result.reserveHereditaireTotale, 0.0);
      expect(result.quotiteDisponible, 800000.0);
      expect(result.quotiteRequiresSpecialistConfirmation, isFalse);
    });

    test('married donor without children flags missing parentela context', () {
      final result = DonationService.calculate(
        montant: 50000,
        donateurAge: 50,
        lienParente: 'fratrie',
        canton: 'ZH',
        civilStatus: 'marie',
        nbEnfants: 0,
        fortuneTotaleDonateur: 800000,
      );

      expect(result.reserveHereditaireTotale, 300000.0);
      expect(result.quotiteDisponible, 500000.0);
      expect(
        result.alerts,
        contains(DonationMessageCode.alertMissingParentela),
      );
    });

    test('donation beyond disposable portion reports only the excess amount',
        () {
      final result = DonationService.calculate(
        montant: 600000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'ZH',
        civilStatus: 'celibataire',
        nbEnfants: 2,
        fortuneTotaleDonateur: 1000000,
      );

      expect(result.donationDepasseQuotite, isTrue);
      expect(result.montantDepassement, 100000.0);
      expect(result.alerts, contains(DonationMessageCode.alertReductionRisk));
    });
  });

  group('DonationService - succession impact', () {
    test('advancement of inheritance is described as future collation', () {
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        avancementHoirie: true,
      );

      expect(result.impactSuccession, DonationMessageCode.impactAdvancement);
    });

    test('outside advancement stays conditional on deed and reserved shares',
        () {
      final result = DonationService.calculate(
        montant: 50000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'ZH',
        avancementHoirie: false,
        civilStatus: 'celibataire',
        nbEnfants: 0,
        fortuneTotaleDonateur: 500000,
      );

      expect(result.impactSuccession, DonationMessageCode.impactOutsidePart);
    });

    test('outside advancement beyond disposable portion flags reduction risk',
        () {
      final result = DonationService.calculate(
        montant: 600000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'ZH',
        avancementHoirie: false,
        civilStatus: 'celibataire',
        nbEnfants: 2,
        fortuneTotaleDonateur: 1000000,
      );

      expect(result.impactSuccession, DonationMessageCode.impactReductionRisk);
      expect(result.montantDepassement, 100000.0);
    });
  });

  group('DonationService - alerts and compliance', () {
    test('real-estate donation requires notary and land-register checks', () {
      final result = DonationService.calculate(
        montant: 0,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        typeDonation: 'immobilier',
        valeurImmobiliere: 500000,
        soldeHypothecaire: 200000,
      );

      expect(result.montantDonation, 300000.0);
      expect(result.alerts, contains(DonationMessageCode.alertRealEstate));
      expect(
        result.checklist,
        contains(DonationMessageCode.checklistLandRegister),
      );
    });

    test('older donor warning stays about planning, not automatic contestation',
        () {
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 70,
        lienParente: 'descendant',
        canton: 'ZH',
      );

      expect(result.alerts, contains(DonationMessageCode.alertOlderDonor));
      expect(
        result.alerts,
        isNot(contains(DonationMessageCode.alertReductionRisk)),
      );
    });

    test('large donation warns about personal liquidity', () {
      final result = DonationService.calculate(
        montant: 600000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        fortuneTotaleDonateur: 1000000,
      );

      expect(result.alerts, contains(DonationMessageCode.alertLargeDonation));
    });

    test('checklist keeps specialist and tax-authority verification', () {
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
      );

      expect(result.checklist.length, greaterThanOrEqualTo(5));
      expect(
        result.checklist,
        contains(DonationMessageCode.checklistVerifyQuotite),
      );
      expect(
        result.checklist,
        contains(DonationMessageCode.checklistConfirmTax),
      );
    });

    test('sources include official federal/legal references', () {
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
      );

      expect(result.sources, contains('source_ch_gift_tax'));
      expect(result.sources, contains('source_cc_471_2023'));
      expect(result.sources, contains('source_cc_522'));
    });
  });
}
