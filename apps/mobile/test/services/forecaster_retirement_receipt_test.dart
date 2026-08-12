import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/money_truth_receipt.dart';
import 'package:mint_mobile/services/forecaster_service.dart';

/// V2-4 — contrat du producteur de receipt du revenu mensuel de retraite.
/// Le receipt ENVELOPPE le chiffre affiché (jamais de recalcul) : `value` ==
/// `monthlyIncome` passé, `inputsHash` déterministe (64 hex), provenance BRUT.
void main() {
  MoneyTruthReceipt build({
    double monthlyIncome = 5200,
    double? rangeLow = 4800,
    double? rangeHigh = 5600,
    bool isCouple = false,
    String? receiptId,
    String? computedAt,
  }) =>
      ForecasterService.buildRetirementIncomeReceipt(
        monthlyIncome: monthlyIncome,
        rangeLow: rangeLow,
        rangeHigh: rangeHigh,
        avsMensuel: 2200,
        lppMensuel: 2500,
        troisAMensuel: 500,
        canton: 'vd',
        currentAge: 45,
        retirementAge: 65,
        isCouple: isCouple,
        civilStatus: 'Marie',
        confidenceScore: 72, // [0,100]
        receiptId: receiptId,
        computedAt: computedAt,
      );

  test('value == chiffre affiché (aucun recalcul), claim + base corrects', () {
    final r = build(monthlyIncome: 5234.56);
    expect(r.claimId, kRetirementMonthlyIncomeClaimId);
    expect(r.value, 5234.56);
    expect(r.base, 'brut');
    expect(r.jurisdiction, 'CH-VD');
    expect(r.civilStatus, 'marie');
    expect(r.engine, 'financial_core.forecaster_service');
  });

  test('inputsHash déterministe, 64 hex, sensible aux drivers', () {
    final a = build(receiptId: 'x', computedAt: 't');
    final b = build(receiptId: 'y', computedAt: 'u');
    // Mêmes inputs → même hash (indépendant de receiptId/computedAt).
    expect(a.inputsHash, b.inputsHash);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(a.inputsHash), isTrue);
    // Un driver différent (isCouple) → hash différent.
    final c = build(isCouple: true, receiptId: 'z', computedAt: 'v');
    expect(c.inputsHash, isNot(a.inputsHash));
  });

  test('receiptId / computedAt injectables ; sinon uuid + timestamp', () {
    final fixed = build(receiptId: 'rcpt-42', computedAt: '2026-01-01T00:00:00Z');
    expect(fixed.receiptId, 'rcpt-42');
    expect(fixed.computedAt, '2026-01-01T00:00:00Z');
    final auto = build();
    expect(auto.receiptId, isNotEmpty);
    expect(auto.receiptId, isNot('rcpt-42'));
  });

  test('bande triée et valeur dans [low, high] ; confiance normalisée [0,1]', () {
    // Bornes fournies inversées → le producteur les trie.
    final r = build(monthlyIncome: 5200, rangeLow: 5600, rangeHigh: 4800);
    expect(r.range, isNotNull);
    expect(r.range!.low, lessThanOrEqualTo(r.range!.high));
    expect(r.value, greaterThanOrEqualTo(r.range!.low));
    expect(r.value, lessThanOrEqualTo(r.range!.high));
    expect(r.confidence, isNotNull);
    // 72/100 → 0.72 (score = confiance projection affichée).
    expect(r.confidence!.score, closeTo(0.72, 1e-9));
    expect(r.confidence!.completeness, closeTo(0.72, 1e-9));
  });

  test('bande omise (range null) si bornes absentes ou non finies (P2/P1)', () {
    // Couple : l'écran passe null (la bande affichée est mono-personne).
    expect(build(rangeLow: null, rangeHigh: null).range, isNull);
    // Une borne non finie -> pas de bande scellée (jamais « inf CHF »).
    expect(build(rangeLow: double.infinity).range, isNull);
    expect(build(rangeHigh: double.nan).range, isNull);
  });

  test('mention conjoint uniquement en couple', () {
    expect(
      build(isCouple: true)
          .assumptions
          .any((a) => a.toLowerCase().contains('conjoint')),
      isTrue,
    );
    expect(
      build(isCouple: false)
          .assumptions
          .any((a) => a.toLowerCase().contains('conjoint')),
      isFalse,
    );
  });

  test('aucun terme de classement (extra=forbid backend) dans le receipt', () {
    final json = build().toJson().toString().toLowerCase();
    for (final banned in ['recommended', 'best', 'optimal', 'meilleur']) {
      expect(json.contains(banned), isFalse, reason: 'terme banni: $banned');
    }
  });
}
