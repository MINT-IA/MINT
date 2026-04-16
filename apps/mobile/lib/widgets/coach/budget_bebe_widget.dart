import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P9-E  Budget 50/30/20 avec curseur nombre d'enfants
//  Charte : L1 (CHF/mois) + L2 (Avant/Après)
//  Source : OFS statistiques ménages, règle 50/30/20 (épargne)
// ────────────────────────────────────────────────────────────

class BudgetBebeWidget extends StatefulWidget {
  const BudgetBebeWidget({
    super.key,
    required this.monthlyIncome,
    required this.costPerChild,
  });

  final double monthlyIncome;
  final double costPerChild;

  @override
  State<BudgetBebeWidget> createState() => _BudgetBebeWidgetState();
}

class _BudgetBebeWidgetState extends State<BudgetBebeWidget> {
  int _children = 0;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  // 50/30/20 rule: besoins/envies/épargne
  double get _needs => widget.monthlyIncome * 0.50;
  double get _wants => widget.monthlyIncome * 0.30;
  double get _savings => widget.monthlyIncome * 0.20;

  double get _childrenCost => widget.costPerChild * _children;

  // Impact: children cost eats into savings first, then wants
  double get _savingsAfter {
    final remaining = _savings - _childrenCost;
    return remaining > 0 ? remaining : 0;
  }

  double get _wantsAfter {
    final overshoot = _childrenCost - _savings;
    if (overshoot <= 0) return _wants;
    final remaining = _wants - overshoot;
    return remaining > 0 ? remaining : 0;
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Budget 50 30 20 bébé impact mensuel',
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
                  _buildChildrenSlider(),
                  const SizedBox(height: 20),
                  _buildBudgetComparison(),
                  const SizedBox(height: 16),
                  if (_children > 0) _buildImpactAlert(),
                  if (_children > 0) const SizedBox(height: 16),
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
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('🍼', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Budget 50/30/20 avec bébé',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Besoins / Envies / Épargne — avant et après',
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChildrenSlider() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Nombre d\'enfants',
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _children == 0 ? 'Sans enfant' : '$_children enfant${_children > 1 ? 's' : ''}',
                style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        Slider(
          value: _children.toDouble(),
          min: 0,
          max: 3,
          divisions: 3,
          activeColor: MintColors.primary,
          onChanged: (v) => setState(() => _children = v.round()),
        ),
      ],
    );
  }

  Widget _buildBudgetComparison() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Répartition mensuelle',
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _buildBudgetRow(
          label: '🏠 Besoins (50%)',
          before: _needs,
          after: _needs,
          color: MintColors.info,
          note: 'Loyer, nourriture, santé',
        ),
        const SizedBox(height: 8),
        _buildBudgetRow(
          label: '🎭 Envies (30%)',
          before: _wants,
          after: _wantsAfter,
          color: MintColors.scoreAttention,
          note: 'Loisirs, restaurants, voyages',
        ),
        const SizedBox(height: 8),
        _buildBudgetRow(
          label: '💰 Épargne (20%)',
          before: _savings,
          after: _savingsAfter,
          color: MintColors.scoreExcellent,
          note: '3a, LPP rachat, fonds urgence',
        ),
        if (_children > 0) ...[
          const SizedBox(height: 8),
          _buildBudgetRow(
            label: '👶 Enfant${_children > 1 ? 's' : ''}',
            before: 0,
            after: _childrenCost,
            color: MintColors.info,
            note: 'CHF ${_fmt(widget.costPerChild)}/enfant/mois',
            isNew: true,
          ),
        ],
      ],
    );
  }

  Widget _buildBudgetRow({
    required String label,
    required double before,
    required double after,
    required Color color,
    required String note,
    bool isNew = false,
  }) {
    final changed = (before - after).abs() > 1;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      note,
                      style: MintTextStyles.micro(color: MintColors.textSecondary),
                    ),
                  ],
                ),
              ),
              if (isNew || _children == 0) ...[
                Text(
                  'CHF ${_fmt(after)}',
                  style: MintTextStyles.titleMedium(color: color).copyWith(fontWeight: FontWeight.w800),
                ),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (changed && _children > 0) ...[
                      Text(
                        'CHF ${_fmt(before)}',
                        style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(decoration: TextDecoration.lineThrough),
                      ),
                    ],
                    Text(
                      'CHF ${_fmt(after)}',
                      style: MintTextStyles.titleMedium(color: changed && _children > 0 ? MintColors.scoreCritique : color).copyWith(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (_children > 0 && !isNew) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: after / (before > 0 ? before : 1),
                minHeight: 6,
                backgroundColor: color.withValues(alpha: 0.15),
                valueColor: AlwaysStoppedAnimation<Color>(
                  after < before * 0.5 ? MintColors.scoreCritique : color,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildImpactAlert() {
    final savingsLost = _savings - _savingsAfter;
    final isSerious = _savingsAfter < _savings * 0.3;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: (isSerious ? MintColors.scoreCritique : MintColors.scoreAttention)
            .withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: (isSerious ? MintColors.scoreCritique : MintColors.scoreAttention)
              .withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isSerious ? '⚠️' : '💡', style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isSerious
                      ? 'Ton épargne est fortement impactée'
                      : 'Pense à ajuster ton épargne',
                  style: MintTextStyles.bodySmall(color: isSerious ? MintColors.scoreCritique : MintColors.scoreAttention).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  savingsLost > 0
                      ? 'Tes enfants coûtent CHF ${_fmt(_childrenCost)}/mois, '
                        'ce qui réduit ton épargne de CHF ${_fmt(savingsLost)}/mois.'
                      : 'Tes enfants sont financés par tes envies — ton épargne reste intacte.',
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
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
      'Source : OFS statistiques des ménages suisses, règle budgétaire 50/30/20.',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
