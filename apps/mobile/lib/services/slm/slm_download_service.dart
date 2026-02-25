/// SLM Download Service — manages on-device model lifecycle.
///
/// Handles downloading, verifying, and managing the Gemma 3n model
/// for on-device inference. The model is stored in the app's
/// documents directory and persists across app restarts.
///
/// Privacy guarantee: model runs 100% on-device, zero network
/// traffic during inference.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
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

  /// Model file name on disk.
  static const String _modelFileName = 'gemma-3n-e4b-it.bin';

  /// Expected model size (~2.3 GB).
  static const int _expectedSizeBytes = 2400000000;

  /// Model version for cache invalidation.
  static const String _modelVersion = '1.0.0';

  /// SharedPreferences key for download state.
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

  // ═══════════════════════════════════════════════════════════════
  //  Public API
  // ═══════════════════════════════════════════════════════════════

  /// Get the local model file path (null if not downloaded).
  Future<String?> get modelPath async {
    final prefs = await SharedPreferences.getInstance();
    final isDownloaded = prefs.getBool(_prefKeyDownloaded) ?? false;
    if (!isDownloaded) return null;

    final path = prefs.getString(_prefKeyPath);
    if (path == null) return null;

    // Verify file still exists on disk.
    if (!File(path).existsSync()) {
      await _clearDownloadState();
      return null;
    }

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

  /// Download the model to local storage.
  ///
  /// [onProgress] is called with (progress 0.0-1.0, downloadedBytes, totalBytes).
  ///
  /// The download URL should point to a Kaggle/HuggingFace hosted model
  /// or a self-hosted CDN. In production, configure this via remote config.
  Future<bool> downloadModel({
    DownloadProgressCallback? onProgress,
  }) async {
    if (_state == DownloadState.downloading) return false;

    _state = DownloadState.downloading;
    _stateController.add(_state);

    try {
      // Determine storage path.
      // On Android: getApplicationDocumentsDirectory()
      // On iOS: getApplicationSupportDirectory()
      //
      // For now, we use a platform-agnostic stub.
      // In production, use path_provider package.
      final storagePath = await _getStoragePath();
      final modelFile = File('$storagePath/$_modelFileName');

      // Create parent directory if needed.
      await modelFile.parent.create(recursive: true);

      // Download the model.
      // In production, this would use:
      //   1. HttpClient for chunked download with resume support
      //   2. Checksum verification (SHA-256)
      //   3. Background download via workmanager
      //
      // Stub: mark as completed for development.
      // The actual download will be implemented when CDN is configured.

      // Save download state.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyDownloaded, true);
      await prefs.setString(_prefKeyVersion, _modelVersion);
      await prefs.setString(_prefKeyPath, modelFile.path);

      _state = DownloadState.completed;
      _stateController.add(_state);
      return true;
    } catch (e) {
      _state = DownloadState.failed;
      _stateController.add(_state);
      return false;
    }
  }

  /// Cancel an in-progress download.
  Future<void> cancelDownload() async {
    if (_state != DownloadState.downloading) return;
    _state = DownloadState.notStarted;
    _stateController.add(_state);
  }

  /// Delete the downloaded model to free disk space.
  Future<bool> deleteModel() async {
    try {
      final path = await modelPath;
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
      await _clearDownloadState();
      _state = DownloadState.notStarted;
      _stateController.add(_state);
      return true;
    } catch (e) {
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

  Future<String> _getStoragePath() async {
    // In production, use path_provider:
    //   final dir = await getApplicationSupportDirectory();
    //   return '${dir.path}/slm';
    //
    // Stub for development:
    if (Platform.isIOS || Platform.isMacOS) {
      return '/tmp/mint_slm';
    }
    return '/tmp/mint_slm';
  }

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
