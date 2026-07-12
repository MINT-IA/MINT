import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('one canonical snapshot causes exactly one recompute', () async {
    SharedPreferences.setMockInitialValues({});
    final provider = MintStateProvider();
    var notifications = 0;
    provider.addListener(() => notifications++);

    final t0 = DateTime.utc(2026, 7, 12, 12);
    final initial = CoachProfile.fromWizardAnswers(const {
      'q_birth_year': 1985,
      'q_canton': 'VD',
      'q_gross_salary_annual': 96000,
    }).copyWith(createdAt: t0, updatedAt: t0);

    await provider.recompute(initial);
    expect(notifications, 1);

    // Negative control: the proxy may offer the same snapshot again.
    await provider.recompute(initial);
    expect(notifications, 1);

    final salaryMutation = initial.copyWith(
      salaireBrutMensuel: 9000,
      updatedAt: t0.add(const Duration(minutes: 1)),
    );
    await provider.recompute(salaryMutation);
    expect(notifications, 2);
    await provider.recompute(salaryMutation);
    expect(notifications, 2);

    final provenanceMutation = salaryMutation.copyWith(
      dataSources: const {
        'salaireBrutMensuel': ProfileDataSource.certificate,
      },
      updatedAt: t0.add(const Duration(minutes: 2)),
    );
    await provider.recompute(provenanceMutation);
    expect(notifications, 3);
    await provider.recompute(provenanceMutation);
    expect(notifications, 3);
  });
}
