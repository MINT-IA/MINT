import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  HERO RETIREMENT CARD — LOT 4 / Retirement Dashboard
// ────────────────────────────────────────────────────────────
//
//  Carte principale affichant le revenu de retraite projete.
//  3 modes selon le score de confiance :
//
//  full       (>= 70%) — Montant precis + taux de remplacement
//  range      (40-69%) — Fourchette min/max + avertissement
//  educational(< 40%)  — Aucun chiffre, CTA profil uniquement
//
//  Widget pur — aucune dependance Provider.
//  Aucun terme banni (garanti, certain, optimal…).
// ────────────────────────────────────────────────────────────

/// Mode d'affichage de la carte hero.
enum HeroCardMode {
  /// Projection fiable — montant precis affiche.
  full,

  /// Projection partielle — fourchette affichee.
  range,

  /// Donnees insuffisantes — aucun chiffre, CTA uniquement.
  educational,
}

class HeroRetirementCard extends StatelessWidget {
  final HeroCardMode mode;

  // Mode full
  final double? monthlyIncome;
  final double? replacementRatio; // 0-100 (%)
  final double? rangeMin;
  final double? rangeMax;

  /// Current gross monthly salary (for before/after comparison — P1-A).
  final double? currentMonthlySalary;

  // Mode educational
  final VoidCallback? onCompleteProfil;

  const HeroRetirementCard({
    super.key,
    required this.mode,
    this.monthlyIncome,
    this.replacementRatio,
    this.rangeMin,
    this.rangeMax,
    this.currentMonthlySalary,
    this.onCompleteProfil,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
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
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildContent(context),
          const SizedBox(height: 16),
          _buildDisclaimer(),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  HEADER
  // ────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: MintColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.account_balance_outlined,
            color: MintColors.primary,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _headerTitle,
                style: MintTextStyles.titleMedium(color: MintColors.textPrimary),
              ),
              Text(
                _headerSubtitle,
                style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
              ),
            ],
          ),
        ),
        _buildModeBadge(),
      ],
    );
  }

  String get _headerTitle {
    switch (mode) {
      case HeroCardMode.full:
        return 'Ton salaire apr\u00e8s 65 ans';
      case HeroCardMode.range:
        return 'Ton salaire apr\u00e8s 65 ans';
      case HeroCardMode.educational:
        return 'Projection retraite';
    }
  }

  String get _headerSubtitle {
    switch (mode) {
      case HeroCardMode.full:
        return 'AVS + LPP + \u00e9pargne';
      case HeroCardMode.range:
        return 'Estimation avec incertitude';
      case HeroCardMode.educational:
        return 'Profil incomplet';
    }
  }

  Widget _buildModeBadge() {
    switch (mode) {
      case HeroCardMode.full:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: MintColors.scoreExcellent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Fiable',
            style: MintTextStyles.labelSmall(color: MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w600),
          ),
        );
      case HeroCardMode.range:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: MintColors.scoreAttention.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Estimation',
            style: MintTextStyles.labelSmall(color: MintColors.scoreAttention).copyWith(fontWeight: FontWeight.w600),
          ),
        );
      case HeroCardMode.educational:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'A compl\u00e9ter',
            style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600),
          ),
        );
    }
  }

  // ────────────────────────────────────────────────────────────
  //  CONTENT PAR MODE
  // ────────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context) {
    switch (mode) {
      case HeroCardMode.full:
        return _buildFullMode();
      case HeroCardMode.range:
        return _buildRangeMode();
      case HeroCardMode.educational:
        return _buildEducationalMode(context);
    }
  }

  /// Mode full : montant precis + avant/apres + taux de remplacement.
  Widget _buildFullMode() {
    final income = monthlyIncome ?? 0;
    final ratio = replacementRatio ?? 0;
    final hasSalary = currentMonthlySalary != null && currentMonthlySalary! > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Before/After comparison (P1-A) ──
        if (hasSalary) ...[
          Row(
            children: [
              Expanded(
                child: _buildSalaryColumn(
                  label: "Aujourd'hui",
                  amount: currentMonthlySalary!,
                  isHighlighted: false,
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: MintColors.textMuted,
                  size: 20,
                ),
              ),
              Expanded(
                child: _buildSalaryColumn(
                  label: '\u00c0 la retraite',
                  amount: income,
                  isHighlighted: true,
                ),
              ),
            ],
          ),
        ] else ...[
          // Fallback without current salary
          Text(
            formatChfWithPrefix(income),
            style: MintTextStyles.displayMedium(color: MintColors.textPrimary).copyWith(fontSize: 36, fontWeight: FontWeight.w800, height: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            'par mois \u00e0 la retraite',
            style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
          ),
        ],
        if (ratio > 0) ...[
          const SizedBox(height: 12),
          _buildReplacementRatioBar(ratio),
        ],
        if (rangeMin != null && rangeMax != null) ...[
          const SizedBox(height: 12),
          _buildRangeChip(),
        ],
      ],
    );
  }

  Widget _buildSalaryColumn({
    required String label,
    required double amount,
    required bool isHighlighted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          formatChfWithPrefix(amount),
          style: MintTextStyles.displayMedium(color: isHighlighted ? MintColors.primary : MintColors.textPrimary).copyWith(fontSize: isHighlighted ? 28 : 22, fontWeight: FontWeight.w800, height: 1.0),
        ),
        const SizedBox(height: 2),
        Text(
          '/mois',
          style: MintTextStyles.labelSmall(color: MintColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildReplacementRatioBar(double ratio) {
    final color = ratio >= 70
        ? MintColors.scoreExcellent
        : ratio >= 50
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;

    // P1-A: Human explanation of replacement ratio
    final explanation = ratio >= 70
        ? 'Confortable \u2014 tu gardes ton train de vie'
        : ratio >= 60
            ? 'Suffisant pour la plupart des m\u00e9nages (charges r\u00e9duites \u00e0 la retraite)'
            : ratio >= 50
                ? 'Serr\u00e9 \u2014 des ajustements seront n\u00e9cessaires'
                : 'Insuffisant \u2014 agis maintenant pour am\u00e9liorer ta situation';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
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
                      'Tu garderas ${ratio.toStringAsFixed(0)}% de ton train de vie',
                      style: MintTextStyles.bodyMedium(color: color).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Icon(
                ratio >= 70
                    ? Icons.check_circle_outline
                    : ratio >= 50
                        ? Icons.info_outline
                        : Icons.warning_amber_outlined,
                color: color,
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeChip() {
    return Row(
      children: [
        const Icon(Icons.unfold_more, size: 14, color: MintColors.textMuted),
        const SizedBox(width: 4),
        Text(
          'Fourchette\u00a0: ${formatChfWithPrefix(rangeMin!)} \u2013 ${formatChfWithPrefix(rangeMax!)} / mois',
          style: MintTextStyles.labelMedium(color: MintColors.textMuted),
        ),
      ],
    );
  }

  /// Mode range : fourchette + message d'avertissement.
  Widget _buildRangeMode() {
    final min = rangeMin ?? 0;
    final max = rangeMax ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Entre',
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatChfWithPrefix(min),
              style: MintTextStyles.displaySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w800, height: 1.0),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3, left: 6, right: 6),
              child: Text(
                'et',
                style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
              ),
            ),
            Text(
              formatChfWithPrefix(max),
              style: MintTextStyles.displaySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w800, height: 1.0),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'par mois \u00e0 la retraite',
          style: MintTextStyles.bodyMedium(color: MintColors.textSecondary),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: MintColors.scoreAttention.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
                color: MintColors.scoreAttention.withValues(alpha: 0.25)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: MintColors.scoreAttention),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'La fourchette se r\u00e9duira en ajoutant tes donn\u00e9es LPP et AVS.',
                  style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Mode educational : aucun chiffre, uniquement des questions et CTA.
  Widget _buildEducationalMode(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Il nous manque des informations',
                style: MintTextStyles.labelLarge(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Pour estimer ton revenu de retraite, quelques questions suffisent\u00a0:',
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(height: 1.4),
              ),
              const SizedBox(height: 12),
              _buildQuestion(
                  Icons.work_outline, 'Ton salaire et statut professionnel'),
              _buildQuestion(
                  Icons.account_balance_outlined, 'Ton avoir LPP'),
              _buildQuestion(Icons.savings_outlined, 'Ton \u00e9pargne 3e pilier'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCompleteProfil ??
                () => context.push('/scan'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              'Compl\u00e9ter mon profil',
              style: MintTextStyles.bodySmall(color: MintColors.white).copyWith(fontWeight: FontWeight.w600),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              foregroundColor: MintColors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestion(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: MintColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  DISCLAIMER
  // ────────────────────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Text(
      'Outil \u00e9ducatif simplifi\u00e9. Ne constitue pas un conseil financier (LSFin).',
      style: MintTextStyles.micro(color: MintColors.textMuted),
    );
  }

}
