/// TimelineNodeWidget — renders a single timeline node with type-specific icon.
///
/// Phase 18: Full Living Timeline. Visual states:
/// - earned: solid, green left border (3px)
/// - pulsing: primary left border (3px), no animation on nodes
/// - ghosted: 0.4 opacity wrapper, muted left border
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/tension_card.dart';
import 'package:mint_mobile/models/timeline_node.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class TimelineNodeWidget extends StatelessWidget {
  final TimelineNode node;

  const TimelineNodeWidget({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final title = _resolveTitle(l10n);

    Widget content = InkWell(
      onTap: () => context.go(node.deepLink),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MintColors.craie,
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: _borderColor(),
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            _buildIcon(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: MintTextStyles.bodySmall(
                      color: _titleColor(),
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (node.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      node.subtitle,
                      style: MintTextStyles.labelMedium(
                        color: MintColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );

    // Ghosted nodes get reduced opacity
    if (node.visualState == TensionType.ghosted) {
      content = Opacity(opacity: 0.4, child: content);
    }

    return content;
  }

  // ── Title resolution from i18n keys ────────────────────────

  String _resolveTitle(S l10n) {
    switch (node.title) {
      case 'timelineCommitmentEarned':
        return l10n.timelineCommitmentEarned;
      case 'timelineCommitmentActive':
        return l10n.timelineCommitmentActive;
      case 'timelineConversation':
        return l10n.timelineConversation;
      case 'timelineCoupleEstimate':
        return l10n.timelineCoupleEstimate;
      case 'timelineProjection':
        return l10n.timelineProjection;
      case 'timelineDocument':
        return l10n.timelineDocument;
      default:
        return node.title;
    }
  }

  // ── Icon by NodeType ──────────────────────────────────────

  Widget _buildIcon() {
    final IconData iconData;
    final Color iconColor;

    switch (node.type) {
      case NodeType.document:
        iconData = Icons.description_outlined;
        iconColor = MintColors.success;
      case NodeType.conversation:
        iconData = Icons.chat_bubble_outline;
        iconColor = MintColors.textPrimary;
      case NodeType.commitment:
        iconData = Icons.check_circle_outline;
        iconColor = MintColors.success;
      case NodeType.couple:
        iconData = Icons.people_outline;
        iconColor = MintColors.textPrimary;
      case NodeType.projection:
        iconData = Icons.auto_awesome;
        iconColor = MintColors.textMutedAaa;
    }

    return Icon(iconData, color: iconColor, size: 24);
  }

  // ── Visual state colors ───────────────────────────────────

  Color _borderColor() {
    switch (node.visualState) {
      case TensionType.earned:
        return MintColors.success;
      case TensionType.pulsing:
        return MintColors.textPrimary;
      case TensionType.ghosted:
        return MintColors.textMutedAaa;
    }
  }

  Color _titleColor() {
    switch (node.visualState) {
      case TensionType.earned:
        return MintColors.textPrimary;
      case TensionType.pulsing:
        return MintColors.textPrimary;
      case TensionType.ghosted:
        return MintColors.textMutedAaa;
    }
  }
}
