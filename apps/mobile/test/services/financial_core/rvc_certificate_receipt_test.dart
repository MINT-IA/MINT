import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';

/// beads MINT_nosync-8wy — audit RvC mode Certificat.
///
/// Bug prouvé sur dev : le receipt exigeait `current_age` inconditionnellement
/// (mobile `_requiredRvcAssumptionKeys` + engine `missingRequiredInputs` +
/// backend `_rvc_calculation_receipt`), alors que le mode certificat calcule
/// sur les valeurs RÉELLES du certificat LPP sans aucune projection — et que
/// le calcul backend ne consomme jamais current_age. Conséquence :
/// `missingRequiredInputs=['current_age']` -> `isComplete=false` -> le bloc
/// résultat de l'écran ne se rendait JAMAIS en mode certificat.
void main() {
  ArbitrageResult certificat() => ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 650000,
        capitalObligatoire: 500000,
        capitalSurobligatoire: 150000,
        renteAnnuelleProposee: 37000,
        canton: 'GE',
        ageRetraite: 65,
        // Mode certificat : pas d'âge courant, pas de salaire — valeurs
        // réelles, aucune projection.
      );

  group('receipt RvC — mode certificat (sans current_age)', () {
    test('certificat -> receipt complet, readiness ready, rien de manquant',
        () {
      final r = certificat();
      final receipt = r.calculationReceipt;
      expect(receipt, isNotNull);
      expect(receipt!.missingRequiredInputs, isEmpty,
          reason: "le mode certificat n'a pas besoin de current_age : "
              'aucune projection ne le consomme');
      expect(receipt.readiness, 'ready');
      expect(receipt.isComplete, isTrue,
          reason: 'receipt incomplet = bloc résultat bloqué à l\'écran '
              '(fail-closed) — le certificat ne rendait jamais rien');
      expect(r.isProjected, isFalse);
    });

    test('projection demandée (salaire) SANS âge -> current_age reste requis',
        () {
      final r = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 650000,
        capitalObligatoire: 500000,
        capitalSurobligatoire: 150000,
        renteAnnuelleProposee: 37000,
        canton: 'GE',
        ageRetraite: 65,
        grossAnnualSalary: 96000, // intention estimation…
        // …mais pas de currentAge : la projection est impossible.
      );
      final receipt = r.calculationReceipt!;
      expect(receipt.missingRequiredInputs, contains('current_age'),
          reason: "l'assouplissement certificat ne doit PAS désarmer le "
              'garde-fou du mode estimation');
      expect(receipt.isComplete, isFalse);
    });

    test('mode estimation complet (âge + salaire) -> inchangé, complet', () {
      final r = ArbitrageEngine.compareRenteVsCapital(
        capitalLppTotal: 650000,
        capitalObligatoire: 500000,
        capitalSurobligatoire: 150000,
        renteAnnuelleProposee: 37000,
        canton: 'GE',
        ageRetraite: 65,
        currentAge: 45,
        grossAnnualSalary: 96000,
      );
      expect(r.calculationReceipt!.isComplete, isTrue);
      expect(r.isProjected, isTrue);
    });

    test('current_age présent mais aberrant -> fail-closed conservé', () {
      final base = certificat().calculationReceipt!;
      final tampered = ArbitrageCalculationReceipt(
        calculationOrigin: base.calculationOrigin,
        calculationVersion: base.calculationVersion,
        constantsVersionHash: base.constantsVersionHash,
        unit: base.unit,
        assumptions: {...base.assumptions, 'current_age': -5},
        sources: base.sources,
        readiness: base.readiness,
        confidenceScore: base.confidenceScore,
        missingRequiredInputs: base.missingRequiredInputs,
      );
      expect(tampered.isComplete, isFalse,
          reason: 'optionnel ne veut pas dire non-validé : un âge fourni '
              'doit rester dans le domaine plausible');
    });
  });
}
