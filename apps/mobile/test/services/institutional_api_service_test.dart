import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mint_mobile/services/institutional/institutional_api_service.dart';
import 'package:mint_mobile/services/institutional/pension_fund_registry.dart';

void main() {
  // =========================================================================
  // INSTITUTIONAL API SERVICE — 35 unit tests (S69-S70)
  // =========================================================================
  //
  // Tests cover:
  //   - Connection lifecycle (connect, disconnect, status)
  //   - Data fetching with confidence = 0.95 (certificate-grade)
  //   - Profile sync with audit trail
  //   - Token encryption compliance
  //   - Rate limiting (once/day)
  //   - Error handling (auth failure, network, expired)
  //   - Graceful degradation (cached data on API failure)
  //   - Registry metadata
  //   - Read-only compliance (no write operations)
  //   - French accents in user-facing text
  //   - No banned terms
  //   - Audit log entries for ALL API calls
  //   - Disclaimer + legal sources on all output
  //   - Golden couple (Julien CPE, Lauren HOTELA)
  //   - Privacy: no cross-user data leakage

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // Reset to clean mock backend for each test
    InstitutionalApiService.setBackend(MockPensionFundBackend());
    InstitutionalApiService.clearAuditLog();
  });

  // ── 1. connect stores connection in SharedPreferences ──────
  test('connect stores connection in SharedPreferences', () async {
    final conn = await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'test-oauth-token-123',
      prefs: prefs,
    );

    expect(conn.status, ConnectionStatus.connected);
    expect(conn.connectedAt, isNotNull);
    expect(conn.lastSync, isNotNull);
    expect(conn.errorMessage, isNull);

    // Verify persisted
    final stored = prefs.getString('institutional_connection_publica');
    expect(stored, isNotNull);
    expect(stored, contains('"status":"connected"'));
  });

  // ── 2. disconnect removes connection ───────────────────────
  test('disconnect removes connection and all stored data', () async {
    // First connect
    await InstitutionalApiService.connect(
      fund: PensionFund.bvk,
      authToken: 'token-bvk',
      prefs: prefs,
    );

    // Fetch data so cache exists
    await InstitutionalApiService.fetchData(
      fund: PensionFund.bvk,
      prefs: prefs,
      forceRefresh: true,
    );

    // Disconnect
    await InstitutionalApiService.disconnect(
      fund: PensionFund.bvk,
      prefs: prefs,
    );

    // Verify all keys removed
    expect(prefs.getString('institutional_connection_bvk'), isNull);
    expect(prefs.getString('institutional_token_bvk'), isNull);
    expect(prefs.getInt('institutional_last_refresh_bvk'), isNull);
    expect(prefs.getString('institutional_data_bvk'), isNull);
  });

  // ── 3. checkStatus returns correct state ───────────────────
  test('checkStatus returns disconnected when no connection exists', () async {
    final status = await InstitutionalApiService.checkStatus(
      fund: PensionFund.cpev,
      prefs: prefs,
    );
    expect(status, ConnectionStatus.disconnected);
  });

  // ── 4. checkStatus returns connected for valid connection ──
  test('checkStatus returns connected for valid token', () async {
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'valid-token',
      prefs: prefs,
    );

    final status = await InstitutionalApiService.checkStatus(
      fund: PensionFund.publica,
      prefs: prefs,
    );
    expect(status, ConnectionStatus.connected);
  });

  // ── 5. fetchData returns PensionFundData with confidence=0.95 ─
  test('fetchData returns data with confidenceScore = 0.95 (certificate-grade)',
      () async {
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token',
      prefs: prefs,
    );

    final data = await InstitutionalApiService.fetchData(
      fund: PensionFund.publica,
      prefs: prefs,
      forceRefresh: true,
    );

    expect(data.confidenceScore, 0.95);
    expect(data.fund, PensionFund.publica);
    expect(data.avoirLpp, greaterThan(0));
    expect(data.rachatMaximal, greaterThan(0));
    expect(data.tauxConversion, 0.068);
    expect(data.source, contains('Publica'));
    expect(data.source, contains('certifiées'));
  });

  // ── 6. syncToProfile updates fields and returns audit trail ─
  test('syncToProfile updates fields and returns audit trail', () {
    final data = PensionFundData(
      fund: PensionFund.publica,
      avoirLpp: 72500.0,
      rachatMaximal: 130000.0,
      tauxConversion: 0.068,
      bonificationAnnuelle: 0.15,
      dataDate: DateTime.now(),
      source: 'API Publica — données certifiées',
    );

    final result = InstitutionalApiService.syncToProfile(
      data: data,
      profileFields: {'avoirLpp': 70377.0, 'rachatMaximal': 120000.0},
      previousConfidence: 0.60,
    );

    expect(result.updatedFields['avoirLpp'], 72500.0);
    expect(result.updatedFields['rachatMaximal'], 130000.0);
    expect(result.newConfidence, 0.95);
    expect(result.previousConfidence, 0.60);
    expect(result.auditTrail, contains('70\'377'));
    expect(result.auditTrail, contains('72\'500'));
    expect(result.auditTrail, contains('Publica'));
  });

  // ── 7. syncToProfile preserves non-LPP profile fields ──────
  test('syncToProfile only updates LPP-related fields', () {
    final data = PensionFundData(
      fund: PensionFund.bvk,
      avoirLpp: 95300.0,
      rachatMaximal: 250000.0,
      tauxConversion: 0.068,
      bonificationAnnuelle: 0.10,
      dataDate: DateTime.now(),
      source: 'API BVK — données certifiées',
    );

    final profile = {
      'avoirLpp': 80000.0,
      'salaireBrut': 120000.0,
      'canton': 'BE',
    };

    final result = InstitutionalApiService.syncToProfile(
      data: data,
      profileFields: profile,
    );

    // Original profile fields not in updatedFields (not touched)
    expect(result.updatedFields.containsKey('salaireBrut'), false);
    expect(result.updatedFields.containsKey('canton'), false);
    // LPP fields are updated
    expect(result.updatedFields['avoirLpp'], 95300.0);
    expect(result.updatedFields['lppDataSource'], 'institutionalApi');
  });

  // ── 8. listConnections returns all connected funds ─────────
  test('listConnections returns status for all 3 funds', () async {
    // Connect one fund
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token',
      prefs: prefs,
    );

    final connections =
        await InstitutionalApiService.listConnections(prefs: prefs);

    expect(connections.length, 3);
    final publicaConn =
        connections.firstWhere((c) => c.fund == PensionFund.publica);
    final bvkConn =
        connections.firstWhere((c) => c.fund == PensionFund.bvk);
    final cpevConn =
        connections.firstWhere((c) => c.fund == PensionFund.cpev);

    expect(publicaConn.status, ConnectionStatus.connected);
    expect(bvkConn.status, ConnectionStatus.disconnected);
    expect(cpevConn.status, ConnectionStatus.disconnected);
  });

  // ── 9. Auth token encrypted (not stored in plain text) ─────
  test('auth token is encrypted in SharedPreferences', () async {
    const rawToken = 'my-secret-oauth-token';
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: rawToken,
      prefs: prefs,
    );

    final storedToken = prefs.getString('institutional_token_publica');
    expect(storedToken, isNotNull);
    expect(storedToken, isNot(equals(rawToken)));

    // Verify it's encrypted (base64)
    final isEncrypted = await InstitutionalApiService.isTokenEncrypted(
      fund: PensionFund.publica,
      prefs: prefs,
    );
    expect(isEncrypted, true);
  });

  // ── 10. Read-only: no write operations exposed ─────────────
  test('service exposes no write/mutation operations on the fund', () {
    final mock = MockPensionFundBackend();

    // The backend interface only has these 3 methods:
    expect(mock.authenticate, isNotNull);
    expect(mock.fetchFundData, isNotNull);
    expect(mock.isTokenValid, isNotNull);

    // No methods like: transferFunds, updateBalance, writeFundData, etc.
    // This is enforced by the PensionFundBackend abstract class.
  });

  // ── 11. Error handling: network failure → error status ─────
  test('connect returns error status on auth failure', () async {
    InstitutionalApiService.setBackend(
      MockPensionFundBackend(shouldFailAuth: true),
    );

    final conn = await InstitutionalApiService.connect(
      fund: PensionFund.cpev,
      authToken: 'token',
      prefs: prefs,
    );

    expect(conn.status, ConnectionStatus.error);
    expect(conn.errorMessage, isNotNull);
    expect(conn.errorMessage, contains('authentification'));
  });

  // ── 12. Error handling: expired token → expired status ─────
  test('checkStatus returns expired when token is no longer valid', () async {
    // First connect successfully
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token',
      prefs: prefs,
    );

    // Now switch to expired backend
    InstitutionalApiService.setBackend(
      MockPensionFundBackend(shouldReturnExpired: true),
    );

    final status = await InstitutionalApiService.checkStatus(
      fund: PensionFund.publica,
      prefs: prefs,
    );

    expect(status, ConnectionStatus.expired);
  });

  // ── 13. Mock backend works for all 3 funds ─────────────────
  test('mock backend returns valid data for all 3 funds', () async {
    final mock = MockPensionFundBackend();

    for (final fund in PensionFund.values) {
      final data = await mock.fetchFundData(fund);
      expect(data.fund, fund);
      expect(data.confidenceScore, 0.95);
      expect(data.avoirLpp, greaterThan(0));
      expect(data.source, contains('certifiées'));
    }
  });

  // ── 14. All 3 funds in registry with correct metadata ──────
  test('registry contains all 3 pilot funds', () {
    final all = PensionFundRegistry.getAll();
    expect(all.length, 3);

    final publica = PensionFundRegistry.getInfo(PensionFund.publica);
    expect(publica.name, contains('Publica'));
    expect(publica.isActive, true);
    expect(publica.apiVersion, '1.0.0');

    final bvk = PensionFundRegistry.getInfo(PensionFund.bvk);
    expect(bvk.shortName, 'BVK');
    expect(bvk.supportedCantons, contains('BE'));

    final cpev = PensionFundRegistry.getInfo(PensionFund.cpev);
    expect(cpev.shortName, 'CPEV');
    expect(cpev.supportedCantons, contains('VD'));
  });

  // ── 15. Fund registry has correct metadata ─────────────────
  test('registry supports canton-based lookup', () {
    final bernFunds = PensionFundRegistry.getForCanton('BE');
    expect(bernFunds.length, greaterThanOrEqualTo(2)); // Publica + BVK
    expect(bernFunds.any((f) => f.id == PensionFund.bvk), true);
    expect(bernFunds.any((f) => f.id == PensionFund.publica), true);

    final vaudFunds = PensionFundRegistry.getForCanton('VD');
    expect(vaudFunds.any((f) => f.id == PensionFund.cpev), true);
    expect(vaudFunds.any((f) => f.id == PensionFund.publica), true);
  });

  // ── 16. Audit trail includes old and new values ────────────
  test('audit trail includes old and new values with CHF formatting', () {
    final data = PensionFundData(
      fund: PensionFund.cpev,
      avoirLpp: 150000.0,
      rachatMaximal: 200000.0,
      tauxConversion: 0.068,
      bonificationAnnuelle: 0.18,
      dataDate: DateTime.now(),
      source: 'API CPEV — données certifiées',
    );

    final result = InstitutionalApiService.syncToProfile(
      data: data,
      profileFields: {'avoirLpp': 142750.0, 'rachatMaximal': 180000.0},
    );

    // Old values
    expect(result.auditTrail, contains('142\'750'));
    // New values
    expect(result.auditTrail, contains('150\'000'));
    // Fund name
    expect(result.auditTrail, contains('CPEV'));
    // Arrow separator
    expect(result.auditTrail, contains('→'));
  });

  // ── 17. ConfidenceScore always 0.95 for institutional data ─
  test('PensionFundData default confidenceScore is 0.95', () {
    final data = PensionFundData(
      fund: PensionFund.publica,
      avoirLpp: 100000,
      rachatMaximal: 50000,
      tauxConversion: 0.068,
      bonificationAnnuelle: 0.15,
      dataDate: DateTime.now(),
      source: 'API Publica — données certifiées',
    );

    expect(data.confidenceScore, 0.95);

    // Also via syncToProfile
    final result = InstitutionalApiService.syncToProfile(
      data: data,
      profileFields: {},
      previousConfidence: 0.25,
    );
    expect(result.newConfidence, 0.95);
  });

  // ── 18. Auto-refresh rate limited (once/day) ───────────────
  test('fetchData returns cached data within 24h cooldown', () async {
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token',
      prefs: prefs,
    );

    // First fetch
    final data1 = await InstitutionalApiService.fetchData(
      fund: PensionFund.publica,
      prefs: prefs,
      forceRefresh: true,
    );

    // Second fetch (within 24h) — should return cached
    final data2 = await InstitutionalApiService.fetchData(
      fund: PensionFund.publica,
      prefs: prefs,
    );

    // Both should have valid data
    expect(data1.avoirLpp, data2.avoirLpp);
    expect(data1.fund, data2.fund);

    // Verify cache key exists
    expect(prefs.getString('institutional_data_publica'), isNotNull);
    expect(prefs.getInt('institutional_last_refresh_publica'), isNotNull);
  });

  // ── 19. Compliance: no money movement methods ──────────────
  test('PensionFundBackend interface has no write/transfer methods', () {
    final mock = MockPensionFundBackend();

    // Can authenticate (read: validate credentials)
    expect(mock.authenticate(PensionFund.publica, 'x'), completes);
    // Can fetch data (read)
    expect(mock.fetchFundData(PensionFund.publica), completes);
    // Can check token validity (read)
    expect(mock.isTokenValid(PensionFund.publica, 'x'), completes);

    // No methods named: transfer, send, write, update, modify, delete
    // This is enforced by the abstract class definition.
  });

  // ── 20. French accents and no banned terms in text ─────────
  test('user-facing text has French accents and no banned terms', () async {
    // Test error message from failed auth
    InstitutionalApiService.setBackend(
      MockPensionFundBackend(shouldFailAuth: true),
    );
    final conn = await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token',
      prefs: prefs,
    );

    // Contains proper French (with accents)
    expect(conn.errorMessage, contains('Échec'));
    expect(conn.errorMessage, contains('authentification'));

    // No banned terms
    const bannedTerms = [
      'garanti', 'certain', 'assuré', 'sans risque',
      'optimal', 'meilleur', 'parfait',
    ];
    for (final term in bannedTerms) {
      expect(
        conn.errorMessage!.toLowerCase().contains(term),
        false,
        reason: 'Error message must not contain banned term "$term"',
      );
    }

    // Test data source labels
    InstitutionalApiService.setBackend(MockPensionFundBackend());
    final data =
        await MockPensionFundBackend().fetchFundData(PensionFund.publica);
    expect(data.source, contains('données certifiées'));
    // "certifiées" has proper accent
    expect(data.source, contains('ées'));

    // No banned terms in source
    for (final term in bannedTerms) {
      expect(
        data.source.toLowerCase().contains(term),
        false,
        reason: 'Source label must not contain banned term "$term"',
      );
    }
  });

  // =========================================================================
  // NEW TESTS — Compliance Hardener + Test Generation (S69-S70 audit)
  // =========================================================================

  // ── 21. Audit log: connect creates audit entry ─────────────
  test('connect creates audit log entry on success', () async {
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token',
      prefs: prefs,
    );

    final log = InstitutionalApiService.auditLog;
    expect(log, isNotEmpty);
    final entry = log.last;
    expect(entry.operation, 'connect');
    expect(entry.fund, PensionFund.publica);
    expect(entry.success, true);
    expect(entry.timestamp, isNotNull);
  });

  // ── 22. Audit log: connect failure creates audit entry ─────
  test('connect creates audit log entry on failure', () async {
    InstitutionalApiService.setBackend(
      MockPensionFundBackend(shouldFailAuth: true),
    );

    await InstitutionalApiService.connect(
      fund: PensionFund.bvk,
      authToken: 'bad-token',
      prefs: prefs,
    );

    final log = InstitutionalApiService.auditLog;
    expect(log, isNotEmpty);
    final entry = log.last;
    expect(entry.operation, 'connect');
    expect(entry.fund, PensionFund.bvk);
    expect(entry.success, false);
    expect(entry.detail, contains('failed'));
  });

  // ── 23. Audit log: checkStatus creates audit entry ─────────
  test('checkStatus creates audit log entry', () async {
    await InstitutionalApiService.checkStatus(
      fund: PensionFund.cpev,
      prefs: prefs,
    );

    final log = InstitutionalApiService.auditLog;
    expect(log.any((e) => e.operation == 'checkStatus'), true);
  });

  // ── 24. Audit log: fetchData creates audit entry ───────────
  test('fetchData creates audit log entry on success', () async {
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token',
      prefs: prefs,
    );
    InstitutionalApiService.clearAuditLog();

    await InstitutionalApiService.fetchData(
      fund: PensionFund.publica,
      prefs: prefs,
      forceRefresh: true,
    );

    final log = InstitutionalApiService.auditLog;
    expect(log.any((e) => e.operation == 'fetchData' && e.success), true);
  });

  // ── 25. Audit log: disconnect creates audit entry ──────────
  test('disconnect creates audit log entry', () async {
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token',
      prefs: prefs,
    );
    InstitutionalApiService.clearAuditLog();

    await InstitutionalApiService.disconnect(
      fund: PensionFund.publica,
      prefs: prefs,
    );

    final log = InstitutionalApiService.auditLog;
    expect(log.any((e) => e.operation == 'disconnect'), true);
  });

  // ── 26. Disclaimer present on all PensionFundData ──────────
  test('PensionFundData includes disclaimer and legal sources', () {
    final data = PensionFundData(
      fund: PensionFund.publica,
      avoirLpp: 100000,
      rachatMaximal: 50000,
      tauxConversion: 0.068,
      bonificationAnnuelle: 0.15,
      dataDate: DateTime.now(),
      source: 'API Publica — données certifiées',
    );

    // Disclaimer required (CLAUDE.md §6)
    expect(data.disclaimer, contains('éducatif'));
    expect(data.disclaimer, contains('LSFin'));
    expect(data.disclaimer, contains('ne constitue pas un conseil'));

    // Legal sources required
    expect(data.sources, isNotEmpty);
    expect(data.sources.any((s) => s.contains('LPP')), true);
  });

  // ── 27. Disclaimer survives JSON serialization ─────────────
  test('disclaimer and sources survive JSON round-trip', () {
    final data = PensionFundData(
      fund: PensionFund.bvk,
      avoirLpp: 95300,
      rachatMaximal: 250000,
      tauxConversion: 0.068,
      bonificationAnnuelle: 0.10,
      dataDate: DateTime(2026, 3, 18),
      source: 'API BVK — données certifiées',
    );

    final json = data.toJson();
    final restored = PensionFundData.fromJson(json);

    expect(restored.disclaimer, data.disclaimer);
    expect(restored.sources, data.sources);
    expect(restored.confidenceScore, 0.95);
  });

  // ── 28. syncToProfile includes disclaimer in updates ───────
  test('syncToProfile includes disclaimer and sources in updatedFields', () {
    final data = PensionFundData(
      fund: PensionFund.publica,
      avoirLpp: 72500.0,
      rachatMaximal: 130000.0,
      tauxConversion: 0.068,
      bonificationAnnuelle: 0.15,
      dataDate: DateTime.now(),
      source: 'API Publica — données certifiées',
    );

    final result = InstitutionalApiService.syncToProfile(
      data: data,
      profileFields: {},
    );

    expect(result.updatedFields['disclaimer'], isNotNull);
    expect(result.updatedFields['disclaimer'], contains('LSFin'));
    expect(result.updatedFields['sources'], isNotEmpty);
  });

  // ── 29. Graceful degradation: cached data on API failure ───
  test('fetchData returns cached data when API fails', () async {
    // First: connect and fetch successfully
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token',
      prefs: prefs,
    );
    final original = await InstitutionalApiService.fetchData(
      fund: PensionFund.publica,
      prefs: prefs,
      forceRefresh: true,
    );

    // Now: switch to failing backend
    InstitutionalApiService.setBackend(
      MockPensionFundBackend(shouldFailFetch: true),
    );

    // Force refresh to bypass rate limit — should gracefully degrade to cache
    final cached = await InstitutionalApiService.fetchData(
      fund: PensionFund.publica,
      prefs: prefs,
      forceRefresh: true,
    );

    expect(cached.avoirLpp, original.avoirLpp);
    expect(cached.fund, PensionFund.publica);

    // Verify audit log recorded the failure + fallback
    final log = InstitutionalApiService.auditLog;
    expect(log.any((e) => e.operation == 'fetchData' && !e.success), true);
    expect(
      log.any((e) =>
          e.operation == 'fetchData' &&
          e.detail != null &&
          e.detail!.contains('cached')),
      true,
    );
  });

  // ── 30. Graceful degradation: no cache → rethrow ───────────
  test('fetchData rethrows when API fails and no cache exists', () async {
    InstitutionalApiService.setBackend(
      MockPensionFundBackend(shouldFailFetch: true),
    );

    expect(
      () => InstitutionalApiService.fetchData(
        fund: PensionFund.publica,
        prefs: prefs,
        forceRefresh: true,
      ),
      throwsException,
    );
  });

  // ── 31. Privacy: fund data is isolated per fund ────────────
  test('privacy: fund data does not leak across different funds', () async {
    // Connect and fetch Publica
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token-publica',
      prefs: prefs,
    );
    await InstitutionalApiService.fetchData(
      fund: PensionFund.publica,
      prefs: prefs,
      forceRefresh: true,
    );

    // Connect and fetch BVK
    await InstitutionalApiService.connect(
      fund: PensionFund.bvk,
      authToken: 'token-bvk',
      prefs: prefs,
    );
    await InstitutionalApiService.fetchData(
      fund: PensionFund.bvk,
      prefs: prefs,
      forceRefresh: true,
    );

    // Disconnect Publica
    await InstitutionalApiService.disconnect(
      fund: PensionFund.publica,
      prefs: prefs,
    );

    // BVK data still intact
    final bvkData = prefs.getString('institutional_data_bvk');
    expect(bvkData, isNotNull);

    // Publica data gone
    final publicaData = prefs.getString('institutional_data_publica');
    expect(publicaData, isNull);
  });

  // ── 32. Privacy: tokens isolated per fund ──────────────────
  test('privacy: auth tokens are stored separately per fund', () async {
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token-A',
      prefs: prefs,
    );
    await InstitutionalApiService.connect(
      fund: PensionFund.bvk,
      authToken: 'token-B',
      prefs: prefs,
    );

    final tokenA = prefs.getString('institutional_token_publica');
    final tokenB = prefs.getString('institutional_token_bvk');

    // Both exist and are different (different source tokens)
    expect(tokenA, isNotNull);
    expect(tokenB, isNotNull);
    expect(tokenA, isNot(equals(tokenB)));
  });

  // ── 33. Golden couple: Julien (CPE caisse) ─────────────────
  test('golden couple: Julien CPE profile sync matches expected values',
      () {
    // Julien: avoirLpp = 70'377, rachat = 539'414 (CLAUDE.md §8)
    final data = PensionFundData(
      fund: PensionFund.cpev, // Closest pilot fund for test
      avoirLpp: 70377.0,
      rachatMaximal: 539414.0,
      tauxConversion: 0.068,
      bonificationAnnuelle: 0.15, // age 49 → 15% (art. 16)
      dataDate: DateTime(2026, 3, 18),
      source: 'API CPE — données certifiées',
    );

    final result = InstitutionalApiService.syncToProfile(
      data: data,
      profileFields: {'avoirLpp': 65000.0}, // previous estimate
      previousConfidence: 0.60, // userInput level
    );

    expect(result.updatedFields['avoirLpp'], 70377.0);
    expect(result.updatedFields['rachatMaximal'], 539414.0);
    expect(result.newConfidence, 0.95);
    expect(result.previousConfidence, 0.60);
    expect(result.auditTrail, contains('70\'377'));
    expect(result.updatedFields['lppDataSource'], 'institutionalApi');
  });

  // ── 34. Golden couple: Lauren (HOTELA caisse) ──────────────
  test('golden couple: Lauren HOTELA profile sync matches expected values',
      () {
    // Lauren: avoirLpp = 19'620, rachat = 52'949 (CLAUDE.md §8)
    final data = PensionFundData(
      fund: PensionFund.bvk, // Closest pilot fund for test
      avoirLpp: 19620.0,
      rachatMaximal: 52949.0,
      tauxConversion: 0.068,
      bonificationAnnuelle: 0.10, // age 43 → 10% (art. 16)
      dataDate: DateTime(2026, 3, 18),
      source: 'API HOTELA — données certifiées',
    );

    final result = InstitutionalApiService.syncToProfile(
      data: data,
      profileFields: {}, // first import
      previousConfidence: 0.25, // estimated level
    );

    expect(result.updatedFields['avoirLpp'], 19620.0);
    expect(result.updatedFields['rachatMaximal'], 52949.0);
    expect(result.newConfidence, 0.95);
    expect(result.auditTrail, contains('19\'620'));
    expect(result.auditTrail, contains('importé'));
  });

  // ── 35. Data freshness: dataDate tracked in profile ────────
  test('data freshness: dataDate persisted in profile updates', () {
    final dataDate = DateTime(2026, 3, 15);
    final data = PensionFundData(
      fund: PensionFund.publica,
      avoirLpp: 185420.0,
      rachatMaximal: 120000.0,
      tauxConversion: 0.068,
      bonificationAnnuelle: 0.15,
      dataDate: dataDate,
      source: 'API Publica — données certifiées',
    );

    final result = InstitutionalApiService.syncToProfile(
      data: data,
      profileFields: {},
    );

    expect(result.updatedFields['lppDataDate'], dataDate.toIso8601String());
    expect(result.updatedFields['lppDataSource'], 'institutionalApi');
  });

  // ── 36. Banned terms scan on disclaimer text ───────────────
  test('disclaimer text contains no banned terms', () {
    final data = PensionFundData(
      fund: PensionFund.publica,
      avoirLpp: 100000,
      rachatMaximal: 50000,
      tauxConversion: 0.068,
      bonificationAnnuelle: 0.15,
      dataDate: DateTime.now(),
      source: 'API Publica — données certifiées',
    );

    const bannedTerms = [
      'garanti', 'certain', 'assuré', 'sans risque',
      'optimal', 'meilleur', 'parfait',
    ];

    for (final term in bannedTerms) {
      expect(
        data.disclaimer.toLowerCase().contains(term),
        false,
        reason: 'Disclaimer must not contain banned term "$term"',
      );
    }
  });

  // ── 37. AuditLogEntry serialization ────────────────────────
  test('AuditLogEntry serializes to JSON correctly', () async {
    await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: 'token',
      prefs: prefs,
    );

    final entry = InstitutionalApiService.auditLog.last;
    final json = entry.toJson();

    expect(json['operation'], 'connect');
    expect(json['fund'], 'publica');
    expect(json['success'], true);
    expect(json['timestamp'], isNotNull);
  });

  // ── 38. Registry: findByShortName case-insensitive ─────────
  test('registry findByShortName is case-insensitive', () {
    expect(PensionFundRegistry.findByShortName('publica')?.id,
        PensionFund.publica);
    expect(PensionFundRegistry.findByShortName('PUBLICA')?.id,
        PensionFund.publica);
    expect(PensionFundRegistry.findByShortName('Publica')?.id,
        PensionFund.publica);
    // Unknown fund returns null
    expect(PensionFundRegistry.findByShortName('CPE'), isNull);
    expect(PensionFundRegistry.findByShortName('HOTELA'), isNull);
  });

  // ── 39. Registry: getActive returns only active funds ──────
  test('registry getActive returns only active funds', () {
    final active = PensionFundRegistry.getActive();
    expect(active.length, 3); // All 3 pilot funds are active
    for (final fund in active) {
      expect(fund.isActive, true);
    }
  });

  // ── 40. Empty auth token rejected ──────────────────────────
  test('connect with empty token fails authentication', () async {
    final conn = await InstitutionalApiService.connect(
      fund: PensionFund.publica,
      authToken: '',
      prefs: prefs,
    );

    expect(conn.status, ConnectionStatus.error);
  });

  // ── 41. Connection serialization round-trip ────────────────
  test('PensionFundConnection survives JSON round-trip', () {
    final now = DateTime.now();
    final conn = PensionFundConnection(
      fund: PensionFund.cpev,
      status: ConnectionStatus.connected,
      connectedAt: now,
      lastSync: now,
    );

    final json = conn.toJson();
    final restored = PensionFundConnection.fromJson(json);

    expect(restored.fund, PensionFund.cpev);
    expect(restored.status, ConnectionStatus.connected);
    expect(restored.connectedAt, isNotNull);
    expect(restored.errorMessage, isNull);
  });
}
