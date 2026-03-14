import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/segments_service.dart';

// ────────────────────────────────────────────────────────────
//  GENDER GAP PREVOYANCE SCREEN — Sprint S12 / Chantier 6
// ────────────────────────────────────────────────────────────
//
// Interactive screen showing the pension gap between current
// activity rate and 100%. Includes taux_activite slider,
// visual comparison, educational content about the
// coordination deduction, and personalised recommendations.
// ────────────────────────────────────────────────────────────

class GenderGapScreen extends StatefulWidget {
  const GenderGapScreen({super.key});

  @override
  State<GenderGapScreen> createState() => _GenderGapScreenState();
}

class _GenderGapScreenState extends State<GenderGapScreen> {
  // ── State ──────────────────────────────────────────────────
  double _tauxActivite = 60;
  final double _revenuAnnuel = 85000;
  final int _age = 40;
  final double _avoirLpp = 120000;
  final int _anneesCotisation = 15;
  final String _canton = 'VD';

  GenderGapResult? _result;

  @override
  void initState() {
    super.initState();
    _compute();
  }

  void _compute() {
    // Scale revenue to match activity rate for the input
    final input = GenderGapInput(
      tauxActivite: _tauxActivite,
      age: _age,
      revenuAnnuel: _revenuAnnuel * (_tauxActivite / 100),
      avoirLpp: _avoirLpp,
      anneesCotisation: _anneesCotisation,
      canton: _canton,
    );
    setState(() {
      _result = GenderGapService.analyse(input: input);
    });
  }

  // ── Build ──────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildHeader(),
                const SizedBox(height: 20),
                _buildIntro(),
                const SizedBox(height: 24),

                // Taux activite slider
                _buildTauxSlider(),
                const SizedBox(height: 24),

                // Input section
                _buildInputSection(),
                const SizedBox(height: 24),

                // Results
                if (_result != null) ...[
                  _buildPensionComparison(),
                  const SizedBox(height: 20),
                  _buildCoordinationExplanation(),
                  const SizedBox(height: 20),
                  _buildOfsStatistic(),
                  const SizedBox(height: 20),
                  _buildRecommendations(),
                  const SizedBox(height: 20),
                ],

                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: 16),

                // Sources
                _buildSourcesFooter(),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        S.of(context)!.genderGapAppBarTitle,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700,
          fontSize: 14,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.successionBg,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.balance,
            color: MintColors.categoryPurple,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                S.of(context)!.genderGapTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                S.of(context)!.genderGapSubtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Intro ──────────────────────────────────────────────────

  Widget _buildIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.genderGapIntroText,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Taux slider ────────────────────────────────────────────

  Widget _buildTauxSlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.genderGapActivityRate,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _tauxActivite < 60
                      ? MintColors.error.withOpacity(0.1)
                      : _tauxActivite < 80
                          ? MintColors.warning.withOpacity(0.1)
                          : MintColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${_tauxActivite.round()}%',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _tauxActivite < 60
                        ? MintColors.error
                        : _tauxActivite < 80
                            ? MintColors.warning
                            : MintColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withOpacity(0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _tauxActivite,
              min: 10,
              max: 100,
              divisions: 18,
              onChanged: (value) {
                _tauxActivite = value;
                _compute();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10%', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text('100%', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Input section ──────────────────────────────────────────

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.genderGapParameters,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildInputRow(S.of(context)!.genderGapGrossAnnualIncome, GenderGapService.formatChf(_revenuAnnuel)),
          const SizedBox(height: 8),
          _buildInputRow(S.of(context)!.genderGapAge, S.of(context)!.genderGapAgeValue(_age)),
          const SizedBox(height: 8),
          _buildInputRow(S.of(context)!.genderGapCurrentLppAssets, GenderGapService.formatChf(_avoirLpp)),
          const SizedBox(height: 8),
          _buildInputRow(S.of(context)!.genderGapContributionYears, '$_anneesCotisation'),
          const SizedBox(height: 8),
          _buildInputRow(S.of(context)!.genderGapCanton, _canton),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: MintColors.neutralBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.science_outlined, color: MintColors.categoryBlue, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context)!.genderGapDemoNotice,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.blueDark,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Pension comparison ─────────────────────────────────────

  Widget _buildPensionComparison() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.genderGapEstimatedLppPension,
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            S.of(context)!.genderGapProjectionYears(result.anneesRestantes),
            style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // Visual bars
          _buildPensionBar(
            label: S.of(context)!.genderGapAt100Pct,
            amount: result.renteAt100Pct,
            maxAmount: result.renteAt100Pct,
            color: MintColors.success,
          ),
          const SizedBox(height: 12),
          _buildPensionBar(
            label: S.of(context)!.genderGapAtTaux(_tauxActivite.round()),
            amount: result.renteAtCurrentTaux,
            maxAmount: result.renteAt100Pct,
            color: _tauxActivite < 60 ? MintColors.error : MintColors.warning,
          ),
          const SizedBox(height: 20),

          // Gap highlight
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.error.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.error.withOpacity(0.2)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      S.of(context)!.genderGapAnnualGap,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MintColors.error,
                      ),
                    ),
                    Text(
                      GenderGapService.formatChf(result.lacuneAnnuelle),
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: MintColors.error,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      S.of(context)!.genderGapTotalGap,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: MintColors.textSecondary,
                      ),
                    ),
                    Text(
                      GenderGapService.formatChf(result.lacuneTotale),
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPensionBar({
    required String label,
    required double amount,
    required double maxAmount,
    required Color color,
  }) {
    final ratio = maxAmount > 0 ? (amount / maxAmount).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
              ),
            ),
            Text(
              S.of(context)!.genderGapPerYear(GenderGapService.formatChf(amount)),
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 12,
            backgroundColor: MintColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Coordination explanation ───────────────────────────────

  Widget _buildCoordinationExplanation() {
    final result = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.school_outlined, color: MintColors.purple, size: 20),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.genderGapCoordinationTitle,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.genderGapCoordinationExplanation,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),

          // Comparison table
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                _buildComparisonRow(
                  S.of(context)!.genderGapGrossSalary100,
                  GenderGapService.formatChf(_revenuAnnuel),
                ),
                const Divider(height: 16),
                _buildComparisonRow(
                  S.of(context)!.genderGapCoordSalary100,
                  GenderGapService.formatChf(result.salaireCoordonne100),
                ),
                const Divider(height: 16),
                _buildComparisonRow(
                  S.of(context)!.genderGapGrossSalaryAtTaux(_tauxActivite.round()),
                  GenderGapService.formatChf(_revenuAnnuel * (_tauxActivite / 100)),
                ),
                const Divider(height: 16),
                _buildComparisonRow(
                  S.of(context)!.genderGapCoordSalaryAtTaux(_tauxActivite.round()),
                  GenderGapService.formatChf(result.salaireCoordonneActuel),
                  highlight: true,
                ),
                const Divider(height: 16),
                _buildComparisonRow(
                  S.of(context)!.genderGapCoordDeductionFixed,
                  GenderGapService.formatChf(result.deductionCoordination),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.genderGapSourceLpp,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(String label, String value, {bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: highlight ? MintColors.error : MintColors.textSecondary,
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: highlight ? MintColors.error : MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── OFS Statistic ──────────────────────────────────────────

  Widget _buildOfsStatistic() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [MintColors.successionBg, MintColors.successionBg.withOpacity(0.5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.bar_chart, color: MintColors.categoryPurple, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.genderGapOfsStatistic,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.purpleDark,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  GenderGapService.statistiqueOfs,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.purpleDark,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Recommendations ────────────────────────────────────────

  Widget _buildRecommendations() {
    final result = _result!;
    if (result.recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.genderGapRecommendations,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...result.recommendations.map((rec) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildRecommendationCard(rec),
        )),
      ],
    );
  }

  Widget _buildRecommendationCard(GenderGapRecommendation rec) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            rec.title,
            style: GoogleFonts.montserrat(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rec.description,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            rec.source,
            style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.genderGapDisclaimer,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.deepOrange,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sources footer ─────────────────────────────────────────

  Widget _buildSourcesFooter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.genderGapSources,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          S.of(context)!.genderGapSourcesDetail,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}
