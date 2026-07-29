// ────────────────────────────────────────────────────────────
//  MoneyTruthReceipt v1 — contrat de vérité chiffrée (Tranche firstJob PR-B)
//
//  Miroir Dart du modèle backend
//  `services/backend/app/models/lucidity/money_truth_receipt.py`.
//  Le receipt ENVELOPPE une valeur L1 (net firstJob, offline-capable) avec sa
//  provenance : inputs normalisés, hash déterministe, millésime, sources
//  datées, bande d'incertitude, confiance.
//
//  Parité (SPEC §4.1 / §4.4) : pour les MÊMES inputs, ce miroir produit le
//  MÊME `inputsHash` (octet pour octet) et la MÊME `value` après arrondi que
//  le producteur backend. Verrou : tools/fixtures/money_truth_receipt_v1.json
//  (rejoué par pytest ET flutter test).
//
//  `computeInputsHash` réutilise l'algorithme prouvé du harnais de parité
//  `apps/mobile/tools/hash_parity_harness/main.dart` (quantize-BEFORE-
//  canonicalize, RFC 8785, SHA256), lui-même validé octet pour octet contre
//  `app.services.coach.inputs_hash.compute_inputs_hash` par
//  `services/backend/tests/test_dag_invalidation/test_hash_parity.py`.
//
//  Interdit (extra=forbid côté backend) : tout champ de classement
//  (recommended* / best* / optimal* …). Aucun ici — cohérent NEVER #5 / LSFin.
// ────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Claim id du producteur v1 (SPEC D3 / §4.1).
const String kFirstJobNetSalaryClaimId = 'firstjob.net_salary.v1';

// ════════════════════════════════════════════════════════════
//  HASH DÉTERMINISTE DES INPUTS (miroir de compute_inputs_hash)
// ════════════════════════════════════════════════════════════

/// Quantifie récursivement les doubles à 2 décimales (ROUND_HALF_UP).
///
/// Miroir EXACT de `_quantize_floats()` (inputs_hash.py) et de `_quantize()`
/// (hash_parity_harness/main.dart). L'ordre de récursion DOIT correspondre à
/// Python sinon les hashes divergent.
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
      throw const FormatException('NaN not allowed in projection inputs');
    }
    if (!v.isFinite) {
      throw const FormatException('inf/-inf not allowed in projection inputs');
    }
    // Decimal(0.01) ROUND_HALF_UP : ×100, round-half-away-from-zero, ÷100.
    final scaled = v * 100.0;
    final rounded = scaled.roundToDouble();
    return rounded / 100.0;
  }
  return v;
}

/// JSON canonique RFC 8785 (clés triées UTF-16, sans espaces, floats entiers
/// sans `.0`). Miroir EXACT de `canonicalize()` du harnais.
String _canonicalize(dynamic v) {
  if (v is Map) {
    final keys = v.keys.cast<String>().toList()..sort();
    return '{${keys.map((k) => '${jsonEncode(k)}:${_canonicalize(v[k])}').join(',')}}';
  }
  if (v is List) {
    return '[${v.map(_canonicalize).join(',')}]';
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

/// SHA256 hex (64 car.) du JSON canonique des inputs quantifiés.
///
/// Déterministe et identique octet pour octet à
/// `compute_inputs_hash(inputs)` côté Python.
String computeInputsHash(Map<String, dynamic> inputs) {
  final quantized = _quantize(inputs);
  final canon = _canonicalize(quantized);
  return sha256.convert(utf8.encode(canon)).toString();
}

// ════════════════════════════════════════════════════════════
//  VALUE OBJECTS
// ════════════════════════════════════════════════════════════

/// Une source datée derrière la valeur (SPEC §4.1 `sources[]`).
class MoneyTruthSource {
  final String id;
  final String label;
  final int vintage;

  const MoneyTruthSource({
    required this.id,
    required this.label,
    required this.vintage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'vintage': vintage,
      };
}

/// Bande d'incertitude {low, high} (SPEC §4.1 `range`).
class MoneyTruthRange {
  final double low;
  final double high;

  const MoneyTruthRange({required this.low, required this.high});

  Map<String, dynamic> toJson() => {'low': low, 'high': high};
}

/// Résumé de confiance — MÊME forme fil que `EnhancedConfidence`
/// (confidence_scorer.dart:995 / app/schemas/enhanced_confidence.py) : 4 axes
/// [0,1] + score combiné. PAS un nouveau scorer (règle 4 / NEVER #3) : juste
/// la forme fil peuplée par le mapping déclaré PR-B.
class MoneyTruthConfidence {
  final double completeness;
  final double accuracy;
  final double freshness;
  final double understanding;
  final double score;

  const MoneyTruthConfidence({
    required this.completeness,
    required this.accuracy,
    required this.freshness,
    required this.understanding,
    required this.score,
  });

  Map<String, dynamic> toJson() => {
        'completeness': completeness,
        'accuracy': accuracy,
        'freshness': freshness,
        'understanding': understanding,
        'score': score,
      };
}

/// Contrat de vérité chiffrée v1 — enveloppe une valeur L1 + sa provenance.
///
/// Immuable (tous champs `final`). Sérialisation camelCase alignée octet sur
/// le backend Pydantic v2.
class MoneyTruthReceipt {
  final String claimId;
  final String receiptId;
  final Map<String, dynamic> inputs;
  final String inputsHash;
  final String jurisdiction;
  final int taxYear;
  final String base; // "brut" | "net"
  final String civilStatus;
  final List<String> assumptions;
  final String engine;
  final String engineVersion;
  final String rounding;
  final List<MoneyTruthSource> sources;
  final double value;
  final MoneyTruthRange? range;
  final MoneyTruthConfidence? confidence;
  final String computedAt;

  const MoneyTruthReceipt({
    required this.claimId,
    required this.receiptId,
    required this.inputs,
    required this.inputsHash,
    required this.jurisdiction,
    required this.taxYear,
    required this.base,
    required this.civilStatus,
    required this.assumptions,
    required this.engine,
    required this.engineVersion,
    required this.rounding,
    required this.sources,
    required this.value,
    required this.range,
    required this.confidence,
    required this.computedAt,
  });

  Map<String, dynamic> toJson() => {
        'claimId': claimId,
        'receiptId': receiptId,
        'inputs': inputs,
        'inputsHash': inputsHash,
        'jurisdiction': jurisdiction,
        'taxYear': taxYear,
        'base': base,
        'civilStatus': civilStatus,
        'assumptions': assumptions,
        'engine': engine,
        'engineVersion': engineVersion,
        'rounding': rounding,
        'sources': sources.map((s) => s.toJson()).toList(),
        'value': value,
        'range': range?.toJson(),
        'confidence': confidence?.toJson(),
        'computedAt': computedAt,
      };
}
