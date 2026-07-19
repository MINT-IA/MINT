import 'package:flutter/foundation.dart';
import 'package:mint_mobile/models/pillar3a_beneficiary_evidence.dart';

enum Pillar3aBeneficiaryConsumerState {
  loading,
  unavailable,
  empty,
  knownCurrentDeclared,
  needsConfirmation,
  inactive,
  missingDocumentReference,
  mismatchedDocumentReference,
  invalidPresenceProvenance,
  invalid,
}

@immutable
class Pillar3aBeneficiaryRenderableDocumentMetadata {
  const Pillar3aBeneficiaryRenderableDocumentMetadata._({
    required this.documentKind,
    required this.sourceDate,
    required this.legalYear,
    required this.temporalBasis,
    required this.relation,
    required this.relationConfirmedAt,
  });

  final Pillar3aBeneficiaryAuthorityDocumentKind documentKind;
  final DateTime sourceDate;
  final int legalYear;
  final Pillar3aBeneficiaryTemporalBasis temporalBasis;
  final Pillar3aBeneficiaryRelation relation;
  final DateTime relationConfirmedAt;
}

@immutable
class Pillar3aBeneficiaryConsumerEntry {
  const Pillar3aBeneficiaryConsumerEntry._({
    required this.state,
    required this.scanContractReferenceId,
    required this.scanExpectedPreviousReferenceId,
    required Pillar3aBeneficiaryRenderableDocumentMetadata?
        renderablePreciseDocumentMetadata,
  }) : _renderablePreciseDocumentMetadata = renderablePreciseDocumentMetadata;

  final Pillar3aBeneficiaryConsumerState state;

  /// Opaque action identity. It is transport input, never display copy.
  final String scanContractReferenceId;
  final String scanExpectedPreviousReferenceId;
  final Pillar3aBeneficiaryRenderableDocumentMetadata?
      _renderablePreciseDocumentMetadata;

  Pillar3aBeneficiaryRenderableDocumentMetadata?
      get renderablePreciseDocumentMetadata =>
          _renderablePreciseDocumentMetadata;

  bool get hasRenderablePreciseDocumentMetadata =>
      _renderablePreciseDocumentMetadata != null;
}

@immutable
class Pillar3aBeneficiaryConsumerResolution {
  const Pillar3aBeneficiaryConsumerResolution._(
    this.state, [
    this.entries = const <Pillar3aBeneficiaryConsumerEntry>[],
  ]);

  const Pillar3aBeneficiaryConsumerResolution.loading()
      : this._(Pillar3aBeneficiaryConsumerState.loading);

  const Pillar3aBeneficiaryConsumerResolution.unavailable()
      : this._(Pillar3aBeneficiaryConsumerState.unavailable);

  const Pillar3aBeneficiaryConsumerResolution.empty()
      : this._(Pillar3aBeneficiaryConsumerState.empty);

  const Pillar3aBeneficiaryConsumerResolution.invalid()
      : this._(Pillar3aBeneficiaryConsumerState.invalid);

  final Pillar3aBeneficiaryConsumerState state;
  final List<Pillar3aBeneficiaryConsumerEntry> entries;

  /// Builds the consumer DTO only from a canonical evidence root.
  ///
  /// The provider remains responsible for the BND/presence state callback;
  /// this model owns the metadata allowlist and immutable aggregate shape.
  static Pillar3aBeneficiaryConsumerResolution fromQualifiedEvidenceRoot(
    Pillar3aBeneficiaryEvidenceRoot root, {
    required Pillar3aBeneficiaryConsumerState Function(
      Pillar3aBeneficiaryEvidence evidence,
    ) resolveState,
  }) {
    final entries = <Pillar3aBeneficiaryConsumerEntry>[];
    for (final evidence in root.contracts) {
      final state = resolveState(evidence);
      entries.add(
        Pillar3aBeneficiaryConsumerEntry._(
          state: state,
          scanContractReferenceId: evidence.contractReferenceId,
          scanExpectedPreviousReferenceId: evidence.referenceId,
          renderablePreciseDocumentMetadata:
              state == Pillar3aBeneficiaryConsumerState.knownCurrentDeclared
                  ? Pillar3aBeneficiaryRenderableDocumentMetadata._(
                      documentKind: evidence.documentKind,
                      sourceDate: evidence.sourceDate,
                      legalYear: evidence.legalYear,
                      temporalBasis: evidence.temporalBasis,
                      relation: evidence.relation,
                      relationConfirmedAt: evidence.relationConfirmedAt,
                    )
                  : null,
        ),
      );
    }
    return Pillar3aBeneficiaryConsumerResolution._(
      _aggregatePillar3aBeneficiaryConsumerState(entries),
      List<Pillar3aBeneficiaryConsumerEntry>.unmodifiable(entries),
    );
  }
}

Pillar3aBeneficiaryConsumerState _aggregatePillar3aBeneficiaryConsumerState(
  List<Pillar3aBeneficiaryConsumerEntry> entries,
) {
  if (entries.isEmpty) return Pillar3aBeneficiaryConsumerState.invalid;
  const priority = <Pillar3aBeneficiaryConsumerState>[
    Pillar3aBeneficiaryConsumerState.mismatchedDocumentReference,
    Pillar3aBeneficiaryConsumerState.missingDocumentReference,
    Pillar3aBeneficiaryConsumerState.invalidPresenceProvenance,
    Pillar3aBeneficiaryConsumerState.invalid,
    Pillar3aBeneficiaryConsumerState.needsConfirmation,
    Pillar3aBeneficiaryConsumerState.knownCurrentDeclared,
    Pillar3aBeneficiaryConsumerState.inactive,
  ];
  for (final state in priority) {
    if (entries.any((entry) => entry.state == state)) return state;
  }
  return Pillar3aBeneficiaryConsumerState.invalid;
}
