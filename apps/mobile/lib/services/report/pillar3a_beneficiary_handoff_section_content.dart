import 'package:intl/intl.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_specialist_handoff.dart';
import 'package:mint_mobile/services/financial_core/swiss_civil_time.dart';

/// Localized display-only allowlist shared by `/rapport` and its PDF export.
final class Pillar3aBeneficiaryHandoffSectionContent {
  const Pillar3aBeneficiaryHandoffSectionContent._({
    required this.title,
    required this.statusBody,
    required this.documentKindLabel,
    required this.documentKindValue,
    required this.sourceDateLabel,
    required this.sourceDateValue,
    required this.legalYearLabel,
    required this.legalYearValue,
    required this.temporalBasisLabel,
    required this.temporalBasisLines,
    required this.declaredRelation,
    required this.freshnessCaveat,
    required this.questionsTitle,
    required this.questions,
    required this.boundary,
    required this.legalFooter,
  });

  final String title;
  final String statusBody;
  final String documentKindLabel;
  final String documentKindValue;
  final String sourceDateLabel;
  final String sourceDateValue;
  final String legalYearLabel;
  final String legalYearValue;
  final String temporalBasisLabel;
  final List<String> temporalBasisLines;
  final String declaredRelation;
  final String freshnessCaveat;
  final String questionsTitle;
  final List<String> questions;
  final String boundary;
  final String legalFooter;

  factory Pillar3aBeneficiaryHandoffSectionContent.fromEntry({
    required Pillar3aBeneficiarySpecialistHandoffEntry entry,
    required S l,
    required String localeName,
  }) {
    final format = DateFormat.yMMMMd(localeName);
    String civilDate(DateTime value) => format.format(
          SwissCivilTime.businessDate(value),
        );
    String optionalCivilDate(DateTime? value) =>
        value == null ? l.pillar3aBeneficiaryNotProvided : civilDate(value);

    final temporalBasisLines = switch (entry.temporalBasis) {
      Pillar3aBeneficiaryExactDates basis => <String>[
          l.pillar3aBeneficiaryTemporalBasisExact,
          '${l.pillar3aBeneficiaryDesignationEffectiveDateLabel} : '
              '${optionalCivilDate(basis.designationEffectiveDate)}',
          '${l.pillar3aBeneficiaryLastModificationDateLabel} : '
              '${optionalCivilDate(basis.lastAssignmentModificationDate)}',
        ],
      Pillar3aBeneficiaryAttestedRegime basis => <String>[
          l.pillar3aBeneficiaryTemporalBasisRegime,
          '${l.pillar3aBeneficiaryRegimeLabel} : '
              '${basis.regime == Pillar3aBeneficiaryRegime.pre20270601 ? l.pillar3aBeneficiaryRegimePre20270601 : l.pillar3aBeneficiaryRegimePost20270601}',
        ],
    };

    return Pillar3aBeneficiaryHandoffSectionContent._(
      title: l.retirementPillar3aBeneficiaryTitle,
      statusBody: l.retirementPillar3aBeneficiaryStateKnown,
      documentKindLabel: l.pillar3aBeneficiaryDocumentKindLabel,
      documentKindValue: switch (entry.documentKind) {
        Pillar3aBeneficiaryAuthorityDocumentKind.confirmationInstitutionnelle =>
          l.pillar3aBeneficiaryDocumentKindConfirmation,
        Pillar3aBeneficiaryAuthorityDocumentKind.avenantAccuse =>
          l.pillar3aBeneficiaryDocumentKindAmendment,
        Pillar3aBeneficiaryAuthorityDocumentKind.formulaireDesignationAccuse =>
          l.pillar3aBeneficiaryDocumentKindDesignationForm,
      },
      sourceDateLabel: l.pillar3aBeneficiaryHandoffSourceDateLabel,
      sourceDateValue: civilDate(entry.sourceDate),
      legalYearLabel: l.pillar3aBeneficiaryHandoffLegalYearLabel,
      legalYearValue: '${entry.legalYear}',
      temporalBasisLabel: l.pillar3aBeneficiaryTemporalBasisLabel,
      temporalBasisLines: List<String>.unmodifiable(temporalBasisLines),
      declaredRelation: l.pillar3aBeneficiaryHandoffDeclaredRelation(
        civilDate(entry.relationConfirmedAt),
      ),
      freshnessCaveat: l.pillar3aBeneficiaryHandoffFreshnessCaveat,
      questionsTitle: l.retirementPillar3aBeneficiarySpecialistSheetTitle,
      questions: List<String>.unmodifiable(<String>[
        l.pillar3aBeneficiaryHandoffQuestionCurrent,
        l.pillar3aBeneficiaryHandoffQuestionTimeline,
      ]),
      boundary: l.pillar3aBeneficiaryHandoffBoundary,
      legalFooter: l.pillar3aBeneficiaryHandoffLegalFooter,
    );
  }
}
