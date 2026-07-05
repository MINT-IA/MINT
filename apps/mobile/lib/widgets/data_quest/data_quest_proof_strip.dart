import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/services/data_quest/data_quest_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

const bool _runtimeProofDebugLabelsEnabled =
    kDebugMode || bool.fromEnvironment('MINT_ENABLE_RUNTIME_PROOF_SEMANTICS');

class DataQuestNextQuestionCard extends StatelessWidget {
  final DataQuestPlan plan;
  final String semanticsPrefix;

  const DataQuestNextQuestionCard({
    super.key,
    required this.plan,
    required this.semanticsPrefix,
  });

  DataQuestAsk? get _nextAsk => plan.asks.isEmpty ? null : plan.asks.first;

  String _modeLabel(S l10n, DataQuestAsk? ask) {
    if (ask == null) return l10n.dataQuestProofComplete;
    return switch (ask.mode) {
      DataQuestAskMode.collect => l10n.dataQuestProofModeCollect,
      DataQuestAskMode.reconfirm => l10n.dataQuestProofModeReconfirm,
      DataQuestAskMode.scenarioAssumption =>
        l10n.dataQuestProofModeScenarioAssumption,
    };
  }

  String _stageLabel(S l10n, DataQuestAsk? ask) {
    if (ask == null) return l10n.dataQuestProofComplete;
    return switch (ask.stage) {
      DataQuestStage.guard => l10n.dataQuestProofStageGuard,
      DataQuestStage.required => l10n.dataQuestProofStageRequired,
      DataQuestStage.useful => l10n.dataQuestProofStageUseful,
    };
  }

  String _fieldLabel(S l10n, DataQuestAsk? ask) {
    if (ask == null) return l10n.dataQuestProofNextSatisfied;
    return switch (ask.inputKey) {
      'incomeGrossYearly' => l10n.affordabilityGrossIncome,
      'canton' => l10n.affordabilityCanton,
      'birthYear' => l10n.authDateOfBirth,
      'has2ndPillar' => l10n.affordabilityPillarLpp,
      'pillar3aAnnual' => l10n.sim3aAnnualContribution,
      'patrimoine.epargneLiquide' ||
      'parentLiquidAssets' =>
        l10n.financialSummaryEpargneLiquide,
      'targetPropertyValue' => l10n.affordabilityTargetPrice,
      'householdType' => l10n.dataBlockMenageTitle,
      'patrimoine.mortgageRate' => l10n.locationTauxHypo,
      'propertyMarketValue' ||
      'patrimoine.propertyMarketValue' =>
        l10n.donationValeurImmobiliere,
      'targetRetirementAge' => l10n.dataQuestFieldTargetRetirementAge,
      'avoirLpp' => l10n.affordabilityPillarLpp,
      'pillar3aBalance' => l10n.affordabilityPillar3a,
      'parentAnnualRetirementIncome' =>
        l10n.dataQuestFieldParentAnnualRetirementIncome,
      'parentAnnualLivingCosts' => l10n.dataQuestFieldParentAnnualLivingCosts,
      'mortgageBalance' ||
      'patrimoine.mortgageBalance' =>
        l10n.dataQuestFieldMortgageBalance,
      'heirsCount' => l10n.donationNbEnfants,
      'cashPaidByRecipient' => l10n.dataQuestFieldCashPaidByRecipient,
      'mortgageAssumedByRecipient' =>
        l10n.dataQuestFieldMortgageAssumedByRecipient,
      'recipientRelationship' => l10n.dataQuestFieldRecipientRelationship,
      'retainedRight' => l10n.dataQuestFieldRetainedRight,
      'avancementHoirie' => l10n.dataQuestFieldAvancementHoirie,
      _ => l10n.dataQuestFieldFallback,
    };
  }

  String? _ownerRoute(DataQuestAsk? ask) {
    return switch (ask?.inputKey) {
      'incomeGrossYearly' ||
      'canton' ||
      'birthYear' ||
      'has2ndPillar' =>
        '/data-block/revenu',
      'pillar3aAnnual' => '/pilier-3a',
      'patrimoine.epargneLiquide' ||
      'parentLiquidAssets' ||
      'targetPropertyValue' ||
      'patrimoine.mortgageRate' =>
        '/data-block/patrimoine',
      'householdType' => '/data-block/compositionMenage',
      'targetRetirementAge' => '/data-block/objectifRetraite',
      'avoirLpp' => '/data-block/lpp',
      'pillar3aBalance' => '/data-block/3a',
      'parentAnnualRetirementIncome' => '/data-block/revenuRetraite',
      _ => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final ask = _nextAsk;
    final ownerRoute = _ownerRoute(ask);
    return Semantics(
      identifier: '${semanticsPrefix}_data_quest_next_question',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        key: ValueKey('${semanticsPrefix}_data_quest_next_question'),
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              ask == null
                  ? l10n.dataQuestNextQuestionCardReadyTitle
                  : l10n.dataQuestNextQuestionCardTitle,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
            const SizedBox(height: MintSpacing.xs),
            Semantics(
              identifier: '${semanticsPrefix}_data_quest_next_question_label',
              container: true,
              child: Text(
                _fieldLabel(l10n, ask),
                style: MintTextStyles.bodyMedium(
                  color: MintColors.textPrimary,
                ).copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              '${_modeLabel(l10n, ask)} · ${_stageLabel(l10n, ask)}',
              style: MintTextStyles.labelSmall(color: MintColors.info)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              ask == null
                  ? l10n.dataQuestNextQuestionCardReadyBody
                  : l10n.dataQuestNextQuestionCardBody,
              style: MintTextStyles.bodySmall(
                color: MintColors.textSecondary,
              ).copyWith(height: 1.35),
            ),
            if (ownerRoute != null) ...[
              const SizedBox(height: MintSpacing.sm),
              OutlinedButton.icon(
                key:
                    ValueKey('${semanticsPrefix}_data_quest_next_question_cta'),
                onPressed: () => context.push(ownerRoute),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l10n.dataBlockDefaultCta),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class DataQuestProofStrip extends StatelessWidget {
  final DataQuestPlan plan;
  final String semanticsPrefix;

  const DataQuestProofStrip({
    super.key,
    required this.plan,
    required this.semanticsPrefix,
  });

  String _nextAsk() =>
      plan.asks.isEmpty ? 'satisfied' : plan.asks.first.inputKey;

  String _nextMode() =>
      plan.asks.isEmpty ? 'satisfied' : plan.asks.first.mode.name;

  String _nextStage() =>
      plan.asks.isEmpty ? 'satisfied' : plan.asks.first.stage.name;

  String _modeLabel(S l10n, String mode) {
    return switch (mode) {
      'collect' => l10n.dataQuestProofModeCollect,
      'reconfirm' => l10n.dataQuestProofModeReconfirm,
      'scenarioAssumption' => l10n.dataQuestProofModeScenarioAssumption,
      _ => l10n.dataQuestProofNextSatisfied,
    };
  }

  String _stageLabel(S l10n, String stage) {
    return switch (stage) {
      'guard' => l10n.dataQuestProofStageGuard,
      'required' => l10n.dataQuestProofStageRequired,
      'useful' => l10n.dataQuestProofStageUseful,
      _ => l10n.dataQuestProofComplete,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final nextAsk = _nextAsk();
    final mode = _nextMode();
    final stage = _nextStage();
    return Semantics(
      identifier: '${semanticsPrefix}_data_quest_contract',
      container: true,
      explicitChildNodes: true,
      child: MintSurface(
        key: ValueKey('${semanticsPrefix}_data_quest_contract'),
        tone: MintSurfaceTone.blanc,
        padding: const EdgeInsets.all(MintSpacing.sm),
        radius: 10,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              identifier: '${semanticsPrefix}_data_quest_case_id',
              value: plan.caseId,
              container: true,
              child: Text(
                l10n.dataQuestProofCaseLabel,
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Semantics(
              identifier: '${semanticsPrefix}_data_quest_pdf_section',
              value: plan.pdfSectionId,
              container: true,
              child: Text(
                l10n.dataQuestProofPdfSectionLabel,
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Semantics(
              identifier: '${semanticsPrefix}_data_quest_runtime_proof',
              value: plan.runtimeProofId,
              container: true,
              hidden: true,
              child: const SizedBox.shrink(),
            ),
            Semantics(
              identifier: '${semanticsPrefix}_data_quest_next_ask',
              value: nextAsk,
              container: true,
              child: Text(
                nextAsk == 'satisfied'
                    ? l10n.dataQuestProofNextSatisfied
                    : l10n.dataQuestProofNextAsk,
                style: MintTextStyles.labelSmall(color: MintColors.info)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (_runtimeProofDebugLabelsEnabled)
              Text(
                'next_ask_value: $nextAsk',
                style: MintTextStyles.labelSmall(color: MintColors.textMuted),
              ),
            Semantics(
              identifier: '${semanticsPrefix}_data_quest_mode',
              value: mode,
              container: true,
              child: Text(
                _modeLabel(l10n, mode),
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
            Semantics(
              identifier: '${semanticsPrefix}_data_quest_stage',
              value: stage,
              container: true,
              child: Text(
                _stageLabel(l10n, stage),
                style:
                    MintTextStyles.labelSmall(color: MintColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
