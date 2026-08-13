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
      '(closed schema, unknown key = test failure)', () async {
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

  test('no sealed value or legacy context can appear anywhere in the body',
      () async {
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

  test('a deterministic rejection clears the reservation and consumes '
      'nothing while an ambiguous failure keeps it replayable', () async {
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

    mockApi(status: 503, body: const {'detail': 'server error'});
    final ambiguous = await TwinReadApiService.requestEclairage(
      question: 'Question',
      attestation: _attestation,
      sessionId: _sessionId,
    );
    expect(ambiguous.kind, TwinReadOutcomeKind.ambiguous);
    expect(prefs.getBool('${TwinReadApiService.pendingKeyPrefix}$key'), isTrue,
        reason: 'issue ambiguë = réservation CONSERVÉE, rejouable');
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
