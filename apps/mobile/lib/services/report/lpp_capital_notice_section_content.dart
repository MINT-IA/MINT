import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_capital_notice_specialist_handoff.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';

final class LppCapitalNoticeQuestionContent {
  const LppCapitalNoticeQuestionContent({
    required this.topic,
    required this.body,
  });

  final String topic;
  final String body;
}

/// Localized display-only allowlist shared by Dashboard, dossier and PDF.
final class LppCapitalNoticeSectionContent {
  const LppCapitalNoticeSectionContent._({
    required this.isStale,
    required this.title,
    required this.statusBody,
    required this.caveat,
    required this.boundary,
    required this.documentKindLabel,
    required this.documentKindValue,
    required this.sourceDateLabel,
    required this.sourceDateValue,
    required this.legalYearLabel,
    required this.legalYearValue,
    required this.confirmedAtLabel,
    required this.confirmedAtValue,
    required this.fundRelationshipLabel,
    required this.fundRelationshipValue,
    required this.deadlineLabel,
    required this.deadlineValue,
    required this.questionsTitle,
    required this.questions,
  });

  final bool isStale;
  final String title;
  final String statusBody;
  final String caveat;
  final String boundary;
  final String documentKindLabel;
  final String documentKindValue;
  final String sourceDateLabel;
  final String sourceDateValue;
  final String legalYearLabel;
  final String legalYearValue;
  final String confirmedAtLabel;
  final String confirmedAtValue;
  final String fundRelationshipLabel;
  final String fundRelationshipValue;
  final String deadlineLabel;
  final String deadlineValue;
  final String questionsTitle;
  final List<LppCapitalNoticeQuestionContent> questions;

  factory LppCapitalNoticeSectionContent.fromHandoff({
    required LppCapitalNoticeSpecialistHandoff handoff,
    required S l,
    required String localeName,
    required DateTime asOf,
  }) {
    final dateFormat = DateFormat.yMMMMd(localeName);
    final deadlineDay = SwissCivilTime.businessDate(handoff.deadlineDate);
    final isStale = deadlineDay.isBefore(SwissCivilTime.civilDate(asOf));
    final deadlineValue = dateFormat.format(deadlineDay);

    return LppCapitalNoticeSectionContent._(
      isStale: isStale,
      title: l.retirementLppCapitalNoticeDeadlineTitle,
      statusBody: isStale
          ? l.retirementLppCapitalNoticeDeadlineStale(deadlineValue)
          : l.retirementLppCapitalNoticeDeadlineKnown(deadlineValue),
      caveat: l.retirementLppCapitalNoticeCaveat,
      boundary: l.retirementLppCapitalNoticeBoundary,
      documentKindLabel: l.retirementLppCapitalNoticeDocumentKindLabel,
      documentKindValue: l.retirementLppCapitalNoticeDocumentKindValue,
      sourceDateLabel: l.retirementLppCapitalNoticeSourceDateLabel,
      sourceDateValue: dateFormat.format(
        SwissCivilTime.businessDate(handoff.sourceDate),
      ),
      legalYearLabel: l.retirementLppCapitalNoticeLegalYearLabel,
      legalYearValue: '${handoff.legalYear}',
      confirmedAtLabel: l.retirementLppCapitalNoticeConfirmedAtLabel,
      confirmedAtValue: dateFormat.format(
        SwissCivilTime.businessDate(handoff.confirmedAt),
      ),
      fundRelationshipLabel: l.retirementLppCapitalNoticeFundRelationshipLabel,
      fundRelationshipValue:
          l.retirementLppCapitalNoticeFundRelationshipCurrent,
      deadlineLabel: l.retirementLppCapitalNoticeDeadlineLabel,
      deadlineValue: deadlineValue,
      questionsTitle: l.retirementLppCapitalNoticeQuestionsTitle,
      questions: <LppCapitalNoticeQuestionContent>[
        for (final topic in handoff.topics)
          LppCapitalNoticeQuestionContent(
            topic: topic,
            body: _questionBody(l, topic),
          ),
      ],
    );
  }

  static String _questionBody(S l, String topic) => switch (topic) {
        'submissionForm' => l.retirementLppCapitalNoticeQuestionSubmissionForm,
        'receiptProof' => l.retirementLppCapitalNoticeQuestionReceiptProof,
        'changeRevocation' =>
          l.retirementLppCapitalNoticeQuestionChangeRevocation,
        _ => throw StateError('Unknown LPP capital-notice topic'),
      };
}
