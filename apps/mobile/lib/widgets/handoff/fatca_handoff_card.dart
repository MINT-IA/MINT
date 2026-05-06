import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/colors.dart';
import '../../theme/mint_text_styles.dart';

/// FATCA hand-off card.
///
/// Shown when the backend's pre-emission gate (Phase 93 Plan 02 — COMP-04)
/// short-circuits the LLM call for an `expat_us` user asking about
/// 3a / pillar 3a / PFIC / CH-US treaty / FBAR / foreign-trust topics.
/// The backend returns a `tool_call` of shape
/// `{"name": "show_handoff_card", "input": {"kind": "fatca", ...}}` and
/// the mobile dispatcher renders this widget instead of the chat bubble.
///
/// Per OAR-G art. 24 + FINMA Guidance 8/2024 §VI.
///
/// Closes:
///   - REQUIREMENTS.md COMP-04
///   - USER_WALKTHROUGH_2026-05-06 BUG #22 P1
///
/// Banned-term hygiene (CLAUDE.md règle 1): the localized strings
/// MUST NOT contain « optimal », « garanti », « sans risque »,
/// « meilleur » or « parfait ». They use « envisager », « adapté »,
/// « pourrait » per the LSFin-compliant copy palette.
class FatcaHandoffCard extends StatelessWidget {
  /// Tapped when the user asks to be redirected to a US-CH specialist.
  /// Wired by the parent (e.g. open the in-app advisor matcher or an
  /// external URL). Keeping it injectable so this widget is pure UI.
  final VoidCallback? onCtaTap;

  const FatcaHandoffCard({super.key, this.onCtaTap});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Semantics(
      container: true,
      label: l.fatcaHandoffTitle,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.fatcaHandoffTitle,
              style: MintTextStyles.titleMedium(),
            ),
            const SizedBox(height: 8),
            Text(
              l.fatcaHandoffBody,
              style: MintTextStyles.bodyMedium(),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: onCtaTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: MintColors.textPrimary,
                  side: const BorderSide(color: MintColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(l.fatcaHandoffCta),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
