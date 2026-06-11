import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/life_events_service.dart';

/// Tests du split LPP divorce borné à la part acquise PENDANT le mariage.
///
/// CC art. 122 / LFLP art. 22a : seule la prévoyance acquise pendant le mariage
/// est partagée 50/50 — l'avoir constitué AVANT le mariage est exclu. Splitter
/// l'avoir TOTAL surestime le transfert (finding cadre_divorce_hypo-5).
///
/// Formule cible : acquis_i = max(0, avoirActuel_i − avoirAuMariage_i) ;
///                 transfert = (acquis_1 − acquis_2).abs() / 2 ;
///                 direction = sens du transfert.
void main() {
  // ════════════════════════════════════════════════════════════
  //  SPLIT BORNÉ À LA PART-MARIAGE (CC art. 122 / LFLP art. 22a)
  // ════════════════════════════════════════════════════════════

  group('DivorceService - Split borné part-mariage (CC 122 / LFLP 22a)', () {
    test(
        'avoir pré-mariage exclu : transfert = (acquis1 − acquis2)/2, '
        'plus jamais sur le total', () {
      // avoir1 = 416250 dont 200000 constitués AU mariage → acquis1 = 216250.
      // avoir2 = 80000 dont 0 au mariage → acquis2 = 80000.
      // transfert = (216250 − 80000)/2 = 68125 (et NON |416250−80000|/2 = 168125).
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 12,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 90000,
          incomeConjoint2: 50000,
          lppConjoint1: 416250,
          lppConjoint2: 80000,
          avoirAuMariage1: 200000,
          avoirAuMariage2: 0,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      expect(result.lppSplit.isIncomplete, isFalse,
          reason: 'Les deux avoirs au mariage sont renseignés');
      expect(result.lppSplit.transferAmount, 68125,
          reason: 'Split sur la part acquise pendant le mariage uniquement');
      expect(result.lppSplit.transferAmount, isNot(168125),
          reason: 'Plus jamais |total1−total2|/2');
      // Part acquise pendant le mariage de chaque conjoint = base de partage.
      expect(result.lppSplit.acquisConjoint1, 216250);
      expect(result.lppSplit.acquisConjoint2, 80000);
      // Conjoint 1 a plus d'acquis → transfert 1 → 2.
      expect(result.lppSplit.transferDirection, contains('1'));
      expect(result.lppSplit.transferDirection, contains('2'));
    });

    test(
        'parts acquises pendant le mariage égales → transfert nul', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 80000,
          lppConjoint1: 300000,
          lppConjoint2: 150000,
          // avoir1 acquis pendant mariage = 300000 − 150000 = 150000
          // avoir2 acquis pendant mariage = 150000 − 0      = 150000
          avoirAuMariage1: 150000,
          avoirAuMariage2: 0,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      expect(result.lppSplit.isIncomplete, isFalse);
      expect(result.lppSplit.acquisConjoint1, 150000);
      expect(result.lppSplit.acquisConjoint2, 150000);
      expect(result.lppSplit.transferAmount, 0);
      expect(result.lppSplit.transferDirection, '-');
    });

    test(
        'avoir au mariage > avoir actuel → part acquise bornée à 0 '
        '(jamais négative)', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 5,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 60000,
          lppConjoint1: 100000,
          lppConjoint2: 120000,
          // avoir1 a baissé sous l'avoir au mariage (rachat retiré, etc.)
          avoirAuMariage1: 150000,
          avoirAuMariage2: 40000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      // acquis1 = max(0, 100000 − 150000) = 0 ; acquis2 = max(0, 120000 − 40000) = 80000
      expect(result.lppSplit.acquisConjoint1, 0);
      expect(result.lppSplit.acquisConjoint2, 80000);
      expect(result.lppSplit.transferAmount, 40000);
      expect(result.lppSplit.transferDirection, contains('2'));
    });

    test(
        'avoirAuMariage null (conjoint 1) → résultat marqué incomplet, '
        'pas de split silencieux sur le total', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 10,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 90000,
          incomeConjoint2: 50000,
          lppConjoint1: 300000,
          lppConjoint2: 100000,
          avoirAuMariage1: null,
          avoirAuMariage2: 0,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      expect(result.lppSplit.isIncomplete, isTrue,
          reason: 'Donnée requise — avoir au mariage manquant');
      expect(result.lppSplit.transferAmount, 0,
          reason: 'Aucun montant de transfert certain sans la donnée');
      expect(result.lppSplit.transferDirection, '-');
    });

    test(
        'les deux avoirAuMariage null → résultat incomplet', () {
      final result = DivorceService.simulate(
        input: const DivorceInput(
          marriageDurationYears: 8,
          numberOfChildren: 0,
          regime: MatrimonialRegime.participationAuxAcquets,
          incomeConjoint1: 80000,
          incomeConjoint2: 80000,
          lppConjoint1: 200000,
          lppConjoint2: 200000,
          pillar3aConjoint1: 0,
          pillar3aConjoint2: 0,
          fortuneCommune: 0,
          dettesCommunes: 0,
        ),
      );

      expect(result.lppSplit.isIncomplete, isTrue);
      expect(result.lppSplit.transferAmount, 0);
    });
  });
}
