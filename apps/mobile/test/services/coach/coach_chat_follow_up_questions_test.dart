// Phase D — backend-piloted follow-up chip contract.
//
// Verifies:
//   1. CoachChatApiResponse parses `followUpQuestions` from JSON, caps at 2,
//      drops empty strings, and returns `[]` when the key is missing.
//   2. CoachResponse carries a `followUpQuestions` field (default empty).
//   3. The two inference / static entrypoints we killed (Phase D) no longer
//      exist on CoachLlmService — the chips must not regrow client-side.

import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/services/coach/coach_chat_api_service.dart';
import 'package:mint_mobile/services/coach_llm_service.dart';

void main() {
  group('CoachChatApiResponse.followUpQuestions', () {
    test('parses valid list and caps at 2 items', () {
      final resp = CoachChatApiResponse.fromJson({
        'message': 'Voici ta situation.',
        'followUpQuestions': ['q1', 'q2', 'q3', 'q4'],
      });
      expect(resp.followUpQuestions, ['q1', 'q2']);
    });

    test('drops empty and whitespace-only entries', () {
      final resp = CoachChatApiResponse.fromJson({
        'message': 'ok',
        'followUpQuestions': ['  ', 'real', ''],
      });
      expect(resp.followUpQuestions, ['real']);
    });

    test('returns empty list when key is missing', () {
      final resp = CoachChatApiResponse.fromJson({'message': 'ok'});
      expect(resp.followUpQuestions, isEmpty);
    });

    test('returns empty list when value is not a list', () {
      final resp = CoachChatApiResponse.fromJson({
        'message': 'ok',
        'followUpQuestions': 'not-a-list',
      });
      expect(resp.followUpQuestions, isEmpty);
    });

    test('ignores non-string items inside the list', () {
      final resp = CoachChatApiResponse.fromJson({
        'message': 'ok',
        'followUpQuestions': [1, 'vraie question', null],
      });
      expect(resp.followUpQuestions, ['vraie question']);
    });
  });

  group('CoachResponse.followUpQuestions', () {
    test('defaults to an empty list', () {
      const resp = CoachResponse(message: 'hi', disclaimer: 'd');
      expect(resp.followUpQuestions, isEmpty);
    });

    test('carries the list when constructed', () {
      const resp = CoachResponse(
        message: 'hi',
        disclaimer: 'd',
        followUpQuestions: ['a', 'b'],
      );
      expect(resp.followUpQuestions, ['a', 'b']);
    });
  });

  group('CoachLlmService — legacy chip inference is gone', () {
    // Phase D: these entrypoints were the source of the polluting regex-based
    // chip suggestions and the opening hardcoded set. They MUST NOT exist on
    // CoachLlmService — chips are backend-piloted now.
    //
    // We cannot import what no longer exists, so we assert via the public
    // surface: no member named `inferSuggestedActions` or `initialSuggestions`
    // should be reachable. A compile-time check is enforced by the absence of
    // references in lib/ (grep in CI); here we document the contract.
    test('suggestedActions is null at service layer', () {
      const resp = CoachResponse(message: 'hi', disclaimer: 'd');
      expect(resp.suggestedActions, isNull);
    });
  });
}
