import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/anticipation_provider.dart';
import 'package:mint_mobile/services/biography/biography_fact.dart';

// ────────────────────────────────────────────────────────────
//  ANTICIPATION PROVIDER TESTS — Phase 04 Plan 03
// ────────────────────────────────────────────────────────────
//
// Tests AnticipationProvider: session evaluation, dismiss,
// snooze, session caching, and reset.
//
// Uses SharedPreferences.setMockInitialValues({}) for hermetic tests.
// ────────────────────────────────────────────────────────────

/// Default goal for test profiles.
final _defaultGoal = GoalA(
  type: GoalAType.retraite,
  targetDate: DateTime(2042, 1, 1),
  label: 'Test goal',
);

/// Helper to build a minimal CoachProfile for testing.
CoachProfile _profile({
  int birthYear = 1990,
  String canton = 'VD',
  double? avoirLppTotal,
  double? rachatMaximum,
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    employmentStatus: 'salarie',
    salaireBrutMensuel: 8000,
    goalA: _defaultGoal,
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLppTotal,
      rachatMaximum: rachatMaximum,
    ),
    createdAt: DateTime(2024, 1, 1),
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════
  // Evaluate on session start
  // ═══════════════════════════════════════════════════════════

  group('evaluateOnSessionStart', () {
    test('populates visibleSignals when triggers fire', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AnticipationProvider();

      // December 15 -> 3a deadline fires
      await provider.evaluateOnSessionStart(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 12, 15),
        prefsOverride: prefs,
      );

      expect(provider.hasSignals, isTrue);
      expect(provider.visibleSignals, isNotEmpty);
      expect(provider.evaluated, isTrue);
    });

    test('returns empty when no triggers fire', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AnticipationProvider();

      // July 15 -> no triggers fire (not Dec, not near cantonal deadline, etc.)
      await provider.evaluateOnSessionStart(
        profile: _profile(canton: ''),
        facts: [],
        now: DateTime(2026, 7, 15),
        prefsOverride: prefs,
      );

      expect(provider.hasSignals, isFalse);
      expect(provider.visibleSignals, isEmpty);
      expect(provider.evaluated, isTrue);
    });

    test('populates multiple signals when multiple triggers fire', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AnticipationProvider();

      // December 15 with LPP data -> 3a deadline + LPP rachat fire
      await provider.evaluateOnSessionStart(
        profile: _profile(avoirLppTotal: 50000, rachatMaximum: 100000),
        facts: [],
        now: DateTime(2026, 12, 15),
        prefsOverride: prefs,
      );

      // At least 2 signals should fire (3a deadline + LPP rachat)
      final total = provider.visibleSignals.length +
          provider.overflowSignals.length;
      expect(total, greaterThanOrEqualTo(2));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Session caching (CTX-02)
  // ═══════════════════════════════════════════════════════════

  group('Session caching', () {
    test('double evaluation returns same result without re-evaluating',
        () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AnticipationProvider();
      final now = DateTime(2026, 12, 15);

      // First evaluation
      await provider.evaluateOnSessionStart(
        profile: _profile(),
        facts: [],
        now: now,
        prefsOverride: prefs,
      );

      final firstResult = List.of(provider.visibleSignals);
      expect(provider.evaluated, isTrue);

      // Second evaluation with different date (should be ignored)
      await provider.evaluateOnSessionStart(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 7, 1), // Different date, but should be cached
        prefsOverride: prefs,
      );

      // Same result (not re-evaluated)
      expect(provider.visibleSignals.length, equals(firstResult.length));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Dismiss
  // ═══════════════════════════════════════════════════════════

  group('dismissSignal', () {
    test('removes signal from visible list', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AnticipationProvider();

      await provider.evaluateOnSessionStart(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 12, 15),
        prefsOverride: prefs,
      );

      expect(provider.visibleSignals, isNotEmpty);
      final signal = provider.visibleSignals.first;

      await provider.dismissSignal(signal);

      expect(
        provider.visibleSignals.where((s) => s.id == signal.id),
        isEmpty,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Snooze
  // ═══════════════════════════════════════════════════════════

  group('snoozeSignal', () {
    test('removes signal from visible list', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AnticipationProvider();

      await provider.evaluateOnSessionStart(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 12, 15),
        prefsOverride: prefs,
      );

      expect(provider.visibleSignals, isNotEmpty);
      final signal = provider.visibleSignals.first;

      await provider.snoozeSignal(signal);

      expect(
        provider.visibleSignals.where((s) => s.id == signal.id),
        isEmpty,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  // Reset session
  // ═══════════════════════════════════════════════════════════

  group('resetSession', () {
    test('allows re-evaluation after reset', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final provider = AnticipationProvider();

      // First evaluation in December
      await provider.evaluateOnSessionStart(
        profile: _profile(),
        facts: [],
        now: DateTime(2026, 12, 15),
        prefsOverride: prefs,
      );

      expect(provider.evaluated, isTrue);
      expect(provider.hasSignals, isTrue);

      // Reset session
      provider.resetSession();
      expect(provider.evaluated, isFalse);

      // Re-evaluate in July (no triggers)
      await provider.evaluateOnSessionStart(
        profile: _profile(canton: ''),
        facts: [],
        now: DateTime(2026, 7, 15),
        prefsOverride: prefs,
      );

      expect(provider.evaluated, isTrue);
      // No signals in July with empty canton
      expect(provider.hasSignals, isFalse);
    });
  });
}
