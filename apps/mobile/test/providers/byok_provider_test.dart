import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/providers/byok_provider.dart';
import 'package:mint_mobile/services/rag_service.dart';

// ── Fake RagService ──

class FakeRagService extends RagService {
  bool shouldSucceed = true;
  bool shouldThrowRagApiException = false;
  String ragApiExceptionMessage = 'Invalid API key';

  FakeRagService() : super(baseUrl: 'http://fake');

  @override
  Future<RagResponse> query({
    required String question,
    required String apiKey,
    required String provider,
    String? model,
    Map<String, dynamic>? profileContext,
    String language = 'fr',
    List<Map<String, dynamic>>? tools,
  }) async {
    if (shouldThrowRagApiException) {
      throw RagApiException(
        code: 'invalid_key',
        message: ragApiExceptionMessage,
      );
    }
    if (!shouldSucceed) {
      throw Exception('Network error');
    }
    return const RagResponse(
      answer: 'Test answer',
      sources: [],
      disclaimers: [],
      tokensUsed: 10,
    );
  }
}

void main() {
  group('ByokProvider', () {
    late FakeRagService fakeRag;
    late ByokProvider provider;

    setUp(() {
      // Use the built-in test mock for FlutterSecureStorage
      FlutterSecureStorage.setMockInitialValues({});
      fakeRag = FakeRagService();
      provider = ByokProvider(
        storage: const FlutterSecureStorage(),
        ragService: fakeRag,
      );
    });

    // ── Initial state ──

    test('initial state has correct defaults', () {
      expect(provider.provider, isNull);
      expect(provider.apiKey, isNull);
      expect(provider.isConfigured, isFalse);
      expect(provider.isLoading, isFalse);
      expect(provider.isTesting, isFalse);
      expect(provider.testError, isNull);
      expect(provider.testSuccess, isFalse);
    });

    // ── maskedKey ──

    test('maskedKey returns *** when apiKey is null', () {
      expect(provider.maskedKey, '***');
    });

    test('maskedKey returns *** when apiKey is too short', () async {
      await provider.saveKey('claude', 'short');
      // 'short' is 5 chars < 8 → returns '***'
      expect(provider.maskedKey, '***');
    });

    test('maskedKey masks correctly for valid key', () async {
      await provider.saveKey('claude', 'sk-ant-1234567890abcdef');
      // First 5 + '...' + last 4
      expect(provider.maskedKey, 'sk-an...cdef');
    });

    // ── providerLabel ──

    test('providerLabel returns correct labels for known providers', () async {
      expect(provider.providerLabel, 'Non configur\u00e9');

      await provider.saveKey('claude', 'sk-test-12345678');
      expect(provider.providerLabel, 'Claude (Anthropic)');

      await provider.saveKey('openai', 'sk-test-12345678');
      expect(provider.providerLabel, 'OpenAI');

      await provider.saveKey('mistral', 'sk-test-12345678');
      expect(provider.providerLabel, 'Mistral');
    });

    test('providerLabel returns Non configure for unknown provider', () async {
      await provider.saveKey('unknown_provider', 'sk-test-12345678');
      expect(provider.providerLabel, 'Non configur\u00e9');
    });

    // ── saveKey ──

    test('saveKey persists provider and apiKey', () async {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.saveKey('claude', 'sk-test-key-12345678');

      expect(provider.provider, 'claude');
      expect(provider.apiKey, 'sk-test-key-12345678');
      expect(provider.isConfigured, isTrue);
      expect(provider.isLoading, isFalse);
      expect(notifyCount, 2); // loading=true, then loading=false
    });

    test('saveKey resets test state from previous test', () async {
      // Set up a successful test first
      await provider.saveKey('claude', 'sk-test-key-12345678');
      fakeRag.shouldSucceed = true;
      await provider.testKey();
      expect(provider.testSuccess, isTrue);

      // saveKey should reset testSuccess and testError
      await provider.saveKey('openai', 'sk-new-key-12345678');
      expect(provider.testSuccess, isFalse);
      expect(provider.testError, isNull);
    });

    // ── loadSavedKey ──

    test('loadSavedKey restores saved key from storage', () async {
      // Pre-populate storage via saveKey
      await provider.saveKey('claude', 'sk-saved-12345678');

      // Create a new provider that reads from the same storage
      final provider2 = ByokProvider(
        storage: const FlutterSecureStorage(),
        ragService: fakeRag,
      );
      await provider2.loadSavedKey();

      expect(provider2.provider, 'claude');
      expect(provider2.apiKey, 'sk-saved-12345678');
      expect(provider2.isConfigured, isTrue);
      expect(provider2.isLoading, isFalse);
    });

    test('loadSavedKey with empty storage stays unconfigured', () async {
      await provider.loadSavedKey();

      expect(provider.provider, isNull);
      expect(provider.apiKey, isNull);
      expect(provider.isConfigured, isFalse);
    });

    test('loadSavedKey notifies listeners', () async {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.loadSavedKey();

      // loading=true, then loading=false
      expect(notifyCount, 2);
    });

    // ── clearKey ──

    test('clearKey removes key and resets state', () async {
      await provider.saveKey('claude', 'sk-test-key-12345678');
      expect(provider.isConfigured, isTrue);

      await provider.clearKey();

      expect(provider.provider, isNull);
      expect(provider.apiKey, isNull);
      expect(provider.isConfigured, isFalse);
      expect(provider.testSuccess, isFalse);
      expect(provider.testError, isNull);
      expect(provider.isLoading, isFalse);
    });

    test('clearKey on already empty state does not throw', () async {
      await provider.clearKey();

      expect(provider.isConfigured, isFalse);
      expect(provider.isLoading, isFalse);
    });

    test('clearKey notifies listeners', () async {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.clearKey();
      // loading=true, then loading=false
      expect(notifyCount, 2);
    });

    test('clearKey removes from storage so loadSavedKey finds nothing', () async {
      await provider.saveKey('claude', 'sk-test-key-12345678');
      await provider.clearKey();

      final provider2 = ByokProvider(
        storage: const FlutterSecureStorage(),
        ragService: fakeRag,
      );
      await provider2.loadSavedKey();
      expect(provider2.isConfigured, isFalse);
    });

    // ── testKey ──

    test('testKey returns false when no key configured', () async {
      final result = await provider.testKey();

      expect(result, isFalse);
      expect(provider.testError, equals(ByokError.notConfigured));
      expect(provider.testSuccess, isFalse);
    });

    test('testKey returns true on successful RAG query', () async {
      await provider.saveKey('claude', 'sk-test-key-12345678');
      fakeRag.shouldSucceed = true;

      final result = await provider.testKey();

      expect(result, isTrue);
      expect(provider.testSuccess, isTrue);
      expect(provider.testError, isNull);
      expect(provider.isTesting, isFalse);
    });

    test('testKey returns false on RagApiException', () async {
      await provider.saveKey('claude', 'sk-test-key-12345678');
      fakeRag.shouldThrowRagApiException = true;
      fakeRag.ragApiExceptionMessage = 'Invalid API key provided';

      final result = await provider.testKey();

      expect(result, isFalse);
      expect(provider.testSuccess, isFalse);
      expect(provider.testError, equals(ByokError.apiError));
      expect(provider.apiErrorMessage, 'Invalid API key provided');
      expect(provider.isTesting, isFalse);
    });

    test('testKey returns false on generic network error', () async {
      await provider.saveKey('claude', 'sk-test-key-12345678');
      fakeRag.shouldSucceed = false;
      fakeRag.shouldThrowRagApiException = false;

      final result = await provider.testKey();

      expect(result, isFalse);
      expect(provider.testSuccess, isFalse);
      expect(provider.testError, equals(ByokError.connectionError));
      expect(provider.isTesting, isFalse);
    });

    test('testKey notifies listeners during test lifecycle', () async {
      await provider.saveKey('claude', 'sk-test-key-12345678');

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      await provider.testKey();

      // isTesting=true notify, then isTesting=false notify
      expect(notifyCount, 2);
    });

    // ── resetTestState ──

    test('resetTestState clears test fields and notifies', () async {
      await provider.saveKey('claude', 'sk-test-key-12345678');
      await provider.testKey(); // Sets testSuccess = true

      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.resetTestState();

      expect(provider.testError, isNull);
      expect(provider.testSuccess, isFalse);
      expect(provider.isTesting, isFalse);
      expect(notifyCount, 1);
    });

    test('resetTestState on fresh state still notifies', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.resetTestState();
      expect(notifyCount, 1);
    });

    // ── State isolation ──

    test('two providers with separate storage have independent state', () async {
      // provider uses the shared mock storage
      await provider.saveKey('claude', 'sk-key1-12345678');
      expect(provider.isConfigured, isTrue);

      // A fresh provider that hasn't loaded will be unconfigured
      FlutterSecureStorage.setMockInitialValues({});
      final provider2 = ByokProvider(
        storage: const FlutterSecureStorage(),
        ragService: FakeRagService(),
      );
      expect(provider2.isConfigured, isFalse);
    });

    // ── Dispose ──

    test('dispose does not throw', () {
      expect(() => provider.dispose(), returnsNormally);
    });
  });
}
