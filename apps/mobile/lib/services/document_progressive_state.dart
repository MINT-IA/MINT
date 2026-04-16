// Phase 28-04 — Progressive document understanding state.
//
// Consumes Stream<DocumentEvent> emitted by Phase 28-02's
// `DocumentService.understandDocumentStream(...)` and exposes incremental
// state to the UI so widgets can render "Tom Hanks reading" UX in real
// time (stages → fields one by one → narrative → done) instead of waiting
// for a single batched result.
//
// Owned by `document_scan_screen.dart` via a ChangeNotifierProvider. UI
// widgets observe `notifyListeners()` after every event.

import 'package:flutter/foundation.dart';

import 'package:mint_mobile/models/document_event.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';

class DocumentProgressiveState extends ChangeNotifier {
  // ── Lifecycle / stage ──
  String? stage; // last seen stage name ("received", "preflight", ...)
  String? summary; // payload.summary from classify_confirmed
  String? documentClass; // raw API string ("lpp_certificate")
  String? subtype;
  String? issuerGuess;
  double? classificationConfidence;

  // ── Field reveals ──
  final List<FieldEvent> fields = [];

  // ── Narrative ──
  String? narrative;
  Map<String, dynamic>? commitment;

  // ── Final state ──
  RenderMode? renderMode;
  double? overallConfidence;
  String? extractionStatus;
  bool thirdPartyDetected = false;
  String? thirdPartyName;
  String? fingerprint;
  Map<String, dynamic>? diffFromPrevious;
  List<String> questionsForUser = const [];

  // ── Status flags ──
  bool isComplete = false;
  String? error;
  bool _disposed = false;

  /// Subscribe to a stream of DocumentEvent and update state incrementally.
  /// Safe to call once per state instance — for retry, instantiate a new state.
  Future<void> consume(Stream<DocumentEvent> stream) async {
    try {
      await for (final ev in stream) {
        if (_disposed) return;
        switch (ev) {
          case StageEvent():
            stage = ev.stage;
            final payload = ev.payload;
            if (payload != null) {
              summary ??= payload['summary'] as String?;
              documentClass ??= payload['document_class'] as String? ??
                  payload['documentClass'] as String?;
              subtype ??= payload['subtype'] as String?;
              issuerGuess ??= payload['issuer_guess'] as String? ??
                  payload['issuerGuess'] as String?;
              final cc = payload['classification_confidence'] ??
                  payload['classificationConfidence'];
              if (cc is num) classificationConfidence = cc.toDouble();
            }
          case FieldEvent():
            fields.add(ev);
          case NarrativeEvent():
            narrative = ev.text;
            commitment = ev.commitment;
          case DoneEvent():
            try {
              renderMode = RenderMode.values.byName(ev.renderMode);
            } catch (_) {
              renderMode = RenderMode.narrative;
            }
            overallConfidence = ev.overallConfidence;
            extractionStatus = ev.extractionStatus;
            thirdPartyDetected = ev.thirdPartyDetected;
            thirdPartyName = ev.thirdPartyName;
            fingerprint = ev.fingerprint;
            diffFromPrevious = ev.diffFromPrevious;
            questionsForUser = ev.questionsForUser;
            if (ev.error != null) error = ev.error;
            isComplete = true;
        }
        notifyListeners();
      }
      // Stream closed without DoneEvent → mark complete defensively.
      if (!isComplete) {
        isComplete = true;
        renderMode ??= RenderMode.narrative;
        notifyListeners();
      }
    } catch (e) {
      if (_disposed) return;
      error = e.toString();
      isComplete = true;
      renderMode ??= RenderMode.reject;
      notifyListeners();
    }
  }

  /// Convert the accumulated state into a `DocumentUnderstandingResult` for
  /// downstream widgets that prefer the unified contract (e.g. the
  /// `ExtractionReviewSheet`).
  DocumentUnderstandingResult toResult() {
    return DocumentUnderstandingResult.fromJson({
      'documentClass': documentClass ?? 'unknown',
      'subtype': subtype,
      'issuerGuess': issuerGuess,
      'classificationConfidence': classificationConfidence ?? 0.0,
      'extractedFields': fields
          .map((f) => {
                'fieldName': f.name,
                'value': f.value,
                'confidence': f.confidence,
                'sourceText': f.sourceText,
              })
          .toList(),
      'overallConfidence': overallConfidence ?? 0.0,
      'extractionStatus': extractionStatus ?? 'partial',
      'renderMode': renderMode?.name ?? 'narrative',
      'summary': summary,
      'questionsForUser': questionsForUser,
      'narrative': narrative,
      'commitmentSuggestion': commitment,
      'thirdPartyDetected': thirdPartyDetected,
      'thirdPartyName': thirdPartyName,
      'fingerprint': fingerprint,
      'diffFromPrevious': diffFromPrevious,
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
