import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_consumer.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';

/// Read-only specialist projection of exact, fully resolved 3a authority.
///
/// The consumer resolution remains the authority boundary. This model never
/// receives the strict root, BND identifiers, document bytes, or beneficiary
/// identity/order/share data.
@immutable
final class Pillar3aBeneficiarySpecialistHandoff {
  Pillar3aBeneficiarySpecialistHandoff._(
    List<Pillar3aBeneficiarySpecialistHandoffEntry> entries,
  ) : entries = List<Pillar3aBeneficiarySpecialistHandoffEntry>.unmodifiable(
          entries,
        );

  final List<Pillar3aBeneficiarySpecialistHandoffEntry> entries;

  static Pillar3aBeneficiarySpecialistHandoff? tryFromConsumerResolution(
    Pillar3aBeneficiaryConsumerResolution resolution,
  ) {
    if (resolution.state !=
            Pillar3aBeneficiaryConsumerState.knownCurrentDeclared ||
        resolution.entries.isEmpty) {
      return null;
    }

    final projected = <Pillar3aBeneficiarySpecialistHandoffEntry>[];
    for (final entry in resolution.entries) {
      final metadata = entry.renderablePreciseDocumentMetadata;
      switch (entry.state) {
        case Pillar3aBeneficiaryConsumerState.knownCurrentDeclared:
          if (metadata == null ||
              metadata.relation !=
                  Pillar3aBeneficiaryRelation.currentActiveUnpaid) {
            return null;
          }
          break;
        case Pillar3aBeneficiaryConsumerState.inactive:
          if (metadata != null) return null;
          continue;
        case Pillar3aBeneficiaryConsumerState.loading:
        case Pillar3aBeneficiaryConsumerState.unavailable:
        case Pillar3aBeneficiaryConsumerState.empty:
        case Pillar3aBeneficiaryConsumerState.needsConfirmation:
        case Pillar3aBeneficiaryConsumerState.missingDocumentReference:
        case Pillar3aBeneficiaryConsumerState.mismatchedDocumentReference:
        case Pillar3aBeneficiaryConsumerState.invalidPresenceProvenance:
        case Pillar3aBeneficiaryConsumerState.invalid:
          return null;
      }
      projected.add(
        Pillar3aBeneficiarySpecialistHandoffEntry._(
          documentKind: metadata.documentKind,
          sourceDate: metadata.sourceDate,
          legalYear: metadata.legalYear,
          temporalBasis: metadata.temporalBasis,
          relationConfirmedAt: metadata.relationConfirmedAt,
        ),
      );
    }
    if (projected.isEmpty) return null;
    return Pillar3aBeneficiarySpecialistHandoff._(projected);
  }

  Map<String, Object?> toLocalJson() => <String, Object?>{
        'entries': entries.map((entry) => entry.toLocalJson()).toList(),
      };
}

@immutable
final class Pillar3aBeneficiarySpecialistHandoffEntry {
  const Pillar3aBeneficiarySpecialistHandoffEntry._({
    required this.documentKind,
    required this.sourceDate,
    required this.legalYear,
    required this.temporalBasis,
    required this.relationConfirmedAt,
  });

  final Pillar3aBeneficiaryAuthorityDocumentKind documentKind;
  final DateTime sourceDate;
  final int legalYear;
  final Pillar3aBeneficiaryTemporalBasis temporalBasis;
  final DateTime relationConfirmedAt;

  Map<String, Object?> toLocalJson() => <String, Object?>{
        'documentKind': documentKind.name,
        'sourceDate': sourceDate.toIso8601String().split('T').first,
        'legalYear': legalYear,
        'temporalBasis': temporalBasis.toJson(),
        'relationConfirmedAt': relationConfirmedAt.toUtc().toIso8601String(),
      };
}
