import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/financial_report_service.dart';
import 'package:mint_mobile/services/pdf_service.dart';
import 'package:mint_mobile/services/report/pillar3a_beneficiary_handoff_section_content.dart';

import '../support/pillar3a_beneficiary_handoff_fixture.dart';

Map<String, dynamic> _answers() => <String, dynamic>{
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_civil_status': 'single',
      'q_children': '0',
      'q_employment_status': 'employee',
      'q_net_income_period_chf': 6000.0,
    };

String _normalize(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

Future<String> _pdfText(List<int> bytes) async {
  final directory = await Directory.systemTemp.createTemp('mint-3a-pdf-');
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

  test('real report bytes contain one ordered exact 3a specialist section',
      () async {
    final handoff = pillar3aBeneficiaryHandoffFixture(attestedRegime: true);
    final content = Pillar3aBeneficiaryHandoffSectionContent.fromEntry(
      entry: handoff.entries.single,
      l: l,
      localeName: l.localeName,
    );
    final report = FinancialReportService().generateReport(
      _answers(),
      pillar3aBeneficiaryHandoff: handoff,
    );
    final bytes = await HttpOverrides.runZoned(
      () => PdfService.buildFinancialReportPdfBytes(report, l: l),
      createHttpClient: (_) => throw StateError('network access forbidden'),
    );

    expect(bytes.take(5), <int>[0x25, 0x50, 0x44, 0x46, 0x2d]);
    expect(bytes.length, greaterThan(1000));
    final text = await _pdfText(bytes);
    final start = text.indexOf(_normalize(content.title.toUpperCase()));
    final end = text.indexOf(_normalize('CONFORMITÉ — STATEMENT OF ADVICE'));
    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    final section = text.substring(start, end);

    final expectedInOrder = <String>[
      content.title.toUpperCase(),
      content.statusBody,
      content.documentKindLabel,
      content.documentKindValue,
      content.sourceDateLabel,
      content.sourceDateValue,
      content.legalYearLabel,
      content.legalYearValue,
      content.temporalBasisLabel,
      ...content.temporalBasisLines,
      content.declaredRelation,
      content.freshnessCaveat,
      content.questionsTitle,
      ...content.questions,
      content.boundary,
      content.legalFooter,
    ];
    var cursor = -1;
    for (final expected in expectedInOrder) {
      final next = section.indexOf(_normalize(expected), cursor + 1);
      expect(next, greaterThan(cursor), reason: expected);
      cursor = next;
    }
    expect(
      section,
      contains(
          _normalize('Régime attesté par l’institution, non déduit par MINT')),
    );
    expect(section, contains(_normalize('Dès le 1er juin 2027')));

    final lowered = section.toLowerCase();
    for (final forbidden in const <String>[
      '11111111-1111-4111-8111-111111111111',
      'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
      '33333333-3333-4333-8333-333333333333',
      'referenceid',
      'documentauthorityid',
      'nom du bénéficiaire',
      'classe bénéficiaire',
      'rang bénéficiaire',
      'quote-part',
      'raw',
      'sha256',
      '/private/',
      '.pdf',
      'iban',
      'numéro avs',
      'ocr',
      'chf',
    ]) {
      expect(lowered, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('null handoff keeps valid bytes and omits exact 3a Swiss copy',
      () async {
    final bytes = await PdfService.buildFinancialReportPdfBytes(
      FinancialReportService().generateReport(_answers()),
      l: l,
    );
    expect(bytes.take(5), <int>[0x25, 0x50, 0x44, 0x46, 0x2d]);
    final text = await _pdfText(bytes);
    for (final absent in const <String>[
      'Date portée par la source institutionnelle',
      'Année juridique indiquée dans le document',
      'Quelle désignation est actuellement enregistrée auprès de l’institution',
      'OPP 3 art. 2, al. 2–3',
    ]) {
      expect(text, isNot(contains(_normalize(absent))), reason: absent);
    }
  });

  test('screen and PDF both depend on the same section presenter', () {
    final pdf = File('lib/services/pdf_service.dart').readAsStringSync();
    final screen = File(
      'lib/screens/advisor/financial_report_screen_v2.dart',
    ).readAsStringSync();
    const symbol = 'Pillar3aBeneficiaryHandoffSectionContent.fromEntry';
    expect(pdf, contains(symbol));
    expect(screen, contains(symbol));
  });

  test('PDF Unicode fonts are bundled and never use a runtime downloader', () {
    final source = File('lib/services/pdf_service.dart').readAsStringSync();
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final license = File(
      'assets/fonts/LibreFranklin-OFL.txt',
    ).readAsStringSync();

    for (final path in const <String>[
      'assets/fonts/LibreFranklin-Regular.ttf',
      'assets/fonts/LibreFranklin-Bold.ttf',
      'assets/fonts/LibreFranklin-OFL.txt',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: path);
      expect(pubspec, contains('- $path'), reason: path);
    }
    expect(source, contains('rootBundle.load'));
    expect(source, contains('pw.Font.ttf'));
    expect(source, isNot(contains('PdfGoogleFonts')));
    expect(license, contains('SIL OPEN FONT LICENSE Version 1.1'));
    expect(license, contains('Copyright (c) 2015, Impallari Type'));
  });
}
