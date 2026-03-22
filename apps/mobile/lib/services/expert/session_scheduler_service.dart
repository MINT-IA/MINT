/// Session Scheduler Service — Sprint S65 (Expert Tier).
///
/// Records and retrieves specialist-session requests.
/// Persists to SharedPreferences — no network calls, fully offline-capable.
///
/// This service does NOT book sessions (that requires a backend in Phase 4).
/// It records intent so:
///  1. The user sees their request history.
///  2. Analytics can track conversion to specialist sessions.
///
/// COMPLIANCE (NON-NEGOTIABLE):
/// - No PII stored — only specialization + timestamp + status.
/// - Term "conseiller" is BANNED — always "spécialiste" / "specialist".
///
/// Outil éducatif — ne constitue pas un conseil financier (LSFin art. 3).
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/expert/advisor_specialization.dart';

// ════════════════════════════════════════════════════════════════
//  ENUMS & MODELS
// ════════════════════════════════════════════════════════════════

/// Status lifecycle for a specialist-session request.
enum SessionStatus {
  /// Request submitted, not yet confirmed by MINT backend.
  requested,

  /// Confirmed and a time slot has been assigned.
  scheduled,

  /// Session took place.
  completed,

  /// Cancelled by the user or the system.
  cancelled,
}

/// A recorded request for a specialist session.
///
/// Contains NO PII — only specialization, timestamp, and status.
class SessionRequest {
  /// Unique identifier (UUID v4 generated at creation).
  final String id;

  /// The specialization topic requested.
  final AdvisorSpecialization specialization;

  /// When the request was submitted.
  final DateTime requestedAt;

  /// Current lifecycle status.
  final SessionStatus status;

  const SessionRequest({
    required this.id,
    required this.specialization,
    required this.requestedAt,
    required this.status,
  });

  // ── Serialization ────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'specialization': specialization.name,
        'requestedAt': requestedAt.toIso8601String(),
        'status': status.name,
      };

  factory SessionRequest.fromJson(Map<String, dynamic> json) {
    return SessionRequest(
      id: json['id'] as String,
      specialization: AdvisorSpecialization.values.firstWhere(
        (e) => e.name == json['specialization'],
        orElse: () => AdvisorSpecialization.retirement,
      ),
      requestedAt: DateTime.parse(json['requestedAt'] as String),
      status: SessionStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => SessionStatus.requested,
      ),
    );
  }

  /// Create a copy with an updated [status].
  SessionRequest copyWithStatus(SessionStatus newStatus) {
    return SessionRequest(
      id: id,
      specialization: specialization,
      requestedAt: requestedAt,
      status: newStatus,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SessionRequest && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

// ════════════════════════════════════════════════════════════════
//  SERVICE
// ════════════════════════════════════════════════════════════════

/// Records and retrieves specialist-session requests.
///
/// All methods are static. SharedPreferences is injected for testability.
class SessionSchedulerService {
  SessionSchedulerService._();

  /// SharedPreferences key for the session request list.
  static const String _prefKey = 'expert_session_requests';

  // ── Public API ───────────────────────────────────────────────

  /// Record a new session request for [specialization].
  ///
  /// Generates a time-based ID, stores the request with status [requested],
  /// and persists it to [prefs].
  ///
  /// Returns the newly created [SessionRequest].
  static Future<SessionRequest> requestSession({
    required AdvisorSpecialization specialization,
    required SharedPreferences prefs,
    DateTime? now,
  }) async {
    final effectiveNow = now ?? DateTime.now();
    final id =
        '${specialization.name}_${effectiveNow.millisecondsSinceEpoch}';

    final request = SessionRequest(
      id: id,
      specialization: specialization,
      requestedAt: effectiveNow,
      status: SessionStatus.requested,
    );

    final existing = await history(prefs);
    final updated = [...existing, request];
    await _persist(prefs, updated);

    return request;
  }

  /// Retrieve the full session-request history, newest first.
  ///
  /// Returns an empty list if no requests have been stored.
  static Future<List<SessionRequest>> history(SharedPreferences prefs) async {
    final raw = prefs.getString(_prefKey);
    if (raw == null || raw.isEmpty) return [];

    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final requests = list
          .map((e) => SessionRequest.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
      return requests;
    } catch (_) {
      // Corrupt data — return empty rather than crash.
      return [];
    }
  }

  /// Update the [status] of the request with [id].
  ///
  /// No-op if no request with that [id] exists.
  static Future<void> updateStatus({
    required String id,
    required SessionStatus status,
    required SharedPreferences prefs,
  }) async {
    final existing = await history(prefs);
    final updated = existing
        .map((r) => r.id == id ? r.copyWithStatus(status) : r)
        .toList();
    await _persist(prefs, updated);
  }

  /// Cancel the request with [id].
  ///
  /// Convenience wrapper around [updateStatus].
  static Future<void> cancelRequest({
    required String id,
    required SharedPreferences prefs,
  }) =>
      updateStatus(
        id: id,
        status: SessionStatus.cancelled,
        prefs: prefs,
      );

  /// Delete all session requests from storage.
  ///
  /// Used for testing and account-reset flows.
  static Future<void> clearHistory(SharedPreferences prefs) async {
    await prefs.remove(_prefKey);
  }

  /// Return requests filtered by [status].
  static Future<List<SessionRequest>> historyByStatus({
    required SessionStatus status,
    required SharedPreferences prefs,
  }) async {
    final all = await history(prefs);
    return all.where((r) => r.status == status).toList();
  }

  // ── Private helpers ───────────────────────────────────────────

  static Future<void> _persist(
    SharedPreferences prefs,
    List<SessionRequest> requests,
  ) async {
    final json = jsonEncode(requests.map((r) => r.toJson()).toList());
    await prefs.setString(_prefKey, json);
  }
}
