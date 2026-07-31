import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/money_truth_receipt.dart';

/// V2-4 — contrat du producteur de receipt de la rente mensuelle nette de
/// rente_vs_capital. `value` == `renteNetMensuelle` affichée, base NET, claimId
/// dédié (distinct du revenu total de retraite), engine reflétant la source.
void main() {
  MoneyTruthReceipt build({
    double renteNetMensuelle = 3120,
    bool isMarried = false,
    bool fromBackend = true,
    String inputMode = 'certificate',
    String? receiptId,
    String? computedAt,
  }) =>
      ArbitrageEngine.buildRenteMensuelleReceipt(
        renteNetMensuelle: renteNetMensuelle,
        capitalLppTotal: 500000,
        capitalObligatoire: 350000,
        capitalSurobligatoire: 150000,
        renteAnnuelleProposee: 34000,
        tauxConversionObligatoire: 0.068,
        tauxConversionSurobligatoire: 0.05,
        canton: 'ge',
        ageRetraite: 65,
        isMarried: isMarried,
        inputMode: inputMode,
        fromBackend: fromBackend,
        confidenceScore: 80,
        receiptId: receiptId,
        computedAt: computedAt,
      );

  test('value == rente affichée, claim dédié, base NET', () {
    final r = build(renteNetMensuelle: 3128.99);
    expect(r.claimId, kRenteVsCapitalRenteClaimId);
    expect(r.claimId, isNot(kRetirementMonthlyIncomeClaimId));
    expect(r.value, 3128.99);
    expect(r.base, 'net');
    expect(r.jurisdiction, 'CH-GE');
  });

  test('engine reflète la source réelle (backend vs repli local)', () {
    expect(build(fromBackend: true).engine, 'backend.rente_vs_capital');
    expect(build(fromBackend: false).engine, 'financial_core.arbitrage_engine');
  });

  test('inputsHash déterministe 64 hex ; sensible aux entrées', () {
    final a = build(receiptId: 'a', computedAt: 't');
    final b = build(receiptId: 'b', computedAt: 'u');
    expect(a.inputsHash, b.inputsHash);
    expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(a.inputsHash), isTrue);
    // Le mode de saisie fait partie des inputs → hash différent.
    final c = build(inputMode: 'estimate', receiptId: 'c');
    expect(c.inputsHash, isNot(a.inputsHash));
  });

  test('civilStatus dérivé de isMarried ; range null (rente déterministe)', () {
    expect(build(isMarried: true).civilStatus, 'marie');
    expect(build(isMarried: false).civilStatus, 'celibataire');
    expect(build().range, isNull);
  });

  test('receiptId / computedAt injectables', () {
    final r = build(receiptId: 'rcpt-9', computedAt: '2026-02-02T00:00:00Z');
    expect(r.receiptId, 'rcpt-9');
    expect(r.computedAt, '2026-02-02T00:00:00Z');
  });

  test('confiance normalisée [0,1] depuis un score [0,100]', () {
    expect(build().confidence, isNotNull);
    expect(build().confidence!.score, closeTo(0.80, 1e-9));
  });
}
