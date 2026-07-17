import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/models/coach_insight.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/commitment_service.dart';
import 'package:mint_mobile/services/document_service.dart';
import 'package:mint_mobile/services/fresh_start_service.dart';
import 'package:mint_mobile/services/household_service.dart';
import 'package:mint_mobile/services/memory/coach_memory_service.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    ApiService.debugResetHttpClient();
    ApiService.debugResetSessionTerminationHandler();
  });

  test('every migrated consumer awaits its one terminal 401 purge', () async {
    final entries = <String, Future<Object?> Function()>{
      'coach': () => CoachChatApiService().chat(message: 'Bonjour'),
      'document': () => DocumentService().listDocuments(),
      'household': () => HouseholdService().getHousehold(),
      'commitment': () => CommitmentService().getCommitments(),
      'fresh-start': () => FreshStartService().fetchLandmarks(),
      'coach-memory': () => CoachMemoryService.debugSyncInsightToBackend(
            CoachInsight(
              id: 'synthetic-insight',
              createdAt: DateTime.utc(2026, 7, 17),
              topic: 'lpp',
              summary: 'Résumé synthétique',
              type: InsightType.fact,
            ),
            transport: ApiService.authenticatedTransport,
          ),
      'rag-query': () => RagService().query(
            question: 'Question synthétique',
            apiKey: 'byok-synthetic',
            provider: 'claude',
          ),
      'rag-vision': () => RagService().extractFromImage(
            imageBase64: 'c3ludGhldGlj',
            mediaType: 'image/jpeg',
            documentType: 'lpp_certificate',
            apiKey: 'byok-synthetic',
            provider: 'claude',
          ),
      'rag-status': () => RagService().getStatus(),
    };

    for (final entry in entries.entries) {
      FlutterSecureStorage.setMockInitialValues({});
      await AuthService.saveToken(
        'access-old',
        'user-1',
        'user@mint.test',
      );
      ApiService.debugResetHttpClient();
      ApiService.debugResetSessionTerminationHandler();
      final requestSeen = Completer<void>();
      ApiService.debugUseHttpClient(MockClient((_) async {
        if (!requestSeen.isCompleted) requestSeen.complete();
        return http.Response('{"detail":"expired"}', 401);
      }));
      final purgeGate = Completer<void>();
      var purgeCalls = 0;
      final binding = ApiService.bindSessionTerminationHandler(
        () {
          purgeCalls++;
          return purgeGate.future;
        },
        sessionEpoch: SessionEpoch(),
      );

      var completed = false;
      final operation = entry.value().then<void>(
            (_) => completed = true,
            onError: (_) => completed = true,
          );
      await requestSeen.future;
      await Future<void>.delayed(Duration.zero);

      expect(completed, isFalse, reason: entry.key);
      expect(purgeCalls, 1, reason: entry.key);
      purgeGate.complete();
      await operation;
      expect(completed, isTrue, reason: entry.key);
      binding.dispose();
    }
  });

  test('RAG cannot send after synchronous logout invalidation', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await AuthService.saveToken('access-old', 'user-a', 'a@mint.test');
    final epoch = SessionEpoch();
    final binding = ApiService.bindSessionTerminationHandler(
      () async {},
      sessionEpoch: epoch,
    );
    addTearDown(binding.dispose);
    var requests = 0;
    ApiService.debugUseHttpClient(MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    }));

    epoch.beginTermination();
    await expectLater(
      RagService().getStatus(),
      throwsA(isA<SessionEpochInvalidated>()),
    );
    expect(requests, 0);
  });
}
