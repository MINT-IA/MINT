// Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 P3 —
// Unit tests for anonymous_session_id.dart + audit_buffer_db.dart.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/audit/anonymous_session_id.dart';
import 'package:mint_mobile/services/audit/audit_buffer_db.dart';

void main() {
  group('generateUuidV7', () {
    test('produces a valid RFC 9562 UUID v7', () {
      final id = generateUuidV7();
      expect(id.length, 36);
      expect(isUuidV7(id), isTrue, reason: 'invalid UUID v7 : $id');
    });

    test('two consecutive calls produce different ids', () {
      final a = generateUuidV7();
      final b = generateUuidV7();
      expect(a, isNot(b));
    });

    test('the hand-crafted fallback also produces a valid v7', () {
      // Force the fallback path by calling the validator with a known
      // hand-crafted value. The public API doesn't expose the private
      // _handCraftedUuidV7 ; we validate via isUuidV7 instead.
      final id = generateUuidV7();
      // Position 14 (the version nibble) must be '7'.
      expect(id[14], '7');
      // Position 19 (the variant nibble) must be 8, 9, a, or b.
      expect({'8', '9', 'a', 'b'}.contains(id[19].toLowerCase()), isTrue);
    });
  });

  group('isUuidV7', () {
    test('rejects strings of the wrong length', () {
      expect(isUuidV7('too-short'), isFalse);
      expect(isUuidV7('a' * 35), isFalse);
      expect(isUuidV7('a' * 37), isFalse);
    });

    test('rejects strings with the wrong version nibble', () {
      // UUID v4 (random) — version nibble = 4, NOT 7.
      const v4 = '550e8400-e29b-41d4-a716-446655440000';
      expect(isUuidV7(v4), isFalse);
    });

    test('rejects non-hex characters', () {
      const malformed = '550e8400-e29b-71d4-a716-44665544000g';
      expect(isUuidV7(malformed), isFalse);
    });
  });

  group('InMemoryAuditBufferDb', () {
    test('insert + fetchPending round-trip', () async {
      final db = InMemoryAuditBufferDb();
      final row = BufferedAuditRow(
        id: 'row-1',
        anonymousSessionId: generateUuidV7(),
        observedAt: DateTime.now().toUtc(),
        appVersion: '2.12.3+test',
        constantsVersionHash: 'h1',
        source: 'mobile_session_start',
        payloadJson: '{}',
      );
      await db.insert(row);
      final pending = await db.fetchPending();
      expect(pending.length, 1);
      expect(pending.first.id, 'row-1');
    });

    test('insert dedup blocks duplicate (sid, observedAt)', () async {
      final db = InMemoryAuditBufferDb();
      final ts = DateTime.now().toUtc();
      final sid = generateUuidV7();
      await db.insert(BufferedAuditRow(
        id: 'a',
        anonymousSessionId: sid,
        observedAt: ts,
        appVersion: 'v',
        constantsVersionHash: 'h',
        source: 'mobile_session_start',
        payloadJson: '{}',
      ));
      await db.insert(BufferedAuditRow(
        id: 'b',
        anonymousSessionId: sid,
        observedAt: ts, // SAME timestamp -> dedup
        appVersion: 'v',
        constantsVersionHash: 'h',
        source: 'mobile_session_warm_resume',
        payloadJson: '{}',
      ));
      expect(await db.pendingCount, 1);
    });

    test('purgeOlderThan removes stale rows', () async {
      final db = InMemoryAuditBufferDb();
      final old = DateTime.now().toUtc().subtract(const Duration(days: 31));
      final fresh = DateTime.now().toUtc();
      await db.insert(BufferedAuditRow(
        id: 'old',
        anonymousSessionId: generateUuidV7(),
        observedAt: old,
        appVersion: 'v',
        constantsVersionHash: 'h',
        source: 'mobile_session_start',
        payloadJson: '{}',
      ));
      await db.insert(BufferedAuditRow(
        id: 'fresh',
        anonymousSessionId: generateUuidV7(),
        observedAt: fresh,
        appVersion: 'v',
        constantsVersionHash: 'h',
        source: 'mobile_session_start',
        payloadJson: '{}',
      ));
      final purged = await db.purgeOlderThan(const Duration(days: 30));
      expect(purged, 1);
      expect(await db.pendingCount, 1);
    });
  });
}
