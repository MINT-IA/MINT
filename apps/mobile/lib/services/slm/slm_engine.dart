/// SLM Engine — On-device Small Language Model inference.
///
/// Wraps flutter_gemma package for Gemma 3n E4B on-device inference.
/// Privacy-first: zero network traffic during inference.
///
/// Architecture:
///   - Model stored locally (~2.3 GB on disk)
///   - Inference runs on-device (GPU preferred, CPU fallback)
///   - No data leaves the device
///   - ComplianceGuard validates ALL output before display
///
/// Priority chain in CoachNarrativeService:
///   1. SLM on-device (if model downloaded + initialized)
///   2. Static templates (always available)
///   3. BYOK cloud LLM (if API key configured)
///
/// References:
///   - flutter_gemma 0.12.x (pub.dev/packages/flutter_gemma)
///   - Gemma 3n E4B IT (ai.google.dev/edge/mediapipe)
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
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

/// On-device SLM engine using flutter_gemma (MediaPipe GenAI).
///
/// Usage:
/// ```dart
/// final engine = SlmEngine.instance;
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

  /// The active flutter_gemma model instance (null until initialized).
  InferenceModel? _model;

  /// Initialize the engine with the downloaded model.
  ///
  /// Must be called after [SlmDownloadService] confirms download.
  /// Returns true if initialization succeeded.
  Future<bool> initialize() async {
    if (_status == SlmStatus.running && _model != null) return true;

    final modelPath = await SlmDownloadService.instance.modelPath;
    if (modelPath == null) {
      _status = SlmStatus.notDownloaded;
      return false;
    }

    try {
      _status = SlmStatus.ready;

      // Create the flutter_gemma model instance.
      // Uses GPU backend for performance, falls back to CPU if unavailable.
      _model = await FlutterGemma.getActiveModel(
        maxTokens: maxContextTokens,
        preferredBackend: PreferredBackend.gpu,
      );

      _status = SlmStatus.running;
      debugPrint('[SLM] Engine initialized: $modelId (GPU preferred)');
      return true;
    } catch (e) {
      debugPrint('[SLM] Engine init failed: $e');
      // Retry with CPU backend
      try {
        _model = await FlutterGemma.getActiveModel(
          maxTokens: maxContextTokens,
          preferredBackend: PreferredBackend.cpu,
        );
        _status = SlmStatus.running;
        debugPrint('[SLM] Engine initialized: $modelId (CPU fallback)');
        return true;
      } catch (e2) {
        debugPrint('[SLM] Engine CPU fallback failed: $e2');
        _status = SlmStatus.error;
        return false;
      }
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
    if (!isAvailable || _model == null) return null;

    final stopwatch = Stopwatch()..start();

    try {
      // Create a chat session for single-turn generation.
      final chat = await _model!.createChat();

      // Build the combined prompt in Gemma 3n format.
      // The flutter_gemma package handles the <start_of_turn> formatting
      // internally, so we send system + user as a single user message.
      final combinedPrompt = '$systemPrompt\n\n$userPrompt';

      await chat.addQueryChunk(Message.text(
        text: combinedPrompt,
        isUser: true,
      ));

      // Generate the response (blocking, full text).
      final response = await chat.generateChatResponse();

      stopwatch.stop();

      // Extract text from the response.
      final responseText = _extractText(response);

      debugPrint(
        '[SLM] Generated ${_estimateTokens(responseText)} tokens '
        'in ${stopwatch.elapsedMilliseconds}ms',
      );

      return SlmResult(
        text: responseText,
        durationMs: stopwatch.elapsedMilliseconds,
        tokensGenerated: _estimateTokens(responseText),
      );
    } catch (e) {
      stopwatch.stop();
      debugPrint('[SLM] Generation failed: $e');
      return null;
    }
  }

  /// Generate text as a stream (token by token).
  ///
  /// Useful for progressive UI display. Yields individual tokens
  /// as they are generated.
  Stream<String> generateStream({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = defaultMaxTokens,
  }) async* {
    if (!isAvailable || _model == null) return;

    try {
      final chat = await _model!.createChat();

      final combinedPrompt = '$systemPrompt\n\n$userPrompt';
      await chat.addQueryChunk(Message.text(
        text: combinedPrompt,
        isUser: true,
      ));

      // Stream the response token by token.
      await for (final chunk in chat.generateChatResponseAsync()) {
        if (chunk is TextResponse) {
          yield chunk.token;
        }
      }
    } catch (e) {
      debugPrint('[SLM] Stream generation failed: $e');
      return;
    }
  }

  /// Release model resources from memory.
  ///
  /// Call this when the app goes to background for extended periods
  /// to free ~2 GB of RAM.
  void dispose() {
    _model = null;
    if (_status == SlmStatus.running) {
      _status = SlmStatus.ready;
    }
    debugPrint('[SLM] Engine disposed');
  }

  /// Extract text from a flutter_gemma response object.
  static String _extractText(dynamic response) {
    if (response is String) return response;
    if (response is List) {
      return response
          .whereType<TextResponse>()
          .map((r) => r.token)
          .join();
    }
    return response?.toString() ?? '';
  }

  /// Rough token count estimation (1 token ~= 4 chars for French).
  static int _estimateTokens(String text) {
    return (text.length / 4).ceil();
  }
}
