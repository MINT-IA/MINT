// Phase 12-01 — Ton chooser segmented control (D-01).
//
// Stateless 3-option segmented control bound to the user's voice preference
// (soft / direct / unfiltered). Used by [TonChooserSheet] (first-launch) and
// inline in the [ProfileDrawer] settings.
//
// Anti-shame doctrine: all 3 options are presented as equally legitimate.
// NEVER use the word "curseur" — see CI gate `tools/ci/grep_no_user_facing_curseur.sh`.
// Default selection is `direct` (mirrors [CoachProfile.voiceCursorPreference]).
//
// Pure presentation: callers wire state via [onChanged]. Pulls all labels from
// AppLocalizations (keys added in Plan 12-01). AAA-contrast tokens only.

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart'
    show VoicePreference;
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Stateless 3-option Ton segmented control (D-01).
class TonChooser extends StatelessWidget {
  const TonChooser({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final VoicePreference current;
  final ValueChanged<VoicePreference> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    final cells = <_TonCellSpec>[
      _TonCellSpec(
        value: VoicePreference.soft,
        label: l10n.tonSoftLabel,
        example: l10n.tonSoftExample,
      ),
      _TonCellSpec(
        value: VoicePreference.direct,
        label: l10n.tonDirectLabel,
        example: l10n.tonDirectExample,
      ),
      _TonCellSpec(
        value: VoicePreference.unfiltered,
        label: l10n.tonUnfilteredLabel,
        example: l10n.tonUnfilteredExample,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: MintColors.craie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          for (final cell in cells)
            Expanded(
              child: _TonCell(
                spec: cell,
                selected: cell.value == current,
                onTap: () => onChanged(cell.value),
                selectedSemantics: l10n.tonSelectedSemantics,
                notSelectedSemantics: l10n.tonNotSelectedSemantics,
              ),
            ),
        ],
      ),
    );
  }
}

class _TonCellSpec {
  const _TonCellSpec({
    required this.value,
    required this.label,
    required this.example,
  });

  final VoicePreference value;
  final String label;
  final String example;
}

class _TonCell extends StatelessWidget {
  const _TonCell({
    required this.spec,
    required this.selected,
    required this.onTap,
    required this.selectedSemantics,
    required this.notSelectedSemantics,
  });

  final _TonCellSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final String selectedSemantics;
  final String notSelectedSemantics;

  @override
  Widget build(BuildContext context) {
    final bg = selected ? MintColors.card : Colors.transparent;
    final labelColor =
        selected ? MintColors.textPrimary : MintColors.textSecondaryAaa;
    final exampleColor =
        selected ? MintColors.infoAaa : MintColors.textSecondaryAaa;

    return Semantics(
      key: ValueKey('ton_cell_${spec.value.name}'),
      container: true,
      button: true,
      selected: selected,
      label: '${spec.label}, '
          '${selected ? selectedSemantics : notSelectedSemantics}',
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(11),
        child: InkResponse(
          onTap: onTap,
          radius: 80,
          containedInkWell: true,
          highlightShape: BoxShape.rectangle,
          customBorder: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(11),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68, minWidth: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.sm,
                vertical: MintSpacing.sm,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    spec.label,
                    style: MintTextStyles.labelLarge(color: labelColor),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    spec.example,
                    style: MintTextStyles.bodySmall(color: exampleColor),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
