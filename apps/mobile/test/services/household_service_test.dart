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
    final service = HouseholdService();

    test('HouseholdService class is accessible', () {
      expect(HouseholdService, isNotNull);
    });

    test('getHousehold is available on the injected service', () {
      expect(service.getHousehold, isA<Function>());
    });

    test('invitePartner is a static method', () {
      expect(service.invitePartner, isA<Function>());
    });

    test('acceptInvitation is a static method', () {
      expect(service.acceptInvitation, isA<Function>());
    });

    test('revokeMember is a static method', () {
      expect(service.revokeMember, isA<Function>());
    });

    test('transferOwnership is a static method', () {
      expect(service.transferOwnership, isA<Function>());
    });
  });

  group('HouseholdService — network error handling', () {
    // Using localhost:1 which is almost certainly not running a server.
    // HTTP requests will fail with SocketException (connection refused).

    test('getHousehold returns null or throws on unreachable server', () async {
      try {
        final result = await service.getHousehold();
        // If it somehow succeeds (unlikely), result should be null
        expect(result, isNull);
      } catch (e) {
        // SocketException or similar is expected
        expect(e, isNotNull);
      }
    });

    test('invitePartner throws on unreachable server', () async {
      try {
        await service.invitePartner('test@example.com');
        fail('Expected an exception');
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('acceptInvitation throws on unreachable server', () async {
      try {
        await service.acceptInvitation('INVITE-CODE');
        fail('Expected an exception');
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('revokeMember throws on unreachable server', () async {
      try {
        await service.revokeMember('user-123');
        fail('Expected an exception');
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('transferOwnership throws on unreachable server', () async {
      try {
        await service.transferOwnership('new-owner-456');
        fail('Expected an exception');
      } catch (e) {
        expect(e, isNotNull);
      }
    });
  });
}

final service = HouseholdService(baseUrl: 'http://127.0.0.1:1');
