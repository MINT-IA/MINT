import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

final _fixedInstant = DateTime.utc(2026, 7, 17, 20);

CoachProfile _profile({bool legacyDataNeedsReview = false}) =>
    CoachProfile.defaults().copyWith(
      fiscal: FiscalProfile(
        legacyDataNeedsReview: legacyDataNeedsReview,
      ),
      createdAt: _fixedInstant,
      updatedAt: _fixedInstant,
    );

void main() {
  test('unchanged copyWith remains equal with the same hash', () {
    final profile = _profile();
    final unchanged = profile.copyWith();

    expect(unchanged, profile);
    expect(unchanged.hashCode, profile.hashCode);
  });

  test('a real fiscal-only change participates in CoachProfile equality', () {
    final baseline = _profile();
    final needsReview = _profile(legacyDataNeedsReview: true);

    expect(needsReview.updatedAt, baseline.updatedAt);
    expect(needsReview.fiscal, isNot(baseline.fiscal));
    expect(needsReview, isNot(baseline));
  });

  test('a real fiscal-only change participates in CoachProfile hashCode', () {
    final baseline = _profile();
    final needsReview = _profile(legacyDataNeedsReview: true);

    expect(needsReview.updatedAt, baseline.updatedAt);
    expect(needsReview.fiscal.hashCode, isNot(baseline.fiscal.hashCode));
    expect(needsReview.hashCode, isNot(baseline.hashCode));
  });
}
