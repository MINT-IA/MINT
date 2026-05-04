// ────────────────────────────────────────────────────────────────────
//  ResponseCardService — FATCA archetype assertion
// ────────────────────────────────────────────────────────────────────
//
//  Closes a gap surfaced by the post-Handoff-2-sweep panel
//  (.planning/decisions/2026-05-04-post-handoff2-sweep-panel.md, rec #3) :
//  the « expatUs » FATCA archetype branch in
//  `response_card_service.dart:583` was never asserted by a widget /
//  service test, so a regression there could ship silently.
//
//  This file only tests the FATCA branch — keeps the diff focused and
//  separate from the broader response_card_service_test.dart suite.
// ────────────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations_fr.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/response_card_service.dart';

final _l = SFr();

CoachProfile _profile({
  required String nationality,
  required int birthYear,
  double salaire = 6000,
}) {
  return CoachProfile(
    salaireBrutMensuel: salaire,
    nombreDeMois: 12.0,
    canton: 'VD',
    birthYear: birthYear,
    employmentStatus: 'salarie',
    etatCivil: CoachCivilStatus.celibataire,
    nationality: nationality,
    prevoyance: const PrevoyanceProfile(),
    patrimoine: const PatrimoineProfile(),
    depenses: const DepensesProfile(),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050),
      label: 'Retraite',
    ),
  );
}

void main() {
  group('ResponseCardService — FATCA archetype branch', () {
    test('expatUs profile resolves to FinancialArchetype.expatUs', () {
      final p = _profile(nationality: 'US', birthYear: 1985);
      expect(p.archetype, FinancialArchetype.expatUs);
    });

    test('non-US profile does NOT resolve to expatUs', () {
      final ch = _profile(nationality: 'CH', birthYear: 1985);
      final fr = _profile(nationality: 'FR', birthYear: 1985);
      expect(ch.archetype, isNot(FinancialArchetype.expatUs));
      expect(fr.archetype, isNot(FinancialArchetype.expatUs));
    });

    test('expatUs profile cannot contribute to 3a (FATCA blocker)', () {
      // US citizens are blocked from pillar 3a per
      // CoachProfile.canContribute3a (most Swiss 3a providers refuse
      // FATCA-reportable persons). Asserts the LSFin-aligned guard.
      final p = _profile(nationality: 'US', birthYear: 1985);
      expect(p.canContribute3a, isFalse);
    });

    test('suggestedPrompts surfaces rcSuggestedPromptFatca for expatUs', () {
      // Use a phase that yields ≤ 2 lifecycle prompts so the take(3)
      // truncation does not clip the cross-phase FATCA prompt.
      // Construction phase (age 30) emits 2 prompts → +1 FATCA = 3 total.
      final p = _profile(nationality: 'US', birthYear: 1996);
      final prompts = ResponseCardService.suggestedPrompts(p, l: _l);

      expect(
        prompts,
        contains(_l.rcSuggestedPromptFatca),
        reason: 'expatUs archetype must surface the FATCA suggested prompt — '
            'ResponseCardService:583 branch coverage',
      );
    });

    test('suggestedPrompts does NOT surface FATCA for swissNative', () {
      final p = _profile(nationality: 'CH', birthYear: 1996);
      final prompts = ResponseCardService.suggestedPrompts(p, l: _l);

      expect(
        prompts,
        isNot(contains(_l.rcSuggestedPromptFatca)),
        reason: 'Non-expatUs profile must not see the FATCA prompt',
      );
    });
  });
}
