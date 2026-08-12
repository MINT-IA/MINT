import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/models/mint_next_revenu_fact.dart';

void main() {
  final asserted = DateTime.utc(2026, 8, 11, 12);

  MintNextRevenuFact fact({
    int amountCents = 650000,
    MintNextRevenuPeriod period = MintNextRevenuPeriod.monthly,
  }) =>
      MintNextRevenuFact(
        amountCents: amountCents,
        period: period,
        assertedAt: asserted,
        source: MintNextRevenuFact.userDeclarationSource,
        schemaVersion: 1,
        needsConfirmation: false,
      );

  test('round-trips through wizard answers for both periods', () {
    for (final period in MintNextRevenuPeriod.values) {
      final original = fact(period: period);
      expect(
        MintNextRevenuFact.fromWizardAnswers(original.toWizardAnswers()),
        original,
        reason: period.id,
      );
    }
  });

  test('period tokens are stable and accent-free', () {
    expect(MintNextRevenuPeriod.values.map((p) => p.id).toList(),
        ['monthly', 'yearly']);
  });

  test(
      'annualization applies the factor twelve exactly once and only for '
      'monthly', () {
    expect(fact(period: MintNextRevenuPeriod.monthly).annualizedCents,
        650000 * 12);
    expect(fact(period: MintNextRevenuPeriod.yearly).annualizedCents, 650000,
        reason: 'a yearly amount is never multiplied — the stored amount is '
            'always the declared per-period amount (anti double factor 12)');
    final monthly = fact(period: MintNextRevenuPeriod.monthly);
    final roundTrip = MintNextRevenuFact.fromWizardAnswers(
        monthly.toWizardAnswers())!;
    expect(roundTrip.amountCents, 650000,
        reason: 'persisting never bakes the annualization into the amount');
  });

  test('legacy projection carries CHF per period and normalized frequency',
      () {
    final projection = fact().legacyProjectionAnswers();
    expect(projection['q_net_income_period_chf'], 6500.0);
    expect(projection['q_pay_frequency'], 'monthly');
    final yearly =
        fact(period: MintNextRevenuPeriod.yearly).legacyProjectionAnswers();
    expect(yearly['q_pay_frequency'], 'yearly');
  });

  test('deletion nulls the owned bundle AND the legacy projection', () {
    final deletion = MintNextRevenuFact.deletionWizardAnswers();
    expect(deletion.keys.toSet(), {
      ...MintNextRevenuFact.wizardKeys,
      'q_net_income_period_chf',
      'q_pay_frequency',
    });
    expect(deletion.values.every((v) => v == null), isTrue,
        reason: 'the tombstone dominates the projection — legacy consumers '
            'must not keep showing a deleted income');
  });

  test('incomplete or invalid metadata yields no fact', () {
    expect(
      MintNextRevenuFact.fromWizardAnswers(
          {'q_revenu_fact_amount_cents': 650000}),
      isNull,
      reason: 'a bare amount without metadata is not a confirmed fact',
    );
    final zeroAmount = fact().toWizardAnswers()
      ..['q_revenu_fact_amount_cents'] = 0;
    expect(MintNextRevenuFact.fromWizardAnswers(zeroAmount), isNull);
    final unknownPeriod = fact().toWizardAnswers()
      ..['q_revenu_fact_period'] = 'weekly';
    expect(MintNextRevenuFact.fromWizardAnswers(unknownPeriod), isNull,
        reason: 'legacy heterogeneous frequencies never enter the fact — '
            'normalization happens at the projection boundary only');
  });

  test('revision fingerprint is the UTC assertion instant', () {
    expect(fact().revision, '2026-08-11T12:00:00.000Z');
  });
}
