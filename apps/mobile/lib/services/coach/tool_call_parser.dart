/// Parses tool call markers from coach response text.
///
/// Wire Spec V2 §3.6: The backend embeds tool calls as text markers
/// `[TOOL_NAME:{json}]` in the response. This parser extracts them
/// and returns clean text + structured tool calls.
library;

import 'dart:convert';

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
  static const validRoutes = <String>{
    '/retraite',
    '/rente-vs-capital',
    '/rachat-lpp',
    '/epl',
    '/decaissement',
    '/succession',
    '/libre-passage',
    '/pilier-3a',
    '/3a-deep/comparator',
    '/3a-deep/real-return',
    '/3a-deep/staggered-withdrawal',
    '/3a-retroactif',
    '/fiscal',
    '/hypotheque',
    '/mortgage/amortization',
    '/mortgage/epl-combined',
    '/mortgage/imputed-rental',
    '/mortgage/saron-vs-fixed',
    '/budget',
    '/check/debt',
    '/debt/ratio',
    '/debt/help',
    '/debt/repayment',
    '/divorce',
    '/mariage',
    '/naissance',
    '/concubinage',
    '/life-event/housing-sale',
    '/life-event/donation',
    '/life-event/deces-proche',
    '/life-event/demenagement-cantonal',
    '/unemployment',
    '/first-job',
    '/expatriation',
    '/simulator/job-comparison',
    '/segments/independant',
    '/independants/avs',
    '/independants/ijm',
    '/independants/3a',
    '/independants/dividende-salaire',
    '/independants/lpp-volontaire',
    '/invalidite',
    '/disability/insurance',
    '/disability/self-employed',
    '/assurances/lamal',
    '/assurances/coverage',
    '/scan',
    '/documents',
    '/arbitrage/bilan',
    '/arbitrage/allocation-annuelle',
    '/arbitrage/location-vs-propriete',
    '/simulator/compound',
    '/simulator/leasing',
    '/simulator/credit',
    '/segments/gender-gap',
    '/segments/frontalier',
    '/education/hub',
    '/profile',
    '/profile/bilan',
    '/profile/byok',
    '/rapport',
    '/couple',
    '/explore/retraite',
    '/explore/famille',
    '/explore/travail',
    '/explore/logement',
    '/explore/fiscalite',
    '/explore/patrimoine',
    '/explore/sante',
  };

  /// Check if a route is in the whitelist.
  static bool isValidRoute(String route) => validRoutes.contains(route);
}
