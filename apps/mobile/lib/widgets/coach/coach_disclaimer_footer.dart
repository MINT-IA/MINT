import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  COACH DISCLAIMER FOOTER — permanent slim legal anchor
//
//  Phase C (2026-04-14). Replaces the legacy per-message
//  CoachDisclaimersSection card. State-of-the-art pattern:
//  Wise / Revolut / Cleo all use a single permanent footer
//  with a tap target opening the canonical legal text.
//
//  Legal basis: LSFin/FINMA require the disclaimer to be
//  accessible at-a-tap — NOT duplicated under every message.
//
//  Visual: one line, ~32px total, textMutedAaa @ 40% alpha,
//  MintTextStyles.micro, tap → modal bottom sheet with the
//  canonical disclaimer content.
// ────────────────────────────────────────────────────────────

/// Permanent slim disclaimer footer for the coach chat scaffold.
///
/// One line, muted, tappable. Opens [showCoachDisclaimerSheet] on tap.
/// Accessible as a Semantics button with a 44x44 minimum hit target.
class CoachDisclaimerFooter extends StatelessWidget {
  const CoachDisclaimerFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Semantics(
      button: true,
      label: s.coachDisclaimerCollapsed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showCoachDisclaimerSheet(context),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 44),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md,
            vertical: MintSpacing.xs,
          ),
          child: Text(
            s.coachDisclaimerCollapsed,
            textAlign: TextAlign.center,
            style: MintTextStyles.micro(
              color: MintColors.textMutedAaa.withValues(alpha: 0.4),
            ).copyWith(
              fontSize: 11,
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
          ),
        ),
      ),
    );
  }
}

/// Opens the canonical disclaimer as a scrollable modal bottom sheet.
///
/// Content is a concise, LSFin-compliant restatement sourced from
/// `legal/DISCLAIMER.md`. The body text uses the existing i18n key
/// `coachDisclaimer`, already localized in the 6 supported languages.
Future<void> showCoachDisclaimerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: MintColors.craie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => const _CoachDisclaimerSheet(),
  );
}

class _CoachDisclaimerSheet extends StatelessWidget {
  const _CoachDisclaimerSheet();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final mq = MediaQuery.of(context);
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: mq.size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.textMutedAaa.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Header row with close button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.md,
                vertical: MintSpacing.xs,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.coachDisclaimerCollapsed,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textPrimary,
                      ).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Fermer',
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      color: MintColors.textSecondaryAaa,
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 0.5),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  MintSpacing.md,
                  MintSpacing.md,
                  MintSpacing.md,
                  MintSpacing.lg,
                ),
                child: Text(
                  s.coachDisclaimer,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondaryAaa,
                  ).copyWith(height: 1.55),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
