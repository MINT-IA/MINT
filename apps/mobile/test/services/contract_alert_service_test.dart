import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/contract_alert_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ContractDeadline', () {
    test('shouldAlert returns true when within alert window', () {
      final deadline = ContractDeadline(
        label: 'Fin de bail',
        deadline: DateTime(2026, 6, 1),
        documentType: 'lease_contract',
        alertDaysBefore: 90,
      );
      // 60 days before → within 90-day window
      expect(deadline.shouldAlert(DateTime(2026, 4, 2)), isTrue);
    });

    test('shouldAlert returns false when too early', () {
      final deadline = ContractDeadline(
        label: 'Fin de bail',
        deadline: DateTime(2026, 12, 31),
        documentType: 'lease_contract',
        alertDaysBefore: 90,
      );
      // 200+ days before → too early
      expect(deadline.shouldAlert(DateTime(2026, 3, 28)), isFalse);
    });

    test('shouldAlert returns false when dismissed', () {
      final deadline = ContractDeadline(
        label: 'Assurance ménage',
        deadline: DateTime(2026, 5, 1),
        documentType: 'insurance_contract',
        alertDaysBefore: 30,
        dismissed: true,
      );
      expect(deadline.shouldAlert(DateTime(2026, 4, 15)), isFalse);
    });

    test('shouldAlert returns false after deadline passed', () {
      final deadline = ContractDeadline(
        label: 'LPP cert',
        deadline: DateTime(2026, 1, 1),
        documentType: 'lpp_certificate',
      );
      expect(deadline.shouldAlert(DateTime(2026, 3, 28)), isFalse);
    });

    test('daysRemaining is positive for future deadlines', () {
      final now = DateTime(2026, 3, 28);
      final deadline = ContractDeadline(
        label: 'Test',
        deadline: now.add(const Duration(days: 15)),
        documentType: 'lease_contract',
      );
      expect(deadline.daysRemaining(now), 15);
    });
  });

  group('ContractAlertService', () {
    test('addDeadline and loadAll round-trips', () async {
      await ContractAlertService.addDeadline(ContractDeadline(
        label: 'Bail Rue des Alpes',
        deadline: DateTime(2026, 9, 30),
        documentType: 'lease_contract',
        alertDaysBefore: 90,
      ));

      final all = await ContractAlertService.loadAll();
      expect(all.length, 1);
      expect(all.first.label, 'Bail Rue des Alpes');
      expect(all.first.deadline.month, 9);
    });

    test('addDeadline deduplicates by label + date', () async {
      await ContractAlertService.addDeadline(ContractDeadline(
        label: 'Assurance RC',
        deadline: DateTime(2026, 6, 1),
        documentType: 'insurance_contract',
      ));
      await ContractAlertService.addDeadline(ContractDeadline(
        label: 'Assurance RC',
        deadline: DateTime(2026, 6, 15), // Different day in same month
        documentType: 'insurance_contract',
      ));

      final all = await ContractAlertService.loadAll();
      expect(all.length, 1); // Deduplicated (same label + same month)
      expect(all.first.deadline.day, 15); // Kept the newer one
    });

    test('getActiveAlerts returns only alertable deadlines', () async {
      await ContractAlertService.addDeadline(ContractDeadline(
        label: 'Soon',
        deadline: DateTime(2026, 4, 15),
        documentType: 'lease_contract',
        alertDaysBefore: 30,
      ));
      await ContractAlertService.addDeadline(ContractDeadline(
        label: 'Far away',
        deadline: DateTime(2027, 1, 1),
        documentType: 'insurance_contract',
        alertDaysBefore: 30,
      ));

      final alerts = await ContractAlertService.getActiveAlerts(
        DateTime(2026, 3, 28),
      );
      expect(alerts.length, 1);
      expect(alerts.first.label, 'Soon');
    });

    test('dismiss marks alert as dismissed', () async {
      await ContractAlertService.addDeadline(ContractDeadline(
        label: 'Bail Genève',
        deadline: DateTime(2026, 5, 1),
        documentType: 'lease_contract',
        alertDaysBefore: 60,
      ));

      await ContractAlertService.dismiss('Bail Genève');

      final alerts = await ContractAlertService.getActiveAlerts(
        DateTime(2026, 3, 28),
      );
      expect(alerts, isEmpty);
    });

    test('cleanup removes expired deadlines', () async {
      await ContractAlertService.addDeadline(ContractDeadline(
        label: 'Old',
        deadline: DateTime(2025, 1, 1),
        documentType: 'lease_contract',
      ));
      await ContractAlertService.addDeadline(ContractDeadline(
        label: 'Current',
        deadline: DateTime(2026, 12, 31),
        documentType: 'insurance_contract',
      ));

      await ContractAlertService.cleanup(DateTime(2026, 3, 28));

      final all = await ContractAlertService.loadAll();
      expect(all.length, 1);
      expect(all.first.label, 'Current');
    });
  });
}
