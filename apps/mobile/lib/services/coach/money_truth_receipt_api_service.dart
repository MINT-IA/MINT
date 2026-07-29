import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';
import 'package:mint_mobile/services/financial_core/money_truth_receipt.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';

/// Store du MoneyTruthReceipt — handoff /first-job -> coach (PR-E, E2).
///
/// POST idempotent du receipt vers `/api/v1/lucidity/receipts` (SPEC §4.3
/// clause 1) AVANT la navigation vers le coach, pour que le coach le RÉSOLVE
/// (chemin `resolved`) et ground sur la MÊME valeur nette. Best-effort :
/// authentifié, timeout court, JAMAIS d'exception vers l'appelant — un échec
/// ne bloque pas la navigation (le chemin `pending`, alimenté par
/// `receiptInputs` dans la requête coach, prend le relais côté backend).
class MoneyTruthReceiptApiService {
  final String baseUrl;

  MoneyTruthReceiptApiService({String? baseUrl})
      : baseUrl = baseUrl ?? ApiService.baseUrl;

  /// Client HTTP injectable (visibleForTesting) — MockClient en test pour
  /// capturer le body réellement posté.
  http.Client? testClient;

  /// Fenêtre courte : le store ne doit pas retarder la navigation coach.
  static const Duration _timeout = Duration(seconds: 4);

  /// Persiste le [receipt] de façon idempotente, scopé à l'utilisateur
  /// authentifié. Retourne `true` si le store a répondu 200, `false` sinon
  /// (pas de token, réseau/timeout, non-200) — sans jamais lever.
  Future<bool> store(MoneyTruthReceipt receipt) async {
    try {
      final token = await AuthService.getToken();
      if (token == null || token.isEmpty) {
        // Non authentifié : le coach (authentifié) ne pourrait de toute façon
        // pas résoudre une ligne scopée anonyme -> on laisse le chemin pending.
        return false;
      }
      final uri = Uri.parse('$baseUrl/lucidity/receipts');
      final headers = {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'X-App-Version': ApiService.appVersionHeaderValue,
      };
      final body = jsonEncode(<String, dynamic>{'receipt': receipt.toJson()});
      final client = testClient ?? MintHttpClient.shared;
      final response =
          await client.post(uri, headers: headers, body: body).timeout(_timeout);
      return response.statusCode == 200;
    } catch (e) {
      // Best-effort : tout échec est avalé (le handoff dégrade en pending).
      if (kDebugMode) {
        debugPrint('[MoneyTruthReceiptApi] store best-effort échoué: $e');
      }
      return false;
    }
  }
}
