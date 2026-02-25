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

  /// Model identifier — delegates to [SlmDownloadService.modelId]
  /// (derived from the URL filename, e.g. 'gemma3n-E4B-it-multi.task').
  static String get modelId => SlmDownloadService.modelId;

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

  /// Concurrency guard — prevents overlapping generate() calls
  /// from creating multiple chat sessions and OOMing the device.
  bool _isGenerating = false;

  /// Initialize the engine with the downloaded model.
  ///
  /// Checks model availability via [FlutterGemma.isModelInstalled],
  /// then creates an [InferenceModel] with GPU preferred (CPU fallback).
  /// Returns true if initialization succeeded.
  Future<bool> initialize() async {
    if (_status == SlmStatus.running && _model != null) return true;

    // Use flutter_gemma's native check instead of SharedPreferences path.
    final isInstalled = await FlutterGemma.isModelInstalled(modelId);
    if (!isInstalled) {
      _status = SlmStatus.notDownloaded;
      return false;
    }

    try {
      _status = SlmStatus.ready;

      // Create the flutter_gemma model instance.
      // GPU preferred for performance, CPU fallback below.
      _model = await FlutterGemma.getActiveModel(
        maxTokens: maxContextTokens,
        preferredBackend: PreferredBackend.gpu,
      );

      _status = SlmStatus.running;
      debugPrint('[SLM] Engine initialized: $modelId (GPU preferred)');
      return true;
    } catch (e) {
      debugPrint('[SLM] Engine GPU init failed: $e');
      // Retry with CPU backend for older devices.
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
  /// [temperature] controls randomness (default 0.3, lower = more deterministic).
  ///
  /// Returns null if engine is not available or another generation is in progress.
  Future<SlmResult?> generate({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = defaultMaxTokens,
    double temperature = defaultTemperature,
  }) async {
    if (!isAvailable || _model == null) return null;

    // Concurrency guard: one generation at a time (device memory constraint).
    if (_isGenerating) {
      debugPrint('[SLM] Generation skipped: another call in progress');
      return null;
    }
    _isGenerating = true;

    final stopwatch = Stopwatch()..start();
    Chat? chat;

    try {
      // Create a chat session with caller-specified params.
      // temperature and tokenBuffer map to our public API.
      chat = await _model!.createChat(
        temperature: temperature,
        tokenBuffer: maxTokens,
        topK: 1,
      );

      // Send system prompt via dedicated Message.systemInfo,
      // then user prompt as Message.text(isUser: true).
      // flutter_gemma handles <start_of_turn> formatting internally.
      await chat.addQueryChunk(Message.systemInfo(text: systemPrompt));
      await chat.addQueryChunk(Message.text(
        text: userPrompt,
        isUser: true,
      ));

      // Generate the response (blocking, full text).
      // Returns ModelResponse — a TextResponse for text-only models.
      final response = await chat.generateChatResponse();

      stopwatch.stop();

      // Extract text from the ModelResponse.
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
    } finally {
      // Always release the chat session to free native resources.
      await chat?.close();
      _isGenerating = false;
    }
  }

  /// Generate text as a stream (token by token).
  ///
  /// Useful for progressive UI display. Yields individual tokens
  /// as they are generated.
  ///
  /// Returns empty stream if engine not available or busy.
  Stream<String> generateStream({
    required String systemPrompt,
    required String userPrompt,
    int maxTokens = defaultMaxTokens,
    double temperature = defaultTemperature,
  }) async* {
    if (!isAvailable || _model == null || _isGenerating) return;

    _isGenerating = true;
    Chat? chat;

    try {
      chat = await _model!.createChat(
        temperature: temperature,
        tokenBuffer: maxTokens,
        topK: 1,
      );

      await chat.addQueryChunk(Message.systemInfo(text: systemPrompt));
      await chat.addQueryChunk(Message.text(
        text: userPrompt,
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
    } finally {
      await chat?.close();
      _isGenerating = false;
    }
  }

  /// Release model resources from memory.
  ///
  /// Calls [InferenceModel.close()] to free native resources (~2 GB RAM).
  /// Call this when the app goes to background for extended periods.
  Future<void> dispose() async {
    if (_model != null) {
      try {
        await _model!.close();
      } catch (e) {
        debugPrint('[SLM] Model close error: $e');
      }
      _model = null;
    }
    if (_status == SlmStatus.running) {
      _status = SlmStatus.ready;
    }
    _isGenerating = false;
    debugPrint('[SLM] Engine disposed');
  }

  /// Extract text from a flutter_gemma [ModelResponse].
  ///
  /// [generateChatResponse()] returns a single [ModelResponse].
  /// For text-only models (Gemma 3n), this is always a [TextResponse].
  static String _extractText(ModelResponse response) {
    if (response is TextResponse) {
      return response.token;
    }
    // Fallback for unexpected response types.
    return response.toString();
  }

  /// Rough token count estimation (1 token ~= 4 chars for French).
  static int _estimateTokens(String text) {
    if (text.isEmpty) return 0;
    return (text.length / 4).ceil();
  }
}
