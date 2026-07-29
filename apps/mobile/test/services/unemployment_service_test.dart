import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';
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
  setUp(RegulatorySyncService.clearCache);
  tearDown(RegulatorySyncService.clearCache);

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

    test('salaire exactement au seuil (CHF 3797) sans enfants => taux 80%', () {
      // Review #986 : borne INCLUSIVE — le SECO donne 80% lorsque le gain
      // assuré NE DÉPASSE PAS 3'797 CHF (OACI art. 33). L'ancien test
      // pinnait 70% au seuil exact.
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 3797,
        age: 30,
        moisCotisation: 18,
        hasChildren: false,
        hasDisability: false,
      );

      expect(result.tauxIndemnite, 0.80);
    });

    test('salaire juste au-dessus du seuil (CHF 3798) => taux 70%', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 3798,
        age: 30,
        moisCotisation: 18,
      );

      expect(result.tauxIndemnite, 0.70);
    });

    test('invalidité >= 40% : 22 mois ouvrent les 520 jours sans les 55 ans',
        () {
      // Review #986 : let. c = 22 mois ET (55 ans OU invalidité >= 40%).
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 45,
        moisCotisation: 22,
        hasDisability: true,
      );

      expect(result.nombreIndemnites, 520);
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
      const expected = 6000.0 * 0.70 / 21.75;
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

    test('age >= 55, cotisation >= 22 mois => 520 indemnites (SECO senior)',
        () {
      // SECO rules: 55+ = senior = 520 days (LACI art. 27 al. 2)
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 55,
        moisCotisation: 22,
      );

      expect(result.nombreIndemnites, 520);
    });

    test('18 mois de cotisation => 400 indemnites (LACI art. 27 al. 2 let. b)',
        () {
      // Beads -4za : l'ancien barème servait 260 pour 18 mois — le mapping
      // mois->jours était décalé d'un palier (sous-estimation du droit).
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 25,
        moisCotisation: 18,
      );

      expect(result.nombreIndemnites, 400);
    });

    test('12 mois de cotisation => 260 indemnites (let. a)', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 12,
      );

      expect(result.nombreIndemnites, 260);
    });

    test('< 25 ans SANS enfant : plafond jeunes 200 (12 mois cotisés)', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 4000,
        age: 24,
        moisCotisation: 12,
      );

      expect(result.nombreIndemnites, 200,
          reason: 'plafond < 25 ans sans obligation d\'entretien');
    });

    test('< 25 ans AVEC enfant : pas de plafond jeunes (barème plein)', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 4000,
        age: 24,
        moisCotisation: 18,
        hasChildren: true,
      );

      expect(result.nombreIndemnites, 400,
          reason: 'l\'obligation d\'entretien lève le plafond jeunes');
    });

    test('55 ans mais seulement 18 mois cotisés => 400, pas 520', () {
      // let. c exige 22 mois ET l'âge — l'âge seul ne suffit pas.
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 57,
        moisCotisation: 18,
      );

      expect(result.nombreIndemnites, 400);
    });

    test('moins de 12 mois de cotisation => 0 (pas de droit modélisé)', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 8,
      );

      expect(result.nombreIndemnites, 0);
    });

    test('duree en mois = nombreIndemnites / 21.75', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
      );

      // 18 mois -> 400 jours (barème corrigé -4za).
      expect(result.dureeMois, closeTo(400 / 21.75, 0.01));
    });

    test('cache registry pilote plafond mensuel, seuil majore et durees', () {
      // Clés renommées beads -4za : le barème mois->jours officiel porte
      // days_12_months / days_18_months / days_22_months_senior /
      // days_under25_cap (les anciennes clés min/intermediate/senior_days
      // suivaient la sémantique fausse).
      RegulatorySyncService.setMockCache({
        'ac.max_insured_salary': 60000.0,
        'ac.enhanced_rate_threshold': 10000.0,
        'ac.senior_age_threshold': 60.0,
        'ac.days_22_months_senior': 600.0,
        'ac.days_18_months': 333.0,
        'ac.days_12_months': 250.0,
        'ac.days_under25_cap': 222.0,
      });

      final eighteen = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 9000,
        age: 30,
        moisCotisation: 18,
      );

      expect(eighteen.gainAssureRetenu, 5000.0);
      expect(eighteen.tauxIndemnite, 0.80);
      expect(eighteen.indemniteMensuelle, closeTo(4000.0, 0.01));
      expect(eighteen.nombreIndemnites, 333);

      final senior = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 9000,
        age: 60,
        moisCotisation: 22,
      );
      expect(senior.nombreIndemnites, 600);

      final youngCapped = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 9000,
        age: 24,
        moisCotisation: 12,
      );
      expect(youngCapped.nombreIndemnites, 222,
          reason: 'plafond jeunes piloté par le cache (min(250, 222))');
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
      expect(
          urgences, containsAll(['immediate', 'semaine1', 'mois1', 'mois3']));
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
      const expectedDaily = 12350.0 * 0.70 / 21.75;
      expect(result.indemniteJournaliere, closeTo(expectedDaily, 0.01));
    });

    test('premier éclairage mentionne la perte mensuelle', () {
      final result = UnemploymentService.calculateBenefits(
        gainAssureMensuel: 6000,
        age: 30,
        moisCotisation: 18,
      );

      expect(result.premierEclairage, contains('mois'));
      expect(result.premierEclairage, contains('salaire'));
    });

    test('formatChf formate avec apostrophe suisse', () {
      expect(UnemploymentService.formatChf(1234), 'CHF\u00A01\'234');
      expect(UnemploymentService.formatChf(0), 'CHF\u00A00');
      expect(UnemploymentService.formatChf(12350), 'CHF\u00A012\'350');
      expect(UnemploymentService.formatChf(1000000), 'CHF\u00A01\'000\'000');
    });
  });
}
