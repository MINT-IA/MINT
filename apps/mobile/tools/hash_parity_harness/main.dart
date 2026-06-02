// Phase 95 DAG-INVALIDATION — hash parity harness (Path A pure-Dart).
//
// Per RESEARCH §D-03 : standalone harness that takes JSONL on stdin
// (`{"id":..., "inputs": {...}}` per line), emits JSONL on stdout
// (`{"id":..., "sha256":...}` per line). Uses only `dart:convert`,
// `dart:io`, and `package:crypto` — no `financial_core/` imports, so
// `dart compile exe` works today without the Phase 92.7 cascade fix.
//
// IMPORTANT — Quantize-BEFORE-canonicalize (CONTEXT D-02 / RESEARCH §D-01).
// Python compute_inputs_hash() does:
//   1. _quantize_floats(dict) : recursive walker, floats -> Decimal(0.01)
//      ROUND_HALF_UP, ints/bools preserved.
//   2. rfc8785.dumps(quantized) : canonical JSON with sorted keys.
//   3. sha256.hexdigest().
// The Dart side MUST mirror step 1 OR the hashes diverge (e.g. 0.068
// quantized to 0.07 on the Python side stays 0.068 on the Dart side).
// _quantize() below replicates the Python recursion order exactly.
//
// RFC 8785 canonicalisation hand-implemented (no `dart_jcs` exists on
// pub.dev as of 2026-05-10). Rules suffice for our quantized-float /
// ASCII-key inputs :
//   1. Object keys sorted by UTF-16 code unit (Dart String.compareTo).
//   2. No whitespace (no JsonEncoder.withIndent).
//   3. Floats : integer-valued floats serialise without trailing `.0`
//      to match Python's RFC 8785 output.
//
// Python side : services/backend/app/services/coach/inputs_hash.py.
// Parity test : services/backend/tests/test_dag_invalidation/test_hash_parity.py.
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';

/// Mirrors Python `_quantize_floats()` from inputs_hash.py.
///
/// Recursion order (MUST match Python exactly) :
///  1. Map -> recurse on values, preserve keys.
///  2. List -> recurse element-wise.
///  3. bool -> return as-is (precedes int branch ; Dart `bool` is NOT
///     a subtype of `num`, but we still keep the order parallel).
///  4. int -> return as-is.
///  5. double -> quantize to 2 decimals ROUND_HALF_UP.
///  6. Other -> return as-is.
dynamic _quantize(dynamic v) {
  if (v is Map) {
    final out = <String, dynamic>{};
    v.forEach((k, val) {
      out[k as String] = _quantize(val);
    });
    return out;
  }
  if (v is List) {
    return v.map(_quantize).toList();
  }
  if (v is bool) return v;
  if (v is int) return v;
  if (v is double) {
    if (v.isNaN) {
      throw const FormatException("NaN not allowed in projection inputs");
    }
    if (!v.isFinite) {
      throw const FormatException("inf/-inf not allowed in projection inputs");
    }
    // Decimal(0.01) ROUND_HALF_UP : multiply by 100, round half-away-from-zero,
    // divide by 100. Dart's `roundToDouble()` is ROUND_HALF_AWAY_FROM_ZERO
    // which matches Python's ROUND_HALF_UP for positive numbers ; for
    // negative numbers Python's ROUND_HALF_UP rounds away from zero
    // (e.g. -0.005 -> -0.01), which also matches Dart's roundToDouble.
    final scaled = v * 100.0;
    final rounded = scaled.roundToDouble();
    return rounded / 100.0;
  }
  return v;
}

String canonicalize(dynamic v) {
  if (v is Map) {
    final keys = v.keys.cast<String>().toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${canonicalize(v[k])}').join(',')}}';
  }
  if (v is List) {
    return '[${v.map(canonicalize).join(',')}]';
  }
  if (v is double) {
    if (v.truncateToDouble() == v && v.isFinite) {
      return v.toInt().toString();
    }
    return v.toString();
  }
  if (v is bool) return v ? 'true' : 'false';
  if (v == null) return 'null';
  return jsonEncode(v); // strings + ints
}

Future<void> main(List<String> args) async {
  final Stream<String> lines = args.isNotEmpty
      ? File(args.first)
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())
      : stdin.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final fx = jsonDecode(line) as Map<String, dynamic>;
    final quantized = _quantize(fx['inputs']);
    final canon = canonicalize(quantized);
    final hash = sha256.convert(utf8.encode(canon)).toString();
    stdout.writeln(jsonEncode({'id': fx['id'], 'sha256': hash}));
  }
}
