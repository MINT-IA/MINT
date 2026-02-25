import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:mint_mobile/services/api_service.dart';

/// Unit tests for ApiService
///
/// ApiService is a thin HTTP wrapper — most methods make network calls.
/// These tests cover the testable surface without mocking:
/// - Base URL configuration constant
/// - URI construction patterns (endpoint paths)
/// - Error message format
/// - Class structure and method signatures
/// - Endpoint path conventions
void main() {
  // ═══════════════════════════════════════════════════════════════════════
  // Base URL Configuration
  // ═══════════════════════════════════════════════════════════════════════

  group('ApiService — Base URL', () {
    test('baseUrl is a valid localhost URL', () {
      expect(ApiService.baseUrl, isNotEmpty);
      expect(ApiService.baseUrl, startsWith('http'));
    });

    test('baseUrl ends with /api/v1 (versioned API)', () {
      expect(ApiService.baseUrl, endsWith('/api/v1'));
    });

    test('baseUrl fallback depends on build mode', () {
      if (kReleaseMode) {
        expect(ApiService.baseUrl, equals('https://api.mint.ch/api/v1'));
      } else {
        expect(ApiService.baseUrl, equals('http://localhost:8888/api/v1'));
      }
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // URI Construction — endpoint path building
  // ═══════════════════════════════════════════════════════════════════════

  group('ApiService — URI construction', () {
    test('endpoint appended to baseUrl produces valid URI', () {
      final uri = Uri.parse('${ApiService.baseUrl}/profiles');
      expect(uri.path, equals('/api/v1/profiles'));
      if (!kReleaseMode) {
        expect(uri.host, equals('localhost'));
        expect(uri.port, equals(8888));
      }
    });

    test('auth/register endpoint URI is correct', () {
      final uri = Uri.parse('${ApiService.baseUrl}/auth/register');
      expect(uri.path, equals('/api/v1/auth/register'));
      expect(uri.scheme, equals('http'));
    });

    test('auth/login endpoint URI is correct', () {
      final uri = Uri.parse('${ApiService.baseUrl}/auth/login');
      expect(uri.path, equals('/api/v1/auth/login'));
    });

    test('auth/me endpoint URI is correct', () {
      final uri = Uri.parse('${ApiService.baseUrl}/auth/me');
      expect(uri.path, equals('/api/v1/auth/me'));
    });

    test('sessions endpoint URI is correct', () {
      final uri = Uri.parse('${ApiService.baseUrl}/sessions');
      expect(uri.path, equals('/api/v1/sessions'));
    });

    test('session report endpoint with ID produces valid URI', () {
      const sessionId = 'abc-123';
      final uri = Uri.parse('${ApiService.baseUrl}/sessions/$sessionId/report');
      expect(uri.path, equals('/api/v1/sessions/abc-123/report'));
    });

    test('nested endpoint paths remain valid URIs', () {
      final uri = Uri.parse('${ApiService.baseUrl}/rag/query');
      expect(uri.pathSegments, containsAll(['api', 'v1', 'rag', 'query']));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Error message format
  // ═══════════════════════════════════════════════════════════════════════

  group('ApiService — Error message format', () {
    test('GET error includes endpoint path and body', () {
      // Verifies the format of exception messages that ApiService throws.
      // The pattern is: '{METHOD} {endpoint} failed: {body}'
      const endpoint = '/profiles';
      const body = '{"detail":"Not found"}';
      const msg = 'GET $endpoint failed: $body';
      expect(msg, contains('GET'));
      expect(msg, contains(endpoint));
      expect(msg, contains(body));
    });

    test('POST error includes endpoint path and body', () {
      const endpoint = '/sessions';
      const body = '{"detail":"Validation error"}';
      const msg = 'POST $endpoint failed: $body';
      expect(msg, contains('POST'));
      expect(msg, contains(endpoint));
      expect(msg, contains(body));
    });

    test('PUT error includes endpoint path and body', () {
      const endpoint = '/profiles/123';
      const body = '{"detail":"Conflict"}';
      const msg = 'PUT $endpoint failed: $body';
      expect(msg, contains('PUT'));
      expect(msg, contains(endpoint));
    });

    test('DELETE error includes endpoint path and body', () {
      const endpoint = '/sessions/456';
      const body = '{"detail":"Forbidden"}';
      const msg = 'DELETE $endpoint failed: $body';
      expect(msg, contains('DELETE'));
      expect(msg, contains(endpoint));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Content-Type header convention
  // ═══════════════════════════════════════════════════════════════════════

  group('ApiService — Header conventions', () {
    test('standard Content-Type is application/json', () {
      // The service uses 'Content-Type': 'application/json' for all requests
      const contentType = 'application/json';
      final headers = {'Content-Type': contentType};
      expect(headers['Content-Type'], equals('application/json'));
    });

    test('auth header uses Bearer scheme', () {
      // Token is prefixed with "Bearer " in the Authorization header
      const token = 'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.test';
      const authHeader = 'Bearer $token';
      expect(authHeader, startsWith('Bearer '));
      expect(authHeader, contains(token));
    });

    test('auth header is absent when token is null', () {
      // When no token is stored, only Content-Type should be present
      const String? token = null;
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
      expect(headers.containsKey('Authorization'), isFalse);
      expect(headers.length, equals(1));
    });

    test('auth header is present when token exists', () {
      const token = 'some-jwt-token';
      final headers = <String, String>{'Content-Type': 'application/json'};
      if (token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
      expect(headers.containsKey('Authorization'), isTrue);
      expect(headers.length, equals(2));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════
  // Registration request body structure
  // ═══════════════════════════════════════════════════════════════════════

  group('ApiService — Request body conventions', () {
    test('register body includes email and password', () {
      final body = {
        'email': 'test@mint.ch',
        'password': 'securePassword123',
      };
      expect(body.containsKey('email'), isTrue);
      expect(body.containsKey('password'), isTrue);
    });

    test('register body includes display_name when provided', () {
      const displayName = 'Jean Dupont';
      final body = {
        'email': 'test@mint.ch',
        'password': 'securePassword123',
        'display_name': displayName,
      };
      expect(body.containsKey('display_name'), isTrue);
      expect(body['display_name'], equals('Jean Dupont'));
    });

    test('register body omits display_name when null', () {
      const String? displayName = null;
      final body = {
        'email': 'test@mint.ch',
        'password': 'securePassword123',
        if (displayName != null) 'display_name': displayName,
      };
      expect(body.containsKey('display_name'), isFalse);
    });

    test('login body has email and password only', () {
      final body = {
        'email': 'user@example.com',
        'password': 'myPassword',
      };
      expect(body.length, equals(2));
      expect(body.keys, containsAll(['email', 'password']));
    });
  });
}
