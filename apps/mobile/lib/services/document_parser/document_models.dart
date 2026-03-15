// ────────────────────────────────────────────────────────────
//  DOCUMENT PARSER MODELS — Sprint S42-S43
// ────────────────────────────────────────────────────────────
//
//  Shared types for the document parsing pipeline.
//  Used by LPP certificate parser, tax declaration parser,
//  AVS extract parser, and all extraction screens.
//
//  Reference: DATA_ACQUISITION_STRATEGY.md — Channel 1
// ────────────────────────────────────────────────────────────

/// Types of documents MINT can scan and parse.
enum DocumentType {
  lppCertificate,
  taxDeclaration,
  avsExtract,
  threeAAttestation,
  mortgageAttestation,
  salaryCertificate,
}

/// Human-readable label for each document type (French).
extension DocumentTypeLabel on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.lppCertificate:
        return 'Certificat de prévoyance LPP';
      case DocumentType.taxDeclaration:
        return 'Déclaration fiscale';
      case DocumentType.avsExtract:
        return 'Extrait de compte AVS';
      case DocumentType.threeAAttestation:
        return 'Attestation 3e pilier';
      case DocumentType.mortgageAttestation:
        return 'Attestation hypothécaire';
      case DocumentType.salaryCertificate:
        return 'Fiche de salaire';
    }
  }

  /// Short description of what the document provides.
  String get description {
    switch (this) {
      case DocumentType.lppCertificate:
        return 'Avoir LPP, parts oblig/suroblig, taux de conversion, lacune de rachat';
      case DocumentType.taxDeclaration:
        return 'Revenu imposable, fortune, taux marginal effectif';
      case DocumentType.avsExtract:
        return 'Années de cotisation, RAMD, lacunes';
      case DocumentType.threeAAttestation:
        return 'Solde 3a, versements cumulés, rendement';
      case DocumentType.mortgageAttestation:
        return 'Capital restant dû, taux, échéance';
      case DocumentType.salaryCertificate:
        return 'Salaire brut, déductions, 13ème, LPP employé, taux d\'activité';
    }
  }

  /// Estimated confidence boost from scanning this document.
  int get confidenceImpact {
    switch (this) {
      case DocumentType.lppCertificate:
        return 27; // +25-30 points
      case DocumentType.taxDeclaration:
        return 17; // +15-20 points
      case DocumentType.avsExtract:
        return 22; // +20-25 points
      case DocumentType.threeAAttestation:
        return 7; // +5-10 points
      case DocumentType.mortgageAttestation:
        return 12; // +10-15 points
      case DocumentType.salaryCertificate:
        return 20; // +18-22 points
    }
  }
}

/// Provenance of a profile field value.
///
/// Ordered from least reliable to most reliable.
/// Reference: DATA_ACQUISITION_STRATEGY.md — Rule 1.
enum DataSource {
  /// MINT computed default based on archetype/age/salary.
  systemEstimate,

  /// User typed "environ 150k" without precision.
  userEstimate,

  /// User entered an exact value manually.
  userEntry,

  /// User entry that passed cross-validation checks.
  userEntryCrossValidated,

  /// OCR extraction from a scanned document.
  documentScan,

  /// OCR extraction confirmed/corrected by user.
  documentScanVerified,

  /// Live data from Open Banking (bLink/SFTI).
  openBanking,

  /// Direct feed from caisse de pension / AFC API.
  institutionalApi,
}

/// Accuracy weight for each data source (0.0-1.0).
extension DataSourceAccuracy on DataSource {
  double get accuracyWeight {
    switch (this) {
      case DataSource.systemEstimate:
        return 0.25;
      case DataSource.userEstimate:
        return 0.50;
      case DataSource.userEntry:
        return 0.60;
      case DataSource.userEntryCrossValidated:
        return 0.70;
      case DataSource.documentScan:
        return 0.85;
      case DataSource.documentScanVerified:
        return 0.95;
      case DataSource.openBanking:
        return 1.00;
      case DataSource.institutionalApi:
        return 0.95;
    }
  }
}

/// A single field extracted from a document by OCR.
class ExtractedField {
  /// Profile field name (e.g. 'lpp_total', 'conversion_rate_oblig').
  final String fieldName;

  /// Human-readable label in French.
  final String label;

  /// Extracted value (double for amounts/rates, String for text).
  final dynamic value;

  /// Extraction confidence: 0.0 (no confidence) to 1.0 (certain).
  final double confidence;

  /// Raw text from OCR that was parsed to extract this value.
  final String sourceText;

  /// True if confidence is below threshold and user should verify.
  final bool needsReview;

  /// Optional: the profile field this maps to for injection.
  final String? profileField;

  const ExtractedField({
    required this.fieldName,
    required this.label,
    required this.value,
    required this.confidence,
    required this.sourceText,
    required this.needsReview,
    this.profileField,
  });

  /// Create a copy with a user-corrected value.
  ExtractedField copyWithValue(dynamic newValue) {
    return ExtractedField(
      fieldName: fieldName,
      label: label,
      value: newValue,
      confidence: 1.0, // User-verified = full confidence
      sourceText: sourceText,
      needsReview: false,
      profileField: profileField,
    );
  }

  /// Confidence level category for UI display.
  ConfidenceLevel get confidenceLevel {
    if (confidence >= 0.80) return ConfidenceLevel.high;
    if (confidence >= 0.50) return ConfidenceLevel.medium;
    return ConfidenceLevel.low;
  }
}

/// Confidence level for UI color coding.
enum ConfidenceLevel { high, medium, low }

/// How a field was extracted — for provenance tracking in the review screen.
enum ExtractionSource {
  /// Deterministic regex pattern matching (highest trust).
  regex,

  /// On-device SLM (Gemma 3n) enhancement — validated but needs review.
  slm,

  /// Cloud vision API via BYOK (Claude/OpenAI).
  byokVision,

  /// User entered the value manually.
  manual,
}

/// Result of parsing a complete document.
class ExtractionResult {
  /// Type of document that was parsed.
  final DocumentType documentType;

  /// All fields successfully extracted.
  final List<ExtractedField> fields;

  /// Overall extraction confidence (average of field confidences).
  final double overallConfidence;

  /// How many confidence points this adds to the user profile.
  final double confidenceDelta;

  /// Warnings detected during parsing (inconsistencies, missing fields, etc.).
  final List<String> warnings;

  /// Compliance disclaimer (non-negotiable).
  final String disclaimer;

  /// Legal sources referenced.
  final List<String> sources;

  const ExtractionResult({
    required this.documentType,
    required this.fields,
    required this.overallConfidence,
    required this.confidenceDelta,
    required this.warnings,
    required this.disclaimer,
    required this.sources,
  });

  /// Fields that need user review (confidence < 80%).
  List<ExtractedField> get fieldsNeedingReview =>
      fields.where((f) => f.needsReview).toList();

  /// Fields with high confidence (>= 80%).
  List<ExtractedField> get highConfidenceFields =>
      fields.where((f) => f.confidence >= 0.80).toList();

  /// Number of fields successfully extracted.
  int get fieldCount => fields.length;

  /// True if any field needs review.
  bool get hasFieldsNeedingReview => fields.any((f) => f.needsReview);
}
