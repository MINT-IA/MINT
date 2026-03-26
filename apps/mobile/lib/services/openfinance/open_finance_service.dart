// ────────────────────────────────────────────────────────────
//  OPEN FINANCE SERVICE — Sprint S73-S74 (bLink)
// ────────────────────────────────────────────────────────────
//
// Auto account aggregation via Swiss bLink/SFTI Open Finance APIs.
// Passive data enrichment (WHOOP-inspired): connected accounts
// auto-upgrade ConfidenceScore fields to openBanking (1.00).
//
// Compliance:
//   - ALL connections READ-ONLY (no money movement — CLAUDE.md §6)
//   - User consent required for every connection (nLPD art. 6)
//   - Consent revocable at any time → data immediately purged
//   - No transaction details stored — balances only
//   - Audit trail for every enrichment
//
// Sources: LPD art. 6, nLPD art. 5 let. f, LSFin art. 3
//
// ARCHITECTURAL NOTE (V12-5): SharedPreferences keys are global, not per-account.
// Account isolation relies on purge at logout/deleteAccount (auth_provider.dart).
// TODO: Prefix all keys with user ID for native multi-account isolation.
// ────────────────────────────────────────────────────────────

import 'dart:convert';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ════════════════════════════════════════════════════════════════
//  ENUMS
// ════════════════════════════════════════════════════════════════

/// Type of financial institution for Open Finance connection.
enum FinanceProvider {
  /// Checking / savings accounts (UBS, PostFinance, etc.)
  bank,

  /// Pillar 3a accounts (VIAC, frankly, finpension, etc.)
  pillar3a,

  /// LPP data from pension fund insurers
  insuranceLpp,

  /// Cantonal tax authority data
  taxAuthority,
}

/// How often data is synchronized.
enum SyncFrequency { realtime, daily, weekly, manual }

/// Status of a finance connection.
enum ConnectionStatus {
  /// Connection active and syncing.
  active,

  /// Connection pending user consent.
  pending,

  /// Connection failed (API error).
  error,

  /// Consent expired — needs renewal.
  expired,

  /// User revoked consent — data purged.
  revoked,
}

// ════════════════════════════════════════════════════════════════
//  DATA CLASSES
// ════════════════════════════════════════════════════════════════

/// A connected financial institution.
class FinanceConnection {
  final String id;
  final FinanceProvider type;
  final String institutionName;
  final ConnectionStatus status;
  final DateTime? lastSync;
  final SyncFrequency frequency;

  /// Data confidence: always 1.00 for openBanking-sourced data.
  final double dataConfidence;

  const FinanceConnection({
    required this.id,
    required this.type,
    required this.institutionName,
    required this.status,
    this.lastSync,
    this.frequency = SyncFrequency.daily,
    this.dataConfidence = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'institutionName': institutionName,
        'status': status.name,
        'lastSync': lastSync?.toIso8601String(),
        'frequency': frequency.name,
        'dataConfidence': dataConfidence,
      };

  factory FinanceConnection.fromJson(Map<String, dynamic> json) {
    return FinanceConnection(
      id: json['id'] as String,
      type: FinanceProvider.values.byName(json['type'] as String),
      institutionName: json['institutionName'] as String,
      status: ConnectionStatus.values.byName(json['status'] as String),
      lastSync: json['lastSync'] != null
          ? DateTime.parse(json['lastSync'] as String)
          : null,
      frequency: SyncFrequency.values.byName(json['frequency'] as String),
      dataConfidence: (json['dataConfidence'] as num).toDouble(),
    );
  }

  FinanceConnection copyWith({
    ConnectionStatus? status,
    DateTime? lastSync,
    SyncFrequency? frequency,
    double? dataConfidence,
  }) {
    return FinanceConnection(
      id: id,
      type: type,
      institutionName: institutionName,
      status: status ?? this.status,
      lastSync: lastSync ?? this.lastSync,
      frequency: frequency ?? this.frequency,
      dataConfidence: dataConfidence ?? this.dataConfidence,
    );
  }
}

/// A single data point retrieved from a connected institution.
class FinanceDataPoint {
  /// Profile field path, e.g. "patrimoine.epargneLiquide".
  final String fieldPath;

  /// The value retrieved.
  final double value;

  /// When the data was last confirmed by the source.
  final DateTime asOf;

  /// Human-readable source, e.g. "bLink API \u2014 UBS Compte \u00e9pargne".
  final String source;

  /// Always 1.00 for API-verified data.
  final double confidence;

  const FinanceDataPoint({
    required this.fieldPath,
    required this.value,
    required this.asOf,
    required this.source,
    this.confidence = 1.0,
  });

  Map<String, dynamic> toJson() => {
        'fieldPath': fieldPath,
        'value': value,
        'asOf': asOf.toIso8601String(),
        'source': source,
        'confidence': confidence,
      };

  factory FinanceDataPoint.fromJson(Map<String, dynamic> json) {
    return FinanceDataPoint(
      fieldPath: json['fieldPath'] as String,
      value: (json['value'] as num).toDouble(),
      asOf: DateTime.parse(json['asOf'] as String),
      source: json['source'] as String,
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}

/// Result of passive profile enrichment from connected data.
class EnrichmentResult {
  /// Fields that were updated: fieldPath -> new value.
  final Map<String, dynamic> updatedFields;

  /// Confidence upgrades: fieldPath -> new confidence (1.00).
  final Map<String, double> confidenceUpgrades;

  /// Audit trail describing old->new for each changed field.
  final String auditTrail;

  /// When the enrichment happened.
  final DateTime enrichedAt;

  /// Educational disclaimer (compliance — CLAUDE.md §6).
  final String disclaimer;

  const EnrichmentResult({
    required this.updatedFields,
    required this.confidenceUpgrades,
    required this.auditTrail,
    required this.enrichedAt,
    this.disclaimer =
        'Donn\u00e9es synchronis\u00e9es automatiquement \u2014 '
        'outil \u00e9ducatif, ne constitue pas un conseil financier (LSFin).',
  });
}

/// A discoverable financial institution.
class FinanceInstitution {
  final String id;
  final String name;
  final FinanceProvider type;

  /// Cantons where this institution operates.
  final List<String> supportedCantons;

  /// Whether the institution supports bLink/SFTI.
  final bool blinkCompatible;

  /// API version, if known.
  final String? apiVersion;

  const FinanceInstitution({
    required this.id,
    required this.name,
    required this.type,
    this.supportedCantons = const [],
    this.blinkCompatible = true,
    this.apiVersion,
  });
}

/// A consent record for an Open Finance connection.
class ConsentRecord {
  final String connectionId;
  final DateTime grantedAt;
  final DateTime? expiresAt;

  /// Data scopes: e.g. ['balance', 'identity'].
  final List<String> scopes;
  final bool isActive;

  const ConsentRecord({
    required this.connectionId,
    required this.grantedAt,
    this.expiresAt,
    this.scopes = const ['balance', 'identity'],
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'connectionId': connectionId,
        'grantedAt': grantedAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
        'scopes': scopes,
        'isActive': isActive,
      };

  factory ConsentRecord.fromJson(Map<String, dynamic> json) {
    return ConsentRecord(
      connectionId: json['connectionId'] as String,
      grantedAt: DateTime.parse(json['grantedAt'] as String),
      expiresAt: json['expiresAt'] != null
          ? DateTime.parse(json['expiresAt'] as String)
          : null,
      scopes: (json['scopes'] as List).cast<String>(),
      isActive: json['isActive'] as bool,
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  OPEN FINANCE SERVICE
// ════════════════════════════════════════════════════════════════

/// Open Finance aggregation service (bLink / SFTI).
///
/// Read-only, consent-first, nLPD-compliant.
/// All connections are mock until FINMA consultation is complete.
///
/// Connected data auto-upgrades [ProfileDataSource] to `openBanking`
/// (confidence 1.00) via [enrichProfile].
class OpenFinanceService {
  // ── Storage keys ──────────────────────────────────────────
  static const String _connectionsKey = '_openfinance_connections';
  static const String _consentsKey = '_openfinance_consents';
  static const String _dataPointsKey = '_openfinance_data_points';

  // ── Mock institution registry ─────────────────────────────

  static const List<FinanceInstitution> _mockInstitutions = [
    FinanceInstitution(
      id: 'ubs',
      name: 'UBS',
      type: FinanceProvider.bank,
      supportedCantons: [],
      apiVersion: 'bLink v2.1',
    ),
    FinanceInstitution(
      id: 'postfinance',
      name: 'PostFinance',
      type: FinanceProvider.bank,
      supportedCantons: [],
      apiVersion: 'bLink v2.0',
    ),
    FinanceInstitution(
      id: 'raiffeisen',
      name: 'Raiffeisen',
      type: FinanceProvider.bank,
      supportedCantons: [],
      apiVersion: 'bLink v2.1',
    ),
    FinanceInstitution(
      id: 'bcv',
      name: 'BCV',
      type: FinanceProvider.bank,
      supportedCantons: ['VD'],
      apiVersion: 'bLink v2.0',
    ),
    FinanceInstitution(
      id: 'bcge',
      name: 'BCGE',
      type: FinanceProvider.bank,
      supportedCantons: ['GE'],
      apiVersion: 'bLink v2.0',
    ),
    FinanceInstitution(
      id: 'zkb',
      name: 'ZKB',
      type: FinanceProvider.bank,
      supportedCantons: ['ZH'],
      apiVersion: 'bLink v2.1',
    ),
    FinanceInstitution(
      id: 'viac',
      name: 'VIAC',
      type: FinanceProvider.pillar3a,
      supportedCantons: [],
      apiVersion: 'bLink v2.0',
    ),
    FinanceInstitution(
      id: 'frankly',
      name: 'frankly',
      type: FinanceProvider.pillar3a,
      supportedCantons: [],
      apiVersion: 'bLink v2.0',
    ),
    FinanceInstitution(
      id: 'finpension',
      name: 'finpension',
      type: FinanceProvider.pillar3a,
      supportedCantons: [],
      apiVersion: 'bLink v2.0',
    ),
    FinanceInstitution(
      id: 'cpe',
      name: 'CPE (Caisse de pr\u00e9voyance)',
      type: FinanceProvider.insuranceLpp,
      supportedCantons: ['VS'],
      apiVersion: 'bLink v1.0',
      blinkCompatible: true,
    ),
    FinanceInstitution(
      id: 'hotela',
      name: 'HOTELA',
      type: FinanceProvider.insuranceLpp,
      supportedCantons: [],
      apiVersion: 'bLink v1.0',
      blinkCompatible: true,
    ),
  ];

  // ── Discovery ─────────────────────────────────────────────

  /// Returns available financial institutions, optionally filtered by canton.
  static Future<List<FinanceInstitution>> discoverInstitutions({
    String? canton,
  }) async {
    if (canton == null || canton.isEmpty) {
      return _mockInstitutions;
    }
    return _mockInstitutions
        .where((inst) =>
            inst.supportedCantons.isEmpty ||
            inst.supportedCantons.contains(canton))
        .toList();
  }

  // ── Connection ────────────────────────────────────────────

  /// Connect to a financial institution with user-granted consent.
  ///
  /// The [consentToken] proves the user explicitly approved the connection.
  /// Returns the new [FinanceConnection].
  static Future<FinanceConnection> connect({
    required FinanceProvider type,
    required String institutionId,
    required String consentToken,
    SharedPreferences? prefs,
  }) async {
    if (consentToken.isEmpty) {
      throw ArgumentError(
          'Consentement requis pour toute connexion (nLPD art.\u00a06).');
    }

    // Validate institution exists
    final institution = _mockInstitutions.where((i) => i.id == institutionId);
    if (institution.isEmpty) {
      throw ArgumentError('Institution inconnue\u00a0: $institutionId');
    }

    final now = DateTime.now();
    final connectionId = 'conn_${institutionId}_${now.millisecondsSinceEpoch}';

    // SAFETY: mock connections use system_estimate confidence (V6-5 audit fix).
    final connection = FinanceConnection(
      id: connectionId,
      type: type,
      institutionName: institution.first.name,
      status: ConnectionStatus.active,
      lastSync: now,
      frequency: SyncFrequency.daily,
      dataConfidence: _mockDataConfidence,
    );

    final consent = ConsentRecord(
      connectionId: connectionId,
      grantedAt: now,
      expiresAt: now.add(const Duration(days: 90)),
      scopes: const ['balance', 'identity'],
      isActive: true,
    );

    // Persist
    if (prefs != null) {
      await _saveConnection(prefs, connection);
      await _saveConsent(prefs, consent);
    }

    return connection;
  }

  /// Disconnect a financial institution and purge its data.
  static Future<void> disconnect({
    required String connectionId,
    SharedPreferences? prefs,
  }) async {
    if (prefs == null) return;

    // Remove connection
    final connections = await _loadConnections(prefs);
    connections.removeWhere((c) => c.id == connectionId);
    await _persistConnections(prefs, connections);

    // Revoke consent
    final consents = await _loadConsents(prefs);
    consents.removeWhere((c) => c.connectionId == connectionId);
    await _persistConsents(prefs, consents);

    // Purge data points
    final dataPoints = await _loadDataPoints(prefs);
    dataPoints.removeWhere((dp) => dp.source.contains(connectionId));
    await _persistDataPoints(prefs, dataPoints);
  }

  /// Revoke ALL consents and purge ALL Open Finance data.
  static Future<void> revokeAllConsents({SharedPreferences? prefs}) async {
    if (prefs == null) return;

    await prefs.remove(_connectionsKey);
    await prefs.remove(_consentsKey);
    await prefs.remove(_dataPointsKey);
  }

  // ── Data sync ─────────────────────────────────────────────

  /// Sync data from a connected institution.
  ///
  /// Returns data points with confidence = 1.00 (openBanking).
  /// Privacy: only balances, never transaction details.
  static Future<List<FinanceDataPoint>> sync({
    required String connectionId,
    SharedPreferences? prefs,
  }) async {
    // Validate connection exists and is active
    if (prefs != null) {
      final connections = await _loadConnections(prefs);
      final conn = connections.where((c) => c.id == connectionId);
      if (conn.isEmpty) {
        throw StateError('Connexion introuvable\u00a0: $connectionId');
      }
      if (conn.first.status != ConnectionStatus.active) {
        throw StateError(
            'Connexion inactive (statut\u00a0: ${conn.first.status.name})');
      }

      // Check consent expiry
      final consents = await _loadConsents(prefs);
      final consent =
          consents.where((c) => c.connectionId == connectionId);
      if (consent.isNotEmpty && consent.first.expiresAt != null) {
        if (DateTime.now().isAfter(consent.first.expiresAt!)) {
          // Mark connection as expired
          final idx = connections.indexWhere((c) => c.id == connectionId);
          if (idx >= 0) {
            connections[idx] =
                connections[idx].copyWith(status: ConnectionStatus.expired);
            await _persistConnections(prefs, connections);
          }
          throw StateError(
              'Consentement expir\u00e9 \u2014 renouvellement n\u00e9cessaire.');
        }
      }
    }

    final now = DateTime.now();

    // Mock data points based on connection ID pattern
    final dataPoints = _generateMockDataPoints(connectionId, now);

    // Persist data points
    if (prefs != null) {
      final existing = await _loadDataPoints(prefs);
      // Replace old data for same source
      existing.removeWhere(
          (dp) => dp.source.contains(connectionId));
      existing.addAll(dataPoints);
      await _persistDataPoints(prefs, existing);

      // Update lastSync on connection
      final connections = await _loadConnections(prefs);
      final idx = connections.indexWhere((c) => c.id == connectionId);
      if (idx >= 0) {
        connections[idx] = connections[idx].copyWith(lastSync: now);
        await _persistConnections(prefs, connections);
      }
    }

    return dataPoints;
  }

  // ── Passive enrichment (WHOOP-style) ──────────────────────

  /// Enrich a [CoachProfile] with connected data points.
  ///
  /// Auto-upgrades confidence from userInput (0.60) to openBanking (1.00).
  /// Returns an [EnrichmentResult] with audit trail.
  static Future<EnrichmentResult> enrichProfile({
    required CoachProfile profile,
    required List<FinanceDataPoint> dataPoints,
  }) async {
    final updatedFields = <String, dynamic>{};
    final confidenceUpgrades = <String, double>{};
    final auditLines = <String>[];
    final now = DateTime.now();

    for (final dp in dataPoints) {
      final oldValue = _resolveFieldValue(profile, dp.fieldPath);
      updatedFields[dp.fieldPath] = dp.value;
      confidenceUpgrades[dp.fieldPath] = dp.confidence; // 1.00

      auditLines.add(
        '${dp.fieldPath}\u00a0: '
        '${oldValue != null ? oldValue.toStringAsFixed(0) : "n/a"} '
        '\u2192 ${dp.value.toStringAsFixed(0)} '
        '(source\u00a0: ${dp.source}, '
        'confiance\u00a0: ${dp.confidence})',
      );
    }

    return EnrichmentResult(
      updatedFields: updatedFields,
      confidenceUpgrades: confidenceUpgrades,
      auditTrail: auditLines.join('\n'),
      enrichedAt: now,
    );
  }

  // ── Connection listing ────────────────────────────────────

  /// List all active connections.
  static Future<List<FinanceConnection>> listConnections({
    SharedPreferences? prefs,
  }) async {
    if (prefs == null) return [];
    return _loadConnections(prefs);
  }

  // ── Consent management ────────────────────────────────────

  /// Get consent record for a connection.
  static Future<ConsentRecord> getConsent({
    required String connectionId,
    SharedPreferences? prefs,
  }) async {
    if (prefs == null) {
      throw StateError('Aucun stockage disponible.');
    }

    final consents = await _loadConsents(prefs);
    final match = consents.where((c) => c.connectionId == connectionId);
    if (match.isEmpty) {
      throw StateError(
          'Aucun consentement trouv\u00e9 pour $connectionId');
    }

    final consent = match.first;

    // Check expiry
    if (consent.expiresAt != null &&
        DateTime.now().isAfter(consent.expiresAt!)) {
      return ConsentRecord(
        connectionId: consent.connectionId,
        grantedAt: consent.grantedAt,
        expiresAt: consent.expiresAt,
        scopes: consent.scopes,
        isActive: false,
      );
    }

    return consent;
  }

  // ════════════════════════════════════════════════════════════
  //  PRIVATE HELPERS
  // ════════════════════════════════════════════════════════════

  /// Resolve a profile field value from its dotted path.
  static double? _resolveFieldValue(CoachProfile profile, String fieldPath) {
    switch (fieldPath) {
      case 'patrimoine.epargneLiquide':
        return profile.patrimoine.epargneLiquide;
      case 'prevoyance.avoirLppTotal':
        return profile.prevoyance.avoirLppTotal;
      case 'prevoyance.totalEpargne3a':
        return profile.prevoyance.totalEpargne3a;
      case 'patrimoine.capitalLibre':
        return profile.patrimoine.investissements;
      default:
        return null;
    }
  }

  /// SAFETY: mock data must never claim openBanking confidence (V6-5 audit fix).
  /// Mock data is capped at 0.25 (system_estimate level) to prevent
  /// mock values from being treated as verified openBanking data.
  static const double _mockDataConfidence = 0.25;

  /// Generate mock data points for a connection (balances only).
  static List<FinanceDataPoint> _generateMockDataPoints(
    String connectionId,
    DateTime now,
  ) {
    // Determine institution from connection ID
    if (connectionId.contains('ubs') ||
        connectionId.contains('postfinance') ||
        connectionId.contains('raiffeisen') ||
        connectionId.contains('bcv') ||
        connectionId.contains('bcge') ||
        connectionId.contains('zkb')) {
      return [
        FinanceDataPoint(
          fieldPath: 'patrimoine.epargneLiquide',
          value: 45230.0,
          asOf: now,
          source: 'bLink API \u2014 $connectionId (mock)',
          confidence: _mockDataConfidence,
        ),
      ];
    }
    if (connectionId.contains('viac') ||
        connectionId.contains('frankly') ||
        connectionId.contains('finpension')) {
      return [
        FinanceDataPoint(
          fieldPath: 'prevoyance.totalEpargne3a',
          value: 32000.0,
          asOf: now,
          source: 'bLink API \u2014 $connectionId (mock)',
          confidence: _mockDataConfidence,
        ),
      ];
    }
    if (connectionId.contains('cpe') || connectionId.contains('hotela')) {
      return [
        FinanceDataPoint(
          fieldPath: 'prevoyance.avoirLppTotal',
          value: 70377.0,
          asOf: now,
          source: 'bLink API \u2014 $connectionId (mock)',
          confidence: _mockDataConfidence,
        ),
      ];
    }
    // Fallback
    return [
      FinanceDataPoint(
        fieldPath: 'patrimoine.capitalLibre',
        value: 10000.0,
        asOf: now,
        source: 'bLink API \u2014 $connectionId (mock)',
        confidence: _mockDataConfidence,
      ),
    ];
  }

  // ── Persistence helpers ───────────────────────────────────

  static Future<void> _saveConnection(
    SharedPreferences prefs,
    FinanceConnection connection,
  ) async {
    final connections = await _loadConnections(prefs);
    connections.add(connection);
    await _persistConnections(prefs, connections);
  }

  static Future<List<FinanceConnection>> _loadConnections(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_connectionsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => FinanceConnection.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _persistConnections(
    SharedPreferences prefs,
    List<FinanceConnection> connections,
  ) async {
    await prefs.setString(
      _connectionsKey,
      jsonEncode(connections.map((c) => c.toJson()).toList()),
    );
  }

  static Future<void> _saveConsent(
    SharedPreferences prefs,
    ConsentRecord consent,
  ) async {
    final consents = await _loadConsents(prefs);
    consents.add(consent);
    await _persistConsents(prefs, consents);
  }

  static Future<List<ConsentRecord>> _loadConsents(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_consentsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => ConsentRecord.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _persistConsents(
    SharedPreferences prefs,
    List<ConsentRecord> consents,
  ) async {
    await prefs.setString(
      _consentsKey,
      jsonEncode(consents.map((c) => c.toJson()).toList()),
    );
  }

  static Future<List<FinanceDataPoint>> _loadDataPoints(
    SharedPreferences prefs,
  ) async {
    final raw = prefs.getString(_dataPointsKey);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => FinanceDataPoint.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> _persistDataPoints(
    SharedPreferences prefs,
    List<FinanceDataPoint> dataPoints,
  ) async {
    await prefs.setString(
      _dataPointsKey,
      jsonEncode(dataPoints.map((dp) => dp.toJson()).toList()),
    );
  }
}
