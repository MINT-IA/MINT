// test/providers/mint_state_provider_test.dart
//
// Unit tests for MintStateProvider.
// Covers the profile-identity guard (Bug 2 fix) and baseline lifecycle.
//
// Golden couple reference (CLAUDE.md §8):
//   Julien: birthYear=1977, salaireBrut=122207 CHF/an, canton=VS

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';

// ── Helpers ──────────────────────────────────────────────────────────────────

/// Fixed timestamp so CoachProfile value-equality is deterministic in tests.
/// CoachProfile.== includes updatedAt (version stamp), so both instances must
/// be created with the same explicit timestamp to be value-equal.
final _fixedUpdatedAt = DateTime(2026, 3, 22);
final _fixedCreatedAt = DateTime(2026, 1, 1);

final _goalRetraite = GoalA(
  type: GoalAType.retraite,
  targetDate: DateTime(2042),
  label: 'Retraite',
);

CoachProfile _profileA() => CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: 10184, // 122207 / 12
      goalA: _goalRetraite,
      createdAt: _fixedCreatedAt,
      updatedAt: _fixedUpdatedAt,
    );

/// Returns a distinct Dart object with the same field values as [_profileA].
/// Used to verify the identity guard uses value equality, not reference equality.
CoachProfile _profileADuplicate() => CoachProfile(
      birthYear: 1977,
      canton: 'VS',
      salaireBrutMensuel: 10184,
      goalA: _goalRetraite,
      createdAt: _fixedCreatedAt,
      updatedAt: _fixedUpdatedAt,
    );

CoachProfile _profileB() => CoachProfile(
      birthYear: 1982,
      canton: 'VS',
      salaireBrutMensuel: 5583, // 67000 / 12
      goalA: _goalRetraite,
      updatedAt: _fixedUpdatedAt,
    );

// ── Tests ─────────────────────────────────────────────────────────────────────

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('MintStateProvider — initial state', () {
    test('state is null before first recompute', () {
      final provider = MintStateProvider();
      expect(provider.state, isNull);
      expect(provider.hasState, isFalse);
      expect(provider.isRecomputing, isFalse);
    });
  });

  group('MintStateProvider — clear()', () {
    test('clear resets state and notifies listeners', () {
      final provider = MintStateProvider();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.clear();

      expect(provider.state, isNull);
      expect(provider.hasState, isFalse);
      expect(notifyCount, equals(1));
    });

    test('clear after clear does not crash', () {
      final provider = MintStateProvider();
      provider.clear();
      expect(() => provider.clear(), returnsNormally);
    });
  });

  group('MintStateProvider — profile identity guard (Bug 2)', () {
    test(
        'recompute with a value-equal profile object is a no-op '
        '(does not trigger a second computation)', () async {
      final provider = MintStateProvider();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      final profileA = _profileA();

      // First call — should start a computation (may succeed or error silently).
      await provider.recompute(profileA);

      final countAfterFirst = notifyCount;

      // Second call with a different object but same value — must be a no-op.
      final profileADuplicate = _profileADuplicate();
      expect(profileA, equals(profileADuplicate),
          reason: 'Test precondition: profiles must be value-equal');
      expect(identical(profileA, profileADuplicate), isFalse,
          reason: 'Test precondition: must be distinct object references');

      await provider.recompute(profileADuplicate);

      expect(notifyCount, equals(countAfterFirst),
          reason:
              'recompute with a value-equal profile must not trigger a new computation');
    });

    test(
        'recompute with same object reference is a no-op '
        'after it has been used once', () async {
      final provider = MintStateProvider();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      final profile = _profileA();
      await provider.recompute(profile);

      final countAfterFirst = notifyCount;

      // Exact same reference — must be a no-op.
      await provider.recompute(profile);

      expect(notifyCount, equals(countAfterFirst),
          reason: 'recompute with the identical profile reference must be a no-op');
    });

    test('recompute with a different profile triggers a new computation',
        () async {
      final provider = MintStateProvider();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      final profileA = _profileA();
      await provider.recompute(profileA);
      final countAfterFirst = notifyCount;

      final profileB = _profileB();
      await provider.recompute(profileB);

      // profileB differs from profileA, so a new computation must have run.
      // Notify count must be strictly greater than after the first call.
      expect(notifyCount, greaterThan(countAfterFirst),
          reason:
              'recompute with a different profile must trigger a new computation');
    });

    test('clear resets the identity guard — same profile recomputes after clear',
        () async {
      final provider = MintStateProvider();
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      final profile = _profileA();
      await provider.recompute(profile);
      final countAfterFirst = notifyCount;

      // Same profile — no-op.
      await provider.recompute(_profileADuplicate());
      expect(notifyCount, equals(countAfterFirst));

      // Clear resets the guard.
      provider.clear();
      final countAfterClear = notifyCount; // clear itself fires one notification.

      // After clear, same profile value must trigger a fresh computation.
      await provider.recompute(_profileADuplicate());
      expect(notifyCount, greaterThan(countAfterClear),
          reason: 'After clear(), the same profile must recompute');
    });
  });
}
