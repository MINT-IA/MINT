// Phase mint-data-architecture-v1-02 Plan 02-02 W1 continuation-4 P3 —
// D-30 anonymous_session_id generator (UUID v7 per RFC 9562).
//
// UUID v7 = 48-bit unix ms timestamp + 12 bits rand_a + 62 bits rand_b
// (per RFC 9562 § 5.7). The `uuid` package shipped in pubspec
// (v4.0.0) exposes Uuid().v7() ; this module provides a safe wrapper
// that survives package-API drift (downgrades, alternate forks) by
// falling back to a hand-crafted implementation that matches the
// RFC bit layout.

import 'dart:math';

import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Generate a fresh RFC 9562 UUID v7.
///
/// Tries the `uuid` package's `v7()` API first ; falls back to a
/// hand-crafted v7 (millisecond-timestamp-prefixed, fully RFC 9562
/// compliant) if the package API surface drifts. The fallback path is
/// covered by tests in
/// `test/services/audit/anonymous_session_buffer_test.dart`.
String generateUuidV7() {
  try {
    // ignore: avoid_dynamic_calls — package_v7 API may exist or not
    // ignore: prefer_const_declarations — runtime cast not const-foldable
    final dyn = _uuid as dynamic;
    final result = dyn.v7();
    if (result is String && result.length >= 36) {
      return result;
    }
  } catch (_) {
    // Fall through to hand-crafted v7.
  }
  return _handCraftedUuidV7();
}

/// Hand-crafted UUID v7 per RFC 9562 § 5.7.
///
/// Layout :
///   48 bits : unix ts in ms (big-endian)
///   12 bits : rand_a (version field embedded : top 4 bits = 0b0111)
///   62 bits : rand_b (variant field embedded : top 2 bits = 0b10)
String _handCraftedUuidV7() {
  final rng = Random.secure();
  final tsMs = DateTime.now().toUtc().millisecondsSinceEpoch;

  // 16 random bytes, then patch in the version + variant bits.
  final bytes = List<int>.generate(16, (_) => rng.nextInt(256));

  // bytes[0..5] = high 48 bits of timestamp (big-endian).
  for (var i = 0; i < 6; i++) {
    bytes[i] = (tsMs >> (40 - i * 8)) & 0xFF;
  }
  // bytes[6] top 4 bits = version (0b0111 = 7).
  bytes[6] = (bytes[6] & 0x0F) | 0x70;
  // bytes[8] top 2 bits = variant (0b10).
  bytes[8] = (bytes[8] & 0x3F) | 0x80;

  String hex(int b) => b.toRadixString(16).padLeft(2, '0');
  final hexStr = bytes.map(hex).join();
  return '${hexStr.substring(0, 8)}-${hexStr.substring(8, 12)}-'
      '${hexStr.substring(12, 16)}-${hexStr.substring(16, 20)}-'
      '${hexStr.substring(20, 32)}';
}

/// Return True if `value` looks like an RFC 9562 UUID v7 string.
///
/// Validates : 36-char canonical form (8-4-4-4-12), hex chars only,
/// version nibble == 7 (char index 14), variant nibble in 8/9/a/b
/// (char index 19).
bool isUuidV7(String value) {
  if (value.length != 36) {
    return false;
  }
  final hyphensAt = [8, 13, 18, 23];
  for (final i in hyphensAt) {
    if (value[i] != '-') return false;
  }
  for (var i = 0; i < value.length; i++) {
    if (hyphensAt.contains(i)) continue;
    final c = value.codeUnitAt(i);
    final isHex = (c >= 0x30 && c <= 0x39) ||
        (c >= 0x61 && c <= 0x66) ||
        (c >= 0x41 && c <= 0x46);
    if (!isHex) return false;
  }
  if (value[14] != '7') return false;
  final variantChar = value[19].toLowerCase();
  if (!{'8', '9', 'a', 'b'}.contains(variantChar)) return false;
  return true;
}
