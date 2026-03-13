import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  RESPONSE CARD WIDGET — Phase 1 / Dynamic Cards
// ────────────────────────────────────────────────────────────
//
//  Rendu unifie pour les cartes coach.
//  Utilise dans PulseScreen et CoachChatScreen.
//
//  Layout :
//  ┌──────────────────────────────────────┐
//  │ [icon]  Titre              [badge]  │
//  │         Sous-titre                  │
//  │                                      │
//  │  ╔═══════════════╗                  │
//  │  ║ CHF 34'200    ║  ← chiffre-choc │
//  │  ║ impact estime ║                  │
//  │  ╚═══════════════╝                  │
//  │                                      │
//  │  [CTA button]              [source] │
//  └──────────────────────────────────────┘
//
//  Aucun terme banni. CTA educatifs uniquement.
// ────────────────────────────────────────────────────────────

/// Widget individuel pour une ResponseCard.
///
/// Supporte un mode [compact] (sans chiffre-choc) pour le chat inline.
class ResponseCardWidget extends StatelessWidget {
  final ResponseCard card;

  /// Si true, affiche une version compacte (sans chiffre-choc).
  /// Utilise dans le chat inline.
  final bool compact;

  const ResponseCardWidget({
    super.key,
    required this.card,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(card.cta.route),
      child: Container(
        width: compact ? null : 280,
        padding: const EdgeInsets.all(16),
        margin: compact ? EdgeInsets.zero : const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: card.borderColor,
              width: 3,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: MintColors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header : icon + titre + badge ──────────
            _buildHeader(),
            const SizedBox(height: 6),

            // ── Sous-titre ────────────────────────────
            Text(
              card.subtitle,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
              maxLines: compact ? 2 : 3,
              overflow: TextOverflow.ellipsis,
            ),

            // ── Chiffre-choc (mode normal uniquement) ─
            if (!compact) ...[
              const SizedBox(height: 8),
              _buildChiffreChoc(),
            ],

            // ── Explanation ─────────────────────────────
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(
                card.chiffreChoc.explanation,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            // ── Alertes ─────────────────────────────────
            if (!compact && card.alertes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: MintColors.warning.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14,
                        color: MintColors.warning.withValues(alpha: 0.8)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        card.alertes.first,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: MintColors.warning,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // ── Footer : CTA + source ─────────────────
            const SizedBox(height: 12),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        // Type icon
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: card.badgeColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            card.icon ?? _typeIcon,
            size: 18,
            color: card.borderColor,
          ),
        ),
        const SizedBox(width: 10),

        // Title
        Expanded(
          child: Text(
            card.title,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Deadline badge
        if (card.deadlineBadge != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: card.badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.schedule, size: 12, color: card.borderColor),
                const SizedBox(width: 4),
                Text(
                  card.deadlineBadge!,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: card.borderColor,
                  ),
                ),
              ],
            ),
          )
        else if (card.impactPoints > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: card.badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${card.impactPoints} pts',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: card.borderColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChiffreChoc() {
    return Text(
      card.chiffreChoc.formatted,
      style: GoogleFonts.montserrat(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: card.borderColor,
        letterSpacing: -0.5,
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        // CTA button
        Flexible(
          child: GestureDetector(
            onTap: () => context.push(card.cta.route),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: MintColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (card.cta.icon != null) ...[
                    Icon(_ctaIcon, size: 14, color: MintColors.white),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      card.cta.label,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MintColors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Source reference
        if (card.sources.isNotEmpty)
          Flexible(
            child: Text(
              card.sources.join(' · '),
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    );
  }

  // ── Type → Icon mapping ─────────────────────────────────

  IconData get _typeIcon => switch (card.type) {
        ResponseCardType.pillar3a => Icons.savings,
        ResponseCardType.lppBuyback => Icons.account_balance,
        ResponseCardType.replacementRate => Icons.trending_up,
        ResponseCardType.renteVsCapital => Icons.compare_arrows,
        ResponseCardType.avsGap => Icons.verified_user,
        ResponseCardType.taxOptimization => Icons.receipt_long,
        ResponseCardType.coupleAlert => Icons.family_restroom,
        ResponseCardType.patrimoine => Icons.account_balance_wallet,
        ResponseCardType.mortgage => Icons.home,
        ResponseCardType.independant => Icons.business_center,
      };

  // ── CTA icon ────────────────────────────────────────────

  IconData get _ctaIcon => switch (card.cta.icon) {
        'savings' => Icons.savings,
        'account_balance' => Icons.account_balance,
        'trending_up' => Icons.trending_up,
        'receipt_long' => Icons.receipt_long,
        'family_restroom' => Icons.family_restroom,
        'verified_user' => Icons.verified_user,
        'home' => Icons.home,
        'account_balance_wallet' => Icons.account_balance_wallet,
        'business_center' => Icons.business_center,
        _ => Icons.arrow_forward,
      };
}

/// Strip horizontale scrollable de ResponseCards.
/// Utilisee dans le chat Coach et optionnellement sur Pulse.
class ResponseCardStrip extends StatelessWidget {
  final List<ResponseCard> cards;

  const ResponseCardStrip({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: _estimateCardHeight(cards),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          return ResponseCardWidget(card: cards[index]);
        },
      ),
    );
  }

  /// Estime la hauteur du strip selon le contenu le plus riche.
  static double _estimateCardHeight(List<ResponseCard> cards) {
    double maxHeight = 310; // base (title + subtitle + chiffre + explanation + footer + padding)
    for (final card in cards) {
      if (card.alertes.isNotEmpty) maxHeight = maxHeight.clamp(350, 400);
      if (card.sources.isNotEmpty) maxHeight = maxHeight.clamp(330, 400);
    }
    return maxHeight;
  }
}
