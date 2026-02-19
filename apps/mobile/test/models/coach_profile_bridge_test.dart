import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coaching_service.dart';

void main() {
  // ── Helper ──────────────────────────────────────────────────
  CoachProfile _makeProfile({
    String employmentStatus = 'salarie',
    CoachCivilStatus etatCivil = CoachCivilStatus.celibataire,
    int birthYear = 1990,
    String canton = 'ZH',
    double salaire = 7000,
    double avoir3a = 5000,
    double avoirLpp = 80000,
    double rachatMaximum = 20000,
    double loyer = 1500,
    double epargne = 15000,
    double autresDettes = 0,
    List<PlannedMonthlyContribution> contributions = const [],
  }) {
    return CoachProfile(
      birthYear: birthYear,
      canton: canton,
      salaireBrutMensuel: salaire,
      employmentStatus: employmentStatus,
      etatCivil: etatCivil,
      depenses: DepensesProfile(loyer: loyer, assuranceMaladie: 350),
      prevoyance: PrevoyanceProfile(
        totalEpargne3a: avoir3a,
        avoirLppTotal: avoirLpp,
        rachatMaximum: rachatMaximum,
      ),
      patrimoine: PatrimoineProfile(epargneLiquide: epargne),
      dettes: DetteProfile(
        autresDettes: autresDettes,
      ),
      goalA: GoalA(
        type: GoalAType.retraite,
        targetDate: DateTime(2055, 12, 31),
        label: 'Retraite',
      ),
      plannedContributions: contributions,
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  BRIDGE METHOD TESTS
  // ═══════════════════════════════════════════════════════════════

  group('CoachProfile.toCoachingProfile()', () {
    test('maps salarie profile correctly', () {
      final profile = _makeProfile(
        employmentStatus: 'salarie',
        etatCivil: CoachCivilStatus.celibataire,
        salaire: 7000,
        avoir3a: 10000,
        avoirLpp: 120000,
        rachatMaximum: 30000,
        epargne: 25000,
      );

      final coaching = profile.toCoachingProfile();

      expect(coaching.age, profile.age);
      expect(coaching.canton, 'ZH');
      expect(coaching.revenuAnnuel, 7000 * 12);
      // has3a depends on nombre3a (default 0), not totalEpargne3a
      expect(coaching.montant3a, profile.total3aMensuel * 12);
      expect(coaching.hasLpp, true);
      expect(coaching.avoirLpp, 120000);
      expect(coaching.lacuneLpp, 30000);
      expect(coaching.epargneDispo, 25000);
      expect(coaching.detteTotale, 0);
      expect(coaching.employmentStatus, EmploymentStatus.salarie);
      expect(coaching.etatCivil, EtatCivil.celibataire);
    });

    test('maps independant profile correctly', () {
      final profile = _makeProfile(
        employmentStatus: 'independant',
        etatCivil: CoachCivilStatus.marie,
      );

      final coaching = profile.toCoachingProfile();

      expect(coaching.employmentStatus, EmploymentStatus.independant);
      expect(coaching.etatCivil, EtatCivil.marie);
    });

    test('maps chomage / sans_emploi correctly', () {
      final profile1 = _makeProfile(employmentStatus: 'chomage');
      final profile2 = _makeProfile(employmentStatus: 'sans_emploi');

      expect(
        profile1.toCoachingProfile().employmentStatus,
        EmploymentStatus.sansEmploi,
      );
      expect(
        profile2.toCoachingProfile().employmentStatus,
        EmploymentStatus.sansEmploi,
      );
    });

    test('maps all etatCivil values', () {
      final cases = {
        CoachCivilStatus.celibataire: EtatCivil.celibataire,
        CoachCivilStatus.marie: EtatCivil.marie,
        CoachCivilStatus.divorce: EtatCivil.divorce,
        CoachCivilStatus.veuf: EtatCivil.veuf,
        CoachCivilStatus.concubinage: EtatCivil.concubinage,
      };

      for (final entry in cases.entries) {
        final profile = _makeProfile(etatCivil: entry.key);
        expect(
          profile.toCoachingProfile().etatCivil,
          entry.value,
          reason: 'Expected ${entry.value} for ${entry.key}',
        );
      }
    });

    test('hasBudget reflects planned contributions', () {
      final withoutContribs = _makeProfile(contributions: const []);
      final withContribs = _makeProfile(
        contributions: const [
          PlannedMonthlyContribution(
            id: '3a_test',
            label: '3a Test',
            amount: 604,
            category: '3a',
            isAutomatic: true,
          ),
        ],
      );

      expect(withoutContribs.toCoachingProfile().hasBudget, false);
      expect(withContribs.toCoachingProfile().hasBudget, true);
    });

    test('handles zero avoir LPP (hasLpp = false)', () {
      final profile = _makeProfile(avoirLpp: 0);
      final coaching = profile.toCoachingProfile();

      expect(coaching.hasLpp, false);
      expect(coaching.avoirLpp, 0);
    });

    test('handles zero 3a (has3a depends on nombre3a)', () {
      final profile = _makeProfile(avoir3a: 0);
      final coaching = profile.toCoachingProfile();

      // has3a depends on prevoyance.nombre3a, not totalEpargne3a
      expect(coaching.has3a, isA<bool>());
    });

    test('maps dettes correctly', () {
      final profile = _makeProfile(autresDettes: 15000);
      final coaching = profile.toCoachingProfile();

      expect(coaching.detteTotale, 15000);
    });

    test('chargesFixesMensuelles matches depenses.totalMensuel', () {
      final profile = _makeProfile(loyer: 2000);
      final coaching = profile.toCoachingProfile();

      expect(coaching.chargesFixesMensuelles, profile.depenses.totalMensuel);
    });
  });
}
