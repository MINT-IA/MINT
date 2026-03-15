import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  SMART SHORTCUTS — Raccourcis contextuels vers outils/arbitrages
// ────────────────────────────────────────────────────────────
//
//  Shows max 4 tappable chips linking to the most relevant
//  arbitrage screens, simulators, and tools based on profile.
//
//  Filtering logic:
//    • age > 50          → Rente vs Capital
//    • rachat LPP > 0    → Rachat LPP
//    • no/low 3a         → Simulateur 3a
//    • not homeowner     → Capacité immobilière
//    • couple            → Vue couple
//    • independant       → Outils indépendant
//    • expat             → Analyse expat
//    • always            → Budget, Bilan complet
// ────────────────────────────────────────────────────────────

class SmartShortcuts extends StatelessWidget {
  final CoachProfile profile;
  final double confidenceScore;

  const SmartShortcuts({
    super.key,
    required this.profile,
    required this.confidenceScore,
  });

  @override
  Widget build(BuildContext context) {
    final shortcuts = _computeShortcuts();
    if (shortcuts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header + CTA
        GestureDetector(
          onTap: () => context.push('/coach/cockpit'),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: MintColors.primary.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: MintColors.primary.withValues(alpha: 0.12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.dashboard_outlined,
                    size: 18, color: MintColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Voir ton bilan détaillé',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.primary,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios,
                    size: 14, color: MintColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Shortcut chips (wrap flow)
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: shortcuts.take(4).map((s) => _buildChip(context, s)).toList(),
        ),
      ],
    );
  }

  Widget _buildChip(BuildContext context, _Shortcut s) {
    return GestureDetector(
      onTap: () => context.push(s.route),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: s.color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: s.color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(s.icon, size: 14, color: s.color),
            const SizedBox(width: 6),
            Text(
              s.label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: s.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<_Shortcut> _computeShortcuts() {
    final age = profile.age;
    final isExpat =
        profile.nationality != null && profile.nationality != 'CH';
    final isIndependant = profile.employmentStatus == 'independant';
    final hasLowThreeA = profile.prevoyance.totalEpargne3a < 5000;
    final hasRachat = (profile.prevoyance.rachatMaximum ?? 0) > 0;
    final isNotHomeowner = (profile.patrimoine.immobilier ?? 0) == 0;

    final shortcuts = <_Shortcut>[];

    // Priority 1: Age-driven arbitrages
    if (age > 50) {
      shortcuts.add(_Shortcut(
        label: 'Rente vs Capital',
        icon: Icons.compare_arrows_outlined,
        route: '/rente-vs-capital',
        color: MintColors.purpleDark,
      ));
    }

    // Priority 2: LPP rachat
    if (hasRachat) {
      shortcuts.add(_Shortcut(
        label: 'Rachat LPP',
        icon: Icons.trending_up,
        route: '/rachat-lpp',
        color: MintColors.retirementLpp,
      ));
    }

    // Priority 3: 3a simulator
    if (hasLowThreeA) {
      shortcuts.add(_Shortcut(
        label: 'Simulateur 3a',
        icon: Icons.savings_outlined,
        route: '/pilier-3a',
        color: MintColors.retirement3a,
      ));
    }

    // Priority 4: Mortgage capacity
    if (isNotHomeowner && age < 55) {
      shortcuts.add(_Shortcut(
        label: 'Capacité immobilière',
        icon: Icons.home_outlined,
        route: '/hypotheque',
        color: MintColors.retirementAvs,
      ));
    }

    // Priority 5: Expat tools
    if (isExpat) {
      shortcuts.add(_Shortcut(
        label: 'Analyse expat',
        icon: Icons.flight_land_outlined,
        route: '/expatriation',
        color: MintColors.info,
      ));
    }

    // Priority 6: Self-employed tools
    if (isIndependant) {
      shortcuts.add(_Shortcut(
        label: 'Outils indépendant',
        icon: Icons.business_center_outlined,
        route: '/independants/avs',
        color: MintColors.warning,
      ));
    }

    // Priority 7: Retirement calendar (age > 55)
    if (age > 55) {
      shortcuts.add(_Shortcut(
        label: 'Calendrier retraits',
        icon: Icons.event_outlined,
        route: '/decaissement',
        color: MintColors.urgentOrange,
      ));
    }

    // Always available: Budget
    shortcuts.add(_Shortcut(
      label: 'Budget',
      icon: Icons.pie_chart_outline,
      route: '/budget',
      color: MintColors.textSecondary,
    ));

    // Always available: Education hub
    shortcuts.add(_Shortcut(
      label: 'Comprendre',
      icon: Icons.school_outlined,
      route: '/education/hub',
      color: MintColors.textSecondary,
    ));

    // Always available: Document scan (if low confidence)
    if (confidenceScore < 70) {
      shortcuts.insert(
        shortcuts.length > 2 ? 2 : shortcuts.length,
        _Shortcut(
          label: 'Scanner un document',
          icon: Icons.document_scanner_outlined,
          route: '/scan',
          color: MintColors.primary,
        ),
      );
    }

    return shortcuts;
  }
}

class _Shortcut {
  final String label;
  final IconData icon;
  final String route;
  final Color color;

  const _Shortcut({
    required this.label,
    required this.icon,
    required this.route,
    required this.color,
  });
}
