import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_capital_notice_specialist_handoff.dart';
import 'package:mint_mobile/models/lpp_regulation_specialist_handoff.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';
import 'package:mint_mobile/services/report/lpp_capital_notice_section_content.dart';

const _referenceId = '22222222-2222-4222-8222-222222222222';
final _confirmedAt = DateTime.utc(2026, 7, 18, 10, 15, 30);
final _asOf = DateTime.utc(2026, 7, 18, 12);

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

Map<String, dynamic> _answers() => <String, dynamic>{
      'q_birth_year': 1990,
      'q_canton': 'VD',
      'q_civil_status': 'single',
      'q_children': '0',
      'q_employment_status': 'employee',
      'q_net_income_period_chf': 6000.0,
    };

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        S.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: S.supportedLocales,
      home: home,
    );

void main() {
  setUpAll(() async {
    await initializeDateFormatting('fr');
  });

  for (final testCase in <({String label, String deadline})>[
    (label: 'known', deadline: '2099-09-30'),
    (label: 'stale', deadline: '2020-01-01'),
  ]) {
    testWidgets('dossier renders ${testCase.label} capital deadline allowlist',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final handoff = _handoff(testCase.deadline);
      await tester.pumpWidget(_app(FinancialReportScreenV2(
        wizardAnswers: _answers(),
        lppCapitalNoticeHandoff: handoff,
      )));
      await tester.pumpAndSettle();

      final section = find.bySemanticsIdentifier(
        'financial_report_lpp_capital_notice_handoff',
      );
      expect(section, findsOneWidget);
      final l = S.of(tester.element(section))!;
      final content = LppCapitalNoticeSectionContent.fromHandoff(
        handoff: handoff,
        l: l,
        localeName: l.localeName,
        asOf: _asOf,
      );
      expect(content.title, 'Échéance déclarée pour une prestation en capital');
      expect(
        content.statusBody,
        testCase.label == 'known'
            ? 'Le règlement examiné indique le ${content.deadlineValue} comme '
                'échéance pour faire connaître ta volonté de recevoir une '
                'prestation en capital. Cette indication ne confirme ni '
                'l’application du règlement à ta situation, ni l’acceptation '
                'de l’option.'
            : 'Le règlement examiné indiquait le ${content.deadlineValue} pour '
                'faire connaître cette volonté; cette date est dépassée. MINT '
                'ne peut conclure ni à la perte d’un droit, ni à l’existence '
                'd’une exception, d’une autre échéance ou modalité.',
      );
      expect(
        content.caveat,
        'Tu as déclaré, sans vérification indépendante, que ce règlement '
        'provient de ta caisse actuelle.',
      );
      expect(
        content.boundary,
        'Repère documentaire uniquement — pas un conseil. Confirme directement '
        'auprès de l’institution concernée le règlement applicable, '
        'l’échéance, la forme exigée et la réception de ta demande avant toute '
        'décision.',
      );
      expect(content.questions, hasLength(3));
      expect(
        content.questions.map((question) => question.topic),
        <String>['submissionForm', 'receiptProof', 'changeRevocation'],
      );
      for (final expected in <String>[
        content.title,
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
      ]) {
        expect(
          find.descendant(
            of: section,
            matching: find.textContaining(expected, findRichText: true),
          ),
          findsOneWidget,
          reason: expected,
        );
      }
      final rendered = tester
          .widgetList<Text>(
            find.descendant(of: section, matching: find.byType(Text)),
          )
          .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
          .join(' ')
          .toLowerCase();
      for (final forbidden in <String>[
        _referenceId,
        'referenceid',
        'authorityreferenceid',
        'snapshotid',
        'ownerkind',
        'certificate',
        '/private/',
        'sha256',
        'ocr',
        '123456 chf',
      ]) {
        expect(rendered, isNot(contains(forbidden)), reason: forbidden);
      }
    });
  }

  testWidgets('dossier omits capital section when typed handoff is null',
      (tester) async {
    await tester.pumpWidget(_app(FinancialReportScreenV2(
      wizardAnswers: _answers(),
    )));
    await tester.pumpAndSettle();

    expect(
      find.bySemanticsIdentifier(
        'financial_report_lpp_capital_notice_handoff',
      ),
      findsNothing,
    );
  });

  testWidgets('capital dossier section precedes distinct regulation section',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 6000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(_app(FinancialReportScreenV2(
      wizardAnswers: _answers(),
      lppCapitalNoticeHandoff: _handoff('2099-09-30'),
      lppRegulationHandoff: _regulationHandoff(),
    )));
    await tester.pumpAndSettle();

    final capital = find.bySemanticsIdentifier(
      'financial_report_lpp_capital_notice_handoff',
    );
    final regulation = find.bySemanticsIdentifier(
      'financial_report_lpp_regulation_handoff',
    );
    expect(capital, findsOneWidget);
    expect(regulation, findsOneWidget);
    expect(
      tester.getTopLeft(capital).dy,
      lessThan(tester.getTopLeft(regulation).dy),
    );
  });

  test('dossier presenter uses report generatedAt, never a second wall clock',
      () {
    final source = File(
      'lib/screens/advisor/financial_report_screen_v2.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'Widget _buildLppCapitalNoticeHandoffSection',
    );
    final end = source.indexOf(
      'Widget _buildLppRegulationHandoffSection',
      start,
    );
    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    final block = source.substring(start, end);
    expect(block, contains('asOf: report.generatedAt'));
    expect(block, isNot(contains('asOf: DateTime.now()')));
  });

  test('Dashboard consumes the same capital presenter from one current instant',
      () {
    final source = File(
      'lib/screens/coach/retirement_dashboard_screen.dart',
    ).readAsStringSync();
    final start = source.indexOf(
      'List<Widget> _buildLppCapitalNoticeEducation',
    );
    final end = source.indexOf(
      'List<Widget> _buildLppRegulationEducation',
      start,
    );
    expect(start, isNonNegative);
    expect(end, greaterThan(start));
    final block = source.substring(start, end);

    expect(block, contains('LppCapitalNoticeSectionContent.fromHandoff'));
    expect(block, contains('final asOf = DateTime.now();'));
    expect(block, contains('asOf: asOf'));
    expect(RegExp(r'DateTime\.now\(\)').allMatches(block), hasLength(1));
    for (final field in <String>[
      'content.title',
      'content.statusBody',
      'content.caveat',
      'content.boundary',
    ]) {
      expect(block, contains(field), reason: field);
    }
    expect(block, isNot(contains('retirementLppCapitalNoticeDeadlineKnown')));
    expect(block, isNot(contains('retirementLppCapitalNoticeDeadlineStale')));
  });
}
