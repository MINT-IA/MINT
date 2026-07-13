import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:mint_mobile/services/api_service.dart';

void main() {
  PremierEclairage parse(String? category) {
    return ApiService.parseOnboardingPremierEclairageResponse(
      response: {
        if (category != null) 'category': category,
        'primary_number': 2345,
        'display_text': 'CHF 2\'345 de retraite',
        'explanation_text': 'Copie AVS backend legacy',
        'confidence_mode': 'factual',
      },
      grossSalary: 104000,
    );
  }

  for (final category in ['retirement_gap', 'retirement_income']) {
    test('$category is remapped without backend retirement amount or copy', () {
      final insight = parse(category);

      expect(insight.type, PremierEclairageType.hourlyRate);
      expect(insight.rawValue, 50);
      expect(insight.title, 'Ton salaire brut horaire');
      expect(insight.value, 'CHF\u00a050/h');
      expect(insight.subtitle, isEmpty);
      expect(insight.value, isNot(contains("2'345")));
      expect(insight.subtitle, isNot(contains('AVS')));
    });
  }

  test('missing category fails closed to salary-derived hourly rate', () {
    final insight = parse(null);

    expect(insight.type, PremierEclairageType.hourlyRate);
    expect(insight.rawValue, 50);
    expect(insight.subtitle, isEmpty);
  });

  test('supported non-retirement category preserves backend payload', () {
    final insight = ApiService.parseOnboardingPremierEclairageResponse(
      response: const {
        'category': 'liquidity',
        'primary_number': 1.5,
        'display_text': '1,5 mois de réserve',
        'explanation_text': 'à confirmer',
        'confidence_mode': 'pedagogical',
      },
      grossSalary: 104000,
    );

    expect(insight.type, PremierEclairageType.liquidityAlert);
    expect(insight.rawValue, 1.5);
    expect(insight.subtitle, '1,5 mois de réserve à confirmer');
    expect(
      insight.confidenceMode,
      PremierEclairageConfidence.pedagogical,
    );
  });
}
