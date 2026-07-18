import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/authenticated_transport.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/commitment_service.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/fresh_start_service.dart';
import 'package:mint_mobile/services/household_service.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('coach preserves successful response parsing through transport',
      () async {
    final transport = _FakeTransport([
      _jsonResponse({
        'message': 'Éclairage synthétique',
        'toolCalls': [
          {
            'name': 'save_fact',
            'input': {'key': 'value'}
          },
        ],
        'sources': [
          {'title': 'Source', 'file': 'source.md', 'section': '1'},
        ],
        'disclaimers': ['Éducatif'],
        'tokensUsed': 17,
        'responseMeta': {
          'degraded': true,
          'modelUsed': 'synthetic-model',
          'budgetTier': 'soft_cap',
        },
      }),
    ]);

    final response = await CoachChatApiService(
      baseUrl: 'https://example.test/api/v1',
      transport: transport,
    ).chat(message: 'Bonjour');

    expect(response.message, 'Éclairage synthétique');
    expect(response.toolCalls.single.name, 'save_fact');
    expect(response.sources.single.file, 'source.md');
    expect(response.tokensUsed, 17);
    expect(response.degraded, isTrue);
    expect(response.modelUsed, 'synthetic-model');
    final request = transport.requests.single;
    expect(request.uri.path, '/api/v1/coach/chat');
    expect(request.timeout, const Duration(seconds: 50));
    expect((request.jsonBody as Map)['message'], 'Bonjour');
  });

  test('coach preserves no-auth failure before a network request', () async {
    final transport = _FakeTransport(const [], hasCredential: false);

    await expectLater(
      CoachChatApiService(transport: transport).chat(message: 'Bonjour'),
      throwsA(
        isA<CoachChatApiException>().having(
          (error) => error.code,
          'code',
          'no_auth',
        ),
      ),
    );
    expect(transport.requests, isEmpty);
  });

  test('document multipart keeps file field and result parsing', () async {
    final directory = await Directory.systemTemp.createTemp('mint-doc');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/certificate.pdf');
    await file.writeAsBytes(const [1, 2, 3]);
    final transport = _FakeTransport([
      _jsonResponse({
        'id': 'doc-1',
        'document_type': 'lpp_certificate',
        'extracted_fields': <String, dynamic>{},
        'confidence': 0.87,
        'fields_found': 3,
        'fields_total': 10,
        'warnings': <String>[],
      }, statusCode: 201),
    ]);

    final result = await DocumentService(
      transport: transport,
      baseUrl: 'https://example.test/api/v1',
    ).uploadDocument(file);

    expect(result.id, 'doc-1');
    expect(result.confidence, 0.87);
    final request = transport.requests.single;
    expect(request.bodyKind, AuthenticatedBodyKind.multipart);
    expect(request.multipartFields['document_type'], 'lpp_certificate');
    expect(request.multipartFiles.single.field, 'file');
    expect(request.multipartFiles.single.path, file.path);
    expect(request.headers['Idempotency-Key'], isNotEmpty);
    expect(request.timeout, const Duration(seconds: 120));
  });

  test('LPP plan multipart sends the exact zero-fact document type', () async {
    final directory = await Directory.systemTemp.createTemp('mint-lpp-plan');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/plan.pdf');
    await file.writeAsBytes(const [1, 2, 3]);
    final transport = _FakeTransport([
      _jsonResponse({
        'id': 'plan-1',
        'document_type': 'lpp_plan',
        'extracted_fields': <String, dynamic>{},
        'confidence': 0,
        'fields_found': 0,
        'fields_total': 0,
        'warnings': <String>[],
        'rag_indexed': false,
      }, statusCode: 201),
    ]);

    final result = await DocumentService(
      transport: transport,
      baseUrl: 'https://example.test/api/v1',
    ).uploadDocument(file, type: VaultDocumentType.lppPlan);

    expect(result.documentType, VaultDocumentType.lppPlan);
    expect(result.isExactLppPlanAuthority, isTrue);
    final request = transport.requests.single;
    expect(request.bodyKind, AuthenticatedBodyKind.multipart);
    expect(request.multipartFields, const {'document_type': 'lpp_plan'});
    expect(request.multipartFiles.single.field, 'file');
    expect(request.multipartFiles.single.path, file.path);
  });

  test('document list preserves wrapped and bare response parsing', () async {
    Map<String, dynamic> document(String id) => {
          'id': id,
          'document_type': 'lpp_certificate',
          'upload_date': '2026-07-17T00:00:00Z',
          'confidence': 0.9,
          'fields_found': 4,
        };
    final transport = _FakeTransport([
      _jsonResponse({
        'documents': [document('wrapped')],
      }),
      AuthenticatedResponse(
        statusCode: 200,
        body: jsonEncode([document('bare')]),
        bodyBytes: utf8.encode(jsonEncode([document('bare')])),
        headers: const {'content-type': 'application/json'},
      ),
    ]);
    final service = DocumentService(
      transport: transport,
      baseUrl: 'https://example.test/api/v1',
    );

    expect((await service.listDocuments()).single.id, 'wrapped');
    expect((await service.listDocuments()).single.id, 'bare');
  });

  test('household preserves all verbs payloads and parsing', () async {
    final transport = _FakeTransport([
      _jsonResponse({
        'household': {'id': 'h-1'},
        'members': [],
        'role': 'owner'
      }),
      _jsonResponse({'invitation_code': 'CODE'}, statusCode: 201),
      _jsonResponse({'accepted': true}),
      _jsonResponse({'revoked': true}),
      _jsonResponse({'transferred': true}),
    ]);
    final service = HouseholdService(
      transport: transport,
      baseUrl: 'https://example.test/api/v1',
    );

    expect((await service.getHousehold())!['role'], 'owner');
    expect(
        (await service
            .invitePartner('partner@example.test'))['invitation_code'],
        'CODE');
    expect((await service.acceptInvitation('CODE'))['accepted'], isTrue);
    expect((await service.revokeMember('member-1'))['revoked'], isTrue);
    expect(
        (await service.transferOwnership('member-2'))['transferred'], isTrue);
    expect(
      transport.requests.map((request) => request.method),
      [
        AuthenticatedHttpMethod.get,
        AuthenticatedHttpMethod.post,
        AuthenticatedHttpMethod.post,
        AuthenticatedHttpMethod.delete,
        AuthenticatedHttpMethod.put,
      ],
    );
    expect(
      (transport.requests[1].jsonBody as Map)['email'],
      'partner@example.test',
    );
  });

  test('commitment and fresh-start keep successful parsing', () async {
    final transport = _FakeTransport([
      _jsonResponse({
        'id': 'commitment-1',
        'status': 'active',
        'reminderAt': null,
      }, statusCode: 201),
      _jsonResponse({
        'landmarks': [
          {
            'type': 'birthday',
            'date': '2026-08-01',
            'daysUntil': 15,
            'message': 'Un jalon',
            'intent': 'review',
          },
        ],
      }),
    ]);

    final commitment = await CommitmentService(
      transport: transport,
      baseUrl: 'https://example.test/api/v1',
    ).saveCommitment(
      whenText: 'Demain',
      whereText: 'Chez moi',
      ifThenText: 'Si prêt, alors relire',
    );
    final landmarks = await FreshStartService(
      transport: transport,
      baseUrl: 'https://example.test/api/v1',
    ).fetchLandmarks();

    expect(commitment['id'], 'commitment-1');
    expect(landmarks.single.type, 'birthday');
    expect(landmarks.single.daysUntil, 15);
  });

  test('coach memory injects filtered backend sync through transport',
      () async {
    SharedPreferences.setMockInitialValues({});
    CoachMemoryService.debugConfigureSessionAuthority(
      sessionEpoch: SessionEpoch(),
      userIdReader: () async => null,
    );
    addTearDown(CoachMemoryService.debugResetSessionAuthority);
    final transport = _FakeTransport([_jsonResponse(const {})]);
    final prefs = await SharedPreferences.getInstance();
    final insight = CoachInsight(
      id: 'insight-1',
      createdAt: DateTime.utc(2026, 7, 17),
      topic: 'lpp',
      summary: 'Résumé sans donnée exacte',
      type: InsightType.fact,
      metadata: const {
        'documentType': 'lpp_certificate',
        'unsafeSalary': 120000,
      },
    );

    await CoachMemoryService.saveInsight(
      insight,
      prefs: prefs,
      transport: transport,
    );
    await _waitFor(() => transport.requests.isNotEmpty);

    final body = transport.requests.single.jsonBody as Map<String, dynamic>;
    expect(body['insight_id'], 'insight-1');
    expect(body['metadata'], {'documentType': 'lpp_certificate'});
    expect(body, isNot(contains('unsafeSalary')));
  });

  test('RAG query, vision and status preserve BYOK JSON over transport',
      () async {
    final transport = _FakeTransport([
      _jsonResponse({
        'answer': 'Réponse',
        'sources': <Object>[],
        'disclaimers': <Object>[],
        'tokens_used': 9,
      }),
      _jsonResponse({
        'extracted_fields': [
          {
            'field_name': 'avoir_lpp',
            'label': 'Avoir LPP',
            'value': 12345,
            'confidence': 0.91,
          },
        ],
        'document_type_detected': 'lpp_certificate',
        'raw_analysis': 'Analyse',
        'confidence_delta': 4,
        'disclaimers': <Object>[],
        'tokens_used': 12,
      }),
      _jsonResponse({
        'vector_store_ready': true,
        'documents_count': 42,
      }),
    ]);
    final service = RagService(
      baseUrl: 'https://example.test/api/v1',
      transport: transport,
      headers: const {'X-MINT-RAG-Mode': 'ephemeral-byok'},
    );

    final query = await service.query(
      question: 'Question',
      apiKey: 'byok-secret',
      provider: 'claude',
      model: 'synthetic-model',
      profileContext: const {'canton': 'VD'},
      tools: const [
        {'name': 'route_to_screen'}
      ],
      cashLevel: 9,
    );
    final vision = await service.extractFromImage(
      imageBase64: 'c3ludGhldGlj',
      mediaType: 'image/jpeg',
      documentType: 'lpp_certificate',
      apiKey: 'vision-byok-secret',
      provider: 'claude',
    );
    final status = await service.getStatus();

    expect(query.answer, 'Réponse');
    expect(vision.extractedFields.single.value, 12345);
    expect(status.documentsCount, 42);
    expect(transport.requests, hasLength(3));

    final queryRequest = transport.requests[0];
    expect(queryRequest.uri.path, '/api/v1/rag/query');
    expect(queryRequest.bodyKind, AuthenticatedBodyKind.json);
    expect(queryRequest.timeout, const Duration(seconds: 60));
    expect(queryRequest.headers, isNot(contains('Authorization')));
    expect(queryRequest.headers['X-MINT-RAG-Mode'], 'ephemeral-byok');
    expect(queryRequest.jsonBody, containsPair('api_key', 'byok-secret'));
    expect(queryRequest.jsonBody, containsPair('cash_level', 5));

    final visionRequest = transport.requests[1];
    expect(visionRequest.uri.path, '/api/v1/rag/vision');
    expect(visionRequest.bodyKind, AuthenticatedBodyKind.json);
    expect(visionRequest.timeout, const Duration(seconds: 120));
    expect(
      visionRequest.jsonBody,
      containsPair('api_key', 'vision-byok-secret'),
    );
    expect(
        visionRequest.jsonBody, containsPair('image_base64', 'c3ludGhldGlj'));

    final statusRequest = transport.requests[2];
    expect(statusRequest.uri.path, '/api/v1/rag/status');
    expect(statusRequest.method, AuthenticatedHttpMethod.get);
    expect(statusRequest.timeout, const Duration(seconds: 10));
  });

  test('RAG rejects a missing session before transport send', () async {
    final transport = _FakeTransport(const [], hasCredential: false);
    final service = RagService(transport: transport);

    await expectLater(
      service.query(
        question: 'Question',
        apiKey: 'byok-secret',
        provider: 'claude',
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.errorCode,
          'errorCode',
          ApiErrorCode.authenticationRequired,
        ),
      ),
    );
    expect(transport.requests, isEmpty);
  });
}

AuthenticatedResponse _jsonResponse(
  Object body, {
  int statusCode = 200,
}) {
  final encoded = jsonEncode(body);
  return AuthenticatedResponse(
    statusCode: statusCode,
    body: encoded,
    bodyBytes: utf8.encode(encoded),
    headers: const {'content-type': 'application/json'},
  );
}

final class _FakeTransport implements AuthenticatedTransport {
  _FakeTransport(this._responses, {this.hasCredential = true});

  final List<AuthenticatedResponse> _responses;
  final bool hasCredential;
  final List<AuthenticatedRequest> requests = [];

  @override
  AuthenticatedOperation beginOperation() => _FakeOperation(this);
}

final class _FakeOperation implements AuthenticatedOperation {
  _FakeOperation(this.transport);

  final _FakeTransport transport;
  bool _authorized = false;

  @override
  Future<void> requireSession() async {
    if (!transport.hasCredential) {
      throw ApiException.authenticationRequired();
    }
    _authorized = true;
  }

  @override
  Future<AuthenticatedResponse> send(AuthenticatedRequest request) async {
    if (!_authorized) await requireSession();
    transport.requests.add(request);
    if (transport._responses.isEmpty) throw StateError('No fake response');
    return transport._responses.removeAt(0);
  }
}

Future<void> _waitFor(bool Function() predicate) async {
  for (var i = 0; i < 20; i++) {
    if (predicate()) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('Timed out waiting for async consumer');
}
