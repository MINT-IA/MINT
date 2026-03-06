import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/document_parser/document_models.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('CoachProfileProvider.updateFromTaxExtraction', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('persists canonical tax fields and data sources', () async {
      final provider = CoachProfileProvider();
      provider.updateFromSmartFlow(
        age: 35,
        grossSalary: 120000,
        canton: 'VD',
      );

      final fields = <ExtractedField>[
        const ExtractedField(
          fieldName: 'revenu_imposable',
          label: 'Revenu imposable',
          value: 98500.0,
          confidence: 0.9,
          sourceText: 'Revenu imposable 98\'500',
          needsReview: false,
          profileField: 'actualTaxableIncome',
        ),
        const ExtractedField(
          fieldName: 'fortune_imposable',
          label: 'Fortune imposable',
          value: 12000.0,
          confidence: 0.9,
          sourceText: 'Fortune imposable 12\'000',
          needsReview: false,
          profileField: 'actualTaxableWealth',
        ),
        const ExtractedField(
          fieldName: 'taux_marginal_effectif',
          label: 'Taux marginal effectif',
          value: 31.5,
          confidence: 0.85,
          sourceText: 'Taux marginal 31.5%',
          needsReview: false,
          profileField: 'actualMarginalRate',
        ),
        const ExtractedField(
          fieldName: 'impot_cantonal',
          label: 'Impot cantonal et communal',
          value: 14520.0,
          confidence: 0.88,
          sourceText: 'Impot cantonal 14\'520',
          needsReview: false,
          profileField: 'actualCantonalTax',
        ),
        const ExtractedField(
          fieldName: 'impot_federal',
          label: 'Impot federal direct',
          value: 4230.0,
          confidence: 0.88,
          sourceText: 'IFD 4\'230',
          needsReview: false,
          profileField: 'actualFederalTax',
        ),
      ];

      await provider.updateFromTaxExtraction(fields);

      final profile = provider.profile;
      expect(profile, isNotNull);
      expect(
        profile!.dataSources['fiscal.revenuImposable'],
        ProfileDataSource.certificate,
      );
      expect(
        profile.dataSources['fiscal.fortuneImposable'],
        ProfileDataSource.certificate,
      );
      expect(
        profile.dataSources['fiscal.tauxMarginal'],
        ProfileDataSource.certificate,
      );
      expect(
        profile.dataSources['fiscal.impots'],
        ProfileDataSource.certificate,
      );

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['_coach_tax_revenu_imposable'], 98500.0);
      expect(answers['_coach_tax_fortune_imposable'], 12000.0);
      expect(answers['_coach_tax_taux_marginal'], 31.5);
      expect(answers['_coach_tax_impot_cantonal'], 14520.0);
      expect(answers['_coach_tax_impot_federal'], 4230.0);
      expect(answers['_coach_tax_source'], 'document_scan');
    });

    test('handles missing fields gracefully', () async {
      final provider = CoachProfileProvider();
      provider.updateFromSmartFlow(
        age: 50,
        grossSalary: 100000,
        canton: 'ZH',
      );

      // Only marginal rate extracted
      final fields = <ExtractedField>[
        const ExtractedField(
          fieldName: 'taux_marginal_effectif',
          label: 'Taux marginal effectif',
          value: 28.0,
          confidence: 0.80,
          sourceText: 'Taux marginal 28%',
          needsReview: false,
          profileField: 'actualMarginalRate',
        ),
      ];

      await provider.updateFromTaxExtraction(fields);

      final profile = provider.profile;
      expect(profile, isNotNull);
      expect(
        profile!.dataSources['fiscal.tauxMarginal'],
        ProfileDataSource.certificate,
      );
      // Other fiscal sources should not be set
      expect(profile.dataSources['fiscal.revenuImposable'], isNull);

      final answers = await ReportPersistenceService.loadAnswers();
      expect(answers['_coach_tax_taux_marginal'], 28.0);
      expect(answers['_coach_tax_revenu_imposable'], isNull);
    });

    test('does nothing when no profile exists', () async {
      final provider = CoachProfileProvider();
      // No profile created

      final fields = <ExtractedField>[
        const ExtractedField(
          fieldName: 'revenu_imposable',
          label: 'Revenu imposable',
          value: 98500.0,
          confidence: 0.9,
          sourceText: 'Test',
          needsReview: false,
          profileField: 'actualTaxableIncome',
        ),
      ];

      // Should not throw
      await provider.updateFromTaxExtraction(fields);
      expect(provider.profile, isNull);
    });
  });
}
