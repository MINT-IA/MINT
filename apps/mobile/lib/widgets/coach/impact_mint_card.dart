import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  IMPACT MINT CARD — LOT 4 / Retirement Dashboard
// ────────────────────────────────────────────────────────────
//
//  Comparaison avant/apres des actions d'optimisation MINT.
//  Affiche deux colonnes (Sans / Avec) + delta en evidence.
//
//  Visible uniquement si delta > 0 (guard interne).
//
//  Aucun terme banni. Ton pedagogique.
//  Widget pur — aucune dependance Provider.
// ────────────────────────────────────────────────────────────

class ImpactMintCard extends StatefulWidget {
  /// Revenu mensuel estim\u00e9 sans actions d'optimisation. CHF/mois.
  final double withoutOptimization;

  /// Revenu mensuel estim\u00e9 avec actions MINT. CHF/mois.
  final double withOptimization;

  /// Description courte des actions (ex. "gr\u00e2ce au 3a et rachat LPP").
  final String description;

  const ImpactMintCard({
    super.key,
    required this.withoutOptimization,
    required this.withOptimization,
    required this.description,
  });

  @override
  State<ImpactMintCard> createState() => _ImpactMintCardState();
}

class _ImpactMintCardState extends State<ImpactMintCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double get _delta => widget.withOptimization - widget.withoutOptimization;

  @override
  Widget build(BuildContext context) {
    // Guard : ne pas afficher si delta nul ou negatif
    if (_delta <= 0) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: MintColors.scoreExcellent.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: MintColors.scoreExcellent.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildComparison(),
          const SizedBox(height: 14),
          _buildDescription(),
          const SizedBox(height: 12),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  HEADER
  // ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MintColors.scoreExcellent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.bolt,
            color: MintColors.scoreExcellent,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Impact des actions MINT',
                style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Text(
                'Ce que tu peux faire changer',
                style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  COMPARISON COLUMNS
  // ────────────────────────────────────────────────────────────

  Widget _buildComparison() {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, _) {
        return Row(
          children: [
            // Sans
            Expanded(
              child: _buildColumn(
                title: 'Sans actions',
                amount: widget.withoutOptimization,
                color: MintColors.textMuted,
                bgColor: MintColors.surface,
                isHighlighted: false,
              ),
            ),
            const SizedBox(width: 12),
            // Arrow
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 20),
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: MintColors.scoreExcellent.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    size: 16,
                    color: MintColors.scoreExcellent,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            // Avec
            Expanded(
              child: _buildColumn(
                title: 'Avec MINT',
                amount: widget.withOptimization,
                color: MintColors.scoreExcellent,
                bgColor: MintColors.scoreExcellent.withValues(alpha: 0.06),
                isHighlighted: true,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildColumn({
    required String title,
    required double amount,
    required Color color,
    required Color bgColor,
    required bool isHighlighted,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: isHighlighted
            ? Border.all(
                color: MintColors.scoreExcellent.withValues(alpha: 0.30))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MintTextStyles.labelSmall(color: color).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            formatChfWithPrefix(amount),
            style: MintTextStyles.titleMedium(color: isHighlighted ? MintColors.scoreExcellent : MintColors.textSecondary).copyWith(fontWeight: FontWeight.w800, height: 1.1),
          ),
          const SizedBox(height: 2),
          Text(
            '/ mois',
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  DELTA + DESCRIPTION
  // ────────────────────────────────────────────────────────────

  Widget _buildDescription() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.scoreExcellent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            '+${formatChfWithPrefix(_delta)} / mois',
            style: MintTextStyles.titleMedium(color: MintColors.scoreExcellent).copyWith(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.description,
              style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  DISCLAIMER
  // ────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Text(
      'Outil \u00e9ducatif simplifi\u00e9. Ne constitue pas un conseil financier (LSFin).',
      style: MintTextStyles.micro(color: MintColors.textMuted),
    );
  }

}
