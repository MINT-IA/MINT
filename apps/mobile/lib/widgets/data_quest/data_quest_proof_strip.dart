import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/data_quest/data_quest_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

class DataQuestProofStrip extends StatelessWidget {
  final DataQuestPlan plan;
  final String keyPrefix;

  const DataQuestProofStrip({
    super.key,
    required this.plan,
    this.keyPrefix = 'data_quest',
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final ask = plan.asks.isEmpty ? null : plan.asks.first;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: '${keyPrefix}_contract',
      child: MintSurface(
        key: Key('${keyPrefix}_contract'),
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 14,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: MintColors.primary.withAlpha(18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fact_check_outlined,
                    color: MintColors.primary,
                    size: 18,
                  ),
                ),
                const SizedBox(width: MintSpacing.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.dataQuestProofTitle,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.textPrimary,
                        ).copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _caseLabel(l, plan.caseId),
                        style: MintTextStyles.labelSmall(
                          color: MintColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm + 2),
            if (ask == null)
              Text(
                l.dataQuestProofSatisfied,
                style: MintTextStyles.bodySmall(
                  color: MintColors.textPrimary,
                ).copyWith(height: 1.4),
              )
            else
              _NextAsk(
                ask: ask,
                keyPrefix: keyPrefix,
                modeLabel: _modeLabel(l, ask.mode),
                stageLabel: _stageLabel(l, ask.stage),
                fieldLabel: _fieldLabel(l, ask.inputKey),
              ),
          ],
        ),
      ),
    );
  }

  static String _caseLabel(S l, String caseId) {
    return switch (caseId) {
      'transmit_property' => l.dataQuestProofCaseTransmitProperty,
      _ => caseId,
    };
  }

  static String _modeLabel(S l, DataQuestAskMode mode) {
    return switch (mode) {
      DataQuestAskMode.collect => l.dataQuestProofNextCollect,
      DataQuestAskMode.reconfirm => l.dataQuestProofNextReconfirm,
      DataQuestAskMode.scenarioAssumption =>
        l.dataQuestProofNextScenarioAssumption,
    };
  }

  static String _stageLabel(S l, DataQuestStage stage) {
    return switch (stage) {
      DataQuestStage.guard => l.dataQuestProofStageGuard,
      DataQuestStage.required => l.dataQuestProofStageRequired,
      DataQuestStage.useful => l.dataQuestProofStageUseful,
    };
  }

  static String _fieldLabel(S l, String inputKey) {
    return switch (inputKey) {
      'propertyMarketValue' => l.dataQuestFieldPropertyMarketValue,
      'targetRetirementAge' => l.dataQuestFieldTargetRetirementAge,
      'avoirLpp' => l.dataQuestFieldAvoirLpp,
      'pillar3aBalance' => l.dataQuestFieldPillar3aBalance,
      'parentLiquidAssets' => l.dataQuestFieldParentLiquidAssets,
      'parentAnnualRetirementIncome' =>
        l.dataQuestFieldParentAnnualRetirementIncome,
      'parentAnnualLivingCosts' => l.dataQuestFieldParentAnnualLivingCosts,
      'mortgageBalance' => l.dataQuestFieldMortgageBalance,
      'heirsCount' => l.dataQuestFieldHeirsCount,
      _ => l.dataQuestFieldFallback,
    };
  }
}

class _NextAsk extends StatelessWidget {
  final DataQuestAsk ask;
  final String keyPrefix;
  final String modeLabel;
  final String stageLabel;
  final String fieldLabel;

  const _NextAsk({
    required this.ask,
    required this.keyPrefix,
    required this.modeLabel,
    required this.stageLabel,
    required this.fieldLabel,
  });

  @override
  Widget build(BuildContext context) {
    final priorValue = ask.priorValue;

    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: '${keyPrefix}_next_ask',
      child: Column(
        key: Key('${keyPrefix}_next_ask'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: MintSpacing.xs,
            runSpacing: MintSpacing.xs,
            children: [
              _Pill(
                key: Key('${keyPrefix}_mode_${ask.mode.name}'),
                semanticsIdentifier: '${keyPrefix}_mode_${ask.mode.name}',
                text: modeLabel,
                color: MintColors.primary,
              ),
              _Pill(
                key: Key('${keyPrefix}_stage_${ask.stage.name}'),
                semanticsIdentifier: '${keyPrefix}_stage_${ask.stage.name}',
                text: stageLabel,
                color: _stageColor(ask.stage),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 2),
          Text(
            fieldLabel,
            style: MintTextStyles.bodyMedium(
              color: MintColors.textPrimary,
            ).copyWith(fontWeight: FontWeight.w700, height: 1.25),
          ),
          if (priorValue != null) ...[
            const SizedBox(height: 4),
            Text(
              priorValue.toString(),
              style: MintTextStyles.labelMedium(
                color: MintColors.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static Color _stageColor(DataQuestStage stage) {
    return switch (stage) {
      DataQuestStage.guard => MintColors.urgentOrange,
      DataQuestStage.required => MintColors.info,
      DataQuestStage.useful => MintColors.successDeep,
    };
  }
}

class _Pill extends StatelessWidget {
  final String semanticsIdentifier;
  final String text;
  final Color color;

  const _Pill({
    super.key,
    required this.semanticsIdentifier,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      explicitChildNodes: true,
      identifier: semanticsIdentifier,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color.withAlpha(18),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withAlpha(55)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.sm,
            vertical: 4,
          ),
          child: Text(
            text,
            style: MintTextStyles.labelSmall(color: color).copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
