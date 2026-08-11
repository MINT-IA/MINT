import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_lpp_affiliation_fact.dart';

void main() {
  final asserted = DateTime.utc(2026, 8, 11, 14);

  MintNextLppAffiliationFact fact({
    bool affiliated = true,
    bool needsConfirmation = false,
  }) =>
      MintNextLppAffiliationFact(
        affiliated: affiliated,
        assertedAt: asserted,
        source: MintNextLppAffiliationFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: needsConfirmation,
      );

  test('round-trips through wizard answers for both values', () {
    for (final affiliated in [true, false]) {
      final original = fact(affiliated: affiliated);
      expect(
        MintNextLppAffiliationFact.fromWizardAnswers(
            original.toWizardAnswers()),
        original,
        reason: 'affiliated=$affiliated',
      );
    }
  });

  test('business reading is tri-state — absence NEVER reads as not affiliated',
      () {
    expect(MintNextLppAffiliationFact.statusOf(fact(affiliated: true)),
        MintNextLppAffiliationStatus.confirmedYes);
    expect(MintNextLppAffiliationFact.statusOf(fact(affiliated: false)),
        MintNextLppAffiliationStatus.confirmedNo);
    expect(MintNextLppAffiliationFact.statusOf(null),
        MintNextLppAffiliationStatus.unknown,
        reason: 'a missing fact is unknown, never confirmed_no');
    expect(
        MintNextLppAffiliationFact.statusOf(
            fact(affiliated: false, needsConfirmation: true)),
        MintNextLppAffiliationStatus.unknown,
        reason: 'a pending fact is unknown, never confirmed_no');
  });

  test('a stringly-typed or incomplete bundle yields no fact', () {
    expect(
      MintNextLppAffiliationFact.fromWizardAnswers(
          {'q_lpp_affiliation_fact_value': true}),
      isNull,
      reason: 'a bare value without metadata is not a confirmed fact',
    );
    final stringly = fact().toWizardAnswers()
      ..['q_lpp_affiliation_fact_value'] = 'true';
    expect(MintNextLppAffiliationFact.fromWizardAnswers(stringly), isNull,
        reason: 'the stored value is a strict bool — a string never sneaks '
            'in as an affiliation (corruption reads as no fact → unknown)');
  });

  test('deletion nulls the complete owned bundle and nothing else', () {
    final deletion = MintNextLppAffiliationFact.deletionWizardAnswers();
    expect(deletion.keys.toSet(), MintNextLppAffiliationFact.wizardKeys);
    expect(deletion.values.every((v) => v == null), isTrue,
        reason: 'no legacy projection exists for this fact — deletion '
            'returns the affiliation to unknown');
  });

  test('revision fingerprint is the UTC assertion instant', () {
    expect(fact().revision, '2026-08-11T14:00:00.000Z');
  });
}
