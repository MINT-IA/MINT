// Lego C1 — client twin-read : enveloppe FERMÉE + réservation/commit.
//
// Contrat : product/mint_next/storyboard/coach_twin_read_3a.storyboard.json.
// Rien d'autre que l'attestation publique et son reçu de consentement ne
// quitte l'appareil. Aucun appel sans reçu actif. La clé d'opération est
// dérivée de l'attestation : un timeout post-envoi se rejoue, il ne se
// devine pas.

import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/financial_core/mint_next_marge_3a_calculator.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Issue d'un éclairage — le rendu ne montre JAMAIS un chiffre sans
/// [TwinReadOutcome.answer] validée par le serveur.
class TwinReadOutcome {
  const TwinReadOutcome({
    required this.kind,
    this.answer,
    this.taxYear,
    this.computedAt,
  });

  final TwinReadOutcomeKind kind;
  final String? answer;
  final int? taxYear;
  final String? computedAt;
}

enum TwinReadOutcomeKind {
  /// Réponse validée, affichable.
  answered,

  /// Rejet déterministe (claim-checker, schéma) — copie sûre sans chiffre.
  refused,

  /// Issue AMBIGUË (réseau/timeout/5xx) — l'état reste dû, rejouable.
  ambiguous,

  /// Quota épuisé.
  quotaExhausted,

  /// Pas de consentement actif — aucun octet n'est parti.
  consentMissing,
}

class TwinReadApiService {
  const TwinReadApiService._();

  static const String pendingKeyPrefix = 'mint_twin_read_pending_v1_';
  static const String lockKeyPrefix = 'mint_twin_read_done_v1_';

  /// Clé d'opération = dérivation de l'attestation (mêmes composantes que
  /// le serveur, qui la RECALCULE et rejette toute clé forgée).
  static String operationKeyFor({
    required String inputsHash,
    required String registryHash,
    required int taxYear,
  }) =>
      sha256
          .convert(utf8.encode('$inputsHash$registryHash$taxYear'))
          .toString();

  /// L'attestation n'existe QUE sur un résultat disponible et signé.
  static Map<String, dynamic>? attestationFrom(
    MintNextMarge3aResult result, {
    required String inputsHash,
    required String computedAt,
  }) {
    if (result.status != MintNextMarge3aStatus.available) return null;
    final marge = result.margeCents;
    final registryHash = result.constantsVersionHash;
    if (marge == null || registryHash == null) return null;
    return {
      'amountCents': marge < 0 ? 0 : marge,
      'currency': 'CHF',
      'taxYear': result.taxYear,
      'state': marge > 0 ? 'positive' : 'zero',
      'computedAt': computedAt,
      'engineVersion': 'marge-3a-v1',
      'inputsHash': inputsHash,
      'registryHash': registryHash,
    };
  }

  /// Un éclairage est-il déjà servi pour CETTE attestation ? (verrou par
  /// attestation-hash : une correction rouvre la surface.)
  static Future<bool> isLockedFor(String operationKey) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('$lockKeyPrefix$operationKey') == true;
  }

  /// Demande l'éclairage. Aucun octet ne part sans reçu de consentement
  /// actif ; la réservation durable précède l'appel.
  static Future<TwinReadOutcome> requestEclairage({
    required String question,
    required Map<String, dynamic> attestation,
    required String sessionId,
  }) async {
    final receipt = await ConsentService()
        .activeReceiptFor(ConsentPurpose.twinRead3aMargin);
    if (receipt == null) {
      return const TwinReadOutcome(kind: TwinReadOutcomeKind.consentMissing);
    }

    final operationKey = operationKeyFor(
      inputsHash: attestation['inputsHash'] as String,
      registryHash: attestation['registryHash'] as String,
      taxYear: attestation['taxYear'] as int,
    );
    final prefs = await SharedPreferences.getInstance();
    // Réservation DURABLE avant l'appel : un crash ou une réponse perdue
    // laisse une trace rejouable, jamais un état inventé.
    await prefs.setBool('$pendingKeyPrefix$operationKey', true);

    try {
      final response = await ApiService.post(
        '/coach/twin-read/3a-margin',
        {
          'contractVersion': 1,
          'purpose': 'explain_attested_3a_margin',
          'question': question,
          'sessionId': sessionId,
          'operationKey': operationKey,
          'consentReceipt': {
            'receiptId': receipt.receiptId,
            'purpose': 'twin_read_3a_margin',
            'version': 1,
            'grantedAt': receipt.consentTimestamp.toUtc().toIso8601String(),
          },
          'attestation': attestation,
        },
      );
      final answer = response['answer'] as String?;
      if (answer == null || answer.isEmpty) {
        return const TwinReadOutcome(kind: TwinReadOutcomeKind.refused);
      }
      // Commit : verrou posé, réservation levée.
      await prefs.setBool('$lockKeyPrefix$operationKey', true);
      await prefs.remove('$pendingKeyPrefix$operationKey');
      return TwinReadOutcome(
        kind: TwinReadOutcomeKind.answered,
        answer: answer,
        taxYear: attestation['taxYear'] as int?,
        computedAt: attestation['computedAt'] as String?,
      );
    } on ApiException catch (e) {
      // Rejet DÉTERMINISTE (422/429) : rien n'est dû, la réservation part.
      if (e.statusCode == 422 || e.statusCode == 429) {
        await prefs.remove('$pendingKeyPrefix$operationKey');
        return TwinReadOutcome(
          kind: e.statusCode == 429
              ? TwinReadOutcomeKind.quotaExhausted
              : TwinReadOutcomeKind.refused,
        );
      }
      // Issue AMBIGUË : la réservation RESTE — le rejeu de la même clé
      // tranchera (le serveur ressert sa réponse sans re-consommer).
      return const TwinReadOutcome(kind: TwinReadOutcomeKind.ambiguous);
    } catch (_) {
      return const TwinReadOutcome(kind: TwinReadOutcomeKind.ambiguous);
    }
  }
}
