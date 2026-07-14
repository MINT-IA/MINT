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

import 'package:mint_mobile/models/coach_profile.dart';

/// Types of documents MINT can scan and parse.
/// Document types — must map to backend DocumentType (snake_case).
/// Mapping: lppCertificate ↔ lpp_certificate, threeAAttestation ↔ pillar_3a_attestation
enum DocumentType {
  lppCertificate, // → lpp_certificate
  taxDeclaration, // → tax_declaration
  avsExtract, // → avs_extract
  threeAAttestation, // → pillar_3a_attestation
  mortgageAttestation, // → mortgage_attestation
  salaryCertificate, // → salary_certificate
}

/// Convert to backend snake_case format.
extension DocumentTypeBackend on DocumentType {
  String get backendValue {
    switch (this) {
      case DocumentType.threeAAttestation:
        return 'pillar_3a_attestation';
      case DocumentType.lppCertificate:
        return 'lpp_certificate';
      case DocumentType.taxDeclaration:
        return 'tax_declaration';
      case DocumentType.avsExtract:
        return 'avs_extract';
      case DocumentType.mortgageAttestation:
        return 'mortgage_attestation';
      case DocumentType.salaryCertificate:
        return 'salary_certificate';
    }
  }

  static DocumentType fromBackend(String value) {
    switch (value) {
      case 'pillar_3a_attestation':
        return DocumentType.threeAAttestation;
      case 'lpp_certificate':
        return DocumentType.lppCertificate;
      case 'tax_declaration':
        return DocumentType.taxDeclaration;
      case 'avs_extract':
        return DocumentType.avsExtract;
      case 'mortgage_attestation':
        return DocumentType.mortgageAttestation;
      case 'salary_certificate':
        return DocumentType.salaryCertificate;
      default:
        return DocumentType.lppCertificate;
    }
  }
}

/// Human-readable label for each document type (French).
extension DocumentTypeLabel on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.lppCertificate:
        return 'Certificat de prevoyance LPP';
      case DocumentType.taxDeclaration:
        return 'Document fiscal';
      case DocumentType.avsExtract:
        return 'Extrait de compte AVS';
      case DocumentType.threeAAttestation:
        return 'Attestation 3e pilier';
      case DocumentType.mortgageAttestation:
        return 'Attestation hypothecaire';
      case DocumentType.salaryCertificate:
        return 'Fiche de salaire';
    }
  }

  /// Short description of what the document provides.
  ///
  /// Tax copy is localized at the screen boundary and therefore has no
  /// untranslated fallback in this model.
  String? get description {
    switch (this) {
      case DocumentType.lppCertificate:
        return 'Avoir LPP, parts oblig/suroblig, taux de conversion, lacune de rachat';
      case DocumentType.taxDeclaration:
        return null;
      case DocumentType.avsExtract:
        return 'Annees de cotisation, RAMD, lacunes';
      case DocumentType.threeAAttestation:
        return 'Solde 3a, versements cumules, rendement';
      case DocumentType.mortgageAttestation:
        return 'Capital restant du, taux, echeance';
      case DocumentType.salaryCertificate:
        return 'Salaire brut, deductions, 13eme, LPP employe, taux d\'activite';
    }
  }

  /// Estimated confidence boost from scanning this document.
  int get confidenceImpact {
    switch (this) {
      case DocumentType.lppCertificate:
        return 27; // +25-30 points
      case DocumentType.taxDeclaration:
        return 0;
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

/// Stable UI-copy identifiers for extracted fields that must be localized at
/// the rendering boundary.
enum ExtractionFieldLabelCode {
  taxTaxableIncome,
  taxTaxableWealth,
  taxDeductions,
  taxCantonalCommunalTax,
  taxCantonalOnlyTax,
  taxFederalDirectTax,
  taxMarginalRate,
  taxAverageRate,
}

/// Machine-readable diagnostics emitted by document parsers.
enum ExtractionDiagnosticCode {
  taxPercentUnitOutOfRange,
  taxNegativeWealthNeedsLabelReview,
  taxComputedAverageRateNotMarginal,
}

/// Typed diagnostic payload; user-facing copy is resolved by the screen.
class ExtractionDiagnostic {
  final ExtractionDiagnosticCode code;
  final double? amountChf;
  final double? ratePercent;

  const ExtractionDiagnostic.percentUnit(double rate)
      : code = ExtractionDiagnosticCode.taxPercentUnitOutOfRange,
        amountChf = null,
        ratePercent = rate;

  const ExtractionDiagnostic.negativeWealth(double amount)
      : code = ExtractionDiagnosticCode.taxNegativeWealthNeedsLabelReview,
        amountChf = amount,
        ratePercent = null;

  const ExtractionDiagnostic.averageNotMarginal(double rate)
      : code = ExtractionDiagnosticCode.taxComputedAverageRateNotMarginal,
        amountChf = null,
        ratePercent = rate;
}

/// A single field extracted from a document by OCR.
class ExtractedField {
  /// Profile field name (e.g. 'lpp_total', 'conversion_rate_oblig').
  final String fieldName;

  /// Legacy display label, or a stable technical code when [labelCode] is set.
  final String label;

  /// Optional typed label resolved through AppLocalizations at the UI boundary.
  final ExtractionFieldLabelCode? labelCode;

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
    this.labelCode,
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
      labelCode: labelCode,
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

  /// Typed diagnostics whose copy must be resolved at the UI boundary.
  final List<ExtractionDiagnostic> diagnostics;

  /// Compliance disclaimer (non-negotiable).
  final String disclaimer;

  /// Legal sources referenced.
  final List<String> sources;

  /// LPP plan type detected by backend (legal, surobligatoire, 1e).
  final String? planType;

  /// Warning text when plan type is 1e (no guaranteed conversion rate).
  final String? planTypeWarning;

  /// Cross-field coherence warnings from backend validation.
  final List<String> coherenceWarnings;

  const ExtractionResult({
    required this.documentType,
    required this.fields,
    required this.overallConfidence,
    required this.confidenceDelta,
    required this.warnings,
    required this.disclaimer,
    required this.sources,
    this.diagnostics = const [],
    this.planType,
    this.planTypeWarning,
    this.coherenceWarnings = const [],
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

/// In-memory tax interpretation retained while the user reviews a scan.
/// Raw OCR remains reachable only through [extraction] and is never serialized.
class TaxExtractionCandidate {
  final String snapshotId;
  final ExtractionResult extraction;
  final TaxDocumentKind documentKind;
  final TaxAssessmentStatus assessmentStatus;
  final int? taxYear;
  final int? basedOnTaxYear;
  final DateTime? sourceDate;
  final TaxSubjectScope subjectScope;
  final String? cantonCode;
  final String? municipalityId;
  final String? municipalityLabel;
  final double? cantonalCommunalTaxableIncomeChf;
  final double? federalTaxableIncomeChf;
  final double? cantonalCommunalTaxableWealthChf;
  final AssessedTaxAmount? cantonalCommunalAssessedTax;
  final AssessedTaxAmount? federalDirectAssessedTax;
  final double? explicitMarginalIncomeTaxRate;
  final double? explicitAverageIncomeTaxRate;

  const TaxExtractionCandidate._({
    required this.snapshotId,
    required this.extraction,
    required this.documentKind,
    required this.assessmentStatus,
    required this.taxYear,
    required this.basedOnTaxYear,
    required this.sourceDate,
    required this.subjectScope,
    required this.cantonCode,
    required this.municipalityId,
    required this.municipalityLabel,
    required this.cantonalCommunalTaxableIncomeChf,
    required this.federalTaxableIncomeChf,
    required this.cantonalCommunalTaxableWealthChf,
    required this.cantonalCommunalAssessedTax,
    required this.federalDirectAssessedTax,
    required this.explicitMarginalIncomeTaxRate,
    required this.explicitAverageIncomeTaxRate,
  });

  factory TaxExtractionCandidate.fromExtractionResult(
    ExtractionResult extraction, {
    required String Function() snapshotIdFactory,
    TaxDocumentKind documentKind = TaxDocumentKind.unknown,
    TaxAssessmentStatus assessmentStatus = TaxAssessmentStatus.unknown,
    int? taxYear,
    int? basedOnTaxYear,
    DateTime? sourceDate,
    TaxSubjectScope subjectScope = TaxSubjectScope.unknown,
    String? cantonCode,
    String? municipalityId,
    String? municipalityLabel,
    double? cantonalCommunalTaxableIncomeChf,
    double? federalTaxableIncomeChf,
    double? cantonalCommunalTaxableWealthChf,
    AssessedTaxAmount? cantonalCommunalAssessedTax,
    AssessedTaxAmount? federalDirectAssessedTax,
    double? explicitMarginalIncomeTaxRate,
    double? explicitAverageIncomeTaxRate,
  }) {
    final snapshotId = snapshotIdFactory();
    if (!TaxSnapshot.uuidV4Pattern.hasMatch(snapshotId)) {
      throw ArgumentError.value(snapshotId, 'snapshotId', 'UUIDv4 required');
    }
    _validateRatio(explicitMarginalIncomeTaxRate, 'marginal rate');
    _validateRatio(explicitAverageIncomeTaxRate, 'average rate');
    return TaxExtractionCandidate._(
      snapshotId: snapshotId,
      extraction: extraction,
      documentKind: documentKind,
      assessmentStatus: assessmentStatus,
      taxYear: taxYear,
      basedOnTaxYear: basedOnTaxYear,
      sourceDate: sourceDate,
      subjectScope: subjectScope,
      cantonCode: cantonCode,
      municipalityId: municipalityId,
      municipalityLabel: municipalityLabel,
      cantonalCommunalTaxableIncomeChf: cantonalCommunalTaxableIncomeChf,
      federalTaxableIncomeChf: federalTaxableIncomeChf,
      cantonalCommunalTaxableWealthChf: cantonalCommunalTaxableWealthChf,
      cantonalCommunalAssessedTax: cantonalCommunalAssessedTax,
      federalDirectAssessedTax: federalDirectAssessedTax,
      explicitMarginalIncomeTaxRate: explicitMarginalIncomeTaxRate,
      explicitAverageIncomeTaxRate: explicitAverageIncomeTaxRate,
    );
  }

  static void _validateRatio(double? value, String label) {
    if (value != null && (!value.isFinite || value < 0 || value > 1)) {
      throw ArgumentError.value(value, label, 'ratio 0...1 required');
    }
  }
}

/// Immutable user-confirmed interpretation accepted by the ledger writer.
class TaxReviewConfirmation {
  final TaxExtractionCandidate candidate;
  final int? taxYear;
  final int? basedOnTaxYear;
  final DateTime? sourceDate;
  final TaxDocumentKind documentKind;
  final TaxAssessmentStatus assessmentStatus;
  final bool inForceAttested;
  final TaxSubjectScope subjectScope;
  final String? cantonCode;
  final String? municipalityId;
  final String? municipalityLabel;
  final double? cantonalCommunalTaxableIncomeChf;
  final double? federalTaxableIncomeChf;
  final double? cantonalCommunalTaxableWealthChf;
  final AssessedTaxAmount? cantonalCommunalAssessedTax;
  final AssessedTaxAmount? federalDirectAssessedTax;
  final double? explicitMarginalIncomeTaxRate;
  final double? explicitAverageIncomeTaxRate;

  factory TaxReviewConfirmation({
    required TaxExtractionCandidate candidate,
    required int? taxYear,
    required int? basedOnTaxYear,
    required DateTime? sourceDate,
    required TaxDocumentKind documentKind,
    required TaxAssessmentStatus assessmentStatus,
    bool inForceAttested = false,
    required TaxSubjectScope subjectScope,
    required String? cantonCode,
    required String? municipalityId,
    required String? municipalityLabel,
    required double? cantonalCommunalTaxableIncomeChf,
    required double? federalTaxableIncomeChf,
    required double? cantonalCommunalTaxableWealthChf,
    required AssessedTaxAmount? cantonalCommunalAssessedTax,
    required AssessedTaxAmount? federalDirectAssessedTax,
    required double? explicitMarginalIncomeTaxRate,
    required double? explicitAverageIncomeTaxRate,
  }) {
    if (assessmentStatus == TaxAssessmentStatus.inForce && !inForceAttested) {
      throw ArgumentError.value(
        inForceAttested,
        'inForceAttested',
        'explicit user attestation required for an in-force assessment',
      );
    }
    TaxSnapshot.validateRuntimeFacts(
      documentKind: documentKind,
      assessmentStatus: assessmentStatus,
      cantonalCommunalTaxableIncomeChf: cantonalCommunalTaxableIncomeChf,
      federalTaxableIncomeChf: federalTaxableIncomeChf,
      cantonalCommunalTaxableWealthChf: cantonalCommunalTaxableWealthChf,
      cantonalCommunalAssessedTax: cantonalCommunalAssessedTax,
      federalDirectAssessedTax: federalDirectAssessedTax,
      explicitMarginalIncomeTaxRate: explicitMarginalIncomeTaxRate,
      explicitAverageIncomeTaxRate: explicitAverageIncomeTaxRate,
    );
    return TaxReviewConfirmation._(
      candidate: candidate,
      taxYear: taxYear,
      basedOnTaxYear: basedOnTaxYear,
      sourceDate: sourceDate,
      documentKind: documentKind,
      assessmentStatus: assessmentStatus,
      inForceAttested: inForceAttested,
      subjectScope: subjectScope,
      cantonCode: cantonCode,
      municipalityId: municipalityId,
      municipalityLabel: municipalityLabel,
      cantonalCommunalTaxableIncomeChf: cantonalCommunalTaxableIncomeChf,
      federalTaxableIncomeChf: federalTaxableIncomeChf,
      cantonalCommunalTaxableWealthChf: cantonalCommunalTaxableWealthChf,
      cantonalCommunalAssessedTax: cantonalCommunalAssessedTax,
      federalDirectAssessedTax: federalDirectAssessedTax,
      explicitMarginalIncomeTaxRate: explicitMarginalIncomeTaxRate,
      explicitAverageIncomeTaxRate: explicitAverageIncomeTaxRate,
    );
  }

  const TaxReviewConfirmation._({
    required this.candidate,
    required this.taxYear,
    required this.basedOnTaxYear,
    required this.sourceDate,
    required this.documentKind,
    required this.assessmentStatus,
    required this.inForceAttested,
    required this.subjectScope,
    required this.cantonCode,
    required this.municipalityId,
    required this.municipalityLabel,
    required this.cantonalCommunalTaxableIncomeChf,
    required this.federalTaxableIncomeChf,
    required this.cantonalCommunalTaxableWealthChf,
    required this.cantonalCommunalAssessedTax,
    required this.federalDirectAssessedTax,
    required this.explicitMarginalIncomeTaxRate,
    required this.explicitAverageIncomeTaxRate,
  });
}
