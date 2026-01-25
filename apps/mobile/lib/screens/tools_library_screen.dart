import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/widgets/modules/pc_widget.dart';
import 'package:mint_mobile/widgets/simulators/buyback_widget.dart';
import 'package:mint_mobile/widgets/simulators/real_interest_widget.dart';
import 'package:mint_mobile/widgets/tools/letter_generator_sheet.dart';

class ToolsLibraryScreen extends StatefulWidget {
  const ToolsLibraryScreen({super.key});

  @override
  State<ToolsLibraryScreen> createState() => _ToolsLibraryScreenState();
}

class _ToolsLibraryScreenState extends State<ToolsLibraryScreen> {
  // Simulation toggle for visualization
  bool _simulateDebt = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text("Outils Avancés",
            style: GoogleFonts.outfit(color: MintColors.textPrimary)),
        backgroundColor: MintColors.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: MintColors.primary),
        actions: [
          // Dev Tool to toggle Safe Mode
          Switch(
            value: _simulateDebt,
            onChanged: (v) => setState(() => _simulateDebt = v),
            activeColor: MintColors.error,
          ),
          const SizedBox(width: 8),
          Center(
              child: Text("Sim. Dette ",
                  style: GoogleFonts.inter(
                      fontSize: 10, color: MintColors.textMuted))),
          const SizedBox(width: 16),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Boîte à Outils",
              style:
                  GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Simulateurs pédagogiques et aides administratives.",
              style: GoogleFonts.inter(color: MintColors.textSecondary),
            ),

            const SizedBox(height: 24),

            // 1. Simulateur Intérêt Réel (Targeted by Safe Mode)
            SafeModeGate(
              hasDebt: _simulateDebt,
              child: const RealInterestWidget(
                initialAmount: 7056,
                marginalTaxRate: 0.25,
              ),
            ),

            // 2. Simulateur Rachat (Targeted by Safe Mode)
            SafeModeGate(
              hasDebt: _simulateDebt,
              child: const BuybackWidget(
                totalBuybackPotential: 50000,
                taxableIncome: 120000,
                canton: 'VD',
                civilStatus: 'single',
              ),
            ),

            // 3. Module PC
            const SizedBox(height: 12),
            const PCWidget(
              netIncome: 3000,
              netWealth: 10000,
              rent: 1400,
              canton: 'VD',
            ),

            const SizedBox(height: 24),

            // 4. Letter Generator Trigger
            Text("Admin",
                style: GoogleFonts.outfit(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) =>
                      const LetterGeneratorSheet(userName: "Utilisateur Test"),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: MintColors.border),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: MintColors.surface,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.print, color: MintColors.primary),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Générateur de Lettres",
                            style: GoogleFonts.outfit(
                                fontWeight: FontWeight.w600)),
                        Text("Modèles PDF (Rachats, Attestations)",
                            style: GoogleFonts.inter(
                                fontSize: 12, color: MintColors.textSecondary)),
                      ],
                    ),
                    const Spacer(),
                    const Icon(Icons.chevron_right,
                        color: MintColors.textMuted),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
