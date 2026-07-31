import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';

// ────────────────────────────────────────────────────────────
//  D4 vérités (2026-07-31) — the coach opens with one bubble then leaves a
//  blank space down to « Dis-moi. ». resolveCoachStarterSuggestions() picks up
//  to 3 profile-adaptive starter questions to fill that space and guide the
//  entry. This exercises the selection without mounting the full screen.
// ────────────────────────────────────────────────────────────

GoalA _goal() => GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(2050, 12, 31),
      label: 'Retraite',
    );

CoachProfile _profile({
  required int birthYear,
  String employmentStatus = 'salarie',
  CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
}) =>
    CoachProfile(
      firstName: 'Test',
      birthYear: birthYear,
      canton: 'VD',
      salaireBrutMensuel: 8000,
      employmentStatus: employmentStatus,
      etatCivil: etatCivil,
      goalA: _goal(),
    );

void main() {
  late S l10n;

  setUpAll(() async {
    l10n = await S.delegate.load(const Locale('fr'));
  });

  test('always returns exactly 3 distinct suggestions', () {
    for (final p in <CoachProfile?>[
      null,
      _profile(birthYear: 1995),
      _profile(birthYear: 1960, etatCivil: CoachCivilStatus.marie),
      _profile(birthYear: 1985, employmentStatus: 'independant'),
    ]) {
      final out = resolveCoachStarterSuggestions(p, l10n);
      expect(out.length, 3, reason: 'profile=$p');
      expect(out.toSet().length, 3, reason: 'no duplicates: $out');
    }
  });

  test('plain salaried under 50 → life-event-diverse base (not retirement-first)',
      () {
    final out = resolveCoachStarterSuggestions(_profile(birthYear: 1995), l10n);
    expect(out, <String>[
      l10n.coachStarterSuggestionLpp,
      l10n.coachStarterSuggestion3a,
      l10n.coachStarterSuggestionBudget,
    ]);
  });

  test('null profile falls back to the base three', () {
    final out = resolveCoachStarterSuggestions(null, l10n);
    expect(out, <String>[
      l10n.coachStarterSuggestionLpp,
      l10n.coachStarterSuggestion3a,
      l10n.coachStarterSuggestionBudget,
    ]);
  });

  test('couple aged >= 50 surfaces rente-vs-capital and couple questions first',
      () {
    final out = resolveCoachStarterSuggestions(
      _profile(birthYear: 1960, etatCivil: CoachCivilStatus.marie),
      l10n,
    );
    expect(out, <String>[
      l10n.coachStarterSuggestionRenteCapital,
      l10n.coachStarterSuggestionCouple,
      l10n.coachStarterSuggestionLpp,
    ]);
  });

  test('self-employed under 50 surfaces the independent question first', () {
    final out = resolveCoachStarterSuggestions(
      _profile(birthYear: 1985, employmentStatus: 'independant'),
      l10n,
    );
    expect(out, <String>[
      l10n.coachStarterSuggestionIndependant,
      l10n.coachStarterSuggestionLpp,
      l10n.coachStarterSuggestion3a,
    ]);
  });
}
