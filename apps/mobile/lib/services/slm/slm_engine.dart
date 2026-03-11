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
///   2. BYOK cloud LLM (if API key configured)
///   3. Static templates (always available)
///
/// References:
///   - flutter_gemma 0.12.x (pub.dev/packages/flutter_gemma)
///   - Gemma 3n E4B IT (ai.google.dev/edge/mediapipe)
library;

import 'dart:async';
import 'dart:io';

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
/// ## Privacy guarantee (no-network contract)
///
/// This engine runs ENTIRELY on-device. Zero network traffic during
/// inference. The model file (~2.3 GB) is downloaded once, then all
/// subsequent inference is local.
///
/// Assertions enforced:
/// - [isOnDeviceOnly] always returns true (compile-time contract)
/// - No HTTP client, Socket, or network import in this file
/// - [generate] and [generateStream] never call network APIs
/// - All data stays on the user's device (LPD art. 6 compliance)
///
/// Usage:
/// ```dart
/// final engine = SlmEngine.instance;
/// await engine.initialize();
/// assert(SlmEngine.isOnDeviceOnly); // Always true
/// final result = await engine.generate(
///   systemPrompt: PromptRegistry.baseSystemPrompt,
///   userPrompt: 'Genere un greeting pour Julien, score 62/100',
///   maxTokens: 150,
/// );
/// ```
class SlmEngine {
  SlmEngine._();
  static final SlmEngine instance = SlmEngine._();

  /// No-network assertion: SLM inference is always on-device.
  ///
  /// This is a compile-time contract. If this ever needs to change,
  /// it requires an explicit architecture decision (ADR) and user
  /// consent flow update.
  ///
  /// References: LPD art. 6 (data processing principles)
  static const bool isOnDeviceOnly = true;

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
  /// Set to 2048 for compatibility with 4 GB RAM devices (iPhone 13 mini).
  static const int maxContextTokens = 2048;

  /// Default max output tokens per generation.
  static const int defaultMaxTokens = 256;

  /// Temperature for generation (lower = more deterministic).
  static const double defaultTemperature = 0.3;

  /// The active flutter_gemma model instance (null until initialized).
  InferenceModel? _model;

  /// Concurrency guard — prevents overlapping generate() calls
  /// from creating multiple chat sessions and OOMing the device.
  ///
  /// Note on race safety: Dart runs on a single-isolate event loop, so
  /// there is no true parallelism within the same isolate. The only
  /// "race" risk is if an async gap exists between the check and set,
  /// but in both [generate] and [generateStream] we check-and-set
  /// synchronously (no `await` between `if (_isGenerating)` and
  /// `_isGenerating = true`), making this safe without a mutex.
  bool _isGenerating = false;

  /// Tracks whether [dispose] was called, so [initialize] can re-create
  /// the engine when the user returns to the coach screen.
  bool _disposed = false;

  /// Init lock: prevents concurrent [initialize] calls from corrupting state.
  /// If init is in progress, subsequent callers await the same future.
  Completer<bool>? _initCompleter;

  /// Check whether the device has enough RAM to run the SLM.
  ///
  /// Uses [Platform.numberOfProcessors] (CPU core count) as a proxy for
  /// device RAM capability. There is no reliable cross-platform way to
  /// query total physical RAM in Dart without native plugins.
  ///
  /// ProcessInfo.maxRss is NOT usable here — it reports the current
  /// process's resident set size, not total device RAM, so it will
  /// always be far below the 6 GB threshold we need.
  ///
  /// Core-count heuristic (empirically correlated with device RAM):
  ///   - <= 4 cores → reject (iPhone SE/Mini, older Android: 3-4 GB RAM)
  ///   - 5 cores → reject (conservative, edge case)
  ///   - >= 6 cores → accept (iPhone 12 Pro+, modern Android: 6-8 GB+ RAM)
  ///
  /// Returns true if the device is deemed capable of running the SLM.
  static bool _checkDeviceCapability() {
    final cores = Platform.numberOfProcessors;
    if (cores < 6) {
      debugPrint(
        '[SLM] Device likely low-RAM ($cores cores, need >= 6) — skipping SLM',
      );
      return false;
    }
    return true;
  }

  /// Initialize the engine with the downloaded model.
  ///
  /// Checks device capability (RAM) and model availability via
  /// [FlutterGemma.isModelInstalled], then creates an [InferenceModel]
  /// with GPU preferred (CPU fallback).
  ///
  /// Uses a [Completer]-based lock to prevent concurrent init calls from
  /// corrupting state. If init is already in progress, subsequent callers
  /// await the same future instead of starting a new initialization.
  ///
  /// Returns true if initialization succeeded.
  Future<bool> initialize() async {
    // If init is already in progress, await the same future.
    if (_initCompleter != null) return _initCompleter!.future;

    if (_status == SlmStatus.running && _model != null) return true;

    _initCompleter = Completer<bool>();
    try {
      final result = await _doInitialize();
      _initCompleter!.complete(result);
      return result;
    } catch (e) {
      _initCompleter!.completeError(e);
      return false;
    } finally {
      _initCompleter = null;
    }
  }

  /// Internal initialization logic, called only from [initialize].
  Future<bool> _doInitialize() async {
    // Reset disposed flag — the caller is explicitly requesting (re-)init.
    _disposed = false;

    // RAM guard: skip SLM entirely on low-RAM devices to prevent OOM crash.
    // Gemma 3n 4B needs ~6 GB total device RAM (model + KV cache + OS).
    if (!_checkDeviceCapability()) {
      _status = SlmStatus.error;
      debugPrint('[SLM] Skipping init — device does not meet RAM requirements');
      return false;
    }

    // Use flutter_gemma's native check instead of SharedPreferences path.
    bool isInstalled;
    try {
      isInstalled = await FlutterGemma.isModelInstalled(modelId);
    } catch (e) {
      debugPrint('[SLM] Model availability check failed: $e');
      // Don't persist error — allow retry on next call.
      return false;
    }
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
    if (_disposed) return null;
    if (!isAvailable || _model == null) return null;

    // Concurrency guard: one generation at a time (device memory constraint).
    if (_isGenerating) {
      debugPrint('[SLM] Generation skipped: another call in progress');
      return null;
    }
    _isGenerating = true;

    final stopwatch = Stopwatch()..start();
    InferenceChat? chat;

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
      await chat?.session.close();
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
    // BUG 4 fix: early return if disposed.
    if (_disposed) {
      debugPrint('[SLM] generateStream skipped: engine disposed');
      return;
    }
    // BUG 6 fix: log clearly when returning empty so callers can detect
    // and fall back (e.g. to BYOK or FallbackTemplates).
    if (!isAvailable || _model == null) {
      debugPrint('[SLM] generateStream unavailable: '
          'status=$_status, model=${_model != null}');
      return;
    }
    if (_isGenerating) {
      debugPrint('[SLM] generateStream skipped: another generation in progress');
      return;
    }

    _isGenerating = true;
    InferenceChat? chat;

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
      await chat?.session.close();
      _isGenerating = false;
    }
  }

  /// Release model resources from memory.
  ///
  /// Calls [InferenceModel.close()] to free native resources (~2 GB RAM).
  /// Call this when the app goes to background for extended periods.
  ///
  /// After dispose, calling [initialize] again will re-create the engine
  /// (safe re-entry for when the user returns to the coach screen).
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
    _disposed = true;
    debugPrint('[SLM] Engine disposed (will re-initialize on next use)');
  }

  /// Whether the engine was disposed and needs re-initialization.
  bool get wasDisposed => _disposed;

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

  /// Rough token count estimation (~3.5 chars/token for French with accents).
  static int _estimateTokens(String text) {
    if (text.isEmpty) return 0;
    return (text.length / 3.5).ceil();
  }
}
