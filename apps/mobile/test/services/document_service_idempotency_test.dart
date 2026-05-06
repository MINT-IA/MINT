// DOCS-03 (Phase 92) — pure deterministic test for the SHA256-of-bytes
// Idempotency-Key derivation used by `/documents/upload`. We assert the
// contract on the public helper [computeIdempotencyKey] rather than
// driving the full singleton DocumentService through HTTP — surgical
// scope (Karpathy practice 3) keeps the singleton untouched and avoids
// having to wire client injection just for this assertion.
//
// What this test guarantees :
//   - Same payload  → same key (real idempotency, backend dedupes)
//   - Different payload → different key (no false collisions)
//   - Format is hex-encoded SHA-256 (64 chars, lowercase a-f0-9)

import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/document_service.dart';

void main() {
  group('DOCS-03 — computeIdempotencyKey (SHA256 of file bytes)', () {
    final bytesA = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final bytesAcopy = Uint8List.fromList(<int>[1, 2, 3, 4]);
    final bytesB = Uint8List.fromList(<int>[1, 2, 3, 5]);

    test('matches direct sha256 hex digest (no homemade transform)', () {
      final expected = sha256.convert(bytesA).toString();
      expect(computeIdempotencyKey(bytesA), expected);
    });

    test('same bytes yield same key (deterministic, real dedup)', () {
      expect(computeIdempotencyKey(bytesA), computeIdempotencyKey(bytesAcopy));
    });

    test('different bytes yield different keys (no collision)', () {
      expect(computeIdempotencyKey(bytesA),
          isNot(equals(computeIdempotencyKey(bytesB))));
    });

    test('format is 64-char hex (lowercase)', () {
      final key = computeIdempotencyKey(bytesA);
      expect(key.length, 64);
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue,
          reason: 'Expected lowercase hex SHA-256, got "$key"');
    });

    test('regression : empty payload still returns a stable hex digest', () {
      // SHA-256 of empty bytes is a well-known constant. If the hashing
      // pipeline ever silently changes (e.g. switches to a salted
      // variant), this anchor breaks first.
      const emptySha256 =
          'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855';
      expect(computeIdempotencyKey(Uint8List(0)), emptySha256);
    });

    test('treats UUID v4 fallback as a strict regression : ≥1 hyphen would '
        'mean we slipped back to the old random-key path', () {
      // Backend dedup at documents.py:415-420 only works when retries with
      // the same payload produce the same key. UUID v4 keys all contain
      // hyphens ; SHA-256 hex never does. This assertion is intentionally
      // crude — it locks in the new format.
      expect(computeIdempotencyKey(bytesA), isNot(contains('-')));
    });
  });
}
