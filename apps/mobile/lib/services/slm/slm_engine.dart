/// SLM Engine — stubbed.
///
/// Originally wrapped flutter_gemma for Gemma 3n E4B on-device inference.
/// Removed 2026-04-17: flutter_gemma's TensorFlowLiteSelectTfOps pod has
/// no arm64-simulator slice, which blocked iterating on Apple Silicon
/// simulators. SLM was gated off at runtime anyway
/// (FeatureFlags.slmPluginReady=false), so dropping the dep costs
/// nothing the product currently relies on and unlocks fast simulator
/// QA. The public API is preserved so callers (CoachOrchestrator,
/// SlmProvider, CoachChatScreen, main.dart, app.dart) fall through to
/// BYOK / server-key / templates without any code change.
///
/// To restore on-device SLM: re-add flutter_gemma to pubspec, restore
/// this file from the git history before commit that removes the dep,
/// and flip FeatureFlags.slmPluginReady=true.
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:mint_mobile/services/slm/slm_download_service.dart';

/// Status of the SLM engine (stubbed, always [notDownloaded]).
enum SlmStatus {
  notDownloaded,
  downloading,
  ready,
  running,
  error,
}

/// Result of an SLM inference call. Kept for API compatibility; never
/// returned by the stubbed engine.
class SlmResult {
  final String text;
  final int durationMs;
  final int tokensGenerated;

  const SlmResult({
    required this.text,
    required this.durationMs,
    required this.tokensGenerated,
  });
}

/// Preferred backend indicator. Kept so existing call-sites that read
/// `activeBackend` / `isCpuFallback` compile untouched.
enum PreferredBackend { gpu, cpu }

/// Stubbed SLM engine. Every method short-circuits so the orchestrator
/// falls through to the network tier.
class SlmEngine {
  SlmEngine._();
  static final SlmEngine instance = SlmEngine._();

  static const bool isOnDeviceOnly = true;

  SlmStatus get status => SlmStatus.notDownloaded;
  bool get isAvailable => false;
  bool get wasDisposed => false;

  static String get modelId => SlmDownloadService.modelId;
  static String get modelDisplayName =>
      SlmDownloadService.instance.activeTierConfig.displayName;

  static const int maxContextTokens = 2048;
  static const int defaultMaxTokens = 256;
  static const double defaultTemperature = 0.3;

  PreferredBackend? get activeBackend => null;
  bool get isCpuFallback => false;

  Future<bool> initialize() async {
    debugPrint('[SLM] Stub engine — on-device SLM disabled.');
    return false;
  }

  Future<SlmResult?> generate({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = defaultMaxTokens,
    double temperature = defaultTemperature,
  }) async =>
      null;

  Stream<String> generateStream({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = defaultMaxTokens,
    double temperature = defaultTemperature,
  }) async* {
    // Empty stream — the orchestrator falls through to the next tier.
  }

  Future<void> dispose() async {}
}
