/// SLM Download Service — stubbed.
///
/// Originally managed the flutter_gemma on-device model lifecycle
/// (download, verify, uninstall). Removed 2026-04-17 along with
/// flutter_gemma itself: the TensorFlowLiteSelectTfOps pod has no
/// arm64-simulator slice, which blocked iterating on iOS simulators.
/// The public API is preserved so SlmProvider, onboarding checks, and
/// the settings screen keep compiling; every call reports "not
/// downloaded" / no-op so the engine stays gated off.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/slm/slm_model_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef DownloadProgressCallback = void Function(
  double progress,
  int downloadedBytes,
  int totalBytes,
);

enum DownloadState {
  notStarted,
  downloading,
  paused,
  completed,
  failed,
}

class ModelInfo {
  final String modelId;
  final String displayName;
  final int sizeBytes;
  final String version;
  final bool isReady;
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

class SlmDownloadService {
  SlmDownloadService._();
  static final SlmDownloadService instance = SlmDownloadService._();

  static const String _buildModelUrl = String.fromEnvironment('SLM_MODEL_URL');
  static const String _buildHfToken =
      String.fromEnvironment('HUGGINGFACE_TOKEN');

  static String get modelUrl => _buildModelUrl.trim().isNotEmpty
      ? _buildModelUrl.trim()
      : instance.activeTierConfig.hfUrl;

  static String get modelId {
    final url = modelUrl;
    if (url.isEmpty) return 'slm_stub';
    final segments = Uri.parse(url).pathSegments;
    return segments.isEmpty ? 'slm_stub' : segments.last;
  }

  static const String _modelVersion = '1.0.0';
  static const String _prefKeyTier = 'slm_active_tier';

  SlmModelTier _activeTier = SlmModelTier.e4b;
  SlmModelTier get activeTier => _activeTier;
  SlmTierConfig get activeTierConfig => SlmTierConfig.forTier(_activeTier);

  int get expectedSizeBytes => activeTierConfig.expectedSizeBytes;
  String get modelSizeFormatted => activeTierConfig.modelSizeFormatted;
  int get estimatedDownloadMinutes =>
      activeTierConfig.estimatedDownloadMinutes;

  Future<void> setActiveTier(SlmModelTier tier) async {
    _activeTier = tier;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKeyTier, tier.name);
  }

  Future<void> loadSavedTier() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKeyTier);
    if (saved != null) {
      for (final tier in SlmModelTier.values) {
        if (tier.name == saved) {
          _activeTier = tier;
          return;
        }
      }
    }
    _activeTier = SlmModelTier.e4b;
  }

  DownloadState get state => DownloadState.notStarted;

  final _stateController = StreamController<DownloadState>.broadcast();
  Stream<DownloadState> get stateStream => _stateController.stream;

  double get progress => 0.0;
  String? get lastError => null;
  String? get lastErrorRaw => null;

  bool get hasAuthToken => _buildHfToken.trim().isNotEmpty;
  bool get requiresAuthForCurrentUrl => false;
  bool get canAttemptDownload => false;
  String? get prerequisiteWarning => 'slm_disabled_in_build';

  Future<bool> initializePlugin({String? huggingFaceToken}) async {
    debugPrint('[SLM] Download service stubbed — on-device SLM disabled.');
    await loadSavedTier();
    return false;
  }

  Future<bool> get isModelReady async => false;
  Future<String?> get modelPath async => null;

  Future<ModelInfo> getModelInfo() async {
    await loadSavedTier();
    return ModelInfo(
      modelId: modelId,
      displayName: activeTierConfig.displayName,
      sizeBytes: activeTierConfig.expectedSizeBytes,
      version: _modelVersion,
      isReady: false,
      localPath: null,
    );
  }

  Future<bool> downloadModel({
    DownloadProgressCallback? onProgress,
    String? modelUrl,
    String? hfToken,
  }) async =>
      false;

  void cancelDownload() {}

  Future<bool> deleteModel() async => true;

  Future<void> dispose() async {
    await _stateController.close();
  }
}
