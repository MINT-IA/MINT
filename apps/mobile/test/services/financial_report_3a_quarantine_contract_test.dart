import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('G1 financial report 3a quarantine', () {
    test('the report model exposes no provider-comparison facade', () {
      final model = File('lib/models/financial_report.dart').readAsStringSync();

      expect(model, isNot(contains('Pillar3aAnalysis')));
      expect(model, isNot(contains('pillar3aAnalysis')));
      expect(model, contains('final double? pillar3aCapital'));
    });

    test('the report service creates no 3a point or provider ranking', () {
      final service =
          File('lib/services/financial_report_service.dart').readAsStringSync();
      final start =
          service.indexOf('RetirementProjection? _buildRetirementProjection');
      final end = service.indexOf('LppBuybackStrategy? _buildLppStrategy');
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final retirementBlock = service.substring(start, end);

      expect(retirementBlock,
          isNot(contains("answers['q_3a_annual_contribution']")));
      expect(retirementBlock, isNot(contains('_futureValue(')));
      expect(retirementBlock, contains('pillar3aCapital: null'));

      for (final forbidden in <String>[
        'Pillar3aAnalysis',
        'pillar3aAnalysis',
        '_build3aAnalysis',
        "answers['q_3a_providers']",
        'projectionsByProvider',
        'potentialGainVsBank',
        'withdrawalOptimizationSavings',
        "recommendation.contains('premier compte 3a')",
        "recommendation.contains('2e compte 3a')",
        'fintech',
      ]) {
        expect(service, isNot(contains(forbidden)),
            reason: '$forbidden must not classify 3a providers in the report');
      }
    });

    test('the report screen owns no 3a chip or comparator', () {
      final screen = File(
        'lib/screens/advisor/financial_report_screen_v2.dart',
      ).readAsStringSync();

      for (final forbidden in <String>[
        'Pillar3aComparatorWidget',
        'pillar3a_comparator_widget.dart',
        'report.pillar3aAnalysis',
        "answers['q_has_3a']",
        "answers['q_3a_accounts_count']",
        'reportRetirement3aNone',
        'reportRetirement3aOne',
        'reportRetirement3aMulti',
      ]) {
        expect(screen, isNot(contains(forbidden)),
            reason: '$forbidden belongs to the removed report facade');
      }

      expect(
        File('lib/widgets/comparators/pillar3a_comparator_widget.dart')
            .existsSync(),
        isFalse,
      );
    });

    test('UI and PDF keep 3a pending without formatting a point', () {
      final widget = File(
        'lib/widgets/report/retirement_projection_card.dart',
      ).readAsStringSync();
      final pdf = File('lib/services/pdf_service.dart').readAsStringSync();
      final pdfStart = pdf.indexOf('// 5. PROJECTION RETRAITE');
      final pdfEnd = pdf.indexOf('// 6. STRATÉGIE RACHAT LPP');
      expect(pdfStart, isNonNegative);
      expect(pdfEnd, greaterThan(pdfStart));
      final pdfBlock = pdf.substring(pdfStart, pdfEnd);

      expect(widget, contains('financial_report_3a_pending'));
      expect(widget, contains("context.push('/data-block/3a')"));
      expect(widget, isNot(contains('projection.pillar3aCapital')));
      expect(pdfBlock, isNot(contains('ret.pillar3aCapital')));
      expect(pdfBlock, contains('l.coverageCheckAVerifier'));
    });
  });
}
