import 'dart:convert';

// ────────────────────────────────────────────────────────────
//  BIOGRAPHY FACT — Phase 03 / Memoire Narrative
// ────────────────────────────────────────────────────────────
//
// Immutable data model for a single fact in the user's
// FinancialBiography. Facts form a graph via causalLinks and
// temporalLinks, enabling the coach to understand the user's
// financial story over time.
//
// Storage: encrypted local SQLite via BiographyRepository.
// Privacy: NEVER sent to external APIs. Coach receives only
// an anonymized summary (see AnonymizedBiographySummary).
//
// See: BIO-01, BIO-02 requirements.
// ────────────────────────────────────────────────────────────

/// The type of financial fact being recorded.
///
/// Maps to domains in the user's financial life. Used for
/// querying, freshness categorization, and coach context.
enum FactType {
  salary,
  lppCapital,
  lppRachatMax,
  threeACapital,
  avsContributionYears,
  taxRate,
  mortgageDebt,
  canton,
  civilStatus,
  employmentStatus,
  lifeEvent,
  userDecision,
  coachPreference,
}

/// How the fact was captured or last updated.
///
/// Source affects confidence scoring:
/// - document: highest (extracted from official document)
/// - userInput: moderate (user-declared)
/// - userEdit: moderate (user corrected a value)
/// - coach: low-moderate (inferred during conversation)
enum FactSource {
  document,
  userInput,
  userEdit,
  coach,
}

/// A single fact in the user's FinancialBiography.
///
/// Immutable value object. Use [copyWith] to create modified copies.
/// Serializes to/from JSON for SQLite storage.
///
/// Graph links:
/// - [causalLinks]: fact IDs that caused this fact (e.g., jobLoss -> salary change)
/// - [temporalLinks]: fact IDs that happened around the same time
class BiographyFact {
  /// Unique identifier (UUID v4).
  final String id;

  /// The type of fact.
  final FactType factType;

  /// Optional mapping to a CoachProfile field path (e.g., 'prevoyance.avoirLppTotal').
  final String? fieldPath;

  /// The fact's value as a string. Numbers stored as strings for flexibility.
  final String value;

  /// How this fact was captured.
  final FactSource source;

  /// When the source document or event dates from (may differ from createdAt).
  final DateTime? sourceDate;

  /// When this fact was first recorded in MINT.
  final DateTime createdAt;

  /// When this fact was last confirmed or updated.
  final DateTime updatedAt;

  /// IDs of facts that causally relate to this one.
  final List<String> causalLinks;

  /// IDs of facts that are temporally related.
  final List<String> temporalLinks;

  /// Whether this fact has been soft-deleted (privacy screen).
  final bool isDeleted;

  /// Freshness category: 'annual' (12-month threshold) or 'volatile' (3-month threshold).
  final String freshnessCategory;

  const BiographyFact({
    required this.id,
    required this.factType,
    this.fieldPath,
    required this.value,
    required this.source,
    this.sourceDate,
    required this.createdAt,
    required this.updatedAt,
    this.causalLinks = const [],
    this.temporalLinks = const [],
    this.isDeleted = false,
    this.freshnessCategory = 'annual',
  });

  /// Create a modified copy of this fact.
  BiographyFact copyWith({
    String? id,
    FactType? factType,
    String? fieldPath,
    String? value,
    FactSource? source,
    DateTime? sourceDate,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<String>? causalLinks,
    List<String>? temporalLinks,
    bool? isDeleted,
    String? freshnessCategory,
  }) {
    return BiographyFact(
      id: id ?? this.id,
      factType: factType ?? this.factType,
      fieldPath: fieldPath ?? this.fieldPath,
      value: value ?? this.value,
      source: source ?? this.source,
      sourceDate: sourceDate ?? this.sourceDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      causalLinks: causalLinks ?? this.causalLinks,
      temporalLinks: temporalLinks ?? this.temporalLinks,
      isDeleted: isDeleted ?? this.isDeleted,
      freshnessCategory: freshnessCategory ?? this.freshnessCategory,
    );
  }

  /// Serialize to a JSON-compatible map for SQLite storage.
  Map<String, dynamic> toJson() => {
        'id': id,
        'factType': factType.name,
        'fieldPath': fieldPath,
        'value': value,
        'source': source.name,
        'sourceDate': sourceDate?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'causalLinks': jsonEncode(causalLinks),
        'temporalLinks': jsonEncode(temporalLinks),
        'isDeleted': isDeleted ? 1 : 0,
        'freshnessCategory': freshnessCategory,
      };

  /// Deserialize from a JSON map (from SQLite row).
  factory BiographyFact.fromJson(Map<String, dynamic> json) {
    return BiographyFact(
      id: json['id'] as String,
      factType: FactType.values.firstWhere(
        (t) => t.name == (json['factType'] as String),
        orElse: () => FactType.salary,
      ),
      fieldPath: json['fieldPath'] as String?,
      value: json['value'] as String,
      source: FactSource.values.firstWhere(
        (s) => s.name == (json['source'] as String),
        orElse: () => FactSource.userInput,
      ),
      sourceDate: json['sourceDate'] != null
          ? DateTime.tryParse(json['sourceDate'] as String)
          : null,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      causalLinks: _decodeStringList(json['causalLinks']),
      temporalLinks: _decodeStringList(json['temporalLinks']),
      isDeleted: json['isDeleted'] == 1 || json['isDeleted'] == true,
      freshnessCategory:
          (json['freshnessCategory'] as String?) ?? 'annual',
    );
  }

  /// Decode a JSON-encoded list of strings, handling both
  /// String (from DB) and List (from in-memory) formats.
  static List<String> _decodeStringList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) return raw.cast<String>();
    if (raw is String) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) return decoded.cast<String>();
      } catch (_) {
        // Graceful degradation: return empty list on parse error.
      }
    }
    return [];
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiographyFact &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'BiographyFact(id: $id, type: ${factType.name}, value: $value, '
      'source: ${source.name}, deleted: $isDeleted)';
}
