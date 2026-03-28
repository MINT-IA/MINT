import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/services/api_service.dart';

/// Response from the RAG query endpoint
/// A tool call returned by the LLM (e.g. route_to_screen).
class RagToolCall {
  final String name;
  final Map<String, dynamic> input;

  const RagToolCall({required this.name, required this.input});

  factory RagToolCall.fromJson(Map<String, dynamic> json) {
    return RagToolCall(
      name: json['name'] as String? ?? '',
      input: (json['input'] as Map<String, dynamic>?) ?? {},
    );
  }
}

class RagResponse {
  final String answer;
  final List<RagSource> sources;
  final List<String> disclaimers;
  final int tokensUsed;
  final List<RagToolCall> toolCalls;

  const RagResponse({
    required this.answer,
    required this.sources,
    required this.disclaimers,
    required this.tokensUsed,
    this.toolCalls = const [],
  });

  /// Whether the LLM returned tool_use blocks alongside text.
  bool get hasToolCalls => toolCalls.isNotEmpty;

  factory RagResponse.fromJson(Map<String, dynamic> json) {
    return RagResponse(
      answer: json['answer'] as String? ?? '',
      sources: (json['sources'] as List<dynamic>?)
              ?.map((s) => RagSource.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      disclaimers: (json['disclaimers'] as List<dynamic>?)
              ?.map((d) => d as String)
              .toList() ??
          [],
      tokensUsed: json['tokens_used'] as int? ?? 0,
      toolCalls: (json['tool_calls'] as List<dynamic>?)
              ?.map((t) => RagToolCall.fromJson(t as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// A source document referenced in a RAG response
class RagSource {
  final String title;
  final String file;
  final String section;

  const RagSource({
    required this.title,
    required this.file,
    required this.section,
  });

  factory RagSource.fromJson(Map<String, dynamic> json) {
    return RagSource(
      title: json['title'] as String? ?? '',
      file: json['file'] as String? ?? '',
      section: json['section'] as String? ?? '',
    );
  }
}

/// A single field extracted from a document image via vision LLM.
class RagExtractedField {
  final String fieldName;
  final String label;
  final double? value;
  final String? textValue;
  final double confidence;
  final String sourceText;

  const RagExtractedField({
    required this.fieldName,
    required this.label,
    this.value,
    this.textValue,
    this.confidence = 0.85,
    this.sourceText = '',
  });

  factory RagExtractedField.fromJson(Map<String, dynamic> json) {
    return RagExtractedField(
      fieldName: json['field_name'] as String? ?? '',
      label: json['label'] as String? ?? '',
      value: (json['value'] as num?)?.toDouble(),
      textValue: json['text_value'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.85,
      sourceText: json['source_text'] as String? ?? '',
    );
  }
}

/// Response from the RAG vision extraction endpoint.
class RagVisionResponse {
  final List<RagExtractedField> extractedFields;
  final String documentTypeDetected;
  final String rawAnalysis;
  final int confidenceDelta;
  final List<String> disclaimers;
  final int tokensUsed;

  const RagVisionResponse({
    required this.extractedFields,
    required this.documentTypeDetected,
    required this.rawAnalysis,
    required this.confidenceDelta,
    required this.disclaimers,
    required this.tokensUsed,
  });

  factory RagVisionResponse.fromJson(Map<String, dynamic> json) {
    return RagVisionResponse(
      extractedFields: (json['extracted_fields'] as List<dynamic>?)
              ?.map((f) => RagExtractedField.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      documentTypeDetected:
          json['document_type_detected'] as String? ?? '',
      rawAnalysis: json['raw_analysis'] as String? ?? '',
      confidenceDelta: json['confidence_delta'] as int? ?? 0,
      disclaimers: (json['disclaimers'] as List<dynamic>?)
              ?.map((d) => d as String)
              .toList() ??
          [],
      tokensUsed: json['tokens_used'] as int? ?? 0,
    );
  }
}

/// Status of the RAG vector store
class RagStatus {
  final bool vectorStoreReady;
  final int documentsCount;

  const RagStatus({
    required this.vectorStoreReady,
    required this.documentsCount,
  });

  factory RagStatus.fromJson(Map<String, dynamic> json) {
    return RagStatus(
      vectorStoreReady: json['vector_store_ready'] as bool? ?? false,
      documentsCount: json['documents_count'] as int? ?? 0,
    );
  }
}

/// Service for querying the MINT RAG (Retrieval-Augmented Generation) backend.
///
/// Supports BYOK (Bring Your Own Key) with Claude, OpenAI, and Mistral providers.
class RagService {
  final String baseUrl;

  RagService({String? baseUrl}) : baseUrl = baseUrl ?? ApiService.baseUrl;

  /// Query the RAG endpoint with a user question.
  ///
  /// [question] - The user's question about Swiss finance.
  /// [apiKey] - The user's own LLM API key (BYOK).
  /// [provider] - One of "claude", "openai", "mistral".
  /// [model] - Optional model override (e.g. "claude-sonnet-4-20250514").
  /// [profileContext] - Optional user profile data for personalization.
  /// [language] - Response language (defaults to "fr").
  Future<RagResponse> query({
    required String question,
    required String apiKey,
    required String provider,
    String? model,
    Map<String, dynamic>? profileContext,
    String language = 'fr',
    List<Map<String, dynamic>>? tools,
  }) async {
    final uri = Uri.parse('$baseUrl/rag/query');

    final body = <String, dynamic>{
      'question': question,
      'api_key': apiKey,
      'provider': provider,
      'language': language,
    };

    if (model != null) body['model'] = model;
    if (profileContext != null) body['profile_context'] = profileContext;
    if (tools != null) body['tools'] = tools;

    // T3-11: Retry with exponential backoff on 429 rate limit.
    const maxRetries = 2;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return RagResponse.fromJson(json);
      } else if (response.statusCode == 401) {
        throw const RagApiException(
          code: 'invalid_key',
          // ragErrorInvalidKey — user-visible, extracted to ARB
          message: 'La cl\u00e9 API est invalide ou expir\u00e9e.',
        );
      } else if (response.statusCode == 429) {
        if (attempt < maxRetries) {
          await Future<void>.delayed(Duration(seconds: (attempt + 1) * 2));
          continue;
        }
        throw const RagApiException(
          code: 'rate_limit',
          // ragErrorRateLimit — user-visible, extracted to ARB
          message: 'Limite de requ\u00eates atteinte. R\u00e9essaie dans quelques instants.',
        );
      } else if (response.statusCode == 400) {
        // T3-12: Specific error for bad request.
        final errorBody = _tryDecodeError(response.body);
        throw RagApiException(
          code: 'bad_request',
          // ragErrorBadRequest — user-visible fallback, extracted to ARB
          message: errorBody ?? 'Requ\u00eate invalide.',
        );
      } else if (response.statusCode == 503) {
        // T3-12: Specific error for service unavailable.
        throw const RagApiException(
          code: 'service_unavailable',
          // ragErrorServiceUnavailable — user-visible, extracted to ARB
          message: 'Service temporairement indisponible. R\u00e9essaie plus tard.',
        );
      } else {
        final errorBody = _tryDecodeError(response.body);
        throw RagApiException(
          code: 'server_error',
          message: errorBody ?? 'Erreur serveur (${response.statusCode}).', // Dynamic — not extracted
        );
      }
    }
    // Should never reach here, but dart analyzer needs it.
    throw const RagApiException(
      code: 'rate_limit',
      // ragErrorRateLimitShort — user-visible, extracted to ARB
      message: 'Limite de requ\u00eates atteinte.',
    );
  }

  /// Extract structured fields from a document image via BYOK vision LLM.
  ///
  /// [imageBase64] - Base64-encoded document image (JPEG/PNG/WEBP).
  /// [mediaType] - MIME type of the image.
  /// [documentType] - Target document type for extraction.
  /// [apiKey] - The user's own LLM API key (BYOK).
  /// [provider] - One of "claude", "openai" (must support vision).
  /// [language] - Response language (defaults to "fr").
  Future<RagVisionResponse> extractFromImage({
    required String imageBase64,
    required String mediaType,
    required String documentType,
    required String apiKey,
    required String provider,
    String? model,
    Map<String, dynamic>? profileContext,
    String language = 'fr',
  }) async {
    final uri = Uri.parse('$baseUrl/rag/vision');

    final body = <String, dynamic>{
      'image_base64': imageBase64,
      'media_type': mediaType,
      'document_type': documentType,
      'api_key': apiKey,
      'provider': provider,
      'language': language,
    };

    if (model != null) body['model'] = model;
    if (profileContext != null) body['profile_context'] = profileContext;

    final response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return RagVisionResponse.fromJson(json);
    } else if (response.statusCode == 400) {
      final errorBody = _tryDecodeError(response.body);
      throw RagApiException(
        code: 'vision_bad_request',
        // ragErrorVisionBadRequest — user-visible fallback, extracted to ARB
        message: errorBody ?? 'Requ\u00eate vision invalide.',
      );
    } else if (response.statusCode == 413) {
      throw const RagApiException(
        code: 'image_too_large',
        // ragErrorImageTooLarge — user-visible, extracted to ARB
        message: 'L\'image d\u00e9passe la taille limite de 20\u00a0MB.',
      );
    } else {
      final errorBody = _tryDecodeError(response.body);
      throw RagApiException(
        code: 'vision_error',
        message: errorBody ?? 'Erreur d\'extraction vision (${response.statusCode}).', // Dynamic — not extracted
      );
    }
  }

  /// Check the RAG system status (vector store readiness, document count).
  Future<RagStatus> getStatus() async {
    final uri = Uri.parse('$baseUrl/rag/status');

    final response = await http
        .get(uri, headers: {'Content-Type': 'application/json'})
        .timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return RagStatus.fromJson(json);
    } else {
      throw const RagApiException(
        code: 'status_error',
        // ragErrorStatus — user-visible, extracted to ARB
        message: 'Impossible de v\u00e9rifier le statut du syst\u00e8me RAG.',
      );
    }
  }

  String? _tryDecodeError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail'] as String? ?? json['message'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// Custom exception for RAG API errors.
class RagApiException implements Exception {
  final String code;
  final String message;

  const RagApiException({required this.code, required this.message});

  @override
  String toString() => 'RagApiException($code): $message';
}
