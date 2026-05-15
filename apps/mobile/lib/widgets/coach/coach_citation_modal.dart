import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/rag_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Wave 1b — citation modal.
///
/// Opens a bottom-sheet showing the provenance of a server-side tool call:
/// tool name, inputs_hash (truncated to 16 chars), computed_at (relative,
/// via ARB keys per Q8_DECISION), raw response (collapsible pretty-printed
/// JSON), and "Souviens-toi de cette source" CTA.
///
/// Per CONTEXT D-03 — modal is READ-ONLY; no edit/refresh.
/// Per Q7_DECISION (Plan 06) — the rollout-flag-state badge is dropped in v1
/// (chip only renders when the flag is on, so the badge would always read "on"
/// with zero information content). See plan rationale for the alternative path.
/// Per Q8_DECISION (Plan 06) — relative-time strings via 4 ARB keys
/// (`coachCitationRelativeJustNow`, `coachCitationRelativeMinutes`,
/// `coachCitationRelativeHours`, `coachCitationRelativeDays`) consumed
/// through the generated `S` localization class.
Future<void> showCoachCitationModal(
  BuildContext context,
  ToolCallCitationChip chip, {
  void Function(ToolCallCitationChip)? onRememberTap,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    constraints: BoxConstraints(
      maxHeight: MediaQuery.of(context).size.height * 0.85,
    ),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => _CoachCitationModalBody(
      chip: chip,
      onRememberTap: onRememberTap,
    ),
  );
}

/// Maps the canonical Wave 1a tool short-name to its ARB display label.
/// Duplicated from CoachCitationChipsSection (Plan 05) per Karpathy #2 —
/// duplication of an 8-line switch is acceptable for v1; refactor to a
/// shared helper if a 3rd consumer appears.
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

/// Q8_DECISION — reads 4 ARB keys via the generated `S` class.
///
/// NEVER returns a Dart literal — a silent FR-only string in the EN/DE/ES/IT/PT
/// app would violate CLAUDE.md TOP rule #5 (i18n required) and would NOT be
/// caught by `validate_arb_parity` (gate checks ARB completeness, not Dart
/// literal leakage).
String _relativeTime(DateTime computedAt, S l10n) {
  final delta = DateTime.now().toUtc().difference(computedAt.toUtc());
  if (delta.inMinutes < 1) {
    return l10n.coachCitationRelativeJustNow;
  }
  if (delta.inHours < 1) {
    return l10n.coachCitationRelativeMinutes(delta.inMinutes);
  }
  if (delta.inDays < 1) {
    return l10n.coachCitationRelativeHours(delta.inHours);
  }
  return l10n.coachCitationRelativeDays(delta.inDays);
}

class _CoachCitationModalBody extends StatelessWidget {
  final ToolCallCitationChip chip;
  final void Function(ToolCallCitationChip)? onRememberTap;

  const _CoachCitationModalBody({
    required this.chip,
    this.onRememberTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final toolDisplayName = _toolDisplayName(context, chip.toolName);
    final prettyJson =
        const JsonEncoder.withIndent('  ').convert(chip.rawResponse);
    final hashShort = chip.inputsHash.length >= 16
        ? '${chip.inputsHash.substring(0, 16)}…'
        : chip.inputsHash;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(MintSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle.
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: MintSpacing.md),
              decoration: BoxDecoration(
                color: MintColors.porcelaine,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header.
          Text(
            s.coachCitationModalTitle(toolDisplayName),
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.md),
          // inputs_hash row (truncated to 16 chars + ellipsis, selectable).
          Row(
            children: [
              Icon(
                Icons.fingerprint,
                size: 14,
                color: MintColors.textSecondaryAaa.withValues(alpha: 0.7),
              ),
              const SizedBox(width: MintSpacing.xs),
              Expanded(
                child: SelectableText(
                  hashShort,
                  style: MintTextStyles.micro(
                    color: MintColors.textSecondaryAaa,
                  ).copyWith(fontFamily: 'monospace'), // lint-ignore: prefer_mint_fonts
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.xs),
          // computed_at relative row — Q8_DECISION: 4 ARB keys via
          // _relativeTime(chip.computedAt, s).
          Row(
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: MintColors.textSecondaryAaa.withValues(alpha: 0.7),
              ),
              const SizedBox(width: MintSpacing.xs),
              Text(
                _relativeTime(chip.computedAt, s),
                style: MintTextStyles.micro(
                  color: MintColors.textSecondaryAaa,
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),
          // Collapsible JSON viewer (Karpathy #2 — dart:convert pretty-print,
          // no syntax highlight dep).
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: MintColors.transparent,
            ),
            child: ExpansionTile(
              key: const Key('coachCitationModalJsonExpansion'),
              tilePadding: EdgeInsets.zero,
              childrenPadding:
                  const EdgeInsets.only(top: MintSpacing.xs),
              title: Text(
                s.coachCitationJsonViewerLabel,
                style: MintTextStyles.micro(
                  color: MintColors.textMutedAaa,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(MintSpacing.sm),
                  decoration: BoxDecoration(
                    color: MintColors.bleuAir.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    prettyJson,
                    style: MintTextStyles.micro(
                      color: MintColors.textSecondaryAaa,
                    ).copyWith(fontFamily: 'monospace'), // lint-ignore: prefer_mint_fonts
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.lg),
          // Souviens-toi CTA. Persistence (save_insight tool wiring) is
          // documented as Wave 2 follow-up — Plan 06 ships UI only.
          SizedBox(
            width: double.infinity,
            child: TextButton.icon(
              key: const Key('coachCitationModalRememberCta'),
              icon: const Icon(Icons.bookmark_outline, size: 16),
              label: Text(s.coachCitationRememberCta),
              onPressed: onRememberTap == null
                  ? null
                  : () {
                      onRememberTap!(chip);
                      Navigator.of(context).pop();
                    },
            ),
          ),
        ],
      ),
    );
  }
}
