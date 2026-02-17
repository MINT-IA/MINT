import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/unemployment_service.dart';

/// Unit tests for UnemploymentService — Sprint S19 (Chomage / LACI)
///
/// Tests pure Dart financial calculations for Swiss unemployment benefits:
///   - Indemnity rate determination (70% / 80%)
///   - Duration based on age and contribution months
///   - Waiting period (delai de carence)
///   - Gain assure capping
///   - Edge cases (zero income, max insured salary, boundary ages)
///   - Timeline completeness
///   - Chiffre choc and formatting
///
/// Legal references: LACI art. 28-30
void main() {
  // ════════════════════════════════════════════════════════════
  //  ELIGIBILITY
  // ════════════════════════════════════════════════════════════

  group('UnemploymentService - Eligibilite', () {
    test('moins de 12 mois de cotisation => non eligible', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 11,
      );

      expect(result.eligible, isFalse);
      expect(result.raisonNonEligible, contains('12 mois'));
      expect(result.raisonNonEligible, contains('11 mois'));
      expect(result.tauxIndemnite, 0);
      expect(result.indemniteJournaliere, 0);
      expect(result.indemniteMensuelle, 0);
      expect(result.nombreIndemnites, 0);
      expect(result.dureeMois, 0);
    });

    test('exactement 12 mois de cotisation => eligible', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 12,
      );

      expect(result.eligible, isTrue);
      expect(result.raisonNonEligible, isNull);
      expect(result.nombreIndemnites, greaterThan(0));
    });

    test('zero mois de cotisation => non eligible', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 0,
      );

      expect(result.eligible, isFalse);
      expect(result.raisonNonEligible, contains('0 mois'));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  TAUX D'INDEMNITE (70% / 80%)
  // ════════════════════════════════════════════════════════════

  group('UnemploymentService - Taux indemnite', () {
    test('salaire eleve sans enfants ni handicap => taux 70%', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
        hasChildren: false,
        hasDisability: false,
      );

      expect(result.tauxIndemnite, 0.70);
    });

    test('avec enfants => taux majore 80%', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
        hasChildren: true,
        hasDisability: false,
      );

      expect(result.tauxIndemnite, 0.80);
    });

    test('avec handicap => taux majore 80%', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
        hasChildren: false,
        hasDisability: true,
      );

      expect(result.tauxIndemnite, 0.80);
    });

    test('salaire bas (< CHF 3797) => taux majore 80%', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 3500,
        age: 30,
        moisCotisation: 18,
        hasChildren: false,
        hasDisability: false,
      );

      expect(result.tauxIndemnite, 0.80);
    });

    test('salaire exactement au seuil (CHF 3797) sans enfants => taux 70%', () {
      // gainAssureMensuel >= 3797 && no children && no disability => 70%
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 3797,
        age: 30,
        moisCotisation: 18,
        hasChildren: false,
        hasDisability: false,
      );

      expect(result.tauxIndemnite, 0.70);
    });

    test('salaire juste en dessous du seuil => taux 80%', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 3796,
        age: 30,
        moisCotisation: 18,
        hasChildren: false,
        hasDisability: false,
      );

      expect(result.tauxIndemnite, 0.80);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  GAIN ASSURE ET INDEMNITES
  // ════════════════════════════════════════════════════════════

  group('UnemploymentService - Gain assure et indemnites', () {
    test('gain assure plafonne a CHF 12350', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 15000,
        age: 30,
        moisCotisation: 18,
      );

      expect(result.gainAssureRetenu, 12350.0);
    });

    test('gain assure sous le plafond => retenu tel quel', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
      );

      expect(result.gainAssureRetenu, 6000.0);
    });

    test('indemnite journaliere = gain retenu * taux / 21.75', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
        hasChildren: false,
        hasDisability: false,
      );

      // 6000 * 0.70 / 21.75
      final expected = 6000.0 * 0.70 / 21.75;
      expect(result.indemniteJournaliere, closeTo(expected, 0.01));
    });

    test('indemnite mensuelle = indemnite journaliere * 21.75', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
      );

      // indemniteMensuelle should be gainRetenu * taux (round-trip)
      final expectedMensuelle = result.indemniteJournaliere * 21.75;
      expect(result.indemniteMensuelle, closeTo(expectedMensuelle, 0.01));
    });

    test('perte mensuelle correcte', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
      );

      final expectedPerte = 6000 - result.indemniteMensuelle;
      expect(result.perteMensuelle, closeTo(expectedPerte, 0.01));
    });
  });

  // ════════════════════════════════════════════════════════════
  //  DUREE (NOMBRE D'INDEMNITES)
  // ════════════════════════════════════════════════════════════

  group('UnemploymentService - Duree', () {
    test('age >= 60, cotisation >= 22 mois => 520 indemnites', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 60,
        moisCotisation: 22,
      );

      expect(result.nombreIndemnites, 520);
    });

    test('age >= 55, cotisation >= 22 mois => 400 indemnites', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 55,
        moisCotisation: 22,
      );

      expect(result.nombreIndemnites, 400);
    });

    test('age >= 25, cotisation >= 18 mois => 260 indemnites', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 25,
        moisCotisation: 18,
      );

      expect(result.nombreIndemnites, 260);
    });

    test('age < 25, cotisation >= 12 mois => 200 indemnites', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 4000,
        age: 24,
        moisCotisation: 12,
      );

      expect(result.nombreIndemnites, 200);
    });

    test('duree en mois = nombreIndemnites / 21.75', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
      );

      expect(result.dureeMois, closeTo(260 / 21.75, 0.01));
    });

    test('age 55 avec seulement 18 mois cotisation => 260 (pas 400)', () {
      // 55+ needs >= 22 mois for 400, with only 18 falls to age>=25 bracket
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 55,
        moisCotisation: 18,
      );

      expect(result.nombreIndemnites, 260);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  DELAI DE CARENCE ET TIMELINE
  // ════════════════════════════════════════════════════════════

  group('UnemploymentService - Delai de carence et timeline', () {
    test('delai de carence = 5 jours', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
      );

      expect(result.delaiCarenceJours, 5);
    });

    test('timeline contient 8 etapes', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
      );

      expect(result.timeline.length, 8);
    });

    test('premiere etape timeline = inscription ORP a jour 0', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
      );

      expect(result.timeline.first.jour, 0);
      expect(result.timeline.first.action, 'Inscription ORP');
      expect(result.timeline.first.urgence, 'immediate');
    });

    test('timeline contient toutes les urgences', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
      );

      final urgences = result.timeline.map((e) => e.urgence).toSet();
      expect(urgences, containsAll(['immediate', 'semaine1', 'mois1', 'mois3']));
    });

    test('non eligible retourne quand meme une timeline', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 5,
      );

      expect(result.eligible, isFalse);
      expect(result.timeline.length, 8);
    });
  });

  // ════════════════════════════════════════════════════════════
  //  EDGE CASES
  // ════════════════════════════════════════════════════════════

  group('UnemploymentService - Edge cases', () {
    test('gain assure zero => non eligible (backend aligned)', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 0,
        age: 30,
        moisCotisation: 18,
      );

      // Backend validates gain_assure_mensuel > 0 (calculator.py:163)
      expect(result.eligible, isFalse);
      expect(result.indemniteJournaliere, 0);
      expect(result.indemniteMensuelle, 0);
    });

    test('salaire tres eleve plafonne correctement', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 50000,
        age: 30,
        moisCotisation: 18,
      );

      expect(result.gainAssureRetenu, 12350.0);
      // indemnite basee sur le plafond, pas le salaire reel
      final expectedDaily = 12350.0 * 0.70 / 21.75;
      expect(result.indemniteJournaliere, closeTo(expectedDaily, 0.01));
    });

    test('chiffre choc mentionne la perte mensuelle', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
      );

      expect(result.chiffreChoc, contains('mois'));
      expect(result.chiffreChoc, contains('salaire'));
    });

    test('formatChf formate avec apostrophe suisse', () {
      expect(UnemploymentService.formatChf(1234), 'CHF\u00A01\'234');
      expect(UnemploymentService.formatChf(0), 'CHF\u00A00');
      expect(UnemploymentService.formatChf(12350), 'CHF\u00A012\'350');
      expect(UnemploymentService.formatChf(1000000), 'CHF\u00A01\'000\'000');
    });
  });
}
