import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/lpp_regulation_specialist_handoff.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';

final class LppRegulationHandoffQuestionContent {
  const LppRegulationHandoffQuestionContent({
    required this.topic,
    required this.title,
    required this.body,
  });

  final String topic;
  final String title;
  final String body;
}

/// Localized display-only allowlist shared by the sheet and dossier.
final class LppRegulationHandoffSectionContent {
  const LppRegulationHandoffSectionContent._({
    required this.title,
    required this.referenceBody,
    required this.boundary,
    required this.privacy,
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
    required this.applicabilityQuestion,
    required this.questionsTitle,
    required this.questions,
  });

  final String title;
  final String referenceBody;
  final String boundary;
  final String privacy;
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
  final String applicabilityQuestion;
  final String questionsTitle;
  final List<LppRegulationHandoffQuestionContent> questions;

  factory LppRegulationHandoffSectionContent.fromHandoff({
    required LppRegulationSpecialistHandoff handoff,
    required S l,
    required String localeName,
  }) {
    final dateFormat = DateFormat.yMMMMd(localeName);
    return LppRegulationHandoffSectionContent._(
      title: l.retirementLppRegulationHandoffTitle,
      referenceBody: l.retirementLppRegulationReferenceBody,
      boundary: l.retirementLppRegulationHandoffBoundary,
      privacy: l.retirementLppRegulationHandoffPrivacy,
      documentKindLabel: l.retirementLppRegulationDocumentKindLabel,
      documentKindValue: l.retirementLppRegulationDocumentKindValue,
      sourceDateLabel: l.retirementLppRegulationSourceDateLabel,
      sourceDateValue: dateFormat.format(
        SwissCivilTime.businessDate(handoff.sourceDate),
      ),
      legalYearLabel: l.retirementLppRegulationLegalYearLabel,
      legalYearValue: '${handoff.legalYear}',
      confirmedAtLabel: l.retirementLppRegulationConfirmedAtLabel,
      confirmedAtValue: dateFormat.format(
        SwissCivilTime.businessDate(handoff.confirmedAt),
      ),
      fundRelationshipLabel: l.retirementLppRegulationFundRelationshipLabel,
      fundRelationshipValue: switch (handoff.fundRelationship) {
        LppFundRelationship.currentFund =>
          l.retirementLppRegulationFundRelationshipCurrent,
        LppFundRelationship.uncertain =>
          l.retirementLppRegulationFundRelationshipUncertain,
        LppFundRelationship.formerOrOther =>
          l.retirementLppRegulationFundRelationshipFormerOrOther,
      },
      applicabilityQuestion: l.retirementLppRegulationApplicabilityQuestion,
      questionsTitle: l.retirementLppRegulationQuestionsTitle,
      questions: <LppRegulationHandoffQuestionContent>[
        for (final topic in handoff.topics)
          LppRegulationHandoffQuestionContent(
            topic: topic,
            title: _topicTitle(l, topic),
            body: _questionBody(l, topic),
          ),
      ],
    );
  }

  static String _topicTitle(S l, String topic) => switch (topic) {
        'buyback' => l.retirementLppRegulationQuestionBuyback,
        'conversion' => l.retirementLppRegulationQuestionConversion,
        'flexibleRetirement' =>
          l.retirementLppRegulationQuestionFlexibleRetirement,
        'disability' => l.retirementLppRegulationQuestionDisability,
        'survivors' => l.retirementLppRegulationQuestionSurvivors,
        'divorce' => l.retirementLppRegulationQuestionDivorce,
        _ => throw StateError('Unknown LPP regulation topic'),
      };

  static String _questionBody(S l, String topic) => switch (topic) {
        'buyback' => l.retirementLppRegulationQuestionBuybackBody,
        'conversion' => l.retirementLppRegulationQuestionConversionBody,
        'flexibleRetirement' =>
          l.retirementLppRegulationQuestionFlexibleRetirementBody,
        'disability' => l.retirementLppRegulationQuestionDisabilityBody,
        'survivors' => l.retirementLppRegulationQuestionSurvivorsBody,
        'divorce' => l.retirementLppRegulationQuestionDivorceBody,
        _ => throw StateError('Unknown LPP regulation topic'),
      };
}
