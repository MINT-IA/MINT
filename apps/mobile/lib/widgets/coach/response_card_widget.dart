import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

// ────────────────────────────────────────────────────────────
//  RESPONSE CARD WIDGET — V2 "Calm Narrative"
// ────────────────────────────────────────────────────────────
//
//  Principles (MINT_UX_GRAAL_MASTERPLAN.md §9 + §12):
//  - Narrative first, proof accessible, action ensuite
//  - 1 chiffre, 1 phrase, 1 CTA — lisible en 3 secondes
//  - Aucun diagnostic negatif sans levier
//  - Sources/alertes en panneau secondaire, pas exposes de force
//  - Tokens MintTextStyles, MintSpacing, MintColors uniquement
//
//  3 variantes:
//  - chat:    inline dans le coach, compact, cliquable
//  - sheet:   bottom sheet ou surface large, chiffre visible
//  - compact: minimal, titre + CTA seulement
//
//  Removed from V1:
//  - bordure gauche coloree
//  - badge "+X pts"
//  - largeur fixe 280
//  - GoogleFonts ad hoc
//  - source inline permanente
//  - alerte inline orange
// ────────────────────────────────────────────────────────────

/// Visual variant for ResponseCardWidget.
enum ResponseCardVariant {
  /// Inline in coach chat — compact narrative card.
  chat,

  /// Full surface — chiffre-choc visible, proof accessible.
  sheet,

  /// Minimal — title + subtitle + CTA only.
  compact,
}

/// Widget for a single ResponseCard.
///
/// State-of-the-art: Cleo-inspired calm narrative card.
/// Narrative → chiffre → CTA. Proof on demand.
class ResponseCardWidget extends StatelessWidget {
  final ResponseCard card;
  final ResponseCardVariant variant;

  /// Callback when CTA is tapped. Defaults to GoRouter push.
  final VoidCallback? onCtaTap;

  const ResponseCardWidget({
    super.key,
    required this.card,
    this.variant = ResponseCardVariant.sheet,
    this.onCtaTap,
  });

  /// Shortcut constructors
  const ResponseCardWidget.chat({super.key, required this.card, this.onCtaTap})
      : variant = ResponseCardVariant.chat;

  const ResponseCardWidget.compact(
      {super.key, required this.card, this.onCtaTap})
      : variant = ResponseCardVariant.compact;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${card.title} — ${card.subtitle}',
      child: GestureDetector(
        onTap: () => _handleTap(context),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: EdgeInsets.all(
            variant == ResponseCardVariant.compact
                ? MintSpacing.sm + 4
                : MintSpacing.md,
          ),
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: MintColors.black.withValues(alpha: 0.03),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: _buildContent(context),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (variant) {
      case ResponseCardVariant.compact:
        return _buildCompact(context);
      case ResponseCardVariant.chat:
        return _buildChat(context);
      case ResponseCardVariant.sheet:
        return _buildSheet(context);
    }
  }

  // ── COMPACT: titre + CTA chevron ──────────────────────────

  Widget _buildCompact(BuildContext context) {
    return Row(
      children: [
        _buildIcon(size: 32),
        const SizedBox(width: MintSpacing.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                card.title,
                style: MintTextStyles.titleMedium(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (card.subtitle.isNotEmpty)
                Text(
                  card.subtitle,
                  style: MintTextStyles.bodySmall(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        const SizedBox(width: MintSpacing.sm),
        const Icon(
          Icons.chevron_right_rounded,
          color: MintColors.textMuted,
          size: 20,
        ),
      ],
    );
  }

  // ── CHAT: narrative card for coach inline ─────────────────

  Widget _buildChat(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Title row
        Row(
          children: [
            _buildIcon(size: 28),
            const SizedBox(width: MintSpacing.sm),
            Expanded(
              child: Text(
                card.title,
                style: MintTextStyles.titleMedium(),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (_hasDeadline) _buildDeadlinePill(),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),

        // Subtitle / narrative
        Text(
          card.subtitle,
          style: MintTextStyles.bodyMedium(),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),

        // Chiffre-choc (if meaningful)
        if (_hasChiffreChoc) ...[
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            card.chiffreChoc.formatted,
            style: MintTextStyles.displayMedium(
              color: MintColors.textPrimary,
            ).copyWith(fontSize: 22),
          ),
        ],

        const SizedBox(height: MintSpacing.md),

        // CTA
        _buildCta(context),
      ],
    );
  }

  // ── SHEET: full surface with proof layer ──────────────────

  Widget _buildSheet(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header: icon + title + deadline
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIcon(size: 36),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.title,
                    style: MintTextStyles.titleMedium(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    card.subtitle,
                    style: MintTextStyles.bodySmall(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (_hasDeadline) ...[
              const SizedBox(width: MintSpacing.sm),
              _buildDeadlinePill(),
            ],
          ],
        ),

        // Chiffre-choc hero
        if (_hasChiffreChoc) ...[
          const SizedBox(height: MintSpacing.md + 4),
          Text(
            card.chiffreChoc.formatted,
            style: MintTextStyles.displayMedium(
              color: MintColors.textPrimary,
            ),
          ),
          if (card.chiffreChoc.explanation.isNotEmpty) ...[
            const SizedBox(height: MintSpacing.xs),
            Text(
              card.chiffreChoc.explanation,
              style: MintTextStyles.bodySmall(),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],

        const SizedBox(height: MintSpacing.md + 4),

        // CTA + proof access
        Row(
          children: [
            Expanded(child: _buildCta(context)),
            if (_hasProof) ...[
              const SizedBox(width: MintSpacing.sm),
              _buildProofButton(context),
            ],
          ],
        ),
      ],
    );
  }

  // ── SHARED COMPONENTS ─────────────────────────────────────

  Widget _buildIcon({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(
        card.icon ?? _typeIcon,
        size: size * 0.5,
        color: MintColors.primary,
      ),
    );
  }

  Widget _buildDeadlinePill() {
    final badge = card.deadlineBadge;
    if (badge == null) return const SizedBox.shrink();

    final isUrgent = card.urgency == CardUrgency.high;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isUrgent
            ? MintColors.error.withValues(alpha: 0.08)
            : MintColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule_rounded,
            size: 12,
            color: isUrgent ? MintColors.error : MintColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            badge,
            style: MintTextStyles.labelSmall(
              color: isUrgent ? MintColors.error : MintColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCta(BuildContext context) {
    return Semantics(
      button: true,
      label: card.cta.label,
      child: GestureDetector(
        onTap: () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.md,
            vertical: MintSpacing.sm + 2,
          ),
          decoration: BoxDecoration(
            color: MintColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  card.cta.label,
                  style: MintTextStyles.bodySmall(color: MintColors.white)
                      .copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: MintColors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Proof accessible" button — opens sources + alertes in a bottom sheet.
  /// Narrative first, proof on demand (MINT_UX_GRAAL_MASTERPLAN §9).
  Widget _buildProofButton(BuildContext context) {
    return GestureDetector(
      onTap: () => _showProofSheet(context),
      child: Container(
        padding: const EdgeInsets.all(MintSpacing.sm + 2),
        decoration: BoxDecoration(
          color: MintColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  void _showProofSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(MintSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: MintColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: MintSpacing.md),

            Text(card.title, style: MintTextStyles.titleMedium()),
            const SizedBox(height: MintSpacing.md),

            // Sources
            if (card.sources.isNotEmpty) ...[
              Text(S.of(context)?.proofSheetSources ?? 'Sources',
                  style: MintTextStyles.bodySmall()),
              const SizedBox(height: MintSpacing.xs),
              ...card.sources.map(
                (s) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(s, style: MintTextStyles.micro()),
                ),
              ),
              const SizedBox(height: MintSpacing.md),
            ],

            // Alertes
            if (card.alertes.isNotEmpty) ...[
              ...card.alertes.map(
                (a) => Container(
                  margin: const EdgeInsets.only(bottom: MintSpacing.sm),
                  padding: const EdgeInsets.all(MintSpacing.sm + 4),
                  decoration: BoxDecoration(
                    color: MintColors.warning.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: MintColors.warning.withValues(alpha: 0.7),
                      ),
                      const SizedBox(width: MintSpacing.sm),
                      Expanded(
                        child: Text(
                          a,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            // Disclaimer
            if (card.disclaimer.isNotEmpty) ...[
              const SizedBox(height: MintSpacing.sm),
              Text(card.disclaimer, style: MintTextStyles.micro()),
            ],

            const SizedBox(height: MintSpacing.md),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (onCtaTap != null) {
      onCtaTap!();
    } else {
      context.push(card.cta.route);
    }
  }

  // ── COMPUTED ──────────────────────────────────────────────

  bool get _hasChiffreChoc => card.chiffreChoc.value != 0;
  bool get _hasDeadline => card.deadlineBadge != null;
  bool get _hasProof =>
      card.sources.isNotEmpty ||
      card.alertes.isNotEmpty ||
      card.disclaimer.isNotEmpty;

  IconData get _typeIcon => switch (card.type) {
        ResponseCardType.pillar3a => Icons.savings_rounded,
        ResponseCardType.lppBuyback => Icons.account_balance_rounded,
        ResponseCardType.replacementRate => Icons.trending_up_rounded,
        ResponseCardType.renteVsCapital => Icons.compare_arrows_rounded,
        ResponseCardType.avsGap => Icons.verified_user_rounded,
        ResponseCardType.taxOptimization => Icons.receipt_long_rounded,
        ResponseCardType.coupleAlert => Icons.family_restroom_rounded,
        ResponseCardType.patrimoine => Icons.account_balance_wallet_rounded,
        ResponseCardType.mortgage => Icons.home_rounded,
        ResponseCardType.independant => Icons.business_center_rounded,
      };
}

/// Scrollable strip of ResponseCards — used in coach chat.
///
/// V2: uses chat variant by default. Flexible width.
class ResponseCardStrip extends StatelessWidget {
  final List<ResponseCard> cards;
  final ResponseCardVariant variant;

  const ResponseCardStrip({
    super.key,
    required this.cards,
    this.variant = ResponseCardVariant.chat,
  });

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    if (cards.length == 1) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
        child: ResponseCardWidget(card: cards.first, variant: variant),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // 75% of available width, minimum 260, maximum 320.
        final cardWidth = (constraints.maxWidth * 0.75).clamp(260.0, 320.0);
        return SizedBox(
          height: _estimateHeight(),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.md),
            itemCount: cards.length,
            separatorBuilder: (_, __) =>
                const SizedBox(width: MintSpacing.sm + 4),
            itemBuilder: (_, index) => SizedBox(
              width: cardWidth,
              child: ResponseCardWidget(card: cards[index], variant: variant),
            ),
          ),
        );
      },
    );
  }

  double _estimateHeight() {
    switch (variant) {
      case ResponseCardVariant.compact:
        return 72;
      case ResponseCardVariant.chat:
        return _hasChiffreChoc ? 200 : 160;
      case ResponseCardVariant.sheet:
        return _hasChiffreChoc ? 260 : 200;
    }
  }

  bool get _hasChiffreChoc =>
      cards.any((c) => c.chiffreChoc.value != 0);
}
