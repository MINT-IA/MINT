import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/chat_tool_dispatcher.dart';
import 'package:mint_mobile/services/coach/tool_call_parser.dart';
import 'package:mint_mobile/services/rag_service.dart';

void main() {
  group('ChatToolDispatcher.normalize', () {
    test('converts ParsedToolCall SCREAMING_SNAKE to snake_case RagToolCall', () {
      final parsed = [
        const ParsedToolCall(
          toolName: 'SHOW_FACT_CARD',
          arguments: {'value': '42'},
        ),
      ];
      final result = ChatToolDispatcher.normalize(parsed);
      expect(result.length, 1);
      expect(result[0].name, 'show_fact_card');
      expect(result[0].input, {'value': '42'});
    });

    test('returns empty list for empty input', () {
      final result = ChatToolDispatcher.normalize([]);
      expect(result, isEmpty);
    });

    test('caps at 5 when input has 7 ParsedToolCalls', () {
      final parsed = List.generate(
        7,
        (i) => ParsedToolCall(
          toolName: 'TOOL_$i',
          arguments: {'index': i},
        ),
      );
      final result = ChatToolDispatcher.normalize(parsed);
      expect(result.length, 5);
    });

    test('returns all 3 when input has exactly 3 ParsedToolCalls', () {
      final parsed = List.generate(
        3,
        (i) => ParsedToolCall(
          toolName: 'TOOL_$i',
          arguments: {'index': i},
        ),
      );
      final result = ChatToolDispatcher.normalize(parsed);
      expect(result.length, 3);
    });

    test('preserves arguments map from ParsedToolCall', () {
      const args = {'route': '/retraite', 'context_message': 'test'};
      final parsed = [
        const ParsedToolCall(toolName: 'ROUTE_TO_SCREEN', arguments: args),
      ];
      final result = ChatToolDispatcher.normalize(parsed);
      expect(result[0].input, args);
    });

    test('lowercases multi-word tool names correctly', () {
      final parsed = [
        const ParsedToolCall(
          toolName: 'SHOW_RETIREMENT_COMPARISON',
          arguments: {},
        ),
      ];
      final result = ChatToolDispatcher.normalize(parsed);
      expect(result[0].name, 'show_retirement_comparison');
    });
  });

  group('ChatToolDispatcher.filterRag', () {
    test('caps at 5 when input has 7 RagToolCalls', () {
      final calls = List.generate(
        7,
        (i) => RagToolCall(name: 'tool_$i', input: {}),
      );
      final result = ChatToolDispatcher.filterRag(calls);
      expect(result.length, 5);
    });

    test('returns all 3 when input has 3 RagToolCalls', () {
      final calls = List.generate(
        3,
        (i) => RagToolCall(name: 'tool_$i', input: {}),
      );
      final result = ChatToolDispatcher.filterRag(calls);
      expect(result.length, 3);
    });

    test('returns empty list for empty input', () {
      final result = ChatToolDispatcher.filterRag([]);
      expect(result, isEmpty);
    });

    test('returns exactly 5 when input has exactly 5 RagToolCalls', () {
      final calls = List.generate(
        5,
        (i) => RagToolCall(name: 'tool_$i', input: {}),
      );
      final result = ChatToolDispatcher.filterRag(calls);
      expect(result.length, 5);
    });
  });

  group('ChatToolDispatcher.resolveRoute', () {
    test('returns valid route when in whitelist', () {
      final result = ChatToolDispatcher.resolveRoute({
        'route': '/rente-vs-capital',
      });
      expect(result, '/rente-vs-capital');
    });

    test('returns null for route not in whitelist', () {
      final result = ChatToolDispatcher.resolveRoute({
        'route': '/admin/evil',
      });
      expect(result, isNull);
    });

    test('returns null when route key is null', () {
      final result = ChatToolDispatcher.resolveRoute({'route': null});
      expect(result, isNull);
    });

    test('returns null when route key is absent', () {
      final result = ChatToolDispatcher.resolveRoute({});
      expect(result, isNull);
    });

    test(
      'resolves intent key via MintScreenRegistry (STAB-01, 07-02)',
      () {
        // 'retirement_choice' is a canonical intent registered in
        // MintScreenRegistry that resolves to /rente-vs-capital, which is
        // in the ToolCallParser whitelist.
        final result = ChatToolDispatcher.resolveRoute({
          'intent': 'retirement_choice',
        });
        expect(result, isNotNull);
        expect(result, startsWith('/'));
        // Must pass the whitelist (base path only, strip query string).
        expect(ToolCallParser.isValidRoute(result!.split('?').first), isTrue);
      },
    );

    test('returns null for unknown intent', () {
      final result = ChatToolDispatcher.resolveRoute({
        'intent': 'totally_unknown_intent_xyz',
      });
      expect(result, isNull);
    });

    test('returns valid route for /rachat-lpp', () {
      final result = ChatToolDispatcher.resolveRoute({'route': '/rachat-lpp'});
      expect(result, '/rachat-lpp');
    });

    test('returns null for empty string route', () {
      final result = ChatToolDispatcher.resolveRoute({'route': ''});
      expect(result, isNull);
    });

    test('returns valid route for /retraite', () {
      final result = ChatToolDispatcher.resolveRoute({'route': '/retraite'});
      expect(result, '/retraite');
    });
  });
}
