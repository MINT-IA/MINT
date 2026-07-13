import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/l10n/app_localizations_de.dart';
import 'package:mint_mobile/l10n/app_localizations_en.dart';
import 'package:mint_mobile/l10n/app_localizations_es.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/l10n/app_localizations_it.dart';
import 'package:mint_mobile/l10n/app_localizations_pt.dart';

void main() {
  group('G1 financial report retirement contract', () {
    test('the PDF projection block uses localized copy end to end', () {
      final source = File('lib/services/pdf_service.dart').readAsStringSync();
      final start = source.indexOf('// 5. PROJECTION RETRAITE');
      final end = source.indexOf('// 6. STRATÉGIE RACHAT LPP');

      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final block = source.substring(start, end);

      for (final getter in <String>[
        'reportPdfRetirementProjectionTitle',
        'reportPdfRetirementHorizon',
        'reportPdfRetirementMonthlyPensions',
        'reportPdfRetirementCapitalsAtAge',
        'reportPdfRetirementLppCapital',
        'reportPdfRetirementPillar3aCapital',
        'reportPdfRetirementOtherAssets',
        'reportPdfRetirementTotalCapital',
      ]) {
        expect(block, contains('l.$getter'), reason: '$getter must be wired');
      }

      for (final literal in <String>[
        "_pdfSectionTitle('Projection Retraite')",
        "'Horizon : ",
        "pw.Text('Rentes mensuelles estimées'",
        "pw.Text('Capitaux estimés à 65 ans'",
        "_pdfKeyValue('Capital LPP'",
        "_pdfKeyValue('Capital 3a'",
        "_pdfKeyValue('Autres actifs'",
        "'Capital total estimé'",
      ]) {
        expect(block, isNot(contains(literal)),
            reason: 'the projection block must not embed $literal');
      }

      for (final uncertifiedValue in <String>[
        'ret.monthlyLppRent',
        'ret.lppCapital',
        'ret.pillar3aCapital',
        'ret.totalCapital',
      ]) {
        expect(block, isNot(contains(uncertifiedValue)),
            reason: '$uncertifiedValue must stay pending in the PDF');
      }
      expect(block, contains('l.coverageCheckAVerifier'));
    });

    test('all six locales expose the complete PDF projection vocabulary', () {
      final localizations = <S>[SFr(), SEn(), SDe(), SEs(), SIt(), SPt()];

      expect(
        localizations.map((l) => l.reportPdfRetirementProjectionTitle),
        <String>[
          'Projection retraite',
          'Retirement projection',
          'Pensionierungsprojektion',
          'Proyección de jubilación',
          'Proiezione pensionistica',
          'Projeção da reforma',
        ],
      );

      for (final l in localizations) {
        expect(l.reportPdfRetirementHorizon(12, 65),
            allOf(contains('12'), contains('65')));
        expect(l.reportPdfRetirementMonthlyPensions, isNotEmpty);
        expect(l.reportPdfRetirementCapitalsAtAge(65), contains('65'));
        expect(l.reportPdfRetirementLppCapital, isNotEmpty);
        expect(l.reportPdfRetirementPillar3aCapital, isNotEmpty);
        expect(l.reportPdfRetirementOtherAssets, isNotEmpty);
        expect(l.reportPdfRetirementTotalCapital, isNotEmpty);
        expect(l.report3aPendingBody, isNotEmpty);
        expect(l.report3aPendingCta, isNotEmpty);
      }
    });

    test('the PDF footer makes no claim about quarantined projections', () {
      final source = File('lib/services/pdf_service.dart').readAsStringSync();

      for (final obsoleteClaim in <String>[
        'Le taux de conversion LPP utilisé est de 6%',
        'Les comparaisons de fournisseurs sont basées sur des données publiques',
      ]) {
        expect(
          source,
          isNot(contains(obsoleteClaim)),
          reason: '$obsoleteClaim is false after the report quarantine',
        );
      }
    });

    test('the report profile exposes no questionnaire-derived AVS facade', () {
      final model = File('lib/models/financial_report.dart').readAsStringSync();
      final profileStart = model.indexOf('class UserProfile');
      final profileEnd = model.indexOf('class TaxSimulation');
      expect(profileStart, isNonNegative);
      expect(profileEnd, greaterThan(profileStart));
      final profile = model.substring(profileStart, profileEnd);

      for (final identifier in <String>[
        'gender',
        'spouseGender',
        'avsGapYears',
        'spouseAvsGapYears',
        'contributionYears',
        'spouseContributionYears',
        'firstEmploymentYear',
        'spouseFirstEmploymentYear',
        'spouseBirthYear',
        'spouseMonthlyNetIncome',
        'spouseAge',
        'theoreticalAvsYears',
        'avsReductionFactor',
        'spouseAvsReductionFactor',
      ]) {
        expect(profile, isNot(contains(identifier)),
            reason: '$identifier belonged to the removed AVS estimator');
      }

      final service =
          File('lib/services/financial_report_service.dart').readAsStringSync();
      for (final staleInput in <String>[
        "answers['q_gender']",
        "answers['q_spouse_gender']",
        "answers['q_partner_birth_year']",
        "answers['q_partner_net_income_chf']",
        "answers['q_avs_contribution_years']",
        "answers['q_spouse_avs_contribution_years']",
        "answers['q_first_employment_year']",
        "answers['q_spouse_first_employment_year']",
        '_calculateAvsGaps(',
        '_calculateSpouseAvsGaps(',
      ]) {
        expect(service, isNot(contains(staleInput)),
            reason: '$staleInput must not feed the financial report');
      }
    });

    test('the report service never invents an LPP point projection', () {
      final source =
          File('lib/services/financial_report_service.dart').readAsStringSync();
      final start =
          source.indexOf('RetirementProjection? _buildRetirementProjection');
      final end = source.indexOf('LppBuybackStrategy? _buildLppStrategy');
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final block = source.substring(start, end);

      for (final syntheticInput in <String>[
        "answers['q_current_lpp_capital']",
        "answers['q_lpp_buyback_available']",
        'NetIncomeBreakdown.estimateBrutFromNet',
        'getLppBonificationRate',
        "reg('lpp.conversion_rate_min'",
        'lppTauxConversionMinDecimal',
      ]) {
        expect(block, isNot(contains(syntheticInput)),
            reason: '$syntheticInput cannot certify an LPP projection');
      }
      expect(block, contains('lppCapital: null'));
      expect(block, contains('monthlyLppRent: null'));
    });
  });
}
