// Phase 96 D-04..D-07 — inline animated row revealed below a card on tap.
//
// 48dp expansion (MintSpacing.xxl), 200ms easeOutCubic
// (MintMotion.curveStandard). 3 verb chips: « Explique-moi » / « Simule »
// / « Rassure-moi ». Per CLAUDE.md rule 2 (zero hardcoded colors per
// Phase 90 lint prefer_mint_color_token) and rule 5 (i18n via
// AppLocalizations). 44dp minimum tap targets per Apple HIG (D-04
// compliance, T-96-W1-CardActionBarUI mitigation).
//
// Scope (Karpathy #2): SCAFFOLD + DISPATCH only. The persistent
// pressed-state visual (mentheVive12 background + mintForest icon
// + inkPrimary text per UI-SPEC) is delegated to the InkWell splash
// for v1 — a future StatefulWidget toggle is a polish iteration.

import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;
import 'package:mint_mobile/models/serialized_card_context.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_motion.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class MintCardActionBar extends StatelessWidget {
  /// Card snapshot routed to the chat overlay or simulator. Plan 96-02
  /// extends this to the backend coach_chat endpoint.
  final SerializedCardContext sourceCard;

  /// When true, the 48dp row reveals with a 200ms AnimatedSize +
  /// AnimatedOpacity. When false, the widget collapses to height 0.
  final bool expanded;

  /// « Explique-moi » tap — opens MintChatOverlay with intent=explain.
  final VoidCallback onExplain;

  /// « Simule » tap — deep-links to Explorer (zero LLM call, D-06).
  final VoidCallback onSimulate;

  /// « Rassure-moi » tap — opens MintChatOverlay with intent=reassure.
  final VoidCallback onReassure;

  /// 200ms is the locked D-04 duration. It sits between MintMotion.fast
  /// (150ms) and MintMotion.standard (300ms), so we use a literal
  /// Duration here (the only one in this widget file, by D-26 grep gate).
  static const Duration _kAnimDuration = Duration(milliseconds: 200);

  const MintCardActionBar({
    super.key,
    required this.sourceCard,
    required this.expanded,
    required this.onExplain,
    required this.onSimulate,
    required this.onReassure,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Semantics(
      identifier: 'mint_card_action_bar',
      container: true,
      label: 'Actions sur cette carte',
      child: AnimatedSize(
        duration: _kAnimDuration,
        curve: MintMotion.curveStandard,
        child: AnimatedOpacity(
          duration: _kAnimDuration,
          curve: MintMotion.curveStandard,
          opacity: expanded ? 1.0 : 0.0,
          child: SizedBox(
            height: expanded ? MintSpacing.xxl : 0,
            child: Container(
              color: MintColors.craieHandoff,
              padding: const EdgeInsets.symmetric(
                horizontal: MintSpacing.md,
              ),
              // F008/F009 — 3 chips share the available width via
              // Expanded(flex: 1). The inner icon+label cluster can scale
              // down slightly instead of truncating primary action labels on
              // iPhone-width Home screenshots.
              child: Row(
                children: [
                  Expanded(
                    child: _VerbChip(
                      label: l.verbExplique,
                      icon: Icons.lightbulb_outline,
                      semanticsIdentifier: 'mint_card_action_explain',
                      semanticsLabel:
                          'Explique-moi — ouvre le coach sur cette carte',
                      onTap: onExplain,
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: _VerbChip(
                      label: l.verbSimule,
                      icon: Icons.tune_outlined,
                      semanticsIdentifier: 'mint_card_action_simulate',
                      semanticsLabel:
                          'Simule — ouvre le simulateur pour cette carte',
                      onTap: onSimulate,
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: _VerbChip(
                      label: l.verbRassure,
                      icon: Icons.shield_outlined,
                      semanticsIdentifier: 'mint_card_action_reassure',
                      semanticsLabel:
                          "Rassure-moi — ouvre le coach pour réduire l'inquiétude",
                      onTap: onReassure,
                    ),
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

class _VerbChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final String semanticsIdentifier;
  final String semanticsLabel;
  final VoidCallback onTap;

  const _VerbChip({
    required this.label,
    required this.icon,
    required this.semanticsIdentifier,
    required this.semanticsLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticsIdentifier,
      button: true,
      label: semanticsLabel,
      child: InkWell(
        onTap: onTap,
        splashColor: MintColors.mentheVive12,
        highlightColor: MintColors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 44,
            minWidth: 44,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md,
              vertical: 12,
            ),
            decoration: BoxDecoration(
              color: MintColors.surface,
              border: Border.all(color: MintColors.border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: MintColors.textMuted),
                  const SizedBox(width: MintSpacing.xs),
                  Text(
                    label,
                    style: MintTextStyles.labelLarge(
                      color: MintColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.visible,
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
