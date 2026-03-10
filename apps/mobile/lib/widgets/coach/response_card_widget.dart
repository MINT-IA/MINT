import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  RESPONSE CARD WIDGET — Phase 1 / Dynamic Cards
// ────────────────────────────────────────────────────────────
//
//  Affiche une ResponseCard avec :
//    - Chiffre-choc (gros nombre impactant)
//    - Deadline badge (si urgence)
//    - CTA educatif
//    - Sources legales
//
//  Utilise sur le dashboard Pulse et dans le chat Coach.
//  Aucun terme banni. CTA educatifs uniquement.
// ────────────────────────────────────────────────────────────

/// Widget individuel pour une ResponseCard.
class ResponseCardWidget extends StatelessWidget {
  final ResponseCard card;

  const ResponseCardWidget({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 280,
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _urgencyBorderColor.withValues(alpha: 0.3),
          width: card.urgency == CardUrgency.high ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: icon + title + deadline badge
          _buildHeader(),

          // Chiffre-choc
          _buildChiffreChoc(),

          // Explanation
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              card.chiffreChoc.explanation,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Alertes
          if (card.alertes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
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
            ),
          ],

          const SizedBox(height: 12),

          // CTA button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push(card.cta.route),
                style: FilledButton.styleFrom(
                  backgroundColor: _typeAccentColor,
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (card.cta.icon != null) ...[
                      Icon(_ctaIcon, size: 16),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        card.cta.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Sources
          if (card.sources.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
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

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Row(
        children: [
          // Type icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _typeAccentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _typeIcon,
              size: 20,
              color: _typeAccentColor,
            ),
          ),
          const SizedBox(width: 10),

          // Title + subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  card.title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  card.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Deadline badge
          if (card.deadlineBadge != null) _buildDeadlineBadge(),
        ],
      ),
    );
  }

  Widget _buildDeadlineBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _urgencyBadgeColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.schedule,
            size: 12,
            color: _urgencyBadgeColor,
          ),
          const SizedBox(width: 4),
          Text(
            card.deadlineBadge!,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _urgencyBadgeColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
      child: Text(
        card.chiffreChoc.formatted,
        style: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: _typeAccentColor,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  // ── Type → Color mapping ────────────────────────────────

  Color get _typeAccentColor => switch (card.type) {
        ResponseCardType.pillar3a => MintColors.retirement3a,
        ResponseCardType.lppBuyback => MintColors.retirementLpp,
        ResponseCardType.replacementRate => MintColors.info,
        ResponseCardType.renteVsCapital => MintColors.cyan,
        ResponseCardType.avsGap => MintColors.retirementAvs,
        ResponseCardType.taxOptimization => MintColors.indigo,
        ResponseCardType.coupleAlert => MintColors.pink,
        ResponseCardType.patrimoine => MintColors.teal,
        ResponseCardType.mortgage => MintColors.deepOrange,
        ResponseCardType.independant => MintColors.amber,
      };

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

  // ── Urgency → Color mapping ─────────────────────────────

  Color get _urgencyBorderColor => switch (card.urgency) {
        CardUrgency.high => MintColors.error,
        CardUrgency.medium => MintColors.warning,
        CardUrgency.low => MintColors.border,
      };

  Color get _urgencyBadgeColor => switch (card.urgency) {
        CardUrgency.high => MintColors.error,
        CardUrgency.medium => MintColors.warning,
        CardUrgency.low => MintColors.textMuted,
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
    double maxHeight = 220; // base
    for (final card in cards) {
      if (card.alertes.isNotEmpty) maxHeight = maxHeight.clamp(260, 300);
      if (card.sources.isNotEmpty) maxHeight = maxHeight.clamp(240, 300);
    }
    return maxHeight;
  }
}
