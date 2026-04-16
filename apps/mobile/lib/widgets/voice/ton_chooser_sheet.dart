// Phase 12-01 — Ton chooser modal sheet (D-02).
//
// Full-width bottom sheet wrapping [TonChooser]. Shown on intent_screen
// first launch BEFORE routing to /coach/chat. Returns the chosen
// [VoicePreference], or null if the user dismisses with "Plus tard".
//
// Anti-shame: "Plus tard" is a first-class option, not a hidden escape.
// Default Profile.voiceCursorPreference (direct) remains intact on skip.

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/services/voice/voice_cursor_contract.dart'
    show VoicePreference;
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/voice/ton_chooser.dart';

/// Push the [TonChooserSheet] as a modal bottom sheet.
///
/// Returns the chosen [VoicePreference], or `null` if the user tapped
/// "Plus tard" or dismissed the sheet.
Future<VoicePreference?> showTonChooserSheet(
  BuildContext context, {
  required VoicePreference current,
}) {
  return showModalBottomSheet<VoicePreference>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MintColors.craie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => TonChooserSheet(initial: current),
  );
}

/// Sheet body. Stateful so the user can preview a selection before tapping
/// "Continuer". Pops with the chosen [VoicePreference] on confirm, or `null`
/// on "Plus tard".
class TonChooserSheet extends StatefulWidget {
  const TonChooserSheet({super.key, required this.initial});

  final VoicePreference initial;

  @override
  State<TonChooserSheet> createState() => _TonChooserSheetState();
}

class _TonChooserSheetState extends State<TonChooserSheet> {
  late VoicePreference _selected = widget.initial;

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          MintSpacing.lg,
          MintSpacing.md,
          MintSpacing.lg,
          MintSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Drag handle ──
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.lightBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),

            // ── Title row + Plus tard ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l10n.tonChooserTitle,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                TextButton(
                  key: const ValueKey('ton_sheet_skip'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    l10n.tonSkipLater,
                    style: MintTextStyles.labelLarge(
                      color: MintColors.textSecondaryAaa,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              l10n.tonChooserSubtitle,
              style: MintTextStyles.bodyLarge(
                color: MintColors.textSecondaryAaa,
              ),
            ),
            const SizedBox(height: MintSpacing.lg),

            // ── Chooser ──
            TonChooser(
              current: _selected,
              onChanged: (v) => setState(() => _selected = v),
            ),
            const SizedBox(height: MintSpacing.lg),

            // ── Confirm CTA ──
            FilledButton(
              key: const ValueKey('ton_sheet_confirm'),
              onPressed: () => Navigator.of(context).pop(_selected),
              style: FilledButton.styleFrom(
                backgroundColor: MintColors.primary,
                foregroundColor: MintColors.card,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(
                MaterialLocalizations.of(context).continueButtonLabel,
                style: MintTextStyles.labelLarge(color: MintColors.card),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
