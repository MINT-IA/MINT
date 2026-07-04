import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';

void main() {
  test('keeps review and confirmed scan data behind a stable session id', () {
    final provider = ScanSessionProvider();
    const review = ExtractionResult(
      documentType: DocumentType.lppCertificate,
      fields: [],
      overallConfidence: 0.72,
      confidenceDelta: 12,
      warnings: [],
      disclaimer: 'test',
      sources: ['unit'],
    );
    const confirmed = ExtractionResult(
      documentType: DocumentType.lppCertificate,
      fields: [],
      overallConfidence: 0.91,
      confidenceDelta: 18,
      warnings: [],
      disclaimer: 'test',
      sources: ['unit'],
    );

    final id = provider.createReviewSession(review);
    expect(id, isNotEmpty);
    expect(provider.sessionFor(id)?.reviewResult, same(review));
    expect(provider.sessionFor(id)?.confirmedResult, isNull);

    provider.confirm(
      id: id,
      result: confirmed,
      previousConfidence: 44,
    );

    final session = provider.sessionFor(id);
    expect(session?.reviewResult, same(review));
    expect(session?.confirmedResult, same(confirmed));
    expect(session?.previousConfidence, 44);
  });
}
