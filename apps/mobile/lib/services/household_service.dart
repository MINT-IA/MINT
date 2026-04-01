import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/services/api_service.dart';

/// Service for managing Couple+ household.
///
/// Provides API calls for:
/// - Fetching household details
/// - Inviting a partner by email
/// - Accepting an invitation code
/// - Revoking a household member
/// - Transferring household ownership
class HouseholdService {
  static const String _basePath = '/household';

  static String _normalizeBaseUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.endsWith('/api/v1')) {
      value = '$value/api/v1';
    }
    return value;
  }

  static Uri _uri(String baseUrl, String suffix) {
    return Uri.parse('${_normalizeBaseUrl(baseUrl)}$_basePath$suffix');
  }

  /// Get household details for current user.
  static Future<Map<String, dynamic>?> getHousehold(
    String token,
    String baseUrl,
  ) async {
    final response = await http.get(
      _uri(baseUrl, ''),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) return null;
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Invite a partner by email.
  static Future<Map<String, dynamic>> invitePartner(
    String token,
    String baseUrl,
    String email,
  ) async {
    final response = await http.post(
      _uri(baseUrl, '/invite'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'email': email}),
    );
    if (response.statusCode != 201) {
      String detail;
      try {
        detail = json.decode(response.body)['detail'] ?? 'Invitation failed';
      } catch (_) {
        detail = 'Invitation failed';
      }
      throw ApiException(detail, statusCode: response.statusCode);
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Accept an invitation code.
  static Future<Map<String, dynamic>> acceptInvitation(
    String token,
    String baseUrl,
    String invitationCode,
  ) async {
    final response = await http.post(
      _uri(baseUrl, '/accept'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'invitation_code': invitationCode}),
    );
    if (response.statusCode != 200) {
      String detail;
      try {
        detail = json.decode(response.body)['detail'] ?? 'Invitation acceptance failed';
      } catch (_) {
        detail = 'Invitation acceptance failed';
      }
      throw ApiException(detail, statusCode: response.statusCode);
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Revoke a household member.
  static Future<Map<String, dynamic>> revokeMember(
    String token,
    String baseUrl,
    String userId,
  ) async {
    final response = await http.delete(
      _uri(baseUrl, '/member/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      String detail;
      try {
        detail = json.decode(response.body)['detail'] ?? 'Member revocation failed';
      } catch (_) {
        detail = 'Member revocation failed';
      }
      throw ApiException(detail, statusCode: response.statusCode);
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }

  /// Transfer household ownership.
  static Future<Map<String, dynamic>> transferOwnership(
    String token,
    String baseUrl,
    String newOwnerId,
  ) async {
    final response = await http.put(
      _uri(baseUrl, '/transfer'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'new_owner_id': newOwnerId}),
    );
    if (response.statusCode != 200) {
      String detail;
      try {
        detail = json.decode(response.body)['detail'] ?? 'Ownership transfer failed';
      } catch (_) {
        detail = 'Ownership transfer failed';
      }
      throw ApiException(detail, statusCode: response.statusCode);
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }
}
