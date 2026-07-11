import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/avs_reference_age.dart';

void main() {
  group('AvsReferenceAge', () {
    test('applies AVS21 transition for women born in 1961', () {
      final birthDate = DateTime(1961);

      expect(
        AvsReferenceAge.referenceDate(
          dateOfBirth: birthDate,
          birthYear: 1961,
          gender: 'F',
        ),
        DateTime(2025, 4),
      );
      expect(
        AvsReferenceAge.hasReachedReferenceAge(
          dateOfBirth: birthDate,
          birthYear: 1961,
          gender: 'F',
          today: DateTime(2025, 3, 31),
        ),
        isFalse,
      );
      expect(
        AvsReferenceAge.hasReachedReferenceAge(
          dateOfBirth: birthDate,
          birthYear: 1961,
          gender: 'F',
          today: DateTime(2025, 4),
        ),
        isTrue,
      );
    });

    test('detects the four-year LACI window before AVS reference age', () {
      final birthDate = DateTime(1962);

      expect(
        AvsReferenceAge.referenceDate(
          dateOfBirth: birthDate,
          birthYear: 1962,
          gender: 'F',
        ),
        DateTime(2026, 7),
      );
      expect(
        AvsReferenceAge.isWithinFourYearsBeforeReferenceAge(
          dateOfBirth: birthDate,
          birthYear: 1962,
          gender: 'F',
          today: DateTime(2022, 6, 30),
        ),
        isFalse,
      );
      expect(
        AvsReferenceAge.isWithinFourYearsBeforeReferenceAge(
          dateOfBirth: birthDate,
          birthYear: 1962,
          gender: 'F',
          today: DateTime(2022, 7),
        ),
        isTrue,
      );
    });

    test('uses age 65 fallback when gender is unknown', () {
      expect(
        AvsReferenceAge.referenceDate(
          dateOfBirth: DateTime(1962),
          birthYear: 1962,
          gender: null,
        ),
        DateTime(2027),
      );
    });
  });
}
