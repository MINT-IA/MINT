/// Deterministic civil-time rules for Switzerland (Europe/Zurich).
///
/// Financial contracts use Swiss civil dates even when the device or the
/// persisted instant uses another timezone. Switzerland follows the European
/// DST rule: the offset is UTC+1 in winter and UTC+2 from the last Sunday in
/// March at 01:00 UTC until the last Sunday in October at 01:00 UTC.
class SwissCivilTime {
  const SwissCivilTime._();

  static final RegExp _canonicalCivilDatePattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})$',
  );

  /// Earliest birth date admitted by the existing MINT adult collector.
  static final DateTime earliestSupportedBirthDate = DateTime.utc(1900, 1, 1);

  /// Returns Zurich wall-clock components represented in a UTC [DateTime].
  ///
  /// The returned object is a civil value, not an instant. Its UTC flag keeps
  /// host-local timezone settings from changing comparisons of its components.
  static DateTime civilDateTime(DateTime instant) {
    final utc = instant.toUtc();
    final offsetHours = _isZurichSummerTime(utc) ? 2 : 1;
    final shifted = utc.add(Duration(hours: offsetHours));
    return DateTime.utc(
      shifted.year,
      shifted.month,
      shifted.day,
      shifted.hour,
      shifted.minute,
      shifted.second,
      shifted.millisecond,
      shifted.microsecond,
    );
  }

  static DateTime civilDate(DateTime instant) {
    final civil = civilDateTime(instant);
    return DateTime.utc(civil.year, civil.month, civil.day);
  }

  /// Preserves explicit business-date components independently of host zone.
  static DateTime businessDate(DateTime value) =>
      DateTime.utc(value.year, value.month, value.day);

  /// Parses exactly `YYYY-MM-DD` without accepting DateTime normalization.
  static DateTime? parseCanonicalCivilDate(String value) {
    final match = _canonicalCivilDatePattern.firstMatch(value);
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day) {
      return null;
    }
    return parsed;
  }

  /// Applies the existing MINT collector bounds: 1900 and 18 years old.
  static bool isSupportedAdultBirthDate(
    DateTime dateOfBirth, {
    required DateTime now,
  }) {
    final birthDate = businessDate(dateOfBirth);
    final today = civilDate(now);
    final adultCutoff = _addCalendarYears(today, -18);
    return !birthDate.isBefore(earliestSupportedBirthDate) &&
        !birthDate.isAfter(adultCutoff);
  }

  /// A source date is a business date, never an instant.
  static bool isFutureCivilDate(DateTime sourceDate, {required DateTime now}) =>
      businessDate(sourceDate).isAfter(civilDate(now));

  /// Resolves Zurich civil midnight to its exact UTC instant.
  static DateTime startOfCivilDate(DateTime civilDate) => utcInstant(
        year: civilDate.year,
        month: civilDate.month,
        day: civilDate.day,
      );

  static DateTime utcInstant({
    required int year,
    required int month,
    required int day,
    int hour = 0,
    int minute = 0,
    int second = 0,
    int millisecond = 0,
    int microsecond = 0,
  }) {
    for (final offsetHours in const <int>[2, 1]) {
      final candidate = DateTime.utc(
        year,
        month,
        day,
        hour - offsetHours,
        minute,
        second,
        millisecond,
        microsecond,
      );
      final civil = civilDateTime(candidate);
      if (civil.year == year &&
          civil.month == month &&
          civil.day == day &&
          civil.hour == hour &&
          civil.minute == minute &&
          civil.second == second &&
          civil.millisecond == millisecond &&
          civil.microsecond == microsecond) {
        return candidate;
      }
    }
    throw ArgumentError('non-existent Europe/Zurich civil time');
  }

  static bool _isZurichSummerTime(DateTime utc) {
    final year = utc.year;
    final startsAt = DateTime.utc(
      year,
      3,
      _lastSundayOfMonth(year, 3),
      1,
    );
    final endsAt = DateTime.utc(
      year,
      10,
      _lastSundayOfMonth(year, 10),
      1,
    );
    return !utc.isBefore(startsAt) && utc.isBefore(endsAt);
  }

  static int _lastSundayOfMonth(int year, int month) {
    final lastDay = DateTime.utc(year, month + 1, 0);
    return lastDay.day - lastDay.weekday % DateTime.daysPerWeek;
  }

  static DateTime _addCalendarYears(DateTime value, int years) {
    final year = value.year + years;
    final maxDay = DateTime.utc(year, value.month + 1, 0).day;
    return DateTime.utc(year, value.month, value.day.clamp(1, maxDay));
  }
}
