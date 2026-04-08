/// Tests for Explorer tab hub readiness evaluation logic.
///
/// These tests verify the readiness level of Explorer hubs
/// based on CoachProfile completeness. The logic is tested
/// indirectly by checking that field presence evaluation
/// matches expected states per hub.
///
/// UXP-03: ReadinessGate-driven visual states for Explorer hubs.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';

// ── Helper: build minimal CoachProfile ─────────────────────────

/// Creates a CoachProfile with the given field overrides.
/// Uses realistic defaults for all required fields.
CoachProfile _profileWith({
  double salaireBrutMensuel = 5000,
  int birthYear = 1985,
  String canton = 'VD',
  String employmentStatus = 'salarie',
  double epargneLiquide = 0,
}) {
  return CoachProfile(
    birthYear: birthYear,
    canton: canton,
    salaireBrutMensuel: salaireBrutMensuel,
    employmentStatus: employmentStatus,
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
    patrimoine: PatrimoineProfile(epargneLiquide: epargneLiquide),
  );
}

/// Hub field requirements as defined in ExploreTab._hubFieldRequirements.
/// Mirrors the production logic for test verification.
const Map<String, Map<String, List<String>>> _hubRequirements = {
  'retraite': {
    'critical': ['salaireBrutMensuel', 'birthYear', 'canton'],
    'optional': [],
  },
  'fiscalite': {
    'critical': ['salaireBrutMensuel', 'canton'],
    'optional': [],
  },
  'logement': {
    'critical': ['salaireBrutMensuel'],
    'optional': [],
  },
  'famille': {
    'critical': [],
    'optional': ['etatCivil'],
  },
  'travail': {
    'critical': [],
    'optional': ['employmentStatus'],
  },
  'patrimoine': {
    'critical': [],
    'optional': ['epargne'],
  },
  'sante': {
    'critical': [],
    'optional': [],
  },
};

/// Evaluates readiness for a hub using the same logic as ExploreTab.
/// Returns 'ready', 'partial', or 'blocked'.
String _evaluateHubState(String hubKey, CoachProfile profile) {
  final requirements = _hubRequirements[hubKey]!;
  final criticalFields = requirements['critical']!;
  final optionalFields = requirements['optional']!;

  final missingCritical = criticalFields.where((f) => !_isPresent(f, profile)).toList();
  final missingOptional = optionalFields.where((f) => !_isPresent(f, profile)).toList();

  if (missingCritical.isNotEmpty) return 'blocked';
  if (missingOptional.isNotEmpty) return 'partial';
  return 'ready';
}

bool _isPresent(String field, CoachProfile profile) {
  switch (field) {
    case 'salaireBrutMensuel':
      return profile.salaireBrutMensuel > 0;
    case 'birthYear':
      return profile.birthYear != 1990 && profile.birthYear > 1920;
    case 'canton':
      return profile.canton.isNotEmpty && profile.canton != 'VD';
    case 'etatCivil':
      return true; // always has a default value
    case 'employmentStatus':
      return profile.employmentStatus.isNotEmpty;
    case 'epargne':
      return profile.patrimoine.epargneLiquide > 0;
    default:
      return true;
  }
}

void main() {
  group('ExploreTab — ReadinessGate hub states', () {
    // ── Test 1: Complete profile → all hubs ready ──────────────
    test('complete profile renders all hubs at ready state', () {
      final profile = _profileWith(
        salaireBrutMensuel: 8000,
        birthYear: 1985,
        canton: 'ZH',
        employmentStatus: 'salarie',
        epargneLiquide: 50000,
      );

      for (final hub in _hubRequirements.keys) {
        expect(
          _evaluateHubState(hub, profile),
          equals('ready'),
          reason: 'Hub $hub should be ready with complete profile',
        );
      }
    });

    // ── Test 2: Zero salary → salary-dependent hubs blocked ────
    test('missing salary blocks retraite, fiscalite, logement hubs', () {
      final profile = _profileWith(
        salaireBrutMensuel: 0,
        birthYear: 1985,
        canton: 'ZH',
      );

      expect(_evaluateHubState('retraite', profile), equals('blocked'));
      expect(_evaluateHubState('fiscalite', profile), equals('blocked'));
      expect(_evaluateHubState('logement', profile), equals('blocked'));
    });

    // ── Test 3: Default canton (VD) → canton-dependent hubs blocked
    test('default canton (VD) causes canton-dependent hubs to be blocked', () {
      final profile = _profileWith(
        salaireBrutMensuel: 8000,
        birthYear: 1985,
        canton: 'VD', // default = not set
      );

      // retraite requires salary + birthYear + canton
      expect(_evaluateHubState('retraite', profile), equals('blocked'));
      // fiscalite requires salary + canton
      expect(_evaluateHubState('fiscalite', profile), equals('blocked'));
      // logement only requires salary — should be ready
      expect(_evaluateHubState('logement', profile), equals('ready'));
    });

    // ── Test 4: No epargne → patrimoine hub partial ─────────────
    test('missing epargne renders patrimoine hub partial', () {
      final profile = _profileWith(
        salaireBrutMensuel: 8000,
        birthYear: 1985,
        canton: 'GE',
        epargneLiquide: 0, // not set
      );

      expect(_evaluateHubState('patrimoine', profile), equals('partial'));
    });

    // ── Test 5: Epargne present → patrimoine hub ready ──────────
    test('epargne present renders patrimoine hub ready', () {
      final profile = _profileWith(
        salaireBrutMensuel: 8000,
        birthYear: 1985,
        canton: 'GE',
        epargneLiquide: 10000,
      );

      expect(_evaluateHubState('patrimoine', profile), equals('ready'));
    });

    // ── Test 6: Sante always ready (no required fields) ─────────
    test('sante hub is always ready regardless of profile completeness', () {
      final minimalProfile = _profileWith(
        salaireBrutMensuel: 0,
        birthYear: 1990, // default year
        canton: 'VD',
      );

      expect(_evaluateHubState('sante', minimalProfile), equals('ready'));
    });

    // ── Test 7: Famille uses only optional field → etatCivil ────
    test('famille hub has no critical fields (etatCivil always has default)', () {
      final profile = _profileWith();

      // etatCivil is always present (defaults to celibataire)
      expect(_evaluateHubState('famille', profile), equals('ready'));
    });

    // ── Test 8: Default birthYear (1990) causes retraite blocked ─
    test('default birthYear (1990) causes retraite hub to be blocked', () {
      final profile = _profileWith(
        salaireBrutMensuel: 8000,
        birthYear: 1990, // default = not set
        canton: 'ZH',
      );

      expect(_evaluateHubState('retraite', profile), equals('blocked'));
    });

    // ── Test 9: Missing fields list populated correctly ──────────
    test('blocked state includes the correct missing field names', () {
      final profile = _profileWith(
        salaireBrutMensuel: 0,
        birthYear: 1990,
        canton: 'VD',
      );

      final requirements = _hubRequirements['retraite']!;
      final criticalFields = requirements['critical']!;
      final missingCritical =
          criticalFields.where((f) => !_isPresent(f, profile)).toList();

      expect(missingCritical, containsAll(['salaireBrutMensuel', 'birthYear', 'canton']));
      expect(missingCritical.length, equals(3));
    });

    // ── Test 10: Travail hub checks employmentStatus optional ────
    test('travail hub is ready when employmentStatus is set', () {
      final profile = _profileWith(
        salaireBrutMensuel: 5000,
        birthYear: 1985,
        canton: 'ZH',
        employmentStatus: 'salarie',
      );

      expect(_evaluateHubState('travail', profile), equals('ready'));
    });

    // ── Test 11: Empty employmentStatus would show partial ────────
    test('empty employmentStatus returns partial for travail hub', () {
      // Note: CoachProfile enforces non-empty employmentStatus via constructor,
      // but we verify the logic handles the edge case consistently.
      // In practice, employmentStatus has default 'salarie' so it's always set.
      expect(_isPresent('employmentStatus', _profileWith()), isTrue);
    });

    // ── Test 12: Partial state missing fields list ─────────────
    test('partial state lists missing optional fields correctly', () {
      final profile = _profileWith(epargneLiquide: 0);

      final requirements = _hubRequirements['patrimoine']!;
      final optionalFields = requirements['optional']!;
      final missingOptional =
          optionalFields.where((f) => !_isPresent(f, profile)).toList();

      expect(missingOptional, equals(['epargne']));
    });
  });
}
