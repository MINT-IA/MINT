// Outil educatif — ne constitue pas un conseil financier (LSFin).
// Projection basee sur les donnees declarees. Les rentes AVS/LPP
// sont des estimations (LAVS art. 21-40, LPP art. 14-16).

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// "Futur" panel of the triptyque layout — retirement income projection.
///
/// Shows monthly income projection at retirement (AVS + LPP + 3a SWR +
/// libre passage SWR + market investments SWR), capital summary,
/// replacement rate, confidence score, and uncertainty band.
class FuturProjectionCard extends StatelessWidget {
  final String firstName;
  final String? conjointFirstName;
  final int ageRetraite;
  final int? conjointAgeRetraite;
  final double renteAvsUser;
  final double? renteAvsConjoint;
  final double renteLppUser;
  final double? renteLppConjoint;
  final double capital3aUser;
  final double? capital3aConjoint;
  final double? capitalLibrePassage;
  final double? investissementsMarche;
  final double disposableActuel;
  final double? disposableCouple;
  final double confidenceScore;
  final VoidCallback? onDetailTap;

  const FuturProjectionCard({
    super.key,
    required this.firstName,
    this.conjointFirstName,
    this.ageRetraite = 65,
    this.conjointAgeRetraite,
    required this.renteAvsUser,
    this.renteAvsConjoint,
    required this.renteLppUser,
    this.renteLppConjoint,
    required this.capital3aUser,
    this.capital3aConjoint,
    this.capitalLibrePassage,
    this.investissementsMarche,
    required this.disposableActuel,
    this.disposableCouple,
    required this.confidenceScore,
    this.onDetailTap,
  });

  bool get _isCouple => conjointFirstName != null;

  /// SWR = Safe Withdrawal Rate: 4% annual / 12 = monthly drawdown.
  double _swrMonthly(double capital) => capital * 0.04 / 12;

  double get _totalAvsMonthly =>
      renteAvsUser + (renteAvsConjoint ?? 0);

  double get _totalLppMonthly =>
      renteLppUser + (renteLppConjoint ?? 0);

  double get _total3aCapital =>
      capital3aUser + (capital3aConjoint ?? 0);

  double get _totalCapitalLP => capitalLibrePassage ?? 0;

  double get _totalInvestissements => investissementsMarche ?? 0;

  double get _swr3aMonthly => _swrMonthly(_total3aCapital);

  double get _swrLpMonthly => _swrMonthly(_totalCapitalLP);

  double get _swrInvestMonthly => _swrMonthly(_totalInvestissements);

  double get _totalMonthlyProjected =>
      _totalAvsMonthly +
      _totalLppMonthly +
      _swr3aMonthly +
      _swrLpMonthly +
      _swrInvestMonthly;

  double get _currentReference =>
      disposableCouple ?? disposableActuel;

  double get _tauxRemplacement =>
      _currentReference > 0
          ? (_totalMonthlyProjected / _currentReference) * 100
          : 0;

  double get _totalCapitalRetraite =>
      _total3aCapital + _totalCapitalLP + _totalInvestissements;

  String _fmtChf(double v) => formatChf(v);

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(l),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildKpiRow(l),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildIncomeSection(l),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildCapitalSection(l),
          if (confidenceScore < 70) _buildUncertaintyBand(l),
          _buildFootnote(l),
          if (onDetailTap != null) _buildDetailCta(l),
          if (onDetailTap == null) const SizedBox(height: 8),
        ],
      ),
    );
  }

  // ──────────────── Header ────────────────

  Widget _buildHeader(S l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          const Icon(Icons.timeline, size: 18, color: MintColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              l.futurHorizonTitle,
              style: GoogleFonts.montserrat(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
          ),
          if (_isCouple)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: MintColors.info.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                l.futurCoupleLabel,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: MintColors.info,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ──────────────── KPI Row ────────────────

  Widget _buildKpiRow(S l) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          _kpiCard(
            l.futurTauxRemplacement,
            '${_tauxRemplacement.toStringAsFixed(0)}%',
            _tauxRemplacement >= 60
                ? MintColors.success
                : _tauxRemplacement >= 40
                    ? MintColors.warning
                    : MintColors.error,
          ),
          const SizedBox(width: 8),
          _kpiCard(
            l.futurAgeRetraite,
            '$ageRetraite ans',
            MintColors.info,
          ),
          const SizedBox(width: 8),
          _kpiCard(
            l.futurConfiance,
            '${confidenceScore.toStringAsFixed(0)}%',
            confidenceScore >= 70
                ? MintColors.success
                : confidenceScore >= 40
                    ? MintColors.warning
                    : MintColors.error,
          ),
        ],
      ),
    );
  }

  Widget _kpiCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: color.withAlpha(14),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withAlpha(40)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: MintColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ──────────────── Income Section ────────────────

  Widget _buildIncomeSection(S l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(l.futurRevenuMensuelProjection),
          const SizedBox(height: 8),
          _incomeLine(
            l.futurRenteAvs,
            _totalAvsMonthly,
            MintColors.retirementAvs,
            detail: _isCouple && renteAvsConjoint != null
                ? '${_fmtChf(renteAvsUser)} + ${_fmtChf(renteAvsConjoint!)}'
                : null,
          ),
          _incomeLine(
            l.futurRenteLpp,
            _totalLppMonthly,
            MintColors.retirementLpp,
            detail: _isCouple && renteLppConjoint != null
                ? '${_fmtChf(renteLppUser)} + ${_fmtChf(renteLppConjoint!)}'
                : null,
          ),
          if (_total3aCapital > 0)
            _incomeLine(
              l.futurPilier3aSwr,
              _swr3aMonthly,
              MintColors.retirement3a,
              hint: l.futurCapitalLabel(_fmtChf(_total3aCapital)),
            ),
          if (_totalCapitalLP > 0)
            _incomeLine(
              l.futurLibrePassageSwr,
              _swrLpMonthly,
              MintColors.retirementLibre,
              hint: l.futurCapitalLabel(_fmtChf(_totalCapitalLP)),
            ),
          if (_totalInvestissements > 0)
            _incomeLine(
              l.futurInvestissementsSwr,
              _swrInvestMonthly,
              MintColors.amber,
              hint: l.futurCapitalLabel(_fmtChf(_totalInvestissements)),
            ),
          const SizedBox(height: 4),
          // Hero total line
          _buildHeroTotal(l),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Row(
      children: [
        const Expanded(child: Divider(height: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: MintColors.textMuted,
            ),
          ),
        ),
        const Expanded(child: Divider(height: 1)),
      ],
    );
  }

  Widget _incomeLine(
    String label,
    double monthly,
    Color dotColor, {
    String? detail,
    String? hint,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ),
              Text(
                'CHF ${_fmtChf(monthly)}/mois',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          if (detail != null || hint != null)
            Padding(
              padding: const EdgeInsets.only(left: 16, top: 1),
              child: Text(
                detail ?? hint!,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  fontStyle: hint != null ? FontStyle.italic : FontStyle.normal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroTotal(S l) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.primary.withAlpha(14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.primary.withAlpha(40)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _isCouple
                  ? l.futurTotalCoupleProjecte
                  : l.futurTotalMensuelProjecte,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.primary,
              ),
            ),
          ),
          Text(
            'CHF ${_fmtChf(_totalMonthlyProjected)}/mois',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MintColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Capital Section ────────────────

  Widget _buildCapitalSection(S l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionLabel(l.futurCapitalRetraite),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  l.futurCapitalTotal,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                'CHF ${_fmtChf(_totalCapitalRetraite)}',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 12, color: MintColors.textMuted),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  l.futurCapitalTaxHint,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: MintColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────── Uncertainty Band ────────────────

  Widget _buildUncertaintyBand(S l) {
    final uncertaintyPct = (100 - confidenceScore).clamp(10, 50);
    final low = _totalMonthlyProjected * (1 - uncertaintyPct / 100);
    final high = _totalMonthlyProjected * (1 + uncertaintyPct / 100);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MintColors.warning.withAlpha(14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.warning.withAlpha(40)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              size: 16, color: MintColors.warning),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.futurMargeIncertitude(uncertaintyPct.toStringAsFixed(0)),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: MintColors.warning,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.futurFourchette(_fmtChf(low), _fmtChf(high)),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  l.futurCompleterProfil,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontStyle: FontStyle.italic,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────── Footnote ────────────────

  Widget _buildFootnote(S l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Text(
        l.futurDisclaimer,
        style: GoogleFonts.inter(
          fontSize: 10,
          color: MintColors.textMuted,
          height: 1.3,
        ),
      ),
    );
  }

  // ──────────────── Detail CTA ────────────────

  Widget _buildDetailCta(S l) {
    return Column(
      children: [
        const Divider(height: 1, indent: 16, endIndent: 16),
        InkWell(
          onTap: onDetailTap,
          borderRadius: const BorderRadius.only(
            bottomLeft: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.explore_outlined,
                    size: 16, color: MintColors.info),
                const SizedBox(width: 8),
                Text(
                  l.futurExplorerDetails,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: MintColors.info,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
