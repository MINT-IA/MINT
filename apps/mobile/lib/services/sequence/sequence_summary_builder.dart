/// Builds a human-readable summary from completed sequence outputs.
///
/// Accepts localization object (S) for i18n-compliant labels.
/// Takes templateId + allOutputs + localizations → structured summary items.
///
/// Each template has its own summary logic because the financial
/// context and key numbers differ between housing, 3a, and retirement.
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/sequence_message_payload.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;

/// Builds summary items from completed sequence outputs.
///
/// [templateId] identifies which sequence template was completed.
/// [allOutputs] maps stepId → {key: value} for all completed steps.
/// [l] provides localized labels for each summary line.
///
/// Returns a list of [SequenceSummaryItem] for display in the chat.
/// Returns empty list if the template is unknown or outputs are empty.
List<SequenceSummaryItem> buildSequenceSummary({
  required String templateId,
  required Map<String, Map<String, dynamic>> allOutputs,
  S? l,
}) {
  final loc = l ?? _FallbackLabels();
  return switch (templateId) {
    'housing_purchase' => _buildHousingSummary(allOutputs, loc),
    'optimize_3a' => _build3aSummary(allOutputs, loc),
    'retirement_prep' => _buildRetirementSummary(allOutputs, loc),
    'financial_tension' => _buildTensionSummary(allOutputs, loc),
    'preretraite_complete' => _buildPreretraiteSummary(allOutputs, loc),
    _ => const [],
  };
}

/// Fallback labels (FR) for testing without a full localization context.
/// Production code MUST pass S.of(context)! as [l].
class _FallbackLabels implements S {
  @override String get summaryCapaciteAchat => 'Capacité d\u2019achat';
  @override String get summaryFondsPropres => 'Fonds propres nécessaires';
  @override String get summaryRetraitEpl => 'Retrait EPL envisagé';
  @override String get summaryImpactRente => 'Impact sur ta rente';
  @override String get summaryImpotRetrait => 'Impôt sur le retrait';
  @override String get summaryMontantNet => 'Montant net après impôt';
  @override String get summaryVersementAnnuel => 'Versement annuel';
  @override String get summaryEconomieFiscale => 'Économie fiscale annuelle';
  @override String get summaryGainEchelonnement => 'Gain à échelonner les retraits';
  @override String get summaryTauxRemplacement => 'Taux de remplacement';
  @override String get summaryEcartMensuel => 'Écart mensuel estimé';
  @override String get summaryEconomieRachat => 'Économie via rachat échelonné';
  @override String get summaryDonneesLpp => 'Données certificat LPP';
  @override String get summaryEstimationSansCertificat => 'Estimation sans certificat';
  @override String get summaryChoixRenteCapital => 'Choix rente/capital';
  @override String get summaryRatioEndettement => 'Ratio d\u2019endettement';
  @override String get summaryMargeMensuelle => 'Marge mensuelle';
  @override String get summaryRevenuNet => 'Revenu net mensuel';
  @override String get summaryChargesFixes => 'Charges fixes totales';
  @override String get summaryHorizonLiberation => 'Horizon de libération';
  @override String get summaryVersementMensuel => 'Versement mensuel';

  @override dynamic noSuchMethod(Invocation invocation) => '';
}

List<SequenceSummaryItem> _buildHousingSummary(
  Map<String, Map<String, dynamic>> outputs, S l,
) {
  final items = <SequenceSummaryItem>[];

  final step1 = outputs['housing_01_affordability'];
  final capacite = step1?['capacite_achat'];
  if (capacite is num && capacite > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.home_outlined,
      label: l.summaryCapaciteAchat,
      value: 'CHF\u00a0${formatChf(capacite.toDouble())}',
    ));
  }
  final fonds = step1?['fonds_propres_requis'];
  if (fonds is num && fonds > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.savings_outlined,
      label: l.summaryFondsPropres,
      value: 'CHF\u00a0${formatChf(fonds.toDouble())}',
    ));
  }

  final step2 = outputs['housing_02_epl'];
  final epl = step2?['montant_epl'];
  if (epl is num && epl > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.account_balance_outlined,
      label: l.summaryRetraitEpl,
      value: 'CHF\u00a0${formatChf(epl.toDouble())}',
    ));
  }
  final impact = step2?['impact_rente'];
  if (impact is num && impact.abs() > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.trending_down_outlined,
      label: l.summaryImpactRente,
      value: '-CHF\u00a0${formatChf(impact.abs().toDouble())}/mois',
    ));
  }

  final step3 = outputs['housing_03_fiscal'];
  final impot = step3?['impot_retrait'];
  if (impot is num && impot > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.receipt_long_outlined,
      label: l.summaryImpotRetrait,
      value: 'CHF\u00a0${formatChf(impot.toDouble())}',
    ));
  }

  if (epl is num && epl > 0 && impot is num && impot > 0) {
    final net = epl - impot;
    items.add(SequenceSummaryItem(
      icon: Icons.check_circle_outline,
      label: l.summaryMontantNet,
      value: 'CHF\u00a0${formatChf(net.toDouble())}',
    ));
  }

  return items;
}

List<SequenceSummaryItem> _build3aSummary(
  Map<String, Map<String, dynamic>> outputs, S l,
) {
  final items = <SequenceSummaryItem>[];

  final step1 = outputs['3a_01_simulator'];
  final contribution = step1?['contribution_annuelle'];
  if (contribution is num && contribution > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.savings_outlined,
      label: l.summaryVersementAnnuel,
      value: 'CHF\u00a0${formatChf(contribution.toDouble())}',
    ));
  }
  final economieFiscale = step1?['economie_fiscale'];
  if (economieFiscale is num && economieFiscale > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.discount_outlined,
      label: l.summaryEconomieFiscale,
      value: 'CHF\u00a0${formatChf(economieFiscale.toDouble())}',
    ));
  }

  final step2 = outputs['3a_02_withdrawal'];
  final gain = step2?['gain_echelonnement'];
  if (gain is num && gain > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.timeline_outlined,
      label: l.summaryGainEchelonnement,
      value: 'CHF\u00a0${formatChf(gain.toDouble())}',
    ));
  }

  return items;
}

List<SequenceSummaryItem> _buildRetirementSummary(
  Map<String, Map<String, dynamic>> outputs, S l,
) {
  final items = <SequenceSummaryItem>[];

  final step1 = outputs['ret_01_projection'];
  final taux = step1?['taux_remplacement'];
  if (taux is num && taux > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.speed_outlined,
      label: l.summaryTauxRemplacement,
      value: '${taux.toStringAsFixed(0)}\u00a0%',
    ));
  }
  final gap = step1?['gap_mensuel'];
  if (gap is num && gap > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.warning_amber_outlined,
      label: l.summaryEcartMensuel,
      value: 'CHF\u00a0${formatChf(gap.toDouble())}',
    ));
  }

  final step2 = outputs['ret_02_choice'];
  final decision = step2?['decision_mixte'];
  if (decision is String && decision.isNotEmpty) {
    final choiceLabel = switch (decision) {
      'certificate' => l.summaryDonneesLpp,
      'estimate' => l.summaryEstimationSansCertificat,
      _ => '${l.summaryChoixRenteCapital}\u00a0: $decision',
    };
    items.add(SequenceSummaryItem(
      icon: Icons.check_circle_outline,
      label: choiceLabel,
      value: '✓',
    ));
  }

  final step3 = outputs['ret_03_buyback'];
  final economie = step3?['economie_rachat'];
  if (economie is num && economie > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.trending_up_outlined,
      label: l.summaryEconomieRachat,
      value: 'CHF\u00a0${formatChf(economie.toDouble())}',
    ));
  }

  return items;
}

List<SequenceSummaryItem> _buildTensionSummary(
  Map<String, Map<String, dynamic>> outputs, S l,
) {
  final items = <SequenceSummaryItem>[];

  final step1 = outputs['tension_01_diagnostic'];
  final ratio = step1?['ratio_endettement'];
  if (ratio is num && ratio > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.speed_outlined,
      label: l.summaryRatioEndettement,
      value: '${ratio.toStringAsFixed(0)}\u00a0%',
    ));
  }
  final marge = step1?['marge_mensuelle'];
  if (marge is num) {
    items.add(SequenceSummaryItem(
      icon: marge >= 0 ? Icons.check_circle_outline : Icons.warning_amber_outlined,
      label: l.summaryMargeMensuelle,
      value: 'CHF\u00a0${formatChf(marge.toDouble())}',
    ));
  }

  final step2 = outputs['tension_02_budget'];
  final revenu = step2?['revenu_net'];
  if (revenu is num && revenu > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.account_balance_wallet_outlined,
      label: l.summaryRevenuNet,
      value: 'CHF\u00a0${formatChf(revenu.toDouble())}',
    ));
  }
  final charges = step2?['charges_totales'];
  if (charges is num && charges > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.receipt_outlined,
      label: l.summaryChargesFixes,
      value: 'CHF\u00a0${formatChf(charges.toDouble())}',
    ));
  }

  final step3 = outputs['tension_03_repayment'];
  final horizon = step3?['horizon_mois'];
  if (horizon is num && horizon > 0) {
    final annees = horizon >= 12
        ? '${(horizon / 12).toStringAsFixed(1)} ans'
        : '${horizon.round()} mois';
    items.add(SequenceSummaryItem(
      icon: Icons.calendar_today_outlined,
      label: l.summaryHorizonLiberation,
      value: annees,
    ));
  }
  final versement = step3?['versement_mensuel'];
  if (versement is num && versement > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.payments_outlined,
      label: l.summaryVersementMensuel,
      value: 'CHF\u00a0${formatChf(versement.toDouble())}',
    ));
  }

  return items;
}

List<SequenceSummaryItem> _buildPreretraiteSummary(
  Map<String, Map<String, dynamic>> outputs, S l,
) {
  final items = <SequenceSummaryItem>[];

  // Step 1: Projection
  final step1 = outputs['pre_01_projection'];
  final taux = step1?['taux_remplacement'];
  if (taux is num && taux > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.speed_outlined,
      label: l.summaryTauxRemplacement,
      value: '${taux.toStringAsFixed(0)}\u00a0%',
    ));
  }
  final gap = step1?['gap_mensuel'];
  if (gap is num && gap > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.warning_amber_outlined,
      label: l.summaryEcartMensuel,
      value: 'CHF\u00a0${formatChf(gap.toDouble())}',
    ));
  }

  // Step 2: 3a
  final step2 = outputs['pre_02_3a'];
  final economieFiscale = step2?['economie_fiscale'];
  if (economieFiscale is num && economieFiscale > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.discount_outlined,
      label: l.summaryEconomieFiscale,
      value: 'CHF\u00a0${formatChf(economieFiscale.toDouble())}',
    ));
  }

  // Step 3: Rente vs Capital choice
  final step3 = outputs['pre_03_choice'];
  final decision = step3?['decision_mixte'];
  if (decision is String && decision.isNotEmpty) {
    items.add(SequenceSummaryItem(
      icon: Icons.check_circle_outline,
      label: l.summaryChoixRenteCapital,
      value: '✓',
    ));
  }

  // Step 4: 3a withdrawal optimization
  final step4 = outputs['pre_04_withdrawal'];
  final gainEch = step4?['gain_echelonnement'];
  if (gainEch is num && gainEch > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.timeline_outlined,
      label: l.summaryGainEchelonnement,
      value: 'CHF\u00a0${formatChf(gainEch.toDouble())}',
    ));
  }

  // Step 6: LPP buyback (optional)
  final step6 = outputs['pre_06_buyback'];
  final economieRachat = step6?['economie_rachat'];
  if (economieRachat is num && economieRachat > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.trending_up_outlined,
      label: l.summaryEconomieRachat,
      value: 'CHF\u00a0${formatChf(economieRachat.toDouble())}',
    ));
  }

  return items;
}
