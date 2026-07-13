import 'package:mint_mobile/services/financial_core/avs_calculator.dart';

/// Explicit official raw pensions on scale 44, where the 2026 payable cap is
/// known without an incomplete-scale pension-table lookup.
AvsCouplePensionResult officialScale44AvsCouple({
  required double selfPension,
  required double partnerPension,
  required AvsCoupleLegalStatus legalStatus,
  String source = 'official test fixture',
}) =>
    AvsCalculator.computeCouplePensions(
      AvsCouplePensionInput(
        legalStatus: legalStatus,
        self: AvsPersonPensionInput(
          owner: AvsPersonRole.self,
          entitlement: AvsPensionEntitlement.oldAge,
          rawMonthlyPension: selfPension,
          contributionScale: 44,
          pensionPercentage: 1,
          oldAgePaymentMode: AvsOldAgePaymentMode.ordinary,
        ),
        partner: AvsPersonPensionInput(
          owner: AvsPersonRole.partner,
          entitlement: AvsPensionEntitlement.oldAge,
          rawMonthlyPension: partnerPension,
          contributionScale: 44,
          pensionPercentage: 1,
          oldAgePaymentMode: AvsOldAgePaymentMode.ordinary,
        ),
        judicialSeparation: legalStatus == AvsCoupleLegalStatus.cohabiting
            ? null
            : AvsJudicialSeparationEvidence(
                isSeparated: false,
                source: source,
              ),
      ),
    );
