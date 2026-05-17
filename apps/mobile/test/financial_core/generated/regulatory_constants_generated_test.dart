// Phase mint-data-architecture-v1-01 Plan 04 Task 2 — Dart-side assertion
// of the generated artifact's shape + integrity.
//
// The codegen script (tools/codegen/regulatory_constants_to_dart.py) bakes
// the active backend regulatory snapshot into the generated file imported
// below. These tests lock the consumer contract :
//   - regulatoryConstantsVersionHash is a 64-char SHA-256 hex literal.
//   - regulatoryConstantsSnapshot decodes lazily to Map<String, dynamic>
//     and contains the expected top-level `parameters` list (non-empty).
//   - regulatoryConstantsEffectiveOn is an ISO 8601 date.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/generated/regulatory_constants.g.dart';

void main() {
  group('regulatory_constants.g.dart — Plan 04 generated artifact', () {
    test('version hash is non-empty SHA-256 hex', () {
      expect(regulatoryConstantsVersionHash, isNotEmpty);
      expect(regulatoryConstantsVersionHash.length, equals(64));
      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(regulatoryConstantsVersionHash),
        isTrue,
        reason: 'version hash must be lowercase 64-char hex',
      );
    });

    test('snapshot decodes cleanly to Map<String, dynamic>', () {
      expect(regulatoryConstantsSnapshot, isA<Map<String, dynamic>>());
      expect(regulatoryConstantsSnapshot.containsKey('parameters'), isTrue);
      final parameters = regulatoryConstantsSnapshot['parameters'] as List<dynamic>;
      expect(parameters, isNotEmpty);
      expect(regulatoryConstantsSnapshot.containsKey('version_hash'), isTrue);
      expect(regulatoryConstantsSnapshot['version_hash'], equals(regulatoryConstantsVersionHash));
    });

    test('effective_on is ISO 8601 date', () {
      expect(
        regulatoryConstantsEffectiveOn,
        matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')),
      );
    });
  });
}
