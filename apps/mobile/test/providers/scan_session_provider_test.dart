import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/scan_session_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';

const _extraction = ExtractionResult(
  documentType: DocumentType.avsExtract,
  fields: [],
  overallConfidence: 0.8,
  confidenceDelta: 12,
  warnings: [],
  disclaimer: 'test',
  sources: [],
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
}
