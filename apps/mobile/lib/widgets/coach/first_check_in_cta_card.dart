import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  FIRST CHECK-IN CTA CARD — Phase 5 / Suivi & Check-in
// ────────────────────────────────────────────────────────────
//
// Empty state card shown on Aujourd'hui when the user has a plan
// but hasn't done any check-in yet.
//
// Per 05-UI-SPEC.md:
//  - MintSurface tone: craie
//  - Icon: Icons.calendar_today_outlined, 32px, textMuted alpha 0.4
//  - Title: headlineMedium
//  - Body: bodyLarge
//  - CTA: FilledButton full-width
// ────────────────────────────────────────────────────────────

class FirstCheckInCtaCard extends StatelessWidget {
  final VoidCallback? onTap;

  const FirstCheckInCtaCard({super.key, this.onTap});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return MintSurface(
      tone: MintSurfaceTone.craie,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 32,
            color: MintColors.textMuted.withValues(alpha: 0.4),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            l.firstCheckInCardTitle,
            style: MintTextStyles.headlineMedium(),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            l.firstCheckInCardBody,
            style: MintTextStyles.bodyLarge(color: MintColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MintSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onTap,
              child: Text(l.checkInCtaButton),
            ),
          ),
        ],
      ),
    );
  }
}
