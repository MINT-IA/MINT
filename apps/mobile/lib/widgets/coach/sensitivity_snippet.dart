import 'package:flutter/material.dart';
import 'package:mint_mobile/services/financial_core/tornado_sensitivity_service.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Compact sensitivity snippet showing the top 3 variables that most
/// influence retirement income.
///
/// Displays horizontal bars with pessimistic/optimistic ranges,
/// sorted by impact (swing) descending.
///
/// P4 gate: State A only (confidence >= 70%).
///
/// Ref: outil educatif (LSFin). Ne constitue pas un conseil.
class SensitivitySnippet extends StatelessWidget {
  /// Top tornado variables (pre-sorted by swing descending).
  final List<TornadoVariable> variables;

  /// Maximum number of variables to display (default 3).
  final int maxVariables;

  /// Callback to navigate to full tornado analysis.
  final VoidCallback? onViewAll;

  const SensitivitySnippet({
    super.key,
    required this.variables,
    this.maxVariables = 3,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    if (variables.isEmpty) return const SizedBox.shrink();

    final displayVars = variables.take(maxVariables).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ─────────────────────────────────
          Text(
            'Ce qui influence le plus ton revenu',
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            'Dans ces simulations, chaque variable est test\u00e9e '
            'ind\u00e9pendamment.',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),

          // ── Variable bars ──────────────────────────
          for (int i = 0; i < displayVars.length; i++) ...[
            _buildVariableRow(displayVars[i]),
            if (i < displayVars.length - 1) const SizedBox(height: 10),
          ],

          // ── View all link ──────────────────────────
          if (onViewAll != null) ...[
            const SizedBox(height: 12),
            Semantics(
              label: 'Voir l\'analyse complète',
              button: true,
              child: GestureDetector(
                onTap: onViewAll,
                child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Voir l\'analyse compl\u00e8te',
                    style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(
                    Icons.chevron_right,
                    size: 16,
                    color: MintColors.primary,
                  ),
                ],
              ),
            ),
            ),
          ],

          // ── Disclaimer ─────────────────────────────
          const SizedBox(height: 10),
          Text(
            'Outil \u00e9ducatif simplifi\u00e9 (LSFin). '
            'Sources\u00a0: LIFD art.\u00a038, LPP art.\u00a014, '
            'LAVS art.\u00a021-29.',
            style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontStyle: FontStyle.normal),
          ),
        ],
      ),
    );
  }

  Widget _buildVariableRow(TornadoVariable variable) {
    final categoryColor = _categoryColor(variable.category);
    final swing = variable.highValue - variable.lowValue;
    final deltaLow = variable.lowValue - variable.baseValue;
    final deltaHigh = variable.highValue - variable.baseValue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label + category dot
        Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: categoryColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                variable.label,
                style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '\u00b1\u00a0CHF\u00a0${formatChf(swing / 2)}',
              style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 6),

        // ── Horizontal bar ───────────────────────────
        SizedBox(
          height: 24,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints.maxWidth;
              final maxDeviation = [deltaLow.abs(), deltaHigh.abs()]
                  .reduce((a, b) => a > b ? a : b);
              if (maxDeviation == 0) return const SizedBox.shrink();

              final center = maxWidth / 2;
              final scale = (maxWidth * 0.40) / maxDeviation;

              final lowBarWidth = (deltaLow.abs() * scale).clamp(2.0, center);
              final highBarWidth = (deltaHigh.abs() * scale).clamp(2.0, center);

              return Stack(
                children: [
                  // Center line
                  Positioned(
                    left: center - 0.5,
                    top: 0,
                    bottom: 0,
                    child: Container(
                      width: 1,
                      color: MintColors.textMuted.withValues(alpha: 0.25),
                    ),
                  ),
                  // Low bar (left)
                  Positioned(
                    left: center - lowBarWidth,
                    top: 3,
                    child: Container(
                      width: lowBarWidth,
                      height: 18,
                      decoration: BoxDecoration(
                        color: MintColors.error.withValues(alpha: 0.55),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // High bar (right)
                  Positioned(
                    left: center,
                    top: 3,
                    child: Container(
                      width: highBarWidth,
                      height: 18,
                      decoration: BoxDecoration(
                        color: MintColors.success.withValues(alpha: 0.55),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  // Labels
                  Positioned(
                    left: 0,
                    top: 5,
                    child: Text(
                      variable.lowLabel,
                      style: MintTextStyles.micro(color: MintColors.error).copyWith(fontSize: 9, fontWeight: FontWeight.w500, fontStyle: FontStyle.normal),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    top: 5,
                    child: Text(
                      variable.highLabel,
                      style: MintTextStyles.micro(color: MintColors.success).copyWith(fontSize: 9, fontWeight: FontWeight.w500, fontStyle: FontStyle.normal),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  static Color _categoryColor(String category) {
    return switch (category) {
      'strategy' => MintColors.primary,
      'lpp' => MintColors.pillarLpp,
      'avs' => MintColors.amber,
      '3a' => MintColors.positive,
      'libre' => MintColors.purple,
      'depenses' => MintColors.danger,
      _ => MintColors.textSecondary,
    };
  }
}
