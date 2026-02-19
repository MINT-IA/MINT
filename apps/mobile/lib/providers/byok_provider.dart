import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:mint_mobile/services/rag_service.dart';

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

  String? _provider;
  String? _apiKey;
  bool _isConfigured = false;
  bool _isLoading = false;
  bool _isTesting = false;
  String? _testError;
  bool _testSuccess = false;

  ByokProvider({
    FlutterSecureStorage? storage,
    RagService? ragService,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _ragService = ragService ?? RagService();

  // Getters
  String? get provider => _provider;
  String? get apiKey => _apiKey;
  bool get isConfigured => _isConfigured;
  bool get isLoading => _isLoading;
  bool get isTesting => _isTesting;
  String? get testError => _testError;
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
    _isLoading = true;
    notifyListeners();

    try {
      _provider = await _storage.read(key: _providerKey);
      _apiKey = await _storage.read(key: _apiKeyKey);
      _isConfigured = _provider != null && _apiKey != null && _apiKey!.isNotEmpty;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ByokProvider: Error loading saved key: $e');
      }
      _isConfigured = false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save a new API key + provider to secure storage.
  Future<void> saveKey(String provider, String apiKey) async {
    _isLoading = true;
    _testError = null;
    _testSuccess = false;
    notifyListeners();

    try {
      await _storage.write(key: _providerKey, value: provider);
      await _storage.write(key: _apiKeyKey, value: apiKey);
      _provider = provider;
      _apiKey = apiKey;
      _isConfigured = true;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ByokProvider: Error saving key: $e');
      }
      _testError = 'Erreur lors de la sauvegarde.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Clear saved key from secure storage.
  Future<void> clearKey() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _storage.delete(key: _providerKey);
      await _storage.delete(key: _apiKeyKey);
      _provider = null;
      _apiKey = null;
      _isConfigured = false;
      _testSuccess = false;
      _testError = null;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('ByokProvider: Error clearing key: $e');
      }
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Test the key by making a simple query to the RAG backend.
  /// Returns true if the key works, false otherwise.
  Future<bool> testKey() async {
    if (_apiKey == null || _provider == null) {
      _testError = 'Configure d\'abord un fournisseur et une cl\u00e9.';
      _testSuccess = false;
      notifyListeners();
      return false;
    }

    _isTesting = true;
    _testError = null;
    _testSuccess = false;
    notifyListeners();

    try {
      await _ragService.query(
        question: 'Qu\'est-ce que le 3e pilier en Suisse ?',
        apiKey: _apiKey!,
        provider: _provider!,
        language: 'fr',
      );
      _testSuccess = true;
      _testError = null;
      return true;
    } on RagApiException catch (e) {
      _testSuccess = false;
      _testError = e.message;
      return false;
    } catch (e) {
      _testSuccess = false;
      _testError = 'Erreur de connexion. V\u00e9rifie ta connexion internet.';
      return false;
    } finally {
      _isTesting = false;
      notifyListeners();
    }
  }

  /// Reset test state (useful when navigating away).
  void resetTestState() {
    _testError = null;
    _testSuccess = false;
    _isTesting = false;
    notifyListeners();
  }
}
