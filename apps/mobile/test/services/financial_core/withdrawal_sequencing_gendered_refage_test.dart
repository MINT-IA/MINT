import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/withdrawal_sequencing_service.dart';

/// beads MINT_nosync-t5r (c) — audit T01-F35.
///
/// Bug prouvé sur dev (withdrawal_sequencing_service.dart:392-395) : la
/// fenêtre OPP3 art. 3 (retrait anticipé 3a 5 ans avant l'âge de référence
/// AVS) lisait `avs.reference_age_men` pour TOUT LE MONDE, alors que
/// `avsReferenceAge(birthYear:, isFemale:)` (AVS21, LAVS art. 21 al. 1)
/// existe déjà dans social_insurance.dart et est déjà utilisé par
/// AvsCalculator et MonteCarloService.
///
/// Note d'honnêteté (0-TRUST) : les cohortes transitoires féminines
/// (naissance ≤ 1963, réf. 64) ont toutes ≥ 63 ans aujourd'hui, et
/// `earliestWithdrawalAge = (réf − 5).clamp(currentAge, 99)` est dominé par
/// `currentAge` pour elles — le défaut n'a donc PAS de delta observable via
/// l'API publique pour une utilisatrice réelle en 2026. Ce test verrouille
/// donc le CÂBLAGE (source de vérité unique, F35) plutôt qu'un comportement :
/// il devient rouge si quelqu'un re-hardcode l'âge hommes pour tous.
void main() {
  final source = File(
    'lib/services/financial_core/withdrawal_sequencing_service.dart',
  ).readAsStringSync();

  group('fenêtre OPP3 — âge de référence genré (câblage F35)', () {
    test('optimize() résout la référence via avsReferenceAge du profil', () {
      expect(
        source.contains('avsReferenceAge(birthYear:'),
        isTrue,
        reason: 'la fenêtre de retrait doit réutiliser avsReferenceAge '
            '(source unique AVS21), pas un âge hommes en dur',
      );
      expect(source.contains("profile.gender == 'F'"), isTrue,
          reason: 'la branche féminine doit être résolue depuis le profil');
    });

    test('_buildOptimizedSequence ne lit plus avs.reference_age_men', () {
      final body = source.split('_buildOptimizedSequence({').last;
      expect(
        body.contains("reg('avs.reference_age_men'"),
        isFalse,
        reason: "l'âge de référence doit être injecté par l'appelant "
            '(résolu selon le genre), pas relu en dur hommes-pour-tous '
            'dans la construction de la séquence',
      );
    });

    test('équivalence H/F hors cohortes transitoires (réf 65 des deux côtés)',
        () {
      WithdrawalSequencingResult run(String? gender) =>
          WithdrawalSequencingService.optimize(
            profile: _buildProfile(birthYear: 1980, gender: gender),
            retirementAge: 65,
          );
      final m = run('M');
      final f = run('F');
      expect(f.optimizedSequence.length, m.optimizedSequence.length);
      for (var i = 0; i < m.optimizedSequence.length; i++) {
        expect(f.optimizedSequence[i].age, m.optimizedSequence[i].age,
            reason: 'femme née en 1980 : réf 65 comme un homme (AVS21 '
                'harmonisé), la séquence doit être identique');
      }
      expect(f.totalTaxOptimized, closeTo(m.totalTaxOptimized, 1e-6));
    });
  });
}

CoachProfile _buildProfile({
  required int birthYear,
  String? gender,
}) {
  const nombre3a = 3;
  const totalEpargne3a = 240000.0;
  final accounts = List.generate(
    nombre3a,
    (i) => Compte3a(
      provider: 'Test Provider ${i + 1}',
      solde: totalEpargne3a / nombre3a,
      rendementEstime: 0.0,
    ),
  );
  return CoachProfile(
    birthYear: birthYear,
    gender: gender,
    canton: 'ZH',
    etatCivil: CoachCivilStatus.celibataire,
    salaireBrutMensuel: 8000,
    prevoyance: PrevoyanceProfile(
      nombre3a: nombre3a,
      totalEpargne3a: totalEpargne3a,
      comptes3a: accounts,
    ),
    goalA: GoalA(
      type: GoalAType.retraite,
      targetDate: DateTime(birthYear + 65, 12, 31),
      label: 'Retraite a 65 ans',
    ),
  );
}
