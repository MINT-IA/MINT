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

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart'
    as mlkit;
import 'package:path_provider/path_provider.dart';

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
  /// Labels (Google's base label-map names) that disqualify an image as a
  /// financial document. Exact strings — ML Kit returns capitalised English
  /// labels regardless of UI locale.
  static const Set<String> blockLabels = {
    'Food', 'Plate', 'Drink', 'Beverage',
    'Selfie', 'Person',
    'Cat', 'Dog', 'Pet',
    'Landscape', 'Sky', 'Mountain', 'Sea', 'Beach',
    'Plant', 'Flower', 'Tree',
    'Cartoon', 'Meme', 'Sticker',
    // Note: we deliberately do NOT include "Screenshot" because banking app
    // screenshots are valid input and trigger narrative mode server-side.
  };

  static const double confidenceThreshold = 0.7;
  static const int topNToInspect = 3;

  final ImageLabelerPort Function() labelerFactory;

  /// Default constructor wires the real ML Kit labeler.
  LocalImageClassifier({ImageLabelerPort Function()? labelerFactory})
      : labelerFactory = labelerFactory ?? _defaultLabelerFactory;

  Future<RejectDecision> shouldRejectAsNonFinancial(Uint8List bytes) async {
    if (_isPdf(bytes)) return RejectDecision.accept;
    if (kIsWeb) return RejectDecision.accept; // labeler unavailable on web
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
      // Fail-open: never wrongly reject a legitimate document.
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

  static ImageLabelerPort _defaultLabelerFactory() => _MlKitLabeler();
}

class _MlKitLabeler implements ImageLabelerPort {
  late final mlkit.ImageLabeler _labeler = mlkit.ImageLabeler(
    options: mlkit.ImageLabelerOptions(confidenceThreshold: 0.5),
  );

  @override
  Future<List<ScoredLabel>> process(Uint8List bytes) async {
    final tmpDir = await getTemporaryDirectory();
    final path =
        '${tmpDir.path}/mint_classifier_${DateTime.now().microsecondsSinceEpoch}.bin';
    final file = File(path);
    try {
      await file.writeAsBytes(bytes, flush: true);
      final input = InputImage.fromFilePath(path);
      final raw = await _labeler.processImage(input);
      return raw
          .map((l) => ScoredLabel(label: l.label, confidence: l.confidence))
          .toList(growable: false);
    } finally {
      try {
        if (await file.exists()) await file.delete();
      } catch (_) {/* best effort */}
    }
  }

  @override
  Future<void> close() => _labeler.close();
}
