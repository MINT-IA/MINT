// Phase 28-03 — Local image classifier (pre-reject).
//
// Purpose: before paying ~3500 Vision tokens + ~15s latency to send a photo
// to the backend, label it locally with Google ML Kit Image Labeling. If the
// top labels with confidence >= 0.7 fall in the BLOCK list (food, selfie,
// landscape, pet, meme, screenshot_social…), short-circuit upstream with
// `RejectDecision.reject = true` and surface a friendly "ce n'est pas un
// document financier" bubble in the chat.
//
// Doctrine:
//   - Fail-open: any classifier error or empty label set returns `reject:false`.
//     Better to pay one wrong Vision call than to wrongly reject a real LPP cert.
//   - PDFs are never labeled (image labelers don't understand them); short-
//     circuit on the %PDF magic header to save the labeler round-trip.
//   - The labeler is injected through `ImageLabelerPort` so tests can mock the
//     ML Kit MethodChannel.

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;

// 2026-04-17 — Stubbed (was google_mlkit_image_labeling). The iOS pod graph
// wants MLKitCore 9.x for ImageLabeling but MLKitCore 7.x for
// TextRecognition 7.x (keept for OCR accuracy on Swiss LPP certs). This is
// structural at the CocoaPods level — image labeling is disabled until we
// migrate TextRecognition to MLKit 9.x. Fail-open keeps scanning usable;
// the backend Vision endpoint filters non-financial images on its side.

/// Single labeled prediction returned by an [ImageLabelerPort].
class ScoredLabel {
  final String label;
  final double confidence;

  const ScoredLabel({required this.label, required this.confidence});
}

/// Decision returned by [LocalImageClassifier.shouldRejectAsNonFinancial].
class RejectDecision {
  final bool reject;
  final String? reason;
  final double? confidence;

  const RejectDecision({
    required this.reject,
    this.reason,
    this.confidence,
  });

  static const accept = RejectDecision(reject: false);
}

/// Port abstraction over the ML Kit labeler so unit tests don't touch the
/// real platform channel.
abstract class ImageLabelerPort {
  Future<List<ScoredLabel>> process(Uint8List bytes);
  Future<void> close();
}

class LocalImageClassifier {
  /// Label names kept for tests that still reference the constant; unused
  /// at runtime while the classifier is stubbed.
  static const Set<String> blockLabels = {
    'Food', 'Plate', 'Drink', 'Beverage',
    'Selfie', 'Person',
    'Cat', 'Dog', 'Pet',
    'Landscape', 'Sky', 'Mountain', 'Sea', 'Beach',
    'Plant', 'Flower', 'Tree',
    'Cartoon', 'Meme', 'Sticker',
  };

  static const double confidenceThreshold = 0.7;
  static const int topNToInspect = 3;

  final ImageLabelerPort Function() labelerFactory;

  /// Constructor preserved for call-sites and tests. The default factory
  /// returns a no-op labeler so the `shouldRejectAsNonFinancial` contract
  /// still holds without the MLKit image-labeling pod.
  LocalImageClassifier({ImageLabelerPort Function()? labelerFactory})
      : labelerFactory = labelerFactory ?? _defaultLabelerFactory;

  /// Stubbed: always accepts. Backend Vision filters non-financial images.
  /// Tests that inject a [labelerFactory] still exercise the branching.
  Future<RejectDecision> shouldRejectAsNonFinancial(Uint8List bytes) async {
    if (_isPdf(bytes)) return RejectDecision.accept;
    if (kIsWeb) return RejectDecision.accept;
    if (bytes.isEmpty) return RejectDecision.accept;

    final labeler = labelerFactory();
    try {
      final labels = await labeler.process(bytes);
      for (final l in labels.take(topNToInspect)) {
        if (l.confidence >= confidenceThreshold &&
            blockLabels.contains(l.label)) {
          return RejectDecision(
            reject: true,
            reason: l.label.toLowerCase(),
            confidence: l.confidence,
          );
        }
      }
      return RejectDecision.accept;
    } catch (_) {
      return RejectDecision.accept;
    } finally {
      try {
        await labeler.close();
      } catch (_) {/* swallow */}
    }
  }

  static bool _isPdf(Uint8List bytes) {
    if (bytes.length < 4) return false;
    return bytes[0] == 0x25 && // %
        bytes[1] == 0x50 && // P
        bytes[2] == 0x44 && // D
        bytes[3] == 0x46; // F
  }

  static ImageLabelerPort _defaultLabelerFactory() => _NoopLabeler();
}

/// No-op labeler used while the MLKit image-labeling pod is disabled.
/// Emits an empty label set so every image is accepted (fail-open).
class _NoopLabeler implements ImageLabelerPort {
  @override
  Future<List<ScoredLabel>> process(Uint8List bytes) async => const [];

  @override
  Future<void> close() async {}
}
