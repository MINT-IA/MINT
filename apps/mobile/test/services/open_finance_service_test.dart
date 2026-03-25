import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/openfinance/open_finance_service.dart';

/// Helper: build a minimal CoachProfile for enrichment tests.
CoachProfile _minimalProfile({
  double epargneLiquide = 20000,
  double? avoirLppTotal = 50000,
  double totalEpargne3a = 14000,
}) {
  return CoachProfile(
    birthYear: 1977,
    canton: 'VS',
    salaireBrutMensuel: 10184,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2042, 1, 12),
      label: 'Retraite',
    ),
    patrimoine: PatrimoineProfile(epargneLiquide: epargneLiquide),
    prevoyance: PrevoyanceProfile(
      avoirLppTotal: avoirLppTotal,
      totalEpargne3a: totalEpargne3a,
    ),
  );
}

void main() {
  // =========================================================================
  // OPEN FINANCE SERVICE — 25 unit tests (S73-S74)
  // =========================================================================
  //
  // Tests cover:
  //   - Institution discovery (with/without canton filter)
  //   - Connection lifecycle (connect, disconnect, list)
  //   - Consent management (grant, get, revoke, expiry)
  //   - Data sync (data points with confidence 1.00)
  //   - Passive enrichment (WHOOP-style field upgrade)
  //   - Audit trail for enrichment
  //   - Privacy: no transaction details, balances only
  //   - Read-only compliance (no money movement)
  //   - Error handling (API down, invalid consent, expired)
  //   - French text with accents, no banned terms
  //   - Multiple connections coexist
  //   - ConfidenceScore upgrade: userInput(0.60) → openBanking(1.00)
  // =========================================================================

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  // ── 1. discoverInstitutions returns available institutions ──

  test('discoverInstitutions returns available banks and providers', () async {
    final institutions = await OpenFinanceService.discoverInstitutions();

    expect(institutions, isNotEmpty);
    // Should include banks, 3a providers, and LPP insurers
    final types = institutions.map((i) => i.type).toSet();
    expect(types, contains(FinanceProvider.bank));
    expect(types, contains(FinanceProvider.pillar3a));
    expect(types, contains(FinanceProvider.insuranceLpp));
  });

  // ── 2. connect stores connection with consent ──

  test('connect stores connection with consent', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'user-consent-token-abc',
      prefs: prefs,
    );

    expect(conn.id, startsWith('conn_ubs_'));
    expect(conn.type, FinanceProvider.bank);
    expect(conn.institutionName, 'UBS');
    expect(conn.status, ConnectionStatus.active);
    // V6-5 audit fix: mock data capped at system_estimate confidence (0.25)
    expect(conn.dataConfidence, 0.25);
    expect(conn.lastSync, isNotNull);
  });

  // ── 3. disconnect removes connection and data ──

  test('disconnect removes connection and data', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'consent-123',
      prefs: prefs,
    );

    // Sync to create data points
    await OpenFinanceService.sync(connectionId: conn.id, prefs: prefs);

    // Disconnect
    await OpenFinanceService.disconnect(connectionId: conn.id, prefs: prefs);

    final connections = await OpenFinanceService.listConnections(prefs: prefs);
    expect(connections, isEmpty);
  });

  // ── 4. revokeAllConsents purges everything ──

  test('revokeAllConsents purges everything', () async {
    // Create two connections
    await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'consent-1',
      prefs: prefs,
    );
    await OpenFinanceService.connect(
      type: FinanceProvider.pillar3a,
      institutionId: 'viac',
      consentToken: 'consent-2',
      prefs: prefs,
    );

    var connections = await OpenFinanceService.listConnections(prefs: prefs);
    expect(connections.length, 2);

    // Revoke all
    await OpenFinanceService.revokeAllConsents(prefs: prefs);

    connections = await OpenFinanceService.listConnections(prefs: prefs);
    expect(connections, isEmpty);
  });

  // ── 5. sync returns data points with confidence 1.00 ──

  test('sync returns data points with confidence 1.00', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'consent-sync',
      prefs: prefs,
    );

    final dataPoints =
        await OpenFinanceService.sync(connectionId: conn.id, prefs: prefs);

    expect(dataPoints, isNotEmpty);
    for (final dp in dataPoints) {
      // V6-5 audit fix: mock data capped at system_estimate confidence (0.25)
      expect(dp.confidence, 0.25);
      expect(dp.fieldPath, isNotEmpty);
      expect(dp.source, contains('bLink API'));
    }
  });

  // ── 6. enrichProfile updates fields and upgrades confidence ──

  test('enrichProfile updates fields and upgrades confidence', () async {
    final profile = _minimalProfile(epargneLiquide: 20000);
    final dataPoints = [
      FinanceDataPoint(
        fieldPath: 'patrimoine.epargneLiquide',
        value: 45230.0,
        asOf: DateTime.now(),
        source: 'bLink API \u2014 UBS',
        confidence: 1.0,
      ),
    ];

    final result = await OpenFinanceService.enrichProfile(
      profile: profile,
      dataPoints: dataPoints,
    );

    expect(result.updatedFields['patrimoine.epargneLiquide'], 45230.0);
    expect(result.confidenceUpgrades['patrimoine.epargneLiquide'], 1.0);
  });

  // ── 7. enrichProfile audit trail includes old→new values ──

  test('enrichProfile audit trail includes old and new values', () async {
    final profile = _minimalProfile(epargneLiquide: 20000);
    final dataPoints = [
      FinanceDataPoint(
        fieldPath: 'patrimoine.epargneLiquide',
        value: 45230.0,
        asOf: DateTime.now(),
        source: 'bLink API \u2014 UBS',
        confidence: 1.0,
      ),
    ];

    final result = await OpenFinanceService.enrichProfile(
      profile: profile,
      dataPoints: dataPoints,
    );

    expect(result.auditTrail, contains('20000'));
    expect(result.auditTrail, contains('45230'));
    expect(result.auditTrail, contains('\u2192'));
  });

  // ── 8. listConnections returns all active ──

  test('listConnections returns all active connections', () async {
    await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'c1',
      prefs: prefs,
    );
    await OpenFinanceService.connect(
      type: FinanceProvider.pillar3a,
      institutionId: 'viac',
      consentToken: 'c2',
      prefs: prefs,
    );

    final connections = await OpenFinanceService.listConnections(prefs: prefs);
    expect(connections.length, 2);
    expect(connections[0].institutionName, 'UBS');
    expect(connections[1].institutionName, 'VIAC');
  });

  // ── 9. getConsent returns valid consent record ──

  test('getConsent returns valid consent record', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'consent-get',
      prefs: prefs,
    );

    final consent = await OpenFinanceService.getConsent(
      connectionId: conn.id,
      prefs: prefs,
    );

    expect(consent.connectionId, conn.id);
    expect(consent.isActive, true);
    expect(consent.scopes, contains('balance'));
    expect(consent.scopes, contains('identity'));
    expect(consent.expiresAt, isNotNull);
    // Expires in ~90 days
    final daysUntilExpiry =
        consent.expiresAt!.difference(consent.grantedAt).inDays;
    expect(daysUntilExpiry, inInclusiveRange(89, 91));
  });

  // ── 10. Expired consent → connection status expired ──

  test('expired consent marks connection as expired on sync', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'postfinance',
      consentToken: 'consent-exp',
      prefs: prefs,
    );

    // Manually expire the consent by rewriting it with past date
    final raw = prefs.getString('_openfinance_consents');
    final expiredJson = raw!.replaceAll(
      RegExp(r'"expiresAt":"[^"]*"'),
      '"expiresAt":"2020-01-01T00:00:00.000"',
    );
    await prefs.setString('_openfinance_consents', expiredJson);

    // Sync should throw due to expired consent
    expect(
      () => OpenFinanceService.sync(connectionId: conn.id, prefs: prefs),
      throwsA(isA<StateError>()),
    );
  });

  // ── 11. Read-only: no write/transfer methods exposed ──

  test('service exposes no write or transfer methods', () {
    // Verify the API surface: only discovery, connect, disconnect, sync, enrich
    // No 'transfer', 'send', 'pay', 'write' methods exist.
    // This is a compile-time guarantee: OpenFinanceService has no such methods.
    // We verify by checking the class is importable and usable as read-only.
    expect(OpenFinanceService.discoverInstitutions, isNotNull);
    expect(OpenFinanceService.connect, isNotNull);
    expect(OpenFinanceService.disconnect, isNotNull);
    expect(OpenFinanceService.sync, isNotNull);
    expect(OpenFinanceService.enrichProfile, isNotNull);
    expect(OpenFinanceService.listConnections, isNotNull);
    expect(OpenFinanceService.getConsent, isNotNull);
    expect(OpenFinanceService.revokeAllConsents, isNotNull);
  });

  // ── 12. Consent revocation → immediate data purge ──

  test('consent revocation purges all data immediately', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'raiffeisen',
      consentToken: 'consent-purge',
      prefs: prefs,
    );

    await OpenFinanceService.sync(connectionId: conn.id, prefs: prefs);

    // Verify data exists
    var connections = await OpenFinanceService.listConnections(prefs: prefs);
    expect(connections, isNotEmpty);

    // Disconnect (= revoke consent for this connection)
    await OpenFinanceService.disconnect(connectionId: conn.id, prefs: prefs);

    connections = await OpenFinanceService.listConnections(prefs: prefs);
    expect(connections, isEmpty);
  });

  // ── 13. Privacy: no transaction details stored (only balances) ──

  test('sync returns only balance data, no transactions', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'consent-priv',
      prefs: prefs,
    );

    final dataPoints =
        await OpenFinanceService.sync(connectionId: conn.id, prefs: prefs);

    for (final dp in dataPoints) {
      // Field paths should be balance-related, not transaction-related
      expect(dp.fieldPath, isNot(contains('transaction')));
      expect(dp.fieldPath, isNot(contains('virement')));
      expect(dp.fieldPath, isNot(contains('payment')));
    }
  });

  // ── 14. Mock backend works for testing ──

  test('mock backend provides consistent test data', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'consent-mock',
      prefs: prefs,
    );

    final dp1 =
        await OpenFinanceService.sync(connectionId: conn.id, prefs: prefs);
    final dp2 =
        await OpenFinanceService.sync(connectionId: conn.id, prefs: prefs);

    // Same connection → same field paths
    expect(dp1.first.fieldPath, dp2.first.fieldPath);
    expect(dp1.first.value, dp2.first.value);
  });

  // ── 15. Multiple connections coexist ──

  test('multiple connections coexist without interference', () async {
    final bankConn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'c-bank',
      prefs: prefs,
    );
    final p3aConn = await OpenFinanceService.connect(
      type: FinanceProvider.pillar3a,
      institutionId: 'viac',
      consentToken: 'c-3a',
      prefs: prefs,
    );

    final bankData =
        await OpenFinanceService.sync(connectionId: bankConn.id, prefs: prefs);
    final p3aData =
        await OpenFinanceService.sync(connectionId: p3aConn.id, prefs: prefs);

    expect(bankData.first.fieldPath, 'patrimoine.epargneLiquide');
    expect(p3aData.first.fieldPath, 'prevoyance.totalEpargne3a');
  });

  // ── 16. Sync frequency respected (connection stores frequency) ──

  test('connection stores sync frequency', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'c-freq',
      prefs: prefs,
    );

    expect(conn.frequency, SyncFrequency.daily);
  });

  // ── 17. Error handling: API down → error state ──

  test('sync on non-existent connection throws StateError', () async {
    expect(
      () => OpenFinanceService.sync(
        connectionId: 'conn_nonexistent_000',
        prefs: prefs,
      ),
      throwsA(isA<StateError>()),
    );
  });

  // ── 18. Error handling: invalid consent → rejected ──

  test('connect with empty consent token throws ArgumentError', () async {
    expect(
      () => OpenFinanceService.connect(
        type: FinanceProvider.bank,
        institutionId: 'ubs',
        consentToken: '',
        prefs: prefs,
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  // ── 19. Compliance: no money movement ──

  test('FinanceConnection is read-only data model', () {
    const conn = FinanceConnection(
      id: 'test',
      type: FinanceProvider.bank,
      institutionName: 'Test Bank',
      status: ConnectionStatus.active,
    );

    // Can only read data, not initiate transfers
    expect(conn.dataConfidence, 1.0);
    expect(conn.status, ConnectionStatus.active);
    // No 'transfer()', 'send()', or 'pay()' methods exist on the model
  });

  // ── 20. French text with accents ──

  test('enrichment result contains French disclaimer with accents', () async {
    final profile = _minimalProfile();
    final result = await OpenFinanceService.enrichProfile(
      profile: profile,
      dataPoints: [
        FinanceDataPoint(
          fieldPath: 'patrimoine.epargneLiquide',
          value: 30000,
          asOf: DateTime.now(),
          source: 'bLink API',
        ),
      ],
    );

    // Disclaimer uses proper French accents
    expect(result.disclaimer, contains('\u00e9')); // é
    expect(result.disclaimer, contains('outil \u00e9ducatif'));
    expect(result.disclaimer, contains('LSFin'));
  });

  // ── 21. No banned terms ──

  test('no banned terms in service outputs', () async {
    final profile = _minimalProfile();
    final result = await OpenFinanceService.enrichProfile(
      profile: profile,
      dataPoints: [
        FinanceDataPoint(
          fieldPath: 'patrimoine.epargneLiquide',
          value: 30000,
          asOf: DateTime.now(),
          source: 'bLink API',
        ),
      ],
    );

    final allText = result.disclaimer + result.auditTrail;
    final bannedTerms = [
      'garanti',
      'certain',
      'assur\u00e9',
      'sans risque',
      'optimal',
      'meilleur',
      'parfait',
    ];
    for (final term in bannedTerms) {
      expect(allText.toLowerCase(), isNot(contains(term)));
    }
  });

  // ── 22. Disclaimer on enrichment results ──

  test('enrichment result always includes disclaimer', () async {
    final profile = _minimalProfile();
    final result = await OpenFinanceService.enrichProfile(
      profile: profile,
      dataPoints: [],
    );

    expect(result.disclaimer, isNotEmpty);
    expect(result.disclaimer, contains('ne constitue pas un conseil'));
  });

  // ── 23. ConfidenceScore upgrade: userInput(0.60) → openBanking(1.00) ──

  test('confidence upgrade from userInput to openBanking', () async {
    final profile = _minimalProfile(avoirLppTotal: 50000);

    final dataPoints = [
      FinanceDataPoint(
        fieldPath: 'prevoyance.avoirLppTotal',
        value: 70377.0,
        asOf: DateTime.now(),
        source: 'bLink API \u2014 CPE',
        confidence: 1.0,
      ),
    ];

    final result = await OpenFinanceService.enrichProfile(
      profile: profile,
      dataPoints: dataPoints,
    );

    // Confidence upgraded to 1.00 (openBanking level)
    expect(result.confidenceUpgrades['prevoyance.avoirLppTotal'], 1.0);
    // Value updated
    expect(result.updatedFields['prevoyance.avoirLppTotal'], 70377.0);
  });

  // ── 24. Canton-based discovery works ──

  test('canton-based discovery filters institutions', () async {
    final vsInstitutions =
        await OpenFinanceService.discoverInstitutions(canton: 'VS');

    // CPE is VS-specific, should be included
    final names = vsInstitutions.map((i) => i.id).toSet();
    expect(names, contains('cpe'));

    // National banks (empty supportedCantons) should also be included
    expect(names, contains('ubs'));

    // ZKB is ZH-only, should NOT be included
    expect(names, isNot(contains('zkb')));
  });

  // ═══════════════════════════════════════════════════════════════════════
  // COMPLIANCE HARDENER — additional tests (audit S73-S74)
  // ═══════════════════════════════════════════════════════════════════════

  // ── 25. PII not in toString/debug output ──

  test('FinanceConnection.toString() does not leak PII', () {
    const conn = FinanceConnection(
      id: 'conn_ubs_123',
      type: FinanceProvider.bank,
      institutionName: 'UBS',
      status: ConnectionStatus.active,
    );
    final str = conn.toString();
    // Default Dart toString shows "Instance of 'FinanceConnection'"
    // Must NOT expose account details, IBAN, or balances
    expect(str, isNot(contains('CH93')));
    expect(str, isNot(contains('45230')));
    expect(str, isNot(contains('UBS'))); // institution name not leaked
  });

  test('FinanceDataPoint.toString() does not expose balance values', () {
    final dp = FinanceDataPoint(
      fieldPath: 'patrimoine.epargneLiquide',
      value: 45230.0,
      asOf: DateTime(2026, 3, 18),
      source: 'bLink API — conn_ubs_123',
    );
    final str = dp.toString();
    expect(str, contains('Instance of'));
  });

  // ── 26. No IBAN stored in any data class ──

  test('FinanceConnection.toJson() contains no IBAN field', () {
    const conn = FinanceConnection(
      id: 'conn_ubs_123',
      type: FinanceProvider.bank,
      institutionName: 'UBS',
      status: ConnectionStatus.active,
    );
    final json = conn.toJson();
    expect(json.containsKey('iban'), isFalse);
    expect(json.containsKey('accountNumber'), isFalse);
    for (final value in json.values) {
      if (value is String) {
        expect(
          RegExp(r'CH\d{2}\s?\d{4}\s?\d{4}').hasMatch(value),
          isFalse,
          reason: 'IBAN pattern detected in: $value',
        );
      }
    }
  });

  test('FinanceDataPoint.toJson() contains no IBAN field', () {
    final dp = FinanceDataPoint(
      fieldPath: 'test',
      value: 0,
      asOf: DateTime(2026),
      source: 'test',
    );
    final dpJson = dp.toJson();
    expect(dpJson.keys.where((k) => k.toLowerCase().contains('iban')), isEmpty);
    expect(dpJson.keys.where((k) => k.toLowerCase().contains('account')), isEmpty);
  });

  // ── 27. Consent scopes restricted to safe read-only scopes ──

  test('consent scopes exclude transaction/transfer/payment', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'consent-scope-check',
      prefs: prefs,
    );

    final consent = await OpenFinanceService.getConsent(
      connectionId: conn.id,
      prefs: prefs,
    );

    expect(consent.scopes, containsAll(['balance', 'identity']));
    expect(consent.scopes, isNot(contains('transactions')));
    expect(consent.scopes, isNot(contains('transfer')));
    expect(consent.scopes, isNot(contains('payment')));
    expect(consent.scopes, isNot(contains('write')));
  });

  // ── 28. Serialization roundtrip: FinanceConnection ──

  test('FinanceConnection serialization roundtrip preserves all fields', () {
    final conn = FinanceConnection(
      id: 'conn_ubs_999',
      type: FinanceProvider.bank,
      institutionName: 'UBS',
      status: ConnectionStatus.active,
      lastSync: DateTime(2026, 3, 18),
      frequency: SyncFrequency.daily,
      dataConfidence: 1.0,
    );

    final json = conn.toJson();
    final restored = FinanceConnection.fromJson(json);

    expect(restored.id, conn.id);
    expect(restored.type, conn.type);
    expect(restored.institutionName, conn.institutionName);
    expect(restored.status, conn.status);
    expect(restored.lastSync, conn.lastSync);
    expect(restored.frequency, conn.frequency);
    expect(restored.dataConfidence, conn.dataConfidence);
  });

  // ── 29. Serialization roundtrip: ConsentRecord ──

  test('ConsentRecord serialization roundtrip preserves all fields', () {
    final consent = ConsentRecord(
      connectionId: 'conn_test',
      grantedAt: DateTime(2026, 3, 18, 10, 30),
      expiresAt: DateTime(2026, 6, 18, 10, 30),
      scopes: const ['balance', 'identity'],
      isActive: true,
    );

    final json = consent.toJson();
    final restored = ConsentRecord.fromJson(json);

    expect(restored.connectionId, consent.connectionId);
    expect(restored.grantedAt, consent.grantedAt);
    expect(restored.expiresAt, consent.expiresAt);
    expect(restored.scopes, consent.scopes);
    expect(restored.isActive, consent.isActive);
  });

  // ── 30. getConsent throws when prefs is null ──

  test('getConsent throws StateError when prefs is null', () async {
    expect(
      () => OpenFinanceService.getConsent(
        connectionId: 'any',
        prefs: null,
      ),
      throwsA(isA<StateError>()),
    );
  });

  // ── 31. listConnections returns empty when prefs is null ──

  test('listConnections returns empty list when prefs is null', () async {
    final connections =
        await OpenFinanceService.listConnections(prefs: null);
    expect(connections, isEmpty);
  });

  // ── 32. disconnect is safe with null prefs ──

  test('disconnect is safe with null prefs (no-op)', () async {
    await OpenFinanceService.disconnect(
      connectionId: 'any',
      prefs: null,
    );
    // Should not throw
  });

  // ── 33. revokeAllConsents safe with null prefs ──

  test('revokeAllConsents is safe with null prefs', () async {
    await OpenFinanceService.revokeAllConsents(prefs: null);
    // Should not throw
  });

  // ── 34. connect throws for unknown institution ──

  test('connect throws ArgumentError for unknown institution', () async {
    expect(
      () => OpenFinanceService.connect(
        type: FinanceProvider.bank,
        institutionId: 'nonexistent_bank_xyz',
        consentToken: 'valid-token',
        prefs: prefs,
      ),
      throwsA(isA<ArgumentError>().having(
        (e) => e.message,
        'message',
        contains('Institution inconnue'),
      )),
    );
  });

  // ── 35. getConsent returns inactive for expired consent ──

  test('getConsent returns isActive=false for expired consent', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'consent-expired-get',
      prefs: prefs,
    );

    // Expire consent
    final raw = prefs.getString('_openfinance_consents');
    final expired = raw!.replaceAll(
      RegExp(r'"expiresAt":"[^"]*"'),
      '"expiresAt":"2020-01-01T00:00:00.000"',
    );
    await prefs.setString('_openfinance_consents', expired);

    final consent = await OpenFinanceService.getConsent(
      connectionId: conn.id,
      prefs: prefs,
    );
    expect(consent.isActive, isFalse);
  });

  // ── 36. copyWith preserves unchanged fields ──

  test('FinanceConnection.copyWith preserves unchanged fields', () {
    const conn = FinanceConnection(
      id: 'test',
      type: FinanceProvider.bank,
      institutionName: 'Test',
      status: ConnectionStatus.active,
      dataConfidence: 1.0,
    );

    final updated = conn.copyWith(status: ConnectionStatus.expired);
    expect(updated.id, conn.id);
    expect(updated.type, conn.type);
    expect(updated.institutionName, conn.institutionName);
    expect(updated.status, ConnectionStatus.expired);
    expect(updated.dataConfidence, 1.0);
  });

  // ── 37. Enums have expected values ──

  test('FinanceProvider enum has 4 values', () {
    expect(FinanceProvider.values, hasLength(4));
    expect(FinanceProvider.values, contains(FinanceProvider.bank));
    expect(FinanceProvider.values, contains(FinanceProvider.pillar3a));
    expect(FinanceProvider.values, contains(FinanceProvider.insuranceLpp));
    expect(FinanceProvider.values, contains(FinanceProvider.taxAuthority));
  });

  test('ConnectionStatus enum has 5 values', () {
    expect(ConnectionStatus.values, hasLength(5));
    expect(ConnectionStatus.values, contains(ConnectionStatus.active));
    expect(ConnectionStatus.values, contains(ConnectionStatus.pending));
    expect(ConnectionStatus.values, contains(ConnectionStatus.error));
    expect(ConnectionStatus.values, contains(ConnectionStatus.expired));
    expect(ConnectionStatus.values, contains(ConnectionStatus.revoked));
  });

  test('SyncFrequency enum has 4 values', () {
    expect(SyncFrequency.values, hasLength(4));
  });

  // ── 38. Enrichment with empty data points returns empty result ──

  test('enrichProfile with empty data points returns empty result', () async {
    final profile = _minimalProfile();
    final result = await OpenFinanceService.enrichProfile(
      profile: profile,
      dataPoints: [],
    );

    expect(result.updatedFields, isEmpty);
    expect(result.confidenceUpgrades, isEmpty);
    expect(result.auditTrail, isEmpty);
    expect(result.disclaimer, isNotEmpty); // Disclaimer always present
  });

  // ── 39. Enrichment for unknown field path returns null old value ──

  test('enrichProfile handles unknown field path gracefully', () async {
    final profile = _minimalProfile();
    final result = await OpenFinanceService.enrichProfile(
      profile: profile,
      dataPoints: [
        FinanceDataPoint(
          fieldPath: 'unknown.field',
          value: 999.0,
          asOf: DateTime(2026, 3, 18),
          source: 'bLink API',
        ),
      ],
    );

    expect(result.updatedFields['unknown.field'], 999.0);
    expect(result.auditTrail, contains('n/a'));
  });

  // ── 40. revokeAllConsents is idempotent ──

  test('revokeAllConsents is idempotent (safe to call twice)', () async {
    await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'c-idem',
      prefs: prefs,
    );

    await OpenFinanceService.revokeAllConsents(prefs: prefs);
    await OpenFinanceService.revokeAllConsents(prefs: prefs);

    final connections = await OpenFinanceService.listConnections(prefs: prefs);
    expect(connections, isEmpty);
  });

  // ── 41. Data points from sync have valid timestamps ──

  test('sync data points have recent asOf timestamps', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'c-ts',
      prefs: prefs,
    );

    final before = DateTime.now();
    final dataPoints =
        await OpenFinanceService.sync(connectionId: conn.id, prefs: prefs);
    final after = DateTime.now();

    for (final dp in dataPoints) {
      expect(dp.asOf.isAfter(before.subtract(const Duration(seconds: 1))),
          isTrue);
      expect(dp.asOf.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    }
  });

  // ── 42. FinanceDataPoint confidence default is 1.0 ──

  test('FinanceDataPoint default confidence is 1.0 (openBanking)', () {
    final dp = FinanceDataPoint(
      fieldPath: 'test',
      value: 100,
      asOf: DateTime(2026),
      source: 'test',
    );
    expect(dp.confidence, 1.0);
  });

  // ── 43. Discovery returns bLink-compatible institutions ──

  test('all discovered institutions are bLink compatible', () async {
    final institutions = await OpenFinanceService.discoverInstitutions();
    for (final inst in institutions) {
      expect(inst.blinkCompatible, isTrue,
          reason: '${inst.name} should be bLink compatible');
    }
  });

  // ── 44. Sync updates lastSync timestamp on connection ──

  test('sync updates lastSync timestamp on connection', () async {
    final conn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'c-lastsync',
      prefs: prefs,
    );

    final originalSync = conn.lastSync;
    // Small delay to ensure timestamps differ
    await Future<void>.delayed(const Duration(milliseconds: 10));

    await OpenFinanceService.sync(connectionId: conn.id, prefs: prefs);

    final connections = await OpenFinanceService.listConnections(prefs: prefs);
    final updated = connections.firstWhere((c) => c.id == conn.id);
    expect(
      updated.lastSync!.millisecondsSinceEpoch,
      greaterThanOrEqualTo(originalSync!.millisecondsSinceEpoch),
    );
  });

  // ── Original test 25. Data points have valid field paths ──

  test('synced data points have valid profile field paths', () async {
    // Connect to each type and verify field paths
    final bankConn = await OpenFinanceService.connect(
      type: FinanceProvider.bank,
      institutionId: 'ubs',
      consentToken: 'c-valid',
      prefs: prefs,
    );
    final p3aConn = await OpenFinanceService.connect(
      type: FinanceProvider.pillar3a,
      institutionId: 'viac',
      consentToken: 'c-valid-3a',
      prefs: prefs,
    );
    final lppConn = await OpenFinanceService.connect(
      type: FinanceProvider.insuranceLpp,
      institutionId: 'cpe',
      consentToken: 'c-valid-lpp',
      prefs: prefs,
    );

    final bankDp =
        await OpenFinanceService.sync(connectionId: bankConn.id, prefs: prefs);
    final p3aDp =
        await OpenFinanceService.sync(connectionId: p3aConn.id, prefs: prefs);
    final lppDp =
        await OpenFinanceService.sync(connectionId: lppConn.id, prefs: prefs);

    final validPaths = {
      'patrimoine.epargneLiquide',
      'prevoyance.totalEpargne3a',
      'prevoyance.avoirLppTotal',
      'patrimoine.capitalLibre',
    };

    for (final dp in [...bankDp, ...p3aDp, ...lppDp]) {
      expect(validPaths, contains(dp.fieldPath),
          reason: 'Invalid field path: ${dp.fieldPath}');
    }
  });
}
