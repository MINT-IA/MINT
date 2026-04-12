import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/auth_service.dart';

/// Exception thrown by [BankImportService] on failures.
class BankImportException implements Exception {
  final String message;
  final int? statusCode;

  const BankImportException(this.message, {this.statusCode});

  @override
  String toString() => message;
}

/// A single parsed bank transaction returned by the backend.
class ImportedTransaction {
  final DateTime date;
  final String description;
  final double amount;
  final double? balance;
  final String category;
  final String? subcategory;
  final bool isRecurring;

  const ImportedTransaction({
    required this.date,
    required this.description,
    required this.amount,
    this.balance,
    this.category = 'Divers',
    this.subcategory,
    this.isRecurring = false,
  });

  factory ImportedTransaction.fromJson(Map<String, dynamic> json) {
    return ImportedTransaction(
      date: DateTime.parse(json['date'] as String),
      description: (json['description'] as String?) ?? '',
      amount: (json['amount'] as num).toDouble(),
      balance: json['balance'] != null
          ? (json['balance'] as num).toDouble()
          : null,
      category: (json['category'] as String?) ?? 'Divers',
      subcategory: json['subcategory'] as String?,
      isRecurring: (json['isRecurring'] as bool?) ?? false,
    );
  }
}

/// Result of importing a bank statement via the backend API.
class BankImportResult {
  final String bankName;
  final String format;
  final List<ImportedTransaction> transactions;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final String currency;
  final double? openingBalance;
  final double? closingBalance;
  final double totalCredits;
  final double totalDebits;
  final Map<String, double> categorySummary;
  final double confidence;
  final int transactionCount;
  final List<String> warnings;

  const BankImportResult({
    required this.bankName,
    required this.format,
    this.transactions = const [],
    this.periodStart,
    this.periodEnd,
    this.currency = 'CHF',
    this.openingBalance,
    this.closingBalance,
    this.totalCredits = 0.0,
    this.totalDebits = 0.0,
    this.categorySummary = const {},
    this.confidence = 0.0,
    this.transactionCount = 0,
    this.warnings = const [],
  });

  factory BankImportResult.fromJson(Map<String, dynamic> json) {
    final txList = (json['transactions'] as List<dynamic>?)
            ?.map((e) =>
                ImportedTransaction.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    final catSummary = <String, double>{};
    final rawCat = json['categorySummary'] as Map<String, dynamic>?;
    if (rawCat != null) {
      for (final entry in rawCat.entries) {
        catSummary[entry.key] = (entry.value as num).toDouble();
      }
    }

    return BankImportResult(
      bankName: (json['bankName'] as String?) ?? 'Unknown',
      format: (json['format'] as String?) ?? 'unknown',
      transactions: txList,
      periodStart: json['periodStart'] != null
          ? DateTime.tryParse(json['periodStart'] as String)
          : null,
      periodEnd: json['periodEnd'] != null
          ? DateTime.tryParse(json['periodEnd'] as String)
          : null,
      currency: (json['currency'] as String?) ?? 'CHF',
      openingBalance: json['openingBalance'] != null
          ? (json['openingBalance'] as num).toDouble()
          : null,
      closingBalance: json['closingBalance'] != null
          ? (json['closingBalance'] as num).toDouble()
          : null,
      totalCredits: (json['totalCredits'] as num?)?.toDouble() ?? 0.0,
      totalDebits: (json['totalDebits'] as num?)?.toDouble() ?? 0.0,
      categorySummary: catSummary,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      transactionCount: (json['transactionCount'] as int?) ?? txList.length,
      warnings:
          (json['warnings'] as List<dynamic>?)?.cast<String>() ?? const [],
    );
  }
}

/// Service for importing bank statements via the MINT backend.
///
/// Calls POST /api/v1/bank-import/import with a file upload.
class BankImportService {
  /// Upload a bank statement file and get parsed results.
  ///
  /// Accepts .csv and .xml files. The backend auto-detects the bank format
  /// (UBS, PostFinance, Raiffeisen, BCGE/BCV, CS/ZKB, Yuh/Neon, ISO 20022).
  ///
  /// Throws [BankImportException] on failure.
  Future<BankImportResult> importStatement(File file) async {
    final baseUrl = ApiService.baseUrl;
    final uri = Uri.parse('$baseUrl/bank-import/import');

    final request = http.MultipartRequest('POST', uri);

    // Add auth token if available
    final token = await AuthService.getToken();
    if (token != null) {
      request.headers['Authorization'] = 'Bearer $token';
    }

    // Attach file
    final filename = file.path.split('/').last;
    request.files.add(
      await http.MultipartFile.fromPath('file', file.path, filename: filename),
    );

    try {
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();

      if (streamedResponse.statusCode == 200) {
        final json = jsonDecode(responseBody) as Map<String, dynamic>;
        return BankImportResult.fromJson(json);
      }

      // Error handling
      String errorMessage;
      try {
        final errorJson = jsonDecode(responseBody) as Map<String, dynamic>;
        final detail = errorJson['detail'];
        if (detail is Map) {
          errorMessage = (detail['error'] as String?) ??
              'Erreur lors de l\'import du releve.';
        } else if (detail is String) {
          errorMessage = detail;
        } else {
          errorMessage = 'Erreur lors de l\'import du releve.';
        }
      } catch (_) {
        errorMessage = 'Erreur lors de l\'import du releve.';
      }

      throw BankImportException(
        errorMessage,
        statusCode: streamedResponse.statusCode,
      );
    } on BankImportException {
      rethrow;
    } catch (e) {
      throw const BankImportException(
        'Impossible de contacter le serveur. Verifiez votre connexion.',
      );
    }
  }
}
