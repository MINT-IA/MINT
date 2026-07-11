import 'dart:math';

class SuccessionReserveResult {
  final double reserveHereditaireTotale;
  final double quotiteDisponible;
  final bool hasReservedSpouse;
  final bool hasChildren;

  const SuccessionReserveResult({
    required this.reserveHereditaireTotale,
    required this.quotiteDisponible,
    required this.hasReservedSpouse,
    required this.hasChildren,
  });
}

/// Swiss compulsory-portion calculator for educational succession scenarios.
///
/// Legal basis checked 2026-07-11:
/// - Swiss Civil Code (CC) art. 457-471.
/// - Revised Swiss inheritance law effective 2023-01-01.
class SuccessionReserveCalculator {
  const SuccessionReserveCalculator._();

  static const Map<String, double> compulsoryPortionFractions = {
    'descendant': 0.50,
    'conjoint': 0.50,
    'parent': 0.0,
  };

  static const double spouseLegalShareWithChildren = 0.50;
  static const double descendantsLegalShareWithSpouse = 0.50;
  static const double descendantsLegalShareWithoutSpouse = 1.0;
  static const double spouseLegalShareWithParentela = 0.75;
  static const double largeDonationShareThreshold = 0.50;

  static const Set<String> reservedSpouseStatuses = {
    'marie',
    'partenariat_enregistre',
    'registered_partner',
  };

  static SuccessionReserveResult estimate({
    required double estateReference,
    required String civilStatus,
    required int childrenCount,
  }) {
    final fortune = max(0.0, estateReference);
    final hasReservedSpouse = reservedSpouseStatuses.contains(civilStatus);
    final hasChildren = childrenCount > 0;

    final reserve = _reserveAmount(
      fortune: fortune,
      hasReservedSpouse: hasReservedSpouse,
      hasChildren: hasChildren,
    );

    return SuccessionReserveResult(
      reserveHereditaireTotale: reserve,
      quotiteDisponible: max(0.0, fortune - reserve),
      hasReservedSpouse: hasReservedSpouse,
      hasChildren: hasChildren,
    );
  }

  static bool isLargeDonation({
    required double donationAmount,
    required double estateReference,
  }) {
    return estateReference > 0 &&
        donationAmount > estateReference * largeDonationShareThreshold;
  }

  static double netRealEstateGiftValue({
    required double marketValue,
    required double mortgageBalance,
  }) {
    return max(0.0, marketValue - mortgageBalance);
  }

  static double _reserveAmount({
    required double fortune,
    required bool hasReservedSpouse,
    required bool hasChildren,
  }) {
    if (hasChildren && hasReservedSpouse) {
      final spouseReserve = fortune *
          spouseLegalShareWithChildren *
          compulsoryPortionFractions['conjoint']!;
      final childrenReserve = fortune *
          descendantsLegalShareWithSpouse *
          compulsoryPortionFractions['descendant']!;
      return spouseReserve + childrenReserve;
    }
    if (hasChildren) {
      return fortune *
          descendantsLegalShareWithoutSpouse *
          compulsoryPortionFractions['descendant']!;
    }
    if (hasReservedSpouse) {
      return fortune *
          spouseLegalShareWithParentela *
          compulsoryPortionFractions['conjoint']!;
    }
    return 0.0;
  }
}
