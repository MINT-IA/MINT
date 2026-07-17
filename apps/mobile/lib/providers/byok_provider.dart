import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/services/session_epoch.dart';

/// Error codes for BYOK operations.
///
/// The provider sets an error code; the UI layer translates it to a
/// localized message via `AppLocalizations`.
enum ByokError {
  /// Key save failed (secure storage write error).
  saveFailed,

  /// Provider or API key not configured before testing.
  notConfigured,

  /// Network / connection error during key test.
  connectionError,

  /// API returned a typed machine error (see [ByokProvider.apiErrorCode]).
  apiError,
}

/// Manages BYOK (Bring Your Own Key) API key storage and state.
///
/// Uses flutter_secure_storage for secure persistence of the user's
/// LLM API key. The key never leaves the device except when sent
/// directly to the LLM provider via the RAG backend proxy.
class ByokProvider extends ChangeNotifier {
  static const String _providerKey = 'byok_provider';
  static const String _apiKeyKey = 'byok_api_key';

  final FlutterSecureStorage _storage;
  final RagService _ragService;
  final SessionEpoch _sessionEpoch;

  String? _provider;
  String? _apiKey;
  bool _isConfigured = false;
  bool _isLoading = false;
  bool _isTesting = false;
  ByokError? _testError;
  RagErrorCode? _apiErrorCode;
  bool _testSuccess = false;

  ByokProvider({
    FlutterSecureStorage? storage,
    RagService? ragService,
    SessionEpoch? sessionEpoch,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _ragService = ragService ?? RagService(),
        _sessionEpoch = sessionEpoch ?? SessionEpoch();

  // Getters
  String? get provider => _provider;
  String? get apiKey => _apiKey;
  bool get isConfigured => _isConfigured;
  bool get isLoading => _isLoading;
  bool get isTesting => _isTesting;
  ByokError? get testError => _testError;

  /// Machine identity returned by RAG when [testError] is [ByokError.apiError].
  RagErrorCode? get apiErrorCode => _apiErrorCode;
  bool get testSuccess => _testSuccess;

  /// Masked display of the API key (e.g. "sk-...abc1")
  String get maskedKey {
    if (_apiKey == null || _apiKey!.length < 8) return '***';
    return '${_apiKey!.substring(0, 5)}...${_apiKey!.substring(_apiKey!.length - 4)}';
  }

  /// Human-readable label for the current provider
  String get providerLabel {
    switch (_provider) {
      case 'claude':
        return 'Claude (Anthropic)';
      case 'openai':
        return 'OpenAI';
      case 'mistral':
        return 'Mistral';
      default:
        return 'Non configur\u00e9';
    }
  }

  /// Load saved key from secure storage on init.
  Future<void> loadSavedKey() async {
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    notifyListeners();

    try {
      final provider = await _storage.read(key: _providerKey);
      guard.assertCurrent();
      final apiKey = await _storage.read(key: _apiKeyKey);
      guard.assertCurrent();
      _provider = provider;
      _apiKey = apiKey;
      _isConfigured =
          _provider != null && _apiKey != null && _apiKey!.isNotEmpty;
    } on SessionEpochInvalidated {
      return;
    } catch (e) {
      guard.assertCurrent();
      if (kDebugMode) {
        debugPrint('ByokProvider: Error loading saved key: $e');
      }
      _isConfigured = false;
    } finally {
      try {
        guard.assertCurrent();
        _isLoading = false;
        notifyListeners();
      } on SessionEpochInvalidated {
        // Session termination owns the cleared state.
      }
    }
  }

  /// Save a new API key + provider to secure storage.
  Future<void> saveKey(String provider, String apiKey) async {
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    _testError = null;
    _apiErrorCode = null;
    _testSuccess = false;
    notifyListeners();

    try {
      await _sessionEpoch.runGuardedPersistence(guard, () async {
        await _storage.write(key: _providerKey, value: provider);
        await _storage.write(key: _apiKeyKey, value: apiKey);
      });
      guard.assertCurrent();
      _provider = provider;
      _apiKey = apiKey;
      _isConfigured = true;
    } on SessionEpochInvalidated {
      rethrow;
    } catch (e) {
      guard.assertCurrent();
      if (kDebugMode) {
        debugPrint('ByokProvider: Error saving key: $e');
      }
      _testError = ByokError.saveFailed;
    } finally {
      try {
        guard.assertCurrent();
        _isLoading = false;
        notifyListeners();
      } on SessionEpochInvalidated {
        // Session termination owns the cleared state.
      }
    }
  }

  /// Clear saved key from secure storage.
  Future<void> clearKey() async {
    final guard = _sessionEpoch.capture();
    _isLoading = true;
    notifyListeners();

    try {
      await _sessionEpoch.runGuardedPersistence(guard, () async {
        await _storage.delete(key: _providerKey);
        await _storage.delete(key: _apiKeyKey);
      });
      guard.assertCurrent();
      _provider = null;
      _apiKey = null;
      _isConfigured = false;
      _testSuccess = false;
      _testError = null;
      _apiErrorCode = null;
    } on SessionEpochInvalidated {
      rethrow;
    } catch (e) {
      guard.assertCurrent();
      if (kDebugMode) {
        debugPrint('ByokProvider: Error clearing key: $e');
      }
    } finally {
      try {
        guard.assertCurrent();
        _isLoading = false;
        notifyListeners();
      } on SessionEpochInvalidated {
        // Session termination owns the cleared state.
      }
    }
  }

  /// Clears the in-memory API key after the coordinator purged secure storage.
  void clearSessionMemoryAfterPurge() {
    _provider = null;
    _apiKey = null;
    _isConfigured = false;
    _isLoading = false;
    _isTesting = false;
    _testError = null;
    _apiErrorCode = null;
    _testSuccess = false;
    notifyListeners();
  }

  /// Test the key by making a simple query to the RAG backend.
  /// Returns true if the key works, false otherwise.
  Future<bool> testKey() async {
    final guard = _sessionEpoch.capture();
    if (_apiKey == null || _provider == null) {
      _testError = ByokError.notConfigured;
      _apiErrorCode = null;
      _testSuccess = false;
      notifyListeners();
      return false;
    }

    _isTesting = true;
    _testError = null;
    _apiErrorCode = null;
    _testSuccess = false;
    notifyListeners();

    try {
      await _ragService.query(
        question: 'What is the Swiss third pillar?',
        apiKey: _apiKey!,
        provider: _provider!,
        language: 'en',
      );
      guard.assertCurrent();
      _testSuccess = true;
      _testError = null;
      _apiErrorCode = null;
      return true;
    } on SessionEpochInvalidated {
      return false;
    } on RagApiException catch (e) {
      guard.assertCurrent();
      _testSuccess = false;
      _testError = ByokError.apiError;
      _apiErrorCode = e.errorCode;
      return false;
    } catch (e) {
      guard.assertCurrent();
      _testSuccess = false;
      _testError = ByokError.connectionError;
      _apiErrorCode = null;
      return false;
    } finally {
      try {
        guard.assertCurrent();
        _isTesting = false;
        notifyListeners();
      } on SessionEpochInvalidated {
        // Session termination owns the cleared state.
      }
    }
  }

  /// Reset test state (useful when navigating away).
  void resetTestState() {
    _testError = null;
    _apiErrorCode = null;
    _testSuccess = false;
    _isTesting = false;
    notifyListeners();
  }
}
