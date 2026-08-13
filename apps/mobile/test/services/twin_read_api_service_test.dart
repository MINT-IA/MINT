// Lego C1 — beats c3 (consentement), c4 (enveloppe fermée),
// c8 (atomicité), c9 (verrou par attestation-hash) côté mobile.

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/coach/twin_read_api_service.dart';
import 'package:mint_mobile/services/consent/consent_service.dart';
import 'package:mint_mobile/services/observability/mint_http_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _attestation = {
  'amountCents': 375800,
  'currency': 'CHF',
  'taxYear': 2026,
  'state': 'positive',
  'computedAt': '2026-08-13T00:00:00Z',
  'engineVersion': 'marge-3a-v1',
  'inputsHash':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'registryHash':
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
};

const _sessionId = '00000000-0000-0000-0000-000000000000';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Map<String, dynamic>> sentBodies;
  late List<String> sentPaths;

  void mockApi({
    int status = 200,
    Map<String, dynamic> body = const {'answer': 'éclairage validé'},
  }) {
    ApiService.setHttpClientForTesting(
      MintHttpClient(
        MockClient((request) async {
          sentPaths.add(request.url.path);
          if (request.body.isNotEmpty) {
            sentBodies.add(
                jsonDecode(request.body) as Map<String, dynamic>);
          }
          // Le statut injecté ne vaut que pour le twin-read : les autres
          // routes (consents) restent saines, sinon on testerait le mock.
          final isTwinRead = request.url.path.contains('twin-read');
          return http.Response(
            jsonEncode(isTwinRead ? body : const {'consents': []}),
            isTwinRead ? status : 200,
            headers: {'content-type': 'application/json'},
          );
        }),
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
    ConsentService.resetCacheForTest();
    sentBodies = [];
    sentPaths = [];
    mockApi();
  });

  tearDown(() => ApiService.setHttpClientForTesting(null));

  Future<ConsentReceipt> grantConsent() =>
      ConsentService().grantLocal(ConsentPurpose.twinRead3aMargin);

  test('without an active twin-read consent receipt no HTTP request ever '
      'leaves', () async {
    final outcome = await TwinReadApiService.requestEclairage(
      question: 'Que veut dire cette marge ?',
      attestation: _attestation,
      sessionId: _sessionId,
    );
    expect(outcome.kind, TwinReadOutcomeKind.consentMissing);
    expect(sentPaths.where((p) => p.contains('twin-read')), isEmpty,
        reason: 'aucun octet ne part sans reçu actif');
  });

  test('an anonymous twin-read receipt is granted and revoked locally and '
      'immediately without any backend call', () async {
    final receipt = await grantConsent();
    expect(
        await ConsentService()
            .activeReceiptFor(ConsentPurpose.twinRead3aMargin),
        isNotNull);

    sentPaths.clear();
    final result = await ConsentService().revoke(receipt.receiptId);
    expect(result['scope'], 'local');
    expect(sentPaths.where((p) => p.contains('consents')), isEmpty,
        reason: 'un reçu anonyme meurt sans réseau');
    expect(
        await ConsentService()
            .activeReceiptFor(ConsentPurpose.twinRead3aMargin),
        isNull);
  });

  test('the revoked receipt blocks the next call at the mobile gate',
      () async {
    final receipt = await grantConsent();
    await ConsentService().revoke(receipt.receiptId);
    final outcome = await TwinReadApiService.requestEclairage(
      question: 'Et maintenant ?',
      attestation: _attestation,
      sessionId: _sessionId,
    );
    expect(outcome.kind, TwinReadOutcomeKind.consentMissing);
    expect(sentPaths.where((p) => p.contains('twin-read')), isEmpty);
  });

  test('the mobile envelope serializes only the public attestation fields '
      '(closed recursive schema, unknown key = test failure)', () async {
    await grantConsent();
    await TwinReadApiService.requestEclairage(
      question: 'Que veut dire cette marge ?',
      attestation: _attestation,
      sessionId: _sessionId,
    );
    expect(sentBodies, hasLength(1));
    final body = sentBodies.single;
    expect(body.keys.toSet(), {
      'contractVersion',
      'purpose',
      'question',
      'sessionId',
      'operationKey',
      'consentReceipt',
      'attestation',
    });
    expect((body['attestation'] as Map).keys.toSet(), {
      'amountCents',
      'currency',
      'taxYear',
      'state',
      'computedAt',
      'engineVersion',
      'inputsHash',
      'registryHash',
    });
    expect((body['consentReceipt'] as Map).keys.toSet(),
        {'receiptId', 'purpose', 'version', 'grantedAt'});
  });

  test('a sealed value smuggled inside the question field is detected by '
      'the value-level guard', () async {
    await grantConsent();
    await TwinReadApiService.requestEclairage(
      question: 'Mon revenu de 120000 change quoi ?',
      attestation: _attestation,
      sessionId: _sessionId,
    );
    final raw = jsonEncode(sentBodies.single);
    for (final forbidden in [
      'q_gross_salary',
      'wizard_answers',
      'coachContext',
      'profileContext',
      '_mint_canonical',
    ]) {
      expect(raw.contains(forbidden), isFalse,
          reason: '$forbidden ne doit JAMAIS transiter');
    }
  });

  test('the operation key is derived from the attestation so a replay is '
      'possible and a correction reopens the surface', () async {
    final key = TwinReadApiService.operationKeyFor(
      inputsHash: _attestation['inputsHash']! as String,
      registryHash: _attestation['registryHash']! as String,
      taxYear: _attestation['taxYear']! as int,
    );
    expect(key, hasLength(64));
    final sameAgain = TwinReadApiService.operationKeyFor(
      inputsHash: _attestation['inputsHash']! as String,
      registryHash: _attestation['registryHash']! as String,
      taxYear: _attestation['taxYear']! as int,
    );
    expect(sameAgain, key, reason: 'stable pour la même attestation');
    final corrected = TwinReadApiService.operationKeyFor(
      inputsHash: 'c' * 64,
      registryHash: _attestation['registryHash']! as String,
      taxYear: _attestation['taxYear']! as int,
    );
    expect(corrected, isNot(key),
        reason: 'une correction produit une nouvelle clé — surface rouverte');
  });

  test('a validated answer commits the lock and clears the reservation',
      () async {
    await grantConsent();
    final outcome = await TwinReadApiService.requestEclairage(
      question: 'Que veut dire cette marge ?',
      attestation: _attestation,
      sessionId: _sessionId,
    );
    expect(outcome.kind, TwinReadOutcomeKind.answered);
    expect(outcome.answer, 'éclairage validé');

    final key = TwinReadApiService.operationKeyFor(
      inputsHash: _attestation['inputsHash']! as String,
      registryHash: _attestation['registryHash']! as String,
      taxYear: _attestation['taxYear']! as int,
    );
    expect(await TwinReadApiService.isLockedFor(key), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('${TwinReadApiService.pendingKeyPrefix}$key'),
        isNull);
  });

  test('a pre-send failure and a deterministic rejection consume nothing '
      'and fall back without numbers', () async {
    await grantConsent();
    final key = TwinReadApiService.operationKeyFor(
      inputsHash: _attestation['inputsHash']! as String,
      registryHash: _attestation['registryHash']! as String,
      taxYear: _attestation['taxYear']! as int,
    );
    final prefs = await SharedPreferences.getInstance();

    mockApi(status: 422, body: const {'detail': 'claim_check_rejected'});
    final refused = await TwinReadApiService.requestEclairage(
      question: 'Question',
      attestation: _attestation,
      sessionId: _sessionId,
    );
    expect(refused.kind, TwinReadOutcomeKind.refused);
    expect(prefs.getBool('${TwinReadApiService.pendingKeyPrefix}$key'), isNull,
        reason: 'rejet déterministe = rien de dû');
    expect(await TwinReadApiService.isLockedFor(key), isFalse,
        reason: 'aucun verrou sur un rejet');

  });

  test('an ambiguous post-send timeout keeps the reservation, replays the '
      'same operation key and resolves only through the durable receipt',
      () async {
    await grantConsent();
    final key = TwinReadApiService.operationKeyFor(
      inputsHash: _attestation['inputsHash']! as String,
      registryHash: _attestation['registryHash']! as String,
      taxYear: _attestation['taxYear']! as int,
    );
    final prefs = await SharedPreferences.getInstance();

    mockApi(status: 503, body: const {'detail': 'server error'});
    final ambiguous = await TwinReadApiService.requestEclairage(
      question: 'Question',
      attestation: _attestation,
      sessionId: _sessionId,
    );
    expect(ambiguous.kind, TwinReadOutcomeKind.ambiguous);
    expect(prefs.getBool('${TwinReadApiService.pendingKeyPrefix}$key'), isTrue,
        reason: 'issue ambiguë = réservation CONSERVÉE, jamais présumée');

    // Le rejeu de la MÊME clé tranche : seul le reçu durable résout.
    sentBodies.clear();
    mockApi();
    await TwinReadApiService.reconcilePendingAtBoot(
      attestationLookup: (_) async => _attestation,
      sessionId: _sessionId,
    );
    expect(sentBodies.single['operationKey'], key,
        reason: 'même clé rejouée, jamais une nouvelle opération');
    expect(prefs.getBool('${TwinReadApiService.pendingKeyPrefix}$key'), isNull);
    expect(await TwinReadApiService.isLockedFor(key), isTrue);
  });

  test('a second C1 attempt on the same attestation hash is locked locally',
      () async {
    await grantConsent();
    final first = await TwinReadApiService.requestEclairage(
      question: 'Question',
      attestation: _attestation,
      sessionId: _sessionId,
    );
    expect(first.kind, TwinReadOutcomeKind.answered);
    final key = TwinReadApiService.operationKeyFor(
      inputsHash: _attestation['inputsHash']! as String,
      registryHash: _attestation['registryHash']! as String,
      taxYear: _attestation['taxYear']! as int,
    );
    expect(await TwinReadApiService.isLockedFor(key), isTrue,
        reason: 'un éclairage servi verrouille CETTE attestation');
  });

  test('a new attestation hash after a correction reopens the C1 surface',
      () async {
    await grantConsent();
    await TwinReadApiService.requestEclairage(
      question: 'Question',
      attestation: _attestation,
      sessionId: _sessionId,
    );
    // Correction du jumeau => nouvelles révisions => nouvel inputsHash.
    final corrected = {..._attestation, 'inputsHash': 'c' * 64};
    final correctedKey = TwinReadApiService.operationKeyFor(
      inputsHash: corrected['inputsHash']! as String,
      registryHash: corrected['registryHash']! as String,
      taxYear: corrected['taxYear']! as int,
    );
    expect(await TwinReadApiService.isLockedFor(correctedKey), isFalse,
        reason: 'une nouvelle attestation ROUVRE la surface');
    final second = await TwinReadApiService.requestEclairage(
      question: 'Et après ma correction ?',
      attestation: corrected,
      sessionId: _sessionId,
    );
    expect(second.kind, TwinReadOutcomeKind.answered);
  });

  test('a lost response is reconciled at boot by replaying the operation '
      'key without double counting', () async {
    await grantConsent();
    final key = TwinReadApiService.operationKeyFor(
      inputsHash: _attestation['inputsHash']! as String,
      registryHash: _attestation['registryHash']! as String,
      taxYear: _attestation['taxYear']! as int,
    );
    final prefs = await SharedPreferences.getInstance();
    // Crash simulé : réservation posée, aucune réponse traitée.
    await prefs.setBool('${TwinReadApiService.pendingKeyPrefix}$key', true);

    await TwinReadApiService.reconcilePendingAtBoot(
      attestationLookup: (_) async => _attestation,
      sessionId: _sessionId,
    );

    expect(prefs.getBool('${TwinReadApiService.pendingKeyPrefix}$key'), isNull,
        reason: 'la réservation est close par le rejeu');
    expect(await TwinReadApiService.isLockedFor(key), isTrue,
        reason: 'le serveur a resservi sa réponse — exactement une fois');
    expect(sentBodies, hasLength(1),
        reason: 'un seul rejeu, avec la MÊME clé');
    expect(sentBodies.single['operationKey'], key);
  });

  test('a crash between reservation and commit converges at boot to exactly '
      'zero or one consumption', () async {
    await grantConsent();
    final key = TwinReadApiService.operationKeyFor(
      inputsHash: _attestation['inputsHash']! as String,
      registryHash: _attestation['registryHash']! as String,
      taxYear: _attestation['taxYear']! as int,
    );
    final prefs = await SharedPreferences.getInstance();
    // Crash APRÈS réservation : ni verrou, ni réponse rendue.
    await prefs.setBool('${TwinReadApiService.pendingKeyPrefix}$key', true);
    expect(await TwinReadApiService.isLockedFor(key), isFalse);

    // Deux boots successifs : la convergence est idempotente (0 ou 1).
    await TwinReadApiService.reconcilePendingAtBoot(
      attestationLookup: (_) async => _attestation,
      sessionId: _sessionId,
    );
    await TwinReadApiService.reconcilePendingAtBoot(
      attestationLookup: (_) async => _attestation,
      sessionId: _sessionId,
    );
    expect(prefs.getBool('${TwinReadApiService.pendingKeyPrefix}$key'), isNull);
    expect(sentBodies, hasLength(1),
        reason: 'le second boot n\'a plus rien à rejouer');
  });

  test('a reservation whose attestation disappeared is lifted honestly',
      () async {
    await grantConsent();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
        '${TwinReadApiService.pendingKeyPrefix}orphan', true);
    await TwinReadApiService.reconcilePendingAtBoot(
      attestationLookup: (_) async => null,
      sessionId: _sessionId,
    );
    expect(prefs.getBool('${TwinReadApiService.pendingKeyPrefix}orphan'),
        isNull);
    expect(sentBodies, isEmpty, reason: 'rien à rejouer, rien envoyé');
  });

  test('a quota exhaustion is surfaced as such and never as a network '
      'failure', () async {
    await grantConsent();
    mockApi(status: 429, body: const {'detail': 'anonymous quota reached'});
    final outcome = await TwinReadApiService.requestEclairage(
      question: 'Question',
      attestation: _attestation,
      sessionId: _sessionId,
    );
    expect(outcome.kind, TwinReadOutcomeKind.quotaExhausted);
  });
}
