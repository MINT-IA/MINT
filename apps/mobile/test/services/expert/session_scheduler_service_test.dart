/// SessionSchedulerService — S65 Expert Tier.
///
/// 13 tests covering:
///  1.  requestSession creates a SessionRequest with status "requested"
///  2.  requestSession persists to SharedPreferences
///  3.  history returns newest-first ordering
///  4.  history returns empty list when nothing stored
///  5.  history returns empty list on corrupt JSON
///  6.  updateStatus changes status of matching request
///  7.  updateStatus is no-op for unknown id
///  8.  cancelRequest sets status to "cancelled"
///  9.  clearHistory removes all requests
///  10. historyByStatus filters correctly
///  11. SessionRequest.fromJson round-trips through toJson
///  12. SessionRequest.id never contains PII
///  13. Multiple requests for same specialization are all stored
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/expert/advisor_specialization.dart';
import 'package:mint_mobile/services/expert/session_scheduler_service.dart';

// ══════════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════════

Future<SharedPreferences> _freshPrefs() async {
  SharedPreferences.setMockInitialValues({});
  return SharedPreferences.getInstance();
}

final _testDate = DateTime(2026, 3, 18, 10, 30);

// ══════════════════════════════════════════════════════════════
//  TESTS
// ══════════════════════════════════════════════════════════════

void main() {
  group('SessionSchedulerService', () {
    test('1. requestSession returns a SessionRequest with status requested',
        () async {
      final prefs = await _freshPrefs();
      final req = await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.retirement,
        prefs: prefs,
        now: _testDate,
      );

      expect(req.status, equals(SessionStatus.requested));
      expect(req.specialization, equals(AdvisorSpecialization.retirement));
      expect(req.requestedAt, equals(_testDate));
      expect(req.id, isNotEmpty);
    });

    test('2. requestSession persists to SharedPreferences', () async {
      final prefs = await _freshPrefs();
      await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.succession,
        prefs: prefs,
        now: _testDate,
      );

      final history = await SessionSchedulerService.history(prefs);
      expect(history.length, equals(1));
      expect(history.first.specialization, equals(AdvisorSpecialization.succession));
    });

    test('3. history returns newest-first ordering', () async {
      final prefs = await _freshPrefs();
      final t1 = DateTime(2026, 3, 10);
      final t2 = DateTime(2026, 3, 15);
      final t3 = DateTime(2026, 3, 18);

      await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.divorce,
        prefs: prefs,
        now: t1,
      );
      await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.succession,
        prefs: prefs,
        now: t2,
      );
      await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.retirement,
        prefs: prefs,
        now: t3,
      );

      final history = await SessionSchedulerService.history(prefs);
      expect(history.length, equals(3));
      expect(history[0].requestedAt, equals(t3));
      expect(history[1].requestedAt, equals(t2));
      expect(history[2].requestedAt, equals(t1));
    });

    test('4. history returns empty list when nothing stored', () async {
      final prefs = await _freshPrefs();
      final history = await SessionSchedulerService.history(prefs);
      expect(history, isEmpty);
    });

    test('5. history returns empty list on corrupt JSON', () async {
      SharedPreferences.setMockInitialValues({
        'expert_session_requests': 'not_valid_json{{{{',
      });
      final prefs = await SharedPreferences.getInstance();
      final history = await SessionSchedulerService.history(prefs);
      expect(history, isEmpty);
    });

    test('6. updateStatus changes status of matching request', () async {
      final prefs = await _freshPrefs();
      final req = await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.taxOptimization,
        prefs: prefs,
        now: _testDate,
      );

      await SessionSchedulerService.updateStatus(
        id: req.id,
        status: SessionStatus.scheduled,
        prefs: prefs,
      );

      final history = await SessionSchedulerService.history(prefs);
      expect(history.first.status, equals(SessionStatus.scheduled));
    });

    test('7. updateStatus is no-op for unknown id', () async {
      final prefs = await _freshPrefs();
      await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.retirement,
        prefs: prefs,
        now: _testDate,
      );

      await SessionSchedulerService.updateStatus(
        id: 'nonexistent_id',
        status: SessionStatus.completed,
        prefs: prefs,
      );

      final history = await SessionSchedulerService.history(prefs);
      // The original request must remain unchanged.
      expect(history.first.status, equals(SessionStatus.requested));
    });

    test('8. cancelRequest sets status to cancelled', () async {
      final prefs = await _freshPrefs();
      final req = await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.debtManagement,
        prefs: prefs,
        now: _testDate,
      );

      await SessionSchedulerService.cancelRequest(id: req.id, prefs: prefs);

      final history = await SessionSchedulerService.history(prefs);
      expect(history.first.status, equals(SessionStatus.cancelled));
    });

    test('9. clearHistory removes all requests', () async {
      final prefs = await _freshPrefs();
      await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.divorce,
        prefs: prefs,
        now: _testDate,
      );
      await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.realEstate,
        prefs: prefs,
        now: _testDate,
      );

      await SessionSchedulerService.clearHistory(prefs);

      final history = await SessionSchedulerService.history(prefs);
      expect(history, isEmpty);
    });

    test('10. historyByStatus filters correctly', () async {
      final prefs = await _freshPrefs();
      final req1 = await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.retirement,
        prefs: prefs,
        now: DateTime(2026, 3, 1),
      );
      final req2 = await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.succession,
        prefs: prefs,
        now: DateTime(2026, 3, 5),
      );

      // Schedule req1.
      await SessionSchedulerService.updateStatus(
        id: req1.id,
        status: SessionStatus.scheduled,
        prefs: prefs,
      );

      final scheduled = await SessionSchedulerService.historyByStatus(
        status: SessionStatus.scheduled,
        prefs: prefs,
      );
      final requested = await SessionSchedulerService.historyByStatus(
        status: SessionStatus.requested,
        prefs: prefs,
      );

      expect(scheduled.length, equals(1));
      expect(scheduled.first.id, equals(req1.id));
      expect(requested.length, equals(1));
      expect(requested.first.id, equals(req2.id));
    });

    test('11. SessionRequest.fromJson round-trips through toJson', () {
      final original = SessionRequest(
        id: 'retirement_1710756600000',
        specialization: AdvisorSpecialization.selfEmployment,
        requestedAt: DateTime(2026, 3, 18, 9, 0),
        status: SessionStatus.completed,
      );

      final json = original.toJson();
      final reconstructed = SessionRequest.fromJson(json);

      expect(reconstructed.id, equals(original.id));
      expect(reconstructed.specialization, equals(original.specialization));
      expect(reconstructed.requestedAt.toIso8601String(),
          equals(original.requestedAt.toIso8601String()));
      expect(reconstructed.status, equals(original.status));
    });

    test('12. Session request ID never contains PII patterns', () async {
      final prefs = await _freshPrefs();
      for (final spec in AdvisorSpecialization.values) {
        final req = await SessionSchedulerService.requestSession(
          specialization: spec,
          prefs: prefs,
          now: _testDate,
        );
        // ID must not match IBAN, SSN or contain digits that could be salary
        expect(
          RegExp(r'CH\d{2}').hasMatch(req.id),
          isFalse,
          reason: 'ID for $spec must not look like an IBAN',
        );
        expect(
          RegExp(r'\d{3}\.\d{4}').hasMatch(req.id),
          isFalse,
          reason: 'ID for $spec must not look like an SSN',
        );
        // ID must use specialization name (predictable, not personal data)
        expect(req.id, contains(spec.name));
      }
    });

    test('13. multiple requests for same specialization are all stored', () async {
      final prefs = await _freshPrefs();
      await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.retirement,
        prefs: prefs,
        now: DateTime(2026, 3, 1),
      );
      await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.retirement,
        prefs: prefs,
        now: DateTime(2026, 3, 8),
      );
      await SessionSchedulerService.requestSession(
        specialization: AdvisorSpecialization.retirement,
        prefs: prefs,
        now: DateTime(2026, 3, 15),
      );

      final history = await SessionSchedulerService.history(prefs);
      final retirementRequests = history
          .where((r) => r.specialization == AdvisorSpecialization.retirement)
          .toList();

      expect(retirementRequests.length, equals(3));
    });
  });
}
