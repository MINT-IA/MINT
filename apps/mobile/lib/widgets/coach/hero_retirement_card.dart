import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
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
          _buildHeader(context),
          const SizedBox(height: 20),
          _buildContent(context),
          const SizedBox(height: 16),
          _buildDisclaimer(context),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  HEADER
  // ────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final s = S.of(context)!;
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
                _headerTitle(s),
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                _headerSubtitle(s),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        _buildModeBadge(s),
      ],
    );
  }

  String _headerTitle(S s) {
    switch (mode) {
      case HeroCardMode.full:
        return s.heroRetirementTitleFull;
      case HeroCardMode.range:
        return s.heroRetirementTitleFull;
      case HeroCardMode.educational:
        return s.heroRetirementTitleEducational;
    }
  }

  String _headerSubtitle(S s) {
    switch (mode) {
      case HeroCardMode.full:
        return s.heroRetirementSubtitleFull;
      case HeroCardMode.range:
        return s.heroRetirementSubtitleRange;
      case HeroCardMode.educational:
        return s.heroRetirementSubtitleEducational;
    }
  }

  Widget _buildModeBadge(S s) {
    switch (mode) {
      case HeroCardMode.full:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: MintColors.scoreExcellent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            s.heroRetirementBadgeFull,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MintColors.scoreExcellent,
            ),
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
            s.heroRetirementBadgeRange,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MintColors.scoreAttention,
            ),
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
            s.heroRetirementBadgeEducational,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MintColors.textMuted,
            ),
          ),
        );
    }
  }

  // ────────────────────────────────────────────────────────────
  //  CONTENT PAR MODE
  // ────────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context) {
    final s = S.of(context)!;
    switch (mode) {
      case HeroCardMode.full:
        return _buildFullMode(context, s);
      case HeroCardMode.range:
        return _buildRangeMode(s);
      case HeroCardMode.educational:
        return _buildEducationalMode(context, s);
    }
  }

  /// Mode full : montant precis + avant/apres + taux de remplacement.
  Widget _buildFullMode(BuildContext context, S s) {
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
                  label: s.heroRetirementLabelToday,
                  amount: currentMonthlySalary!,
                  isHighlighted: false,
                  perMonthLabel: s.heroRetirementPerMonth,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  Icons.arrow_forward_rounded,
                  color: MintColors.textMuted,
                  size: 20,
                ),
              ),
              Expanded(
                child: _buildSalaryColumn(
                  label: s.heroRetirementLabelRetirement,
                  amount: income,
                  isHighlighted: true,
                  perMonthLabel: s.heroRetirementPerMonth,
                ),
              ),
            ],
          ),
        ] else ...[
          // Fallback without current salary
          Text(
            formatChfWithPrefix(income),
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            s.heroRetirementPerMonthRetirement,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.textSecondary,
            ),
          ),
        ],
        if (ratio > 0) ...[
          const SizedBox(height: 12),
          _buildReplacementRatioBar(ratio, s),
        ],
        if (rangeMin != null && rangeMax != null) ...[
          const SizedBox(height: 12),
          _buildRangeChip(s),
        ],
      ],
    );
  }

  Widget _buildSalaryColumn({
    required String label,
    required double amount,
    required bool isHighlighted,
    String perMonthLabel = '/mois',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formatChfWithPrefix(amount),
          style: GoogleFonts.montserrat(
            fontSize: isHighlighted ? 28 : 22,
            fontWeight: FontWeight.w800,
            color: isHighlighted ? MintColors.primary : MintColors.textPrimary,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          perMonthLabel,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
          ),
        ),
      ],
    );
  }

  Widget _buildReplacementRatioBar(double ratio, S s) {
    final color = ratio >= 70
        ? MintColors.scoreExcellent
        : ratio >= 50
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;

    // P1-A: Human explanation of replacement ratio
    final explanation = ratio >= 70
        ? s.heroRetirementExplanationComfortable
        : ratio >= 60
            ? s.heroRetirementExplanationSufficient
            : ratio >= 50
                ? s.heroRetirementExplanationTight
                : s.heroRetirementExplanationInsufficient;

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
                      s.heroRetirementReplacementRatio(ratio.toStringAsFixed(0)),
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: color,
                      ),
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
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRangeChip(S s) {
    return Row(
      children: [
        Icon(Icons.unfold_more, size: 14, color: MintColors.textMuted),
        const SizedBox(width: 4),
        Text(
          s.heroRetirementRangeLabel(formatChfWithPrefix(rangeMin!), formatChfWithPrefix(rangeMax!)),
          style: GoogleFonts.inter(
            fontSize: 12,
            color: MintColors.textMuted,
          ),
        ),
      ],
    );
  }

  /// Mode range : fourchette + message d'avertissement.
  Widget _buildRangeMode(S s) {
    final min = rangeMin ?? 0;
    final max = rangeMax ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.heroRetirementBetween,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              formatChfWithPrefix(min),
              style: GoogleFonts.montserrat(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: MintColors.textPrimary,
                height: 1.0,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 3, left: 6, right: 6),
              child: Text(
                s.heroRetirementAnd,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                ),
              ),
            ),
            Text(
              formatChfWithPrefix(max),
              style: GoogleFonts.montserrat(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: MintColors.textPrimary,
                height: 1.0,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          s.heroRetirementPerMonthRetirement,
          style: GoogleFonts.inter(
            fontSize: 14,
            color: MintColors.textSecondary,
          ),
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
              Icon(Icons.info_outline,
                  size: 16, color: MintColors.scoreAttention),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  s.heroRetirementRangeWarning,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Mode educational : aucun chiffre, uniquement des questions et CTA.
  Widget _buildEducationalMode(BuildContext context, S s) {
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
                s.heroRetirementMissingInfo,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.heroRetirementMissingInfoDesc,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuestion(
                  Icons.work_outline, s.heroRetirementQuestionSalary),
              _buildQuestion(
                  Icons.account_balance_outlined, s.heroRetirementQuestionLpp),
              _buildQuestion(Icons.savings_outlined, s.heroRetirementQuestion3a),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onCompleteProfil ??
                () => context.push('/document-scan'),
            icon: const Icon(Icons.edit_outlined, size: 18),
            label: Text(
              s.heroRetirementCompleteProfile,
              style: GoogleFonts.inter(fontWeight: FontWeight.w600),
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
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  DISCLAIMER
  // ────────────────────────────────────────────────────────────

  Widget _buildDisclaimer(BuildContext context) {
    final s = S.of(context)!;
    return Text(
      s.heroRetirementDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textMuted,
        fontStyle: FontStyle.italic,
      ),
    );
  }

}
