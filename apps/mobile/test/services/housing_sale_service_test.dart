import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/housing_sale_service.dart';

/// Unit tests for HousingSaleService — Sprint S24 (Vente immobiliere).
///
/// L'impot sur les gains immobiliers est desormais delegue au modele calibre
/// (mirror de fiscal.gains_immobiliers_calibres, ADR 2026-07-28 P5). Les
/// anciennes assertions gravees sur la table fabriquee (taux par duree,
/// exoneration 0 % apres 20-25 ans) etaient fausses : elles sont remplacees par
/// des assertions etalon (rejeu des vecteurs officiels ZH, bareme VD/GE, statut
/// mecanisme / inconnu pour les cantons non calibres).

/// Charge l'archive de sources primaires (parite archive <-> dart).
Map<String, dynamic> _loadArchive() {
  const rel =
      '.planning/audit-etat-des-lieux-2026-07/constants-audit/gains_immobiliers_2026/extraction.json';
  for (final base in ['../..', '../../..', '.']) {
    final f = File('$base/$rel');
    if (f.existsSync()) {
      return jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    }
  }
  fail('archive extraction.json introuvable depuis ${Directory.current.path}');
}

void main() {
  // ════════════════════════════════════════════════════════════
  //  PARITE archive <-> dart (champ par champ)
  // ════════════════════════════════════════════════════════════

  group('Gains immobiliers - parite archive', () {
    final archive = _loadArchive();

    test('ZH franchise + tranches', () {
      expect(kFranchiseZh, (archive['ZH']['franchise_chf'] as num).toDouble());
      final tranches = archive['ZH']['tranches_par_gain'] as List;
      expect(kTranchesZh.length, tranches.length);
      for (var i = 0; i < tranches.length; i++) {
        final entry = tranches[i] as Map<String, dynamic>;
        final portion = entry['portion_chf'];
        expect(kTranchesZh[i].$1, portion == null ? null : (portion as num).toDouble());
        expect(kTranchesZh[i].$2, (entry['taux'] as num).toDouble());
      }
    });

    test('ZH majoration + rabais', () {
      final maj = archive['ZH']['majoration_courte_duree'];
      expect(kMajorationZhMoins1An, (maj['moins_de_1_an'] as num).toDouble());
      expect(kMajorationZhMoins2Ans, (maj['moins_de_2_ans'] as num).toDouble());
      final rab = archive['ZH']['rabais_longue_duree'];
      expect(kRabaisZhPlafond, (rab['plafond'] as num).toDouble());
      final table = rab['table_annees_pleines'] as Map<String, dynamic>;
      expect(kRabaisZhTable.length, table.length);
      table.forEach((k, v) {
        expect(kRabaisZhTable[int.parse(k)], (v as num).toDouble());
      });
    });

    test('VD bareme', () {
      final bareme = archive['VD']['bareme_par_annees_de_possession'] as List;
      expect(kBaremeVd.length, bareme.length);
      for (var i = 0; i < bareme.length; i++) {
        final e = bareme[i] as Map<String, dynamic>;
        expect(kBaremeVd[i].$1, e['de']);
        expect(kBaremeVd[i].$2, e['a_exclu']);
        expect(kBaremeVd[i].$3, (e['taux'] as num).toDouble());
      }
    });

    test('GE bareme', () {
      final bareme = archive['GE']['bareme_par_annees_de_possession'] as List;
      expect(kBaremeGe.length, bareme.length);
      for (var i = 0; i < bareme.length; i++) {
        final e = bareme[i] as Map<String, dynamic>;
        expect(kBaremeGe[i].$1, e['de']);
        expect(kBaremeGe[i].$2, e['a_exclu']);
        expect(kBaremeGe[i].$3, (e['taux'] as num).toDouble());
      }
    });

    test('rejeu des 4 vecteurs officiels ZH (tableau B)', () {
      final vecteurs = archive['ZH']['vecteurs_officiels_tableau_B'] as List;
      for (final v in vecteurs) {
        final gain = (v['gewinn_chf'] as num).toDouble();
        final attendu = (v['steuer_chf'] as num).toDouble();
        expect(impotBaseZh(gain), attendu, reason: 'ZH tableau B gain $gain');
      }
    });
  });

  // ════════════════════════════════════════════════════════════
  //  MODELE CALIBRE — vecteurs geles + cas cibles
  // ════════════════════════════════════════════════════════════

  group('Modele calibre - ZH', () {
    test('vecteurs geles (impot de base)', () {
      expect(impotBaseZh(5000), 550);
      expect(impotBaseZh(25000), 4650);
      expect(impotBaseZh(50000), 11900);
      expect(impotBaseZh(64900), 17115);
    });

    test('franchise : gain < 5000 => 0', () {
      expect(impotZh(4999, 3), 0.0);
    });

    test('majoration < 1 an : 5000 => 825', () {
      expect(impotZh(5000, 0), 825.0);
    });

    test('rabais 20 ans : x 0.5', () {
      expect(impotZh(25000, 20), impotBaseZh(25000) * 0.5);
    });
  });

  group('Modele calibre - VD', () {
    test('double comptage occupation : 8 possede + 8 occupe => duree 16 => 11 %', () {
      expect(dureeEffectiveVd(8, 8), 16);
      expect(tauxVd(16), 0.11);
    });

    test('bornes 0 / 24+', () {
      expect(tauxVd(0), 0.30);
      expect(tauxVd(24), 0.07);
      expect(tauxVd(40), 0.07);
    });
  });

  group('Modele calibre - GE', () {
    test('24 ans => 10 %, 25 ans => 2 % (revision 2025)', () {
      expect(tauxGe(24), 0.10);
      expect(tauxGe(25), 0.02);
    });
  });

  group('Verdict dispatcher', () {
    test('BE => mecanisme, impot null', () {
      final v = verdictGainImmobilier('BE', 100000, 5);
      expect(v.modele, 'mecanisme');
      expect(v.impotChf, isNull);
    });

    test('canton inconnu => inconnu, impot null', () {
      final v = verdictGainImmobilier('XX', 100000, 5);
      expect(v.modele, 'inconnu');
      expect(v.impotChf, isNull);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  HOUSING SALE — plus-value et impot
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - Plus-value et impot', () {
    test('plus-value brute = prix vente - prix achat - investissements - frais', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        investissementsValorisants: 50000,
        fraisAcquisition: 10000,
        canton: 'ZH',
      );
      // 700000 - 500000 - 50000 - 10000 = 140000
      expect(result.plusValueBrute, 140000.0);
    });

    test('Zurich: detention 10 ans => tarif progressif calibre (jamais un taux plat)', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );
      // imposable 200k, duree 10 -> impotZh (base × rabais 20 %)
      expect(result.dureeDetention, 10);
      expect(result.modeleGain, 'calibre');
      expect(result.impotPlusValue, impotZh(200000, 10));
      expect(result.impotPlusValue, 55520.0);
    });

    test('Zurich: detention < 2 ans => majoration de courte duree', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 600000,
        anneeAchat: 2024,
        anneeVente: 2025,
        canton: 'ZH',
      );
      expect(result.dureeDetention, 1);
      // imposable 100k, duree 1 -> base(100k) × 1.25
      expect(result.impotPlusValue, impotZh(100000, 1));
    });

    test('Zurich: detention >= 20 ans => rabais plafonne 50 %, jamais 0', () {
      final result = HousingSaleService.calculate(
        prixAchat: 300000,
        prixVente: 700000,
        anneeAchat: 2000,
        anneeVente: 2025,
        canton: 'ZH',
      );
      expect(result.dureeDetention, 25);
      expect(result.impotPlusValue, impotZh(400000, 25));
      expect(result.impotPlusValue! > 0, isTrue);
    });

    test('Vaud: detention 24+ ans => 7 %', () {
      final result = HousingSaleService.calculate(
        prixAchat: 300000,
        prixVente: 700000,
        anneeAchat: 1995,
        anneeVente: 2025,
        canton: 'VD',
      );
      expect(result.dureeDetention, 30);
      expect(result.tauxImpositionPlusValue, closeTo(0.07, 1e-9));
    });

    test('Vaud: impot = imposable * taux du bareme', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2018,
        anneeVente: 2025,
        canton: 'VD',
      );
      // imposable 200k, VD 7 ans -> 16 %
      expect(result.impotPlusValue, closeTo(200000 * tauxVd(7), 0.01));
    });

    test('Vaud: double comptage de l\'occupation personnelle', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2017,
        anneeVente: 2025, // 8 ans possede
        canton: 'VD',
        anneesOccupation: 8,
      );
      // duree effective 16 -> 11 %
      expect(result.tauxImpositionPlusValue, closeTo(0.11, 1e-9));
    });

    test('vente a perte => plus-value imposable = 0, pas d\'impot', () {
      final result = HousingSaleService.calculate(
        prixAchat: 700000,
        prixVente: 600000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );
      expect(result.plusValueBrute, -100000.0);
      expect(result.plusValueImposable, 0.0);
      expect(result.impotPlusValue, 0.0);
    });

    test('canton inconnu => aucun impot fabrique (pas de fallback)', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2020,
        anneeVente: 2025,
        canton: 'XX',
      );
      expect(result.modeleGain, 'inconnu');
      expect(result.impotPlusValue, isNull);
      expect(result.tauxImpositionPlusValue, isNull);
      expect(result.produitNet, isNull);
    });

    test('canton mecanisme (BE) => impot null + renvoi', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'BE',
      );
      expect(result.modeleGain, 'mecanisme');
      expect(result.impotPlusValue, isNull);
      expect(result.produitNet, isNull);
      expect(result.alerts, anyElement(contains('Berne')));
    });

    test('perte dans un canton non calibre (BE) => impot 0, produit net calcule', () {
      // F4 : gain <= 0 -> impot 0 deterministe, produit net non nullifie.
      final result = HousingSaleService.calculate(
        prixAchat: 800000,
        prixVente: 600000,
        anneeAchat: 2020,
        anneeVente: 2025,
        canton: 'BE',
        hypothequeRestante: 500000,
      );
      expect(result.modeleGain, 'mecanisme');
      expect(result.impotPlusValue, 0.0);
      expect(result.produitNet, 100000.0); // 600k - 500k
      expect(result.alerts, isNot(anyElement(contains('Berne'))));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  REMPLOI (report d'imposition sur l'impot)
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - Remploi', () {
    test('remploi total: prix remploi >= prix vente => impot differe complet', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        projetRemploi: true,
        prixRemploi: 800000,
      );
      expect(result.remploiReport, result.impotPlusValue);
      expect(result.impotEffectif, 0.0);
    });

    test('remploi partiel: methode absolue ATF 130 II 202 (20 %, pas 60 %)', () {
      // Achat 500k, vente 1M (gain 500k), remploi 600k -> gain reinvesti
      // 100k sur 500k -> 20 % de l'impot reporte.
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 1000000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        prixRemploi: 600000,
        projetRemploi: true,
      );
      expect(result.remploiReport, closeTo(result.impotPlusValue! * 0.20, 0.01));
      expect(result.impotEffectif, closeTo(result.impotPlusValue! * 0.80, 0.01));
    });

    test('remploi du capital seul ne defere rien (correction TF)', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 1000000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        prixRemploi: 500000, // = couts d'investissement -> gain reinvesti 0
        projetRemploi: true,
      );
      expect(result.remploiReport, 0.0);
      expect(result.impotEffectif, result.impotPlusValue);
    });

    test('remploi impossible si pas residence principale', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: false,
        projetRemploi: true,
        prixRemploi: 800000,
      );
      expect(result.remploiReport, 0.0);
      expect(result.impotEffectif, result.impotPlusValue);
    });

    test('pas de remploi sans projetRemploi', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        projetRemploi: false,
      );
      expect(result.remploiReport, 0.0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  REMBOURSEMENT EPL
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - EPL', () {
    test('EPL LPP et 3a rembourses si residence principale', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        eplLppUtilise: 50000,
        epl3aUtilise: 20000,
      );
      expect(result.remboursementEplLpp, 50000.0);
      expect(result.remboursementEpl3a, 20000.0);
    });

    test('EPL pas rembourse si pas residence principale', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: false,
        eplLppUtilise: 50000,
        epl3aUtilise: 20000,
      );
      expect(result.remboursementEplLpp, 0.0);
      expect(result.remboursementEpl3a, 0.0);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  PRODUIT NET
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - Produit net', () {
    test('produit net = prix vente - hypotheque - impot - EPL', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        eplLppUtilise: 50000,
        epl3aUtilise: 20000,
        hypothequeRestante: 300000,
      );
      final expectedNet =
          700000.0 - 300000.0 - result.impotEffectif! - 50000.0 - 20000.0;
      expect(result.produitNet, closeTo(expectedNet, 0.01));
    });

    test('produit net negatif => alerte', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 520000,
        anneeAchat: 2024,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        eplLppUtilise: 50000,
        epl3aUtilise: 20000,
        hypothequeRestante: 480000,
      );
      expect(result.produitNet! < 0, isTrue);
      expect(result.alerts, anyElement(contains('produit net est négatif')));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  ALERTES
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - Alertes', () {
    test('vente a perte => alerte moins-value', () {
      final result = HousingSaleService.calculate(
        prixAchat: 700000,
        prixVente: 600000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );
      expect(result.alerts, anyElement(contains('perte')));
    });

    test('detention < 2 ans => alerte speculative', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 600000,
        anneeAchat: 2024,
        anneeVente: 2025,
        canton: 'ZH',
      );
      expect(result.alerts, anyElement(contains('spéculative')));
    });

    test('EPL utilise => alerte obligation de remboursement', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        eplLppUtilise: 50000,
      );
      expect(result.alerts, anyElement(contains('LPP art. 30d')));
    });

    test('remploi sur non-residence principale => alerte', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: false,
        projetRemploi: true,
        prixRemploi: 800000,
      );
      expect(result.alerts, anyElement(contains('résidence principale')));
    });

    test('hypotheque > 80% prix vente => alerte', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 600000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        hypothequeRestante: 500000,
      );
      expect(result.alerts, anyElement(contains('80%')));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  CHECKLIST ET COMPLIANCE
  // ════════════════════════════════════════════════════════════

  group('HousingSaleService - Checklist et compliance', () {
    test('checklist de base contient au moins 5 elements', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );
      expect(result.checklist.length, greaterThanOrEqualTo(5));
      expect(result.checklist, anyElement(contains('estimation immobilière')));
      expect(result.checklist, anyElement(contains('notaire')));
    });

    test('projet remploi ajoute element checklist', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        projetRemploi: true,
        prixRemploi: 800000,
      );
      expect(result.checklist, anyElement(contains('remploi')));
    });

    test('EPL LPP utilise ajoute element checklist', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        eplLppUtilise: 50000,
      );
      expect(result.checklist, anyElement(contains('EPL LPP')));
    });

    test('EPL 3a utilise ajoute element checklist', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
        residencePrincipale: true,
        epl3aUtilise: 20000,
      );
      expect(result.checklist, anyElement(contains('EPL 3a')));
    });

    test('disclaimer mentionne outil educatif et LSFin', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );
      expect(result.disclaimer, contains('outil educatif'));
      expect(result.disclaimer, contains('LSFin'));
    });

    test('sources contiennent LHID et LPP', () {
      final result = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );
      expect(result.sources, isNotEmpty);
      expect(result.sources, anyElement(contains('LHID art. 12')));
      expect(result.sources, anyElement(contains('LPP art. 30d')));
    });

    test('premier éclairage positif ou negatif selon produit net', () {
      final resultPositif = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 700000,
        anneeAchat: 2015,
        anneeVente: 2025,
        canton: 'ZH',
      );
      expect(resultPositif.premierEclairage, contains('Produit net'));

      final resultNegatif = HousingSaleService.calculate(
        prixAchat: 500000,
        prixVente: 520000,
        anneeAchat: 2024,
        anneeVente: 2025,
        canton: 'ZH',
        hypothequeRestante: 480000,
        eplLppUtilise: 50000,
        epl3aUtilise: 20000,
        residencePrincipale: true,
      );
      expect(resultNegatif.premierEclairage, contains('negatif'));
    });
  });
}
