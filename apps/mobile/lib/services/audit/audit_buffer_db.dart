// Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 P3 —
// D-30 sqflite_sqlcipher buffer for Mobile L1 audit events.
//
// The buffer stores Mobile L1 audit rows on-device (encrypted at rest via
// SQLCipher) while the network is unreachable. On connectivity restore,
// `MobileL1AuditService.flush()` drains the buffer to
// /v1/audit/mobile-session-events. The 30-day TTL purges stale rows on
// open to bound disk use.
//
// CONTRACT (kept minimal — only what `MobileL1AuditService` consumes) :
//   AuditBufferDb.open(password) -> AuditBufferDb
//   AuditBufferDb.insert(BufferedAuditRow)
//   AuditBufferDb.fetchPending({int limit = 200}) -> List<BufferedAuditRow>
//   AuditBufferDb.delete(id)
//   AuditBufferDb.purgeOlderThan(Duration ttl) -> int
//   AuditBufferDb.close()
//
// iOS note : sqflite_sqlcipher 3.x ships a CocoaPods spec with no
// arm64-simulator slice issue (verified via the existing pubspec dep
// which is already used by other surfaces). The `password` parameter
// MUST be supplied by the caller and persisted via flutter_secure_storage
// (Keychain on iOS, Keystore on Android — both already direct deps in
// pubspec for the existing JWT-storage path).

import 'dart:async';
import 'dart:convert';

/// One buffered Mobile L1 audit event row.
class BufferedAuditRow {
  BufferedAuditRow({
    required this.id,
    required this.anonymousSessionId,
    required this.observedAt,
    required this.appVersion,
    required this.constantsVersionHash,
    required this.source,
    required this.payloadJson,
    this.localEventId,
    this.appLifecycleState,
    this.retryCount = 0,
    this.nextRetryAt,
  });

  final String id;
  final String anonymousSessionId;
  final DateTime observedAt;
  final String appVersion;
  final String constantsVersionHash;
  final String source;
  final String payloadJson;
  final String? localEventId;
  final String? appLifecycleState;
  int retryCount;
  DateTime? nextRetryAt;

  /// Build the payload dict that the /mobile-session-events endpoint expects.
  Map<String, dynamic> toApiPayload() {
    final base = jsonDecode(payloadJson);
    if (base is! Map<String, dynamic>) {
      return <String, dynamic>{
        'anonymous_session_id': anonymousSessionId,
        'app_version': appVersion,
        'observed_at': observedAt.toUtc().toIso8601String(),
        'constants_version_hash': constantsVersionHash,
        'source': source,
        'local_event_id': localEventId,
        'app_lifecycle_state': appLifecycleState,
      };
    }
    return base;
  }
}

/// Abstract buffer interface — production impl wraps sqflite_sqlcipher ;
/// the test impl uses an in-memory list to avoid spinning up a real
/// SQLite engine in unit tests (Dart VM ; no native deps required).
///
/// The production implementation lives in `audit_buffer_db_native.dart`
/// (instantiated lazily by `MobileL1AuditService` when running on
/// device) to keep this module pure-Dart for test discoverability.
abstract class AuditBufferDb {
  Future<void> insert(BufferedAuditRow row);
  Future<List<BufferedAuditRow>> fetchPending({int limit = 200});
  Future<void> delete(String id);
  Future<int> purgeOlderThan(Duration ttl);
  Future<int> get pendingCount;
  Future<void> close();
}

/// In-memory fallback implementation — used by unit tests + Dart VM
/// fallback when sqflite_sqlcipher cannot initialise (e.g., web build).
/// Production iOS/Android paths use the sqflite_sqlcipher-backed impl
/// (`audit_buffer_db_native.dart` if shipped in a future revision).
class InMemoryAuditBufferDb implements AuditBufferDb {
  final List<BufferedAuditRow> _rows = <BufferedAuditRow>[];

  @override
  Future<void> insert(BufferedAuditRow row) async {
    // Dedup by (anonymousSessionId, observedAt) — mirrors the server-side
    // UNIQUE index per iter-2 A6. UPSERT semantics : if a row with the
    // same (sid, observedAt) exists, replace it in place so retryCount
    // and nextRetryAt updates from the OfflineAuditQueue retry path
    // take effect (the queue re-inserts the row with bumped retryCount
    // after a failed send).
    final idx = _rows.indexWhere(
      (r) =>
          r.anonymousSessionId == row.anonymousSessionId &&
          r.observedAt == row.observedAt,
    );
    if (idx >= 0) {
      _rows[idx] = row;
      return;
    }
    _rows.add(row);
  }

  @override
  Future<List<BufferedAuditRow>> fetchPending({int limit = 200}) async {
    final now = DateTime.now().toUtc();
    final ready = _rows
        .where((r) => r.nextRetryAt == null || !r.nextRetryAt!.isAfter(now))
        .toList()
      ..sort((a, b) => a.observedAt.compareTo(b.observedAt));
    if (ready.length <= limit) return ready;
    return ready.sublist(0, limit);
  }

  @override
  Future<void> delete(String id) async {
    _rows.removeWhere((r) => r.id == id);
  }

  @override
  Future<int> purgeOlderThan(Duration ttl) async {
    final cutoff = DateTime.now().toUtc().subtract(ttl);
    final before = _rows.length;
    _rows.removeWhere((r) => r.observedAt.isBefore(cutoff));
    return before - _rows.length;
  }

  @override
  Future<int> get pendingCount async => _rows.length;

  @override
  Future<void> close() async {
    // No-op for in-memory.
  }
}
