import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/coach/tool_call_parser.dart';

void main() {
  group('ToolCallParser', () {
    test('parses ROUTE_TO_SCREEN from text', () {
      const text =
          'Voici ta projection. [ROUTE_TO_SCREEN:{"route":"/rachat-lpp"}] Bonne journ\u00e9e.';
      final result = ToolCallParser.parse(text);
      expect(result.hasToolCalls, isTrue);
      expect(result.toolCalls.length, 1);
      expect(result.toolCalls[0].toolName, 'ROUTE_TO_SCREEN');
      expect(result.toolCalls[0].arguments['route'], '/rachat-lpp');
      expect(result.cleanText, 'Voici ta projection.  Bonne journ\u00e9e.');
    });

    test('parses multiple tool calls', () {
      const text =
          '[SHOW_FACT_CARD:{"title":"AVS","value":"3780"}] Et aussi [ROUTE_TO_SCREEN:{"route":"/retraite"}]';
      final result = ToolCallParser.parse(text);
      expect(result.toolCalls.length, 2);
      expect(result.toolCalls[0].toolName, 'SHOW_FACT_CARD');
      expect(result.toolCalls[0].arguments['title'], 'AVS');
      expect(result.toolCalls[0].arguments['value'], '3780');
      expect(result.toolCalls[1].toolName, 'ROUTE_TO_SCREEN');
      expect(result.toolCalls[1].arguments['route'], '/retraite');
      expect(result.cleanText, 'Et aussi');
    });

    test('handles text with no tool calls', () {
      const text = "Bonjour, comment puis-je t'aider\u00a0?";
      final result = ToolCallParser.parse(text);
      expect(result.hasToolCalls, isFalse);
      expect(result.toolCalls, isEmpty);
      expect(result.cleanText, text);
    });

    test('handles malformed JSON gracefully', () {
      const text = 'Test [BROKEN:{not valid json}] end';
      final result = ToolCallParser.parse(text);
      // Malformed JSON should be kept in the text, not parsed
      expect(result.hasToolCalls, isFalse);
      expect(result.cleanText, contains('BROKEN'));
    });

    test('handles empty text', () {
      final result = ToolCallParser.parse('');
      expect(result.hasToolCalls, isFalse);
      expect(result.cleanText, '');
    });

    test('handles text that is only a tool call', () {
      const text = '[ROUTE_TO_SCREEN:{"route":"/budget"}]';
      final result = ToolCallParser.parse(text);
      expect(result.hasToolCalls, isTrue);
      expect(result.toolCalls.length, 1);
      expect(result.cleanText, '');
    });

    test('preserves text around tool calls', () {
      const text = 'Avant [ROUTE_TO_SCREEN:{"route":"/fiscal"}] Apr\u00e8s';
      final result = ToolCallParser.parse(text);
      expect(result.cleanText, 'Avant  Apr\u00e8s');
    });

    test('isValidRoute accepts whitelisted routes', () {
      expect(ToolCallParser.isValidRoute('/rachat-lpp'), isTrue);
      expect(ToolCallParser.isValidRoute('/budget'), isTrue);
      expect(ToolCallParser.isValidRoute('/pilier-3a'), isTrue);
      expect(ToolCallParser.isValidRoute('/explore/retraite'), isTrue);
      expect(ToolCallParser.isValidRoute('/mortgage/amortization'), isTrue);
    });

    test('isValidRoute rejects non-whitelisted routes', () {
      expect(ToolCallParser.isValidRoute('https://evil.com'), isFalse);
      expect(ToolCallParser.isValidRoute('/admin/delete'), isFalse);
      expect(ToolCallParser.isValidRoute(''), isFalse);
      expect(ToolCallParser.isValidRoute('/arbitrary/path'), isFalse);
      expect(ToolCallParser.isValidRoute('javascript:alert(1)'), isFalse);
    });

    test('does not match lowercase tool names', () {
      const text = 'Test [route_to_screen:{"route":"/budget"}] end';
      final result = ToolCallParser.parse(text);
      expect(result.hasToolCalls, isFalse);
      expect(result.cleanText, text);
    });

    test('parses tool call with nested JSON values', () {
      const text =
          '[SHOW_FACT_CARD:{"title":"LPP","value":"70377","unit":"CHF"}]';
      final result = ToolCallParser.parse(text);
      expect(result.hasToolCalls, isTrue);
      expect(result.toolCalls[0].arguments['unit'], 'CHF');
    });
  });
}
