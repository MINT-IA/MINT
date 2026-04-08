import 'dart:math';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_sqlcipher/sqflite.dart' as sqflite;

import 'package:mint_mobile/services/biography/biography_fact.dart';

// ────────────────────────────────────────────────────────────
//  BIOGRAPHY REPOSITORY — Phase 03 / Memoire Narrative
// ────────────────────────────────────────────────────────────
//
// Encrypted local SQLite CRUD for FinancialBiography facts.
//
// Security:
// - Database encrypted with AES-256-CBC via sqflite_sqlcipher
// - Encryption key stored in flutter_secure_storage (hardware-backed)
// - All queries use parameterized ? placeholders (SQL injection prevention)
// - Soft delete by default; hard delete for privacy screen (GDPR/nLPD)
//
// See: BIO-02, T-03-01, T-03-02 requirements.
// ────────────────────────────────────────────────────────────

/// Abstract database interface for testability.
///
/// In production, backed by sqflite_sqlcipher encrypted database.
/// In tests, backed by an in-memory implementation.
abstract class BiographyDatabase {
  Future<void> execute(String sql, [List<Object?>? arguments]);
  Future<List<Map<String, Object?>>> rawQuery(String sql,
      [List<Object?>? arguments]);
  Future<int> rawInsert(String sql, [List<Object?>? arguments]);
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]);
  Future<int> rawDelete(String sql, [List<Object?>? arguments]);
  Future<void> close();
}

/// Encrypted local repository for FinancialBiography facts.
///
/// Uses sqflite_sqlcipher for AES-256 encryption at rest.
/// Key management via FlutterSecureStorage (Keychain/KeyStore).
///
/// Singleton pattern: call [BiographyRepository.instance()] to get
/// the shared instance. For testing, use [BiographyRepository.withDatabase()].
class BiographyRepository {
  /// Database filename for sqflite_sqlcipher (used in production init).
  static const _dbName = 'mint_biography.db';
  static const _keyAlias = 'mint_biography_key';
  static const _tableName = 'biography_facts';

  static BiographyRepository? _instance;

  final BiographyDatabase _db;

  BiographyRepository._(this._db);

  /// Get the shared singleton instance.
  ///
  /// On first call, initializes the encrypted database.
  /// Subsequent calls return the cached instance.
  static Future<BiographyRepository> instance({
    FlutterSecureStorage? secureStorage,
  }) async {
    if (_instance != null) return _instance!;

    final storage = secureStorage ?? const FlutterSecureStorage();

    // Get or generate encryption key
    var key = await storage.read(key: _keyAlias);
    if (key == null) {
      // Generate a 32-byte hex key on first launch
      key = _generateKey();
      await storage.write(key: _keyAlias, value: key);
      debugPrint('[Biography] Generated new encryption key');
    }

    // Open encrypted database via sqflite_sqlcipher (AES-256-CBC).
    // For tests without native SQLite, use withDatabase() instead.
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, _dbName);
    final sqlDb = await sqflite.openDatabase(
      dbPath,
      password: key,
      version: 1,
      onCreate: (db, version) async {
        // Table creation handled by _createTables() below
      },
    );
    final db = _SqfliteDatabase(sqlDb);
    final repo = BiographyRepository._(db);
    await repo._createTables();
    _instance = repo;
    return repo;
  }

  /// Create a repository with an injected database (for testing).
  static Future<BiographyRepository> withDatabase(
      BiographyDatabase db) async {
    final repo = BiographyRepository._(db);
    await repo._createTables();
    _instance = repo;
    return repo;
  }

  /// Reset the singleton (for testing).
  static void resetInstance() {
    _instance = null;
  }

  /// Generate a 32-byte hex encryption key using cryptographic RNG.
  static String _generateKey() {
    final random = Random.secure();
    return List.generate(32, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // ── Schema ──────────────────────────────────────────────────

  /// Create tables and indexes for the biography database.
  Future<void> _createTables() async {
    await _db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        id TEXT PRIMARY KEY,
        factType TEXT NOT NULL,
        fieldPath TEXT,
        value TEXT NOT NULL,
        source TEXT NOT NULL,
        sourceDate TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        causalLinks TEXT DEFAULT '[]',
        temporalLinks TEXT DEFAULT '[]',
        isDeleted INTEGER DEFAULT 0,
        freshnessCategory TEXT DEFAULT 'annual'
      )
    ''');

    // Indexes for common query patterns
    await _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_fact_type ON $_tableName (factType)');
    await _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_field_path ON $_tableName (fieldPath)');
    await _db.execute(
        'CREATE INDEX IF NOT EXISTS idx_source ON $_tableName (source)');
  }

  /// Placeholder for future schema migrations.
  Future<void> onUpgrade(
      BiographyDatabase db, int oldVersion, int newVersion) async {
    // Future migrations go here.
    // Version 1 -> 2: example
    // if (oldVersion < 2) { await db.execute('ALTER TABLE ...'); }
  }

  // ── CRUD ────────────────────────────────────────────────────

  /// Insert a new fact into the biography.
  ///
  /// Returns the number of rows affected (1 on success).
  Future<int> insertFact(BiographyFact fact) async {
    final json = fact.toJson();
    return _db.rawInsert('''
      INSERT INTO $_tableName (
        id, factType, fieldPath, value, source, sourceDate,
        createdAt, updatedAt, causalLinks, temporalLinks,
        isDeleted, freshnessCategory
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ''', [
      json['id'],
      json['factType'],
      json['fieldPath'],
      json['value'],
      json['source'],
      json['sourceDate'],
      json['createdAt'],
      json['updatedAt'],
      json['causalLinks'],
      json['temporalLinks'],
      json['isDeleted'],
      json['freshnessCategory'],
    ]);
  }

  /// Update a fact's value, source, and updatedAt timestamp.
  ///
  /// Sets source to [FactSource.userEdit] to track manual corrections.
  Future<int> updateFact(String id, String newValue) async {
    return _db.rawUpdate('''
      UPDATE $_tableName
      SET value = ?, source = ?, updatedAt = ?
      WHERE id = ?
    ''', [
      newValue,
      FactSource.userEdit.name,
      DateTime.now().toIso8601String(),
      id,
    ]);
  }

  /// Soft-delete a fact (set isDeleted = 1).
  ///
  /// Fact remains in database but excluded from active queries.
  /// Use [hardDeleteFact] for GDPR/nLPD permanent deletion.
  Future<int> softDeleteFact(String id) async {
    return _db.rawUpdate('''
      UPDATE $_tableName SET isDeleted = 1 WHERE id = ?
    ''', [id]);
  }

  /// Permanently delete a fact from the database.
  ///
  /// Used by the privacy screen for GDPR/nLPD compliance.
  /// This operation is irreversible.
  Future<int> hardDeleteFact(String id) async {
    return _db.rawDelete('''
      DELETE FROM $_tableName WHERE id = ?
    ''', [id]);
  }

  // ── Queries ──────────────────────────────────────────────────

  /// Get all facts (including soft-deleted).
  Future<List<BiographyFact>> getFacts() async {
    final rows = await _db.rawQuery(
      'SELECT * FROM $_tableName ORDER BY updatedAt DESC',
    );
    return rows.map((r) => BiographyFact.fromJson(r)).toList();
  }

  /// Get only active (non-deleted) facts.
  Future<List<BiographyFact>> getActiveFacts() async {
    final rows = await _db.rawQuery(
      'SELECT * FROM $_tableName WHERE isDeleted = ? ORDER BY updatedAt DESC',
      [0],
    );
    return rows.map((r) => BiographyFact.fromJson(r)).toList();
  }

  /// Get facts filtered by [FactType].
  Future<List<BiographyFact>> getFactsByType(FactType type) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM $_tableName WHERE factType = ? AND isDeleted = ? ORDER BY updatedAt DESC',
      [type.name, 0],
    );
    return rows.map((r) => BiographyFact.fromJson(r)).toList();
  }

  /// Get facts matching a specific field path.
  Future<List<BiographyFact>> getFactsByFieldPath(String fieldPath) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM $_tableName WHERE fieldPath = ? AND isDeleted = ? ORDER BY updatedAt DESC',
      [fieldPath, 0],
    );
    return rows.map((r) => BiographyFact.fromJson(r)).toList();
  }

  /// Get the most recent fact for a given field path.
  ///
  /// Returns null if no fact exists for the field.
  Future<BiographyFact?> getLatestFactForField(String fieldPath) async {
    final rows = await _db.rawQuery(
      'SELECT * FROM $_tableName WHERE fieldPath = ? AND isDeleted = ? ORDER BY updatedAt DESC LIMIT 1',
      [fieldPath, 0],
    );
    if (rows.isEmpty) return null;
    return BiographyFact.fromJson(rows.first);
  }

  // ── Phase 9 Plan 09-04 (D-06) — generic fact + alert ack helpers ──

  /// Generic insert used by Phase 9 alert ack persistence. Delegates to
  /// [insertFact] so the storage path is identical to the typed CRUD.
  Future<void> recordFact(BiographyFact fact) async {
    await insertFact(fact);
  }

  /// Returns true if an `alertAcknowledged` fact exists for [alertId].
  ///
  /// Used by [MintAlertHost] to suppress a G3 [MintAlertObject] that the
  /// user has already dismissed via the "Compris" CTA.
  Future<bool> hasAlertAck(String alertId) async {
    final rows = await _db.rawQuery(
      'SELECT id FROM $_tableName WHERE factType = ? AND value = ? AND isDeleted = ? LIMIT 1',
      [FactType.alertAcknowledged.name, alertId, 0],
    );
    return rows.isNotEmpty;
  }

  /// Close the database connection.
  Future<void> close() async {
    await _db.close();
    _instance = null;
  }
}

/// Adapter bridging sqflite_sqlcipher [sqflite.Database] to [BiographyDatabase].
class _SqfliteDatabase implements BiographyDatabase {
  final sqflite.Database _db;
  _SqfliteDatabase(this._db);

  @override
  Future<void> execute(String sql, [List<Object?>? arguments]) =>
      _db.execute(sql, arguments);

  @override
  Future<List<Map<String, Object?>>> rawQuery(String sql,
          [List<Object?>? arguments]) =>
      _db.rawQuery(sql, arguments ?? []);

  @override
  Future<int> rawInsert(String sql, [List<Object?>? arguments]) =>
      _db.rawInsert(sql, arguments ?? []);

  @override
  Future<int> rawUpdate(String sql, [List<Object?>? arguments]) =>
      _db.rawUpdate(sql, arguments ?? []);

  @override
  Future<int> rawDelete(String sql, [List<Object?>? arguments]) =>
      _db.rawDelete(sql, arguments ?? []);

  @override
  Future<void> close() => _db.close();
}
