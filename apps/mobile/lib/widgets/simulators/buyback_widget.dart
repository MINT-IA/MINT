import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/simulators/buyback_simulator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:provider/provider.dart';

class BuybackWidget extends StatefulWidget {
  final double totalBuybackPotential;
  final double taxableIncome;
  final String canton;
  final String civilStatus;

  const BuybackWidget({
    super.key,
    required this.totalBuybackPotential,
    required this.taxableIncome,
    required this.canton,
    required this.civilStatus,
  });

  @override
  State<BuybackWidget> createState() => _BuybackWidgetState();
}

class _BuybackWidgetState extends State<BuybackWidget> {
  int _years = 3;

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    if (widget.totalBuybackPotential <= 0) {
      return const SizedBox.shrink(); // Hide if no potential
    }

    final hasDebt = context.watch<ProfileProvider>().profile?.hasDebt ?? false;

    final result = BuybackSimulator.compareStaggering(
      totalBuybackAmount: widget.totalBuybackPotential,
      years: _years,
      taxableIncome: widget.taxableIncome,
      canton: widget.canton,
      civilStatus: widget.civilStatus,
    );

    return SafeModeGate(
      hasDebt: hasDebt,
      lockedTitle: l.simBuybackLockedTitle,
      lockedMessage: l.simBuybackLockedMessage,
      child: SimulatorCard(
      title: l.simBuybackTitle,
      subtitle: l.simBuybackSubtitle,
      icon: Icons.calendar_view_week,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(l.simBuybackDuration,
                      style: GoogleFonts.inter(fontSize: 14))),
              DropdownButton<int>(
                value: _years,
                items: [2, 3, 4, 5]
                    .map((y) =>
                        DropdownMenuItem(value: y, child: Text(l.simBuybackYears(y))))
                    .toList(),
                onChanged: (v) => setState(() => _years = v!),
                underline: Container(), // clean look
                style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: MintColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Comparison
          Row(
            children: [
              _buildOption(l.simBuybackLessOptimized, l.simBuybackSingleShot,
                  result.singleShotTaxSaving, false),
              const SizedBox(width: 16),
              // Arrow
              const Icon(Icons.arrow_forward,
                  color: MintColors.textMuted, size: 20),
              const SizedBox(width: 16),
              _buildOption(l.simBuybackOptimized, l.simBuybackInNTimes(_years),
                  result.staggeredTotalTaxSaving, true),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.trending_up,
                    color: MintColors.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  l.simBuybackEstimatedGain(result.delta.toStringAsFixed(0)),
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: MintColors.success),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Educational tooltip for taux marginal
          Semantics(
            label: 'Information sur le taux marginal',
            button: true,
            child: GestureDetector(
              onTap: () => _showTauxMarginalInfo(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: MintColors.info.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline,
                      color: MintColors.info, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.simBuybackMarginalRateQuestion,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.info,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: MintColors.info, size: 16),
                ],
              ),
            ),
          ),
          ),

          const SizedBox(height: 12),
          Text(
            result.disclaimer,
            style: GoogleFonts.inter(
                fontSize: 10, color: MintColors.textMuted, height: 1.2),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
      ),
    );
  }

  void _showTauxMarginalInfo(BuildContext context) {
    final l = S.of(context)!;
    showModalBottomSheet(
      context: context,
      backgroundColor: MintColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: MintColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                l.simBuybackMarginalRateTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: MintColors.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l.simBuybackMarginalRateExplanation,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  color: MintColors.textPrimary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: MintColors.accentPastel,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline,
                        color: MintColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        l.simBuybackMarginalRateTip,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: MintColors.primary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption(
      String label, String sublabel, double amount, bool highlight) {
    final l = S.of(context)!;
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, color: MintColors.textSecondary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: highlight ? MintColors.primary : MintColors.surface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: highlight
                  ? [
                      BoxShadow(
                          color: MintColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 4))
                    ]
                  : [],
            ),
            child: Center(
              // Center content
              child: Column(
                children: [
                  Text(
                    l.simBuybackSavingsLabel,
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color:
                            highlight ? MintColors.white70 : MintColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${(amount / 1000).toStringAsFixed(1)}k",
                    style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            highlight ? MintColors.white : MintColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sublabel,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: highlight
                            ? MintColors.white70
                            : MintColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
