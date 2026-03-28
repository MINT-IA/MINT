/// Builds a human-readable summary from completed sequence outputs.
///
/// Pure function — no LLM, no side effects, no providers.
/// Takes templateId + allOutputs → returns structured summary items.
///
/// Each template has its own summary logic because the financial
/// context and key numbers differ between housing, 3a, and retirement.
library;

import 'package:flutter/material.dart';
import 'package:mint_mobile/models/sequence_message_payload.dart';
import 'package:mint_mobile/services/lpp_deep_service.dart' show formatChf;

/// Builds summary items from completed sequence outputs.
///
/// [templateId] identifies which sequence template was completed.
/// [allOutputs] maps stepId → {key: value} for all completed steps.
///
/// Returns a list of [SequenceSummaryItem] for display in the chat.
/// Returns empty list if the template is unknown or outputs are empty.
List<SequenceSummaryItem> buildSequenceSummary({
  required String templateId,
  required Map<String, Map<String, dynamic>> allOutputs,
}) {
  return switch (templateId) {
    'housing_purchase' => _buildHousingSummary(allOutputs),
    'optimize_3a' => _build3aSummary(allOutputs),
    'retirement_prep' => _buildRetirementSummary(allOutputs),
    'financial_tension' => _buildTensionSummary(allOutputs),
    _ => const [],
  };
}

List<SequenceSummaryItem> _buildHousingSummary(
  Map<String, Map<String, dynamic>> outputs,
) {
  final items = <SequenceSummaryItem>[];

  // Step 1: Affordability
  final step1 = outputs['housing_01_affordability'];
  final capacite = step1?['capacite_achat'];
  if (capacite is num && capacite > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.home_outlined,
      label: 'Capacité d\u2019achat',
      value: 'CHF\u00a0${formatChf(capacite.toDouble())}',
    ));
  }
  final fonds = step1?['fonds_propres_requis'];
  if (fonds is num && fonds > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.savings_outlined,
      label: 'Fonds propres nécessaires',
      value: 'CHF\u00a0${formatChf(fonds.toDouble())}',
    ));
  }

  // Step 2: EPL
  final step2 = outputs['housing_02_epl'];
  final epl = step2?['montant_epl'];
  if (epl is num && epl > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.account_balance_outlined,
      label: 'Retrait EPL envisagé',
      value: 'CHF\u00a0${formatChf(epl.toDouble())}',
    ));
  }
  final impact = step2?['impact_rente'];
  if (impact is num && impact.abs() > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.trending_down_outlined,
      label: 'Impact sur ta rente',
      value: '-CHF\u00a0${formatChf(impact.abs().toDouble())}/mois',
    ));
  }

  // Step 3: Fiscal
  final step3 = outputs['housing_03_fiscal'];
  final impot = step3?['impot_retrait'];
  if (impot is num && impot > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.receipt_long_outlined,
      label: 'Impôt sur le retrait',
      value: 'CHF\u00a0${formatChf(impot.toDouble())}',
    ));
  }

  // Net after tax (if we have both EPL and tax)
  if (epl is num && epl > 0 && impot is num && impot > 0) {
    final net = epl - impot;
    items.add(SequenceSummaryItem(
      icon: Icons.check_circle_outline,
      label: 'Montant net après impôt',
      value: 'CHF\u00a0${formatChf(net.toDouble())}',
    ));
  }

  return items;
}

List<SequenceSummaryItem> _build3aSummary(
  Map<String, Map<String, dynamic>> outputs,
) {
  final items = <SequenceSummaryItem>[];

  // Step 1: Simulator 3a
  final step1 = outputs['3a_01_simulator'];
  final contribution = step1?['contribution_annuelle'];
  if (contribution is num && contribution > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.savings_outlined,
      label: 'Versement annuel',
      value: 'CHF\u00a0${formatChf(contribution.toDouble())}',
    ));
  }
  final economieFiscale = step1?['economie_fiscale'];
  if (economieFiscale is num && economieFiscale > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.discount_outlined,
      label: 'Économie fiscale annuelle',
      value: 'CHF\u00a0${formatChf(economieFiscale.toDouble())}',
    ));
  }

  // Step 2: Staggered withdrawal
  final step2 = outputs['3a_02_withdrawal'];
  final gain = step2?['gain_echelonnement'];
  if (gain is num && gain > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.timeline_outlined,
      label: 'Gain à échelonner les retraits',
      value: 'CHF\u00a0${formatChf(gain.toDouble())}',
    ));
  }

  return items;
}

List<SequenceSummaryItem> _buildRetirementSummary(
  Map<String, Map<String, dynamic>> outputs,
) {
  final items = <SequenceSummaryItem>[];

  // Step 1: Projection
  final step1 = outputs['ret_01_projection'];
  final taux = step1?['taux_remplacement'];
  if (taux is num && taux > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.speed_outlined,
      label: 'Taux de remplacement',
      value: '${taux.toStringAsFixed(0)}\u00a0%',
    ));
  }
  final gap = step1?['gap_mensuel'];
  if (gap is num && gap > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.warning_amber_outlined,
      label: 'Écart mensuel estimé',
      value: 'CHF\u00a0${formatChf(gap.toDouble())}',
    ));
  }

  // Step 2: Rente vs Capital choice
  final step2 = outputs['ret_02_choice'];
  final decision = step2?['decision_mixte'];
  if (decision is String && decision.isNotEmpty) {
    final label = switch (decision) {
      'certificate' => 'Données certificat LPP',
      'estimate' => 'Estimation sans certificat',
      _ => 'Choix rente/capital\u00a0: $decision',
    };
    items.add(SequenceSummaryItem(
      icon: Icons.check_circle_outline,
      label: label,
      value: '✓',
    ));
  }

  // Step 3: LPP buyback (optional)
  final step3 = outputs['ret_03_buyback'];
  final economie = step3?['economie_rachat'];
  if (economie is num && economie > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.trending_up_outlined,
      label: 'Économie via rachat échelonné',
      value: 'CHF\u00a0${formatChf(economie.toDouble())}',
    ));
  }

  return items;
}

List<SequenceSummaryItem> _buildTensionSummary(
  Map<String, Map<String, dynamic>> outputs,
) {
  final items = <SequenceSummaryItem>[];

  // Step 1: Debt ratio diagnostic
  final step1 = outputs['tension_01_diagnostic'];
  final ratio = step1?['ratio_endettement'];
  if (ratio is num && ratio > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.speed_outlined,
      label: 'Ratio d\u2019endettement',
      value: '${(ratio * 100).toStringAsFixed(0)}\u00a0%',
    ));
  }
  final marge = step1?['marge_mensuelle'];
  if (marge is num) {
    items.add(SequenceSummaryItem(
      icon: marge >= 0 ? Icons.check_circle_outline : Icons.warning_amber_outlined,
      label: 'Marge mensuelle',
      value: 'CHF\u00a0${formatChf(marge.toDouble())}',
    ));
  }

  // Step 2: Budget
  final step2 = outputs['tension_02_budget'];
  final revenu = step2?['revenu_net'];
  if (revenu is num && revenu > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.account_balance_wallet_outlined,
      label: 'Revenu net mensuel',
      value: 'CHF\u00a0${formatChf(revenu.toDouble())}',
    ));
  }
  final charges = step2?['charges_totales'];
  if (charges is num && charges > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.receipt_outlined,
      label: 'Charges fixes totales',
      value: 'CHF\u00a0${formatChf(charges.toDouble())}',
    ));
  }

  // Step 3: Repayment
  final step3 = outputs['tension_03_repayment'];
  final horizon = step3?['horizon_mois'];
  if (horizon is num && horizon > 0) {
    final annees = horizon >= 12
        ? '${(horizon / 12).toStringAsFixed(1)} ans'
        : '${horizon.round()} mois';
    items.add(SequenceSummaryItem(
      icon: Icons.calendar_today_outlined,
      label: 'Horizon de libération',
      value: annees,
    ));
  }
  final versement = step3?['versement_mensuel'];
  if (versement is num && versement > 0) {
    items.add(SequenceSummaryItem(
      icon: Icons.payments_outlined,
      label: 'Versement mensuel',
      value: 'CHF\u00a0${formatChf(versement.toDouble())}',
    ));
  }

  return items;
}
