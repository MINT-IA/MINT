// Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 P3 —
// D-12 + D-MOB-03 + D-30 Mobile L1 audit ingestion service.
//
// Public entry point for the mobile L1 audit subsystem. Composes :
//   - anonymous_session_id.dart : UUID v7 generator + validator
//   - audit_buffer_db.dart      : sqflite_sqlcipher buffer (or InMemory fallback)
//   - offline_queue.dart        : exponential-backoff replay
//
// API (kept narrow — only what app/main + lifecycle observers consume) :
//   recordSessionStart() : enqueue source='mobile_session_start' row
//   recordSessionResume() : enqueue source='mobile_session_warm_resume' row
//   flush({httpPost}) : drain buffer via supplied httpPost callback
//
// The httpPost callback shape is intentionally generic
// (`Future<int> Function(Uri uri, Map<String, dynamic> body)` returning
// HTTP status) so the service does NOT depend on http/dio package
// (already in pubspec via http : ^1.2.0) at compile time — the wiring
// happens in `main.dart` where the existing ApiService instance lives.

import 'dart:async';
import 'dart:convert';

import 'anonymous_session_id.dart';
import 'audit_buffer_db.dart';
import 'offline_queue.dart';

const _auditPath = '/api/v1/audit/mobile-session-events';

/// Source values per D-12 contract.
enum MobileL1AuditSource { sessionStart, warmResume }

extension on MobileL1AuditSource {
  String get wireValue => switch (this) {
        MobileL1AuditSource.sessionStart => 'mobile_session_start',
        MobileL1AuditSource.warmResume => 'mobile_session_warm_resume',
      };
}

class MobileL1AuditService {
  MobileL1AuditService({
    required this.buffer,
    required this.anonymousSessionId,
    required this.appVersion,
    required this.constantsVersionHash,
    OfflineAuditQueue? queue,
  }) : queue = queue ?? OfflineAuditQueue(buffer: buffer);

  final AuditBufferDb buffer;
  final String anonymousSessionId;
  final String appVersion;
  final String constantsVersionHash;
  final OfflineAuditQueue queue;

  /// Construct a service with a fresh UUID v7 session id + in-memory
  /// buffer fallback. Production callers should pass a sqflite_sqlcipher
  /// AuditBufferDb instead.
  static MobileL1AuditService inMemory({
    required String appVersion,
    required String constantsVersionHash,
  }) {
    return MobileL1AuditService(
      buffer: InMemoryAuditBufferDb(),
      anonymousSessionId: generateUuidV7(),
      appVersion: appVersion,
      constantsVersionHash: constantsVersionHash,
    );
  }

  Future<void> recordSessionStart({String? localEventId, String? lifecycleState}) {
    return _record(MobileL1AuditSource.sessionStart,
        localEventId: localEventId, lifecycleState: lifecycleState);
  }

  Future<void> recordSessionResume({String? localEventId, String? lifecycleState}) {
    return _record(MobileL1AuditSource.warmResume,
        localEventId: localEventId, lifecycleState: lifecycleState);
  }

  Future<void> _record(
    MobileL1AuditSource source, {
    String? localEventId,
    String? lifecycleState,
  }) async {
    final now = DateTime.now().toUtc();
    final payload = <String, dynamic>{
      'anonymous_session_id': anonymousSessionId,
      'app_version': appVersion,
      'observed_at': now.toIso8601String(),
      'constants_version_hash': constantsVersionHash,
      'source': source.wireValue,
      if (localEventId != null) 'local_event_id': localEventId,
      if (lifecycleState != null) 'app_lifecycle_state': lifecycleState,
    };
    final row = BufferedAuditRow(
      id: '${anonymousSessionId}_${now.microsecondsSinceEpoch}',
      anonymousSessionId: anonymousSessionId,
      observedAt: now,
      appVersion: appVersion,
      constantsVersionHash: constantsVersionHash,
      source: source.wireValue,
      payloadJson: jsonEncode(payload),
      localEventId: localEventId,
      appLifecycleState: lifecycleState,
    );
    await buffer.insert(row);
  }

  /// Drain the buffer via `httpPost`. Returns the [DrainOutcome].
  ///
  /// `httpPost(uri, body)` MUST return the HTTP status code (200 on
  /// success, anything else = retry). Caller is responsible for
  /// providing the auth header when available.
  Future<DrainOutcome> flush({
    required Future<int> Function(Uri uri, Map<String, dynamic> body) httpPost,
    required Uri baseUri,
    int limit = 50,
  }) async {
    final uri = baseUri.replace(path: _auditPath);
    return queue.drain(
      limit: limit,
      sender: (row) async {
        final body = <String, dynamic>{
          'items': [row.toApiPayload()],
        };
        final code = await httpPost(uri, body);
        return code == 200;
      },
    );
  }
}
