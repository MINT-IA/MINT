import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/response_card.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  RESPONSE CARD WIDGET — Phase 1 (S50-S51)
// ────────────────────────────────────────────────────────────
//
//  Rendu unifie pour les 10 types de cartes coach.
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
// ────────────────────────────────────────────────────────────

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
      onTap: () => context.push(card.ctaRoute),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            left: BorderSide(
              color: card.borderColor,
              width: 3,
            ),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x08000000),
              blurRadius: 8,
              offset: Offset(0, 2),
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
            if (!compact && card.chiffreChoc != null) ...[
              const SizedBox(height: 12),
              _buildChiffreChoc(),
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
        // Icon badge
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: card.badgeColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            card.icon,
            size: 18,
            color: card.borderColor,
          ),
        ),
        const SizedBox(width: 10),

        // Titre
        Expanded(
          child: Text(
            card.title,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Badge urgence / deadline
        if (card.deadlineText != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: card.badgeColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              card.deadlineText!,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: card.borderColor,
              ),
            ),
          )
        else if (card.impactPoints > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: MintColors.accentPastel,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${card.impactPoints} pts',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: MintColors.accent,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChiffreChoc() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: card.badgeColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            card.chiffreChoc!,
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: card.borderColor,
            ),
          ),
          if (card.chiffreChocLabel != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                card.chiffreChocLabel!,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Row(
      children: [
        // CTA chip
        GestureDetector(
          onTap: () => context.push(card.ctaRoute),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: MintColors.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              card.ctaLabel,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const Spacer(),

        // Source reference (if present)
        if (card.source != null)
          Text(
            card.source!,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
            ),
          ),
      ],
    );
  }
}

/// Version horizontale scrollable pour le chat inline.
class ResponseCardStrip extends StatelessWidget {
  final List<ResponseCard> cards;

  const ResponseCardStrip({super.key, required this.cards});

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: cards.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return SizedBox(
            width: 260,
            child: ResponseCardWidget(
              card: cards[index],
              compact: true,
            ),
          );
        },
      ),
    );
  }
}
