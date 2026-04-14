// Phase 28-02 — Dart mirror of the backend
// `DocumentUnderstandingResult` Pydantic v2 contract
// (services/backend/app/schemas/document_understanding.py).
//
// All field names are camelCase to match the backend's
// `alias_generator=to_camel`. snake_case keys are also tolerated in
// `fromJson` so the same model decodes payloads from older test fixtures
// or pre-aliased internal calls.

enum DocumentClass {
  lppCertificate,
  salaryCertificate,
  avsExtract,
  pillar3aAttestation,
  taxDeclaration,
  payslip,
  lease,
  mortgageAttestation,
  insurancePolicy,
  lamalStatement,
  bankStatement,
  nonFinancial,
  unknown,
}

DocumentClass _documentClassFromApi(String? raw) {
  switch (raw) {
    case 'lpp_certificate':
      return DocumentClass.lppCertificate;
    case 'salary_certificate':
      return DocumentClass.salaryCertificate;
    case 'avs_extract':
      return DocumentClass.avsExtract;
    case 'pillar_3a_attestation':
      return DocumentClass.pillar3aAttestation;
    case 'tax_declaration':
      return DocumentClass.taxDeclaration;
    case 'payslip':
      return DocumentClass.payslip;
    case 'lease':
      return DocumentClass.lease;
    case 'mortgage_attestation':
      return DocumentClass.mortgageAttestation;
    case 'insurance_policy':
      return DocumentClass.insurancePolicy;
    case 'lamal_statement':
      return DocumentClass.lamalStatement;
    case 'bank_statement':
      return DocumentClass.bankStatement;
    case 'non_financial':
      return DocumentClass.nonFinancial;
    default:
      return DocumentClass.unknown;
  }
}

enum RenderMode { confirm, ask, narrative, reject }

RenderMode _renderModeFromApi(String? raw) {
  switch (raw) {
    case 'confirm':
      return RenderMode.confirm;
    case 'ask':
      return RenderMode.ask;
    case 'reject':
      return RenderMode.reject;
    default:
      return RenderMode.narrative;
  }
}

enum ConfidenceLevel { high, medium, low }

ConfidenceLevel _confidenceFromApi(String? raw) {
  switch (raw) {
    case 'high':
      return ConfidenceLevel.high;
    case 'low':
      return ConfidenceLevel.low;
    default:
      return ConfidenceLevel.medium;
  }
}

enum ExtractionStatus {
  success,
  partial,
  noFieldsFound,
  parseError,
  encryptedNeedsPassword,
  nonFinancial,
  rejectedLocal,
}

ExtractionStatus _extractionStatusFromApi(String? raw) {
  switch (raw) {
    case 'success':
      return ExtractionStatus.success;
    case 'partial':
      return ExtractionStatus.partial;
    case 'no_fields_found':
      return ExtractionStatus.noFieldsFound;
    case 'parse_error':
      return ExtractionStatus.parseError;
    case 'encrypted_needs_password':
      return ExtractionStatus.encryptedNeedsPassword;
    case 'non_financial':
      return ExtractionStatus.nonFinancial;
    case 'rejected_local':
      return ExtractionStatus.rejectedLocal;
    default:
      return ExtractionStatus.partial;
  }
}

dynamic _pick(Map<String, dynamic> j, String camel, [String? snake]) {
  if (j.containsKey(camel)) return j[camel];
  if (snake != null && j.containsKey(snake)) return j[snake];
  return null;
}

class ExtractedField {
  final String fieldName;
  final dynamic value;
  final ConfidenceLevel confidence;
  final String sourceText;

  const ExtractedField({
    required this.fieldName,
    required this.value,
    required this.confidence,
    required this.sourceText,
  });

  factory ExtractedField.fromJson(Map<String, dynamic> j) {
    return ExtractedField(
      fieldName: (_pick(j, 'fieldName', 'field_name') as String?) ?? '',
      value: _pick(j, 'value'),
      confidence: _confidenceFromApi(_pick(j, 'confidence') as String?),
      sourceText: (_pick(j, 'sourceText', 'source_text') as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'fieldName': fieldName,
        'value': value,
        'confidence': confidence.name,
        'sourceText': sourceText,
      };
}

class CoherenceWarning {
  final String code;
  final String message;
  final List<String> fields;

  const CoherenceWarning({
    required this.code,
    required this.message,
    this.fields = const [],
  });

  factory CoherenceWarning.fromJson(Map<String, dynamic> j) {
    final f = j['fields'];
    return CoherenceWarning(
      code: (j['code'] as String?) ?? '',
      message: (j['message'] as String?) ?? '',
      fields: f is List ? f.map((e) => e.toString()).toList() : const [],
    );
  }
}

class DocumentUnderstandingResult {
  final String schemaVersion;
  final DocumentClass documentClass;
  final String? subtype;
  final String? issuerGuess;
  final double classificationConfidence;
  final List<ExtractedField> extractedFields;
  final double overallConfidence;
  final ExtractionStatus extractionStatus;
  final String? planType;
  final String? planTypeWarning;
  final List<CoherenceWarning> coherenceWarnings;
  final RenderMode renderMode;
  final String? summary;
  final List<String> questionsForUser;
  final String? narrative;
  final Map<String, dynamic>? commitmentSuggestion;
  final bool thirdPartyDetected;
  final String? thirdPartyName;
  final String? fingerprint;
  final Map<String, dynamic>? diffFromPrevious;
  final int? pagesProcessed;
  final int? pagesTotal;
  final String? pdfWarning;
  final int costTokensIn;
  final int costTokensOut;

  const DocumentUnderstandingResult({
    this.schemaVersion = '1.0',
    required this.documentClass,
    this.subtype,
    this.issuerGuess,
    this.classificationConfidence = 0.0,
    this.extractedFields = const [],
    this.overallConfidence = 0.0,
    required this.extractionStatus,
    this.planType,
    this.planTypeWarning,
    this.coherenceWarnings = const [],
    required this.renderMode,
    this.summary,
    this.questionsForUser = const [],
    this.narrative,
    this.commitmentSuggestion,
    this.thirdPartyDetected = false,
    this.thirdPartyName,
    this.fingerprint,
    this.diffFromPrevious,
    this.pagesProcessed,
    this.pagesTotal,
    this.pdfWarning,
    this.costTokensIn = 0,
    this.costTokensOut = 0,
  });

  factory DocumentUnderstandingResult.fromJson(Map<String, dynamic> j) {
    final fieldsRaw = (_pick(j, 'extractedFields', 'extracted_fields') as List?) ?? const [];
    final warnsRaw = (_pick(j, 'coherenceWarnings', 'coherence_warnings') as List?) ?? const [];
    final qsRaw = (_pick(j, 'questionsForUser', 'questions_for_user') as List?) ?? const [];
    return DocumentUnderstandingResult(
      schemaVersion: (_pick(j, 'schemaVersion', 'schema_version') as String?) ?? '1.0',
      documentClass: _documentClassFromApi(_pick(j, 'documentClass', 'document_class') as String?),
      subtype: _pick(j, 'subtype') as String?,
      issuerGuess: _pick(j, 'issuerGuess', 'issuer_guess') as String?,
      classificationConfidence: (_pick(j, 'classificationConfidence', 'classification_confidence') is num)
          ? (_pick(j, 'classificationConfidence', 'classification_confidence') as num).toDouble()
          : 0.0,
      extractedFields: fieldsRaw
          .whereType<Map<String, dynamic>>()
          .map(ExtractedField.fromJson)
          .toList(),
      overallConfidence: (_pick(j, 'overallConfidence', 'overall_confidence') is num)
          ? (_pick(j, 'overallConfidence', 'overall_confidence') as num).toDouble()
          : 0.0,
      extractionStatus: _extractionStatusFromApi(_pick(j, 'extractionStatus', 'extraction_status') as String?),
      planType: _pick(j, 'planType', 'plan_type') as String?,
      planTypeWarning: _pick(j, 'planTypeWarning', 'plan_type_warning') as String?,
      coherenceWarnings: warnsRaw
          .whereType<Map<String, dynamic>>()
          .map(CoherenceWarning.fromJson)
          .toList(),
      renderMode: _renderModeFromApi(_pick(j, 'renderMode', 'render_mode') as String?),
      summary: _pick(j, 'summary') as String?,
      questionsForUser: qsRaw.map((e) => e.toString()).toList(),
      narrative: _pick(j, 'narrative') as String?,
      commitmentSuggestion: _pick(j, 'commitmentSuggestion', 'commitment_suggestion') as Map<String, dynamic>?,
      thirdPartyDetected: (_pick(j, 'thirdPartyDetected', 'third_party_detected') as bool?) ?? false,
      thirdPartyName: _pick(j, 'thirdPartyName', 'third_party_name') as String?,
      fingerprint: _pick(j, 'fingerprint') as String?,
      diffFromPrevious: _pick(j, 'diffFromPrevious', 'diff_from_previous') as Map<String, dynamic>?,
      pagesProcessed: (_pick(j, 'pagesProcessed', 'pages_processed') as num?)?.toInt(),
      pagesTotal: (_pick(j, 'pagesTotal', 'pages_total') as num?)?.toInt(),
      pdfWarning: _pick(j, 'pdfWarning', 'pdf_warning') as String?,
      costTokensIn: (_pick(j, 'costTokensIn', 'cost_tokens_in') as num?)?.toInt() ?? 0,
      costTokensOut: (_pick(j, 'costTokensOut', 'cost_tokens_out') as num?)?.toInt() ?? 0,
    );
  }
}
