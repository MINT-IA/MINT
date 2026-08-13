// Les intérêts hypothécaires atteignent enfin un calcul.
//
// Le fait logement était enregistré, rechargé, visible dans « Ma situation »,
// et consommé NULLE PART ailleurs. Les intérêts hypothécaires — la déduction
// fiscale la plus courante en Suisse — n'entraient dans aucun calcul. La
// donnée n'était pas perdue : elle était inerte.
//
// Ces oracles vérifient qu'elle ne l'est plus, et surtout qu'elle n'entre pas
// n'importe comment : une charge appartient à une ANNÉE, et celle d'une autre
// année ne se reporte pas.

import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_3a_tax_boundary.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';

void main() {
  MintNextHousingFact owner({
    int? interestCents = 425000,
    int? year = 2025,
    int? debtCents = 61200000,
    bool needsConfirmation = false,
  }) =>
      MintNextHousingFact(
        tenure: PrimaryHomeTenure.ownerOccupier,
        mortgageStatus: HousingMortgageStatus.yes,
        statementAvailability: MortgageStatementAvailability.ready,
        statementYear: year,
        annualInterestCents: interestCents,
        debtBalanceCents: debtCents,
        assertedAt: DateTime.utc(2026, 8, 13),
        source: 'user_declaration',
        schemaVersion: 1,
        needsConfirmation: needsConfirmation,
      );

  test('a confirmed mortgage statement finally reaches the fiscal boundary',
      () {
    final context = MintNext3aHousingContext.fromConfirmedFact(owner());

    expect(context, isNotNull,
        reason: 'la déduction la plus courante en Suisse doit être atteignable');
    expect(context!.annualInterestCents, 425000);
    expect(context.statementYear, 2025);
    expect(context.debtBalanceCents, 61200000);
  });

  test('interest for one year does not answer for another', () {
    final context = MintNext3aHousingContext.fromConfirmedFact(owner())!;

    expect(context.coversTaxYear(2025), isTrue);
    expect(context.coversTaxYear(2026), isFalse,
        reason: "la charge d'une année ne se reporte pas sur une autre");
  });

  test('a statement without its year cannot feed anything', () {
    // Une charge qui ne dit pas de quel exercice elle parle ne peut nourrir
    // aucun calcul.
    expect(MintNext3aHousingContext.fromConfirmedFact(owner(year: null)),
        isNull);
  });

  test('a mortgage with no interest amount is not a charge', () {
    expect(
        MintNext3aHousingContext.fromConfirmedFact(owner(interestCents: null)),
        isNull);
  });

  test('a fact awaiting confirmation is not a known charge', () {
    expect(
        MintNext3aHousingContext.fromConfirmedFact(
            owner(needsConfirmation: true)),
        isNull);
  });

  test('a missing debt balance is not zero', () {
    final context =
        MintNext3aHousingContext.fromConfirmedFact(owner(debtCents: null))!;

    expect(context.debtBalanceCents, isNull,
        reason: 'ne pas savoir combien on doit ne veut pas dire ne rien devoir');
    expect(context.annualInterestCents, 425000,
        reason: 'les intérêts restent utilisables sans le solde');
  });

  group('dans le contexte fiscal complet', () {
    MintNext3aFiscalContext contextFor(int taxYear) => MintNext3aFiscalContext(
          taxYear: taxYear,
          effectiveAt: DateTime.utc(2026, 8, 13),
          housing: MintNext3aHousingContext.fromConfirmedFact(owner()),
        );

    test('the charge is known for its own year', () {
      final context = contextFor(2025);

      expect(context.housingKnown, isTrue);
      expect(context.toJson()['housing_status'], 'known');
      expect(context.toJson()['housing'], isNotNull);
    });

    test('a statement from another year is named, not silently used', () {
      final context = contextFor(2026);

      expect(context.housingKnown, isFalse);
      expect(context.housingStatementFromAnotherYear, isTrue);
      expect(context.toJson()['housing_status'], 'statement_from_another_year',
          reason: "une attestation d'une autre année n'est pas une absence — "
              "l'une appelle une collecte, l'autre une mise à jour");
      expect(context.toJson().containsKey('housing'), isFalse,
          reason: 'et surtout, elle ne fournit AUCUN chiffre');
    });

    test('no fact at all reads as missing, which calls for collection', () {
      final context = MintNext3aFiscalContext(
        taxYear: 2025,
        effectiveAt: DateTime.utc(2026, 8, 13),
      );

      expect(context.housingKnown, isFalse);
      expect(context.housingStatementFromAnotherYear, isFalse);
      expect(context.toJson()['housing_status'], 'missing');
    });
  });
}
