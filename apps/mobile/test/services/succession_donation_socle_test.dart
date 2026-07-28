// Tests du mini-socle succession/donation Dart (ADR 2026-07-28 P4).
//
// Miroir du socle backend services/backend/app/services/fiscal/
// succession_donation_socle.py : verdicts directionnels par canton ×
// catégorie, plage UNIQUEMENT si la source la donne, bascule concubin.
// Parité verrouillée sur l'archive ESTV 1.1.2025
// (.planning/audit-etat-des-lieux-2026-07/constants-audit/
// succession_donation_2025/socle_extraction.json).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/succession_donation_socle.dart';

const _categories = [
  'conjoint',
  'descendant',
  'parent',
  'fratrie',
  'concubin',
  'tiers',
];

Map<String, dynamic> _loadArchive() {
  // flutter test tourne depuis apps/mobile -> racine du dépôt à ../../.
  final file = File(
    '../../.planning/audit-etat-des-lieux-2026-07/constants-audit/'
    'succession_donation_2025/socle_extraction.json',
  );
  return json.decode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('Parité mini-socle Dart ↔ archive ESTV', () {
    // Patron test_parite_table_archive (test_expat.py) : sans ce test, une
    // coquille dans les littéraux Dart shipperait verte et le refresh
    // annuel ESTV n'aurait pas de point d'update mécanique.
    test('26 cantons, cellule par cellule', () {
      final arch = _loadArchive();
      final cantonsArch = arch['cantons'] as Map<String, dynamic>;
      expect(SuccessionDonationSocle.cantons.keys.toSet(),
          cantonsArch.keys.toSet());
      expect(SuccessionDonationSocle.cantons.length, 26);

      for (final entry in cantonsArch.entries) {
        final code = entry.key;
        final archData = entry.value as Map<String, dynamic>;
        final mini = SuccessionDonationSocle.cantons[code]!;

        expect(mini['succession'], archData['succession'],
            reason: '$code.succession');
        expect(mini['donation'], archData['donation'],
            reason: '$code.donation');
        expect(mini['maxEffectifTiersPct'], archData['max_effectif_tiers_pct'],
            reason: '$code.maxEffectifTiersPct');
        expect(mini['maxEffectifTiersNote'], archData['max_effectif_tiers_note'],
            reason: '$code.maxEffectifTiersNote');

        final archCats = archData['categories'] as Map<String, dynamic>?;
        final statuts = mini['statuts'] as Map<String, String>?;
        final franchises = mini['franchises'] as Map<String, num>?;
        final notes = mini['notes'] as Map<String, String?>?;
        if (archCats == null) {
          expect(statuts, isNull, reason: '$code.statuts');
          expect(franchises, isNull, reason: '$code.franchises');
          expect(notes, isNull, reason: '$code.notes');
          continue;
        }
        for (final cat in _categories) {
          final archCat = archCats[cat] as Map<String, dynamic>;
          expect(statuts![cat], archCat['statut'], reason: '$code.$cat.statut');
          expect(franchises?[cat], archCat['franchise'],
              reason: '$code.$cat.franchise');
          expect(notes![cat], archCat['note'], reason: '$code.$cat.note');
        }
        expect(mini['concubinExonerationConditionnelle'],
            (archCats['concubin'] as Map<String, dynamic>)[
                'exoneration_conditionnelle'],
            reason: '$code.concubinExonerationConditionnelle');
      }
    });

    test('source citée : ESTV 2025', () {
      expect(SuccessionDonationSocle.source, contains('ESTV'));
      expect(SuccessionDonationSocle.source, contains('2025'));
    });
  });

  group('Verdicts — faits durs de l\'ADR', () {
    test('conjoint exonéré 26/26 (seule généralisation qui tient)', () {
      for (final canton in SuccessionDonationSocle.cantons.keys) {
        final v = SuccessionDonationSocle.verdict(
          canton: canton,
          categorie: 'conjoint',
        );
        expect(v.statut, 'exonere', reason: canton);
      }
    });

    test('VD descendant : statut taxe + franchise 1M dans les mécanismes',
        () {
      // GOLDEN CORRIGÉ : l'ancienne table Dart _successionTaxRates donnait
      // VD enfant 0.0 (« exempt ») — la ligne directe y est TAXÉE, avec
      // une déduction de 1'000'000 par souche (socle ESTV).
      final v = SuccessionDonationSocle.verdict(
        canton: 'VD',
        categorie: 'descendant',
      );
      expect(v.statut, 'taxe');
      expect(v.plageMaxPct, isNull); // pas de plage catégorielle sourcée
      expect(v.mecanismes.join(' '), contains('1000000'));
    });

    test('BE tiers : plage sourcée ~40 %', () {
      final v = SuccessionDonationSocle.verdict(
        canton: 'BE',
        categorie: 'tiers',
      );
      expect(v.statut, 'taxe_lourd');
      expect(v.plageMaxPct, 40);
    });

    test('ZH concubin : bascule mariage/pacte + franchise 50k ≥5 ans', () {
      // übrige ×6 = la classe au tarif maximal (même multiplicateur que
      // tiers) → taxe_lourd avec plage 42 % (arbitrage swiss-brain
      // 2026-07-28, P3 revue adversariale).
      final v = SuccessionDonationSocle.verdict(
        canton: 'ZH',
        categorie: 'concubin',
      );
      expect(v.statut, 'taxe_lourd');
      expect(v.plageMaxPct, 42);
      expect(v.bascule, isNotNull);
      expect(v.bascule, contains('ariage'));
      expect(v.bascule, contains('50000'));
      expect(v.bascule, contains('5 ans'));
    });

    test('BE concubin : x6 qualifiant < x16 tiers — pas de plage tiers', () {
      final v = SuccessionDonationSocle.verdict(
        canton: 'BE',
        categorie: 'concubin',
      );
      expect(v.statut, 'taxe');
      expect(v.plageMaxPct, isNull);
    });

    test('GR/ZG concubin : exonération inconditionnelle, AUCUNE bascule', () {
      // Revue adversariale #1087 P2 : la bascule était posée
      // inconditionnellement — la source ne documente aucune condition.
      for (final canton in ['GR', 'ZG']) {
        final v = SuccessionDonationSocle.verdict(
          canton: canton,
          categorie: 'concubin',
        );
        expect(v.statut, 'exonere', reason: canton);
        expect(v.bascule, isNull, reason: '$canton: ${v.bascule}');
      }
    });

    test('LU/UR/NW/VS concubin : exonération conditionnelle, bascule portée',
        () {
      for (final canton in ['LU', 'UR', 'NW', 'VS']) {
        final v = SuccessionDonationSocle.verdict(
          canton: canton,
          categorie: 'concubin',
        );
        expect(v.statut, 'exonere', reason: canton);
        expect(v.bascule, isNotNull, reason: canton);
        expect(v.bascule, contains('Condition cantonale actuelle'),
            reason: canton);
      }
    });

    test('LU donation : aucun impôt — le verdict le DIT', () {
      for (final cat in _categories) {
        final v = SuccessionDonationSocle.verdict(
          canton: 'LU',
          categorie: cat,
          typeTransmission: 'donation',
        );
        expect(v.statut, 'exonere', reason: 'LU.$cat');
        expect(v.mecanismes.join(' '), contains('Lucerne'), reason: 'LU.$cat');
      }
    });

    test('LU succession : fratrie/tiers restent taxés', () {
      expect(
        SuccessionDonationSocle.verdict(canton: 'LU', categorie: 'fratrie')
            .statut,
        'taxe',
      );
      expect(
        SuccessionDonationSocle.verdict(canton: 'LU', categorie: 'tiers')
            .statut,
        'taxe_lourd',
      );
    });

    test('jamais de plage hors classe au tarif maximal', () {
      for (final canton in SuccessionDonationSocle.cantons.keys) {
        for (final cat in _categories) {
          final v = SuccessionDonationSocle.verdict(
            canton: canton,
            categorie: cat,
          );
          if (v.statut != 'taxe_lourd') {
            expect(v.plageMaxPct, isNull, reason: '$canton.$cat');
          }
        }
      }
    });

    test('canton inconnu : « inconnu », zéro chiffre fabriqué', () {
      final v = SuccessionDonationSocle.verdict(
        canton: 'XX',
        categorie: 'fratrie',
      );
      expect(v.statut, 'inconnu');
      expect(v.plageMaxPct, isNull);
      expect(v.mecanismes, isNotEmpty);
    });

    test('catégorie invalide rejetée', () {
      expect(
        () => SuccessionDonationSocle.verdict(
          canton: 'GE',
          categorie: 'cousin',
        ),
        throwsArgumentError,
      );
    });
  });
}
