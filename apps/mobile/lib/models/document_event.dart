// Phase 28-02 — typed SSE events emitted by the backend
// `stream_understanding` async generator and consumed by Flutter's
// `DocumentService.understandDocumentStream`.
//
// Sealed (Dart 3) so that downstream `switch` expressions in the UI layer
// (Phase 28-04) get exhaustiveness checking when wiring the four
// render_mode bubbles.

/// Base type for every SSE event the document pipeline can emit.
sealed class DocumentEvent {
  const DocumentEvent();
}

/// `event: stage` — pipeline lifecycle marker (received, preflight,
/// classify_confirmed, ...).
class StageEvent extends DocumentEvent {
  final String stage;
  final Map<String, dynamic>? payload;

  const StageEvent({required this.stage, this.payload});

  @override
  String toString() => 'StageEvent(stage: $stage, payload: $payload)';
}

/// `event: field` — one extracted field, ordered by emotional importance.
class FieldEvent extends DocumentEvent {
  final String name;
  final dynamic value;
  final String confidence; // "high" | "medium" | "low"
  final String sourceText;

  const FieldEvent({
    required this.name,
    required this.value,
    required this.confidence,
    required this.sourceText,
  });

  @override
  String toString() =>
      'FieldEvent(name: $name, value: $value, confidence: $confidence)';
}

/// `event: narrative` — coach-style commentary, optional commitment device.
class NarrativeEvent extends DocumentEvent {
  final String text;
  final Map<String, dynamic>? commitment;

  const NarrativeEvent({required this.text, this.commitment});

  @override
  String toString() => 'NarrativeEvent(text: $text)';
}

/// `event: done` — terminal event carrying render_mode + Document Memory diff.
class DoneEvent extends DocumentEvent {
  final String renderMode; // "confirm" | "ask" | "narrative" | "reject"
  final double overallConfidence;
  final String? extractionStatus;
  final Map<String, dynamic>? diffFromPrevious;
  final bool thirdPartyDetected;
  final String? thirdPartyName;
  final String? fingerprint;
  final List<String> questionsForUser;
  final String? error;

  const DoneEvent({
    required this.renderMode,
    required this.overallConfidence,
    this.extractionStatus,
    this.diffFromPrevious,
    this.thirdPartyDetected = false,
    this.thirdPartyName,
    this.fingerprint,
    this.questionsForUser = const [],
    this.error,
  });

  @override
  String toString() =>
      'DoneEvent(renderMode: $renderMode, overallConfidence: $overallConfidence)';
}

/// Parse a single `(event, data)` pair into the typed event. Throws a
/// FormatException on unknown event names so the caller can decide whether
/// to surface or skip.
DocumentEvent parseDocumentEvent(String event, Map<String, dynamic> data) {
  switch (event) {
    case 'stage':
      return StageEvent(
        stage: (data['stage'] as String?) ?? 'unknown',
        payload: data['payload'] as Map<String, dynamic>?,
      );
    case 'field':
      return FieldEvent(
        name: (data['name'] as String?) ?? '',
        value: data['value'],
        confidence: (data['confidence'] as String?) ?? 'medium',
        sourceText: (data['source_text'] as String?) ??
            (data['sourceText'] as String?) ??
            '',
      );
    case 'narrative':
      return NarrativeEvent(
        text: (data['text'] as String?) ?? '',
        commitment: data['commitment'] as Map<String, dynamic>?,
      );
    case 'done':
      final qs = data['questions_for_user'] ?? data['questionsForUser'];
      return DoneEvent(
        renderMode: (data['render_mode'] as String?) ??
            (data['renderMode'] as String?) ??
            'narrative',
        overallConfidence: (data['overall_confidence'] is num)
            ? (data['overall_confidence'] as num).toDouble()
            : (data['overallConfidence'] is num)
                ? (data['overallConfidence'] as num).toDouble()
                : 0.0,
        extractionStatus: data['extraction_status'] as String? ??
            data['extractionStatus'] as String?,
        diffFromPrevious: (data['diff_from_previous'] ?? data['diffFromPrevious'])
            as Map<String, dynamic>?,
        thirdPartyDetected: (data['third_party_detected'] as bool?) ??
            (data['thirdPartyDetected'] as bool?) ??
            false,
        thirdPartyName: data['third_party_name'] as String? ??
            data['thirdPartyName'] as String?,
        fingerprint: data['fingerprint'] as String?,
        questionsForUser: qs is List ? qs.map((e) => e.toString()).toList() : const [],
        error: data['error'] as String?,
      );
    default:
      throw FormatException('Unknown SSE event type: $event');
  }
}
