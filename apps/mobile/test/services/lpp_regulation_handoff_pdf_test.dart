import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/circle_score.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/financial_report.dart';
import 'package:mint_mobile/models/lpp_regulation_specialist_handoff.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/report/lpp_regulation_handoff_section_content.dart';

const _referenceId = '11111111-1111-4111-8111-111111111111';
final _confirmedAt = DateTime.utc(2026, 7, 18, 10, 15, 30);

LppRegulationSpecialistHandoff _handoff() {
  final evidence = SpecialistReferenceEvidence.tryFromJson(
    <String, dynamic>{
      'referenceId': _referenceId,
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

FinancialReport _report({LppRegulationSpecialistHandoff? handoff}) {
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
    lppRegulationHandoff: handoff,
    priorityActions: const <ActionItem>[],
    personalizedRoadmap: const Roadmap(phases: <RoadmapPhase>[]),
    generatedAt: DateTime.utc(2026, 7, 18),
  );
}

String _normalize(String value) => value
    // PdfService's pre-existing core Helvetica font omits these two
    // unsupported glyphs; keep the byte contract semantic and deterministic.
    .replaceAll(RegExp('[\u2014\u2019]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

Future<String> _pdfText(List<int> bytes) async {
  final directory = await Directory.systemTemp.createTemp('mint-lpp-pdf-');
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

  test('real financial-report bytes contain one ordered safe LPP handoff',
      () async {
    final handoff = _handoff();
    final content = LppRegulationHandoffSectionContent.fromHandoff(
      handoff: handoff,
      l: l,
      localeName: l.localeName,
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
      content.referenceBody,
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
      content.applicabilityQuestion,
      content.questionsTitle,
      for (final question in content.questions) ...<String>[
        question.title,
        question.body,
      ],
      content.boundary,
      content.privacy,
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
      'snapshotid',
      'ownerkind',
      'currentfund',
      'lppregulation',
      'certificate',
      'applicabilityanswer',
      'isapplicable',
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

  test('null handoff keeps a valid PDF with no regulation handoff copy',
      () async {
    final bytes = await PdfService.buildFinancialReportPdfBytes(
      _report(),
      l: l,
    );
    expect(bytes.take(5), <int>[0x25, 0x50, 0x44, 0x46, 0x2d]);
    final text = await _pdfText(bytes);
    for (final absent in <String>[
      l.retirementLppRegulationHandoffTitle.toUpperCase(),
      l.retirementLppRegulationReferenceBody,
      l.retirementLppRegulationApplicabilityQuestion,
      l.retirementLppRegulationQuestionsTitle,
      l.retirementLppRegulationHandoffBoundary,
      l.retirementLppRegulationHandoffPrivacy,
    ]) {
      expect(text, isNot(contains(_normalize(absent))), reason: absent);
    }
  });

  test('share wrapper delegates byte construction and only shares bytes', () {
    final source = File('lib/services/pdf_service.dart').readAsStringSync();
    final builderStart = source.indexOf('buildFinancialReportPdfBytes(');
    final wrapperStart = source.indexOf('generateFinancialReportPdf(');
    final helperStart = source.indexOf('// ===== PDF V2 HELPERS =====');
    expect(builderStart, isNonNegative);
    expect(wrapperStart, greaterThan(builderStart));
    expect(helperStart, greaterThan(wrapperStart));
    final builder = source.substring(builderStart, wrapperStart);
    final wrapper = source.substring(wrapperStart, helperStart);
    expect(builder, contains('pw.Document'));
    expect(builder, contains('return pdf.save()'));
    expect(builder, isNot(contains('Printing.')));
    expect(wrapper, contains('buildFinancialReportPdfBytes('));
    expect(wrapper, contains('Printing.sharePdf('));
    expect(wrapper, contains('bytes: bytes'));
    expect(wrapper, isNot(contains('pw.Document')));
    expect(wrapper, isNot(contains('pdf.save')));
  });
}
