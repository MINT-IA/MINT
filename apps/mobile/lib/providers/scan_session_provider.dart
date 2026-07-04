import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';

@immutable
class ScanSession {
  final String id;
  final ExtractionResult reviewResult;
  final ExtractionResult? confirmedResult;
  final int? previousConfidence;
  final DateTime createdAt;

  const ScanSession({
    required this.id,
    required this.reviewResult,
    required this.createdAt,
    this.confirmedResult,
    this.previousConfidence,
  });

  ScanSession copyWith({
    ExtractionResult? confirmedResult,
    int? previousConfidence,
  }) {
    return ScanSession(
      id: id,
      reviewResult: reviewResult,
      createdAt: createdAt,
      confirmedResult: confirmedResult ?? this.confirmedResult,
      previousConfidence: previousConfidence ?? this.previousConfidence,
    );
  }
}

class ScanSessionProvider extends ChangeNotifier {
  final Map<String, ScanSession> _sessions = {};

  ScanSession? sessionFor(String? id) {
    if (id == null || id.trim().isEmpty) return null;
    return _sessions[id.trim()];
  }

  String createReviewSession(ExtractionResult result) {
    final id = 'scan_${DateTime.now().microsecondsSinceEpoch}';
    _sessions[id] = ScanSession(
      id: id,
      reviewResult: result,
      createdAt: DateTime.now().toUtc(),
    );
    notifyListeners();
    return id;
  }

  void confirm({
    required String id,
    required ExtractionResult result,
    required int previousConfidence,
  }) {
    final existing = _sessions[id];
    if (existing == null) {
      _sessions[id] = ScanSession(
        id: id,
        reviewResult: result,
        confirmedResult: result,
        previousConfidence: previousConfidence,
        createdAt: DateTime.now().toUtc(),
      );
    } else {
      _sessions[id] = existing.copyWith(
        confirmedResult: result,
        previousConfidence: previousConfidence,
      );
    }
    notifyListeners();
  }
}
