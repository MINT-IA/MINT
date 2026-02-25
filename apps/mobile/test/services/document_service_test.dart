import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/document_service.dart';

void main() {
  // ──────────────────────────────────────────────────────────
  // LppExtractedFields — fromJson / toJson / fieldsFound
  // ──────────────────────────────────────────────────────────

  group('LppExtractedFields', () {
    test('fromJson parses all fields from complete JSON', () {
      final json = {
        'avoir_obligatoire': 120000.0,
        'avoir_surobligatoire': 35000.0,
        'avoir_vieillesse_total': 155000.0,
        'salaire_assure': 85320.0,
        'salaire_avs': 95000.0,
        'deduction_coordination': 26460.0,
        'taux_conversion_obligatoire': 6.8,
        'taux_conversion_surobligatoire': 5.0,
        'taux_conversion_enveloppe': 5.6,
        'rente_invalidite': 2400.0,
        'capital_deces': 180000.0,
        'rente_conjoint': 1200.0,
        'rente_enfant': 480.0,
        'rachat_maximum': 45000.0,
        'cotisation_employe': 650.0,
        'cotisation_employeur': 780.0,
      };

      final fields = LppExtractedFields.fromJson(json);

      expect(fields.avoirObligatoire, 120000.0);
      expect(fields.avoirSurobligatoire, 35000.0);
      expect(fields.avoirVieillesseTotal, 155000.0);
      expect(fields.salaireAssure, 85320.0);
      expect(fields.salaireAvs, 95000.0);
      expect(fields.deductionCoordination, 26460.0);
      expect(fields.tauxConversionObligatoire, 6.8);
      expect(fields.tauxConversionSurobligatoire, 5.0);
      expect(fields.tauxConversionEnveloppe, 5.6);
      expect(fields.renteInvalidite, 2400.0);
      expect(fields.capitalDeces, 180000.0);
      expect(fields.renteConjoint, 1200.0);
      expect(fields.renteEnfant, 480.0);
      expect(fields.rachatMaximum, 45000.0);
      expect(fields.cotisationEmploye, 650.0);
      expect(fields.cotisationEmployeur, 780.0);
    });

    test('fromJson handles empty JSON (all null)', () {
      final fields = LppExtractedFields.fromJson({});

      expect(fields.avoirObligatoire, isNull);
      expect(fields.avoirSurobligatoire, isNull);
      expect(fields.salaireAssure, isNull);
      expect(fields.tauxConversionObligatoire, isNull);
      expect(fields.capitalDeces, isNull);
      expect(fields.rachatMaximum, isNull);
    });

    test('fromJson converts int values to double', () {
      final json = {
        'avoir_obligatoire': 120000,
        'salaire_avs': 95000,
      };

      final fields = LppExtractedFields.fromJson(json);

      expect(fields.avoirObligatoire, 120000.0);
      expect(fields.salaireAvs, 95000.0);
    });

    test('fromJson converts String values to double', () {
      final json = {
        'avoir_obligatoire': '120000.50',
        'taux_conversion_obligatoire': '6.8',
      };

      final fields = LppExtractedFields.fromJson(json);

      expect(fields.avoirObligatoire, 120000.50);
      expect(fields.tauxConversionObligatoire, 6.8);
    });

    test('fromJson returns null for unparseable strings', () {
      final json = {
        'avoir_obligatoire': 'not_a_number',
        'salaire_avs': '',
      };

      final fields = LppExtractedFields.fromJson(json);

      expect(fields.avoirObligatoire, isNull);
      expect(fields.salaireAvs, isNull);
    });

    test('fromJson returns null for unsupported types', () {
      final json = {
        'avoir_obligatoire': [1, 2, 3],
        'salaire_avs': {'nested': true},
      };

      final fields = LppExtractedFields.fromJson(json);

      expect(fields.avoirObligatoire, isNull);
      expect(fields.salaireAvs, isNull);
    });

    test('fieldsFound returns count of non-null fields', () {
      final fields = LppExtractedFields(
        avoirObligatoire: 100000.0,
        salaireAssure: 85000.0,
        tauxConversionObligatoire: 6.8,
      );

      expect(fields.fieldsFound, 3);
    });

    test('fieldsFound returns 0 for empty fields', () {
      const fields = LppExtractedFields();
      expect(fields.fieldsFound, 0);
    });

    test('fieldsFound returns fieldsTotal for complete object', () {
      final json = {
        'avoir_obligatoire': 1.0,
        'avoir_surobligatoire': 2.0,
        'avoir_vieillesse_total': 3.0,
        'salaire_assure': 4.0,
        'salaire_avs': 5.0,
        'deduction_coordination': 6.0,
        'taux_conversion_obligatoire': 7.0,
        'taux_conversion_surobligatoire': 8.0,
        'taux_conversion_enveloppe': 9.0,
        'rente_invalidite': 10.0,
        'capital_deces': 11.0,
        'rente_conjoint': 12.0,
        'rente_enfant': 13.0,
        'rachat_maximum': 14.0,
        'cotisation_employe': 15.0,
        'cotisation_employeur': 16.0,
      };

      final fields = LppExtractedFields.fromJson(json);
      expect(fields.fieldsFound, LppExtractedFields.fieldsTotal);
      expect(fields.fieldsFound, 16);
    });

    test('fieldsTotal constant equals 16', () {
      expect(LppExtractedFields.fieldsTotal, 16);
    });

    test('toJson only includes non-null fields', () {
      final fields = LppExtractedFields(
        avoirObligatoire: 100000.0,
        salaireAssure: 85000.0,
      );

      final json = fields.toJson();

      expect(json.length, 2);
      expect(json['avoir_obligatoire'], 100000.0);
      expect(json['salaire_assure'], 85000.0);
      expect(json.containsKey('avoir_surobligatoire'), false);
    });

    test('toJson returns empty map for empty fields', () {
      const fields = LppExtractedFields();
      final json = fields.toJson();
      expect(json, isEmpty);
    });

    test('fromJson/toJson round-trip preserves values', () {
      final original = {
        'avoir_obligatoire': 120000.0,
        'avoir_surobligatoire': 35000.0,
        'taux_conversion_obligatoire': 6.8,
        'rachat_maximum': 45000.0,
      };

      final fields = LppExtractedFields.fromJson(original);
      final roundTripped = fields.toJson();

      expect(roundTripped['avoir_obligatoire'], original['avoir_obligatoire']);
      expect(
          roundTripped['avoir_surobligatoire'], original['avoir_surobligatoire']);
      expect(roundTripped['taux_conversion_obligatoire'],
          original['taux_conversion_obligatoire']);
      expect(roundTripped['rachat_maximum'], original['rachat_maximum']);
    });
  });

  // ──────────────────────────────────────────────────────────
  // DocumentUploadResult — fromJson
  // ──────────────────────────────────────────────────────────

  group('DocumentUploadResult', () {
    test('fromJson parses complete response', () {
      final json = {
        'id': 'doc-abc-123',
        'document_type': 'lpp_certificate',
        'extracted_fields': {
          'avoir_obligatoire': 120000.0,
          'salaire_assure': 85000.0,
        },
        'confidence': 0.92,
        'fields_found': 2,
        'fields_total': 16,
        'warnings': ['Some fields could not be extracted'],
      };

      final result = DocumentUploadResult.fromJson(json);

      expect(result.id, 'doc-abc-123');
      expect(result.documentType, VaultDocumentType.lppCertificate);
      expect(result.extractedFields.lpp?.avoirObligatoire, 120000.0);
      expect(result.extractedFields.lpp?.salaireAssure, 85000.0);
      expect(result.confidence, 0.92);
      expect(result.fieldsFound, 2);
      expect(result.fieldsTotal, 16);
      expect(result.warnings, hasLength(1));
      expect(result.warnings.first, contains('could not be extracted'));
    });

    test('fromJson handles missing optional fields with defaults', () {
      final result = DocumentUploadResult.fromJson({});

      expect(result.id, '');
      // Default to lpp_certificate for backward compatibility
      expect(result.documentType, VaultDocumentType.lppCertificate);
      expect(result.confidence, 0.0);
      expect(result.fieldsFound, 0);
      expect(result.fieldsTotal, 0);
      expect(result.warnings, isEmpty);
    });

    test('fromJson handles null extracted_fields', () {
      final json = {
        'id': 'doc-123',
        'extracted_fields': null,
      };

      // Should not throw, uses empty map fallback
      final result = DocumentUploadResult.fromJson(json);
      expect(result.extractedFields.fieldsFound, 0);
    });
  });

  // ──────────────────────────────────────────────────────────
  // DocumentSummary — fromJson
  // ──────────────────────────────────────────────────────────

  group('DocumentSummary', () {
    test('fromJson parses valid summary', () {
      final json = {
        'id': 'doc-abc-123',
        'document_type': 'lpp_certificate',
        'upload_date': '2025-06-15T10:30:00Z',
        'confidence': 0.88,
        'fields_found': 12,
      };

      final summary = DocumentSummary.fromJson(json);

      expect(summary.id, 'doc-abc-123');
      expect(summary.documentType, VaultDocumentType.lppCertificate);
      expect(summary.uploadDate, DateTime.utc(2025, 6, 15, 10, 30));
      expect(summary.confidence, 0.88);
      expect(summary.fieldsFound, 12);
    });

    test('fromJson handles missing fields with defaults', () {
      final summary = DocumentSummary.fromJson({});

      expect(summary.id, '');
      expect(summary.documentType, VaultDocumentType.other);
      expect(summary.confidence, 0.0);
      expect(summary.fieldsFound, 0);
    });

    test('fromJson handles invalid date string', () {
      final json = {
        'upload_date': 'not-a-date',
      };

      // Should not throw; falls back to DateTime.now()
      final summary = DocumentSummary.fromJson(json);
      expect(summary.uploadDate.year, DateTime.now().year);
    });
  });

  // ──────────────────────────────────────────────────────────
  // BankTransaction (document_service) — fromJson / toJson
  // ──────────────────────────────────────────────────────────

  group('BankTransaction (document_service)', () {
    test('fromJson parses complete transaction', () {
      final json = {
        'date': '2025-03-15T00:00:00Z',
        'description': 'Migros Einkauf',
        'amount': -87.35,
        'balance': 8362.65,
        'category': 'Alimentation',
        'subcategory': 'Supermarche',
        'is_recurring': false,
      };

      final tx = BankTransaction.fromJson(json);

      expect(tx.date, DateTime.utc(2025, 3, 15));
      expect(tx.description, 'Migros Einkauf');
      expect(tx.amount, -87.35);
      expect(tx.balance, 8362.65);
      expect(tx.category, 'Alimentation');
      expect(tx.subcategory, 'Supermarche');
      expect(tx.isRecurring, false);
    });

    test('fromJson handles minimal JSON with defaults', () {
      final tx = BankTransaction.fromJson({});

      expect(tx.description, '');
      expect(tx.amount, 0.0);
      expect(tx.balance, isNull);
      expect(tx.category, 'Divers');
      expect(tx.subcategory, isNull);
      expect(tx.isRecurring, false);
    });

    test('toJson produces correct snake_case keys', () {
      final tx = BankTransaction(
        date: DateTime.utc(2025, 3, 15),
        description: 'Loyer',
        amount: -1850.0,
        balance: 6150.0,
        category: 'Logement',
        subcategory: 'Loyer',
        isRecurring: true,
      );

      final json = tx.toJson();

      expect(json['description'], 'Loyer');
      expect(json['amount'], -1850.0);
      expect(json['balance'], 6150.0);
      expect(json['category'], 'Logement');
      expect(json['subcategory'], 'Loyer');
      expect(json['is_recurring'], true);
      expect(json['date'], contains('2025-03-15'));
    });

    test('toJson omits null optional fields', () {
      final tx = BankTransaction(
        date: DateTime.utc(2025, 1, 1),
        description: 'Test',
        amount: 100.0,
        category: 'Revenu',
      );

      final json = tx.toJson();

      expect(json.containsKey('balance'), false);
      expect(json.containsKey('subcategory'), false);
    });
  });

  // ──────────────────────────────────────────────────────────
  // BankStatementResult — fromJson
  // ──────────────────────────────────────────────────────────

  group('BankStatementResult', () {
    test('fromJson parses complete statement result', () {
      final json = {
        'bank_name': 'UBS',
        'period_start': '2025-01-01',
        'period_end': '2025-01-31',
        'currency': 'CHF',
        'transactions': [
          {
            'date': '2025-01-01',
            'description': 'Salaire',
            'amount': 7200.0,
            'category': 'Revenu',
          },
          {
            'date': '2025-01-02',
            'description': 'Loyer',
            'amount': -1850.0,
            'category': 'Logement',
          },
        ],
        'total_credits': 7200.0,
        'total_debits': -1850.0,
        'confidence': 0.95,
        'warnings': ['Low OCR confidence on page 2'],
        'category_summary': {
          'Revenu': 7200.0,
          'Logement': 1850.0,
        },
        'recurring_monthly': [
          {
            'date': '2025-01-01',
            'description': 'Salaire',
            'amount': 7200.0,
            'category': 'Revenu',
          },
        ],
      };

      final result = BankStatementResult.fromJson(json);

      expect(result.bankName, 'UBS');
      expect(result.periodStart, DateTime(2025, 1, 1));
      expect(result.periodEnd, DateTime(2025, 1, 31));
      expect(result.currency, 'CHF');
      expect(result.transactions, hasLength(2));
      expect(result.totalCredits, 7200.0);
      expect(result.totalDebits, -1850.0);
      expect(result.confidence, 0.95);
      expect(result.warnings, hasLength(1));
      expect(result.categorySummary['Revenu'], 7200.0);
      expect(result.categorySummary['Logement'], 1850.0);
      expect(result.recurringMonthly, hasLength(1));
    });

    test('fromJson handles empty JSON with defaults', () {
      final result = BankStatementResult.fromJson({});

      expect(result.bankName, 'Banque inconnue');
      expect(result.currency, 'CHF');
      expect(result.transactions, isEmpty);
      expect(result.totalCredits, 0.0);
      expect(result.totalDebits, 0.0);
      expect(result.confidence, 0.0);
      expect(result.warnings, isEmpty);
      expect(result.categorySummary, isEmpty);
      expect(result.recurringMonthly, isEmpty);
    });
  });

  // ──────────────────────────────────────────────────────────
  // BudgetImportPreview — fromStatementResult
  // ──────────────────────────────────────────────────────────

  group('BudgetImportPreview', () {
    test('fromStatementResult computes correct savings rate', () {
      final statementResult = BankStatementResult(
        bankName: 'UBS',
        periodStart: DateTime(2025, 1, 1),
        periodEnd: DateTime(2025, 1, 31),
        transactions: const [],
        totalCredits: 7200.0,
        totalDebits: -5000.0,
        confidence: 0.9,
        categorySummary: {
          'Logement': 1850.0,
          'Alimentation': 600.0,
          'Transport': 400.0,
        },
      );

      final preview = BudgetImportPreview.fromStatementResult(statementResult);

      expect(preview.estimatedMonthlyIncome, 7200.0);
      expect(preview.estimatedMonthlyExpenses, 5000.0);
      // savingsRate = (7200 - 5000) / 7200 * 100 ≈ 30.56%
      expect(preview.savingsRate, closeTo(30.56, 0.1));
    });

    test('fromStatementResult sorts categories by amount descending', () {
      final statementResult = BankStatementResult(
        bankName: 'Test',
        periodStart: DateTime(2025, 1, 1),
        periodEnd: DateTime(2025, 1, 31),
        transactions: const [],
        totalCredits: 7200.0,
        totalDebits: -3000.0,
        confidence: 0.9,
        categorySummary: {
          'Transport': 400.0,
          'Logement': 1850.0,
          'Alimentation': 600.0,
        },
      );

      final preview = BudgetImportPreview.fromStatementResult(statementResult);

      expect(preview.topCategories[0].key, 'Logement');
      expect(preview.topCategories[0].value, 1850.0);
      expect(preview.topCategories[1].key, 'Alimentation');
      expect(preview.topCategories[2].key, 'Transport');
    });

    test('fromStatementResult handles zero income gracefully', () {
      final statementResult = BankStatementResult(
        bankName: 'Test',
        periodStart: DateTime(2025, 1, 1),
        periodEnd: DateTime(2025, 1, 31),
        transactions: const [],
        totalCredits: 0.0,
        totalDebits: -500.0,
        confidence: 0.5,
      );

      final preview = BudgetImportPreview.fromStatementResult(statementResult);

      expect(preview.estimatedMonthlyIncome, 0.0);
      expect(preview.savingsRate, 0.0); // No division by zero
    });

    test('fromStatementResult uses recurring from statement', () {
      final recurringTx = BankTransaction(
        date: DateTime(2025, 1, 1),
        description: 'Salaire',
        amount: 7200.0,
        category: 'Revenu',
        isRecurring: true,
      );

      final statementResult = BankStatementResult(
        bankName: 'Test',
        periodStart: DateTime(2025, 1, 1),
        periodEnd: DateTime(2025, 1, 31),
        transactions: [recurringTx],
        totalCredits: 7200.0,
        totalDebits: 0.0,
        confidence: 0.9,
        recurringMonthly: [recurringTx],
      );

      final preview = BudgetImportPreview.fromStatementResult(statementResult);

      expect(preview.recurringCharges, hasLength(1));
      expect(preview.recurringCharges.first.description, 'Salaire');
    });
  });

  // ──────────────────────────────────────────────────────────
  // DocumentServiceException
  // ──────────────────────────────────────────────────────────

  group('DocumentServiceException', () {
    test('toString contains code and message', () {
      const exception = DocumentServiceException(
        code: 'upload_failed',
        message: 'Upload failed (500).',
      );

      final str = exception.toString();

      expect(str, contains('upload_failed'));
      expect(str, contains('Upload failed (500).'));
    });

    test('implements Exception interface', () {
      const exception = DocumentServiceException(
        code: 'test',
        message: 'test message',
      );

      expect(exception, isA<Exception>());
    });
  });
}
