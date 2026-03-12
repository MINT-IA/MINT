import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/feature_flags.dart';
import 'package:mint_mobile/services/slm/slm_download_service.dart';
import 'package:mint_mobile/services/slm/slm_engine.dart';

/// Reactive provider for SLM (on-device Gemma 3n) state.
///
/// Wraps [SlmDownloadService] and [SlmEngine] singletons into a
/// [ChangeNotifier] so that all screens reactively update when the
/// model is downloaded, initialized, or deleted.
///
/// Registered in [MultiProvider] (app.dart). Consumed via
/// `context.watch<SlmProvider>()` in SlmSettingsScreen, ProfileScreen,
/// and SlmAutoPromptService.
class SlmProvider extends ChangeNotifier {
  // ═══════════════════════════════════════════════════════════════
  //  State
  // ═══════════════════════════════════════════════════════════════

  ModelInfo? _modelInfo;
  DownloadState _downloadState = DownloadState.notStarted;
  double _downloadProgress = 0.0;
  bool _isProcessing = false;
  String? _lastError;
  StreamSubscription<DownloadState>? _downloadSub;

  // ═══════════════════════════════════════════════════════════════
  //  Getters
  // ═══════════════════════════════════════════════════════════════

  /// Current model info (null before first load).
  ModelInfo? get modelInfo => _modelInfo;

  /// Current download state from [SlmDownloadService].
  DownloadState get downloadState => _downloadState;

  /// Download progress 0.0–1.0.
  double get downloadProgress => _downloadProgress;

  /// True while an async action (download, delete, init) is running.
  bool get isProcessing => _isProcessing;

  /// Whether the model file is downloaded and verified.
  bool get isModelReady => _modelInfo?.isReady == true;

  /// Current engine status (notDownloaded, ready, running, error).
  SlmStatus get engineStatus => SlmEngine.instance.status;

  /// Whether this build can attempt a model download.
  bool get canAttemptDownload =>
      SlmDownloadService.instance.canAttemptDownload;

  /// User-facing warning when download is blocked (missing HF token).
  String? get prerequisiteWarning =>
      SlmDownloadService.instance.prerequisiteWarning;

  /// Last download error message (user-facing).
  String? get lastError => _lastError;

  /// True if the SLM engine is initialized and ready for inference.
  bool get isEngineAvailable => SlmEngine.instance.isAvailable;

  /// Whether the HuggingFace auth token is configured.
  bool get hasAuthToken => SlmDownloadService.instance.hasAuthToken;

  // ═══════════════════════════════════════════════════════════════
  //  Initialization
  // ═══════════════════════════════════════════════════════════════

  /// Load model info and subscribe to download state changes.
  ///
  /// Called once from [MultiProvider] create callback.
  Future<void> init() async {
    await _refreshModelInfo();
    _downloadSub = SlmDownloadService.instance.stateStream.listen((state) {
      _downloadState = state;
      _downloadProgress = SlmDownloadService.instance.progress;
      _refreshModelInfo();
    });
  }

  // ═══════════════════════════════════════════════════════════════
  //  Actions
  // ═══════════════════════════════════════════════════════════════

  /// Download the model. Returns true on success.
  ///
  /// Auto-initializes the engine after a successful download.
  Future<bool> downloadModel() async {
    if (_isProcessing) return false;
    _isProcessing = true;
    _lastError = null;
    notifyListeners();

    final success = await SlmDownloadService.instance.downloadModel(
      onProgress: (progress, downloaded, total) {
        _downloadProgress = progress;
        notifyListeners();
      },
    );

    if (success) {
      final engineOk = await SlmEngine.instance.initialize();
      if (engineOk) {
        FeatureFlags.slmPluginReady = true;
      }
    } else if (SlmDownloadService.instance.state == DownloadState.failed) {
      _lastError = SlmDownloadService.instance.lastError;
    }

    await _refreshModelInfo();
    _isProcessing = false;
    notifyListeners();
    return success;
  }

  /// Cancel an in-progress download.
  void cancelDownload() {
    SlmDownloadService.instance.cancelDownload();
  }

  /// Delete the model and free disk space (~2.3 GB).
  Future<bool> deleteModel() async {
    if (_isProcessing) return false;
    _isProcessing = true;
    notifyListeners();

    await SlmEngine.instance.dispose();
    final success = await SlmDownloadService.instance.deleteModel();

    await _refreshModelInfo();
    _isProcessing = false;
    notifyListeners();
    return success;
  }

  /// Manually initialize the engine (for the "Initialiser" button).
  ///
  /// Also sets [FeatureFlags.slmPluginReady] so that the
  /// [CoachOrchestrator] uses the SLM tier immediately.
  Future<bool> initializeEngine() async {
    if (_isProcessing) return false;
    _isProcessing = true;
    notifyListeners();

    final success = await SlmEngine.instance.initialize();
    if (success) {
      FeatureFlags.slmPluginReady = true;
    }

    _isProcessing = false;
    notifyListeners();
    return success;
  }

  /// Release engine resources (background lifecycle).
  Future<void> disposeEngine() async {
    if (!SlmEngine.instance.isAvailable) return;
    await SlmEngine.instance.dispose();
    notifyListeners();
  }

  /// Force-refresh model info from [SlmDownloadService].
  Future<void> refreshModelInfo() => _refreshModelInfo();

  // ═══════════════════════════════════════════════════════════════
  //  Internal
  // ═══════════════════════════════════════════════════════════════

  Future<void> _refreshModelInfo() async {
    _modelInfo = await SlmDownloadService.instance.getModelInfo();
    _downloadState = SlmDownloadService.instance.state;
    _downloadProgress = SlmDownloadService.instance.progress;
    notifyListeners();
  }

  @override
  void dispose() {
    _downloadSub?.cancel();
    super.dispose();
  }
}
