// Granular consent client — v2.7 Phase 29 / PRIV-01.
//
// Mirrors backend ConsentPurpose enum and wraps /api/v1/consents endpoints.
// Entry points that touch user data (upload, couple projection) MUST call
// `requireGrantedOrPrompt` before proceeding.
import 'package:flutter/material.dart';

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/widgets/consent/consent_sheet.dart';

enum ConsentPurpose {
  visionExtraction,
  persistence365d,
  transferUsAnthropic,
  coupleProjection,
}

extension ConsentPurposeX on ConsentPurpose {
  String get wire {
    switch (this) {
      case ConsentPurpose.visionExtraction:
        return 'vision_extraction';
      case ConsentPurpose.persistence365d:
        return 'persistence_365d';
      case ConsentPurpose.transferUsAnthropic:
        return 'transfer_us_anthropic';
      case ConsentPurpose.coupleProjection:
        return 'couple_projection';
    }
  }

  static ConsentPurpose fromWire(String raw) {
    switch (raw) {
      case 'vision_extraction':
        return ConsentPurpose.visionExtraction;
      case 'persistence_365d':
        return ConsentPurpose.persistence365d;
      case 'transfer_us_anthropic':
        return ConsentPurpose.transferUsAnthropic;
      case 'couple_projection':
        return ConsentPurpose.coupleProjection;
      default:
        throw ArgumentError('unknown consent purpose: $raw');
    }
  }
}

class ConsentReceipt {
  final String receiptId;
  final ConsentPurpose purpose;
  final String policyVersion;
  final DateTime consentTimestamp;
  final DateTime? revokedAt;

  ConsentReceipt({
    required this.receiptId,
    required this.purpose,
    required this.policyVersion,
    required this.consentTimestamp,
    this.revokedAt,
  });

  bool get isActive => revokedAt == null;

  factory ConsentReceipt.fromJson(Map<String, dynamic> j) => ConsentReceipt(
        receiptId: j['receiptId'] as String,
        purpose: ConsentPurposeX.fromWire(j['purpose'] as String),
        policyVersion: j['policyVersion'] as String,
        consentTimestamp: DateTime.parse(j['consentTimestamp'] as String),
        revokedAt: j['revokedAt'] == null
            ? null
            : DateTime.parse(j['revokedAt'] as String),
      );
}

class ConsentService {
  /// Current privacy policy version the mobile app will negotiate against.
  /// Bump this to trigger re-consent UX (policy diff view).
  static const String currentPolicyVersion = 'v2.3.0';

  static List<ConsentReceipt>? _cache;

  Future<List<ConsentReceipt>> list({bool force = false}) async {
    if (_cache != null && !force) return _cache!;
    final resp = await ApiService.get('/consents');
    final consents = (resp['consents'] as List? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(ConsentReceipt.fromJson)
        .toList();
    _cache = consents;
    return consents;
  }

  Future<ConsentReceipt> grant(ConsentPurpose purpose) async {
    final resp = await ApiService.post('/consents/grant', {
      'purpose': purpose.wire,
      'policyVersion': currentPolicyVersion,
    });
    _cache = null;
    return ConsentReceipt.fromJson(resp);
  }

  Future<Map<String, dynamic>> revoke(String receiptId) async {
    final resp =
        await ApiService.post('/consents/$receiptId/revoke', const {});
    _cache = null;
    return resp;
  }

  /// Returns true iff every purpose has an active grant at the current policy
  /// version. A grant on an older `policyVersion` counts as missing and
  /// triggers re-consent.
  bool _isGrantedNow(
      List<ConsentReceipt> consents, ConsentPurpose purpose) {
    for (final c in consents) {
      if (c.purpose == purpose &&
          c.isActive &&
          c.policyVersion == currentPolicyVersion) {
        return true;
      }
    }
    return false;
  }

  /// Entry-point guard: if any required purpose is not granted at the current
  /// policy version, show the ConsentSheet. Returns true only if all purposes
  /// are (now) granted.
  Future<bool> requireGrantedOrPrompt(
    BuildContext context,
    List<ConsentPurpose> required,
  ) async {
    final consents = await list(force: true);
    final missing = required
        .where((p) => !_isGrantedNow(consents, p))
        .toList(growable: false);
    if (missing.isEmpty) return true;

    if (!context.mounted) return false;
    final accepted = await ConsentSheet.show(context, purposes: missing);
    if (accepted != true) return false;

    for (final p in missing) {
      await grant(p);
    }
    return true;
  }
}
