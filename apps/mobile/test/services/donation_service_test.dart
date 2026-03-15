import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/services/donation_service.dart';

/// Unit tests for DonationService — Sprint S24 (Donations)
///
/// Tests pure Dart financial calculations for Swiss donation tax:
///   - Impot sur les donations par canton et lien de parente
///   - Reserve hereditaire (CC art. 471, nouveau droit 2023)
///   - Quotite disponible et depassement
///   - Avancement d'hoirie vs hors avancement
///   - Impact succession
///   - Checklist et alertes
///   - Compliance (disclaimer, sources, chiffre choc)
///
/// Legal references: CC art. 457-471, CC art. 522 ss, CO art. 239 ss
void main() {
  final S _s = SFr();
  // ════════════════════════════════════════════════════════════
  //  IMPOT SUR LES DONATIONS PAR CANTON
  // ════════════════════════════════════════════════════════════

  group('DonationService - Impot cantonal', () {
    test('donation au conjoint = exoneree dans tous les cantons', () {
      for (final canton in DonationService.tauxDonationCantonal.keys) {
        final result = DonationService.calculate(s: _s,
          montant: 100000,
          donateurAge: 50,
          lienParente: 'conjoint',
          canton: canton,
        );

        expect(result.tauxImposition, 0.0,
            reason: 'Conjoint devrait etre exonere dans $canton');
        expect(result.impotDonation, 0.0);
      }
    });

    test('donation aux descendants = exoneree (ZH, BE, GE, LU, BS, SZ)', () {
      for (final canton in ['ZH', 'BE', 'GE', 'LU', 'BS', 'SZ']) {
        final result = DonationService.calculate(s: _s,
          montant: 100000,
          donateurAge: 50,
          lienParente: 'descendant',
          canton: canton,
        );

        expect(result.tauxImposition, 0.0,
            reason: 'Descendant devrait etre exonere dans $canton');
        expect(result.impotDonation, 0.0);
      }
    });

    test('donation a un tiers en GE => taux 30%', () {
      final result = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'GE',
      );

      expect(result.tauxImposition, 0.30);
      expect(result.impotDonation, 30000.0);
    });

    test('donation a un concubin en VD => taux 25%', () {
      final result = DonationService.calculate(s: _s,
        montant: 200000,
        donateurAge: 45,
        lienParente: 'concubin',
        canton: 'VD',
      );

      expect(result.tauxImposition, 0.25);
      expect(result.impotDonation, 50000.0);
    });

    test('Schwyz (SZ) => taux 0% pour tous les liens', () {
      for (final lien in DonationService.tauxDonationCantonal['SZ']!.keys) {
        final result = DonationService.calculate(s: _s,
          montant: 100000,
          donateurAge: 50,
          lienParente: lien,
          canton: 'SZ',
        );

        expect(result.tauxImposition, 0.0,
            reason: 'SZ devrait etre a 0% pour $lien');
        expect(result.impotDonation, 0.0);
      }
    });

    test('canton inconnu => fallback sur VD', () {
      final resultUnknown = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'XX',
      );

      final resultVD = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'VD',
      );

      expect(resultUnknown.tauxImposition, resultVD.tauxImposition);
      expect(resultUnknown.impotDonation, resultVD.impotDonation);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  RESERVE HEREDITAIRE ET QUOTITE DISPONIBLE
  // ════════════════════════════════════════════════════════════

  group('DonationService - Reserve hereditaire', () {
    test('avec enfants: reserve with regime matrimonial factor', () {
      final result = DonationService.calculate(s: _s,
        montant: 50000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        nbEnfants: 2,
        fortuneTotaleDonateur: 1000000,
      );

      // Default regime = participation_acquets => regimeFactor = 0.75
      // fortune = 1000000 * 0.75 = 750000
      // conjoint: 750000 * 0.50 * 0.50 = 187500
      // enfants:  750000 * 0.50 * 0.50 = 187500
      // total reserve = 375000
      expect(result.reserveHereditaireTotale, 375000.0);
      expect(result.quotiteDisponible, 375000.0);
    });

    test('sans enfants: reserve with regime matrimonial factor', () {
      final result = DonationService.calculate(s: _s,
        montant: 50000,
        donateurAge: 50,
        lienParente: 'fratrie',
        canton: 'ZH',
        nbEnfants: 0,
        fortuneTotaleDonateur: 800000,
      );

      // Default regime = participation_acquets => regimeFactor = 0.75
      // fortune = 800000 * 0.75 = 600000
      // conjoint: 600000 * 0.75 * 0.50 = 225000
      // parents: no reserve since 2023
      expect(result.reserveHereditaireTotale, 225000.0);
      expect(result.quotiteDisponible, 375000.0);
    });

    test('nouveau droit 2023: parents n\'ont plus de reserve', () {
      // Verify that reserves['parent'] is 0.0
      expect(DonationService.reserves['parent'], 0.0);
    });

    test('donation depasse quotite disponible => alerte', () {
      final result = DonationService.calculate(s: _s,
        montant: 600000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'ZH',
        nbEnfants: 2,
        fortuneTotaleDonateur: 1000000,
      );

      // fortune = 1000000 * 0.75 = 750000, reserve = 375000, quotite = 375000
      // donation = 600000 > 375000 => depasse de 225000
      expect(result.donationDepasseQuotite, isTrue);
      expect(result.montantDepassement, 225000.0);
      expect(result.alerts, anyElement(contains('quotité disponible')));
    });

    test('donation ne depasse pas quotite => pas d\'alerte depassement', () {
      final result = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        nbEnfants: 2,
        fortuneTotaleDonateur: 1000000,
      );

      expect(result.donationDepasseQuotite, isFalse);
      expect(result.montantDepassement, 0.0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  IMPACT SUCCESSION (AVANCEMENT HOIRIE)
  // ════════════════════════════════════════════════════════════

  group('DonationService - Impact succession', () {
    test('avancement hoirie => rapportee a la masse successorale', () {
      final result = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        avancementHoirie: true,
      );

      expect(result.impactSuccession, contains('avancement'));
      expect(result.impactSuccession, contains('hoirie'));
    });

    test('hors avancement, dans quotite => imputee sans rapport', () {
      final result = DonationService.calculate(s: _s,
        montant: 50000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'ZH',
        avancementHoirie: false,
        nbEnfants: 0,
        fortuneTotaleDonateur: 500000,
      );

      expect(result.impactSuccession, contains('hors avancement'));
      expect(result.impactSuccession, contains('quotité disponible'));
    });

    test('hors avancement, depasse quotite => action en reduction possible', () {
      final result = DonationService.calculate(s: _s,
        montant: 600000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'ZH',
        avancementHoirie: false,
        nbEnfants: 2,
        fortuneTotaleDonateur: 1000000,
      );

      expect(result.impactSuccession, contains('action en réduction'));
      expect(result.impactSuccession, contains('CC art. 522'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  ALERTES SPECIFIQUES
  // ════════════════════════════════════════════════════════════

  group('DonationService - Alertes', () {
    test('concubin avec taux > 15% => alerte taux eleve', () {
      final result = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'concubin',
        canton: 'VD', // 25%
      );

      expect(result.alerts,
          anyElement(contains("taux d")));
    });

    test('donation immobiliere => alerte notaire obligatoire', () {
      final result = DonationService.calculate(s: _s,
        montant: 0,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        typeDonation: 'immobilier',
        valeurImmobiliere: 500000,
      );

      expect(result.montantDonation, 500000.0);
      expect(result.alerts, anyElement(contains('notaire est obligatoire')));
    });

    test('donateur >= 70 ans => alerte contestation', () {
      final result = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 70,
        lienParente: 'descendant',
        canton: 'ZH',
      );

      expect(result.alerts, anyElement(contains('CC art. 527')));
    });

    test('donation > 50% fortune => alerte reserves personnelles', () {
      final result = DonationService.calculate(s: _s,
        montant: 600000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        fortuneTotaleDonateur: 1000000,
      );

      expect(result.alerts, anyElement(contains('50')));
      expect(result.alerts, anyElement(contains('fortune')));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CHECKLIST ET COMPLIANCE
  // ════════════════════════════════════════════════════════════

  group('DonationService - Checklist et compliance', () {
    test('checklist de base contient au moins 5 elements', () {
      final result = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
      );

      expect(result.checklist.length, greaterThanOrEqualTo(5));
      expect(result.checklist, anyElement(contains('notaire')));
      expect(result.checklist, anyElement(contains('autorités fiscales')));
    });

    test('donation immobiliere ajoute registre foncier a la checklist', () {
      final result = DonationService.calculate(s: _s,
        montant: 0,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        typeDonation: 'immobilier',
        valeurImmobiliere: 500000,
      );

      expect(result.checklist, anyElement(contains('registre foncier')));
    });

    test('avancement hoirie ajoute documentation rapport successoral', () {
      final result = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        avancementHoirie: true,
      );

      expect(result.checklist, anyElement(contains('rapport successoral')));
    });

    test('concubin ajoute conseil testament', () {
      final result = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'concubin',
        canton: 'ZH',
      );

      expect(result.checklist, anyElement(contains('testament')));
    });

    test('disclaimer mentionne outil educatif et LSFin', () {
      final result = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
      );

      expect(result.disclaimer, contains('outil éducatif'));
      expect(result.disclaimer, contains('LSFin'));
    });

    test('sources contiennent les references CC', () {
      final result = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
      );

      expect(result.sources, isNotEmpty);
      expect(result.sources, anyElement(contains('CC art. 471')));
      expect(result.sources, anyElement(contains('CC art. 522')));
    });

    test('chiffre choc mentionne impot ou exoneration', () {
      // Cas exonere
      final resultExonere = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'conjoint',
        canton: 'ZH',
      );
      expect(resultExonere.chiffreChoc, contains('exonérée'));

      // Cas impose
      final resultImpose = DonationService.calculate(s: _s,
        montant: 100000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'GE',
      );
      expect(resultImpose.chiffreChoc, contains('Impôt'));
    });
  });
}
