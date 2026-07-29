// PR-D (TRANCHE-FIRSTJOB-SPEC §1 T3 / §3.1) — deterministic seed-fixture proof
// + provenance gating ("unknown != default", CLAUDE.md NEVER #7).
//
// The RED acceptance flow needs to seed a ~25-year-old profile so the firstJob
// life-event card appears on /home. This exercises the pure mapping glue
// (`homeLifeEventSuggestions`), proving a seeded 25yo profile surfaces
// `/first-job`, that constructor defaults never fabricate phantom cards, and
// that a gross salary is never treated as a net income.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/screens/aujourdhui/home_life_events.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/life_event_suggestions.dart';

/// Default provenance for the "everything declared" fixtures.
const _allProvided = {'age', 'civilStatus', 'employmentStatus', 'canton'};

CoachProfile _profile({
  int? age = 25,
  CoachCivilStatus civilStatus = CoachCivilStatus.celibataire,
  int children = 0,
  String employment = 'salarie',
  double gross = 6500,
  double? net,
  String canton = 'ZH',
  Set<String> provided = _allProvided,
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
    userProvidedFields: provided,
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
    test('25yo profile with a provided age surfaces the firstJob entry', () {
      expect(routes(_profile(age: 25)), contains('/first-job'));
    });

    test('boundary age 28 still eligible; 29 no longer', () {
      expect(routes(_profile(age: 28)), contains('/first-job'));
      expect(routes(_profile(age: 29)), isNot(contains('/first-job')));
    });

    test('unknown age surfaces nothing rather than a wrong card', () {
      // birthYear == 0 sentinel -> ageOrNull null. Must NOT fall back to age 0.
      expect(homeLifeEventSuggestions(_profile(age: null), s), isEmpty);
    });

    test('age present but not user-provided surfaces nothing', () {
      // A birthYear may exist without the user having declared it -> no age
      // provenance -> no age-driven suggestion.
      expect(homeLifeEventSuggestions(_profile(age: 25, provided: {}), s),
          isEmpty);
    });
  });

  group('homeLifeEventSuggestions — provenance ("unknown != default")', () {
    test('age-only profile surfaces the firstJob card and no phantom card', () {
      // Only the age is declared. celibataire / 0 children / salarie / ZH are
      // constructor defaults, not facts.
      final r = routes(_profile(age: 25, provided: {'age'}));
      expect(r, equals(['/first-job']));
      expect(r, isNot(contains('/mariage'))); // civil default
      expect(r, isNot(contains('/simulator/job-comparison'))); // employment
      expect(r, isNot(contains('/hypotheque'))); // income
      expect(r, isNot(contains('/fiscal'))); // canton default
    });

    test('civil status only counts when provided', () {
      // marie provided -> naissance eligible (married + 0 children).
      expect(
        routes(_profile(
            age: 32,
            civilStatus: CoachCivilStatus.marie,
            provided: {'age', 'civilStatus'})),
        contains('/naissance'),
      );
      // marie present but NOT provided -> no civil-driven card.
      final unprov = routes(_profile(
          age: 32, civilStatus: CoachCivilStatus.marie, provided: {'age'}));
      expect(unprov, isNot(contains('/naissance')));
      expect(unprov, isNot(contains('/mariage')));
    });

    test('employment only counts when provided', () {
      expect(
        routes(_profile(
            age: 40,
            employment: 'independant',
            provided: {'age', 'employmentStatus'})),
        contains('/segments/independant'),
      );
      expect(
        routes(_profile(age: 40, employment: 'independant', provided: {'age'})),
        isNot(contains('/segments/independant')),
      );
    });
  });

  group('homeLifeEventSuggestions — income gates require a known net', () {
    test('gross salary is never treated as net (no phantom income card)', () {
      // High gross, but the net is unknown -> no income-gated suggestion.
      final r = routes(_profile(
        age: 30,
        gross: 7000,
        net: null,
        provided: {'age', 'salary'},
      ));
      expect(r, isNot(contains('/hypotheque'))); // >= 5000 net
      expect(r, isNot(contains('/invalidite'))); // > 6000 net (no kids either)
    });

    test('explicit net opens income gates', () {
      final r = routes(_profile(
        age: 30,
        net: 6500,
        provided: {'age', 'salary'},
      ));
      expect(r, contains('/hypotheque'));
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
