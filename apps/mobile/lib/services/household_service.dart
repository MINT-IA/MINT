import 'dart:convert';

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/authenticated_transport.dart';

/// Service for managing Couple+ household through the app-authenticated
/// transport boundary.
class HouseholdService {
  HouseholdService({
    AuthenticatedTransport? transport,
    String? baseUrl,
  })  : _transport = transport ?? ApiService.authenticatedTransport,
        _baseUrl = _normalizeBaseUrl(baseUrl ?? ApiService.baseUrl);

  static const String _basePath = '/household';

  final AuthenticatedTransport _transport;
  final String _baseUrl;

  static String _normalizeBaseUrl(String raw) {
    var value = raw.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    if (!value.endsWith('/api/v1')) value = '$value/api/v1';
    return value;
  }

  Uri _uri(String suffix) => Uri.parse('$_baseUrl$_basePath$suffix');

  Future<Map<String, dynamic>?> getHousehold() async {
    final operation = _transport.beginOperation();
    final response = await operation.send(
      AuthenticatedRequest.get(_uri('')),
    );
    if (response.statusCode != 200) return null;
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> invitePartner(String email) async {
    final operation = _transport.beginOperation();
    final response = await operation.send(
      AuthenticatedRequest.json(
        AuthenticatedHttpMethod.post,
        _uri('/invite'),
        {'email': email},
      ),
    );
    if (response.statusCode != 201) {
      throw ApiException(
        _errorDetail(response.body, 'Invitation failed'),
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> acceptInvitation(String invitationCode) async {
    final operation = _transport.beginOperation();
    final response = await operation.send(
      AuthenticatedRequest.json(
        AuthenticatedHttpMethod.post,
        _uri('/accept'),
        {'invitation_code': invitationCode},
      ),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        _errorDetail(response.body, 'Invitation acceptance failed'),
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> revokeMember(String userId) async {
    final operation = _transport.beginOperation();
    final response = await operation.send(
      AuthenticatedRequest.empty(
        AuthenticatedHttpMethod.delete,
        _uri('/member/$userId'),
      ),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        _errorDetail(response.body, 'Member revocation failed'),
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> transferOwnership(String newOwnerId) async {
    final operation = _transport.beginOperation();
    final response = await operation.send(
      AuthenticatedRequest.json(
        AuthenticatedHttpMethod.put,
        _uri('/transfer'),
        {'new_owner_id': newOwnerId},
      ),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        _errorDetail(response.body, 'Ownership transfer failed'),
        statusCode: response.statusCode,
      );
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static String _errorDetail(String body, String fallback) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        final detail = decoded['detail'];
        if (detail is String && detail.isNotEmpty) return detail;
      }
    } on FormatException {
      // Preserve the former fallback for non-JSON backend errors.
    }
    return fallback;
  }
}
