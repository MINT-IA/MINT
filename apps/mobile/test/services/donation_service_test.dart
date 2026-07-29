import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/donation_service.dart';
import 'package:mint_mobile/services/succession_donation_socle.dart';

/// Unit tests for DonationService — Sprint S24 (Donations)
///
/// Tests pure Dart financial calculations for Swiss donation tax:
///   - Impot sur les donations par canton et lien de parente
///   - Reserve hereditaire (CC art. 471, nouveau droit 2023)
///   - Quotite disponible et depassement
///   - Avancement d'hoirie vs hors avancement
///   - Impact succession
///   - Checklist et alertes
///   - Compliance (disclaimer, sources, premier éclairage)
///
/// Legal references: CC art. 457-471, CC art. 522 ss, CO art. 239 ss
void main() {
  // ════════════════════════════════════════════════════════════
  //  IMPOT SUR LES DONATIONS PAR CANTON
  // ════════════════════════════════════════════════════════════

  group('DonationService - Verdict fiscal (socle ESTV)', () {
    // GOLDENS MIS À JOUR (ADR 2026-07-28 P4) : l'ancienne table Dart
    // tauxDonationCantonal gravait des taux plats non sourcés — LU y
    // figurait taxé alors que Lucerne ne prélève AUCUN impôt sur les
    // donations ; « GE tiers 30 % » contre un barème progressif 24-26 % +
    // centimes ; canton inconnu retombait sur les taux VD. Le service
    // émet désormais un verdict {statut, plage sourcée, mécanismes,
    // bascule, source} — plus de montant × taux.
    test('donation au conjoint = exonérée dans les 26 cantons', () {
      for (final canton in SuccessionDonationSocle.cantons.keys) {
        final result = DonationService.calculate(
          montant: 100000,
          donateurAge: 50,
          lienParente: 'conjoint',
          canton: canton,
        );

        expect(result.verdictFiscal.statut, 'exonere',
            reason: 'Conjoint devrait etre exonere dans $canton');
      }
    });

    test('donation aux descendants = exoneree (ZH, BE, GE, LU, BS, SZ)', () {
      for (final canton in ['ZH', 'BE', 'GE', 'LU', 'BS', 'SZ']) {
        final result = DonationService.calculate(
          montant: 100000,
          donateurAge: 50,
          lienParente: 'descendant',
          canton: canton,
        );

        expect(result.verdictFiscal.statut, 'exonere',
            reason: 'Descendant devrait etre exonere dans $canton');
      }
    });

    test('VD descendant : TAXÉ, franchise donation 300k/an dans les notes',
        () {
      final result = DonationService.calculate(
        montant: 400000,
        donateurAge: 55,
        lienParente: 'descendant',
        canton: 'VD',
      );

      expect(result.verdictFiscal.statut, 'taxe');
      expect(result.verdictFiscal.mecanismes.join(' '), contains('300000'));
    });

    test('donation a un tiers en GE => taxe_lourd, plage sourcée ~26 %', () {
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'GE',
      );

      expect(result.verdictFiscal.statut, 'taxe_lourd');
      expect(result.verdictFiscal.plageMaxPct, 26);
    });

    test('donation a un concubin en VD => taxe_lourd + bascule', () {
      final result = DonationService.calculate(
        montant: 200000,
        donateurAge: 45,
        lienParente: 'concubin',
        canton: 'VD',
      );

      expect(result.verdictFiscal.statut, 'taxe_lourd');
      expect(result.verdictFiscal.bascule, isNotNull);
      expect(result.verdictFiscal.bascule, contains('ariage'));
    });

    test('Lucerne : aucun impôt donation — le service le DIT', () {
      final result = DonationService.calculate(
        montant: 250000,
        donateurAge: 55,
        lienParente: 'fratrie',
        canton: 'LU',
      );

      expect(result.verdictFiscal.statut, 'exonere');
      expect(result.verdictFiscal.mecanismes.join(' '), contains('Lucerne'));
      expect(result.premierEclairage, contains('Lucerne'));
    });

    test('Schwyz (SZ) => exonéré pour tous les liens', () {
      for (final lien in SuccessionDonationSocle.categories) {
        final result = DonationService.calculate(
          montant: 100000,
          donateurAge: 50,
          lienParente: lien,
          canton: 'SZ',
        );

        expect(result.verdictFiscal.statut, 'exonere',
            reason: 'SZ devrait etre exonere pour $lien');
      }
    });

    test('canton inconnu => verdict « inconnu », plus de fallback VD', () {
      final resultUnknown = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'XX',
      );

      expect(resultUnknown.verdictFiscal.statut, 'inconnu');
      expect(resultUnknown.verdictFiscal.plageMaxPct, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  RESERVE HEREDITAIRE ET QUOTITE DISPONIBLE
  // ════════════════════════════════════════════════════════════

  group('DonationService - Reserve hereditaire', () {
    test('avec enfants: reserve with regime matrimonial factor', () {
      final result = DonationService.calculate(
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
      final result = DonationService.calculate(
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
      final result = DonationService.calculate(
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
      expect(result.alerts, anyElement(contains('quotite disponible')));
    });

    test('donation ne depasse pas quotite => pas d\'alerte depassement', () {
      final result = DonationService.calculate(
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
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        avancementHoirie: true,
      );

      expect(result.impactSuccession, contains('avancement d\'hoirie'));
      expect(result.impactSuccession, contains('rapportee'));
    });

    test('hors avancement, dans quotite => imputee sans rapport', () {
      final result = DonationService.calculate(
        montant: 50000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'ZH',
        avancementHoirie: false,
        nbEnfants: 0,
        fortuneTotaleDonateur: 500000,
      );

      expect(result.impactSuccession, contains('hors avancement'));
      expect(result.impactSuccession, contains('quotite disponible'));
    });

    test('hors avancement, depasse quotite => action en reduction possible', () {
      final result = DonationService.calculate(
        montant: 600000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'ZH',
        avancementHoirie: false,
        nbEnfants: 2,
        fortuneTotaleDonateur: 1000000,
      );

      expect(result.impactSuccession, contains('action en reduction'));
      expect(result.impactSuccession, contains('CC art. 522'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  ALERTES SPECIFIQUES
  // ════════════════════════════════════════════════════════════

  group('DonationService - Alertes', () {
    test('concubin taxé => alerte avec bascule, sans chiffre plat', () {
      // GOLDEN MIS À JOUR : l'alerte citait « 25% » plat ; elle garde son
      // message, perd le chiffre, gagne la bascule mariage/pacte.
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'concubin',
        canton: 'VD',
      );

      expect(result.alerts, anyElement(contains('concubin')));
      expect(result.alerts, anyElement(contains('ariage')));
      expect(result.alerts, isNot(anyElement(contains('25%'))));
    });

    test('donation immobiliere => alerte notaire obligatoire', () {
      final result = DonationService.calculate(
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
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 70,
        lienParente: 'descendant',
        canton: 'ZH',
      );

      expect(result.alerts, anyElement(contains('CC art. 527')));
    });

    test('donation > 50% fortune => alerte reserves personnelles', () {
      final result = DonationService.calculate(
        montant: 600000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        fortuneTotaleDonateur: 1000000,
      );

      expect(result.alerts, anyElement(contains('50%')));
      expect(result.alerts, anyElement(contains('fortune totale')));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CHECKLIST ET COMPLIANCE
  // ════════════════════════════════════════════════════════════

  group('DonationService - Checklist et compliance', () {
    test('checklist de base contient au moins 5 elements', () {
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
      );

      expect(result.checklist.length, greaterThanOrEqualTo(5));
      expect(result.checklist, anyElement(contains('notaire')));
      expect(result.checklist, anyElement(contains('autorites fiscales')));
    });

    test('donation immobiliere ajoute registre foncier a la checklist', () {
      final result = DonationService.calculate(
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
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
        avancementHoirie: true,
      );

      expect(result.checklist, anyElement(contains('rapport successoral')));
    });

    test('concubin ajoute conseil testament', () {
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'concubin',
        canton: 'ZH',
      );

      expect(result.checklist, anyElement(contains('testament')));
    });

    test('disclaimer mentionne outil educatif et LSFin', () {
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
      );

      expect(result.disclaimer, contains('outil educatif'));
      expect(result.disclaimer, contains('LSFin'));
    });

    test('sources contiennent les references CC', () {
      final result = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'descendant',
        canton: 'ZH',
      );

      expect(result.sources, isNotEmpty);
      expect(result.sources, anyElement(contains('CC art. 471')));
      expect(result.sources, anyElement(contains('CC art. 522')));
    });

    test('premier éclairage : verdict directionnel, jamais impot × taux',
        () {
      // GOLDEN MIS À JOUR : « Impot : CHF X (Y%) » était calculé sur un
      // taux plat non sourcé — remplacé par le verdict + plage sourcée.
      // Cas exonere
      final resultExonere = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'conjoint',
        canton: 'ZH',
      );
      expect(resultExonere.premierEclairage, contains('exon'));

      // Cas impose
      final resultImpose = DonationService.calculate(
        montant: 100000,
        donateurAge: 50,
        lienParente: 'tiers',
        canton: 'GE',
      );
      expect(resultImpose.premierEclairage.toLowerCase(),
          contains('imposable'));
      expect(resultImpose.premierEclairage, contains('~26'));
    });
  });
}
