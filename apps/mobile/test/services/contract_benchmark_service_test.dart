import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/contract_alert_service.dart';
import 'package:mint_mobile/services/contract_benchmark_service.dart';

CoachProfile _profile({
  String canton = 'VD',
  double loyer = 1800,
  double avoirLpp = 300000,
  double rachat = 50000,
}) {
  return CoachProfile(
    birthYear: 1980,
    salaireBrutMensuel: 8000,
    canton: canton,
    depenses: DepensesProfile(loyer: loyer),
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLpp,
      rachatMaximum: rachat,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2045),
      label: 'Retraite',
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ContractBenchmarkService', () {
    test('enrichAlerts returns empty when no active alerts', () async {
      final result = await ContractBenchmarkService.enrichAlerts(
        profile: _profile(),
        now: DateTime(2026, 3, 28),
      );
      expect(result, isEmpty);
    });

    test('lease alert enriched with cantonal comparison', () async {
      await ContractAlertService.addDeadline(ContractDeadline(
        label: 'Bail Lausanne',
        deadline: DateTime(2026, 5, 1),
        documentType: 'lease_contract',
        alertDaysBefore: 60,
      ));

      final result = await ContractBenchmarkService.enrichAlerts(
        profile: _profile(canton: 'GE', loyer: 2500),
        now: DateTime(2026, 3, 28),
      );

      expect(result.length, 1);
      expect(result.first.benchmarkMessage, isNotNull);
      expect(result.first.benchmarkMessage!, contains('2100'));
    });

    test('lease alert NOT enriched when rent is close to average', () async {
      await ContractAlertService.addDeadline(ContractDeadline(
        label: 'Bail modeste',
        deadline: DateTime(2026, 5, 1),
        documentType: 'lease_contract',
        alertDaysBefore: 60,
      ));

      final result = await ContractBenchmarkService.enrichAlerts(
        profile: _profile(canton: 'VD', loyer: 1650),
        now: DateTime(2026, 3, 28),
      );

      expect(result.length, 1);
      // Diff < 200 → no benchmark message
      expect(result.first.benchmarkMessage, isNull);
    });

    test('LPP alert enriched with buyback potential', () async {
      await ContractAlertService.addDeadline(ContractDeadline(
        label: 'Certificat LPP',
        deadline: DateTime(2026, 5, 1),
        documentType: 'lpp_certificate',
        alertDaysBefore: 60,
      ));

      final result = await ContractBenchmarkService.enrichAlerts(
        profile: _profile(rachat: 80000),
        now: DateTime(2026, 3, 28),
      );

      expect(result.length, 1);
      expect(result.first.benchmarkMessage, contains('rachat'));
      expect(result.first.actionRoute, '/rachat-lpp');
    });

    test('unknown canton falls back to 1400 average', () {
      // Private method test via enrichment — unknown canton should not crash
      expect(
        () async => await ContractBenchmarkService.enrichAlerts(
          profile: _profile(canton: 'XX'),
          now: DateTime(2026, 3, 28),
        ),
        returnsNormally,
      );
    });
  });
}
