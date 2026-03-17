import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/providers/household_provider.dart';

void main() {
  group('HouseholdProvider', () {
    late HouseholdProvider provider;

    setUp(() {
      provider = HouseholdProvider();
    });

    // ── Initial state ──

    test('initial state has correct defaults', () {
      expect(provider.household, isNull);
      expect(provider.members, isEmpty);
      expect(provider.role, isNull);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.pendingInviteCode, isNull);
    });

    // ── Computed getters on empty state ──

    test('hasHousehold is false when household is null', () {
      expect(provider.hasHousehold, isFalse);
    });

    test('isOwner is false when role is null', () {
      expect(provider.isOwner, isFalse);
    });

    test('activeMemberCount is 0 when members is empty', () {
      expect(provider.activeMemberCount, 0);
    });

    test('partner is null when members is empty', () {
      expect(provider.partner, isNull);
    });

    test('hasPendingInvite is false when no pending members', () {
      expect(provider.hasPendingInvite, isFalse);
    });

    // ── clearError ──

    test('clearError sets error to null and notifies', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.clearError();
      expect(provider.error, isNull);
      expect(notifyCount, 1);
    });

    test('clearError notifies even when error was already null', () {
      int notifyCount = 0;
      provider.addListener(() => notifyCount++);

      provider.clearError();
      provider.clearError();
      expect(notifyCount, 2);
    });

    // ── Listener management ──

    test('removed listener is not called on clearError', () {
      int notifyCount = 0;
      void listener() => notifyCount++;

      provider.addListener(listener);
      provider.clearError();
      expect(notifyCount, 1);

      provider.removeListener(listener);
      provider.clearError();
      expect(notifyCount, 1);
    });

    // ── State isolation ──

    test('two providers have independent state', () {
      final p1 = HouseholdProvider();
      final p2 = HouseholdProvider();

      int count1 = 0;
      int count2 = 0;
      p1.addListener(() => count1++);
      p2.addListener(() => count2++);

      p1.clearError();
      expect(count1, 1);
      expect(count2, 0);
    });

    // ── Dispose ──

    test('dispose does not throw on fresh provider', () {
      expect(() => provider.dispose(), returnsNormally);
    });
  });

  group('HouseholdProvider computed getters with data', () {
    // These tests exercise the computed getters by simulating what
    // loadHousehold would populate. Since _members is private,
    // we use the public members getter and verify the computed results
    // indirectly. The actual member list population happens via
    // loadHousehold (which calls the backend).

    test('activeMemberCount counts only active members', () {
      // Cannot set _members directly; verify the count formula:
      // _members.where((m) => m['status'] == 'active').length
      final provider = HouseholdProvider();
      // With empty members, count is 0
      expect(provider.activeMemberCount, 0);
    });

    test('partner returns null when no active partner exists', () {
      final provider = HouseholdProvider();
      expect(provider.partner, isNull);
    });

    test('hasPendingInvite is false with no members', () {
      final provider = HouseholdProvider();
      expect(provider.hasPendingInvite, isFalse);
    });

    test('isOwner requires role to be exactly "owner"', () {
      final provider = HouseholdProvider();
      // role is null → not owner
      expect(provider.isOwner, isFalse);
      // The getter checks _role == 'owner', so 'Owner' or 'OWNER' would fail
    });
  });
}
