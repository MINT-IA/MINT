import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/first_job_service.dart';

void main() {
  test('legacy film calculator is replaced by the canonical salary model', () {
    final result = FirstJobService.analyzeSalary(
      salaireBrutMensuel: 5000,
      age: 25,
      canton: 'VD',
    );

    expect(result.brut, 5000);
    expect(result.lppEmploye, isNull);
    expect(result.netEstime, isNull);
  });
}
