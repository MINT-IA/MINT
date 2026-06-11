// ────────────────────────────────────────────────────────────
//  Affordability prefill — household income unification (W4)
//
//  Closes couple_acheteurs-1 (MATRIX-illogismes-2026-06-09):
//  AffordabilityScreen is reachable by two routes that previously
//  diverged on the prefilled gross household income —
//    • profile auto-fill (line 64-67) : salaire×nombreDeMois +
//      conjoint×nombreDeMois = 196'800 for the matrix couple.
//    • coach GoRouter prefill (line 115-121) : salaireBrut×13 with
//      the conjoint silently dropped = 106'600 (−45.8%).
//
//  Both routes must now produce the SAME household income via a
//  single helper (revenuBrutMenageFromProfile), so the displayed
//  affordability is identical regardless of entry route. Per ASB
//  directive both spouses count toward mortgage capacity.
//
//  Negative control: solo profile must not be over-counted, and the
//  mortgage_service hard-equity / one-third rules (couple_acheteurs-5)
//  are NOT exercised here — they stay untouched and SOURCED.
// ────────────────────────────────────────────────────────────

import 'package:flutter_test/flutter_test.dart';

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/screens/mortgage/affordability_screen.dart';

CoachProfile _coupleProfile() => CoachProfile(
      birthYear: DateTime.now().year - 33,
      canton: 'VD',
      etatCivil: CoachCivilStatus.marie,
      salaireBrutMensuel: 8200,
      nombreDeMois: 12,
      conjoint: const ConjointProfile(
        salaireBrutMensuel: 8200,
        nombreDeMois: 12,
      ),
      goalA: GoalA(
        type: GoalAType.achatImmo,
        targetDate: DateTime.now().add(const Duration(days: 365)),
        label: 'Achat immo',
      ),
    );

CoachProfile _soloProfile() => CoachProfile(
      birthYear: DateTime.now().year - 33,
      canton: 'VD',
      etatCivil: CoachCivilStatus.celibataire,
      salaireBrutMensuel: 8200,
      nombreDeMois: 12,
      goalA: GoalA(
        type: GoalAType.achatImmo,
        targetDate: DateTime.now().add(const Duration(days: 365)),
        label: 'Achat immo',
      ),
    );

void main() {
  group('revenuBrutMenageFromProfile — single source for both routes', () {
    test('couple 2×8200/mois ×12 → 196800 (both salaries count, ASB)', () {
      final profile = _coupleProfile();
      expect(revenuBrutMenageFromProfile(profile), closeTo(196800, 0.01));
    });

    test('solo profile → no spouse over-count (8200×12 = 98400)', () {
      expect(revenuBrutMenageFromProfile(_soloProfile()), closeTo(98400, 0.01));
    });

    test('uses nombreDeMois, never a hardcoded ×13', () {
      // A 13-month profile yields 8200×13 (=106600) for the solo case —
      // proving the helper honours nombreDeMois rather than a fixed 12 or 13.
      final p13 = CoachProfile(
        birthYear: DateTime.now().year - 33,
        canton: 'VD',
        salaireBrutMensuel: 8200,
        nombreDeMois: 13,
        goalA: GoalA(
          type: GoalAType.achatImmo,
          targetDate: DateTime.now().add(const Duration(days: 365)),
          label: 'Achat immo',
        ),
      );
      expect(revenuBrutMenageFromProfile(p13), closeTo(106600, 0.01));
    });
  });

  group('resolveAffordabilityRevenu — coach prefill vs profile route converge', () {
    test('partial coach prefill (monthly only) completes from household, '
        'never drops the conjoint', () {
      final profile = _coupleProfile();
      // Coach suggests only a monthly salary (the old ×13-with-conjoint-dropped bug).
      // The resolver must complete to the full household income from the profile.
      final coachRoute = resolveAffordabilityRevenu(
        prefill: const {'salaireBrut': 8200},
        profile: profile,
      );
      final profileRoute = resolveAffordabilityRevenu(
        prefill: null,
        profile: profile,
      );
      expect(coachRoute, closeTo(196800, 0.01));
      expect(profileRoute, closeTo(196800, 0.01));
      // Same person, same screen, same answer.
      expect(coachRoute, closeTo(profileRoute!, 0.01));
    });

    test('complete coach prefill (explicit annual household) is honoured', () {
      final profile = _coupleProfile();
      final resolved = resolveAffordabilityRevenu(
        prefill: const {'revenuBrut': 210000},
        profile: profile,
      );
      expect(resolved, closeTo(210000, 0.01));
    });

    test('no prefill and no profile → null (keep hardcoded default)', () {
      expect(resolveAffordabilityRevenu(prefill: null, profile: null), isNull);
    });
  });
}
