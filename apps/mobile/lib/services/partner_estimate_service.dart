/// Partner estimate storage — SecureStorage only, NEVER sent to backend.
///
/// COUP-04: Partner data is private by architecture. Stored in
/// FlutterSecureStorage (Keychain/EncryptedSharedPreferences).
/// Backend never sees actual values — only aggregate flags
/// (partner_declared, partner_confidence) via CoachContext.
library;

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Local-only model for partner financial estimates.
///
/// All fields are optional — the user fills them progressively
/// via coach conversation (COUP-02 gap questions).
class PartnerEstimate {
  final double? estimatedSalary; // Annual gross CHF
  final int? estimatedAge;
  final double? estimatedLpp; // LPP assets CHF
  final double? estimated3a; // 3a capital CHF
  final String? estimatedCanton; // 2-letter code

  const PartnerEstimate({
    this.estimatedSalary,
    this.estimatedAge,
    this.estimatedLpp,
    this.estimated3a,
    this.estimatedCanton,
  });

  /// Number of non-null fields (0-5).
  int get filledCount => [
        estimatedSalary,
        estimatedAge,
        estimatedLpp,
        estimated3a,
        estimatedCanton,
      ].where((v) => v != null).length;

  /// Confidence multiplier: estimated data = 0.25 base, scaled by completeness.
  /// 0 fields = 0.0, 5 fields = 0.25.
  double get confidence => filledCount == 0 ? 0.0 : 0.25 * (filledCount / 5);

  /// Whether partner has been declared (at least 1 field).
  bool get isDeclared => filledCount > 0;

  /// Fields that are still null (gap detection for COUP-02).
  List<String> get missingFields {
    final gaps = <String>[];
    if (estimatedSalary == null) gaps.add('estimated_salary');
    if (estimatedAge == null) gaps.add('estimated_age');
    if (estimatedLpp == null) gaps.add('estimated_lpp');
    if (estimated3a == null) gaps.add('estimated_3a');
    if (estimatedCanton == null) gaps.add('estimated_canton');
    return gaps;
  }

  factory PartnerEstimate.fromJson(Map<String, dynamic> json) =>
      PartnerEstimate(
        estimatedSalary: (json['estimated_salary'] as num?)?.toDouble(),
        estimatedAge: json['estimated_age'] as int?,
        estimatedLpp: (json['estimated_lpp'] as num?)?.toDouble(),
        estimated3a: (json['estimated_3a'] as num?)?.toDouble(),
        estimatedCanton: json['estimated_canton'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (estimatedSalary != null) 'estimated_salary': estimatedSalary,
        if (estimatedAge != null) 'estimated_age': estimatedAge,
        if (estimatedLpp != null) 'estimated_lpp': estimatedLpp,
        if (estimated3a != null) 'estimated_3a': estimated3a,
        if (estimatedCanton != null) 'estimated_canton': estimatedCanton,
      };

  PartnerEstimate copyWith({
    double? estimatedSalary,
    int? estimatedAge,
    double? estimatedLpp,
    double? estimated3a,
    String? estimatedCanton,
  }) =>
      PartnerEstimate(
        estimatedSalary: estimatedSalary ?? this.estimatedSalary,
        estimatedAge: estimatedAge ?? this.estimatedAge,
        estimatedLpp: estimatedLpp ?? this.estimatedLpp,
        estimated3a: estimated3a ?? this.estimated3a,
        estimatedCanton: estimatedCanton ?? this.estimatedCanton,
      );
}

/// CRUD service for [PartnerEstimate] using FlutterSecureStorage.
///
/// COUP-04: Data stays on-device. Only aggregate flags
/// ([aggregateForCoachContext]) are sent to the backend.
class PartnerEstimateService {
  static const _storageKey = 'mint_partner_estimate';
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  /// Load partner estimate from SecureStorage.
  static Future<PartnerEstimate?> load() async {
    final raw = await _storage.read(key: _storageKey);
    if (raw == null) return null;
    try {
      return PartnerEstimate.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
    } catch (_) {
      return null;
    }
  }

  /// Save partner estimate to SecureStorage.
  static Future<void> save(PartnerEstimate estimate) async {
    await _storage.write(
      key: _storageKey,
      value: jsonEncode(estimate.toJson()),
    );
  }

  /// Update specific fields (merge with existing).
  static Future<PartnerEstimate> update(Map<String, dynamic> fields) async {
    final existing = await load() ?? const PartnerEstimate();
    final updated = existing.copyWith(
      estimatedSalary: fields['estimated_salary'] != null
          ? (fields['estimated_salary'] as num).toDouble()
          : null,
      estimatedAge: fields['estimated_age'] as int?,
      estimatedLpp: fields['estimated_lpp'] != null
          ? (fields['estimated_lpp'] as num).toDouble()
          : null,
      estimated3a: fields['estimated_3a'] != null
          ? (fields['estimated_3a'] as num).toDouble()
          : null,
      estimatedCanton: fields['estimated_canton'] as String?,
    );
    await save(updated);
    return updated;
  }

  /// Delete all partner data.
  static Future<void> clear() async {
    await _storage.delete(key: _storageKey);
  }

  /// Aggregate flags for CoachContext (COUP-04: only these go to backend).
  static Future<Map<String, dynamic>> aggregateForCoachContext() async {
    final estimate = await load();
    return {
      'partner_declared': estimate?.isDeclared ?? false,
      'partner_confidence': estimate?.confidence ?? 0.0,
    };
  }
}
