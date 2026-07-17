import 'dart:convert';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/authenticated_transport.dart';

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

/// Response from the RAG query endpoint
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
      // FIX-088: Safe int parse — backend may return String or int.
      tokensUsed: json['tokens_used'] is int
          ? json['tokens_used'] as int
          : int.tryParse(json['tokens_used']?.toString() ?? '') ?? 0,
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
              ?.map(
                  (f) => RagExtractedField.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      documentTypeDetected: json['document_type_detected'] as String? ?? '',
      rawAnalysis: json['raw_analysis'] as String? ?? '',
      confidenceDelta: json['confidence_delta'] as int? ?? 0,
      disclaimers: (json['disclaimers'] as List<dynamic>?)
              ?.map((d) => d as String)
              .toList() ??
          [],
      // FIX-088: Safe int parse — backend may return String or int.
      tokensUsed: json['tokens_used'] is int
          ? json['tokens_used'] as int
          : int.tryParse(json['tokens_used']?.toString() ?? '') ?? 0,
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
  final AuthenticatedTransport _transport;
  final Map<String, String> _headers;

  RagService({
    String? baseUrl,
    AuthenticatedTransport? transport,
    Map<String, String> headers = const {},
  })  : baseUrl = baseUrl ?? ApiService.baseUrl,
        _transport = transport ?? ApiService.authenticatedTransport,
        _headers = Map<String, String>.unmodifiable(headers);

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
    int cashLevel = 3,
  }) async {
    final operation = _transport.beginOperation();
    await operation.requireSession();
    final uri = Uri.parse('$baseUrl/rag/query');

    final body = <String, dynamic>{
      'question': question,
      'api_key': apiKey,
      'provider': provider,
      'language': language,
      'cash_level': cashLevel.clamp(1, 5),
    };

    if (model != null) body['model'] = model;
    if (profileContext != null) body['profile_context'] = profileContext;
    if (tools != null) body['tools'] = tools;

    // T3-11: Retry with exponential backoff on 429 rate limit.
    const maxRetries = 2;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      final response = await operation.send(
        AuthenticatedRequest.json(
          AuthenticatedHttpMethod.post,
          uri,
          body,
          headers: _headers,
          timeout: const Duration(seconds: 60),
        ),
      );

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        return RagResponse.fromJson(json);
      } else if (response.statusCode == 401) {
        throw RagApiException.machine(RagErrorCode.invalidKey);
      } else if (response.statusCode == 429) {
        if (attempt < maxRetries) {
          await Future<void>.delayed(Duration(seconds: (attempt + 1) * 2));
          continue;
        }
        throw RagApiException.machine(RagErrorCode.rateLimit);
      } else if (response.statusCode == 400) {
        // T3-12: Specific error for bad request.
        final errorBody = _tryDecodeError(response.body);
        throw errorBody == null
            ? RagApiException.machine(RagErrorCode.badRequest)
            : RagApiException(code: 'bad_request', message: errorBody);
      } else if (response.statusCode == 503) {
        // T3-12: Specific error for service unavailable.
        throw RagApiException.machine(RagErrorCode.serviceUnavailable);
      } else {
        final errorBody = _tryDecodeError(response.body);
        throw errorBody == null
            ? RagApiException.machine(RagErrorCode.serverError)
            : RagApiException(code: 'server_error', message: errorBody);
      }
    }
    // Should never reach here, but dart analyzer needs it.
    throw RagApiException.machine(RagErrorCode.rateLimit);
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
    if (documentType == 'tax_declaration') {
      throw RagApiException.machine(RagErrorCode.taxLocalOnly);
    }
    final operation = _transport.beginOperation();
    await operation.requireSession();
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

    // FIX-084: Retry on 429 (same pattern as query()).
    const maxRetries = 2;
    late AuthenticatedResponse response;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      response = await operation.send(
        AuthenticatedRequest.json(
          AuthenticatedHttpMethod.post,
          uri,
          body,
          headers: _headers,
          timeout: const Duration(seconds: 120),
        ),
      );

      if (response.statusCode == 429 && attempt < maxRetries) {
        await Future<void>.delayed(Duration(seconds: (attempt + 1) * 2));
        continue;
      }
      break;
    }

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return RagVisionResponse.fromJson(json);
    } else if (response.statusCode == 400) {
      final errorBody = _tryDecodeError(response.body);
      throw errorBody == null
          ? RagApiException.machine(RagErrorCode.visionBadRequest)
          : RagApiException(code: 'vision_bad_request', message: errorBody);
    } else if (response.statusCode == 413) {
      throw RagApiException.machine(RagErrorCode.imageTooLarge);
    } else {
      final errorBody = _tryDecodeError(response.body);
      throw errorBody == null
          ? RagApiException.machine(RagErrorCode.visionError)
          : RagApiException(code: 'vision_error', message: errorBody);
    }
  }

  /// Check the RAG system status (vector store readiness, document count).
  Future<RagStatus> getStatus() async {
    final operation = _transport.beginOperation();
    await operation.requireSession();
    final uri = Uri.parse('$baseUrl/rag/status');

    final response = await operation.send(
      AuthenticatedRequest.get(
        uri,
        headers: _headers,
        timeout: const Duration(seconds: 10),
      ),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return RagStatus.fromJson(json);
    } else {
      throw RagApiException.machine(RagErrorCode.statusError);
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

/// Stable machine identities for failures produced by [RagService].
///
/// Presentation layers resolve these codes through `AppLocalizations`; raw
/// backend details are diagnostic data and must never become UI copy.
enum RagErrorCode {
  invalidKey('invalid_key'),
  rateLimit('rate_limit'),
  badRequest('bad_request'),
  serviceUnavailable('service_unavailable'),
  serverError('server_error'),
  taxLocalOnly('tax_local_only'),
  visionBadRequest('vision_bad_request'),
  imageTooLarge('image_too_large'),
  visionError('vision_error'),
  statusError('status_error'),
  unknown('unknown');

  const RagErrorCode(this.machineCode);

  final String machineCode;

  static RagErrorCode fromMachineCode(String code) {
    for (final value in values) {
      if (value.machineCode == code) return value;
    }
    return unknown;
  }
}

/// Custom exception for RAG API errors.
class RagApiException implements Exception {
  final String code;
  final String message;

  const RagApiException({required this.code, required this.message});

  factory RagApiException.machine(RagErrorCode errorCode) {
    return RagApiException(code: errorCode.machineCode, message: '');
  }

  RagErrorCode get errorCode => RagErrorCode.fromMachineCode(code);

  @override
  String toString() => message.isEmpty
      ? 'RagApiException($code)'
      : 'RagApiException($code): $message';
}
