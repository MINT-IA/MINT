/// TensionCardWidget — visual representation of a single tension card.
///
/// Phase 17: Living Timeline. Three visual states:
/// - earned: solid, green left border, checkmark
/// - pulsing: animated opacity, primary left border, dot
/// - ghosted: reduced opacity, dashed left border, blur icon
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/tension_card.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class TensionCardWidget extends StatefulWidget {
  final TensionCard card;

  const TensionCardWidget({super.key, required this.card});

  @override
  State<TensionCardWidget> createState() => _TensionCardWidgetState();
}

class _TensionCardWidgetState extends State<TensionCardWidget>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.card.type == TensionType.pulsing) {
      _pulseController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 2),
      );
      _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
        CurvedAnimation(
          parent: _pulseController!,
          curve: Curves.easeInOut,
        ),
      );
      _pulseController!.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final title = _resolveTitle(l10n);
    final subtitle = _resolveSubtitle(l10n);

    Widget cardContent = InkWell(
      onTap: () => context.go(widget.card.deepLink),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.craie,
          borderRadius: BorderRadius.circular(12),
          border: _buildBorder(),
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
                    style: MintTextStyles.bodyMedium(
                      color: _titleColor(),
                    ).copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ).copyWith(fontWeight: FontWeight.w400),
                      maxLines: 2,
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

    // Wrap pulsing cards with animated opacity
    if (widget.card.type == TensionType.pulsing && _pulseAnimation != null) {
      cardContent = AnimatedBuilder(
        animation: _pulseAnimation!,
        builder: (context, child) => Opacity(
          opacity: _pulseAnimation!.value,
          child: child,
        ),
        child: cardContent,
      );
    }

    // Wrap ghosted cards with reduced opacity
    if (widget.card.type == TensionType.ghosted) {
      cardContent = Opacity(
        opacity: 0.4,
        child: cardContent,
      );
    }

    return cardContent;
  }

  // ── Title resolution from i18n keys ────────────────────────

  String _resolveTitle(S l10n) {
    switch (widget.card.title) {
      case 'tensionEarnedCommitment':
        return l10n.tensionEarnedCommitment;
      case 'tensionEarnedFirstConvo':
        return l10n.tensionEarnedFirstConvo;
      case 'tensionPulsingActiveCommitment':
        return l10n.tensionPulsingActiveCommitment;
      case 'tensionPulsingTalkToCoach':
        return l10n.tensionPulsingTalkToCoach;
      case 'tensionGhostedLandmark':
        return l10n.tensionGhostedLandmark(widget.card.subtitle);
      case 'tensionGhostedFuture':
        return l10n.tensionGhostedFuture;
      default:
        return widget.card.title;
    }
  }

  String _resolveSubtitle(S l10n) {
    // For landmark cards, subtitle is already embedded in title via placeholder
    if (widget.card.title == 'tensionGhostedLandmark') return '';
    return widget.card.subtitle;
  }

  // ── Visual state helpers ───────────────────────────────────

  BoxBorder _buildBorder() {
    switch (widget.card.type) {
      case TensionType.earned:
        return const Border(
          left: BorderSide(color: MintColors.success, width: 4),
        );
      case TensionType.pulsing:
        return const Border(
          left: BorderSide(color: MintColors.textPrimary, width: 4),
        );
      case TensionType.ghosted:
        // Solid fallback for ghosted — dashed not natively supported
        // The 0.4 opacity wrapper already provides the ghosted visual
        return const Border(
          left: BorderSide(color: MintColors.textMutedAaa, width: 4),
        );
    }
  }

  Widget _buildIcon() {
    switch (widget.card.type) {
      case TensionType.earned:
        return const Icon(
          Icons.check_circle,
          color: MintColors.success,
          size: 24,
        );
      case TensionType.pulsing:
        return const Icon(
          Icons.circle,
          color: MintColors.textPrimary,
          size: 8,
        );
      case TensionType.ghosted:
        return const Icon(
          Icons.blur_on,
          color: MintColors.textMutedAaa,
          size: 24,
        );
    }
  }

  Color _titleColor() {
    switch (widget.card.type) {
      case TensionType.earned:
        return MintColors.textPrimary;
      case TensionType.pulsing:
        return MintColors.textPrimary;
      case TensionType.ghosted:
        return MintColors.textMutedAaa;
    }
  }
}
