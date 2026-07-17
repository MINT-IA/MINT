import 'dart:convert';

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/authenticated_transport.dart';
import 'package:mint_mobile/services/notification_service.dart';

// ────────────────────────────────────────────────────────────
//  COMMITMENT SERVICE — Phase 14 / CMIT-01 + CMIT-02
//
//  API client for commitment device persistence.
//  POST /api/v1/coach/commitment   — create commitment
//  GET  /api/v1/coach/commitment   — list commitments
//  PATCH /api/v1/coach/commitment/{id} — update status
//
//  Sources:
//    - CMIT-01: editable WHEN/WHERE/IF-THEN card per locked decision
//    - CMIT-02: notification scheduling per locked decision
// ────────────────────────────────────────────────────────────

class CommitmentService {
  final String baseUrl;
  final AuthenticatedTransport _transport;

  CommitmentService({
    String? baseUrl,
    AuthenticatedTransport? transport,
  })  : baseUrl = baseUrl ?? ApiService.baseUrl,
        _transport = transport ?? ApiService.authenticatedTransport;

  /// Save a new commitment to the backend.
  ///
  /// Returns the created commitment as a map with `id`, `status`,
  /// `reminderAt`, etc. (camelCase keys from backend).
  ///
  /// Throws [CommitmentException] on auth or network errors.
  Future<Map<String, dynamic>> saveCommitment({
    required String whenText,
    required String whereText,
    required String ifThenText,
    DateTime? reminderAt,
  }) async {
    final operation = _transport.beginOperation();
    await _requireSession(operation);

    final uri = Uri.parse('$baseUrl/coach/commitment');
    final body = <String, dynamic>{
      'whenText': whenText,
      'whereText': whereText,
      'ifThenText': ifThenText,
    };
    if (reminderAt != null) {
      body['reminderAt'] = reminderAt.toUtc().toIso8601String();
    }

    final response = await operation.send(
      AuthenticatedRequest.json(
        AuthenticatedHttpMethod.post,
        uri,
        body,
        timeout: const Duration(seconds: 15),
      ),
    );

    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw CommitmentException(
      code: 'save_failed',
      message: 'Failed to save commitment (${response.statusCode}).',
    );
  }

  /// Accept a commitment: saves it to backend AND schedules a local
  /// notification reminder if the backend returned a valid `reminderAt`.
  ///
  /// Centralizes the CMIT-02 notification scheduling so callers don't have
  /// to wire both `saveCommitment` + `NotificationService.scheduleCommitmentReminder`.
  ///
  /// Returns the backend response map (with `id`, `status`, `reminderAt`, …).
  Future<Map<String, dynamic>> acceptCommitment({
    required String whenText,
    required String whereText,
    required String ifThenText,
    DateTime? reminderAt,
    String reminderTitle = 'Rappel MINT',
  }) async {
    final response = await saveCommitment(
      whenText: whenText,
      whereText: whereText,
      ifThenText: ifThenText,
      reminderAt: reminderAt,
    );

    final responseReminderAt = response['reminderAt'] as String?;
    if (responseReminderAt != null && responseReminderAt.isNotEmpty) {
      final parsed = DateTime.tryParse(responseReminderAt);
      if (parsed != null && parsed.isAfter(DateTime.now())) {
        final responseId = response['id'] as String? ?? '';
        await NotificationService().scheduleCommitmentReminder(
          commitmentId: responseId.hashCode,
          reminderAt: parsed,
          title: reminderTitle,
          body: whenText,
        );
      }
    }

    return response;
  }

  /// List user's commitments, optionally filtered by status.
  Future<List<Map<String, dynamic>>> getCommitments({String? status}) async {
    final operation = _transport.beginOperation();
    await _requireSession(operation);

    var uri = Uri.parse('$baseUrl/coach/commitment');
    if (status != null) {
      uri = uri.replace(queryParameters: {'status': status});
    }

    final response = await operation.send(
      AuthenticatedRequest.get(uri, timeout: const Duration(seconds: 15)),
    );

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list.cast<Map<String, dynamic>>();
    }

    throw CommitmentException(
      code: 'list_failed',
      message: 'Failed to list commitments (${response.statusCode}).',
    );
  }

  /// Update commitment status (completed or dismissed).
  Future<Map<String, dynamic>> updateStatus(
    String commitmentId,
    String status,
  ) async {
    final operation = _transport.beginOperation();
    await _requireSession(operation);

    final uri = Uri.parse('$baseUrl/coach/commitment/$commitmentId');
    final response = await operation.send(
      AuthenticatedRequest.json(
        AuthenticatedHttpMethod.patch,
        uri,
        {'status': status},
        timeout: const Duration(seconds: 15),
      ),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    throw CommitmentException(
      code: 'update_failed',
      message: 'Failed to update commitment (${response.statusCode}).',
    );
  }

  Future<void> _requireSession(AuthenticatedOperation operation) async {
    try {
      await operation.requireSession();
    } on ApiException catch (error) {
      if (error.errorCode == ApiErrorCode.authenticationRequired) {
        throw const CommitmentException(
          code: 'no_auth',
          message: 'Not authenticated.',
        );
      }
      rethrow;
    }
  }
}

/// Exception for commitment service errors.
class CommitmentException implements Exception {
  final String code;
  final String message;

  const CommitmentException({required this.code, required this.message});

  @override
  String toString() => 'CommitmentException($code): $message';
}
