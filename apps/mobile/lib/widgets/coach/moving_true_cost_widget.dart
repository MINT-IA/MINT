import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  P12-B  Le Vrai coût du déménagement cantonal
//  Charte : L1 (CHF/mois) + L2 (Avant/Après)
//  Source : LIFD art. 1, loi fiscale cantonale
// ────────────────────────────────────────────────────────────

class MovingCostItem {
  const MovingCostItem({
    required this.label,
    required this.emoji,
    required this.monthlyBefore,
    required this.monthlyAfter,
    this.note,
  });

  final String label;
  final String emoji;
  final double monthlyBefore;
  final double monthlyAfter;
  final String? note;
}

class MovingTrueCostWidget extends StatelessWidget {
  const MovingTrueCostWidget({
    super.key,
    required this.fromCanton,
    required this.toCanton,
    required this.items,
    this.movingFees = 3000,
  });

  final String fromCanton;
  final String toCanton;
  final List<MovingCostItem> items;
  final double movingFees;

  double get _totalBefore => items.fold<double>(0, (s, i) => s + i.monthlyBefore);
  double get _totalAfter => items.fold<double>(0, (s, i) => s + i.monthlyAfter);
  double get _netMonthly => _totalBefore - _totalAfter;
  double get _breakEvenMonths => _netMonthly > 0 ? movingFees / _netMonthly : double.infinity;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Vrai coût déménagement cantonal fiscal comparaison mensuelle',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildItemList(),
                  const SizedBox(height: 16),
                  _buildNetResult(),
                  const SizedBox(height: 12),
                  _buildBreakEven(),
                  const SizedBox(height: 16),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.successBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🗺️', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Déménager : le bilan réel',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '$fromCanton → $toCanton',
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildItemList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(flex: 3, child: SizedBox()),
            Expanded(
              flex: 2,
              child: Text(
                fromCanton,
                style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                toCanton,
                style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...items.map((item) {
          final delta = item.monthlyAfter - item.monthlyBefore;
          final isGain = delta < 0;
          final color = delta == 0
              ? MintColors.textSecondary
              : isGain
                  ? MintColors.scoreExcellent
                  : MintColors.scoreCritique;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Row(
                    children: [
                      Text(item.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.label,
                              style: MintTextStyles.labelMedium(color: MintColors.textPrimary),
                            ),
                            if (item.note != null)
                              Text(
                                item.note!,
                                style: MintTextStyles.labelTiny(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatChfWithPrefix(item.monthlyBefore),
                    style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    formatChfWithPrefix(item.monthlyAfter),
                    style: MintTextStyles.labelMedium(color: color).copyWith(fontWeight: FontWeight.w700),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildNetResult() {
    final isGain = _netMonthly > 0;
    final color = isGain ? MintColors.scoreExcellent : MintColors.scoreCritique;
    final sign = _netMonthly > 0 ? '−' : '+';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            isGain ? '✅ Gain net/mois' : '⚠️ Surcoût net/mois',
            style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            '$sign ${formatChfWithPrefix(_netMonthly.abs())}',
            style: MintTextStyles.headlineSmall(color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakEven() {
    if (_netMonthly <= 0 || _breakEvenMonths.isInfinite) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Text('📅', style: TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Frais de déménagement (${formatChfWithPrefix(movingFees)}) remboursés en '
              '${_breakEvenMonths.round()} mois.',
              style: MintTextStyles.labelMedium(color: MintColors.textPrimary).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil fiscal au sens de la LSFin. '
      'Source : LIFD art. 1, législations cantonales. Chiffres indicatifs — varie selon profil.',
      style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
    );
  }
}
