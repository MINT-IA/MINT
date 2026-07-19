import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/models/lpp_capital_notice_specialist_handoff.dart';
import 'package:mint_mobile/models/lpp_regulation_specialist_handoff.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/report/lpp_capital_notice_section_content.dart';

const _referenceId = '22222222-2222-4222-8222-222222222222';
final _confirmedAt = DateTime.utc(2026, 7, 18, 10, 15, 30);
final _generatedAt = DateTime.utc(2026, 7, 18, 12);

LppCapitalNoticeSpecialistHandoff _handoff(String deadlineDate) {
  final capitalNoticeEvidence = SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': _referenceId,
      'kind': 'lppCapitalNotice',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': _confirmedAt.toIso8601String(),
      'deadlineDate': deadlineDate,
    },
    expectedKind: SpecialistReferenceKind.lppCapitalNotice,
    now: _confirmedAt.add(const Duration(seconds: 1)),
  );
  final regulationEvidence = SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': '11111111-1111-4111-8111-111111111111',
      'kind': 'lppRegulation',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': _confirmedAt.toIso8601String(),
      'fundRelationship': 'currentFund',
    },
    expectedKind: SpecialistReferenceKind.lppRegulation,
    now: _confirmedAt.add(const Duration(seconds: 1)),
  );
  return LppCapitalNoticeSpecialistHandoff.tryFromResolvedEvidence(
    capitalNoticeEvidence: capitalNoticeEvidence,
    regulationEvidence: regulationEvidence,
  )!;
}

LppRegulationSpecialistHandoff _regulationHandoff() {
  final evidence = SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': '11111111-1111-4111-8111-111111111111',
      'kind': 'lppRegulation',
      'ownerKind': 'self',
      'source': 'certificate',
      'sourceDate': '2026-02-03',
      'legalYear': 2026,
      'confirmedAt': _confirmedAt.toIso8601String(),
      'fundRelationship': 'currentFund',
    },
    expectedKind: SpecialistReferenceKind.lppRegulation,
    now: _confirmedAt.add(const Duration(seconds: 1)),
  );
  return LppRegulationSpecialistHandoff.tryFromEvidence(evidence)!;
}

FinancialReport _report({
  LppCapitalNoticeSpecialistHandoff? handoff,
  LppRegulationSpecialistHandoff? regulationHandoff,
}) {
  const circle = CircleScore(
    circleName: 'Test',
    circleNumber: 1,
    percentage: 50,
    level: ScoreLevel.adequate,
    items: <ScoreItem>[],
    recommendations: <String>[],
  );
  return FinancialReport(
    profile: const UserProfile(
      firstName: 'Test',
      birthYear: 1990,
      canton: 'VD',
      civilStatus: 'single',
      childrenCount: 0,
      employmentStatus: 'employee',
      monthlyNetIncome: 123456,
    ),
    healthScore: const FinancialHealthScore(
      circle1Protection: circle,
      circle2Prevoyance: circle,
      circle3Croissance: circle,
      circle4Optimisation: circle,
      overallScore: 50,
      topPriorities: <String>[],
    ),
    taxSimulation: const TaxSimulation(
      taxableIncome: 123456,
      deductions: <String, double>{},
      cantonalTax: 1,
      federalTax: 1,
      totalTax: 2,
      effectiveRate: 0.02,
    ),
    lppCapitalNoticeHandoff: handoff,
    lppRegulationHandoff: regulationHandoff,
    priorityActions: const <ActionItem>[],
    personalizedRoadmap: const Roadmap(phases: <RoadmapPhase>[]),
    generatedAt: _generatedAt,
  );
}

String _normalize(String value) => value
    .replaceAll(RegExp('[\u2014\u2019]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

Future<String> _pdfText(List<int> bytes) async {
  final directory = await Directory.systemTemp.createTemp('mint-capital-pdf-');
  addTearDown(() => directory.delete(recursive: true));
  final file = File('${directory.path}/report.pdf');
  await file.writeAsBytes(bytes, flush: true);
  final result = await Process.run(
    'pdftotext',
    <String>['-layout', file.path, '-'],
  );
  expect(result.exitCode, 0, reason: result.stderr.toString());
  return _normalize(result.stdout.toString());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final l = lookupS(const Locale('fr'));

  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  for (final testCase in <({String label, String deadline})>[
    (label: 'known', deadline: '2099-09-30'),
    (label: 'stale', deadline: '2020-01-01'),
  ]) {
    test('real PDF bytes contain ordered ${testCase.label} capital allowlist',
        () async {
      final handoff = _handoff(testCase.deadline);
      final content = LppCapitalNoticeSectionContent.fromHandoff(
        handoff: handoff,
        l: l,
        localeName: l.localeName,
        asOf: _generatedAt,
      );
      final bytes = await PdfService.buildFinancialReportPdfBytes(
        _report(handoff: handoff),
        l: l,
      );

      expect(bytes.take(5), <int>[0x25, 0x50, 0x44, 0x46, 0x2d]);
      final text = await _pdfText(bytes);
      final start = text.indexOf(_normalize(content.title.toUpperCase()));
      final end = text.indexOf(_normalize('CONFORMITÉ — STATEMENT OF ADVICE'));
      expect(start, isNonNegative);
      expect(end, greaterThan(start));
      final section = text.substring(start, end);

      final expectedInOrder = <String>[
        content.title.toUpperCase(),
        content.statusBody,
        content.caveat,
        content.boundary,
        content.documentKindLabel,
        content.documentKindValue,
        content.sourceDateLabel,
        content.sourceDateValue,
        content.legalYearLabel,
        content.legalYearValue,
        content.confirmedAtLabel,
        content.confirmedAtValue,
        content.fundRelationshipLabel,
        content.fundRelationshipValue,
        content.deadlineLabel,
        content.deadlineValue,
        content.questionsTitle,
        for (final question in content.questions) question.body,
      ];
      var cursor = -1;
      for (final expected in expectedInOrder) {
        final next = section.indexOf(_normalize(expected), cursor + 1);
        expect(next, greaterThan(cursor), reason: expected);
        cursor = next;
      }

      final lowered = section.toLowerCase();
      for (final forbidden in <String>[
        _referenceId,
        'referenceid',
        'authorityreferenceid',
        'snapshotid',
        'ownerkind',
        'lppcapitalnotice',
        'certificate',
        'sha256',
        '.pdf',
        'raw',
        'ocr',
        '123456',
        'chf',
      ]) {
        expect(lowered, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  }

  test('null capital handoff keeps valid PDF with no capital copy', () async {
    final bytes = await PdfService.buildFinancialReportPdfBytes(
      _report(),
      l: l,
    );
    expect(bytes.take(5), <int>[0x25, 0x50, 0x44, 0x46, 0x2d]);
    final text = await _pdfText(bytes);
    expect(
      text,
      isNot(contains(
        _normalize(l.retirementLppCapitalNoticeDeadlineTitle.toUpperCase()),
      )),
    );
  });

  test('capital section precedes the distinct regulation handoff section',
      () async {
    final bytes = await PdfService.buildFinancialReportPdfBytes(
      _report(
        handoff: _handoff('2099-09-30'),
        regulationHandoff: _regulationHandoff(),
      ),
      l: l,
    );
    final text = await _pdfText(bytes);
    final capital = text.indexOf(
      _normalize(l.retirementLppCapitalNoticeDeadlineTitle.toUpperCase()),
    );
    final regulation = text.indexOf(
      _normalize(l.retirementLppRegulationHandoffTitle.toUpperCase()),
    );
    expect(capital, isNonNegative);
    expect(regulation, greaterThan(capital));
  });

  test('PDF presenter uses report generatedAt as its exact civil asOf', () {
    final source = File('lib/services/pdf_service.dart').readAsStringSync();
    final builderStart = source.indexOf('buildFinancialReportPdfBytes(');
    final wrapperStart = source.indexOf('generateFinancialReportPdf(');
    expect(builderStart, isNonNegative);
    expect(wrapperStart, greaterThan(builderStart));
    final builder = source.substring(builderStart, wrapperStart);
    expect(builder, contains('asOf: report.generatedAt'));
    expect(builder, isNot(contains('asOf: DateTime.now()')));
  });
}
