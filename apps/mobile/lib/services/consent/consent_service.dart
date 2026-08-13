// Granular consent client — v2.7 Phase 29 / PRIV-01.
//
// Mirrors backend ConsentPurpose enum and wraps /api/v1/consents endpoints.
// Entry points that touch user data (upload, couple projection) MUST call
// `requireGrantedOrPrompt` before proceeding.
//
// Local-mode fallback (P4 fix, walkthrough 2026-05-07): when the user is in
// « Continuer en mode local » (no auth session), the backend `/consents`
// endpoint returns 401. Instead of blocking the whole feature behind a stale
// snackbar, we mirror the receipt list to a SharedPreferences-backed
// `_LocalConsentStore` so the user can grant/revoke consent on-device.
// The backend remains source-of-truth when authenticated; local store is a
// disjoint additive set with the same `ConsentReceipt` JSON shape.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/widgets/consent/consent_sheet.dart';

enum ConsentPurpose {
  visionExtraction,
  persistence365d,
  transferUsAnthropic,
  coupleProjection,

  /// Lego C1 — lecture par le coach de l'attestation de marge 3a
  /// (enveloppe fermée, aucun fait scellé). Reçu LOCAL pour un anonyme :
  /// accordé et révoqué sur l'appareil, sans backend.
  twinRead3aMargin,
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
      case ConsentPurpose.twinRead3aMargin:
        return 'twin_read_3a_margin';
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
      case 'twin_read_3a_margin':
        return ConsentPurpose.twinRead3aMargin;
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

  Map<String, dynamic> toJson() => {
        'receiptId': receiptId,
        'purpose': purpose.wire,
        'policyVersion': policyVersion,
        'consentTimestamp': consentTimestamp.toIso8601String(),
        if (revokedAt != null) 'revokedAt': revokedAt!.toIso8601String(),
      };
}

/// On-device consent storage used as a fallback when the user is in
/// « Continuer en mode local » (no auth session) and the backend
/// `/consents` endpoint is unreachable. Same JSON shape as the backend
/// receipt so a single `ConsentReceipt.fromJson` deserializer works for
/// both sources.
///
/// `@visibleForTesting` so the local-fallback contract can be unit-tested
/// without needing an HTTP mock (the test asserts that grant() persists +
/// load() round-trips, which is the contract surface that mode local
/// depends on).
@visibleForTesting
class LocalConsentStoreForTests {
  static Future<List<ConsentReceipt>> load() => _LocalConsentStore().load();
  static Future<ConsentReceipt> grant(ConsentPurpose p) =>
      _LocalConsentStore().grant(p);
  static Future<void> clear() => _LocalConsentStore().clear();
}

class _LocalConsentStore {
  static const String _prefsKey = 'mint.consent.local_receipts.v1';

  Future<List<ConsentReceipt>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(ConsentReceipt.fromJson)
          .toList(growable: false);
    } on FormatException catch (_) {
      // Corrupt blob — clear it and start fresh. Better to re-prompt the
      // user once than refuse all flows forever.
      await prefs.remove(_prefsKey);
      return const [];
    }
  }

  Future<ConsentReceipt> grant(ConsentPurpose purpose) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load();
    final receipt = ConsentReceipt(
      receiptId: 'local-${DateTime.now().microsecondsSinceEpoch}',
      purpose: purpose,
      policyVersion: ConsentService.currentPolicyVersion,
      consentTimestamp: DateTime.now().toUtc(),
    );
    // Replace any stale receipt for the same purpose.
    final next = [
      ...existing.where((c) => c.purpose != purpose),
      receipt,
    ];
    await prefs.setString(
      _prefsKey,
      jsonEncode(next.map((c) => c.toJson()).toList(growable: false)),
    );
    return receipt;
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Révocation LOCALE d'un reçu de cet appareil — un reçu anonyme n'a
  /// pas d'existence serveur : il doit pouvoir mourir sans réseau.
  Future<bool> revokeLocal(String receiptId) async {
    final prefs = await SharedPreferences.getInstance();
    final existing = await load();
    final next = existing.where((c) => c.receiptId != receiptId).toList();
    if (next.length == existing.length) return false;
    await prefs.setString(
      _prefsKey,
      jsonEncode(next.map((c) => c.toJson()).toList(growable: false)),
    );
    return true;
  }
}

class ConsentService {
  /// Current privacy policy version the mobile app will negotiate against.
  /// Bump this to trigger re-consent UX (policy diff view).
  static const String currentPolicyVersion = 'v2.4.0';

  static List<ConsentReceipt>? _cache;
  static final _LocalConsentStore _localStore = _LocalConsentStore();

  /// Returns the union of backend receipts + local receipts. In mode local
  /// (no auth) the backend call fails with `ApiException.sessionExpired` —
  /// we then return the local-only receipts so the user can still grant /
  /// be considered granted on-device.
  Future<List<ConsentReceipt>> list({bool force = false}) async {
    if (_cache != null && !force) return _cache!;
    final local = await _localStore.load();
    try {
      final resp = await ApiService.get('/consents');
      final remote = (resp['consents'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ConsentReceipt.fromJson)
          .toList();
      // Merge: remote wins per-purpose if both have a non-revoked grant at
      // the current policy version (server is source-of-truth when
      // authenticated). Local-only purposes (granted while in mode local
      // before logging in) survive.
      final merged = <ConsentReceipt>[
        ...remote,
        ...local.where((l) => !remote.any((r) => r.purpose == l.purpose)),
      ];
      _cache = merged;
      return merged;
    } on ApiException catch (e) {
      if (_isAuthlessApiError(e)) {
        _cache = local;
        return local;
      }
      rethrow;
    } on PlatformException catch (e) {
      // `_authHeaders` reads the auth token from Keychain. On a fresh
      // simulator (or any device where the user has never logged in),
      // the Keychain item is absent and the platform channel raises
      // `PlatformException(code: -34018, ...)` BEFORE the HTTP call ever
      // happens. Other services that hit `_authHeaders` (RegulatorySync,
      // Snapshot loader) already fall back gracefully on this error;
      // ConsentService now does the same — treat as authless and use the
      // on-device store.
      if (_isAuthlessPlatformError(e)) {
        _cache = local;
        return local;
      }
      rethrow;
    }
  }

  /// Grant consent. Prefers backend storage; on auth-less / network failure
  /// falls back to on-device storage so the user can still proceed in mode
  /// local.
  Future<ConsentReceipt> grant(ConsentPurpose purpose) async {
    try {
      final resp = await ApiService.post('/consents/grant', {
        'purpose': purpose.wire,
        'policyVersion': currentPolicyVersion,
      });
      _cache = null;
      return ConsentReceipt.fromJson(resp);
    } on ApiException catch (e) {
      if (_isAuthlessApiError(e)) {
        final local = await _localStore.grant(purpose);
        _cache = null;
        return local;
      }
      rethrow;
    } on PlatformException catch (e) {
      if (_isAuthlessPlatformError(e)) {
        final local = await _localStore.grant(purpose);
        _cache = null;
        return local;
      }
      rethrow;
    }
  }

  /// True if the ApiException indicates the user has no usable auth session
  /// (mode local) — distinct from a transient network failure where we'd
  /// rather surface the error to the user.
  bool _isAuthlessApiError(ApiException e) {
    return e.errorCode == ApiErrorCode.sessionExpired || e.statusCode == 401;
  }

  /// True if the PlatformException indicates the device has no Keychain
  /// entry (fresh sim / never-logged-in user). The relevant codes are
  /// produced by `flutter_secure_storage` / iOS SecItemCopyMatching:
  ///   -25300 errSecItemNotFound  — no token stored
  ///   -34018 errSecMissingEntitlement — keychain access blocked
  /// Both are equivalent for our purpose: there is no auth context.
  bool _isAuthlessPlatformError(PlatformException e) {
    final code = e.code;
    if (code == '-25300' ||
        code == '-34018' ||
        code == 'Unexpected security result code') {
      return true;
    }
    // Some impls bury the OSStatus in the message field instead of code.
    final msg = e.message ?? '';
    return msg.contains('-25300') ||
        msg.contains('-34018') ||
        msg.contains('errSecItemNotFound') ||
        msg.contains('errSecMissingEntitlement');
  }

  Future<Map<String, dynamic>> revoke(String receiptId) async {
    // Reçu LOCAL (anonyme) : il n'existe pas côté serveur — le révoquer
    // sur l'appareil est la révocation complète, sans réseau.
    if (await _localStore.revokeLocal(receiptId)) {
      _cache = null;
      return const {'revoked': true, 'scope': 'local'};
    }
    final resp =
        await ApiService.post('/consents/$receiptId/revoke', const {});
    _cache = null;
    return resp;
  }

  /// Reçu ACTIF pour ce purpose à la version de politique courante, ou
  /// null — gate local du Lego C1 (aucun HTTP sans reçu).
  Future<ConsentReceipt?> activeReceiptFor(ConsentPurpose purpose) async {
    final consents = await list();
    for (final c in consents) {
      if (c.purpose == purpose &&
          c.isActive &&
          c.policyVersion == currentPolicyVersion) {
        return c;
      }
    }
    return null;
  }

  /// Accord LOCAL (anonyme) du purpose twin-read.
  Future<ConsentReceipt> grantLocal(ConsentPurpose purpose) async {
    final receipt = await _localStore.grant(purpose);
    _cache = null;
    return receipt;
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
  ///
  /// Crash-safety (Sentry fatal `6f9002...` 2026-05-04 ch.mint.app@2.9.0+37):
  /// when `list(force: true)` hit a 401 → `ApiException.sessionExpired` →
  /// uncaught propagation through `_onGalleryPressed` → fatal via
  /// `PlatformDispatcher.onError`. We catch any `ApiException` from
  /// list/grant calls, surface a friendly snackbar for transient errors, and
  /// return `false` for non-recoverable cases.
  ///
  /// Mode local fallback (P4 fix, walkthrough 2026-05-07): `list()` and
  /// `grant()` now route through `_LocalConsentStore` when the user has no
  /// auth session, so this guard works the same in mode local as in
  /// authenticated mode — sheet shows, user accepts, receipt is persisted
  /// on-device. No silent failure on « Depuis la galerie » in mode local.
  /// The catch below remains for true network/server errors only.
  /// Seam de test du flux sheet+grant (beads MINT_nosync-tcr) : permet aux
  /// tests d'écran de simuler acceptation/refus sans pomper la vraie
  /// ConsentSheet ni le réseau. Jamais utilisé en production.
  @visibleForTesting
  static Future<bool> Function(
    BuildContext context,
    List<ConsentPurpose> required,
  )? promptOverrideForTests;

  Future<bool> requireGrantedOrPrompt(
    BuildContext context,
    List<ConsentPurpose> required,
  ) async {
    final override = promptOverrideForTests;
    if (override != null) return override(context, required);
    final List<ConsentReceipt> consents;
    try {
      consents = await list(force: true);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.errorCode == ApiErrorCode.sessionExpired
                ? 'Session expirée. Reconnecte-toi pour continuer.'
                : 'Connexion indisponible. Réessaie dans un instant.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }
    final missing = required
        .where((p) => !_isGrantedNow(consents, p))
        .toList(growable: false);
    if (missing.isEmpty) return true;

    if (!context.mounted) return false;
    final accepted = await ConsentSheet.show(context, purposes: missing);
    if (accepted != true) return false;

    try {
      for (final p in missing) {
        await grant(p);
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.errorCode == ApiErrorCode.sessionExpired
                ? 'Session expirée pendant l’enregistrement. Reconnecte-toi.'
                : 'Impossible d’enregistrer le consentement maintenant.'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return false;
    }
    return true;
  }
}
