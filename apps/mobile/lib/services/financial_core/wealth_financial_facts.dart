import 'dart:math' as math;

enum WealthReconciliationStatus {
  noData,
  estimateOnly,
  detailedOnly,
  aligned,
  estimateExceedsKnownDetails,
  detailsExceedEstimate,
}

class WealthReconciliation {
  const WealthReconciliation({
    required this.status,
    required this.detailedAssetTotal,
    required this.wealthEstimate,
    required this.resolvedTotal,
    required this.absoluteGap,
    required this.materialityThreshold,
  });

  final WealthReconciliationStatus status;
  final double detailedAssetTotal;
  final double? wealthEstimate;
  final double resolvedTotal;
  final double absoluteGap;
  final double materialityThreshold;

  bool get hasDetailedAssets => detailedAssetTotal > 0;
  bool get hasEstimate => wealthEstimate != null && wealthEstimate! > 0;

  bool get usesBroadEstimate =>
      hasEstimate &&
      wealthEstimate == resolvedTotal &&
      resolvedTotal > detailedAssetTotal;

  bool get missingDetailSignal =>
      status == WealthReconciliationStatus.estimateExceedsKnownDetails;

  bool get contradictsKnownDetails =>
      status == WealthReconciliationStatus.detailsExceedEstimate;

  bool get needsReconciliation =>
      missingDetailSignal || contradictsKnownDetails;
}

class WealthFinancialFacts {
  const WealthFinancialFacts._();

  static WealthReconciliation reconcileAggregate({
    required double cash,
    required double investments,
    required double propertyValue,
    double? wealthEstimate,
    double toleranceRatio = 0.10,
    double minimumMaterialGap = 10000,
  }) {
    final detailedAssetTotal =
        _positive(cash) + _positive(investments) + _positive(propertyValue);
    final estimate = _positiveOrNull(wealthEstimate);
    final estimateValue = estimate ?? 0;
    final resolvedTotal = math.max(detailedAssetTotal, estimateValue);

    if (detailedAssetTotal == 0 && estimate == null) {
      return const WealthReconciliation(
        status: WealthReconciliationStatus.noData,
        detailedAssetTotal: 0,
        wealthEstimate: null,
        resolvedTotal: 0,
        absoluteGap: 0,
        materialityThreshold: 0,
      );
    }

    if (estimate == null) {
      return WealthReconciliation(
        status: WealthReconciliationStatus.detailedOnly,
        detailedAssetTotal: detailedAssetTotal,
        wealthEstimate: null,
        resolvedTotal: detailedAssetTotal,
        absoluteGap: 0,
        materialityThreshold: 0,
      );
    }

    if (detailedAssetTotal == 0) {
      return WealthReconciliation(
        status: WealthReconciliationStatus.estimateOnly,
        detailedAssetTotal: 0,
        wealthEstimate: estimate,
        resolvedTotal: estimate,
        absoluteGap: 0,
        materialityThreshold: 0,
      );
    }

    final gap = (estimate - detailedAssetTotal).abs();
    final threshold = math.max(
      _positive(minimumMaterialGap),
      resolvedTotal * _positive(toleranceRatio),
    );
    final status = gap <= threshold
        ? WealthReconciliationStatus.aligned
        : estimate > detailedAssetTotal
            ? WealthReconciliationStatus.estimateExceedsKnownDetails
            : WealthReconciliationStatus.detailsExceedEstimate;

    return WealthReconciliation(
      status: status,
      detailedAssetTotal: detailedAssetTotal,
      wealthEstimate: estimate,
      resolvedTotal: resolvedTotal,
      absoluteGap: gap,
      materialityThreshold: threshold,
    );
  }

  static double propertyNetValue({
    required double propertyValue,
    required double mortgageBalance,
  }) {
    return propertyValue - mortgageBalance;
  }

  static double netWealth({
    required double totalAssets,
    required double totalDebts,
  }) {
    return totalAssets - totalDebts;
  }

  static double consumerDebt({
    required double consumerCredit,
    required double leasing,
  }) {
    return consumerCredit + leasing;
  }

  static double _positive(double value) => value > 0 ? value : 0;

  static double? _positiveOrNull(double? value) {
    if (value == null || value <= 0) {
      return null;
    }
    return value;
  }
}
