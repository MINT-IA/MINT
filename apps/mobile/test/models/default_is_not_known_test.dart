import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  test('display estimates do not become known completion facts', () {
    final profile = CoachProfile.fromWizardAnswers(const {});

    expect(profile.canton, 'ZH');
    expect(profile.depenses.loyer, 1500);
    expect(profile.prevoyance.tauxConversion, isNotNull);
    expect(profile.userProvidedFields, isNot(contains('canton')));
    expect(profile.userProvidedFields, isNot(contains('monthlyExpenses')));
    expect(profile.userProvidedFields, isNot(contains('conversionRate')));
    expect(profile.dataTimestamps, isNot(contains('canton')));
    expect(profile.dataTimestamps, isNot(contains('depenses.loyer')));
    expect(
      profile.dataTimestamps,
      isNot(contains('prevoyance.tauxConversion')),
    );
  });

  test('only explicit values acquire known markers', () {
    final profile = CoachProfile.fromWizardAnswers(const {
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 2100,
      'q_lamal_premium_monthly_chf': 420,
      '_coach_taux_conversion': 0.057,
    });

    expect(profile.userProvidedFields, containsAll([
      'canton',
      'monthlyExpenses',
      'conversionRate',
    ]));
    expect(profile.dataTimestamps, contains('canton'));
    expect(profile.dataTimestamps, contains('depenses.loyer'));
    expect(profile.dataTimestamps, contains('prevoyance.tauxConversion'));
  });
}
