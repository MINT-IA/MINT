import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/fiscal_service.dart';

/// beads MINT_nosync-9f8 — le top cantons expat doit venir du CALCUL RÉEL
/// (FiscalService), plus jamais d'un classement fabriqué (rangs SZ/ZG/NW/UR/AI
/// hardcodés, économies linéaires 8500*scale, « Source : AFC » inventée).
///
/// On verrouille ici les propriétés du classement réel que l'écran consomme.
void main() {
  group('Classement cantonal réel (anti-façade T05-F41)', () {
    test('l\'écart vs canton actuel vient des charges réelles du modèle', () {
      const income = 200000.0;
      final chargeGE = (FiscalService.estimateTax(
        revenuBrut: income,
        canton: 'GE',
      )['chargeTotale'] as double);
      final chargeZG = (FiscalService.estimateTax(
        revenuBrut: income,
        canton: 'ZG',
      )['chargeTotale'] as double);
      // GE est plus imposé que ZG dans le modèle — l'écart est positif et
      // N'EST PAS une fonction linéaire inventée du revenu.
      expect(chargeGE - chargeZG, greaterThan(0));
      expect(chargeGE - chargeZG, isNot(closeTo(8500 * (income / 100000), 1)));
    });

    test('compareAllCantons classe 26 cantons par charge croissante', () {
      final all = FiscalService.compareAllCantons(revenuBrut: 150000);
      expect(all.length, 26);
      for (var i = 1; i < all.length; i++) {
        expect(
          all[i]['chargeTotale'] as double,
          greaterThanOrEqualTo(all[i - 1]['chargeTotale'] as double),
        );
      }
    });

    test('canton le moins imposé -> aucun écart favorable (empty honnête)', () {
      final all = FiscalService.compareAllCantons(revenuBrut: 150000);
      final cheapest = all.first['canton'] as String;
      final chargeCheapest = all.first['chargeTotale'] as double;
      final favorable = all
          .where((m) => m['canton'] != cheapest)
          .where((m) => chargeCheapest - (m['chargeTotale'] as double) > 0);
      expect(favorable, isEmpty);
    });
  });
}
