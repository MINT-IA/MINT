import 'package:flutter_test/flutter_test.dart';
import 'package:mint_mobile/services/financial_core/wealth_financial_facts.dart';

void main() {
  group('WealthFinancialFacts', () {
    test('computes property net value after mortgage balance', () {
      expect(
        WealthFinancialFacts.propertyNetValue(
          propertyValue: 900000,
          mortgageBalance: 540000,
        ),
        360000,
      );
    });

    test('computes net wealth after debts', () {
      expect(
        WealthFinancialFacts.netWealth(totalAssets: 420000, totalDebts: 80000),
        340000,
      );
    });

    test('computes consumer debt from credit and leasing', () {
      expect(
        WealthFinancialFacts.consumerDebt(
          consumerCredit: 12000,
          leasing: 8000,
        ),
        20000,
      );
    });

    group('reconcileAggregate', () {
      test('returns noData when neither detailed assets nor estimate exist',
          () {
        final result = WealthFinancialFacts.reconcileAggregate(
          cash: 0,
          investments: 0,
          propertyValue: 0,
        );

        expect(result.status, WealthReconciliationStatus.noData);
        expect(result.resolvedTotal, 0);
        expect(result.needsReconciliation, isFalse);
      });

      test('uses detailed assets when no broad estimate exists', () {
        final result = WealthFinancialFacts.reconcileAggregate(
          cash: 120000,
          investments: 80000,
          propertyValue: 500000,
        );

        expect(result.status, WealthReconciliationStatus.detailedOnly);
        expect(result.detailedAssetTotal, 700000);
        expect(result.resolvedTotal, 700000);
        expect(result.usesBroadEstimate, isFalse);
      });

      test('uses broad estimate without adding detailed assets twice', () {
        final result = WealthFinancialFacts.reconcileAggregate(
          cash: 120000,
          investments: 80000,
          propertyValue: 0,
          wealthEstimate: 1000000,
        );

        expect(
          result.status,
          WealthReconciliationStatus.estimateExceedsKnownDetails,
        );
        expect(result.detailedAssetTotal, 200000);
        expect(result.resolvedTotal, 1000000);
        expect(result.missingDetailSignal, isTrue);
        expect(result.needsReconciliation, isTrue);
      });

      test('flags stale estimates when known details are materially higher',
          () {
        final result = WealthFinancialFacts.reconcileAggregate(
          cash: 250000,
          investments: 150000,
          propertyValue: 700000,
          wealthEstimate: 500000,
        );

        expect(
          result.status,
          WealthReconciliationStatus.detailsExceedEstimate,
        );
        expect(result.detailedAssetTotal, 1100000);
        expect(result.resolvedTotal, 1100000);
        expect(result.contradictsKnownDetails, isTrue);
        expect(result.needsReconciliation, isTrue);
      });

      test('treats close broad estimates as aligned', () {
        final result = WealthFinancialFacts.reconcileAggregate(
          cash: 250000,
          investments: 150000,
          propertyValue: 500000,
          wealthEstimate: 950000,
        );

        expect(result.status, WealthReconciliationStatus.aligned);
        expect(result.resolvedTotal, 950000);
        expect(result.needsReconciliation, isFalse);
      });
    });
  });
}
