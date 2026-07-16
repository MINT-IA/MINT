import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/document_provider.dart';
import 'package:mint_mobile/providers/timeline_provider.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _MemoryProfilePersistence
    implements LppProfilePersistence, TaxProfilePersistence {
  _MemoryProfilePersistence(Map<String, dynamic> answers)
      : answers = Map<String, dynamic>.from(answers);

  final Map<String, dynamic> answers;
  Map<String, dynamic>? lastSaved;

  @override
  Future<Map<String, dynamic>> loadAnswers() async =>
      Map<String, dynamic>.from(answers);

  @override
  Future<void> saveAnswers(Map<String, dynamic> nextAnswers) async {
    lastSaved = Map<String, dynamic>.from(nextAnswers);
    answers
      ..clear()
      ..addAll(lastSaved!);
  }
}

LppAcquisitionAuthorization _selfAuthorization(DateTime declaredAt) {
  return LppAcquisitionAuthorization(
    acquisitionId: '123e4567-e89b-42d3-a456-426614174000',
    subject: LppEvidenceOwnerKind.self,
    partnerAttested: false,
    policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
    declaredAt: declaredAt,
    documentSha256:
        '1111111111111111111111111111111111111111111111111111111111111111',
  );
}

String _mobileLibSource() {
  final files = Directory('lib')
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'))
      .toList()
    ..sort((left, right) => left.path.compareTo(right.path));
  return files.map((file) => file.readAsStringSync()).join('\n');
}

String? _balancedBodyAt(String source, int openingBrace) {
  if (openingBrace < 0 || source[openingBrace] != '{') return null;
  var depth = 0;
  for (var index = openingBrace; index < source.length; index += 1) {
    if (source[index] == '{') {
      depth += 1;
    } else if (source[index] == '}') {
      depth -= 1;
      if (depth == 0) return source.substring(openingBrace, index + 1);
    }
  }
  return null;
}

String? _classBody(String source, String className) {
  final match = RegExp(
    '\\b(?:final\\s+)?class\\s+$className\\b',
  ).firstMatch(source);
  if (match == null) return null;
  return _balancedBodyAt(source, source.indexOf('{', match.end));
}

String? _toJsonBody(String classBody) {
  final methodIndex = classBody.indexOf('toJson()');
  if (methodIndex < 0) return null;
  return _balancedBodyAt(classBody, classBody.indexOf('{', methodIndex));
}

Future<dynamic> _tryRecordConfirmedLppReview(
  DocumentProvider provider,
  dynamic receipt,
) async {
  try {
    return await (provider as dynamic).recordConfirmedLppReview(receipt);
  } on NoSuchMethodError {
    return null;
  }
}

Future<bool> _tryHydrateReferences(DocumentProvider provider) async {
  try {
    await (provider as dynamic).hydrateReferences();
    return true;
  } on NoSuchMethodError {
    return false;
  }
}

Future<dynamic> _tryReferenceById(
  DocumentProvider provider,
  String referenceId,
) async {
  try {
    return await (provider as dynamic).byId(referenceId);
  } on NoSuchMethodError {
    return null;
  }
}

Future<bool> _tryBindLedger(
  Object provider,
  CoachProfileProvider ledger,
) async {
  try {
    await (provider as dynamic).bindLedger(ledger);
    return true;
  } on NoSuchMethodError {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    FeatureFlags.typedLppEvidence = true;
  });

  tearDown(() {
    FeatureFlags.typedLppEvidence = false;
  });

  test('strict self review persists selected facts before returning receipt',
      () async {
    final now = DateTime.utc(2026, 7, 16, 12);
    final sourceDate = DateTime.utc(2026, 6, 30);
    final persistence = _MemoryProfilePersistence(<String, dynamic>{
      'q_birth_year': 1981,
      'q_canton': 'VD',
      'q_civil_status': 'celibataire',
      'q_has_pension_fund': 'yes',
    });
    final provider = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(provider.dispose);
    await provider.loadFromWizard();

    const selectedFactKeys = <LppEvidenceFactKey>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf,
      LppEvidenceFactKey.disabilityPensionAnnualChf,
    };
    final authorization =
        _selfAuthorization(now.subtract(const Duration(hours: 1)));
    const rawSentinel = 'RAW_OCR_BND05_DEATH_CAPITAL_91000';
    final candidateFacts = <LppEvidenceFactKey, LppReviewedFact>{
      LppEvidenceFactKey.vestedBenefitsCapitalChf: const LppReviewedFact(
        value: 125000,
        unit: LppEvidenceUnit.chf,
      ),
      LppEvidenceFactKey.disabilityPensionAnnualChf: const LppReviewedFact(
        value: 24000,
        unit: LppEvidenceUnit.chfPerYear,
      ),
      LppEvidenceFactKey.deathCapitalLumpSumChf: const LppReviewedFact(
        value: 91000,
        unit: LppEvidenceUnit.chfLumpSum,
      ),
    };
    final syntheticCandidateEnvelope = <String, Object?>{
      'facts': candidateFacts,
      'sourceText': rawSentinel,
      'acquisitionId': authorization.acquisitionId,
      'documentSha256': authorization.documentSha256,
    };
    expect(
      (syntheticCandidateEnvelope['facts']
              as Map<LppEvidenceFactKey, LppReviewedFact>)
          .keys,
      contains(LppEvidenceFactKey.deathCapitalLumpSumChf),
      reason: 'the candidate contains an unconfirmed death-capital value',
    );
    final dynamic receipt = await (provider as dynamic).acceptLppReview(
      LppReviewConfirmation(
        authorization: authorization,
        sourceDate: sourceDate,
        facts: <LppEvidenceFactKey, LppReviewedFact>{
          for (final key in selectedFactKeys) key: candidateFacts[key]!,
        },
      ),
    );

    final persistedSerialization =
        persistence.lastSaved!['_coach_lpp_evidence_v1'] as String;
    final persistedRoot = LppEvidenceRoot.fromJsonString(
      persistedSerialization,
    );
    expect(persistedRoot, isNotNull);
    expect(persistedRoot!.manualPartner, isNull);
    expect(persistedRoot.self, isNotNull);
    expect(persistedRoot.self!.facts.keys.toSet(), selectedFactKeys);
    expect(
      persistedRoot.self!.facts,
      isNot(contains(LppEvidenceFactKey.deathCapitalLumpSumChf)),
      reason: 'an unconfirmed death benefit must not enter the strict root',
    );
    for (final fact in persistedRoot.self!.facts.values) {
      expect(fact.source, 'certificate');
      expect(fact.sourceDate, sourceDate);
      expect(fact.ownerKind, LppEvidenceOwnerKind.self);
      expect(fact.profileOwnerId, fact.actorProfileOwnerId);
    }
    expect(
      persistedRoot.self!.facts.values
          .map((fact) => fact.updatedAt.toUtc())
          .toSet(),
      hasLength(1),
      reason: 'one accepted review must stamp every selected fact atomically',
    );
    for (final forbidden in <String>[
      rawSentinel,
      authorization.acquisitionId,
      authorization.documentSha256,
      'sourceText',
    ]) {
      expect(
        persistedSerialization,
        isNot(contains(forbidden)),
        reason: '$forbidden must not cross the strict persisted boundary',
      );
    }

    expect(
      receipt,
      isNotNull,
      reason: 'acceptLppReview must return an immutable LppReviewReceipt only '
          'after the strict root is durably accepted',
    );
    expect(receipt.snapshotId, persistedRoot.self!.snapshotId);
    expect(receipt.ownerKind, LppEvidenceOwnerKind.self);
    expect(receipt.factKeys, selectedFactKeys);
    expect(receipt.factKeys, isA<Set<LppEvidenceFactKey>>());
    expect(
      () => receipt.factKeys.add(LppEvidenceFactKey.deathCapitalLumpSumChf),
      throwsUnsupportedError,
      reason: 'receipt fact keys must be immutable',
    );
  });

  test(
      'confirmed reference survives restart then fails closed on snapshot swap',
      () async {
    final now = DateTime.utc(2026, 7, 16, 14);
    final sourceDate = DateTime.utc(2026, 6, 30);
    final persistence = _MemoryProfilePersistence(<String, dynamic>{
      'q_birth_year': 1981,
      'q_canton': 'VD',
      'q_civil_status': 'celibataire',
      'q_has_pension_fund': 'yes',
    });
    final writer = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(writer.dispose);
    await writer.loadFromWizard();

    final dynamic receipt = await (writer as dynamic).acceptLppReview(
      LppReviewConfirmation(
        authorization:
            _selfAuthorization(now.subtract(const Duration(minutes: 5))),
        sourceDate: sourceDate,
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
            value: 125000,
            unit: LppEvidenceUnit.chf,
          ),
          LppEvidenceFactKey.disabilityPensionAnnualChf: LppReviewedFact(
            value: 24000,
            unit: LppEvidenceUnit.chfPerYear,
          ),
        },
      ),
    );

    final documentWriter = DocumentProvider();
    addTearDown(documentWriter.dispose);
    final dynamic reference =
        await _tryRecordConfirmedLppReview(documentWriter, receipt);
    expect(
      reference,
      isNotNull,
      reason: 'a confirmed strict review must create one opaque reference',
    );
    final referenceId = reference.referenceId as String;

    final coldLedger = CoachProfileProvider(
      taxProfilePersistence: persistence,
      lppProfilePersistence: persistence,
      now: () => now,
    );
    addTearDown(coldLedger.dispose);
    await coldLedger.loadFromWizard();
    final coldDocuments = DocumentProvider();
    addTearDown(coldDocuments.dispose);
    expect(await _tryBindLedger(coldDocuments, coldLedger), isTrue);
    expect(await _tryHydrateReferences(coldDocuments), isTrue);
    final dynamic resolved =
        await _tryReferenceById(coldDocuments, referenceId);
    expect(resolved, isNotNull);
    expect(resolved.referenceId, referenceId);
    expect(resolved.snapshotId, receipt.snapshotId);
    expect(resolved.ownerKind, LppEvidenceOwnerKind.self);

    final timeline = TimelineProvider();
    addTearDown(timeline.dispose);
    expect(await _tryBindLedger(timeline, coldLedger), isTrue);
    await timeline.refresh();
    final nodes = timeline.months.expand((month) => month.nodes).toList();
    final documentNodes =
        nodes.where((node) => node.id == 'document_$referenceId').toList();
    expect(documentNodes, hasLength(1));
    expect(documentNodes.single.deepLink, '/documents/$referenceId');

    await (coldLedger as dynamic).acceptLppReview(
      LppReviewConfirmation(
        authorization:
            _selfAuthorization(now.subtract(const Duration(minutes: 1))),
        sourceDate: sourceDate,
        facts: const <LppEvidenceFactKey, LppReviewedFact>{
          LppEvidenceFactKey.vestedBenefitsCapitalChf: LppReviewedFact(
            value: 131000,
            unit: LppEvidenceUnit.chf,
          ),
          LppEvidenceFactKey.disabilityPensionAnnualChf: LppReviewedFact(
            value: 25200,
            unit: LppEvidenceUnit.chfPerYear,
          ),
        },
      ),
    );
    await timeline.refresh();
    final nodesAfterSnapshotSwap =
        timeline.months.expand((month) => month.nodes).toList();
    expect(
      nodesAfterSnapshotSwap
          .where((node) => node.id == 'document_$referenceId'),
      isEmpty,
      reason: 'a reference bound to the replaced snapshot must fail closed',
    );
  });

  test('production exposes the named BND-05 reference bridge APIs', () {
    final source = _mobileLibSource();

    for (final symbol in <String>[
      'LppReviewReceipt',
      'DocumentReferenceStore',
      'ConfirmedDocumentReference',
      'recordConfirmedLppReview',
      'hydrateReferences',
      'byId(',
      'bindLedger',
    ]) {
      expect(
        source.contains(symbol),
        isTrue,
        reason: '$symbol must exist on the named BND-05 bridge surface',
      );
    }
  });

  test('confirmed reference JSON is the exact raw-free allowlist', () {
    final source = _mobileLibSource();
    final referenceClass = _classBody(source, 'ConfirmedDocumentReference');
    expect(
      referenceClass != null,
      isTrue,
      reason: 'ConfirmedDocumentReference must own the persisted payload',
    );
    final payloadBody = _toJsonBody(referenceClass!);
    expect(payloadBody != null, isTrue);

    final payloadKeys = RegExp(r'''['"]([A-Za-z][A-Za-z0-9]*)['"]\s*:''')
        .allMatches(payloadBody!)
        .map((match) => match.group(1)!)
        .toSet();
    expect(
      payloadKeys,
      <String>{
        'referenceId',
        'kind',
        'snapshotId',
        'ownerKind',
        'confirmedAt',
      },
      reason: 'the reference payload is an exact allowlist, never a second '
          'financial ledger',
    );
    expect(payloadBody, isNot(matches(RegExp(r'RAW_[A-Z0-9_]+'))));
    for (final forbidden in <String>[
      'rawOcr',
      'rawBytes',
      'acquisitionId',
      'documentSha256',
      'sha256',
      'sourceText',
      'scanSessionId',
      "'value'",
      '"value"',
    ]) {
      expect(
        payloadBody,
        isNot(contains(forbidden)),
        reason: '$forbidden must never enter a confirmed reference payload',
      );
    }
  });

  test('timeline abandons the orphan uploaded-documents preference', () {
    final source =
        File('lib/providers/timeline_provider.dart').readAsStringSync();
    expect(source.contains('_uploaded_documents'), isFalse);
  });

  test('timeline document nodes deep-link to document detail', () {
    final source =
        File('lib/providers/timeline_provider.dart').readAsStringSync();
    expect(
      source.contains('/documents/'),
      isTrue,
      reason: 'confirmed reference nodes must reopen /documents/<referenceId>',
    );
  });
}
