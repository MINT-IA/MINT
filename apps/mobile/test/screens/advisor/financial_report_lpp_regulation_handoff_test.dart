import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_regulation_specialist_handoff.dart';
import 'package:mint_mobile/screens/advisor/financial_report_screen_v2.dart';

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
  testWidgets('dossier renders exact typed handoff and six unanswered topics',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final screen = FinancialReportScreenV2(
      wizardAnswers: _answers(),
      lppRegulationHandoff: _handoff(),
    );
    await tester.pumpWidget(_app(screen));
    await tester.pumpAndSettle();

    final section = find.bySemanticsIdentifier(
      'financial_report_lpp_regulation_handoff',
    );
    expect(section, findsOneWidget);
    final l = S.of(tester.element(section))!;
    final sourceDate = DateFormat.yMMMMd('fr').format(DateTime.utc(2026, 2, 3));
    final confirmedAt = DateFormat.yMMMMd('fr').format(_confirmedAt);
    for (final text in <String>[
      l.retirementLppRegulationReferenceBody,
      l.retirementLppRegulationApplicabilityQuestion,
      l.retirementLppRegulationHandoffBoundary,
      l.retirementLppRegulationHandoffPrivacy,
      l.retirementLppRegulationQuestionBuyback,
      l.retirementLppRegulationQuestionBuybackBody,
      l.retirementLppRegulationQuestionConversion,
      l.retirementLppRegulationQuestionConversionBody,
      l.retirementLppRegulationQuestionFlexibleRetirement,
      l.retirementLppRegulationQuestionFlexibleRetirementBody,
      l.retirementLppRegulationQuestionDisability,
      l.retirementLppRegulationQuestionDisabilityBody,
      l.retirementLppRegulationQuestionSurvivors,
      l.retirementLppRegulationQuestionSurvivorsBody,
      l.retirementLppRegulationQuestionDivorce,
      l.retirementLppRegulationQuestionDivorceBody,
    ]) {
      expect(find.descendant(of: section, matching: find.text(text)),
          findsOneWidget);
    }
    for (final metadataLine in <String>[
      '${l.retirementLppRegulationDocumentKindLabel} '
          '${l.retirementLppRegulationDocumentKindValue}',
      '${l.retirementLppRegulationSourceDateLabel} $sourceDate',
      '${l.retirementLppRegulationLegalYearLabel} 2026',
      '${l.retirementLppRegulationConfirmedAtLabel} $confirmedAt',
      '${l.retirementLppRegulationFundRelationshipLabel} '
          '${l.retirementLppRegulationFundRelationshipCurrent}',
    ]) {
      expect(
        find.descendant(
          of: section,
          matching: find.text(metadataLine, findRichText: true),
        ),
        findsOneWidget,
        reason: metadataLine,
      );
    }
    final rendered = tester
        .widgetList<Text>(
            find.descendant(of: section, matching: find.byType(Text)))
        .map((widget) => widget.data ?? widget.textSpan?.toPlainText() ?? '')
        .join(' ')
        .toLowerCase();
    for (final forbidden in <String>[
      _referenceId,
      'snapshotid',
      'ownerkind',
      'certificate',
      '/private/',
      'sha256',
      'ocr',
      '123456 chf',
      'isapplicable',
    ]) {
      expect(rendered, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  testWidgets('dossier omits handoff section when typed authority is null',
      (tester) async {
    await tester.pumpWidget(_app(FinancialReportScreenV2(
      wizardAnswers: _answers(),
    )));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsIdentifier('financial_report_lpp_regulation_handoff'),
      findsNothing,
    );
  });
}
