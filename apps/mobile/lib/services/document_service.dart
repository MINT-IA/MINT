import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';

// ──────────────────────────────────────────────────────────
// Model: LPP Extracted Fields
// ──────────────────────────────────────────────────────────

/// Typed fields extracted from an LPP certificate by Docling.
class LppExtractedFields {
  final double? avoirObligatoire;
  final double? avoirSurobligatoire;
  final double? avoirVieillesseTotal;
  final double? salaireAssure;
  final double? salaireAvs;
  final double? deductionCoordination;
  final double? tauxConversionObligatoire;
  final double? tauxConversionSurobligatoire;
  final double? tauxConversionEnveloppe;
  final double? renteInvalidite;
  final double? capitalDeces;
  final double? renteConjoint;
  final double? renteEnfant;
  final double? rachatMaximum;
  final double? cotisationEmploye;
  final double? cotisationEmployeur;

  const LppExtractedFields({
    this.avoirObligatoire,
    this.avoirSurobligatoire,
    this.avoirVieillesseTotal,
    this.salaireAssure,
    this.salaireAvs,
    this.deductionCoordination,
    this.tauxConversionObligatoire,
    this.tauxConversionSurobligatoire,
    this.tauxConversionEnveloppe,
    this.renteInvalidite,
    this.capitalDeces,
    this.renteConjoint,
    this.renteEnfant,
    this.rachatMaximum,
    this.cotisationEmploye,
    this.cotisationEmployeur,
  });

  factory LppExtractedFields.fromJson(Map<String, dynamic> json) {
    return LppExtractedFields(
      avoirObligatoire: _toDouble(json['avoir_obligatoire']),
      avoirSurobligatoire: _toDouble(json['avoir_surobligatoire']),
      avoirVieillesseTotal: _toDouble(json['avoir_vieillesse_total']),
      salaireAssure: _toDouble(json['salaire_assure']),
      salaireAvs: _toDouble(json['salaire_avs']),
      deductionCoordination: _toDouble(json['deduction_coordination']),
      tauxConversionObligatoire: _toDouble(json['taux_conversion_obligatoire']),
      tauxConversionSurobligatoire:
          _toDouble(json['taux_conversion_surobligatoire']),
      tauxConversionEnveloppe: _toDouble(json['taux_conversion_enveloppe']),
      renteInvalidite: _toDouble(json['rente_invalidite']),
      capitalDeces: _toDouble(json['capital_deces']),
      renteConjoint: _toDouble(json['rente_conjoint']),
      renteEnfant: _toDouble(json['rente_enfant']),
      rachatMaximum: _toDouble(json['rachat_maximum']),
      cotisationEmploye: _toDouble(json['cotisation_employe']),
      cotisationEmployeur: _toDouble(json['cotisation_employeur']),
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    if (avoirObligatoire != null) {
      map['avoir_obligatoire'] = avoirObligatoire;
    }
    if (avoirSurobligatoire != null) {
      map['avoir_surobligatoire'] = avoirSurobligatoire;
    }
    if (avoirVieillesseTotal != null) {
      map['avoir_vieillesse_total'] = avoirVieillesseTotal;
    }
    if (salaireAssure != null) map['salaire_assure'] = salaireAssure;
    if (salaireAvs != null) map['salaire_avs'] = salaireAvs;
    if (deductionCoordination != null) {
      map['deduction_coordination'] = deductionCoordination;
    }
    if (tauxConversionObligatoire != null) {
      map['taux_conversion_obligatoire'] = tauxConversionObligatoire;
    }
    if (tauxConversionSurobligatoire != null) {
      map['taux_conversion_surobligatoire'] = tauxConversionSurobligatoire;
    }
    if (tauxConversionEnveloppe != null) {
      map['taux_conversion_enveloppe'] = tauxConversionEnveloppe;
    }
    if (renteInvalidite != null) map['rente_invalidite'] = renteInvalidite;
    if (capitalDeces != null) map['capital_deces'] = capitalDeces;
    if (renteConjoint != null) map['rente_conjoint'] = renteConjoint;
    if (renteEnfant != null) map['rente_enfant'] = renteEnfant;
    if (rachatMaximum != null) map['rachat_maximum'] = rachatMaximum;
    if (cotisationEmploye != null) {
      map['cotisation_employe'] = cotisationEmploye;
    }
    if (cotisationEmployeur != null) {
      map['cotisation_employeur'] = cotisationEmployeur;
    }
    return map;
  }

  /// Number of non-null fields found.
  int get fieldsFound {
    int count = 0;
    if (avoirObligatoire != null) count++;
    if (avoirSurobligatoire != null) count++;
    if (avoirVieillesseTotal != null) count++;
    if (salaireAssure != null) count++;
    if (salaireAvs != null) count++;
    if (deductionCoordination != null) count++;
    if (tauxConversionObligatoire != null) count++;
    if (tauxConversionSurobligatoire != null) count++;
    if (tauxConversionEnveloppe != null) count++;
    if (renteInvalidite != null) count++;
    if (capitalDeces != null) count++;
    if (renteConjoint != null) count++;
    if (renteEnfant != null) count++;
    if (rachatMaximum != null) count++;
    if (cotisationEmploye != null) count++;
    if (cotisationEmployeur != null) count++;
    return count;
  }

  static const int fieldsTotal = 16;

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}

// ──────────────────────────────────────────────────────────
// Model: Document Upload Result
// ──────────────────────────────────────────────────────────

/// Result returned after uploading and processing a document.
class DocumentUploadResult {
  final String id;
  final String documentType;
  final LppExtractedFields extractedFields;
  final double confidence;
  final int fieldsFound;
  final int fieldsTotal;
  final List<String> warnings;

  const DocumentUploadResult({
    required this.id,
    required this.documentType,
    required this.extractedFields,
    required this.confidence,
    required this.fieldsFound,
    required this.fieldsTotal,
    this.warnings = const [],
  });

  factory DocumentUploadResult.fromJson(Map<String, dynamic> json) {
    final extractedMap =
        json['extracted_fields'] as Map<String, dynamic>? ?? {};
    return DocumentUploadResult(
      id: json['id'] as String? ?? '',
      documentType: json['document_type'] as String? ?? 'unknown',
      extractedFields: LppExtractedFields.fromJson(extractedMap),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      fieldsFound: json['fields_found'] as int? ?? 0,
      fieldsTotal: json['fields_total'] as int? ?? 0,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((w) => w as String)
              .toList() ??
          [],
    );
  }
}

// ──────────────────────────────────────────────────────────
// Model: Document Summary
// ──────────────────────────────────────────────────────────

/// Summary of a previously uploaded document.
class DocumentSummary {
  final String id;
  final String documentType;
  final DateTime uploadDate;
  final double confidence;
  final int fieldsFound;

  const DocumentSummary({
    required this.id,
    required this.documentType,
    required this.uploadDate,
    required this.confidence,
    required this.fieldsFound,
  });

  factory DocumentSummary.fromJson(Map<String, dynamic> json) {
    return DocumentSummary(
      id: json['id'] as String? ?? '',
      documentType: json['document_type'] as String? ?? 'unknown',
      uploadDate: DateTime.tryParse(json['upload_date'] as String? ?? '') ??
          DateTime.now(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      fieldsFound: json['fields_found'] as int? ?? 0,
    );
  }
}

// ──────────────────────────────────────────────────────────
// Model: Bank Transaction
// ──────────────────────────────────────────────────────────

/// A single transaction extracted from a bank statement.
class BankTransaction {
  final DateTime date;
  final String description;
  final double amount;
  final double? balance;
  final String category;
  final String? subcategory;
  final bool isRecurring;

  const BankTransaction({
    required this.date,
    required this.description,
    required this.amount,
    this.balance,
    required this.category,
    this.subcategory,
    this.isRecurring = false,
  });

  factory BankTransaction.fromJson(Map<String, dynamic> json) {
    return BankTransaction(
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balance: (json['balance'] as num?)?.toDouble(),
      category: json['category'] as String? ?? 'Divers',
      subcategory: json['subcategory'] as String?,
      isRecurring: json['is_recurring'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'description': description,
      'amount': amount,
      if (balance != null) 'balance': balance,
      'category': category,
      if (subcategory != null) 'subcategory': subcategory,
      'is_recurring': isRecurring,
    };
  }
}

// ──────────────────────────────────────────────────────────
// Model: Bank Statement Result
// ──────────────────────────────────────────────────────────

/// Result returned after uploading and processing a bank statement.
class BankStatementResult {
  final String bankName;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String currency;
  final List<BankTransaction> transactions;
  final double totalCredits;
  final double totalDebits;
  final double confidence;
  final List<String> warnings;
  final Map<String, double> categorySummary;
  final List<BankTransaction> recurringMonthly;

  const BankStatementResult({
    required this.bankName,
    required this.periodStart,
    required this.periodEnd,
    this.currency = 'CHF',
    required this.transactions,
    required this.totalCredits,
    required this.totalDebits,
    required this.confidence,
    this.warnings = const [],
    this.categorySummary = const {},
    this.recurringMonthly = const [],
  });

  factory BankStatementResult.fromJson(Map<String, dynamic> json) {
    final txList = (json['transactions'] as List<dynamic>?)
            ?.map((t) => BankTransaction.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];
    final recurringList = (json['recurring_monthly'] as List<dynamic>?)
            ?.map((t) => BankTransaction.fromJson(t as Map<String, dynamic>))
            .toList() ??
        [];
    final catSummary = <String, double>{};
    final rawCat = json['category_summary'] as Map<String, dynamic>?;
    if (rawCat != null) {
      for (final entry in rawCat.entries) {
        catSummary[entry.key] = (entry.value as num).toDouble();
      }
    }

    return BankStatementResult(
      bankName: json['bank_name'] as String? ?? 'Banque inconnue',
      periodStart:
          DateTime.tryParse(json['period_start'] as String? ?? '') ??
              DateTime.now(),
      periodEnd:
          DateTime.tryParse(json['period_end'] as String? ?? '') ??
              DateTime.now(),
      currency: json['currency'] as String? ?? 'CHF',
      transactions: txList,
      totalCredits: (json['total_credits'] as num?)?.toDouble() ?? 0.0,
      totalDebits: (json['total_debits'] as num?)?.toDouble() ?? 0.0,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      warnings: (json['warnings'] as List<dynamic>?)
              ?.map((w) => w as String)
              .toList() ??
          [],
      categorySummary: catSummary,
      recurringMonthly: recurringList,
    );
  }
}

// ──────────────────────────────────────────────────────────
// Model: Budget Import Preview
// ──────────────────────────────────────────────────────────

/// Preview of budget data derived from a bank statement analysis.
class BudgetImportPreview {
  final double estimatedMonthlyIncome;
  final double estimatedMonthlyExpenses;
  final List<MapEntry<String, double>> topCategories;
  final List<BankTransaction> recurringCharges;
  final double savingsRate;

  const BudgetImportPreview({
    required this.estimatedMonthlyIncome,
    required this.estimatedMonthlyExpenses,
    required this.topCategories,
    required this.recurringCharges,
    required this.savingsRate,
  });

  /// Derive a budget import preview from a [BankStatementResult].
  factory BudgetImportPreview.fromStatementResult(BankStatementResult result) {
    final income = result.totalCredits;
    final expenses = result.totalDebits.abs();
    final savings = income > 0 ? ((income - expenses) / income) * 100 : 0.0;

    final sortedCategories = result.categorySummary.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return BudgetImportPreview(
      estimatedMonthlyIncome: income,
      estimatedMonthlyExpenses: expenses,
      topCategories: sortedCategories,
      recurringCharges: result.recurringMonthly,
      savingsRate: savings,
    );
  }
}

// ──────────────────────────────────────────────────────────
// Document Service
// ──────────────────────────────────────────────────────────

/// Service for uploading and managing user documents (LPP certificates, etc.).
///
/// Uses the backend POST /api/v1/documents/upload (multipart),
/// GET /api/v1/documents/, and DELETE /api/v1/documents/{id}.
/// Documents are analyzed via Docling on the backend.
class DocumentService {
  static final DocumentService _instance = DocumentService._internal();
  factory DocumentService() => _instance;
  DocumentService._internal();

  static const String _baseUrl = ApiService.baseUrl;

  /// Upload a PDF document for analysis.
  ///
  /// Returns a [DocumentUploadResult] with extracted fields and confidence.
  Future<DocumentUploadResult> uploadDocument(File file) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/documents/upload');

    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return DocumentUploadResult.fromJson(json);
    } else {
      final detail = _tryDecodeError(response.body);
      throw DocumentServiceException(
        code: 'upload_failed',
        message: detail ?? 'Upload failed (${response.statusCode}).',
      );
    }
  }

  /// Upload a bank statement (CSV or PDF) for transaction analysis.
  ///
  /// Returns a [BankStatementResult] with extracted transactions and summaries.
  Future<BankStatementResult> uploadBankStatement(File file) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/documents/upload-statement');

    final request = http.MultipartRequest('POST', uri);
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse =
        await request.send().timeout(const Duration(seconds: 120));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200 || response.statusCode == 201) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return BankStatementResult.fromJson(json);
    } else {
      final detail = _tryDecodeError(response.body);
      throw DocumentServiceException(
        code: 'statement_upload_failed',
        message: detail ?? 'Bank statement upload failed (${response.statusCode}).',
      );
    }
  }

  /// List all documents uploaded by the current user.
  Future<List<DocumentSummary>> listDocuments() async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/documents/');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .get(uri, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final list = jsonDecode(response.body) as List<dynamic>;
      return list
          .map((item) =>
              DocumentSummary.fromJson(item as Map<String, dynamic>))
          .toList();
    } else {
      throw DocumentServiceException(
        code: 'list_failed',
        message: 'Failed to load documents (${response.statusCode}).',
      );
    }
  }

  /// Delete a document by its ID.
  Future<bool> deleteDocument(String id) async {
    final token = await AuthService.getToken();
    final uri = Uri.parse('$_baseUrl/documents/$id');
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final response = await http
        .delete(uri, headers: headers)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 204) {
      return true;
    } else {
      throw DocumentServiceException(
        code: 'delete_failed',
        message: 'Failed to delete document (${response.statusCode}).',
      );
    }
  }

  String? _tryDecodeError(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      return json['detail'] as String? ?? json['message'] as String?;
    } catch (_) {
      return null;
    }
  }
}

/// Custom exception for DocumentService errors.
class DocumentServiceException implements Exception {
  final String code;
  final String message;

  const DocumentServiceException({required this.code, required this.message});

  @override
  String toString() => 'DocumentServiceException($code): $message';
}
