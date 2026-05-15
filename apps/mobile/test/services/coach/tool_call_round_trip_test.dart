// Wave 1b Plan 04 — JSON ↔ ToolCallCitationChip round-trip test.
//
// Asserts that the citationChips field surfaced by the backend (per
// wave-1b-04-AUDIT.md §3 Route b) deserializes into the Dart
// ToolCallCitationChip model with matching fields. Defensive parser
// accepts both camelCase (backend default) and snake_case (resilience).
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/rag_service.dart';

void main() {
  group('ToolCallCitationChip.fromJson', () {
    test('accepts camelCase keys (backend default)', () {
      final json = <String, dynamic>{
        'toolName': 'budget_snapshot',
        'inputsHash': 'a' * 64,
        'computedAt': '2026-05-15T10:00:00.000Z',
        'rawResponse': <String, dynamic>{'monthlyIncome': '7500'},
      };
      final chip = ToolCallCitationChip.fromJson(json);
      expect(chip.toolName, 'budget_snapshot');
      expect(chip.inputsHash, 'a' * 64);
      expect(chip.computedAt.toUtc().toIso8601String(),
          '2026-05-15T10:00:00.000Z');
      expect(chip.rawResponse['monthlyIncome'], '7500');
    });

    test('falls back to snake_case keys for resilience', () {
      final json = <String, dynamic>{
        'tool_name': 'retirement_projection',
        'inputs_hash': 'b' * 64,
        'computed_at': '2026-05-15T11:00:00.000Z',
        'raw_response': <String, dynamic>{'totalMonthly': '4200'},
      };
      final chip = ToolCallCitationChip.fromJson(json);
      expect(chip.toolName, 'retirement_projection');
      expect(chip.inputsHash, 'b' * 64);
      expect(chip.rawResponse['totalMonthly'], '4200');
    });

    test('handles missing fields with safe defaults', () {
      final chip = ToolCallCitationChip.fromJson(<String, dynamic>{});
      expect(chip.toolName, '');
      expect(chip.inputsHash, '');
      expect(chip.rawResponse.isEmpty, true);
    });

    test('handles all 6 Wave 1a tool names', () {
      for (final name in const <String>[
        'budget_snapshot',
        'retirement_projection',
        'cross_pillar_analysis',
        'couple_optimization',
        'cap_status',
        'retrieve_memories',
      ]) {
        final chip = ToolCallCitationChip.fromJson(<String, dynamic>{
          'toolName': name,
          'inputsHash': 'c' * 64,
          'computedAt': '2026-05-15T12:00:00.000Z',
          'rawResponse': <String, dynamic>{'_test': true},
        });
        expect(chip.toolName, name);
        expect(chip.inputsHash.length, 64);
      }
    });

    test('A1-verdict integration shape — fake backend response carries '
        'budget_snapshot inputs_hash to Dart chip', () {
      // Plan 04 must-have truth: "Round-trip test asserts a fake
      // backend response containing a budget_snapshot tool_result with
      // inputs_hash='a'*64 + computed_at='2026-05-15T10:00:00Z'
      // surfaces in Dart as ToolCallCitationChip with matching fields."
      final fakeBackendJson = <String, dynamic>{
        'message': '...',
        'citationChips': <Map<String, dynamic>>[
          <String, dynamic>{
            'toolName': 'budget_snapshot',
            'inputsHash': 'a' * 64,
            'computedAt': '2026-05-15T10:00:00.000Z',
            'rawResponse': <String, dynamic>{
              'monthlyIncome': '7500',
              'monthlyExpenses': '4200',
              'monthlySurplus': '3300',
              'monthsLiquidity': 6.2,
              'inputsHash': 'a' * 64,
              'computedAt': '2026-05-15T10:00:00Z',
            },
          },
        ],
      };
      final chipsJson =
          (fakeBackendJson['citationChips'] as List<dynamic>);
      final chips = chipsJson
          .whereType<Map<String, dynamic>>()
          .map(ToolCallCitationChip.fromJson)
          .toList();
      expect(chips, hasLength(1));
      final chip = chips.single;
      expect(chip.toolName, 'budget_snapshot');
      expect(chip.inputsHash, 'a' * 64);
      expect(chip.computedAt.toUtc().toIso8601String(),
          '2026-05-15T10:00:00.000Z');
      expect(chip.rawResponse['monthlyIncome'], '7500');
      expect(chip.rawResponse['inputsHash'], 'a' * 64);
    });
  });
}
