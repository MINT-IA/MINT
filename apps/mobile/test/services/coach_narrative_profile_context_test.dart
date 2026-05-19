// Phase mint-data-architecture-v1-02 W0 Plan 02-01 (D-10 PR-A2) — assert
// that `CoachNarrativeService._buildProfileContext` emits the 15 fields that
// previously sat missing relative to the server's `_PROFILE_SAFE_FIELDS`
// whitelist. Per RESEARCH § D-10 : emit-pattern (not handle-pattern), no
// `> 0` guards so the server sees absent vs zero cleanly.
//
// Remaining ~25 missing fields are tracked in deferred-items.md
// DEFERRED-02-01-B for PR-A3 (Plan 02-04 per D-10).

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach_narrative_service.dart';

// `_buildProfileContext` is a private static method on `CoachNarrativeService`.
// We expose it via the public `buildProfileContextForTest` test hook below.
//
// NOTE : if the test hook is absent (the simplest scenario for Plan 02-01 PR-A2),
// we exercise the same code path via `_buildContextThroughGenerate` (a private
// orchestrator-side hook that wraps it). For now, we keep the test focused on
// the public surface of the new fields. The assertion below scans the output
// of `_buildProfileContext` indirectly by calling a small helper added in
// `coach_narrative_service.dart` for testability.

// Helper : a minimal CoachProfile sufficient for `_buildProfileContext`.
CoachProfile _minimalProfile() {
  return CoachProfile(
    birthYear: 1990,
    canton: 'VD',
    salaireBrutMensuel: 8000,
    etatCivil: CoachCivilStatus.celibataire,
    employmentStatus: 'salarie',
    nombreEnfants: 0,
    primaryFocus: 'proteger_retraite',
    prevoyance: const PrevoyanceProfile(
      totalEpargne3a: 12000,
      avoirLppTotal: 80000,
      tauxConversion: 6.8,
      renteAVSEstimeeMensuelle: 2450,
      anneesContribuees: 18,
      rachatMaximum: 50000,
      rachatEffectue: 10000,
    ),
    depenses: const DepensesProfile(loyer: 3500, assuranceMaladie: 2000),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2055),
      label: 'Retraite à 65 ans',
    ),
  );
}

void main() {
  group('Phase 02 D-10 PR-A2 — _buildProfileContext emits 15 new fields', () {
    test('all 15 new whitelisted keys present in output map', () {
      final profile = _minimalProfile();
      final ctx = CoachNarrativeService.buildProfileContextForTest(profile);

      // The 15 server-canonical fields we ship in this PR. Plan 02-04 PR-A3
      // closes the remaining ~25 per DEFERRED-02-01-B.
      const expectedKeys = <String>[
        'civil_status',
        'marital_status',
        'employment_status',
        'is_married',
        'number_of_children',
        'has_2nd_pillar',
        'monthly_income',
        'monthly_expenses',
        'salaire_brut',
        'avoir_lpp',
        'lpp_balance_total',
        'lpp_capital',
        'lpp_buyback_max',
        'lpp_conversion_rate',
        'avs_rente',
        'avs_annual_estimate',
        'avs_contribution_years',
        'epargne_3a',
        'primary_focus',
      ];
      for (final key in expectedKeys) {
        expect(ctx.containsKey(key), isTrue,
            reason: 'Expected key `$key` in _buildProfileContext output. '
                'D-10 PR-A2 close gap : 40 → 25 missing baseline.');
      }
    });

    test('numeric flow fields carry expected values', () {
      final profile = _minimalProfile();
      final ctx = CoachNarrativeService.buildProfileContextForTest(profile);
      expect(ctx['monthly_income'], 8000);
      expect(ctx['monthly_expenses'], 5500);
      expect(ctx['salaire_brut'], 8000);
      expect(ctx['avoir_lpp'], 80000);
      expect(ctx['avs_rente'], 2450);
      expect(ctx['avs_annual_estimate'], 2450 * 12);
      expect(ctx['epargne_3a'], 12000);
      expect(ctx['number_of_children'], 0);
      expect(ctx['has_2nd_pillar'], isTrue);
      expect(ctx['is_married'], isFalse);
      expect(ctx['primary_focus'], 'proteger_retraite');
    });

    test('absent fields emit zero (not null) when profile lacks data', () {
      // emit-pattern : we ship absent/zero so server sees "not zero, just empty".
      // (Per RESEARCH § D-10 : no `> 0` guard ; server _sanitize drops None anyway.)
      final blank = CoachProfile(
        birthYear: 1990,
        canton: 'VD',
        salaireBrutMensuel: 0,
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2055),
          label: '',
        ),
      );
      final ctx = CoachNarrativeService.buildProfileContextForTest(blank);
      expect(ctx['avoir_lpp'], 0);
      expect(ctx['avs_rente'], 0);
      expect(ctx['epargne_3a'], 0);
    });
  });
}
