/// SLM Engine — On-device Small Language Model inference.
///
/// Wraps Google MediaPipe LLM Inference API (Gemma 3n 4B E4B)
/// for privacy-first, zero-network coach narratives.
///
/// Architecture:
///   - Model stored locally (~2.3 GB on disk)
///   - Inference runs on-device (CPU/GPU via MediaPipe)
///   - No data leaves the device
///   - ComplianceGuard validates ALL output before display
///
/// Priority chain in CoachNarrativeService:
///   1. SLM on-device (if model downloaded)
///   2. Static templates (always available)
///   3. BYOK cloud LLM (if API key configured)
library;

import 'dart:async';

import 'package:mint_mobile/services/slm/slm_download_service.dart';

/// Status of the SLM engine.
enum SlmStatus {
  /// Model not downloaded yet.
  notDownloaded,

  /// Model is being downloaded.
  downloading,

  /// Model downloaded, engine not initialized.
  ready,

  /// Engine initialized and ready for inference.
  running,

  /// Engine encountered an error.
  error,
}

/// Result of an SLM inference call.
class SlmResult {
  /// The generated text.
  final String text;

  /// Inference duration in milliseconds.
  final int durationMs;

  /// Number of tokens generated.
  final int tokensGenerated;

  const SlmResult({
    required this.text,
    required this.durationMs,
    required this.tokensGenerated,
  });
}

/// On-device SLM engine using MediaPipe LLM Inference.
///
/// Usage:
/// ```dart
/// final engine = SlmEngine();
/// await engine.initialize();
/// final result = await engine.generate(
///   systemPrompt: PromptRegistry.baseSystemPrompt,
///   userPrompt: 'Genere un greeting pour Julien, score 62/100',
///   maxTokens: 150,
/// );
/// ```
class SlmEngine {
  SlmEngine._();
  static final SlmEngine instance = SlmEngine._();

  SlmStatus _status = SlmStatus.notDownloaded;

  /// Current engine status.
  SlmStatus get status => _status;

  /// Whether the engine is ready for inference.
  bool get isAvailable => _status == SlmStatus.running;

  /// Model identifier.
  static const String modelId = 'gemma-3n-e4b-it';

  /// Model display name.
  static const String modelDisplayName = 'Gemma 3n 4B (on-device)';

  /// Maximum context window (tokens).
  static const int maxContextTokens = 8192;

  /// Default max output tokens per generation.
  static const int defaultMaxTokens = 256;

  /// Temperature for generation (lower = more deterministic).
  static const double defaultTemperature = 0.3;

  /// Initialize the engine with the downloaded model.
  ///
  /// Must be called after [SlmDownloadService] confirms download.
  /// Returns true if initialization succeeded.
  Future<bool> initialize() async {
    if (_status == SlmStatus.running) return true;

    final modelPath = await SlmDownloadService.instance.modelPath;
    if (modelPath == null) {
      _status = SlmStatus.notDownloaded;
      return false;
    }

    try {
      // MediaPipe LLM Inference initialization.
      // In production, this calls:
      //   LlmInference.createFromOptions(LlmInferenceOptions(
      //     modelPath: modelPath,
      //     maxTokens: maxContextTokens,
      //     temperature: defaultTemperature,
      //   ));
      //
      // For now, we use a stub that will be replaced when
      // google_mediapipe_genai is added as a dependency.
      _status = SlmStatus.ready;

      // Warm up with a short generation to load model weights into memory.
      _status = SlmStatus.running;
      return true;
    } catch (e) {
      _status = SlmStatus.error;
      return false;
    }
  }

  /// Generate text from a prompt.
  ///
  /// [systemPrompt] sets the model behavior (from PromptRegistry).
  /// [userPrompt] is the specific generation request.
  /// [maxTokens] limits output length (default 256).
  ///
  /// Returns null if engine is not available.
  Future<SlmResult?> generate({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = defaultMaxTokens,
    double temperature = defaultTemperature,
  }) async {
    if (!isAvailable) return null;

    final stopwatch = Stopwatch()..start();

    try {
      // Combine system + user prompt for single-turn generation.
      // Gemma 3n uses <start_of_turn> format:
      //   <start_of_turn>user\n{system}\n\n{user}<end_of_turn>
      //   <start_of_turn>model\n
      final fullPrompt = '<start_of_turn>user\n'
          '$systemPrompt\n\n'
          '$userPrompt<end_of_turn>\n'
          '<start_of_turn>model\n';

      // MediaPipe LLM Inference call.
      // In production: final response = await _inference.generateResponse(fullPrompt);
      //
      // Stub: returns empty to trigger fallback to static templates.
      // This will be replaced with actual MediaPipe call.
      final response = '';

      stopwatch.stop();

      return SlmResult(
        text: response,
        durationMs: stopwatch.elapsedMilliseconds,
        tokensGenerated: _estimateTokens(response),
      );
    } catch (e) {
      stopwatch.stop();
      return null;
    }
  }

  /// Generate text as a stream (token by token).
  ///
  /// Useful for progressive UI display.
  Stream<String> generateStream({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = defaultMaxTokens,
  }) async* {
    if (!isAvailable) return;

    final fullPrompt = '<start_of_turn>user\n'
        '$systemPrompt\n\n'
        '$userPrompt<end_of_turn>\n'
        '<start_of_turn>model\n';

    // MediaPipe streaming generation.
    // In production: yield* _inference.generateResponseStream(fullPrompt);
    //
    // Stub: yields nothing.
    return;
  }

  /// Release model resources from memory.
  void dispose() {
    // In production: _inference.close();
    _status = SlmStatus.ready;
  }

  /// Rough token count estimation (1 token ~= 4 chars for French).
  static int _estimateTokens(String text) {
    return (text.length / 4).ceil();
  }
}
