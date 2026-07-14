import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

void main() {
  group('CoachProfile.fromWizardAnswers — fiscal dataSources restoration', () {
    test('does not promote legacy tax keys into fiscal provenance', () {
      final answers = <String, dynamic>{
        'q_birth_year': 1980,
        'q_canton': 'VD',
        'q_net_income_period_chf': 7250.0,
        'q_employment_status': 'employed',
        '_coach_tax_source': 'document_scan',
        '_coach_tax_revenu_imposable': 95000.0,
        '_coach_tax_taux_marginal': 32.5,
        '_coach_tax_impot_cantonal': 14000.0,
      };

      final profile = CoachProfile.fromWizardAnswers(answers);

      // Untyped legacy tax facts are quarantined by the provider migration.
      // The generic model parser must never certify or publish them directly.
      expect(profile.dataSources['fiscal.revenuImposable'], isNull);
      expect(profile.dataSources['fiscal.tauxMarginal'], isNull);
      expect(profile.dataSources['fiscal.impots'], isNull);
      expect(profile.dataSources['fiscal.fortuneImposable'], isNull);
    });

    test('does not restore fiscal dataSources without _coach_tax_source', () {
      final answers = <String, dynamic>{
        'q_birth_year': 1985,
        'q_canton': 'ZH',
        'q_net_income_period_chf': 8000.0,
        'q_employment_status': 'employed',
        '_coach_tax_revenu_imposable': 90000.0,
      };

      final profile = CoachProfile.fromWizardAnswers(answers);

      expect(profile.dataSources['fiscal.revenuImposable'], isNull);
    });
  });
}
