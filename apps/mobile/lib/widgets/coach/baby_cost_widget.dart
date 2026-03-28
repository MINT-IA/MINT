import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P9-A  Le Coût du bonheur — 1'200 CHF/mois × 25 ans
//  Charte : L1 (CHF/mois) + L6 (Chiffre-choc)
//  Source : OFS, données ménages suisses, statistiques familiales
// ────────────────────────────────────────────────────────────

class BabyCostItem {
  const BabyCostItem({
    required this.label,
    required this.emoji,
    required this.monthlyCost,
    this.note,
  });

  final String label;
  final String emoji;
  final double monthlyCost;
  final String? note;
}

class BabyCostWidget extends StatelessWidget {
  const BabyCostWidget({
    super.key,
    required this.items,
    required this.yearsOfDependency,
    this.canton,
  });

  final List<BabyCostItem> items;
  final int yearsOfDependency;
  final String? canton;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final totalMonthly = items.fold<double>(0, (acc, i) => acc + i.monthlyCost);
    final totalLifetime = totalMonthly * 12 * yearsOfDependency;
    // Guard: items.first crasherait si la liste est vide.
    final BabyCostItem? creche = items.isEmpty
        ? null
        : items.firstWhere(
            (i) => i.label.toLowerCase().contains('crèche') || i.label.toLowerCase().contains('garde'),
            orElse: () => items.first,
          );

    return Semantics(
      label: 'Coût bonheur enfant budget mensuel',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s, totalMonthly, totalLifetime),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBreakdown(s),
                  const SizedBox(height: 16),
                  _buildTotalBar(totalMonthly),
                  const SizedBox(height: 16),
                  if (creche != null) ...[
                    _buildCreche(creche),
                    const SizedBox(height: 16),
                  ],
                  _buildDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S s, double totalMonthly, double totalLifetime) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.neutralBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('👶', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.babyCostTitle,
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildHeroStat(
                label: 'Par mois',
                value: 'CHF ${_fmt(totalMonthly)}',
                color: MintColors.primary,
              )),
              const SizedBox(width: 12),
              Expanded(child: _buildHeroStat(
                label: 'Sur $yearsOfDependency ans',
                value: 'CHF ${_fmt(totalLifetime)}',
                color: MintColors.scoreAttention,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroStat({required String label, required String value, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: MintColors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
          Text(
            value,
            style: MintTextStyles.titleMedium(color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdown(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.babyCostBreakdownTitle,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 10),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                    ),
                    if (item.note != null)
                      Text(
                        item.note!,
                        style: MintTextStyles.micro(color: MintColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Text(
                'CHF ${_fmt(item.monthlyCost)}',
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Widget _buildTotalBar(double totalMonthly) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Total / mois',
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            'CHF ${_fmt(totalMonthly)}',
            style: MintTextStyles.titleMedium(color: MintColors.primary).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildCreche(BabyCostItem creche) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'La crèche coûte plus cher que ton loyer.',
                  style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  '${creche.emoji} ${creche.label} : CHF ${_fmt(creche.monthlyCost)}/mois${canton != null ? " à $canton" : ""}.',
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : OFS, statistiques des ménages suisses.',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
