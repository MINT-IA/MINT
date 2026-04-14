// ThirdPartyFlow — 428 handler + declaration grant + retry orchestration.
//
// v2.7 Phase 29 / PRIV-02.
//
// Backend emits HTTP 428 { code, subjectNames, docHash, declarationEndpoint }
// when a third-party name was detected and no fresh declaration exists.
// This service:
//   1. Parses the 428 payload.
//   2. Shows ThirdPartyDeclarationSheet.
//   3. On accept → POSTs /consents/grant-nominative and returns
//      GrantOutcome.granted so the caller retries its original request.
//   4. On cancel → returns GrantOutcome.cancelled; caller aborts.
//
// Invite intent is a log-only stub; real async SMS/email flow deferred.

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/widgets/document/third_party_declaration_sheet.dart';

enum GrantOutcome { granted, cancelled, failed }

class ThirdPartyGate428 {
  final List<String> subjectNames;
  final String docHash;
  final String declarationEndpoint;

  ThirdPartyGate428({
    required this.subjectNames,
    required this.docHash,
    required this.declarationEndpoint,
  });

  static ThirdPartyGate428? tryParse(dynamic body) {
    try {
      // FastAPI returns {"detail": {...}} for HTTPException with dict detail.
      final detail = (body is Map && body['detail'] is Map)
          ? body['detail'] as Map
          : (body is Map ? body : const {});
      if (detail['code'] != 'third_party_declaration_required') return null;
      final names = (detail['subjectNames'] as List? ?? const [])
          .whereType<String>()
          .toList(growable: false);
      final docHash = detail['docHash'] as String? ?? '';
      final endpoint = detail['declarationEndpoint'] as String? ??
          '/consents/grant-nominative';
      if (names.isEmpty || docHash.isEmpty) return null;
      return ThirdPartyGate428(
        subjectNames: names,
        docHash: docHash,
        declarationEndpoint: endpoint,
      );
    } catch (_) {
      return null;
    }
  }
}

typedef AnalyticsLogger = void Function(String event, Map<String, dynamic> props);

class ThirdPartyFlow {
  /// Optional API override used by tests. Defaults to the real ApiService.
  final Future<Map<String, dynamic>> Function(
      String endpoint, Map<String, dynamic> body)? postOverride;

  /// Optional analytics sink; defaults to debugPrint.
  final AnalyticsLogger? analytics;

  ThirdPartyFlow({this.postOverride, this.analytics});

  Future<Map<String, dynamic>> _post(
      String endpoint, Map<String, dynamic> body) {
    if (postOverride != null) return postOverride!(endpoint, body);
    return ApiService.post(endpoint, body);
  }

  void _log(String event, Map<String, dynamic> props) {
    if (analytics != null) {
      analytics!(event, props);
    } else if (kDebugMode) {
      debugPrint('[analytics] $event ${props.toString()}');
    }
  }

  /// Show the declaration sheet, grant the receipt on accept, and return an
  /// outcome for the caller.
  Future<GrantOutcome> handleGate(
    BuildContext context,
    ThirdPartyGate428 gate,
  ) async {
    final choice = await ThirdPartyDeclarationSheet.show(
      context,
      subjectNames: gate.subjectNames,
      onInviteIntent: () {
        // Log intent only — real invite flow deferred post-v2.7.
        _log('third_party_invite_intent', {
          'subject_count': gate.subjectNames.length,
        });
      },
    );
    if (choice != ThirdPartyDeclarationChoice.confirmed) {
      _log('third_party_declaration_cancelled', {
        'subject_count': gate.subjectNames.length,
      });
      return GrantOutcome.cancelled;
    }

    try {
      for (final name in gate.subjectNames) {
        await _post(gate.declarationEndpoint, {
          'subjectName': name,
          'docHash': gate.docHash,
          'subjectRole': 'declared_other',
          'policyVersion': 'v2.3.0',
        });
      }
      _log('third_party_declaration_granted', {
        'subject_count': gate.subjectNames.length,
      });
      return GrantOutcome.granted;
    } catch (exc, st) {
      debugPrint('ThirdPartyFlow: grant failed $exc\n$st');
      return GrantOutcome.failed;
    }
  }
}
