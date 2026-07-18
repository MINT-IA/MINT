import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';

/// Metadata-only projection of one resolved capital-notice deadline.
///
/// Construction requires the separately resolved regulation evidence because
/// the capital notice alone cannot establish the declared current-fund
/// relationship. No reference identifier or document payload crosses this
/// boundary.
@immutable
final class LppCapitalNoticeSpecialistHandoff {
  const LppCapitalNoticeSpecialistHandoff._({
    required this.documentKind,
    required this.sourceDate,
    required this.legalYear,
    required this.confirmedAt,
    required this.deadlineDate,
    required this.fundRelationship,
  });

  static const List<String> canonicalTopics = <String>[
    'submissionForm',
    'receiptProof',
    'changeRevocation',
  ];

  final String documentKind;
  final DateTime sourceDate;
  final int legalYear;
  final DateTime confirmedAt;
  final DateTime deadlineDate;
  final LppFundRelationship fundRelationship;
  List<String> get topics => canonicalTopics;

  static LppCapitalNoticeSpecialistHandoff? tryFromResolvedEvidence({
    required SpecialistReferenceEvidence? capitalNoticeEvidence,
    required SpecialistReferenceEvidence? regulationEvidence,
  }) {
    if (capitalNoticeEvidence == null ||
        capitalNoticeEvidence.kind !=
            SpecialistReferenceKind.lppCapitalNotice ||
        capitalNoticeEvidence.ownerKind != LppEvidenceOwnerKind.self ||
        capitalNoticeEvidence.deadlineDate == null ||
        regulationEvidence == null ||
        regulationEvidence.kind != SpecialistReferenceKind.lppRegulation ||
        regulationEvidence.ownerKind != LppEvidenceOwnerKind.self ||
        regulationEvidence.fundRelationship !=
            LppFundRelationship.currentFund ||
        regulationEvidence.sourceDate != capitalNoticeEvidence.sourceDate ||
        regulationEvidence.legalYear != capitalNoticeEvidence.legalYear) {
      return null;
    }

    return LppCapitalNoticeSpecialistHandoff._(
      documentKind: capitalNoticeEvidence.kind.name,
      sourceDate: capitalNoticeEvidence.sourceDate,
      legalYear: capitalNoticeEvidence.legalYear,
      confirmedAt: capitalNoticeEvidence.confirmedAt,
      deadlineDate: capitalNoticeEvidence.deadlineDate!,
      fundRelationship: regulationEvidence.fundRelationship!,
    );
  }

  Map<String, dynamic> toLocalJson() => <String, dynamic>{
        'documentKind': documentKind,
        'sourceDate': sourceDate.toIso8601String().split('T').first,
        'legalYear': legalYear,
        'confirmedAt': confirmedAt.toUtc().toIso8601String(),
        'deadlineDate': deadlineDate.toIso8601String().split('T').first,
        'fundRelationship': fundRelationship.wireName,
      };
}
