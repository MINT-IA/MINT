import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/document_parser/lpp_extraction_adapter.dart';

@immutable
class ScanSessionPayload {
  final ExtractionResult extraction;
  final LppExtractionCandidate? lppCandidate;
  final TaxExtractionCandidate? taxCandidate;
  final int? previousConfidence;

  const ScanSessionPayload({
    required this.extraction,
    this.lppCandidate,
    this.taxCandidate,
    this.previousConfidence,
  });

  ScanSessionPayload withImpact({
    required ExtractionResult extraction,
    required int previousConfidence,
  }) {
    return ScanSessionPayload(
      extraction: _withoutSourceText(extraction),
      lppCandidate: null,
      taxCandidate: null,
      previousConfidence: previousConfidence,
    );
  }
}

ExtractionResult _withoutSourceText(ExtractionResult extraction) {
  return ExtractionResult(
    documentType: extraction.documentType,
    fields: extraction.fields
        .map(
          (field) => ExtractedField(
            fieldName: field.fieldName,
            label: field.label,
            value: field.value,
            confidence: field.confidence,
            sourceText: '',
            needsReview: field.needsReview,
            profileField: field.profileField,
            labelCode: field.labelCode,
          ),
        )
        .toList(growable: false),
    overallConfidence: extraction.overallConfidence,
    confidenceDelta: extraction.confidenceDelta,
    warnings: extraction.warnings,
    disclaimer: extraction.disclaimer,
    sources: extraction.sources,
    diagnostics: extraction.diagnostics,
    planType: extraction.planType,
    planTypeWarning: extraction.planTypeWarning,
    coherenceWarnings: extraction.coherenceWarnings,
  );
}

/// In-memory boundary for domain data used by the scan route sequence.
///
/// Route locations carry only [scanSessionId]. A cold deep link or process
/// restart intentionally resolves to the existing recovery state instead of
/// trying to reconstruct an unconfirmed OCR result from navigation payloads.
class ScanSessionProvider extends ChangeNotifier {
  static const maxRetainedSessions = 5;
  final Map<String, ScanSessionPayload> _sessions = {};
  int _nextId = 0;

  String retainExtraction(
    ExtractionResult extraction, {
    LppExtractionCandidate? lppCandidate,
    TaxExtractionCandidate? taxCandidate,
  }) {
    final id = '${DateTime.now().microsecondsSinceEpoch}-${_nextId++}';
    _sessions[id] = ScanSessionPayload(
      extraction: extraction,
      lppCandidate: lppCandidate,
      taxCandidate: taxCandidate,
    );
    while (_sessions.length > maxRetainedSessions) {
      _sessions.remove(_sessions.keys.first);
    }
    notifyListeners();
    return id;
  }

  ScanSessionPayload? byId(String? id) {
    if (id == null || id.isEmpty) return null;
    return _sessions[id];
  }

  bool retainImpact(
    String id, {
    required ExtractionResult extraction,
    required int previousConfidence,
  }) {
    final current = _sessions[id];
    if (current == null) return false;
    _sessions[id] = current.withImpact(
      extraction: extraction,
      previousConfidence: previousConfidence,
    );
    notifyListeners();
    return true;
  }

  void discard(String id) {
    if (_sessions.remove(id) != null) {
      notifyListeners();
    }
  }
}
