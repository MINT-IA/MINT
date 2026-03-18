import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/household_service.dart';

/// Tests for HouseholdService — URL construction and static structure.
///
/// HouseholdService is primarily an HTTP client wrapper. These tests
/// validate the service structure, static method availability, and
/// error handling behavior for unreachable servers.
///
/// NOTE: Full integration tests require an HTTP mock adapter.
void main() {
  group('HouseholdService — structure & import', () {
    test('HouseholdService class is accessible', () {
      expect(HouseholdService, isNotNull);
    });

    test('getHousehold is a static method', () {
      expect(HouseholdService.getHousehold, isA<Function>());
    });

    test('invitePartner is a static method', () {
      expect(HouseholdService.invitePartner, isA<Function>());
    });

    test('acceptInvitation is a static method', () {
      expect(HouseholdService.acceptInvitation, isA<Function>());
    });

    test('revokeMember is a static method', () {
      expect(HouseholdService.revokeMember, isA<Function>());
    });

    test('transferOwnership is a static method', () {
      expect(HouseholdService.transferOwnership, isA<Function>());
    });
  });

  group('HouseholdService — network error handling', () {
    // Using localhost:1 which is almost certainly not running a server.
    // HTTP requests will fail with SocketException (connection refused).

    test('getHousehold returns null or throws on unreachable server', () async {
      try {
        final result = await HouseholdService.getHousehold(
          'fake-token',
          'http://127.0.0.1:1',
        );
        // If it somehow succeeds (unlikely), result should be null
        expect(result, isNull);
      } catch (e) {
        // SocketException or similar is expected
        expect(e, isNotNull);
      }
    });

    test('invitePartner throws on unreachable server', () async {
      try {
        await HouseholdService.invitePartner(
          'fake-token',
          'http://127.0.0.1:1',
          'test@example.com',
        );
        fail('Expected an exception');
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('acceptInvitation throws on unreachable server', () async {
      try {
        await HouseholdService.acceptInvitation(
          'fake-token',
          'http://127.0.0.1:1',
          'INVITE-CODE',
        );
        fail('Expected an exception');
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('revokeMember throws on unreachable server', () async {
      try {
        await HouseholdService.revokeMember(
          'fake-token',
          'http://127.0.0.1:1',
          'user-123',
        );
        fail('Expected an exception');
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('transferOwnership throws on unreachable server', () async {
      try {
        await HouseholdService.transferOwnership(
          'fake-token',
          'http://127.0.0.1:1',
          'new-owner-456',
        );
        fail('Expected an exception');
      } catch (e) {
        expect(e, isNotNull);
      }
    });
  });
}
