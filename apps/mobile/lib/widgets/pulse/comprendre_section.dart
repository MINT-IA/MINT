import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Section "Comprendre" en bas du dashboard Pulse.
///
/// Liens directs vers les simulateurs cles, accessibles
/// sans taper dans le chat. Langage simplifie, 8 mots max.
class ComprendreSection extends StatelessWidget {
  const ComprendreSection({super.key});

  static List<_ComprendreItem> _items(S l) => [
    _ComprendreItem(
      title: l.pulseComprendreRenteCapital,
      subtitle: l.pulseComprendreRenteCapitalSub,
      icon: Icons.compare_arrows,
      route: '/arbitrage/rente-vs-capital',
      color: MintColors.retirementLpp,
    ),
    _ComprendreItem(
      title: l.pulseComprendreRachatLpp,
      subtitle: l.pulseComprendreRachatLppSub,
      icon: Icons.account_balance,
      route: '/lpp-deep/rachat',
      color: MintColors.retirementAvs,
    ),
    _ComprendreItem(
      title: l.pulseComprendre3a,
      subtitle: l.pulseComprendre3aSub,
      icon: Icons.savings,
      route: '/simulator/3a',
      color: MintColors.retirement3a,
    ),
    _ComprendreItem(
      title: l.pulseComprendre_budget,
      subtitle: l.pulseComprendre_budgetSub,
      icon: Icons.pie_chart_outline,
      route: '/budget',
      color: MintColors.info,
    ),
    _ComprendreItem(
      title: l.pulseComprendreAchat,
      subtitle: l.pulseComprendreAchatSub,
      icon: Icons.home_outlined,
      route: '/mortgage/affordability',
      color: MintColors.teal,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final items = _items(l);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.pulseComprendreTitle,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.pulseComprendreSubtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          ...items.map((item) => _buildItem(context, item)),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, _ComprendreItem item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () => context.push(item.route),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: MintColors.lightBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: item.color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(item.icon, size: 18, color: item.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textPrimary,
                        ),
                      ),
                      Text(
                        item.subtitle,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 14,
                  color: MintColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ComprendreItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final String route;
  final Color color;

  const _ComprendreItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.route,
    required this.color,
  });
}
