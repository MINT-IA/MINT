// ────────────────────────────────────────────────────────────
//  SCREEN COMPLETION TRACKER TESTS — S52 / ReturnContract V2
//
//  14 tests covering:
//    - markCompleted persists with correct outcome
//    - markAbandoned persists with correct outcome
//    - markChangedInputs persists with correct outcome
//    - lastOutcome returns null when no record
//    - lastEntry returns full JSON structure
//    - clear removes the record
//    - clear is idempotent (clear twice is safe)
//    - multiple screens tracked independently
//    - overwrite: second call wins
//    - timestamp is stored and parseable
//    - screenId is stored in entry
//    - outcome round-trip for all three values
//    - malformed prefs value returns null
// ────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mint_mobile/services/screen_completion_tracker.dart';
import 'package:mint_mobile/models/screen_return.dart';

void main() {
  // Use shared_preferences in-memory backend for all tests.
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('ScreenCompletionTracker — markCompleted', () {
    test('persists completed outcome for given screenId', () async {
      final prefs = await SharedPreferences.getInstance();
      await ScreenCompletionTracker.markCompleted('sim_3a', prefs: prefs);
      final outcome = await ScreenCompletionTracker.lastOutcome('sim_3a', prefs: prefs);
      expect(outcome, ScreenOutcome.completed);
    });

    test('stores the screenId field in the entry', () async {
      final prefs = await SharedPreferences.getInstance();
      await ScreenCompletionTracker.markCompleted('rente_vs_capital', prefs: prefs);
      final entry = await ScreenCompletionTracker.lastEntry('rente_vs_capital', prefs: prefs);
      expect(entry, isNotNull);
      expect(entry!['screenId'], 'rente_vs_capital');
    });
  });

  group('ScreenCompletionTracker — markAbandoned', () {
    test('persists abandoned outcome', () async {
      final prefs = await SharedPreferences.getInstance();
      await ScreenCompletionTracker.markAbandoned('budget', prefs: prefs);
      final outcome = await ScreenCompletionTracker.lastOutcome('budget', prefs: prefs);
      expect(outcome, ScreenOutcome.abandoned);
    });
  });

  group('ScreenCompletionTracker — markChangedInputs', () {
    test('persists changedInputs outcome', () async {
      final prefs = await SharedPreferences.getInstance();
      await ScreenCompletionTracker.markChangedInputs('fiscal_comparator', prefs: prefs);
      final outcome = await ScreenCompletionTracker.lastOutcome('fiscal_comparator', prefs: prefs);
      expect(outcome, ScreenOutcome.changedInputs);
    });
  });

  group('ScreenCompletionTracker — lastOutcome', () {
    test('returns null when no record exists', () async {
      final prefs = await SharedPreferences.getInstance();
      final outcome = await ScreenCompletionTracker.lastOutcome('nonexistent_screen', prefs: prefs);
      expect(outcome, isNull);
    });

    test('returns null after clear', () async {
      final prefs = await SharedPreferences.getInstance();
      await ScreenCompletionTracker.markCompleted('affordability', prefs: prefs);
      await ScreenCompletionTracker.clear('affordability', prefs: prefs);
      final outcome = await ScreenCompletionTracker.lastOutcome('affordability', prefs: prefs);
      expect(outcome, isNull);
    });
  });

  group('ScreenCompletionTracker — lastEntry', () {
    test('returns null when no record exists', () async {
      final prefs = await SharedPreferences.getInstance();
      final entry = await ScreenCompletionTracker.lastEntry('missing', prefs: prefs);
      expect(entry, isNull);
    });

    test('timestamp is stored and parseable as ISO-8601', () async {
      final prefs = await SharedPreferences.getInstance();
      await ScreenCompletionTracker.markCompleted('divorce_simulator', prefs: prefs);
      final entry = await ScreenCompletionTracker.lastEntry('divorce_simulator', prefs: prefs);
      expect(entry, isNotNull);
      final ts = entry!['timestamp'] as String?;
      expect(ts, isNotNull);
      expect(() => DateTime.parse(ts!), returnsNormally);
    });

    test('outcome field matches string representation', () async {
      final prefs = await SharedPreferences.getInstance();
      await ScreenCompletionTracker.markAbandoned('job_comparison', prefs: prefs);
      final entry = await ScreenCompletionTracker.lastEntry('job_comparison', prefs: prefs);
      expect(entry!['outcome'], 'abandoned');
    });
  });

  group('ScreenCompletionTracker — clear', () {
    test('removes the stored record', () async {
      final prefs = await SharedPreferences.getInstance();
      await ScreenCompletionTracker.markCompleted('lamal_franchise', prefs: prefs);
      await ScreenCompletionTracker.clear('lamal_franchise', prefs: prefs);
      final raw = prefs.getString('screen_return_lamal_franchise');
      expect(raw, isNull);
    });

    test('is idempotent — clearing a missing key does not throw', () async {
      final prefs = await SharedPreferences.getInstance();
      await expectLater(
        ScreenCompletionTracker.clear('never_existed', prefs: prefs),
        completes,
      );
    });
  });

  group('ScreenCompletionTracker — multiple screens', () {
    test('tracks multiple screens independently', () async {
      final prefs = await SharedPreferences.getInstance();
      await ScreenCompletionTracker.markCompleted('screen_a', prefs: prefs);
      await ScreenCompletionTracker.markAbandoned('screen_b', prefs: prefs);
      await ScreenCompletionTracker.markChangedInputs('screen_c', prefs: prefs);

      expect(
        await ScreenCompletionTracker.lastOutcome('screen_a', prefs: prefs),
        ScreenOutcome.completed,
      );
      expect(
        await ScreenCompletionTracker.lastOutcome('screen_b', prefs: prefs),
        ScreenOutcome.abandoned,
      );
      expect(
        await ScreenCompletionTracker.lastOutcome('screen_c', prefs: prefs),
        ScreenOutcome.changedInputs,
      );
    });

    test('clearing one screen does not affect others', () async {
      final prefs = await SharedPreferences.getInstance();
      await ScreenCompletionTracker.markCompleted('x', prefs: prefs);
      await ScreenCompletionTracker.markCompleted('y', prefs: prefs);
      await ScreenCompletionTracker.clear('x', prefs: prefs);

      expect(await ScreenCompletionTracker.lastOutcome('x', prefs: prefs), isNull);
      expect(
        await ScreenCompletionTracker.lastOutcome('y', prefs: prefs),
        ScreenOutcome.completed,
      );
    });
  });

  group('ScreenCompletionTracker — overwrite', () {
    test('second write overwrites the first', () async {
      final prefs = await SharedPreferences.getInstance();
      await ScreenCompletionTracker.markAbandoned('rachat_echelonne', prefs: prefs);
      await ScreenCompletionTracker.markCompleted('rachat_echelonne', prefs: prefs);
      final outcome = await ScreenCompletionTracker.lastOutcome('rachat_echelonne', prefs: prefs);
      expect(outcome, ScreenOutcome.completed);
    });
  });

  group('ScreenCompletionTracker — malformed storage', () {
    test('lastOutcome returns null for malformed JSON', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('screen_return_bad_screen', '{invalid json}');
      final outcome = await ScreenCompletionTracker.lastOutcome('bad_screen', prefs: prefs);
      expect(outcome, isNull);
    });

    test('lastOutcome returns null for unknown outcome string', () async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        'screen_return_unknown_outcome',
        jsonEncode({
          'outcome': 'totally_unknown',
          'timestamp': DateTime.now().toIso8601String(),
          'screenId': 'unknown_outcome',
        }),
      );
      final outcome = await ScreenCompletionTracker.lastOutcome('unknown_outcome', prefs: prefs);
      expect(outcome, isNull);
    });
  });
}
