import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/services/retirement_service.dart';

// ────────────────────────────────────────────────────────────
//  LPP COMPARISON CARD — Sprint S21
// ────────────────────────────────────────────────────────────
//
// Two side-by-side cards:
//   Left:  "Rente" with monthly amount + "a vie"
//   Right: "Capital" with net amount + tax detail
//   Bottom: breakeven age indicator
//
// Neutral presentation (no recommendation).
// ────────────────────────────────────────────────────────────

class LppComparisonCard extends StatelessWidget {
  final double renteMensuelle;
  final double renteAnnuelle;
  final double capitalBrut;
  final double capitalNet;
  final double capitalImpot;
  final int breakevenAge;

  const LppComparisonCard({
    super.key,
    required this.renteMensuelle,
    required this.renteAnnuelle,
    required this.capitalBrut,
    required this.capitalNet,
    required this.capitalImpot,
    required this.breakevenAge,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Side-by-side comparison
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LEFT: Rente ─────────────────────────────
            Expanded(child: _buildRenteCard()),
            const SizedBox(width: 12),
            // ── RIGHT: Capital ──────────────────────────
            Expanded(child: _buildCapitalCard()),
          ],
        ),
        const SizedBox(height: 16),

        // ── Breakeven indicator ─────────────────────────
        _buildBreakevenBar(),
      ],
    );
  }

  Widget _buildRenteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: MintColors.info.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.autorenew,
                  size: 14,
                  color: MintColors.info,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rente',
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Monthly amount
          Text(
            RetirementService.formatChf(renteMensuelle),
            style: MintTextStyles.headlineMedium(color: MintColors.info).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'par mois',
            style: MintTextStyles.bodyMedium(color: MintColors.textMuted).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 8),

          // Annual
          Text(
            '${RetirementService.formatChf(renteAnnuelle)}/an',
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontSize: 13),
          ),
          const SizedBox(height: 12),

          // "a vie" badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.all_inclusive,
                    size: 12, color: MintColors.info),
                const SizedBox(width: 4),
                Text(
                  'a vie',
                  style: MintTextStyles.labelSmall(color: MintColors.info).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapitalCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: MintColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  size: 14,
                  color: MintColors.success,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Capital',
                style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Net amount
          Text(
            RetirementService.formatChf(capitalNet),
            style: MintTextStyles.headlineMedium(color: MintColors.success).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            'net (une fois)',
            style: MintTextStyles.bodyMedium(color: MintColors.textMuted).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 8),

          // Tax detail
          Row(
            children: [
              const Icon(Icons.remove_circle_outline,
                  size: 12, color: MintColors.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Impot: ${RetirementService.formatChf(capitalImpot)}',
                  style: MintTextStyles.bodyMedium(color: MintColors.error).copyWith(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // "unique" badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt, size: 12, color: MintColors.success),
                const SizedBox(width: 4),
                Text(
                  'unique',
                  style: MintTextStyles.labelSmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakevenBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: MintColors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.balance,
              size: 18,
              color: MintColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Point d\'equilibre',
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  'Si tu vis au-dela de $breakevenAge ans, la rente est plus avantageuse',
                  style: MintTextStyles.bodyMedium(color: MintColors.textSecondary).copyWith(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: MintColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$breakevenAge',
              style: MintTextStyles.headlineMedium(color: MintColors.white).copyWith(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}
