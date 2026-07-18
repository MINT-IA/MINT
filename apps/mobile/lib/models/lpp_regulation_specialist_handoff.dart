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
  });

  static const List<String> canonicalTopics = <String>[
    'buyback',
    'conversion',
    'flexibleRetirement',
    'disability',
    'survivors',
    'divorce',
  ];

  final String documentKind;
  final DateTime sourceDate;
  final int legalYear;
  final DateTime confirmedAt;
  List<String> get topics => canonicalTopics;

  static LppRegulationSpecialistHandoff? tryFromEvidence(
    SpecialistReferenceEvidence? evidence,
  ) {
    if (evidence == null ||
        evidence.kind != SpecialistReferenceKind.lppRegulation ||
        evidence.ownerKind != LppEvidenceOwnerKind.self) {
      return null;
    }
    return LppRegulationSpecialistHandoff._(
      documentKind: evidence.kind.name,
      sourceDate: evidence.sourceDate,
      legalYear: evidence.legalYear,
      confirmedAt: evidence.confirmedAt,
    );
  }

  Map<String, dynamic> toLocalJson() => <String, dynamic>{
        'documentKind': documentKind,
        'sourceDate': sourceDate.toIso8601String().split('T').first,
        'legalYear': legalYear,
        'confirmedAt': confirmedAt.toUtc().toIso8601String(),
        'topics': canonicalTopics,
      };
}
