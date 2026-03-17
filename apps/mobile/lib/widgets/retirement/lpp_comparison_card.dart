import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
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
    final s = S.of(context)!;
    return Column(
      children: [
        // Side-by-side comparison
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── LEFT: Rente ─────────────────────────────
            Expanded(child: _buildRenteCard(s)),
            const SizedBox(width: 12),
            // ── RIGHT: Capital ──────────────────────────
            Expanded(child: _buildCapitalCard(s)),
          ],
        ),
        const SizedBox(height: 16),

        // ── Breakeven indicator ─────────────────────────
        _buildBreakevenBar(s),
      ],
    );
  }

  Widget _buildRenteCard(S s) {
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
                s.retirementLppRente,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Monthly amount
          Text(
            RetirementService.formatChf(renteMensuelle),
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: MintColors.info,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.retirementLppParMois,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
            ),
          ),
          const SizedBox(height: 8),

          // Annual
          Text(
            s.retirementLppAnnuelSuffix(RetirementService.formatChf(renteAnnuelle)),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
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
                  s.retirementLppAVie,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.info,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapitalCard(S s) {
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
                s.retirementLppCapital,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Net amount
          Text(
            RetirementService.formatChf(capitalNet),
            style: GoogleFonts.montserrat(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: MintColors.success,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            s.retirementLppNetUneFois,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
            ),
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
                  s.retirementLppImpot(RetirementService.formatChf(capitalImpot)),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.error,
                  ),
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
                  s.retirementLppUnique,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakevenBar(S s) {
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
                  s.retirementLppBreakevenTitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.retirementLppBreakevenDesc(breakevenAge),
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
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
              style: GoogleFonts.montserrat(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: MintColors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
