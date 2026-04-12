/// ChatToolDispatcher — normalizes and filters tool calls from both
/// the SLM text-marker path (ParsedToolCall) and the BYOK path (RagToolCall).
///
/// Threat model (T-02-01, T-02-02):
/// - normalize() caps output at [_maxToolCallsPerResponse] to prevent LLM
///   flooding the chat with excessive widgets.
/// - resolveRoute() validates routes via ToolCallParser.isValidRoute()
///   whitelist — rejects any route not in the known-good set.
library;

import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/coach/tool_call_parser.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';
import 'package:mint_mobile/services/rag_service.dart';

/// Dispatcher for coach tool calls.
///
/// Provides three static utility methods:
/// - [normalize]: convert SLM ParsedToolCall list to RagToolCall list
/// - [filterRag]: cap BYOK RagToolCall list at max allowed
/// - [resolveRoute]: validate and return a route string from tool call input
class ChatToolDispatcher {
  ChatToolDispatcher._();

  /// Maximum number of tool calls allowed per LLM response.
  ///
  /// Prevents LLM flooding the message bubble with excessive widgets.
  /// T-02-07 DoS mitigation — caps both SLM and BYOK paths.
  static const _maxToolCallsPerResponse = 5;

  /// Normalizes a list of [ParsedToolCall] (SLM text-marker path) to
  /// [RagToolCall] (BYOK path format).
  ///
  /// Converts SCREAMING_SNAKE_CASE tool names to snake_case so they match
  /// the WidgetRenderer switch cases (e.g. SHOW_FACT_CARD → show_fact_card).
  /// Caps output at [_maxToolCallsPerResponse]. Logs if capped.
  static List<RagToolCall> normalize(List<ParsedToolCall> parsed) {
    if (parsed.isEmpty) return const [];

    final capped = parsed.length > _maxToolCallsPerResponse
        ? parsed.take(_maxToolCallsPerResponse).toList()
        : parsed;

    if (parsed.length > _maxToolCallsPerResponse) {
      debugPrint(
        '[ChatToolDispatcher] Tool calls capped: '
        '${parsed.length} → $_maxToolCallsPerResponse',
      );
    }

    return capped
        .map(
          (p) => RagToolCall(
            name: p.toolName.toLowerCase(),
            input: p.arguments,
          ),
        )
        .toList();
  }

  /// Filters a list of [RagToolCall] (BYOK path) to at most
  /// [_maxToolCallsPerResponse] entries.
  ///
  /// Returns the list unchanged if already within the limit.
  static List<RagToolCall> filterRag(List<RagToolCall> calls) {
    if (calls.isEmpty) return const [];
    if (calls.length <= _maxToolCallsPerResponse) return calls;

    debugPrint(
      '[ChatToolDispatcher] RAG tool calls capped: '
      '${calls.length} → $_maxToolCallsPerResponse',
    );
    return calls.take(_maxToolCallsPerResponse).toList();
  }

  /// Resolves a route string from a tool call input map.
  ///
  /// Reads `input['route']` as a String and validates it against the
  /// ToolCallParser whitelist (T-02-01 mitigation).
  ///
  /// Returns the route if valid, null otherwise.
  ///
  /// If no explicit `route` is present, falls back to resolving `input['intent']`
  /// via [resolveRouteFromIntent] (STAB-01, D-02 — façade audit 07-02).
  static String? resolveRoute(Map<String, dynamic> input) {
    final route = input['route'] as String?;
    if (route != null && route.isNotEmpty) {
      if (!ToolCallParser.isValidRoute(route)) return null;
      return route;
    }
    // Fallback: resolve via intent tag (STAB-01).
    final intent = input['intent'] as String?;
    if (intent != null && intent.isNotEmpty) {
      return resolveRouteFromIntent(intent);
    }
    return null;
  }

  /// Resolves a canonical intent tag to a MINT GoRouter route.
  ///
  /// STAB-01 / D-02: the backend `route_to_screen` tool emits
  /// `{intent, confidence, context_message}` WITHOUT an explicit route.
  /// Mobile side resolves the intent via [MintScreenRegistry.findByIntentStatic]
  /// (the canonical source of truth for intent→route mapping) and validates
  /// the resulting route against the [ToolCallParser] whitelist.
  ///
  /// Returns the route if the intent is known AND the route passes the
  /// security whitelist. Returns null otherwise (silently dropped upstream).
  static String? resolveRouteFromIntent(String intent) {
    if (intent.isEmpty) return null;
    final entry = MintScreenRegistry.findByIntentStatic(intent);
    if (entry == null) return null;
    // Strip query string for whitelist check (e.g. '/retraite?mode=preretraite')
    final basePath = entry.route.split('?').first;
    if (!ToolCallParser.isValidRoute(basePath)) return null;
    return entry.route;
  }
}
