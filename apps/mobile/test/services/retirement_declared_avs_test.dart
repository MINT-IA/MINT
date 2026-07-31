import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/coach/coach_profile_seeds.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/services/regulatory_sync_service.dart';
import 'package:mint_mobile/services/retirement_projection_service.dart';

/// Unité moteur retraite — la rente AVS DÉCLARÉE (provenance profil, champ
/// nullable renseigné ≠ défaut) doit être HONORÉE par les deux moteurs de
/// projection au lieu d'être recalculée depuis un salaire nul
/// (`renteFromRAMD(0) = 0`).
///
/// Persona réel : seed `retraite_lausanne` (retraité VD 68 ans, salaire 0,
/// `_coach_avs_rente_estimee` = 2'000, avoir LPP 318'000). Hydraté par le
/// chemin de production `CoachProfile.fromWizardAnswers(seed.toWizardAnswers())`.
///
/// La rente déclarée est substituée au NIVEAU BRUT (rente mensuelle ordinaire
/// échelle 44) : elle traverse la 13e rente (`annualRente`, LAVS art. 34) et le
/// plafond couple (LAVS art. 35) comme le chemin recalculé → mensuel effectif =
/// déclaré × 13/12 (homogénéité d'unité, revue actuaire Codex P1).
///
/// Contrat :
///   - Retraité rente déclarée   → ventilation AVS = 2'000 × 13/12, taux non-nul.
///   - Couple marié              → part déclarée plafonnée (LAVS art. 35).
///   - Actif salaire>0 sans rente → recalcul AvsCalculator inchangé.
///   - Retraité sans rente        → AVS = 0 (comportement honnête documenté).
void main() {
  setUp(RegulatorySyncService.clearCache);
  tearDown(RegulatorySyncService.clearCache);

  // Mensuel effectif d'une rente mensuelle ordinaire, 13e rente incluse.
  double effective(double ordinaryMonthly) =>
      ordinaryMonthly * avsNombreRentesParAn / 12;

  CoachProfile retireeWithDeclaredAvs() => CoachProfile.fromWizardAnswers(
        CoachProfileSeeds.registry['retraite_lausanne']!.toWizardAnswers(),
      );

  /// Même persona, mais SANS rente AVS déclarée (clé wizard retirée).
  CoachProfile retireeWithoutDeclaredAvs() {
    final answers = Map<String, dynamic>.from(
      CoachProfileSeeds.registry['retraite_lausanne']!.toWizardAnswers(),
    )..remove('_coach_avs_rente_estimee');
    return CoachProfile.fromWizardAnswers(answers);
  }

  CoachProfile activeSalaried() => CoachProfile.fromWizardAnswers(
        CoachProfileSeeds.registry['julien_swiss']!.toWizardAnswers(),
      );

  group('RetirementProjectionService — rente AVS déclarée honorée', () {
    test('retraité : ventilation AVS = rente déclarée (2 000 × 13/12), pas ≈ 0',
        () {
      final p = retireeWithDeclaredAvs();
      expect(p.prevoyance.renteAVSEstimeeMensuelle, 2000);
      expect(p.revenuBrutAnnuel, 0, reason: 'salaire nul, prémisse du défaut');

      final r = RetirementProjectionService.project(profile: p);

      expect(r.budgetGap.avsMensuel, closeTo(effective(2000), 1),
          reason: 'rente déclarée honorée (brut échelle 44) + 13e rente');
      expect(r.budgetGap.avsMensuel, greaterThan(1000),
          reason: 'ne doit plus être ≈ 0 (défaut recalcul salaire-0)');
      final avsSource = r.phases
          .expand((ph) => ph.sources)
          .firstWhere((s) => s.id.startsWith('avs'));
      expect(avsSource.monthlyAmount, closeTo(effective(2000), 1));
    });

    test('retraité : taux de remplacement non-nul (continuité de revenu)', () {
      final p = retireeWithDeclaredAvs();
      final r = RetirementProjectionService.project(profile: p);
      expect(r.tauxRemplacement, greaterThan(0));
      expect(r.budgetGap.tauxRemplacement, greaterThan(0));
    });

    test('retraité SANS rente déclarée : AVS = 0 (comportement honnête)', () {
      final p = retireeWithoutDeclaredAvs();
      expect(p.prevoyance.renteAVSEstimeeMensuelle, isNull);

      final r = RetirementProjectionService.project(profile: p);
      expect(r.budgetGap.avsMensuel, 0,
          reason: 'aucune rente déclarée + salaire 0 → AVS recalculée = 0');
    });

    test('actif salarié : AVS recalculée depuis le salaire (inchangée)', () {
      final p = activeSalaried();
      expect(p.prevoyance.renteAVSEstimeeMensuelle, isNull);
      expect(p.revenuBrutAnnuel, greaterThan(0));

      final r = RetirementProjectionService.project(profile: p);
      expect(r.budgetGap.avsMensuel, greaterThan(0));
      // La rente d'un actif à plein salaire dépasse largement 2 000/mois.
      expect(r.budgetGap.avsMensuel, greaterThan(2000));
      expect(r.tauxRemplacement, greaterThan(0));
    });

    test('couple marié : la rente déclarée traverse le plafond LAVS art. 35',
        () {
      // Rente user déclarée élevée + conjoint à plein salaire → sans plafond, la
      // somme dépasserait le max couple. Le plafond doit s'appliquer à la part
      // déclarée (Codex P1). Persona construit directement (les seeds retraités
      // sont célibataires).
      const conjoint = ConjointProfile(
        firstName: 'Partenaire',
        birthYear: 1958,
        salaireBrutMensuel: 12000, // rente conjoint proche du max
      );
      final married = CoachProfile(
        firstName: 'Roland',
        birthYear: 1958,
        canton: 'VD',
        salaireBrutMensuel: 0,
        employmentStatus: 'retraite',
        etatCivil: CoachCivilStatus.marie,
        conjoint: conjoint,
        prevoyance: const PrevoyanceProfile(
          renteAVSEstimeeMensuelle: 3000, // déclaré très haut (brut échelle 44)
          avoirLppTotal: 100000,
        ),
        goalA: GoalA(
          type: GoalAType.retraite,
          targetDate: DateTime(2023, 12, 31),
          label: 'Retraite',
        ),
      );

      final r = RetirementProjectionService.project(profile: married);
      // Somme AVS (user + conjoint) plafonnée : ≤ couple max × 13/12.
      final capEffective = effective(avsRenteCoupleMaxMensuelle);
      expect(r.budgetGap.avsMensuel, lessThanOrEqualTo(capEffective + 1),
          reason: 'plafond couple LAVS art. 35 appliqué à la part déclarée');
      // Sans plafond, ce serait ≈ (3000 + rente conjoint) × 13/12 ≫ cap.
      expect(r.budgetGap.avsMensuel, greaterThan(effective(3000)),
          reason: 'la part déclarée + conjoint contribuent bien');
    });
  });

  group('ForecasterService — rente AVS déclarée honorée', () {
    test('retraité : scénario non-vide + AVS annuelle = 2 000 × 13', () {
      final p = retireeWithDeclaredAvs();
      final fc = ForecasterService.project(profile: p);

      expect(fc.base.revenuAnnuelRetraite, greaterThan(0),
          reason: 'un retraité déjà en régime doit avoir un revenu projeté');
      // Rente déclarée honorée au niveau brut → 13e rente incluse (× 13).
      expect(fc.base.decomposition['avs_user'],
          closeTo(2000 * avsNombreRentesParAn, 6));
      expect(fc.tauxRemplacementBase, greaterThan(0));
    });

    test('retraité SANS rente déclarée : AVS annuelle = 0', () {
      final p = retireeWithoutDeclaredAvs();
      final fc = ForecasterService.project(profile: p);
      expect(fc.base.decomposition['avs_user'] ?? 0, 0);
    });

    test('actif salarié : projection normale, AVS recalculée > 0', () {
      final p = activeSalaried();
      final fc = ForecasterService.project(profile: p);
      expect(fc.base.points, isNotEmpty);
      expect((fc.base.decomposition['avs_user'] ?? 0), greaterThan(0));
    });
  });
}
