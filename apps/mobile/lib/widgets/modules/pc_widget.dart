import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/modules/pc_module.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';

class PCWidget extends StatefulWidget {
  final double netIncome;
  final double netWealth;
  final double rent;
  final String canton;

  const PCWidget({
    super.key,
    required this.netIncome,
    required this.netWealth,
    required this.rent,
    required this.canton,
  });

  @override
  State<PCWidget> createState() => _PCWidgetState();
}

class _PCWidgetState extends State<PCWidget> {
  // Local state if we want to allow "What if" simulation
  // For now, simple display based on props.

  @override
  Widget build(BuildContext context) {
    final result = PCModule.checkEligibility(
      netIncome: widget.netIncome,
      netWealth: widget.netWealth,
      rent: widget.rent,
      canton: widget.canton,
    );

    // If clearly not eligible, maybe minimal view?
    // But for education, let's show it anyway.

    final isEligible = result.isPotentiallyEligible;

    return SimulatorCard(
      title: "Droits aux Prestations (PC)",
      subtitle: "Checklist d'éligibilité locale",
      icon: Icons.shield_outlined,
      accentColor: isEligible ? MintColors.success : MintColors.textSecondary,
      child: Column(
        children: [
          Row(
            children: [
              _buildMetric("Revenus", widget.netIncome),
              _buildMetric("Fortune", widget.netWealth),
              _buildMetric("Loyer", widget.rent),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isEligible
                  ? MintColors.success.withValues(alpha: 0.1)
                  : MintColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isEligible ? MintColors.success : MintColors.border,
                width: isEligible ? 1 : 0.5,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isEligible ? Icons.check_circle : Icons.info_outline,
                  color: isEligible
                      ? MintColors.success
                      : MintColors.textSecondary,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    isEligible
                        ? "Ta situation suggère un droit potentiel aux PC."
                        : "Tes revenus semblent suffisants selon les barèmes standards.",
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isEligible) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  // Open Link Action
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: Text("Trouver l'office PC (${widget.canton})"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MintColors.success,
                  foregroundColor: MintColors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],
          if (result.disclaimer.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              result.disclaimer,
              style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  fontStyle: FontStyle.italic),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildMetric(String label, double value) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11, color: MintColors.textSecondary)),
          Text(
            "${(value).toInt()}",
            style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: MintColors.textPrimary),
          ),
        ],
      ),
    );
  }
}
