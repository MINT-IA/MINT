// PR-D (TRANCHE-FIRSTJOB-SPEC §1 T3) — deterministic seed-fixture proof.
//
// The RED acceptance flow needs to seed a ~25-year-old profile so the
// firstJob life-event card appears on /home. This exercises the pure mapping
// glue (`homeLifeEventSuggestions`) that translates a CoachProfile into the
// suggestion contract, proving a seeded 25yo profile surfaces `/first-job`
// and the home card identifier is scoped to the firstJob entry.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/screens/aujourdhui/home_life_events.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';

CoachProfile _profile({
  int? age = 25,
  CoachCivilStatus civilStatus = CoachCivilStatus.celibataire,
  int children = 0,
  String employment = 'salarie',
  double gross = 6500,
  double? net,
  String canton = 'ZH',
}) {
  final now = DateTime.now();
  return CoachProfile(
    birthYear: age == null ? 0 : now.year - age,
    canton: canton,
    salaireBrutMensuel: gross,
    explicitMonthlyNetIncome: net,
    etatCivil: civilStatus,
    nombreEnfants: children,
    employmentStatus: employment,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(now.year + 40),
      label: 'test',
    ),
  );
}

void main() {
  final s = SFr();

  List<String> routes(CoachProfile p) =>
      homeLifeEventSuggestions(p, s).map((e) => e.route).toList();

  group('homeLifeEventSuggestions — firstJob seed fixture', () {
    test('25yo salaried single profile surfaces the firstJob entry', () {
      expect(routes(_profile(age: 25)), contains('/first-job'));
    });

    test('boundary age 28 still eligible; 29 no longer', () {
      expect(routes(_profile(age: 28)), contains('/first-job'));
      expect(routes(_profile(age: 29)), isNot(contains('/first-job')));
    });

    test('unknown age surfaces nothing rather than a wrong card', () {
      // birthYear == 0 sentinel -> ageOrNull null. Must NOT fall back to age
      // 0 and wrongly show the firstJob (<=28) card.
      expect(homeLifeEventSuggestions(_profile(age: null), s), isEmpty);
    });
  });

  group('homeLifeEventSuggestions — CoachProfile representation mapping', () {
    test('CoachCivilStatus.marie maps to married (naissance eligibility)', () {
      expect(
        routes(_profile(age: 32, civilStatus: CoachCivilStatus.marie)),
        contains('/naissance'),
      );
    });

    test('employmentStatus independant maps to independent tools', () {
      expect(
        routes(_profile(age: 40, employment: 'independant')),
        contains('/segments/independant'),
      );
    });

    test('prefers explicit net, falls back to gross for income gates', () {
      // No explicit net -> gross (6500) used as gating input -> housing
      // purchase gate (>= 5000, age 25-50) triggers.
      expect(routes(_profile(age: 30, gross: 6500)), contains('/hypotheque'));
    });
  });

  group('homeLifeEventCardIdentifier — scoped to firstJob', () {
    LifeEventSuggestion suggestion(String route) => LifeEventSuggestion(
          title: 't',
          reason: 'r',
          icon: Icons.abc,
          route: route,
          color: MintColors.info,
        );

    test('firstJob route gets the contract testID', () {
      expect(
        homeLifeEventCardIdentifier(suggestion('/first-job')),
        'home-lifeevent-card-firstJob',
      );
    });

    test('other routes carry no home identifier', () {
      expect(homeLifeEventCardIdentifier(suggestion('/mariage')), isNull);
      expect(homeLifeEventCardIdentifier(suggestion('/succession')), isNull);
    });
  });
}
