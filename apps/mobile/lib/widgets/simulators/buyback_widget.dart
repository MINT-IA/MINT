import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/simulators/buyback_simulator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';

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
    if (widget.totalBuybackPotential <= 0) {
      return const SizedBox.shrink(); // Hide if no potential
    }

    final result = BuybackSimulator.compareStaggering(
      totalBuybackAmount: widget.totalBuybackPotential,
      years: _years,
      taxableIncome: widget.taxableIncome,
      canton: widget.canton,
      civilStatus: widget.civilStatus,
    );

    return SimulatorCard(
      title: "Stratégie Rachat LPP",
      subtitle: "Optimisation par lissage (Staggering)",
      icon: Icons.calendar_view_week,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: Text("Durée du lissage",
                      style: GoogleFonts.inter(fontSize: 14))),
              DropdownButton<int>(
                value: _years,
                items: [2, 3, 4, 5]
                    .map((y) =>
                        DropdownMenuItem(value: y, child: Text("$y ans")))
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
              _buildOption("Moins Optimisé", "En 1 fois",
                  result.singleShotTaxSaving, false),
              const SizedBox(width: 16),
              // Arrow
              const Icon(Icons.arrow_forward,
                  color: MintColors.textMuted, size: 20),
              const SizedBox(width: 16),
              _buildOption("Optimisé", "En $_years fois",
                  result.staggeredTotalTaxSaving, true),
            ],
          ),

          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.trending_up,
                    color: MintColors.success, size: 20),
                const SizedBox(width: 8),
                Text(
                  "Gain estimé: + CHF ${result.delta.toStringAsFixed(0)}",
                  style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: MintColors.success),
                ),
              ],
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
    );
  }

  Widget _buildOption(
      String label, String sublabel, double amount, bool highlight) {
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
                          color: MintColors.primary.withOpacity(0.3),
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
                    "Économie",
                    style: GoogleFonts.inter(
                        fontSize: 10,
                        color:
                            highlight ? Colors.white70 : MintColors.textMuted),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "${(amount / 1000).toStringAsFixed(1)}k",
                    style: GoogleFonts.outfit(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color:
                            highlight ? Colors.white : MintColors.textPrimary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    sublabel,
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        color: highlight
                            ? Colors.white70
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
