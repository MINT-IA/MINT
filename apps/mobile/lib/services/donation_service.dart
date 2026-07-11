import 'package:mint_mobile/services/financial_core/gift_tax_confirmation.dart';
import 'package:mint_mobile/services/financial_core/succession_reserve_calculator.dart';

/// Result model for donation calculation.
class DonationResult {
  final double montantDonation;
  final double tauxImposition;
  final double impotDonation;
  final bool taxRequiresCantonalConfirmation;
  final String taxStatus;
  final double reserveHereditaireTotale;
  final double quotiteDisponible;
  final bool quotiteRequiresSpecialistConfirmation;
  final bool donationDepasseQuotite;
  final double montantDepassement;
  final String impactSuccession;
  final List<String> checklist;
  final List<String> alerts;
  final String disclaimer;
  final List<String> sources;
  final String premierEclairage;

  const DonationResult({
    required this.montantDonation,
    required this.tauxImposition,
    required this.impotDonation,
    required this.taxRequiresCantonalConfirmation,
    required this.taxStatus,
    required this.reserveHereditaireTotale,
    required this.quotiteDisponible,
    required this.quotiteRequiresSpecialistConfirmation,
    required this.donationDepasseQuotite,
    required this.montantDepassement,
    required this.impactSuccession,
    required this.checklist,
    required this.alerts,
    required this.disclaimer,
    required this.sources,
    required this.premierEclairage,
  });
}

class DonationMessageCode {
  const DonationMessageCode._();

  static const taxUnknownCanton = 'tax_unknown_canton';
  static const taxUsualExemption = 'tax_usual_exemption';
  static const taxDescendantConfirm = 'tax_descendant_confirm';
  static const taxCantonalConfirm = 'tax_cantonal_confirm';
  static const impactAdvancement = 'impact_advancement';
  static const impactReductionRisk = 'impact_reduction_risk';
  static const impactOutsidePart = 'impact_outside_part';
  static const checklistVerifyQuotite = 'check_verify_quotite';
  static const checklistDocumentAdvancement = 'check_document_advancement';
  static const checklistConfirmTax = 'check_confirm_tax';
  static const checklistInformReservedHeirs = 'check_inform_reserved_heirs';
  static const checklistKeepDeed = 'check_keep_deed';
  static const checklistLandRegister = 'check_land_register';
  static const checklistFutureCollation = 'check_future_collation';
  static const checklistConcubinageQuestions = 'check_concubinage_questions';
  static const insightUsualExemption = 'insight_usual_exemption';
  static const insightTaxConfirm = 'insight_tax_confirm';
  static const disclaimerStandard = 'disclaimer_standard';
  static const alertUnknownCanton = 'alert_unknown_canton';
  static const alertTaxConfirm = 'alert_tax_confirm';
  static const alertMissingParentela = 'alert_missing_parentela';
  static const alertMatrimonialRegime = 'alert_matrimonial_regime';
  static const alertSpouseLargeGift = 'alert_spouse_large_gift';
  static const alertReductionRisk = 'alert_reduction_risk';
  static const alertConcubinage = 'alert_concubinage';
  static const alertRealEstate = 'alert_real_estate';
  static const alertOlderDonor = 'alert_older_donor';
  static const alertLargeDonation = 'alert_large_donation';
}

/// Educational donation scenario service for Switzerland.
///
/// Gift tax is cantonal/communal and cannot be reduced to one flat app-wide
/// table. This service only models robust federal succession mechanics and
/// usual exemption boundaries; otherwise it returns a confirmation state.
class DonationService {
  static const Set<String> swissCantons = {
    'AG',
    'AI',
    'AR',
    'BE',
    'BL',
    'BS',
    'FR',
    'GE',
    'GL',
    'GR',
    'JU',
    'LU',
    'NE',
    'NW',
    'OW',
    'SG',
    'SH',
    'SO',
    'SZ',
    'TG',
    'TI',
    'UR',
    'VD',
    'VS',
    'ZG',
    'ZH',
  };

  // CC art. 471, new law from 2023: compulsory portion as a fraction of the
  // legal share. Parents no longer have a compulsory portion.
  static const Map<String, double> reserves =
      SuccessionReserveCalculator.compulsoryPortionFractions;

  /// Human-readable labels for relationship types.
  static const Map<String, String> lienParenteLabels = {
    'conjoint': 'Conjoint(e)',
    'descendant': 'Enfant / Descendant(e)',
    'parent': 'Parent',
    'fratrie': 'Frere / Soeur',
    'concubin': 'Concubin(e)',
    'tiers': 'Tiers',
  };

  // Sources checked 2026-07-11:
  // - ch.ch gift tax: spouse/registered partner and descendants are usually
  //   exempt, but cantonal rules apply.
  // - VD.ch Successions/Donations + LMSD art. 16: direct-descendant gifts have
  //   a yearly allowance, not blanket exemption.
  // - NE.ch Impot sur les donations: gift tax is calculated by relationship.
  // - AI.ch Erbschafts- und Schenkungssteuer: descendants are taxed at 1%.
  // Until MINT has a sourced canton-by-canton tariff table, descendants remain
  // a confirmation state instead of a green exemption state.
  /// Calculate the educational tax and succession impact of a donation.
  static DonationResult calculate({
    required double montant,
    required int donateurAge,
    required String lienParente,
    required String canton,
    String civilStatus = 'celibataire',
    String typeDonation = 'especes',
    double valeurImmobiliere = 0,
    double soldeHypothecaire = 0,
    bool avancementHoirie = true,
    int nbEnfants = 0,
    double fortuneTotaleDonateur = 0,
  }) {
    final montantDonation =
        typeDonation == 'immobilier' && valeurImmobiliere > 0
            ? SuccessionReserveCalculator.netRealEstateGiftValue(
                marketValue: valeurImmobiliere,
                mortgageBalance: soldeHypothecaire,
              )
            : montant;
    final cantonCode = canton.trim().toUpperCase();
    final knownCanton = swissCantons.contains(cantonCode);
    final usuallyExempt = _isUsuallyGiftTaxExempt(
      knownCanton: knownCanton,
      canton: cantonCode,
      lienParente: lienParente,
    );
    final taxRequiresCantonalConfirmation = !usuallyExempt;
    final taxStatus = _taxStatus(
      knownCanton: knownCanton,
      usuallyExempt: usuallyExempt,
      lienParente: lienParente,
    );
    const tauxImposition = GiftTaxConfirmation.noComputedRate;
    const impotDonation = GiftTaxConfirmation.noComputedAmount;

    final fortune =
        fortuneTotaleDonateur > 0 ? fortuneTotaleDonateur : montantDonation;
    final reserve = SuccessionReserveCalculator.estimate(
      estateReference: fortune,
      civilStatus: civilStatus,
      childrenCount: nbEnfants,
    );
    final reserveHereditaireTotale = reserve.reserveHereditaireTotale;
    final quotiteDisponible = reserve.quotiteDisponible;

    final quotiteRequiresSpecialistConfirmation = reserve.hasReservedSpouse;
    final donationExceedsEstimatedQuotite = montantDonation > quotiteDisponible;
    final donationDepasseQuotite = !quotiteRequiresSpecialistConfirmation &&
        donationExceedsEstimatedQuotite;
    final montantDepassement =
        donationDepasseQuotite ? montantDonation - quotiteDisponible : 0.0;

    final impactSuccession = _impactSuccession(
      avancementHoirie: avancementHoirie,
      donationDepasseQuotite: donationDepasseQuotite,
    );

    final alerts = _alerts(
      knownCanton: knownCanton,
      taxRequiresCantonalConfirmation: taxRequiresCantonalConfirmation,
      lienParente: lienParente,
      typeDonation: typeDonation,
      donateurAge: donateurAge,
      montantDonation: montantDonation,
      fortuneTotaleDonateur: fortuneTotaleDonateur,
      hasReservedSpouse: reserve.hasReservedSpouse,
      hasChildren: reserve.hasChildren,
      donationExceedsEstimatedQuotite: donationExceedsEstimatedQuotite,
      donationDepasseQuotite: donationDepasseQuotite,
    );

    final checklist = <String>[
      DonationMessageCode.checklistVerifyQuotite,
      DonationMessageCode.checklistDocumentAdvancement,
      DonationMessageCode.checklistConfirmTax,
      DonationMessageCode.checklistInformReservedHeirs,
      DonationMessageCode.checklistKeepDeed,
    ];

    if (typeDonation == 'immobilier') {
      checklist.add(DonationMessageCode.checklistLandRegister);
    }

    if (avancementHoirie) {
      checklist.add(DonationMessageCode.checklistFutureCollation);
    }

    if (lienParente == 'concubin') {
      checklist.add(DonationMessageCode.checklistConcubinageQuestions);
    }

    final premierEclairage = usuallyExempt
        ? DonationMessageCode.insightUsualExemption
        : DonationMessageCode.insightTaxConfirm;

    const sources = [
      'source_ch_gift_tax',
      'source_ch_succession',
      'source_cc_457_471',
      'source_cc_471_2023',
      'source_cc_522',
      'source_co_239',
    ];

    return DonationResult(
      montantDonation: montantDonation,
      tauxImposition: tauxImposition,
      impotDonation: impotDonation,
      taxRequiresCantonalConfirmation: taxRequiresCantonalConfirmation,
      taxStatus: taxStatus,
      reserveHereditaireTotale: reserveHereditaireTotale,
      quotiteDisponible: quotiteDisponible,
      quotiteRequiresSpecialistConfirmation:
          quotiteRequiresSpecialistConfirmation,
      donationDepasseQuotite: donationDepasseQuotite,
      montantDepassement: montantDepassement,
      impactSuccession: impactSuccession,
      checklist: checklist,
      alerts: alerts,
      disclaimer: DonationMessageCode.disclaimerStandard,
      sources: sources,
      premierEclairage: premierEclairage,
    );
  }

  static String _taxStatus({
    required bool knownCanton,
    required bool usuallyExempt,
    required String lienParente,
  }) {
    if (!knownCanton) {
      return DonationMessageCode.taxUnknownCanton;
    }
    if (usuallyExempt) {
      return DonationMessageCode.taxUsualExemption;
    }
    if (lienParente == 'descendant') {
      return DonationMessageCode.taxDescendantConfirm;
    }
    return DonationMessageCode.taxCantonalConfirm;
  }

  static bool _isUsuallyGiftTaxExempt({
    required bool knownCanton,
    required String canton,
    required String lienParente,
  }) {
    if (!knownCanton) return false;
    if (lienParente == 'conjoint') return true;
    return false;
  }

  static String _impactSuccession({
    required bool avancementHoirie,
    required bool donationDepasseQuotite,
  }) {
    if (avancementHoirie) {
      return DonationMessageCode.impactAdvancement;
    }
    if (donationDepasseQuotite) {
      return DonationMessageCode.impactReductionRisk;
    }
    return DonationMessageCode.impactOutsidePart;
  }

  static List<String> _alerts({
    required bool knownCanton,
    required bool taxRequiresCantonalConfirmation,
    required String lienParente,
    required String typeDonation,
    required int donateurAge,
    required double montantDonation,
    required double fortuneTotaleDonateur,
    required bool hasReservedSpouse,
    required bool hasChildren,
    required bool donationExceedsEstimatedQuotite,
    required bool donationDepasseQuotite,
  }) {
    final alerts = <String>[];

    if (!knownCanton) {
      alerts.add(DonationMessageCode.alertUnknownCanton);
    } else if (taxRequiresCantonalConfirmation) {
      alerts.add(DonationMessageCode.alertTaxConfirm);
    }

    if (hasReservedSpouse && !hasChildren) {
      alerts.add(DonationMessageCode.alertMissingParentela);
    }

    if (hasReservedSpouse) {
      alerts.add(DonationMessageCode.alertMatrimonialRegime);
    }

    if (hasReservedSpouse && donationExceedsEstimatedQuotite) {
      alerts.add(DonationMessageCode.alertSpouseLargeGift);
    }

    if (donationDepasseQuotite) {
      alerts.add(DonationMessageCode.alertReductionRisk);
    }

    if (lienParente == 'concubin') {
      alerts.add(DonationMessageCode.alertConcubinage);
    }

    if (typeDonation == 'immobilier') {
      alerts.add(DonationMessageCode.alertRealEstate);
    }

    if (donateurAge >= 70) {
      alerts.add(DonationMessageCode.alertOlderDonor);
    }

    if (SuccessionReserveCalculator.isLargeDonation(
      donationAmount: montantDonation,
      estateReference: fortuneTotaleDonateur,
    )) {
      alerts.add(DonationMessageCode.alertLargeDonation);
    }

    return alerts;
  }
}
