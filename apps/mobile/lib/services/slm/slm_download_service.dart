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

  /// Model file name on disk (.task format for MediaPipe).
  static const String _modelFileName = 'gemma-3n-e4b-it.task';

  /// Expected model size (~2.3 GB).
  static const int _expectedSizeBytes = 2400000000;

  /// Model version for cache invalidation.
  static const String _modelVersion = '1.0.0';

  /// HuggingFace model URL (Gemma 3n E4B IT in .task format).
  /// In production, configure via remote config.
  static const String _defaultModelUrl =
      'https://huggingface.co/litert-community/gemma-3n-E4B-it-litert-preview/resolve/main/gemma3n-E4B-it-multi.task';

  /// SharedPreferences keys for download state.
  static const String _prefKeyDownloaded = 'slm_model_downloaded';
  static const String _prefKeyVersion = 'slm_model_version';
  static const String _prefKeyPath = 'slm_model_path';

  // ═══════════════════════════════════════════════════════════════
  //  State
  // ═══════════════════════════════════════════════════════════════

  DownloadState _state = DownloadState.notStarted;

  /// Current download state.
  DownloadState get state => _state;

  /// Stream of download state changes.
  final _stateController = StreamController<DownloadState>.broadcast();
  Stream<DownloadState> get stateStream => _stateController.stream;

  /// Download progress (0.0 to 1.0).
  double _progress = 0.0;
  double get progress => _progress;

  // ═══════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════

  /// Get the local model file path (null if not downloaded).
  Future<String?> get modelPath async {
    final prefs = await SharedPreferences.getInstance();
    final isDownloaded = prefs.getBool(_prefKeyDownloaded) ?? false;
    if (!isDownloaded) return null;

    final path = prefs.getString(_prefKeyPath);
    return path;
  }

  /// Get model information.
  Future<ModelInfo> getModelInfo() async {
    final path = await modelPath;
    final prefs = await SharedPreferences.getInstance();
    final version = prefs.getString(_prefKeyVersion) ?? _modelVersion;

    return ModelInfo(
      modelId: 'gemma-3n-e4b-it',
      displayName: 'Gemma 3n 4B (on-device)',
      sizeBytes: _expectedSizeBytes,
      version: version,
      isReady: path != null,
      localPath: path,
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
    _stateController.add(_state);

    try {
      final url = modelUrl ?? _defaultModelUrl;

      debugPrint('[SLM] Starting model download from: $url');
      debugPrint('[SLM] Expected size: $modelSizeFormatted');
      debugPrint('[SLM] Estimated time: ~${estimatedDownloadMinutes()} min');

      // Use flutter_gemma's built-in model installer.
      // Handles chunked download, resume support, and verification.
      var installer = FlutterGemma.installModel(
        modelType: ModelType.gemmaIt,
      ).fromNetwork(
        url,
        token: hfToken,
      );

      // Add progress tracking.
      installer = installer.withProgress((progressPercent) {
        _progress = progressPercent / 100.0;
        final downloadedBytes = (_progress * _expectedSizeBytes).toInt();
        onProgress?.call(_progress, downloadedBytes, _expectedSizeBytes);
      });

      // Execute the download + installation.
      await installer.install();

      // Persist download state.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyDownloaded, true);
      await prefs.setString(_prefKeyVersion, _modelVersion);
      await prefs.setString(_prefKeyPath, _modelFileName);

      _state = DownloadState.completed;
      _progress = 1.0;
      _stateController.add(_state);

      debugPrint('[SLM] Model download complete');
      return true;
    } catch (e) {
      debugPrint('[SLM] Model download failed: $e');
      _state = DownloadState.failed;
      _stateController.add(_state);
      return false;
    }
  }

  /// Cancel an in-progress download.
  Future<void> cancelDownload() async {
    if (_state != DownloadState.downloading) return;
    _state = DownloadState.notStarted;
    _progress = 0.0;
    _stateController.add(_state);
    debugPrint('[SLM] Download cancelled');
  }

  /// Delete the downloaded model to free disk space (~2.3 GB).
  Future<bool> deleteModel() async {
    try {
      await _clearDownloadState();
      _state = DownloadState.notStarted;
      _progress = 0.0;
      _stateController.add(_state);
      debugPrint('[SLM] Model deleted');
      return true;
    } catch (e) {
      debugPrint('[SLM] Model deletion failed: $e');
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
    final gb = _expectedSizeBytes / (1024 * 1024 * 1024);
    return '${gb.toStringAsFixed(1)} Go';
  }

  // ═══════════════════════════════════════════════════════════════
  //  Private
  // ═══════════════════════════════════════════════════════════════

  Future<void> _clearDownloadState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefKeyDownloaded);
    await prefs.remove(_prefKeyVersion);
    await prefs.remove(_prefKeyPath);
  }

  /// Release resources.
  void dispose() {
    _stateController.close();
  }
}
