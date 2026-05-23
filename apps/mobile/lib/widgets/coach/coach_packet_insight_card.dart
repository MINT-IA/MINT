import 'package:flutter/material.dart';
import 'package:mint_mobile/services/data_spine/coach_packet_insight_presenter.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class CoachPacketInsightCard extends StatelessWidget {
  final CoachPacketInsight insight;

  const CoachPacketInsightCard({
    super.key,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'coach-context-point-de-depart',
      container: true,
      explicitChildNodes: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: MintColors.craie,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: MintColors.borderSubtle),
          ),
          child: Padding(
            padding: const EdgeInsets.all(MintSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  insight.title,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.md),
                _InsightLine(
                  label: insight.knownLabel,
                  text: insight.knownText,
                ),
                const SizedBox(height: MintSpacing.sm),
                _InsightLine(
                  label: insight.nextLabel,
                  text: insight.nextText,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightLine extends StatelessWidget {
  final String label;
  final String text;

  const _InsightLine({
    required this.label,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: MintTextStyles.labelMedium(color: MintColors.textMuted),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          text,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
        ),
      ],
    );
  }
}
