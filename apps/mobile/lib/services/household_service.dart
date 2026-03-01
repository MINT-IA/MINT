import 'dart:convert';
import 'package:http/http.dart' as http;

/// Service for managing Couple+ household.
///
/// Provides API calls for:
/// - Fetching household details
/// - Inviting a partner by email
/// - Accepting an invitation code
/// - Revoking a household member
/// - Transferring household ownership
class HouseholdService {
  static const String _basePath = '/api/v1/household';

  /// Get household details for current user.
  static Future<Map<String, dynamic>?> getHousehold(String token, String baseUrl) async {
    final response = await http.get(
      Uri.parse('$baseUrl$_basePath'),
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
      Uri.parse('$baseUrl$_basePath/invite'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'email': email}),
    );
    if (response.statusCode != 201) {
      throw Exception(json.decode(response.body)['detail'] ?? 'Erreur invitation');
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
      Uri.parse('$baseUrl$_basePath/accept'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'invitation_code': invitationCode}),
    );
    if (response.statusCode != 200) {
      throw Exception(json.decode(response.body)['detail'] ?? 'Erreur acceptation');
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
      Uri.parse('$baseUrl$_basePath/member/$userId'),
      headers: {'Authorization': 'Bearer $token'},
    );
    if (response.statusCode != 200) {
      throw Exception(json.decode(response.body)['detail'] ?? 'Erreur revocation');
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
      Uri.parse('$baseUrl$_basePath/transfer'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: json.encode({'new_owner_id': newOwnerId}),
    );
    if (response.statusCode != 200) {
      throw Exception(json.decode(response.body)['detail'] ?? 'Erreur transfert');
    }
    return json.decode(response.body) as Map<String, dynamic>;
  }
}
