/// Month/day-aware age calculator.
///
/// A year-only delta lets a 17-year-old register on the day before their
/// 18th birthday (P3-A03 finding). The picker also caps firstDate /
/// lastDate so this is the second line of defence — both must remain in
/// sync.
int yearsBetween(DateTime from, DateTime to) {
  var years = to.year - from.year;
  if (to.month < from.month ||
      (to.month == from.month && to.day < from.day)) {
    years -= 1;
  }
  return years;
}
