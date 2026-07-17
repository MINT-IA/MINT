import 'package:mint_mobile/constants/social_insurance.dart';

/// AVS21 reference age in months by gender and birth year.
///
/// Official cohort schedule: OFAS, « AVS 21 », harmonisation progressive de
/// l'âge de référence. LAVS art. 21 defines the common reference-age rule but
/// does not, by itself, encode the 1961–1963 transitional month schedule.
///
/// Women born 1961-1963 have transitional reference ages:
/// - Born 1960 or earlier: 64 (pre-AVS21)
/// - Born 1961: 64 years 3 months
/// - Born 1962: 64 years 6 months
/// - Born 1963: 64 years 9 months
/// - Born 1964+: 65 (full AVS21 alignment)
/// Men: 65 (unchanged).
int avsReferenceAgeMonths({required int birthYear, required bool isFemale}) {
  if (!isFemale) return avsAgeReferenceHomme * 12;
  if (birthYear <= 1960) return 64 * 12;
  if (birthYear == 1961) return 64 * 12 + 3;
  if (birthYear == 1962) return 64 * 12 + 6;
  if (birthYear == 1963) return 64 * 12 + 9;
  return avsAgeReferenceFemme * 12;
}

/// AVS21 reference age as a fractional year.
double avsReferenceAgeYears({required int birthYear, required bool isFemale}) {
  return avsReferenceAgeMonths(birthYear: birthYear, isFemale: isFemale) / 12;
}

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

    final totalReferenceMonths = avsReferenceAgeMonths(
      birthYear: year,
      isFemale: normalizedGender == 'F',
    );

    final birthDate = dateOfBirth?.isUtc == true
        ? DateTime.utc(year, month, day)
        : DateTime(year, month, day);
    return _addCalendarMonths(birthDate, totalReferenceMonths);
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
}

DateTime _addCalendarMonths(DateTime value, int months) {
  final total = value.year * 12 + value.month - 1 + months;
  final year = total ~/ 12;
  final month = total % 12 + 1;
  final maxDay = DateTime(year, month + 1, 0).day;
  final day = value.day.clamp(1, maxDay);
  return value.isUtc
      ? DateTime.utc(year, month, day)
      : DateTime(year, month, day);
}
