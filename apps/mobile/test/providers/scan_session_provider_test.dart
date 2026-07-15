import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/lpp_evidence.dart';
import 'package:mint_mobile/models/partner_accountability.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';

const _extraction = ExtractionResult(
  documentType: DocumentType.avsExtract,
  fields: [],
  overallConfidence: 0.8,
  confidenceDelta: 12,
  warnings: [],
  disclaimer: 'test',
  sources: [],
);

final _lppCandidate = LppExtractionAdapter.adapt(
  source: LppAcquisitionSource.localParser,
  sourceOverallConfidence: 0.99,
  fields: const [
    ExtractedField(
      fieldName: 'lpp_total',
      label: 'synthetic',
      value: 100000.0,
      confidence: 0.99,
      sourceText: '',
      needsReview: false,
    ),
  ],
).candidate!;
final _lppReviewExtraction = ExtractionResult(
  documentType: DocumentType.lppCertificate,
  fields: [
    ExtractedField(
      fieldName: LppEvidenceFactKey.vestedBenefitsCapitalChf.wireName,
      label: 'synthetic',
      value: 100000.0,
      confidence: 0.99,
      sourceText: '',
      needsReview: false,
    ),
  ],
  overallConfidence: 0.99,
  confidenceDelta: 27,
  warnings: const [],
  disclaimer: '',
  sources: const [],
);
final _lppAuthorization = LppAcquisitionAuthorization(
  acquisitionId: '123e4567-e89b-42d3-a456-426614174000',
  subject: LppEvidenceOwnerKind.self,
  partnerAttested: false,
  policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
  declaredAt: DateTime.utc(2026, 7, 15, 9),
  documentSha256:
      '3d1f57c984978ef98a18378c8166c1cb8ede02c03eeb6aee7e2f121dfeee3e56',
);
final _manualPartnerAuthorization = LppAcquisitionAuthorization(
  acquisitionId: '223e4567-e89b-42d3-a456-426614174000',
  subject: LppEvidenceOwnerKind.manualPartner,
  partnerAttested: true,
  policyVersion: LppAcquisitionAuthorization.currentPolicyVersion,
  declaredAt: DateTime.utc(2026, 7, 15, 9),
  documentSha256:
      '4d1f57c984978ef98a18378c8166c1cb8ede02c03eeb6aee7e2f121dfeee3e57',
  manualPartnerOwnerId: '22222222-2222-4222-8222-222222222222',
  receiptId: '11111111-1111-4111-8111-111111111111',
);
final _manualPartnerAccountability = ManualPartnerAccountabilityContext(
  receiptId: '11111111-1111-4111-8111-111111111111',
  ownerId: '22222222-2222-4222-8222-222222222222',
  expiresAt: DateTime.utc(2027, 7, 15),
  noticeVersion: 'notice-v1',
  policyVersion: 'policy-v1',
  receiptStatus: PartnerAccountabilityReceiptStatus.active,
);

void main() {
  test('scan payload resolves only through its session id', () {
    final provider = ScanSessionProvider();

    final id = provider.retainExtraction(_extraction);

    expect(provider.byId(id)?.extraction, same(_extraction));
    expect(provider.byId('missing'), isNull);
  });

  test('impact remains attached to the same session', () {
    final provider = ScanSessionProvider();
    final id = provider.retainExtraction(_extraction);

    expect(
      provider.retainImpact(
        id,
        extraction: _extraction,
        previousConfidence: 31,
      ),
      isTrue,
    );
    expect(provider.byId(id)?.previousConfidence, 31);
    expect(
      provider.retainImpact(
        'missing',
        extraction: _extraction,
        previousConfidence: 31,
      ),
      isFalse,
    );
  });

  test('old scan payloads are evicted from the bounded session store', () {
    final provider = ScanSessionProvider();
    final firstId = provider.retainExtraction(_extraction);

    for (var i = 0; i < ScanSessionProvider.maxRetainedSessions; i++) {
      provider.retainExtraction(_extraction);
    }

    expect(provider.byId(firstId), isNull);
  });

  test('LPP candidate carries its volatile authorization until impact', () {
    final provider = ScanSessionProvider();
    final id = provider.retainExtraction(
      _lppReviewExtraction,
      lppCandidate: _lppCandidate,
      lppAuthorization: _lppAuthorization,
    );

    expect(provider.byId(id)?.lppCandidate, same(_lppCandidate));
    expect(provider.byId(id)?.lppAuthorization, same(_lppAuthorization));
    expect(id, isNot(contains(_lppAuthorization.acquisitionId)));
    expect(id, isNot(contains(_lppAuthorization.documentSha256)));

    expect(
      provider.retainImpact(
        id,
        extraction: _extraction,
        previousConfidence: 31,
      ),
      isTrue,
    );
    expect(provider.byId(id)?.lppCandidate, isNull);
    expect(provider.byId(id)?.lppAuthorization, isNull);
  });

  test('LPP candidate and authorization cannot be retained independently', () {
    final provider = ScanSessionProvider();

    expect(
      () => provider.retainExtraction(
        _lppReviewExtraction,
        lppCandidate: _lppCandidate,
      ),
      throwsArgumentError,
    );
    expect(
      () => provider.retainExtraction(
        _lppReviewExtraction,
        lppAuthorization: _lppAuthorization,
      ),
      throwsArgumentError,
    );
  });

  test('manual-partner review retains one exact active volatile context', () {
    final provider = ScanSessionProvider();

    final id = provider.retainExtraction(
      _lppReviewExtraction,
      lppCandidate: _lppCandidate,
      lppAuthorization: _manualPartnerAuthorization,
      manualPartnerAccountability: _manualPartnerAccountability,
    );

    expect(
      provider.byId(id)?.manualPartnerAccountability,
      same(_manualPartnerAccountability),
    );
    expect(id, isNot(contains(_manualPartnerAccountability.receiptId)));
  });

  test('manual-partner receipt ids cannot reach review without context', () {
    final provider = ScanSessionProvider();

    expect(
      () => provider.retainExtraction(
        _lppReviewExtraction,
        lppCandidate: _lppCandidate,
        lppAuthorization: _manualPartnerAuthorization,
      ),
      throwsArgumentError,
    );
  });
}
