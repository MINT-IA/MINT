/// SLM Download Service — manages on-device model lifecycle.
///
/// Handles downloading, verifying, and managing the Gemma 3n E4B model
/// for on-device inference via flutter_gemma.
///
/// Privacy guarantee: model runs 100% on-device, zero network
/// traffic during inference.
///
/// References:
///   - flutter_gemma 0.12.x (pub.dev/packages/flutter_gemma)
///   - Gemma 3n E4B IT model (~2.3 GB)
///   - HuggingFace model hosting
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Download progress callback.
typedef DownloadProgressCallback = void Function(
  double progress,
  int downloadedBytes,
  int totalBytes,
);

/// State of the model download.
enum DownloadState {
  /// Not downloaded.
  notStarted,

  /// Download in progress.
  downloading,

  /// Download paused (can resume).
  paused,

  /// Download complete, model verified.
  completed,

  /// Download failed.
  failed,
}

/// Information about the on-device model.
class ModelInfo {
  /// Model identifier.
  final String modelId;

  /// Human-readable name.
  final String displayName;

  /// Model file size in bytes (~2.3 GB).
  final int sizeBytes;

  /// Model version tag.
  final String version;

  /// Whether the model is downloaded and ready.
  final bool isReady;

  /// Local file path (null if not downloaded).
  final String? localPath;

  const ModelInfo({
    required this.modelId,
    required this.displayName,
    required this.sizeBytes,
    required this.version,
    required this.isReady,
    this.localPath,
  });
}

/// Manages the on-device SLM model download and storage.
///
/// Uses flutter_gemma's built-in model installer to download
/// the Gemma 3n E4B IT model from HuggingFace.
///
/// Usage:
/// ```dart
/// final service = SlmDownloadService.instance;
/// final info = await service.getModelInfo();
///
/// if (!info.isReady) {
///   await service.downloadModel(onProgress: (p, dl, total) {
///     print('${(p * 100).toStringAsFixed(1)}%');
///   });
/// }
/// ```
class SlmDownloadService {
  SlmDownloadService._();
  static final SlmDownloadService instance = SlmDownloadService._();

  // ═══════════════════════════════════════════════════════════════
  //  Constants
  // ═══════════════════════════════════════════════════════════════

  /// HuggingFace model URL (Gemma 3n E4B IT in .task format).
  /// In production, configure via remote config.
  static const String _defaultModelUrl =
      'https://huggingface.co/google/gemma-3n-E4B-it-litert-preview/resolve/main/gemma-3n-E4B-it-int4.task';

  /// Build-time override for the model URL (CI/CD).
  ///
  /// Example:
  ///   --dart-define=SLM_MODEL_URL=https://cdn.mint.ch/models/gemma.task
  static const String _buildModelUrl = String.fromEnvironment('SLM_MODEL_URL');

  /// Build-time HuggingFace token for gated repositories.
  ///
  /// Example:
  ///   --dart-define=HUGGINGFACE_TOKEN=hf_xxx
  static const String _buildHfToken =
      String.fromEnvironment('HUGGINGFACE_TOKEN');

  /// Model identifier as registered by flutter_gemma.
  ///
  /// Derived from the URL filename to stay in sync automatically:
  ///   Uri.parse(url).pathSegments.last → 'gemma3n-E4B-it-multi.task'
  /// This MUST match the URL filename for isModelInstalled() to work.
  static String get modelUrl => _buildModelUrl.trim().isNotEmpty
      ? _buildModelUrl.trim()
      : _defaultModelUrl;

  static String get modelId => Uri.parse(modelUrl).pathSegments.last;

  /// Expected model size (~2.3 GB).
  static const int _expectedSizeBytes = 2400000000;

  /// Model version for cache invalidation.
  static const String _modelVersion = '1.0.0';

  /// SharedPreferences key for model version tracking.
  static const String _prefKeyVersion = 'slm_model_version';

  // ═══════════════════════════════════════════════════════════════
  //  State
  // ═══════════════════════════════════════════════════════════════

  DownloadState _state = DownloadState.notStarted;

  /// Current download state.
  DownloadState get state => _state;

  /// Stream of download state changes.
  final _stateController = StreamController<DownloadState>.broadcast();
  Stream<DownloadState> get stateStream => _stateController.stream;

  /// Safe emit — avoids crash if controller was closed.
  void _emitState() {
    if (!_stateController.isClosed) _stateController.add(_state);
  }

  /// Download progress (0.0 to 1.0).
  double _progress = 0.0;
  double get progress => _progress;

  /// Last error message (null if no error).
  String? _lastError;
  String? get lastError => _lastError;

  String? _lastErrorRaw;
  String? get lastErrorRaw => _lastErrorRaw;

  String? _runtimeHfToken;

  bool _pluginInitialized = false;

  /// True if a HuggingFace token is configured (build-time or runtime).
  bool get hasAuthToken =>
      (_runtimeHfToken != null && _runtimeHfToken!.trim().isNotEmpty) ||
      _buildHfToken.trim().isNotEmpty;

  /// Expected model size in bytes (for UI display).
  static int get expectedSizeBytes => _expectedSizeBytes;

  /// Active cancel token for in-progress downloads.
  CancelToken? _cancelToken;

  // ═══════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════

  /// Initialize flutter_gemma runtime once.
  ///
  /// Must be called before model install/check APIs for reliable behavior.
  Future<bool> initializePlugin({String? huggingFaceToken}) async {
    if (_pluginInitialized) return true;
    try {
      final token = _resolveToken(huggingFaceToken);
      _runtimeHfToken = token;
      await FlutterGemma.initialize(
        huggingFaceToken: token,
        maxDownloadRetries: 3,
      );
      _pluginInitialized = true;
      return true;
    } catch (e) {
      debugPrint('[SLM] FlutterGemma.initialize failed: $e');
      _pluginInitialized = false;
      return false;
    }
  }

  /// Check if model is installed via flutter_gemma's native check.
  ///
  /// This is the authoritative source of truth — not SharedPreferences.
  Future<bool> get isModelReady async {
    try {
      if (!_pluginInitialized) {
        await initializePlugin();
      }
      return await FlutterGemma.isModelInstalled(modelId);
    } catch (_) {
      return false;
    }
  }

  /// Get the local model file path (null if not downloaded).
  ///
  /// Note: flutter_gemma manages paths internally. Returns the model
  /// identifier when installed, null otherwise.
  Future<String?> get modelPath async {
    final installed = await isModelReady;
    return installed ? modelId : null;
  }

  /// Get model information.
  ///
  /// Also reconciles service state vs filesystem: if the service thinks
  /// the download completed but the model file is missing, resets to failed.
  Future<ModelInfo> getModelInfo() async {
    final installed = await isModelReady;
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getString(_prefKeyVersion) ?? _modelVersion;

    // Reconcile: service says completed but filesystem disagrees.
    if (_state == DownloadState.completed && !installed) {
      _state = DownloadState.failed;
      _lastError = 'Model file missing after download';
      _emitState();
    }

    return ModelInfo(
      modelId: modelId,
      displayName: 'Gemma 3n 4B (on-device)',
      sizeBytes: _expectedSizeBytes,
      version: version,
      isReady: installed,
      localPath: installed ? modelId : null,
    );
  }

  /// Download the model to local storage via flutter_gemma.
  ///
  /// [onProgress] is called with (progress 0.0-1.0, downloadedBytes, totalBytes).
  /// [modelUrl] overrides the default HuggingFace URL (for custom CDN).
  /// [hfToken] optional HuggingFace auth token for gated models.
  ///
  /// Returns true if download completed successfully.
  Future<bool> downloadModel({
    DownloadProgressCallback? onProgress,
    String? modelUrl,
    String? hfToken,
  }) async {
    if (_state == DownloadState.downloading) return false;

    _state = DownloadState.downloading;
    _progress = 0.0;
    _lastError = null;
    _cancelToken = CancelToken();
    _emitState();

    try {
      final initialized = await initializePlugin(huggingFaceToken: hfToken);
      if (!initialized) {
        _lastError = 'Initialisation du moteur SLM impossible.';
        _lastErrorRaw = 'FlutterGemma.initialize failed';
        _state = DownloadState.failed;
        _emitState();
        return false;
      }

      final url = modelUrl?.trim().isNotEmpty == true
          ? modelUrl!.trim()
          : SlmDownloadService.modelUrl;
      final token = _resolveToken(hfToken);

      // Gemma 3n repos on HuggingFace are typically gated.
      // Fail fast with an actionable message instead of a generic network error.
      if (_isLikelyGatedGemmaUrl(url) && (token == null || token.isEmpty)) {
        _lastErrorRaw = 'Missing HuggingFace token for gated Gemma 3n URL';
        _lastError = 'Authentification HuggingFace manquante pour Gemma 3n. '
            'Ajoute HUGGINGFACE_TOKEN dans le build CI/CD.';
        _state = DownloadState.failed;
        _emitState();
        return false;
      }

      debugPrint('[SLM] Starting model download from: $url');
      debugPrint('[SLM] Expected size: $modelSizeFormatted');
      debugPrint('[SLM] Estimated time: ~${estimatedDownloadMinutes()} min');

      // Use flutter_gemma's built-in model installer.
      // Handles chunked download, resume support, and verification.
      // withProgress receives int 0-100, withCancelToken for abort.
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      )
          .fromNetwork(url, token: token)
          .withProgress((percentInt) {
            _progress = percentInt / 100.0;
            final downloadedBytes = (_progress * _expectedSizeBytes).toInt();
            onProgress?.call(_progress, downloadedBytes, _expectedSizeBytes);
          })
          .withCancelToken(_cancelToken!)
          .install();

      // Persist version for future cache invalidation checks.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyVersion, _modelVersion);

      _state = DownloadState.completed;
      _progress = 1.0;
      _cancelToken = null;
      _emitState();

      debugPrint('[SLM] Model download complete');
      return true;
    } catch (e) {
      // CancelToken.isCancel checks if exception is a cancellation.
      if (CancelToken.isCancel(e)) {
        _state = DownloadState.notStarted;
        _progress = 0.0;
        debugPrint('[SLM] Download cancelled by user');
      } else {
        debugPrint('[SLM] Model download failed: $e');
        _lastErrorRaw = e.toString();
        _lastError = _toUserFacingError(e);
        _state = DownloadState.failed;
      }
      _cancelToken = null;
      _emitState();
      return false;
    }
  }

  /// Cancel an in-progress download.
  ///
  /// Uses flutter_gemma's [CancelToken] to abort the network request.
  void cancelDownload() {
    if (_state != DownloadState.downloading) return;
    _cancelToken?.cancel('User cancelled download');
    debugPrint('[SLM] Cancel requested');
    // State transition happens in downloadModel() catch block.
  }

  /// Delete the downloaded model to free disk space (~2.3 GB).
  ///
  /// Uses [FlutterGemma.uninstallModel] to remove both model files
  /// and flutter_gemma metadata. Also clears our version tracking.
  Future<bool> deleteModel() async {
    try {
      if (!_pluginInitialized) {
        await initializePlugin();
      }
      // Uninstall via flutter_gemma — deletes files + metadata.
      await FlutterGemma.uninstallModel(modelId);
      debugPrint('[SLM] Model uninstalled via flutter_gemma');
    } catch (e) {
      // Model might not be registered (e.g., partial download).
      // Continue to clear our own state regardless.
      debugPrint('[SLM] flutter_gemma uninstall error (continuing): $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKeyVersion);

      _state = DownloadState.notStarted;
      _progress = 0.0;
      _emitState();
      debugPrint('[SLM] Model deleted — ~$modelSizeFormatted liberes');
      return true;
    } catch (e) {
      debugPrint('[SLM] Model state clear failed: $e');
      return false;
    }
  }

  /// Estimated download time based on typical Swiss connection speeds.
  ///
  /// Assumes ~50 Mbps average (Swisscom/Sunrise typical).
  /// Returns duration in minutes.
  static int estimatedDownloadMinutes() {
    const bitsPerSecond = 50 * 1000 * 1000; // 50 Mbps
    const bytesPerSecond = bitsPerSecond / 8;
    const seconds = _expectedSizeBytes / bytesPerSecond;
    return (seconds / 60).ceil();
  }

  /// Human-readable model size.
  static String get modelSizeFormatted {
    const gb = _expectedSizeBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} Go';
  }

  String? _resolveToken(String? overrideToken) {
    if (overrideToken != null && overrideToken.trim().isNotEmpty) {
      return overrideToken.trim();
    }
    if (_runtimeHfToken != null && _runtimeHfToken!.trim().isNotEmpty) {
      return _runtimeHfToken!.trim();
    }
    if (_buildHfToken.trim().isNotEmpty) {
      return _buildHfToken.trim();
    }
    return null;
  }

  String _toUserFacingError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('http 401') ||
        lower.contains('authentication required') ||
        lower.contains('unauthorized')) {
      return 'Acces refuse au modele (HuggingFace). '
          'Le build doit inclure un token valide et l\'acces au repo Gemma 3n.';
    }
    if (lower.contains('http 403') || lower.contains('forbidden')) {
      return 'Token HuggingFace invalide ou sans acces au repo Gemma 3n.';
    }
    if (lower.contains('http 404') || lower.contains('not found')) {
      return 'Fichier modele introuvable. Verifie l\'URL SLM_MODEL_URL.';
    }
    if (lower.contains('network') || lower.contains('socket')) {
      return 'Erreur reseau pendant le telechargement. Verifie WiFi et stabilite reseau.';
    }
    return 'Le telechargement du modele a echoue. Reessaye dans quelques minutes.';
  }

  bool _isLikelyGatedGemmaUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('huggingface.co/google/gemma-3n') ||
        lower.contains('huggingface.co/litert-community/gemma-3n');
  }

  /// Release resources.
  ///
  /// Cancels any in-progress download and closes the state stream.
  Future<void> dispose() async {
    _cancelToken?.cancel('Service disposed');
    await _stateController.close();
  }
}
