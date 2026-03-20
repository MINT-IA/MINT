import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  LPP VS 3A DECISION TREE — P6-F / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Arbre de décision visuel pour LE choix stratégique de
//  l'indépendant·e : LPP volontaire vs Grand 3a.
//
//  Widget pur — aucune dépendance Provider.
//  Lois : L3 (3 niveaux) + L5 (une action)
// ────────────────────────────────────────────────────────────

/// A single option in the decision tree.
class DecisionOption {
  final String title;
  final String emoji;
  final String subtitle;
  final List<String> pros;
  final List<String> cons;
  final double? annualTaxSavings;

  const DecisionOption({
    required this.title,
    required this.emoji,
    required this.subtitle,
    required this.pros,
    required this.cons,
    this.annualTaxSavings,
  });
}

class LppVs3aDecisionTree extends StatefulWidget {
  /// Expected self-employment income.
  final double expectedIncome;

  /// LPP option details.
  final DecisionOption lppOption;

  /// Grand 3a option details.
  final DecisionOption grand3aOption;

  /// Optional callback when user taps "En savoir plus".
  final void Function(String choice)? onLearnMore;

  const LppVs3aDecisionTree({
    super.key,
    required this.expectedIncome,
    required this.lppOption,
    required this.grand3aOption,
    this.onLearnMore,
  });

  @override
  State<LppVs3aDecisionTree> createState() => _LppVs3aDecisionTreeState();
}

class _LppVs3aDecisionTreeState extends State<LppVs3aDecisionTree> {
  int _selectedIndex = -1; // -1 = none, 0 = lpp, 1 = 3a

  /// Seuil pratique: au-dessus de ce revenu, la LPP volontaire devient
  /// compétitive vs Grand 3a seul (salaire coordonné suffisant).
  static const double _lppSeuilVolontaire = 60000.0;

  @override
  Widget build(BuildContext context) {
    final isAboveThreshold = widget.expectedIncome >= _lppSeuilVolontaire;

    return Semantics(
      label: 'Arbre de d\u00e9cision LPP vs 3a. '
          'Revenu\u00a0: ${formatChfWithPrefix(widget.expectedIncome)}.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LPP volontaire ou Grand 3a\u00a0?',
              style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Le choix strat\u00e9gique de l\u2019ind\u00e9pendant\u00b7e',
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontSize: 12),
            ),
            const SizedBox(height: 16),

            // ── Decision node ──
            _buildDecisionNode(isAboveThreshold),
            const SizedBox(height: 12),

            // ── Options ──
            if (isAboveThreshold) ...[
              _buildOptionCard(0, widget.lppOption),
              const SizedBox(height: 10),
              _buildOptionCard(1, widget.grand3aOption),
            ] else
              _buildLowIncomeCard(),

            const SizedBox(height: 12),

            // ── Chiffre-choc ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MintColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: MintColors.primary.withValues(alpha: 0.15)),
              ),
              child: Text(
                'Il n\u2019y a pas de mauvais choix. Mais le bon te fait '
                '\u00e9conomiser 3\u2019000\u20139\u2019000 CHF/an d\u2019imp\u00f4ts.',
                style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
            ),

            const SizedBox(height: 12),
            Text(
              'LPP\u00a0: art. 4 + 44 LPP. 3a\u00a0: OPP3 art. 7. '
              'Outil \u00e9ducatif \u2014 ne constitue pas un conseil financier (LSFin).',
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionNode(bool isAboveThreshold) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Text('\ud83d\udcca', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Revenu attendu\u00a0: ${formatChfWithPrefix(widget.expectedIncome)}/an',
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  isAboveThreshold
                      ? 'Au-dessus du seuil\u00a0: deux options s\u2019offrent \u00e0 toi'
                      : 'Sous ${formatChfWithPrefix(_lppSeuilVolontaire)}\u00a0: le Grand 3a est ton pilier principal',
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionCard(int index, DecisionOption option) {
    final isSelected = _selectedIndex == index;

    return GestureDetector(
      onTap: () => setState(() {
        _selectedIndex = isSelected ? -1 : index;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? MintColors.primary.withValues(alpha: 0.06)
              : MintColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? MintColors.primary.withValues(alpha: 0.3)
                : MintColors.lightBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(option.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    option.title,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Icon(
                  isSelected ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                  color: MintColors.textMuted,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              option.subtitle,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted),
            ),
            if (isSelected) ...[
              const SizedBox(height: 10),
              ...option.pros.map((p) => _buildProCon('\u2705', p)),
              ...option.cons.map((c) => _buildProCon('\u274c', c)),
              if (option.annualTaxSavings != null) ...[
                const SizedBox(height: 6),
                Text(
                  '\u00c9conomie fiscale\u00a0: '
                  '${formatChfWithPrefix(option.annualTaxSavings!)}/an',
                  style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
              if (widget.onLearnMore != null) ...[
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () => widget.onLearnMore!(
                      index == 0 ? 'lpp' : '3a'),
                  child: Text(
                    'En savoir plus \u2192',
                    style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(fontSize: 12, fontWeight: FontWeight.w600, decoration: TextDecoration.underline),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildLowIncomeCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: MintColors.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\ud83c\udfaf', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Grand 3a = ton pilier retraite',
                  style: MintTextStyles.bodyMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Plafond ${formatChfWithPrefix(pilier3aPlafondSansLpp)}/an. Cumule avec l\u2019AVS standard. '
            'Projection\u00a0: 500k\u2013800k \u00e0 65 ans selon rendement.',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildProCon(String icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(icon, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
