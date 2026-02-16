import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/fiscal_service.dart';

// ────────────────────────────────────────────────────────────
//  MOVE SAVINGS CARD — Sprint S20 / Comparateur 26 cantons
// ────────────────────────────────────────────────────────────
//
// Reusable comparison card for canton move simulation.
// Shows: [Canton A] → [Canton B]
// Annual/10-year savings, chiffre choc text.
// Green = savings, Red = surcharge.
// ────────────────────────────────────────────────────────────

class MoveSavingsCard extends StatelessWidget {
  final String cantonFrom;
  final String cantonFromName;
  final String cantonTo;
  final String cantonToName;
  final double chargeFrom;
  final double chargeTo;
  final double economieAnnuelle;
  final double economieMensuelle;
  final double economie10Ans;
  final String chiffreChoc;

  const MoveSavingsCard({
    super.key,
    required this.cantonFrom,
    required this.cantonFromName,
    required this.cantonTo,
    required this.cantonToName,
    required this.chargeFrom,
    required this.chargeTo,
    required this.economieAnnuelle,
    required this.economieMensuelle,
    required this.economie10Ans,
    required this.chiffreChoc,
  });

  bool get _isSaving => economieAnnuelle > 0;
  bool get _isSame => economieAnnuelle.abs() < 1;

  Color get _accentColor => _isSame
      ? MintColors.info
      : _isSaving
          ? MintColors.success
          : MintColors.error;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Chiffre choc ───────────────────────────────────
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: _accentColor,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Text(
                _isSame
                    ? '~CHF\u00A00'
                    : _isSaving
                        ? '+${FiscalService.formatChf(economieAnnuelle)}/an'
                        : '-${FiscalService.formatChf(-economieAnnuelle)}/an',
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                chiffreChoc,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Canton comparison ──────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Column(
            children: [
              // From → To
              Row(
                children: [
                  Expanded(child: _buildCantonBadge(cantonFrom, cantonFromName)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.arrow_forward,
                      color: _accentColor,
                      size: 24,
                    ),
                  ),
                  Expanded(child: _buildCantonBadge(cantonTo, cantonToName)),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: MintColors.border.withValues(alpha: 0.5)),
              const SizedBox(height: 16),

              // Charges comparison
              Row(
                children: [
                  Expanded(
                    child: _buildChargeColumn(
                      'Charge actuelle',
                      chargeFrom,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 50,
                    color: MintColors.lightBorder,
                  ),
                  Expanded(
                    child: _buildChargeColumn(
                      'Nouvelle charge',
                      chargeTo,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(color: MintColors.border.withValues(alpha: 0.5)),
              const SizedBox(height: 16),

              // Savings breakdown
              _buildSavingsRow(
                'Économie mensuelle',
                economieMensuelle,
              ),
              const SizedBox(height: 8),
              _buildSavingsRow(
                'Économie annuelle',
                economieAnnuelle,
              ),
              const SizedBox(height: 8),
              _buildSavingsRow(
                'Économie sur 10 ans',
                economie10Ans,
                isBold: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCantonBadge(String code, String name) {
    return Column(
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: MintColors.appleSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Text(
            code,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          name,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MintColors.textSecondary,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildChargeColumn(String label, double amount) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          FiscalService.formatChf(amount),
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildSavingsRow(String label, double amount, {bool isBold = false}) {
    final isPositive = amount > 0;
    final displayAmount = amount.abs();
    final prefix = isPositive ? '+' : amount < 0 ? '-' : '';
    final color = _isSame
        ? MintColors.textSecondary
        : isPositive
            ? MintColors.success
            : MintColors.error;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: isBold ? 14 : 13,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: MintColors.textSecondary,
          ),
        ),
        Text(
          '$prefix${FiscalService.formatChf(displayAmount)}',
          style: GoogleFonts.montserrat(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
