import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/navigation/route_planner.dart';
import 'package:mint_mobile/services/navigation/screen_registry.dart';

RouteDecision _planFor(CoachProfile profile, String requiredField) {
  final registry = InMemoryScreenRegistry([
    ScreenEntry(
      route: '/default-sensitive',
      intentTag: 'default_sensitive_$requiredField',
      behavior: ScreenBehavior.decisionCanvas,
      requiredFields: [requiredField],
    ),
  ]);
  return RoutePlanner(registry: registry, profile: profile).plan(
    'default_sensitive_$requiredField',
  );
}

void main() {
  test('display estimates do not become known completion facts', () {
    final profile = CoachProfile.fromWizardAnswers(const {});

    expect(profile.canton, 'ZH');
    expect(profile.depenses.loyer, 1500);
    expect(profile.prevoyance.tauxConversion, isNotNull);
    expect(profile.userProvidedFields, isNot(contains('canton')));
    expect(profile.userProvidedFields, isNot(contains('monthlyExpenses')));
    expect(profile.userProvidedFields, isNot(contains('conversionRate')));
    expect(profile.dataTimestamps, isNot(contains('canton')));
    expect(profile.dataTimestamps, isNot(contains('depenses.loyer')));
    expect(
      profile.dataTimestamps,
      isNot(contains('prevoyance.tauxConversion')),
    );
  });

  group('display defaults force the partial-plus-ask route path', () {
    test('default canton must ask before routing', () {
      final decision = _planFor(
        CoachProfile.fromWizardAnswers(const {}),
        'canton',
      );

      expect(decision.action, RouteAction.askFirst);
      expect(decision.willNavigate, isFalse);
      expect(decision.missingFields, contains('canton'));
    });

    for (final field in ['loyer', 'conversionRate']) {
      test('default $field remains partial with a missing-fact ask', () {
        final profile = CoachProfile.fromWizardAnswers(const {});
        final decision = _planFor(profile, field);
        expect(
          decision.action,
          RouteAction.openWithWarning,
          reason: '$field is an estimate until an explicit ledger fact exists',
        );
        expect(decision.missingFields, contains(field));
      });
    }
  });

  test('only explicit values acquire known markers', () {
    final profile = CoachProfile.fromWizardAnswers(const {
      'q_canton': 'VD',
      'q_housing_cost_period_chf': 2100,
      'q_lamal_premium_monthly_chf': 420,
      '_coach_taux_conversion': 0.057,
    });

    expect(
        profile.userProvidedFields,
        containsAll([
          'canton',
          'monthlyExpenses',
          'conversionRate',
        ]));
    expect(profile.dataTimestamps, contains('canton'));
    expect(profile.dataTimestamps, contains('depenses.loyer'));
    expect(profile.dataTimestamps, contains('prevoyance.tauxConversion'));
  });

  group('explicit facts, unlike display defaults, unlock readiness', () {
    for (final field in ['canton', 'loyer', 'conversionRate']) {
      test('explicit $field unlocks the route', () {
        final profile = CoachProfile.fromWizardAnswers(const {
          'q_canton': 'VD',
          'q_housing_cost_period_chf': 2100,
          '_coach_taux_conversion': 0.057,
        });
        final decision = _planFor(profile, field);
        expect(
          decision.action,
          RouteAction.openScreen,
          reason: '$field has an explicit value and known-fact marker',
        );
        expect(decision.missingFields, isNull);
      });
    }
  });

  group('invalid persisted values never become known facts', () {
    for (final invalidCanton in ['XX', '', '   ']) {
      test('invalid canton "$invalidCanton" cannot reuse a stale timestamp',
          () {
        final profile = CoachProfile.fromWizardAnswers({
          'q_canton': invalidCanton,
          '_coach_data_timestamps': const {
            'canton': '2026-07-12T12:00:00.000Z',
          },
        });

        expect(profile.canton, 'ZH');
        expect(profile.userProvidedFields, isNot(contains('canton')));
        expect(profile.dataTimestamps, isNot(contains('canton')));
        expect(_planFor(profile, 'canton').action, RouteAction.askFirst);
      });
    }

    test('readiness rejects a non-canton even with forged evidence', () {
      final corrupted = CoachProfile.fromWizardAnswers(const {
        'q_canton': 'VD',
      }).copyWith(
        canton: 'XX',
        userProvidedFields: const {'canton'},
        dataTimestamps: {
          'canton': DateTime.utc(2026, 7, 12, 12),
        },
      );

      expect(_planFor(corrupted, 'canton').action, RouteAction.askFirst);
    });

    test('valid canton is normalized and keeps canonical evidence', () {
      final profile = CoachProfile.fromWizardAnswers(const {
        'q_canton': ' vd ',
        '_coach_data_timestamps': {
          'canton': '2026-07-12T12:00:00.000Z',
        },
      });

      expect(profile.canton, 'VD');
      expect(profile.userProvidedFields, contains('canton'));
      expect(profile.dataTimestamps['canton'], DateTime.utc(2026, 7, 12, 12));
      expect(_planFor(profile, 'canton').action, RouteAction.openScreen);
    });

    final invalidNonNegativeAmounts = <dynamic>[
      'abc',
      -1,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ];

    for (final invalid in invalidNonNegativeAmounts) {
      test('invalid housing $invalid keeps its display default partial', () {
        final profile = CoachProfile.fromWizardAnswers({
          'q_housing_cost_period_chf': invalid,
          'q_lamal_premium_monthly_chf': 420,
          '_coach_data_timestamps': const {
            'depenses.loyer': '2026-07-12T12:00:00.000Z',
          },
        });

        expect(profile.depenses.loyer, 1500);
        expect(profile.userProvidedFields, isNot(contains('housingCost')));
        expect(profile.userProvidedFields, isNot(contains('monthlyExpenses')));
        expect(profile.dataTimestamps, isNot(contains('depenses.loyer')));
        expect(_planFor(profile, 'loyer').action, RouteAction.openWithWarning);
        expect(
          _planFor(profile, 'totalCharges').action,
          RouteAction.openWithWarning,
        );
      });

      test('invalid Lamal $invalid cannot complete monthly expenses', () {
        final profile = CoachProfile.fromWizardAnswers({
          'q_housing_cost_period_chf': 2100,
          'q_lamal_premium_monthly_chf': invalid,
          '_coach_data_timestamps': const {
            'depenses.assuranceMaladie': '2026-07-12T12:00:00.000Z',
          },
        });

        expect(profile.depenses.assuranceMaladie, greaterThan(0));
        expect(profile.userProvidedFields, isNot(contains('monthlyExpenses')));
        expect(
          profile.dataTimestamps,
          isNot(contains('depenses.assuranceMaladie')),
        );
        expect(
          _planFor(profile, 'totalCharges').action,
          RouteAction.openWithWarning,
        );
      });
    }

    final invalidConversionRates = <dynamic>[
      'abc',
      0,
      -0.01,
      double.nan,
      double.infinity,
      double.negativeInfinity,
    ];

    for (final invalid in invalidConversionRates) {
      test('invalid conversion rate $invalid keeps fallback partial', () {
        final profile = CoachProfile.fromWizardAnswers({
          '_coach_taux_conversion': invalid,
          '_coach_data_timestamps': const {
            'prevoyance.tauxConversion': '2026-07-12T12:00:00.000Z',
          },
        });

        expect(profile.prevoyance.tauxConversion, greaterThan(0));
        expect(profile.userProvidedFields, isNot(contains('conversionRate')));
        expect(
          profile.dataTimestamps,
          isNot(contains('prevoyance.tauxConversion')),
        );
        expect(
          _planFor(profile, 'conversionRate').action,
          RouteAction.openWithWarning,
        );
      });
    }

    test('valid numeric strings preserve persisted canonical timestamps', () {
      final profile = CoachProfile.fromWizardAnswers(const {
        'q_housing_cost_period_chf': '2100',
        'q_lamal_premium_monthly_chf': '420',
        '_coach_taux_conversion': '0.057',
        '_coach_data_timestamps': {
          'depenses.loyer': '2026-07-12T12:00:00.000Z',
          'depenses.assuranceMaladie': '2026-07-12T12:01:00.000Z',
          'prevoyance.tauxConversion': '2026-07-12T12:02:00.000Z',
        },
      });

      expect(profile.depenses.loyer, 2100);
      expect(profile.depenses.assuranceMaladie, 420);
      expect(profile.prevoyance.tauxConversion, 0.057);
      expect(
        profile.userProvidedFields,
        containsAll(['housingCost', 'monthlyExpenses', 'conversionRate']),
      );
      expect(
        profile.dataTimestamps['depenses.loyer'],
        DateTime.utc(2026, 7, 12, 12),
      );
      expect(
        profile.dataTimestamps['depenses.assuranceMaladie'],
        DateTime.utc(2026, 7, 12, 12, 1),
      );
      expect(
        profile.dataTimestamps['prevoyance.tauxConversion'],
        DateTime.utc(2026, 7, 12, 12, 2),
      );
    });
  });
}
