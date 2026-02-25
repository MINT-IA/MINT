import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/retirement_service.dart';

// ────────────────────────────────────────────────────────────
//  AVS SCENARIO CARD — Sprint S21
// ────────────────────────────────────────────────────────────
//
// Visual card showing one AVS retirement scenario:
//   - Scenario name + icon
//   - Monthly rente (large number)
//   - Penalty/bonus percentage (red/green)
//   - "a vie" duration indicator
// ────────────────────────────────────────────────────────────

class AvsScenarioCard extends StatelessWidget {
  final String scenario; // "anticipation", "normal", "ajournement"
  final double renteMensuelle;
  final double penalitePct;
  final bool isSelected;
  final VoidCallback? onTap;

  const AvsScenarioCard({
    super.key,
    required this.scenario,
    required this.renteMensuelle,
    required this.penalitePct,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final config = _scenarioConfig;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isSelected ? config.color.withValues(alpha: 0.06) : Colors.white,
          borderRadius: const Borderconst Radius.circular(16),
          border: Border.all(
            color: isSelected ? config.color : MintColors.lightBorder,
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: config.color.withValues(alpha: 0.12),
                borderRadius: const Borderconst Radius.circular(8),
              ),
              child: Icon(
                config.icon,
                size: 16,
                color: config.color,
              ),
            ),
            const SizedBox(height: 6),
            // Label — FittedBox prevents overflow on small screens
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                config.label,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Monthly rente (large number) — FittedBox prevents overflow
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                RetirementService.formatChf(renteMensuelle),
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: config.color,
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'par mois',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textMuted,
              ),
            ),
            const SizedBox(height: 10),

            // Penalty/bonus badge — epsilon for float safety, if/else for correctness
            if (penalitePct.abs() < 0.01)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: MintColors.info.withValues(alpha: 0.1),
                  borderRadius: const Borderconst Radius.circular(6),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    'Référence',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MintColors.info,
                    ),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: penalitePct < 0
                      ? MintColors.error.withValues(alpha: 0.1)
                      : MintColors.success.withValues(alpha: 0.1),
                  borderRadius: const Borderconst Radius.circular(6),
                ),
                child: Text(
                  '${penalitePct > 0 ? '+' : ''}${penalitePct.toStringAsFixed(1)}%',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: penalitePct < 0
                        ? MintColors.error
                        : MintColors.success,
                  ),
                ),
              ),
            const SizedBox(height: 10),

            // Duration badge
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.all_inclusive,
                  size: 14,
                  color: MintColors.textMuted,
                ),
                const SizedBox(width: 4),
                Text(
                  'à vie',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  _ScenarioConfig get _scenarioConfig {
    switch (scenario) {
      case 'anticipation':
        return _ScenarioConfig(
          label: 'Anticipation',
          icon: Icons.fast_rewind,
          color: MintColors.error,
        );
      case 'ajournement':
        return _ScenarioConfig(
          label: 'Ajournement',
          icon: Icons.fast_forward,
          color: MintColors.info,
        );
      case 'normal':
        return _ScenarioConfig(
          label: 'Normal (65 ans)',
          icon: Icons.check_circle_outline,
          color: MintColors.success,
        );
      default:
        assert(false, 'Unknown AVS scenario: $scenario');
        return _ScenarioConfig(
          label: 'Normal (65 ans)',
          icon: Icons.check_circle_outline,
          color: MintColors.success,
        );
    }
  }
}

class _ScenarioConfig {
  final String label;
  final IconData icon;
  final Color color;

  const _ScenarioConfig({
    required this.label,
    required this.icon,
    required this.color,
  });
}
