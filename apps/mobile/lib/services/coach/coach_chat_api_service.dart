import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/rag_service.dart' show RagSource, RagToolCall;

/// HTTP client for POST /api/v1/coach/chat — the server-key tier.
///
/// Unlike [RagService] (which sends the user's BYOK key to /rag/query),
/// this service sends NO api_key. The backend fills in its own
/// ANTHROPIC_API_KEY when api_key is empty (beta mode).
///
/// Requires JWT auth (user must be logged in).
class CoachChatApiService {
  final String baseUrl;

  CoachChatApiService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiService.baseUrl;

  /// Send a chat message via the server-key /coach/chat endpoint.
  ///
  /// Returns [CoachChatApiResponse] with AI-generated text, sources,
  /// disclaimers, and optional tool_calls.
  ///
  /// Throws on auth errors (401), entitlement errors (403), or
  /// service unavailable (502/503). Returns normally on success.
  /// The orchestrator catches all exceptions and falls through to fallback.
  Future<CoachChatApiResponse> chat({
    required String message,
    Map<String, dynamic>? profileContext,
    String? memoryBlock,
    String language = 'fr',
    int cashLevel = 3,
  }) async {
    final uri = Uri.parse('$baseUrl/coach/chat');

    final token = await AuthService.getToken();
    if (token == null || token.isEmpty) {
      throw const CoachChatApiException(
        code: 'no_auth',
        message: 'Not authenticated — server-key chat requires login.',
      );
    }

    final body = <String, dynamic>{
      'message': message,
      'provider': 'claude',
      'language': language,
      'cash_level': cashLevel.clamp(1, 5),
    };

    if (profileContext != null) body['profile_context'] = profileContext;
    if (memoryBlock != null && memoryBlock.isNotEmpty) {
      body['memory_block'] = memoryBlock;
    }
    // No api_key — backend fills in server-side ANTHROPIC_API_KEY

    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $token',
          },
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return CoachChatApiResponse.fromJson(json);
    } else if (response.statusCode == 401) {
      throw const CoachChatApiException(
        code: 'auth_error',
        message: 'Authentication failed.',
      );
    } else if (response.statusCode == 403) {
      debugPrint('[CoachChatApi] 403 — entitlement gate or permission denied');
      throw const CoachChatApiException(
        code: 'entitlement',
        message: 'Premium required.',
      );
    } else if (response.statusCode == 502 || response.statusCode == 503) {
      throw const CoachChatApiException(
        code: 'service_unavailable',
        message: 'Coach AI temporarily unavailable.',
      );
    } else {
      final errorBody = _tryDecodeError(response.body);
      throw CoachChatApiException(
        code: 'server_error',
        message: errorBody ?? 'Server error (${response.statusCode}).',
      );
    }
  }

  static String? _tryDecodeError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// Response from /coach/chat endpoint.
class CoachChatApiResponse {
  final String message;
  final List<RagToolCall> toolCalls;
  final List<RagSource> sources;
  final List<String> disclaimers;
  final int tokensUsed;

  const CoachChatApiResponse({
    required this.message,
    this.toolCalls = const [],
    this.sources = const [],
    this.disclaimers = const [],
    this.tokensUsed = 0,
  });

  factory CoachChatApiResponse.fromJson(Map<String, dynamic> json) {
    return CoachChatApiResponse(
      message: json['message'] as String? ?? '',
      toolCalls: (json['tool_calls'] as List?)
              ?.map((tc) => RagToolCall(
                    name: tc['name'] as String? ?? '',
                    input: (tc['input'] as Map<String, dynamic>?) ?? {},
                  ))
              .toList() ??
          const [],
      sources: (json['sources'] as List?)
              ?.map((s) => RagSource(
                    title: s['title'] as String? ?? '',
                    file: s['file'] as String? ?? '',
                    section: s['section'] as String? ?? '',
                  ))
              .toList() ??
          const [],
      disclaimers: (json['disclaimers'] as List?)
              ?.map((d) => d as String)
              .toList() ??
          const [],
      tokensUsed: json['tokens_used'] as int? ?? 0,
    );
  }
}

/// Exception thrown by [CoachChatApiService].
class CoachChatApiException implements Exception {
  final String code;
  final String message;

  const CoachChatApiException({required this.code, required this.message});

  @override
  String toString() => 'CoachChatApiException($code): $message';
}
