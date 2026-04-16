// Phase 28-02 / Task 2: Flutter SSE client tests.
//
// Tests the Stream<DocumentEvent> parser and DocumentUnderstandingResult
// fromJson contract — without hitting the network. The DocumentService
// SSE method accepts an injectable http.Client factory so we feed it a
// MockClient that replays a pre-baked SSE byte stream.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/models/document_event.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/document_understanding_result.dart';

// ─────────────────────────────────────────────────────────────────────────
// Test helpers
// ─────────────────────────────────────────────────────────────────────────

/// Build a chunked SSE byte stream from a list of (event, dataMap) pairs.
Stream<List<int>> _sseStream(List<List<dynamic>> events) async* {
  for (final pair in events) {
    final name = pair[0] as String;
    final data = pair[1];
    final dataStr = data is String ? data : jsonEncode(data);
    yield utf8.encode('event: $name\n');
    yield utf8.encode('data: $dataStr\n\n');
  }
}

/// Minimal stub http.Client returning a controlled StreamedResponse.
class _StubClient extends http.BaseClient {
  _StubClient(this._stream, {this.statusCode = 200});
  final Stream<List<int>> _stream;
  final int statusCode;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    return http.StreamedResponse(
      _stream,
      statusCode,
      headers: {'content-type': 'text/event-stream'},
    );
  }
}

class _ErrorClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw const SocketExceptionLike('connection refused');
  }
}

class SocketExceptionLike implements Exception {
  final String message;
  const SocketExceptionLike(this.message);
  @override
  String toString() => 'SocketExceptionLike: $message';
}

// ─────────────────────────────────────────────────────────────────────────
// Tests
// ─────────────────────────────────────────────────────────────────────────

void main() {
  group('understandDocumentStream — SSE parsing', () {
    test('Test 1: 6 SSE events parse to 6 typed DocumentEvent emissions in order', () async {
      final byteStream = _sseStream([
        ['stage', {'stage': 'received'}],
        ['stage', {'stage': 'classify_confirmed', 'payload': {'document_class': 'lpp_certificate', 'issuer_guess': 'CPE', 'summary': 'CPE Plan Maxi.'}}],
        ['field', {'name': 'avoirLppTotal', 'value': 70377, 'confidence': 'high', 'source_text': "CHF 70'377"}],
        ['field', {'name': 'tauxConversion', 'value': 6.0, 'confidence': 'high', 'source_text': '6.0%'}],
        ['narrative', {'text': 'Plan généreux.', 'commitment': null}],
        ['done', {'render_mode': 'confirm', 'overall_confidence': 0.92, 'extraction_status': 'success', 'third_party_detected': false, 'third_party_name': null, 'fingerprint': 'fp-1', 'questions_for_user': []}],
      ]);

      final client = _StubClient(byteStream);
      final events = await DocumentService.understandDocumentStream(
        bytes: Uint8List.fromList([1, 2, 3]),
        filename: 'cert.pdf',
        token: 'tk',
        clientFactory: () => client,
      ).toList();

      expect(events, hasLength(6));
      expect(events[0], isA<StageEvent>());
      expect((events[0] as StageEvent).stage, 'received');
      expect(events[1], isA<StageEvent>());
      expect((events[1] as StageEvent).stage, 'classify_confirmed');
      expect((events[1] as StageEvent).payload?['document_class'], 'lpp_certificate');
      expect(events[2], isA<FieldEvent>());
      expect((events[2] as FieldEvent).name, 'avoirLppTotal');
      expect((events[2] as FieldEvent).value, 70377);
      expect(events[3], isA<FieldEvent>());
      expect((events[3] as FieldEvent).name, 'tauxConversion');
      expect(events[4], isA<NarrativeEvent>());
      expect((events[4] as NarrativeEvent).text, 'Plan généreux.');
      expect(events[5], isA<DoneEvent>());
      final done = events[5] as DoneEvent;
      expect(done.renderMode, 'confirm');
      expect(done.overallConfidence, 0.92);
      expect(done.fingerprint, 'fp-1');
    });

    test('Test 2: malformed SSE line is skipped without crashing the stream', () async {
      // Manually craft a stream with one malformed JSON payload sandwiched
      // between two valid frames. The parser must skip it and yield the
      // surrounding events.
      Stream<List<int>> mixedStream() async* {
        yield utf8.encode('event: stage\ndata: ${jsonEncode({'stage': 'received'})}\n\n');
        // Malformed JSON payload
        yield utf8.encode('event: field\ndata: {not valid json\n\n');
        // Valid done frame
        yield utf8.encode('event: done\ndata: ${jsonEncode({'render_mode': 'reject', 'overall_confidence': 0.0, 'extraction_status': 'rejected_local', 'third_party_detected': false, 'questions_for_user': []})}\n\n');
      }

      final client = _StubClient(mixedStream());
      final events = await DocumentService.understandDocumentStream(
        bytes: Uint8List.fromList([1]),
        filename: 'x.png',
        token: 'tk',
        clientFactory: () => client,
      ).toList();

      // Malformed line dropped, two valid frames survive.
      expect(events, hasLength(2));
      expect(events[0], isA<StageEvent>());
      expect(events[1], isA<DoneEvent>());
      expect((events[1] as DoneEvent).renderMode, 'reject');
    });

    test('Test 3: network error surfaces as Stream error (not silent close)', () async {
      final client = _ErrorClient();
      final stream = DocumentService.understandDocumentStream(
        bytes: Uint8List.fromList([1]),
        filename: 'x.png',
        token: 'tk',
        clientFactory: () => client,
      );

      Object? caught;
      try {
        await stream.toList();
      } catch (e) {
        caught = e;
      }
      expect(caught, isNotNull, reason: 'stream must surface the network error');
    });

    test('Non-200 status throws DocumentStreamException', () async {
      final client = _StubClient(_sseStream([]), statusCode: 502);
      Object? caught;
      try {
        await DocumentService.understandDocumentStream(
          bytes: Uint8List.fromList([1]),
          filename: 'x.png',
          token: 'tk',
          clientFactory: () => client,
        ).toList();
      } catch (e) {
        caught = e;
      }
      expect(caught, isA<DocumentStreamException>());
      expect((caught as DocumentStreamException).statusCode, 502);
    });
  });

  group('DocumentUnderstandingResult.fromJson', () {
    test('Test 4: round-trips all schema fields with camelCase aliases', () {
      final json = {
        'schemaVersion': '1.0',
        'documentClass': 'lpp_certificate',
        'subtype': 'cpe_plan_maxi',
        'issuerGuess': 'CPE',
        'classificationConfidence': 0.95,
        'extractedFields': [
          {
            'fieldName': 'avoirLppTotal',
            'value': 70377,
            'confidence': 'high',
            'sourceText': "CHF 70'377",
          },
          {
            'fieldName': 'tauxConversion',
            'value': 6.0,
            'confidence': 'medium',
            'sourceText': '6.0%',
          },
        ],
        'overallConfidence': 0.92,
        'extractionStatus': 'success',
        'planType': 'enveloppante',
        'planTypeWarning': null,
        'coherenceWarnings': [],
        'renderMode': 'confirm',
        'summary': 'CPE Plan Maxi.',
        'questionsForUser': ['Confirme le rachat ?'],
        'narrative': 'Plan généreux.',
        'commitmentSuggestion': {
          'when': '2026-05-01',
          'where': null,
          'ifThen': 'Si je reçois mon bonus, alors je rachète',
          'actionLabel': 'Planifier rachat',
        },
        'thirdPartyDetected': false,
        'thirdPartyName': null,
        'fingerprint': 'fp-1',
        'diffFromPrevious': null,
        'pagesProcessed': 1,
        'pagesTotal': 1,
        'pdfWarning': null,
        'costTokensIn': 800,
        'costTokensOut': 400,
      };

      final r = DocumentUnderstandingResult.fromJson(json);
      expect(r.documentClass, DocumentClass.lppCertificate);
      expect(r.issuerGuess, 'CPE');
      expect(r.subtype, 'cpe_plan_maxi');
      expect(r.classificationConfidence, 0.95);
      expect(r.extractedFields, hasLength(2));
      expect(r.extractedFields[0].fieldName, 'avoirLppTotal');
      expect(r.extractedFields[0].confidence, ConfidenceLevel.high);
      expect(r.extractedFields[1].confidence, ConfidenceLevel.medium);
      expect(r.overallConfidence, 0.92);
      expect(r.renderMode, RenderMode.confirm);
      expect(r.summary, 'CPE Plan Maxi.');
      expect(r.questionsForUser, ['Confirme le rachat ?']);
      expect(r.narrative, 'Plan généreux.');
      expect(r.commitmentSuggestion?['actionLabel'], 'Planifier rachat');
      expect(r.thirdPartyDetected, false);
      expect(r.fingerprint, 'fp-1');
      expect(r.pagesProcessed, 1);
      expect(r.costTokensIn, 800);
    });
  });
}
