/// Web stub for flutter_gemma — provides type-compatible no-ops.
///
/// On native platforms (iOS/Android), the real flutter_gemma package
/// is used via conditional import in `gemma_interop.dart`.
/// On web, this stub ensures compilation succeeds and all SLM
/// operations gracefully return "unsupported".
library;

// ═══════════════════════════════════════════════════════════════
//  Enums
// ═══════════════════════════════════════════════════════════════

enum PreferredBackend { gpu, cpu }

enum ModelType { gemmaIt }

// ═══════════════════════════════════════════════════════════════
//  Response types
// ═══════════════════════════════════════════════════════════════

class ModelResponse {
  @override
  String toString() => '';
}

class TextResponse extends ModelResponse {
  final String token;
  TextResponse(this.token);
}

// ═══════════════════════════════════════════════════════════════
//  Message
// ═══════════════════════════════════════════════════════════════

class Message {
  final String text;
  final bool isUser;

  const Message._({required this.text, this.isUser = false});

  factory Message.systemInfo({required String text}) =>
      Message._(text: text);

  factory Message.text({required String text, bool isUser = false}) =>
      Message._(text: text, isUser: isUser);
}

// ═══════════════════════════════════════════════════════════════
//  Chat (no-op on web)
// ═══════════════════════════════════════════════════════════════

class Chat {
  Future<void> addQueryChunk(Message message) async {}
  Future<ModelResponse> generateChatResponse() async => ModelResponse();
  Stream<ModelResponse> generateChatResponseAsync() => const Stream.empty();
  Future<void> close() async {}
}

// ═══════════════════════════════════════════════════════════════
//  InferenceModel (no-op on web)
// ═══════════════════════════════════════════════════════════════

class InferenceModel {
  Future<Chat> createChat({
    double temperature = 0.3,
    int tokenBuffer = 256,
    int topK = 1,
  }) async => Chat();

  Future<void> close() async {}
}

// ═══════════════════════════════════════════════════════════════
//  CancelToken
// ═══════════════════════════════════════════════════════════════

class CancelToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;

  void cancel([String? reason]) => _cancelled = true;

  static bool isCancel(dynamic error) => false;
}

// ═══════════════════════════════════════════════════════════════
//  InstallBuilder (no-op chain)
// ═══════════════════════════════════════════════════════════════

class _InstallBuilder {
  _InstallBuilder fromNetwork(String url, {String? token}) => this;
  _InstallBuilder withProgress(void Function(int) callback) => this;
  _InstallBuilder withCancelToken(CancelToken token) => this;
  Future<void> install() async =>
      throw UnsupportedError('flutter_gemma not available on web');
}

// ═══════════════════════════════════════════════════════════════
//  FlutterGemma (web stub — all methods throw/return false)
// ═══════════════════════════════════════════════════════════════

class FlutterGemma {
  FlutterGemma._();

  static Future<bool> isModelInstalled(String modelId) async => false;

  static Future<InferenceModel> getActiveModel({
    int maxTokens = 8192,
    PreferredBackend preferredBackend = PreferredBackend.gpu,
  }) async =>
      throw UnsupportedError('flutter_gemma not available on web');

  static _InstallBuilder installModel({ModelType? modelType}) =>
      _InstallBuilder();

  static Future<void> uninstallModel(String modelId) async {}
}
