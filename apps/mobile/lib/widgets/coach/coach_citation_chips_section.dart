import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Wave 1b — citation chip section for server-side tool calls.
///
/// Sibling of [CoachSourcesSection]. Renders one chip per
/// [ToolCallCitationChip] returned by the backend. Tap opens the
/// citation modal (Plan 06 wires the modal handler via [onChipTap]).
///
/// Per CONTEXT hard constraint #5: reuses chip design tokens from the
/// existing CoachSourcesSection visual (bleuAir alpha 0.1 background,
/// 16dp radius, 12dp padding) — NOT a new design-system primitive.
///
/// Per RESEARCH §9.5: each chip carries `Key('coachCitationChip-<toolName>')`
/// for Maestro testID stability across releases.
class CoachCitationChipsSection extends StatelessWidget {
  final List<ToolCallCitationChip> chips;
  final void Function(ToolCallCitationChip)? onChipTap;

  const CoachCitationChipsSection({
    super.key,
    required this.chips,
    this.onChipTap,
  });

  /// Maps the canonical short tool name to its FR display label via ARB
  /// (Plan 07 ships the 6 keys). Falls back to the raw name for unknown
  /// tools so the chip is never silently dropped.
  String _toolDisplayName(BuildContext context, String toolName) {
    final s = S.of(context)!;
    switch (toolName) {
      case 'budget_snapshot':
        return s.coachToolBudgetSnapshot;
      case 'retirement_projection':
        return s.coachToolRetirementProjection;
      case 'cross_pillar_analysis':
        return s.coachToolCrossPillarAnalysis;
      case 'couple_optimization':
        return s.coachToolCoupleOptimization;
      case 'cap_status':
        return s.coachToolCapStatus;
      case 'retrieve_memories':
        return s.coachToolRetrieveMemories;
      default:
        return toolName;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) {
      return const SizedBox.shrink();
    }
    final s = S.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.md - 4,
        vertical: MintSpacing.md - 4,
      ),
      decoration: BoxDecoration(
        color: MintColors.bleuAir.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.coachCitationChipsHeader,
            style: MintTextStyles.micro(
              color: MintColors.textMutedAaa,
            ).copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          for (final chip in chips)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.xs),
              child: Semantics(
                label: _toolDisplayName(context, chip.toolName),
                button: true,
                child: InkWell(
                  key: Key('coachCitationChip-${chip.toolName}'),
                  borderRadius: BorderRadius.circular(8),
                  onTap: onChipTap == null ? null : () => onChipTap!(chip),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calculate_outlined,
                        size: 12,
                        color: MintColors.textSecondaryAaa
                            .withValues(alpha: 0.6),
                      ),
                      const SizedBox(width: MintSpacing.xs),
                      Expanded(
                        child: Text(
                          s.coachCitationChipLabel(
                            _toolDisplayName(context, chip.toolName),
                          ),
                          style: MintTextStyles.micro(
                            color: MintColors.textSecondaryAaa,
                          ).copyWith(
                            decoration: TextDecoration.underline,
                            decorationColor: MintColors.textSecondaryAaa
                                .withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
