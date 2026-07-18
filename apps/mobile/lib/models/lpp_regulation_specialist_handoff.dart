import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';

@immutable
final class LppRegulationSpecialistHandoff {
  const LppRegulationSpecialistHandoff._({
    required this.documentKind,
    required this.sourceDate,
    required this.legalYear,
    required this.confirmedAt,
    required this.fundRelationship,
  });

  static const List<String> canonicalTopics = <String>[
    'buyback',
    'conversion',
    'flexibleRetirement',
    'disability',
    'survivors',
    'divorce',
  ];
  static const _canonicalApplicabilityQuestion = 'applicability';

  final String documentKind;
  final DateTime sourceDate;
  final int legalYear;
  final DateTime confirmedAt;
  final LppFundRelationship fundRelationship;
  String get applicabilityQuestion => _canonicalApplicabilityQuestion;
  List<String> get topics => canonicalTopics;

  static LppRegulationSpecialistHandoff? tryFromEvidence(
    SpecialistReferenceEvidence? evidence,
  ) {
    if (evidence == null ||
        evidence.kind != SpecialistReferenceKind.lppRegulation ||
        evidence.ownerKind != LppEvidenceOwnerKind.self ||
        evidence.fundRelationship == null) {
      return null;
    }
    return LppRegulationSpecialistHandoff._(
      documentKind: evidence.kind.name,
      sourceDate: evidence.sourceDate,
      legalYear: evidence.legalYear,
      confirmedAt: evidence.confirmedAt,
      fundRelationship: evidence.fundRelationship!,
    );
  }

  Map<String, dynamic> toLocalJson() => <String, dynamic>{
        'documentKind': documentKind,
        'fundRelationship': fundRelationship.wireName,
        'applicabilityQuestion': _canonicalApplicabilityQuestion,
        'sourceDate': sourceDate.toIso8601String().split('T').first,
        'legalYear': legalYear,
        'confirmedAt': confirmedAt.toUtc().toIso8601String(),
        'topics': canonicalTopics,
      };
}
