import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/services/api_service.dart';

/// Response from the RAG query endpoint
class RagResponse {
  final String answer;
  final List<RagSource> sources;
  final List<String> disclaimers;
  final int tokensUsed;

  const RagResponse({
    required this.answer,
    required this.sources,
    required this.disclaimers,
    required this.tokensUsed,
  });

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
      throw RagApiException(
        code: 'invalid_key',
        message: 'La cl\u00e9 API est invalide ou expir\u00e9e.',
      );
    } else if (response.statusCode == 429) {
      throw RagApiException(
        code: 'rate_limit',
        message: 'Limite de requ\u00eates atteinte. R\u00e9essaie dans quelques instants.',
      );
    } else {
      final errorBody = _tryDecodeError(response.body);
      throw RagApiException(
        code: 'server_error',
        message: errorBody ?? 'Erreur serveur (${response.statusCode}).',
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
      throw RagApiException(
        code: 'status_error',
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
