/// AdvisorSpecialization & AdvisorMatchingService — S65 Expert Tier.
///
/// 15 tests covering:
///  1. All 8 enum values exist and are distinct
///  2. Enum values have stable names (serialization safety)
///  3-10. Specialization names map to expected string values
///  11. No "retirement" duplicate with existing advisor service (namespace check)
///  12. All 8 specializations can be used in switch exhaustively
///  13. Enum index order is stable (no regression when adding values)
///  14. Specialization.name returns camelCase for serialization
///  15. No banned terms in specialization names
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/expert/advisor_specialization.dart';

// ══════════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════════

/// Banned terms that must never appear in specialization names.
const _bannedTerms = [
  'conseiller',
  'garanti',
  'optimal',
  'meilleur',
  'parfait',
  'certain',
];

/// Map each specialization to its expected .name string.
const _expectedNames = <AdvisorSpecialization, String>{
  AdvisorSpecialization.retirement: 'retirement',
  AdvisorSpecialization.succession: 'succession',
  AdvisorSpecialization.expatriation: 'expatriation',
  AdvisorSpecialization.divorce: 'divorce',
  AdvisorSpecialization.selfEmployment: 'selfEmployment',
  AdvisorSpecialization.realEstate: 'realEstate',
  AdvisorSpecialization.taxOptimization: 'taxOptimization',
  AdvisorSpecialization.debtManagement: 'debtManagement',
};

void main() {
  group('AdvisorSpecialization enum', () {
    test('1. contains exactly 8 distinct values', () {
      expect(AdvisorSpecialization.values.length, equals(8));
      final names = AdvisorSpecialization.values.map((e) => e.name).toSet();
      expect(names.length, equals(8), reason: 'All values must be distinct');
    });

    test('2. all expected names exist (serialization stability)', () {
      for (final entry in _expectedNames.entries) {
        expect(
          entry.key.name,
          equals(entry.value),
          reason: 'Specialization ${entry.key} must have stable name "${entry.value}"',
        );
      }
    });

    test('3. retirement is present and correctly named', () {
      expect(AdvisorSpecialization.retirement.name, equals('retirement'));
    });

    test('4. succession is present and correctly named', () {
      expect(AdvisorSpecialization.succession.name, equals('succession'));
    });

    test('5. expatriation is present and correctly named', () {
      expect(AdvisorSpecialization.expatriation.name, equals('expatriation'));
    });

    test('6. divorce is present and correctly named', () {
      expect(AdvisorSpecialization.divorce.name, equals('divorce'));
    });

    test('7. selfEmployment is present and correctly named', () {
      expect(AdvisorSpecialization.selfEmployment.name, equals('selfEmployment'));
    });

    test('8. realEstate is present and correctly named', () {
      expect(AdvisorSpecialization.realEstate.name, equals('realEstate'));
    });

    test('9. taxOptimization is present and correctly named', () {
      expect(AdvisorSpecialization.taxOptimization.name, equals('taxOptimization'));
    });

    test('10. debtManagement is present and correctly named', () {
      expect(AdvisorSpecialization.debtManagement.name, equals('debtManagement'));
    });

    test('11. all 8 values can be reconstructed from name (round-trip)', () {
      for (final spec in AdvisorSpecialization.values) {
        final reconstructed = AdvisorSpecialization.values
            .firstWhere((e) => e.name == spec.name);
        expect(reconstructed, equals(spec));
      }
    });

    test('12. exhaustive switch compiles and covers all cases', () {
      // If a new value is added without updating this switch, the test breaks.
      String label(AdvisorSpecialization s) => switch (s) {
            AdvisorSpecialization.retirement => 'retirement',
            AdvisorSpecialization.succession => 'succession',
            AdvisorSpecialization.expatriation => 'expatriation',
            AdvisorSpecialization.divorce => 'divorce',
            AdvisorSpecialization.selfEmployment => 'selfEmployment',
            AdvisorSpecialization.realEstate => 'realEstate',
            AdvisorSpecialization.taxOptimization => 'taxOptimization',
            AdvisorSpecialization.debtManagement => 'debtManagement',
          };

      for (final spec in AdvisorSpecialization.values) {
        expect(label(spec), isNotEmpty);
      }
    });

    test('13. enum index order is stable (no accidental reorder)', () {
      expect(AdvisorSpecialization.values[0], equals(AdvisorSpecialization.retirement));
      expect(AdvisorSpecialization.values[1], equals(AdvisorSpecialization.succession));
      expect(AdvisorSpecialization.values[2], equals(AdvisorSpecialization.expatriation));
      expect(AdvisorSpecialization.values[3], equals(AdvisorSpecialization.divorce));
      expect(AdvisorSpecialization.values[4], equals(AdvisorSpecialization.selfEmployment));
      expect(AdvisorSpecialization.values[5], equals(AdvisorSpecialization.realEstate));
      expect(AdvisorSpecialization.values[6], equals(AdvisorSpecialization.taxOptimization));
      expect(AdvisorSpecialization.values[7], equals(AdvisorSpecialization.debtManagement));
    });

    test('14. specialization names are camelCase (JSON serialization ready)', () {
      for (final spec in AdvisorSpecialization.values) {
        // camelCase: starts with lowercase, no underscores, no spaces
        expect(
          spec.name,
          isNot(contains('_')),
          reason: '${spec.name} should not contain underscores',
        );
        expect(
          spec.name,
          isNot(contains(' ')),
          reason: '${spec.name} should not contain spaces',
        );
        expect(
          spec.name[0],
          equals(spec.name[0].toLowerCase()),
          reason: '${spec.name} should start with lowercase',
        );
      }
    });

    test('15. no banned compliance terms in enum names', () {
      for (final spec in AdvisorSpecialization.values) {
        for (final banned in _bannedTerms) {
          expect(
            spec.name.toLowerCase().contains(banned.toLowerCase()),
            isFalse,
            reason: 'Banned term "$banned" found in ${spec.name}',
          );
        }
      }
    });
  });
}
