class AvsReferenceAge {
  const AvsReferenceAge._();

  static DateTime? referenceDate({
    required DateTime? dateOfBirth,
    required int birthYear,
    required String? gender,
  }) {
    final normalizedGender = gender?.trim().toUpperCase();
    if (dateOfBirth == null && birthYear < 1900) return null;

    final year = dateOfBirth?.year ?? birthYear;
    final month = dateOfBirth?.month ?? 12;
    final day = dateOfBirth?.day ?? 31;

    final totalReferenceMonths = _referenceAgeMonths(
      birthYear: year,
      gender: normalizedGender,
    );
    if (totalReferenceMonths == null) return null;

    final years = totalReferenceMonths ~/ 12;
    final months = totalReferenceMonths % 12;
    return DateTime(year + years, month + months, day);
  }

  static bool? hasReachedReferenceAge({
    required DateTime? dateOfBirth,
    required int birthYear,
    required String? gender,
    DateTime? today,
  }) {
    final reference = referenceDate(
      dateOfBirth: dateOfBirth,
      birthYear: birthYear,
      gender: gender,
    );
    if (reference == null) return null;
    final now = today ?? DateTime.now();
    return !now.isBefore(reference);
  }

  static bool? isWithinFourYearsBeforeReferenceAge({
    required DateTime? dateOfBirth,
    required int birthYear,
    required String? gender,
    DateTime? today,
  }) {
    final reference = referenceDate(
      dateOfBirth: dateOfBirth,
      birthYear: birthYear,
      gender: gender,
    );
    if (reference == null) return null;
    final now = today ?? DateTime.now();
    if (!now.isBefore(reference)) return false;
    final fourYearsBefore = DateTime(
      reference.year - 4,
      reference.month,
      reference.day,
    );
    return !now.isBefore(fourYearsBefore);
  }

  static int? _referenceAgeMonths({
    required int birthYear,
    required String? gender,
  }) {
    if (gender == 'M') return 65 * 12;
    if (gender != 'F') return 65 * 12;

    if (birthYear <= 1960) return 64 * 12;
    if (birthYear == 1961) return 64 * 12 + 3;
    if (birthYear == 1962) return 64 * 12 + 6;
    if (birthYear == 1963) return 64 * 12 + 9;
    return 65 * 12;
  }
}
