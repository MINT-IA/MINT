import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:mint_mobile/services/sequence/sequence_summary_builder.dart';

void main() {
  group('buildSequenceSummary — housing_purchase', () {
    test('produces items from complete outputs', () {
      final items = buildSequenceSummary(
        templateId: 'housing_purchase',
        allOutputs: {
          'housing_01_affordability': {
            'capacite_achat': 450000.0,
            'fonds_propres_requis': 90000.0,
          },
          'housing_02_epl': {
            'montant_epl': 50000.0,
            'impact_rente': 180.0,
          },
          'housing_03_fiscal': {
            'impot_retrait': 5200.0,
          },
        },
      );

      expect(items.length, 6); // capacity + fonds + epl + impact + impot + net
      expect(items[0].label, contains('Capacité'));
      expect(items[0].value, contains('450'));
      expect(items[4].label, contains('Impôt'));
      // Net = 50000 - 5200 = 44800
      expect(items[5].label, contains('net'));
      expect(items[5].value, contains('44'));
    });

    test('handles partial outputs (only step 1)', () {
      final items = buildSequenceSummary(
        templateId: 'housing_purchase',
        allOutputs: {
          'housing_01_affordability': {
            'capacite_achat': 300000.0,
          },
        },
      );

      expect(items.length, 1);
      expect(items[0].icon, Icons.home_outlined);
    });

    test('handles zero values gracefully', () {
      final items = buildSequenceSummary(
        templateId: 'housing_purchase',
        allOutputs: {
          'housing_01_affordability': {
            'capacite_achat': 0.0,
            'fonds_propres_requis': 0.0,
          },
        },
      );

      expect(items, isEmpty);
    });

    test('handles empty outputs', () {
      final items = buildSequenceSummary(
        templateId: 'housing_purchase',
        allOutputs: {},
      );
      expect(items, isEmpty);
    });
  });

  group('buildSequenceSummary — optimize_3a', () {
    test('produces items from complete outputs', () {
      final items = buildSequenceSummary(
        templateId: 'optimize_3a',
        allOutputs: {
          '3a_01_simulator': {
            'contribution_annuelle': 7258.0,
            'economie_fiscale': 2177.0,
          },
          '3a_02_withdrawal': {
            'gain_echelonnement': 8500.0,
          },
        },
      );

      expect(items.length, 3);
      expect(items[0].label, contains('Versement'));
      expect(items[1].label, contains('Économie fiscale'));
      expect(items[2].label, contains('Gain'));
    });
  });

  group('buildSequenceSummary — retirement_prep', () {
    test('produces items from complete outputs including choice', () {
      final items = buildSequenceSummary(
        templateId: 'retirement_prep',
        allOutputs: {
          'ret_01_projection': {
            'taux_remplacement': 65.0,
            'gap_mensuel': 2500.0,
          },
          'ret_02_choice': {
            'decision_mixte': 'certificate',
          },
          'ret_03_buyback': {
            'economie_rachat': 12000.0,
          },
        },
      );

      expect(items.length, 4); // taux + gap + choice + buyback
      expect(items[0].label, contains('Taux'));
      expect(items[0].value, contains('65'));
      expect(items[1].label, contains('Écart'));
      expect(items[2].label, contains('certificat'));
      expect(items[3].label, contains('rachat'));
    });

    test('handles missing optional step', () {
      final items = buildSequenceSummary(
        templateId: 'retirement_prep',
        allOutputs: {
          'ret_01_projection': {
            'taux_remplacement': 72.0,
            'gap_mensuel': 1200.0,
          },
        },
      );

      expect(items.length, 2); // No buyback
    });
  });

  group('buildSequenceSummary — financial_tension', () {
    test('produces items from complete tension outputs', () {
      final items = buildSequenceSummary(
        templateId: 'financial_tension',
        allOutputs: {
          'tension_01_diagnostic': {
            'ratio_endettement': 0.42,
            'marge_mensuelle': -200.0,
          },
          'tension_02_budget': {
            'revenu_net': 6000.0,
            'charges_totales': 4500.0,
          },
          'tension_03_repayment': {
            'horizon_mois': 18.0,
            'versement_mensuel': 800.0,
          },
        },
      );

      expect(items.length, 6);
      expect(items[0].label, contains('Ratio'));
      expect(items[0].value, contains('42'));
      expect(items[1].label, contains('Marge'));
      expect(items[4].label, contains('Horizon'));
      expect(items[4].value, contains('1.5 ans'));
      expect(items[5].label, contains('Versement'));
    });

    test('handles negative marge with warning icon', () {
      final items = buildSequenceSummary(
        templateId: 'financial_tension',
        allOutputs: {
          'tension_01_diagnostic': {
            'ratio_endettement': 0.55,
            'marge_mensuelle': -350.0,
          },
        },
      );

      expect(items.length, 2);
      expect(items[1].icon, Icons.warning_amber_outlined);
    });

    test('handles short horizon in months', () {
      final items = buildSequenceSummary(
        templateId: 'financial_tension',
        allOutputs: {
          'tension_03_repayment': {
            'horizon_mois': 8.0,
            'versement_mensuel': 500.0,
          },
        },
      );

      expect(items.length, 2);
      expect(items[0].value, contains('8 mois'));
    });
  });

  group('buildSequenceSummary — unknown template', () {
    test('returns empty for unknown template', () {
      final items = buildSequenceSummary(
        templateId: 'unknown',
        allOutputs: {},
      );
      expect(items, isEmpty);
    });
  });
}
