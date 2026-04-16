// Phase 28-03 — Local image classifier tests.
//
// We avoid the real ML Kit MethodChannel by injecting a fake labeler that
// returns a deterministic List<MockLabel>. The classifier under test is the
// pure-Dart decision logic on top of that labeler.

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/local_image_classifier.dart';

void main() {
  group('LocalImageClassifier.shouldRejectAsNonFinancial', () {
    final imgBytes = Uint8List.fromList(List.filled(64, 0xAB));

    test('rejects high-confidence Food label', () async {
      final classifier = LocalImageClassifier(
        labelerFactory: () => _FakeLabeler(const [
          ScoredLabel(label: 'Food', confidence: 0.92),
          ScoredLabel(label: 'Plate', confidence: 0.81),
        ]),
      );

      final decision = await classifier.shouldRejectAsNonFinancial(imgBytes);

      expect(decision.reject, isTrue);
      expect(decision.reason, 'food');
      expect(decision.confidence, closeTo(0.92, 0.001));
    });

    test('does NOT reject when top label is Document', () async {
      final classifier = LocalImageClassifier(
        labelerFactory: () => _FakeLabeler(const [
          ScoredLabel(label: 'Document', confidence: 0.85),
          ScoredLabel(label: 'Paper', confidence: 0.70),
        ]),
      );

      final decision = await classifier.shouldRejectAsNonFinancial(imgBytes);

      expect(decision.reject, isFalse);
      expect(decision.reason, isNull);
    });

    test('does NOT reject below confidence threshold (0.7)', () async {
      final classifier = LocalImageClassifier(
        labelerFactory: () => _FakeLabeler(const [
          ScoredLabel(label: 'Selfie', confidence: 0.45),
          ScoredLabel(label: 'Person', confidence: 0.40),
        ]),
      );

      final decision = await classifier.shouldRejectAsNonFinancial(imgBytes);

      expect(decision.reject, isFalse);
    });

    test('empty labels = fail-open (let backend decide)', () async {
      final classifier = LocalImageClassifier(
        labelerFactory: () => _FakeLabeler(const []),
      );

      final decision = await classifier.shouldRejectAsNonFinancial(imgBytes);

      expect(decision.reject, isFalse);
    });

    test('PDF magic bytes return false immediately (no labeling on PDFs)',
        () async {
      // %PDF-1.4 header
      final pdfBytes = Uint8List.fromList(
          [0x25, 0x50, 0x44, 0x46, 0x2D, 0x31, 0x2E, 0x34, 0x0A, 0x00]);
      final fake = _FakeLabeler(const [
        ScoredLabel(label: 'Food', confidence: 0.99),
      ]);
      final classifier = LocalImageClassifier(labelerFactory: () => fake);

      final decision = await classifier.shouldRejectAsNonFinancial(pdfBytes);

      expect(decision.reject, isFalse);
      expect(fake.processCallCount, 0,
          reason: 'PDF must short-circuit before invoking labeler');
    });

    test('labeler error -> fail-open (never wrongly reject a legit doc)',
        () async {
      final classifier = LocalImageClassifier(
        labelerFactory: () => _ThrowingLabeler(),
      );

      final decision = await classifier.shouldRejectAsNonFinancial(imgBytes);

      expect(decision.reject, isFalse);
    });
  });
}

class _FakeLabeler implements ImageLabelerPort {
  _FakeLabeler(this._labels);
  final List<ScoredLabel> _labels;
  int processCallCount = 0;

  @override
  Future<List<ScoredLabel>> process(Uint8List bytes) async {
    processCallCount++;
    return _labels;
  }

  @override
  Future<void> close() async {}
}

class _ThrowingLabeler implements ImageLabelerPort {
  @override
  Future<List<ScoredLabel>> process(Uint8List bytes) async {
    throw StateError('mlkit channel unavailable');
  }

  @override
  Future<void> close() async {}
}
