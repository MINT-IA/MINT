import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  HERO COUPLE CARD — P5 / Couple Interactif
// ────────────────────────────────────────────────────────────
//
//  Vue "Nous Deux" : 2 colonnes côte à côte + total ménage.
//  Chaque colonne montre le revenu projeté du partenaire.
//  Le total ménage est en bas, mis en avant.
//
//  Widget pur — aucune dépendance Provider.
//  Aucun terme banni (garanti, certain, optimal, meilleur…).
// ────────────────────────────────────────────────────────────

class HeroCoupleCard extends StatelessWidget {
  /// User's projected monthly retirement income.
  final double userMonthlyIncome;

  /// Conjoint's projected monthly retirement income.
  final double conjointMonthlyIncome;

  /// User's first name.
  final String userName;

  /// Conjoint's first name.
  final String conjointName;

  /// User's replacement ratio (0-100%).
  final double? userReplacementRatio;

  /// Conjoint's replacement ratio (0-100%).
  final double? conjointReplacementRatio;

  /// User's retirement age.
  final int userRetirementAge;

  /// Conjoint's retirement age.
  final int conjointRetirementAge;

  const HeroCoupleCard({
    super.key,
    required this.userMonthlyIncome,
    required this.conjointMonthlyIncome,
    required this.userName,
    required this.conjointName,
    this.userReplacementRatio,
    this.conjointReplacementRatio,
    required this.userRetirementAge,
    required this.conjointRetirementAge,
  });

  double get _householdTotal => userMonthlyIncome + conjointMonthlyIncome;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          _buildPartnerColumns(),
          const SizedBox(height: 16),
          _buildHouseholdTotal(),
          const SizedBox(height: 12),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MintColors.indigo.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.people_outline_rounded,
            color: MintColors.indigo,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nous Deux',
                style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
              ),
              Text(
                'Revenus combin\u00e9s \u00e0 la retraite',
                style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerColumns() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildPartnerColumn(
            name: userName,
            monthlyIncome: userMonthlyIncome,
            replacementRatio: userReplacementRatio,
            retirementAge: userRetirementAge,
            color: MintColors.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildPartnerColumn(
            name: conjointName,
            monthlyIncome: conjointMonthlyIncome,
            replacementRatio: conjointReplacementRatio,
            retirementAge: conjointRetirementAge,
            color: MintColors.purple,
          ),
        ),
      ],
    );
  }

  Widget _buildPartnerColumn({
    required String name,
    required double monthlyIncome,
    required double? replacementRatio,
    required int retirementAge,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  name,
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            formatChfWithPrefix(monthlyIncome),
            style: MintTextStyles.headlineSmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w800, height: 1.0),
          ),
          const SizedBox(height: 2),
          Text(
            'par mois',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 8),
          Text(
            'Retraite \u00e0 $retirementAge ans',
            style: MintTextStyles.labelSmall(color: MintColors.textMuted),
          ),
          if (replacementRatio != null && replacementRatio > 0) ...[
            const SizedBox(height: 4),
            _buildMiniRatioIndicator(replacementRatio, color),
          ],
        ],
      ),
    );
  }

  Widget _buildMiniRatioIndicator(double ratio, Color color) {
    final indicatorColor = ratio >= 70
        ? MintColors.scoreExcellent
        : ratio >= 50
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;

    return Row(
      children: [
        Icon(
          ratio >= 70
              ? Icons.check_circle_outline
              : ratio >= 50
                  ? Icons.info_outline
                  : Icons.warning_amber_outlined,
          size: 12,
          color: indicatorColor,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            '${ratio.toStringAsFixed(0)}\u00a0% remplacement',
            style: MintTextStyles.micro(color: indicatorColor).copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildHouseholdTotal() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.primary.withValues(alpha: 0.06),
            MintColors.primary.withValues(alpha: 0.02),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total m\u00e9nage',
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  formatChfWithPrefix(_householdTotal),
                  style: MintTextStyles.displaySmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w800, height: 1.0),
                ),
                const SizedBox(height: 2),
                Text(
                  'par mois (les deux \u00e0 la retraite)',
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted),
                ),
              ],
            ),
          ),
          Icon(
            Icons.home_outlined,
            size: 28,
            color: MintColors.primary.withValues(alpha: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil \u00e9ducatif simplifi\u00e9. Ne constitue pas un conseil financier (LSFin).',
      style: MintTextStyles.micro(color: MintColors.textMuted),
    );
  }
}
