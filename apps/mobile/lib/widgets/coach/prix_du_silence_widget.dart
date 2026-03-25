import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P8-B  Le Prix du silence — Concubin vs Marié·e
//  Charte : L1 (CHF/mois) + L2 (Avant/Après)
//  Source : CC art. 462, LHID impôt succession cantonal
// ────────────────────────────────────────────────────────────

class PrixDuSilenceWidget extends StatelessWidget {
  const PrixDuSilenceWidget({
    super.key,
    required this.patrimoine,
    required this.marriedTaxRate,
    required this.concubinTaxRate,
  });

  final double patrimoine;
  final double marriedTaxRate;   // typically 0%
  final double concubinTaxRate;  // typically 24%

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
    final marriedTax = patrimoine * marriedTaxRate / 100;
    final concubinTax = patrimoine * concubinTaxRate / 100;
    final silence = concubinTax - marriedTax;
    const testamentCost = 500.0;

    return Semantics(
      label: 'Prix du silence succession concubin marié comparaison',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(silence),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPatrimoineChip(),
                  const SizedBox(height: 20),
                  _buildComparisonRow('Marié·e', marriedTax, MintColors.scoreExcellent, '💍'),
                  const SizedBox(height: 12),
                  _buildComparisonRow('Concubin·e', concubinTax, MintColors.scoreCritique, '🏠'),
                  const SizedBox(height: 16),
                  _buildSilenceImpact(silence, testamentCost),
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

  Widget _buildHeader(double silence) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.pinkBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🤫', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le prix du silence',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Ce que ton statut marital coûte — ou économise — à ta succession.',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildPatrimoineChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_outlined, color: MintColors.info, size: 18),
          const SizedBox(width: 10),
          Flexible(child: Text(
            'Patrimoine transmis : CHF ${_fmt(patrimoine)}',
            style: MintTextStyles.bodyMedium(color: MintColors.info).copyWith(fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          )),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, double tax, Color color, String emoji) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'Impôt succession : ${tax == 0 ? "0" : _fmt(tax)} CHF',
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            tax == 0 ? '0 CHF' : '-CHF ${_fmt(tax)}',
            style: MintTextStyles.headlineMedium(color: color).copyWith(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildSilenceImpact(double silence, double testamentCost) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💡 Le silence te coûte CHF ${_fmt(silence)}',
            style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Un testament coûte ~CHF ${_fmt(testamentCost)}. '
            'La différence : CHF ${_fmt(silence - testamentCost)}.',
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            '→ Action : Prends rendez-vous chez un·e notaire.',
            style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : CC art. 462, LHID. Taux varient selon canton et lien de parenté.',
      style: MintTextStyles.micro(color: MintColors.textSecondary).copyWith(fontStyle: FontStyle.normal),
    );
  }
}
