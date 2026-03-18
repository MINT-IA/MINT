// ────────────────────────────────────────────────────────────
//  INSTITUTIONAL API SERVICE — Sprint S69-S70
// ────────────────────────────────────────────────────────────
//
// Direct connections with pilot pension funds (Publica, BVK, CPEV).
// Real-time balance retrieval with ConfidenceScore = 0.95
// for connected institutional data (certificate-grade, CLAUDE.md §5).
//
// Compliance:
// - READ-ONLY: no money movement (CLAUDE.md §6)
// - Auth tokens encrypted before storage
// - Audit trail for ALL API calls (connect, fetch, checkStatus)
// - No banned terms in user-facing text
// - Disclaimer + legal sources on all output (CLAUDE.md §6)
// - Graceful degradation: cached data when API unavailable
// ────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'pension_fund_registry.dart';

// ────────────────────────────────────────────────────────────
//  CONNECTION STATUS
// ────────────────────────────────────────────────────────────

/// Status of an institutional API connection.
enum ConnectionStatus {
  /// No connection established.
  disconnected,

  /// Connection in progress (OAuth flow).
  connecting,

  /// Successfully connected and syncing.
  connected,

  /// Connection failed (network, auth, or server error).
  error,

  /// Auth token has expired — re-authentication needed.
  expired,
}

// ────────────────────────────────────────────────────────────
//  PENSION FUND CONNECTION
// ────────────────────────────────────────────────────────────

/// Represents a connection to a pension fund's institutional API.
class PensionFundConnection {
  final PensionFund fund;
  final ConnectionStatus status;
  final DateTime? connectedAt;
  final DateTime? lastSync;
  final String? errorMessage;

  const PensionFundConnection({
    required this.fund,
    required this.status,
    this.connectedAt,
    this.lastSync,
    this.errorMessage,
  });

  /// Serialise for SharedPreferences storage.
  Map<String, dynamic> toJson() => {
        'fund': fund.name,
        'status': status.name,
        if (connectedAt != null) 'connectedAt': connectedAt!.toIso8601String(),
        if (lastSync != null) 'lastSync': lastSync!.toIso8601String(),
        if (errorMessage != null) 'errorMessage': errorMessage,
      };

  factory PensionFundConnection.fromJson(Map<String, dynamic> json) {
    return PensionFundConnection(
      fund: PensionFund.values.firstWhere((f) => f.name == json['fund']),
      status:
          ConnectionStatus.values.firstWhere((s) => s.name == json['status']),
      connectedAt: json['connectedAt'] != null
          ? DateTime.parse(json['connectedAt'] as String)
          : null,
      lastSync: json['lastSync'] != null
          ? DateTime.parse(json['lastSync'] as String)
          : null,
      errorMessage: json['errorMessage'] as String?,
    );
  }
}

// ────────────────────────────────────────────────────────────
//  PENSION FUND DATA
// ────────────────────────────────────────────────────────────

/// Certified pension fund data retrieved via institutional API.
class PensionFundData {
  /// Which fund this data comes from.
  final PensionFund fund;

  /// Current LPP balance (avoir de vieillesse).
  final double avoirLpp;

  /// Maximum buy-back (rachat) amount.
  final double rachatMaximal;

  /// Applicable conversion rate (typically 6.8% BVG minimum).
  final double tauxConversion;

  /// Annual credit rate (bonification annuelle).
  final double bonificationAnnuelle;

  /// Date the data was last updated at the fund.
  final DateTime dataDate;

  /// 0.95 for institutional data — certificate-grade (CLAUDE.md §5).
  /// Only openBanking = 1.00. Certificate/institutional = 0.95.
  final double confidenceScore;

  /// Human-readable source label.
  final String source;

  /// Legal disclaimer (required on all service output — CLAUDE.md §6).
  final String disclaimer;

  /// Legal source references (LPP art. X, etc.).
  final List<String> sources;

  const PensionFundData({
    required this.fund,
    required this.avoirLpp,
    required this.rachatMaximal,
    required this.tauxConversion,
    required this.bonificationAnnuelle,
    required this.dataDate,
    this.confidenceScore = 0.95,
    required this.source,
    this.disclaimer = 'Outil éducatif — ne constitue pas un conseil financier (LSFin). '
        'Données transmises par la caisse de pensions à titre informatif.',
    this.sources = const ['LPP art. 14-16', 'OPP2 art. 5'],
  });

  Map<String, dynamic> toJson() => {
        'fund': fund.name,
        'avoirLpp': avoirLpp,
        'rachatMaximal': rachatMaximal,
        'tauxConversion': tauxConversion,
        'bonificationAnnuelle': bonificationAnnuelle,
        'dataDate': dataDate.toIso8601String(),
        'confidenceScore': confidenceScore,
        'source': source,
        'disclaimer': disclaimer,
        'sources': sources,
      };

  factory PensionFundData.fromJson(Map<String, dynamic> json) {
    return PensionFundData(
      fund: PensionFund.values.firstWhere((f) => f.name == json['fund']),
      avoirLpp: (json['avoirLpp'] as num).toDouble(),
      rachatMaximal: (json['rachatMaximal'] as num).toDouble(),
      tauxConversion: (json['tauxConversion'] as num).toDouble(),
      bonificationAnnuelle: (json['bonificationAnnuelle'] as num).toDouble(),
      dataDate: DateTime.parse(json['dataDate'] as String),
      confidenceScore: (json['confidenceScore'] as num?)?.toDouble() ?? 0.95,
      source: json['source'] as String,
      disclaimer: json['disclaimer'] as String? ??
          'Outil éducatif — ne constitue pas un conseil financier (LSFin).',
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const ['LPP art. 14-16', 'OPP2 art. 5'],
    );
  }
}

// ────────────────────────────────────────────────────────────
//  PROFILE UPDATE RESULT
// ────────────────────────────────────────────────────────────

/// Result of syncing institutional data into the user profile.
class ProfileUpdateResult {
  /// Fields that were updated (field name → new value).
  final Map<String, dynamic> updatedFields;

  /// Confidence before sync.
  final double previousConfidence;

  /// Confidence after sync (should be 1.00 for certified data).
  final double newConfidence;

  /// Audit trail message describing what changed.
  final String auditTrail;

  const ProfileUpdateResult({
    required this.updatedFields,
    required this.previousConfidence,
    required this.newConfidence,
    required this.auditTrail,
  });
}

// ────────────────────────────────────────────────────────────
//  MOCK BACKEND (for testing — no real API calls)
// ────────────────────────────────────────────────────────────

/// Abstract backend for pension fund API calls.
/// Production: real HTTP calls. Testing: mock backend.
abstract class PensionFundBackend {
  /// Authenticate and establish connection.
  Future<bool> authenticate(PensionFund fund, String authToken);

  /// Fetch latest fund data.
  Future<PensionFundData> fetchFundData(PensionFund fund);

  /// Check if token is still valid.
  Future<bool> isTokenValid(PensionFund fund, String encryptedToken);
}

/// Mock backend for testing — returns deterministic data.
class MockPensionFundBackend implements PensionFundBackend {
  bool shouldFailAuth;
  bool shouldFailFetch;
  bool shouldReturnExpired;

  MockPensionFundBackend({
    this.shouldFailAuth = false,
    this.shouldFailFetch = false,
    this.shouldReturnExpired = false,
  });

  @override
  Future<bool> authenticate(PensionFund fund, String authToken) async {
    if (shouldFailAuth) return false;
    return authToken.isNotEmpty;
  }

  @override
  Future<PensionFundData> fetchFundData(PensionFund fund) async {
    if (shouldFailFetch) {
      throw Exception('Erreur réseau\u00a0: impossible de joindre le serveur');
    }

    final info = PensionFundRegistry.getInfo(fund);
    // Deterministic test data per fund
    switch (fund) {
      case PensionFund.publica:
        return PensionFundData(
          fund: fund,
          avoirLpp: 185420.0,
          rachatMaximal: 120000.0,
          tauxConversion: 0.068,
          bonificationAnnuelle: 0.15,
          dataDate: DateTime.now(),
          confidenceScore: 0.95,
          source: 'API ${info.shortName} — données certifiées',
        );
      case PensionFund.bvk:
        return PensionFundData(
          fund: fund,
          avoirLpp: 95300.0,
          rachatMaximal: 250000.0,
          tauxConversion: 0.068,
          bonificationAnnuelle: 0.10,
          dataDate: DateTime.now(),
          confidenceScore: 0.95,
          source: 'API ${info.shortName} — données certifiées',
        );
      case PensionFund.cpev:
        return PensionFundData(
          fund: fund,
          avoirLpp: 142750.0,
          rachatMaximal: 180000.0,
          tauxConversion: 0.068,
          bonificationAnnuelle: 0.18,
          dataDate: DateTime.now(),
          confidenceScore: 0.95,
          source: 'API ${info.shortName} — données certifiées',
        );
    }
  }

  @override
  Future<bool> isTokenValid(PensionFund fund, String encryptedToken) async {
    if (shouldReturnExpired) return false;
    return encryptedToken.isNotEmpty;
  }
}

// ────────────────────────────────────────────────────────────
//  TOKEN ENCRYPTION (simple XOR obfuscation for MVP)
// ────────────────────────────────────────────────────────────

/// Simple token obfuscation for SharedPreferences storage.
///
/// NOTE: Production should use platform keychain (Keychain on iOS,
/// EncryptedSharedPreferences on Android). This XOR obfuscation
/// prevents plain-text storage but is not cryptographically secure.
class _TokenEncryptor {
  static const _key = 'M1NT_S3CUR3_K3Y_2026';

  static String encrypt(String plainText) {
    final keyBytes = utf8.encode(_key);
    final textBytes = utf8.encode(plainText);
    final encrypted = List<int>.generate(
      textBytes.length,
      (i) => textBytes[i] ^ keyBytes[i % keyBytes.length],
    );
    return base64Encode(encrypted);
  }

  static String decrypt(String encoded) {
    final keyBytes = utf8.encode(_key);
    final encrypted = base64Decode(encoded);
    final decrypted = List<int>.generate(
      encrypted.length,
      (i) => encrypted[i] ^ keyBytes[i % keyBytes.length],
    );
    return utf8.decode(decrypted);
  }
}

// ────────────────────────────────────────────────────────────
//  SHARED PREFERENCES KEYS
// ────────────────────────────────────────────────────────────

class _Keys {
  static String connection(PensionFund fund) =>
      'institutional_connection_${fund.name}';
  static String token(PensionFund fund) =>
      'institutional_token_${fund.name}';
  static String lastRefresh(PensionFund fund) =>
      'institutional_last_refresh_${fund.name}';
  static String cachedData(PensionFund fund) =>
      'institutional_data_${fund.name}';
}

// ────────────────────────────────────────────────────────────
//  INSTITUTIONAL API SERVICE
// ────────────────────────────────────────────────────────────

/// Audit log entry for institutional API operations.
class AuditLogEntry {
  final DateTime timestamp;
  final String operation;
  final PensionFund fund;
  final bool success;
  final String? detail;

  const AuditLogEntry({
    required this.timestamp,
    required this.operation,
    required this.fund,
    required this.success,
    this.detail,
  });

  Map<String, dynamic> toJson() => {
        'timestamp': timestamp.toIso8601String(),
        'operation': operation,
        'fund': fund.name,
        'success': success,
        if (detail != null) 'detail': detail,
      };
}

/// Service for managing institutional pension fund API connections.
///
/// Compliance:
/// - Read-only: no write operations to the fund (CLAUDE.md §6).
/// - Auth tokens encrypted before SharedPreferences storage.
/// - Confidence = 0.95 for all institutional data (certificate-grade).
/// - Auto-refresh rate-limited to once per day.
/// - Full audit trail on ALL API calls.
/// - Disclaimer + legal sources on all output.
/// - Graceful degradation: cached data when API unavailable.
class InstitutionalApiService {
  /// Inject a custom backend (for testing). Defaults to mock.
  static PensionFundBackend _backend = MockPensionFundBackend();

  /// In-memory audit log for all API operations.
  static final List<AuditLogEntry> _auditLog = [];

  /// Get the audit log (read-only copy).
  static List<AuditLogEntry> get auditLog => List.unmodifiable(_auditLog);

  /// Clear audit log (for testing).
  static void clearAuditLog() => _auditLog.clear();

  /// Replace the backend (useful for testing or production HTTP client).
  static void setBackend(PensionFundBackend backend) {
    _backend = backend;
  }

  /// Minimum interval between auto-refreshes (24 hours).
  static const _refreshCooldown = Duration(hours: 24);

  /// Log an audit entry.
  static void _log(String operation, PensionFund fund, bool success,
      [String? detail]) {
    _auditLog.add(AuditLogEntry(
      timestamp: DateTime.now(),
      operation: operation,
      fund: fund,
      success: success,
      detail: detail,
    ));
  }

  // ── Connection management ──────────────────────────────────

  /// Connect to a pension fund using an OAuth2 token.
  ///
  /// Stores the connection state and encrypted token in SharedPreferences.
  static Future<PensionFundConnection> connect({
    required PensionFund fund,
    required String authToken,
    SharedPreferences? prefs,
  }) async {
    prefs ??= await SharedPreferences.getInstance();

    // Attempt authentication
    final success = await _backend.authenticate(fund, authToken);
    if (!success) {
      _log('connect', fund, false, 'Authentication failed');
      final conn = PensionFundConnection(
        fund: fund,
        status: ConnectionStatus.error,
        errorMessage: 'Échec d\u2019authentification auprès de la caisse',
      );
      await prefs.setString(_Keys.connection(fund), jsonEncode(conn.toJson()));
      return conn;
    }

    // Store encrypted token
    final encryptedToken = _TokenEncryptor.encrypt(authToken);
    await prefs.setString(_Keys.token(fund), encryptedToken);

    // Store connection
    final now = DateTime.now();
    final conn = PensionFundConnection(
      fund: fund,
      status: ConnectionStatus.connected,
      connectedAt: now,
      lastSync: now,
    );
    await prefs.setString(_Keys.connection(fund), jsonEncode(conn.toJson()));

    _log('connect', fund, true, 'Connected successfully');
    return conn;
  }

  /// Disconnect from a pension fund and remove all stored data.
  static Future<void> disconnect({
    required PensionFund fund,
    SharedPreferences? prefs,
  }) async {
    prefs ??= await SharedPreferences.getInstance();
    await prefs.remove(_Keys.connection(fund));
    await prefs.remove(_Keys.token(fund));
    await prefs.remove(_Keys.lastRefresh(fund));
    await prefs.remove(_Keys.cachedData(fund));
    _log('disconnect', fund, true, 'All stored data removed');
  }

  /// Check the current connection status for a fund.
  ///
  /// If a token exists, validates it against the backend.
  /// Returns [ConnectionStatus.expired] if the token is no longer valid.
  static Future<ConnectionStatus> checkStatus({
    required PensionFund fund,
    SharedPreferences? prefs,
  }) async {
    prefs ??= await SharedPreferences.getInstance();

    final connJson = prefs.getString(_Keys.connection(fund));
    if (connJson == null) {
      _log('checkStatus', fund, true, 'No connection found');
      return ConnectionStatus.disconnected;
    }

    final conn =
        PensionFundConnection.fromJson(jsonDecode(connJson) as Map<String, dynamic>);
    if (conn.status != ConnectionStatus.connected) {
      _log('checkStatus', fund, true, 'Status: ${conn.status.name}');
      return conn.status;
    }

    // Validate token is still active
    final encryptedToken = prefs.getString(_Keys.token(fund));
    if (encryptedToken == null || encryptedToken.isEmpty) {
      _log('checkStatus', fund, false, 'Token missing');
      return ConnectionStatus.expired;
    }

    final valid = await _backend.isTokenValid(fund, encryptedToken);
    if (!valid) {
      _log('checkStatus', fund, false, 'Token expired');
      // Update stored status to expired
      final expired = PensionFundConnection(
        fund: fund,
        status: ConnectionStatus.expired,
        connectedAt: conn.connectedAt,
        lastSync: conn.lastSync,
        errorMessage: 'Le jeton d\u2019accès a expiré — reconnexion nécessaire',
      );
      await prefs.setString(
          _Keys.connection(fund), jsonEncode(expired.toJson()));
      return ConnectionStatus.expired;
    }

    _log('checkStatus', fund, true, 'Token valid');
    return ConnectionStatus.connected;
  }

  // ── Data retrieval ─────────────────────────────────────────

  /// Fetch the latest pension fund data from the institutional API.
  ///
  /// Rate-limited to one refresh per 24 hours. Returns cached data
  /// if a recent fetch exists and [forceRefresh] is false.
  static Future<PensionFundData> fetchData({
    required PensionFund fund,
    SharedPreferences? prefs,
    bool forceRefresh = false,
  }) async {
    prefs ??= await SharedPreferences.getInstance();

    // Check rate limit
    if (!forceRefresh) {
      final lastRefreshMs = prefs.getInt(_Keys.lastRefresh(fund));
      if (lastRefreshMs != null) {
        final lastRefresh =
            DateTime.fromMillisecondsSinceEpoch(lastRefreshMs);
        if (DateTime.now().difference(lastRefresh) < _refreshCooldown) {
          // Return cached data if available
          final cached = prefs.getString(_Keys.cachedData(fund));
          if (cached != null) {
            return PensionFundData.fromJson(
                jsonDecode(cached) as Map<String, dynamic>);
          }
        }
      }
    }

    // Fetch from backend with graceful degradation
    PensionFundData data;
    try {
      data = await _backend.fetchFundData(fund);
      _log('fetchData', fund, true, 'Fresh data fetched');
    } catch (e) {
      _log('fetchData', fund, false, 'API error: $e');
      // Graceful degradation: return cached data if available
      final cached = prefs.getString(_Keys.cachedData(fund));
      if (cached != null) {
        _log('fetchData', fund, true, 'Returning cached data (API unavailable)');
        return PensionFundData.fromJson(
            jsonDecode(cached) as Map<String, dynamic>);
      }
      // No cache available — rethrow
      rethrow;
    }

    // Cache result
    await prefs.setString(_Keys.cachedData(fund), jsonEncode(data.toJson()));
    await prefs.setInt(
        _Keys.lastRefresh(fund), DateTime.now().millisecondsSinceEpoch);

    // Update connection last sync
    final connJson = prefs.getString(_Keys.connection(fund));
    if (connJson != null) {
      final conn = PensionFundConnection.fromJson(
          jsonDecode(connJson) as Map<String, dynamic>);
      final updated = PensionFundConnection(
        fund: fund,
        status: conn.status,
        connectedAt: conn.connectedAt,
        lastSync: DateTime.now(),
      );
      await prefs.setString(
          _Keys.connection(fund), jsonEncode(updated.toJson()));
    }

    return data;
  }

  // ── Profile sync ───────────────────────────────────────────

  /// Sync institutional data into a profile map.
  ///
  /// Returns a [ProfileUpdateResult] with audit trail, updated fields,
  /// and confidence deltas.
  ///
  /// This method operates on a generic Map to avoid tight coupling
  /// with CoachProfile (which may be provided by the caller).
  static ProfileUpdateResult syncToProfile({
    required PensionFundData data,
    required Map<String, dynamic> profileFields,
    double previousConfidence = 0.60,
  }) {
    final updates = <String, dynamic>{};
    final trailParts = <String>[];
    final info = PensionFundRegistry.getInfo(data.fund);

    // Update LPP balance
    final oldAvoir = profileFields['avoirLpp'] as double?;
    updates['avoirLpp'] = data.avoirLpp;
    if (oldAvoir != null) {
      trailParts.add(
        'Avoir LPP mis à jour depuis ${info.shortName}\u00a0: '
        'CHF ${_formatAmount(oldAvoir)} → ${_formatAmount(data.avoirLpp)}',
      );
    } else {
      trailParts.add(
        'Avoir LPP importé depuis ${info.shortName}\u00a0: '
        'CHF ${_formatAmount(data.avoirLpp)}',
      );
    }

    // Update rachat maximal
    final oldRachat = profileFields['rachatMaximal'] as double?;
    updates['rachatMaximal'] = data.rachatMaximal;
    if (oldRachat != null) {
      trailParts.add(
        'Rachat maximal mis à jour\u00a0: '
        'CHF ${_formatAmount(oldRachat)} → ${_formatAmount(data.rachatMaximal)}',
      );
    } else {
      trailParts.add(
        'Rachat maximal importé\u00a0: CHF ${_formatAmount(data.rachatMaximal)}',
      );
    }

    // Update conversion rate
    updates['tauxConversion'] = data.tauxConversion;
    trailParts.add(
      'Taux de conversion\u00a0: ${(data.tauxConversion * 100).toStringAsFixed(1)}\u00a0%',
    );

    // Update bonification rate
    updates['bonificationAnnuelle'] = data.bonificationAnnuelle;

    // Mark data source as institutional
    updates['lppDataSource'] = 'institutionalApi';
    updates['lppDataDate'] = data.dataDate.toIso8601String();
    updates['disclaimer'] = data.disclaimer;
    updates['sources'] = data.sources;

    return ProfileUpdateResult(
      updatedFields: updates,
      previousConfidence: previousConfidence,
      newConfidence: data.confidenceScore, // 0.95 (certificate-grade)
      auditTrail: trailParts.join(' | '),
    );
  }

  // ── List all connections ───────────────────────────────────

  /// Returns the connection state for all registered pension funds.
  static Future<List<PensionFundConnection>> listConnections({
    SharedPreferences? prefs,
  }) async {
    prefs ??= await SharedPreferences.getInstance();
    final connections = <PensionFundConnection>[];

    for (final fund in PensionFund.values) {
      final connJson = prefs.getString(_Keys.connection(fund));
      if (connJson != null) {
        connections.add(PensionFundConnection.fromJson(
            jsonDecode(connJson) as Map<String, dynamic>));
      } else {
        connections.add(PensionFundConnection(
          fund: fund,
          status: ConnectionStatus.disconnected,
        ));
      }
    }

    return connections;
  }

  // ── Helpers ────────────────────────────────────────────────

  /// Format amount with apostrophe separator (Swiss convention).
  static String _formatAmount(double amount) {
    final rounded = amount.round();
    final str = rounded.toString();
    final buffer = StringBuffer();
    var count = 0;
    for (var i = str.length - 1; i >= 0; i--) {
      if (count > 0 && count % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
      count++;
    }
    return buffer.toString().split('').reversed.join();
  }

  /// Check if a stored token is plain text (not encrypted).
  /// Used for compliance validation.
  static Future<bool> isTokenEncrypted({
    required PensionFund fund,
    SharedPreferences? prefs,
  }) async {
    prefs ??= await SharedPreferences.getInstance();
    final stored = prefs.getString(_Keys.token(fund));
    if (stored == null) return true; // No token = no issue
    // Encrypted tokens are base64 and can be round-trip decrypted
    try {
      final decrypted = _TokenEncryptor.decrypt(stored);
      return decrypted != stored; // If decrypted differs, it was encrypted
    } catch (_) {
      return false; // Decode failure = likely plain text
    }
  }
}
