/// Parses tool call markers from coach response text.
///
/// Wire Spec V2 §3.6: The backend embeds tool calls as text markers
/// `[TOOL_NAME:{json}]` in the response. This parser extracts them
/// and returns clean text + structured tool calls.
library;

import 'dart:convert';

import 'package:mint_mobile/services/coach/_valid_routes_generated.dart';

/// A parsed tool call from coach response text.
class ParsedToolCall {
  final String toolName;
  final Map<String, dynamic> arguments;

  const ParsedToolCall({required this.toolName, required this.arguments});
}

/// Result of parsing a coach response for tool calls.
class ToolCallParseResult {
  /// The response text with all tool call markers removed.
  final String cleanText;

  /// Tool calls extracted from the response, in order of appearance.
  final List<ParsedToolCall> toolCalls;

  const ToolCallParseResult({
    required this.cleanText,
    required this.toolCalls,
  });

  bool get hasToolCalls => toolCalls.isNotEmpty;
}

/// Parser for tool call markers in coach response text.
class ToolCallParser {
  // Pattern: [TOOL_NAME:{...json...}]
  // Uses a non-greedy match for the JSON body to handle nested braces minimally.
  static final _pattern = RegExp(r'\[([A-Z_]+):\{(.*?)\}\]');

  /// Parse a coach response text, extracting tool calls and cleaning the text.
  static ToolCallParseResult parse(String text) {
    final toolCalls = <ParsedToolCall>[];
    final cleanText = text.replaceAllMapped(_pattern, (match) {
      final toolName = match.group(1)!;
      final jsonStr = '{${match.group(2)!}}';
      try {
        final args = jsonDecode(jsonStr) as Map<String, dynamic>;
        toolCalls.add(ParsedToolCall(toolName: toolName, arguments: args));
      } catch (_) {
        // Malformed JSON — skip this tool call, leave marker in text
        return match.group(0)!;
      }
      return ''; // Remove the marker from the clean text
    });

    return ToolCallParseResult(
      cleanText: cleanText.trim(),
      toolCalls: toolCalls,
    );
  }

  /// Set of routes the coach is allowed to navigate to.
  /// Rejects any route not in this whitelist (security).
  ///
  /// Phase 53-04: now generated from MintScreenRegistry via
  /// `tools/contracts/regen_screen_registry_contract.py`. Single
  /// source of truth lives in `screen_registry.dart`. The CI gate
  /// `tools/checks/screen_registry_three_way_parity.py` enforces
  /// the contract — drift fails CI with a clear diagnostic.
  static const Set<String> validRoutes = kGeneratedValidRoutes;

  /// Check if a route is in the whitelist.
  static bool isValidRoute(String route) => validRoutes.contains(route);
}
