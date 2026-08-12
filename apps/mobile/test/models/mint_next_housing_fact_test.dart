import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_housing_fact.dart';

void main() {
  test('housing fact round-trips exact cents and metadata', () {
    final fact = MintNextHousingFact(
      tenure: PrimaryHomeTenure.ownerOccupier,
      mortgageStatus: HousingMortgageStatus.yes,
      statementAvailability: MortgageStatementAvailability.ready,
      statementYear: 2025,
      annualInterestCents: 123456,
      debtBalanceCents: 987654321,
      assertedAt: DateTime.utc(2026, 8, 8, 12, 30),
      source: 'user_declared',
      schemaVersion: 1,
      needsConfirmation: false,
    );

    final answers = fact.toWizardAnswers();
    expect(answers[MintNextHousingFact.annualInterestCentsKey], 123456);
    expect(MintNextHousingFact.fromWizardAnswers(answers), fact);
  });

  test('owned deletion bundle contains every stable key as null', () {
    final deletion = MintNextHousingFact.deletionWizardAnswers();
    expect(deletion.keys.toSet(), MintNextHousingFact.wizardKeys);
    expect(deletion.values, everyElement(isNull));
  });

  test('rejects non-integral numeric values instead of truncating cents', () {
    final answers = MintNextHousingFact(
      tenure: PrimaryHomeTenure.ownerOccupier,
      annualInterestCents: 100,
      assertedAt: DateTime.utc(2026, 8, 8),
      source: 'user_declared',
      schemaVersion: 1,
      needsConfirmation: false,
    ).toWizardAnswers()
      ..[MintNextHousingFact.annualInterestCentsKey] = 100.5;

    expect(
      MintNextHousingFact.fromWizardAnswers(answers)!.annualInterestCents,
      isNull,
    );
  });
}
