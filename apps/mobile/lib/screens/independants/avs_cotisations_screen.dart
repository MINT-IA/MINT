import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/independants_service.dart';

// ────────────────────────────────────────────────────────────
//  AVS COTISATIONS SCREEN — Sprint S18 / Independants complet
// ────────────────────────────────────────────────────────────
//
// Barème AVS/AI/APG for self-employed workers.
// Income slider, comparison bar chart vs salarié,
// chiffre choc, gauge showing barème position.
// ────────────────────────────────────────────────────────────

class AvsCotisationsScreen extends StatefulWidget {
  const AvsCotisationsScreen({super.key});

  @override
  State<AvsCotisationsScreen> createState() => _AvsCotisationsScreenState();
}

class _AvsCotisationsScreenState extends State<AvsCotisationsScreen> {
  double _revenuNet = 80000;
  AvsCotisationResult? _result;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = IndependantsService.calculateAvsCotisations(_revenuNet);
    });
  }

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
                _buildIncomeSlider(),
                const SizedBox(height: 24),
                if (_result != null) ...[
                  _buildChiffreChoc(),
                  const SizedBox(height: 24),
                  _buildResultCards(),
                  const SizedBox(height: 24),
                  _buildComparisonChart(),
                  const SizedBox(height: 24),
                  _buildBaremeGauge(),
                  const SizedBox(height: 24),
                  _buildEducation(),
                  const SizedBox(height: 24),
                ],
                _buildDisclaimer(),
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
      expandedHeight: 120,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        title: Text(
          S.of(context)!.avsCotisationsTitle,
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: MintColors.white,
          ),
        ),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.primary.withValues(alpha: 0.85),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader() {
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
              S.of(context)!.avsCotisationsHeaderInfo,
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

  // ── Income Slider ──────────────────────────────────────────

  Widget _buildIncomeSlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.avsCotisationsRevenuNetAnnuel,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            IndependantsService.formatChf(_revenuNet),
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: MintColors.primary,
            ),
          ),
          const SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _revenuNet,
              min: 0,
              max: 250000,
              divisions: 250,
              onChanged: (value) {
                _revenuNet = value;
                _calculate();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.of(context)!.avsCotisationsSliderMin, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text(S.of(context)!.avsCotisationsSliderMax, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Chiffre Choc ───────────────────────────────────────────

  Widget _buildChiffreChoc() {
    final r = _result!;
    if (r.differenceAnnuelle <= 0) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            IndependantsService.formatChf(r.differenceAnnuelle),
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: MintColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context)!.avsCotisationsChiffreChocBody(IndependantsService.formatChf(r.differenceAnnuelle)),
            style: GoogleFonts.inter(
              fontSize: 14,
              color: MintColors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Result Cards ───────────────────────────────────────────

  Widget _buildResultCards() {
    final r = _result!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.avsCotisationsTauxEffectif,
                '${r.tauxEffectif.toStringAsFixed(2)}%',
                Icons.percent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.avsCotisationsCotisationAn,
                IndependantsService.formatChf(r.cotisationAnnuelle),
                Icons.calendar_month_outlined,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.avsCotisationsCotisationMois,
                IndependantsService.formatChf(r.cotisationMensuelle),
                Icons.today_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.avsCotisationsTranche,
                r.tranchLabel,
                Icons.format_list_numbered,
                small: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon,
      {bool small = false}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: MintColors.textMuted),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: small ? 13 : 18,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Comparison Chart ───────────────────────────────────────

  Widget _buildComparisonChart() {
    final r = _result!;
    final maxVal = r.cotisationAnnuelle > r.cotisationSalarie
        ? r.cotisationAnnuelle
        : r.cotisationSalarie;
    if (maxVal <= 0) return const SizedBox.shrink();

    final indepRatio = r.cotisationAnnuelle / maxVal;
    final salarieRatio = r.cotisationSalarie / maxVal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.avsCotisationsComparaisonAnnuelle,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Independant bar
          _buildComparisonBar(
            label: S.of(context)!.avsCotisationsIndependant,
            value: r.cotisationAnnuelle,
            ratio: indepRatio,
            color: MintColors.error,
          ),
          const SizedBox(height: 16),

          // Salarie bar
          _buildComparisonBar(
            label: S.of(context)!.avsCotisationsSalariePartEmployee,
            value: r.cotisationSalarie,
            ratio: salarieRatio,
            color: MintColors.success,
          ),
          const SizedBox(height: 16),

          // Difference
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.error.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.arrow_upward, size: 16, color: MintColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context)!.avsCotisationsSurcout(IndependantsService.formatChf(r.differenceAnnuelle)),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.error,
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

  Widget _buildComparisonBar({
    required String label,
    required double value,
    required double ratio,
    required Color color,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
            ),
            Text(
              IndependantsService.formatChf(value),
              style: GoogleFonts.inter(
                fontSize: 13,
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
            value: ratio.clamp(0.0, 1.0),
            minHeight: 12,
            backgroundColor: MintColors.border.withValues(alpha: 0.3),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ── Barème Gauge ───────────────────────────────────────────

  Widget _buildBaremeGauge() {
    final r = _result!;
    // Position on the barème (0 to 60500+ mapped to 0-1)
    final position = (_revenuNet / 60500).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_outlined, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.avsCotisationsPositionnementBareme,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Gauge
          Stack(
            children: [
              Container(
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: const LinearGradient(
                    colors: [
                      MintColors.centralScenario,
                      MintColors.yellowLight,
                      MintColors.orangeFF,
                      MintColors.redMaterial,
                    ],
                  ),
                ),
              ),
              Positioned(
                left: (MediaQuery.of(context).size.width - 88) * position.clamp(0.02, 0.95),
                top: 0,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: MintColors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: MintColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: MintColors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.of(context)!.avsCotisationsBaremeMin, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text(S.of(context)!.avsCotisationsBaremeMax, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context)!.avsCotisationsTonTauxEffectif(r.tauxEffectif.toStringAsFixed(2)),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  // ── Education ──────────────────────────────────────────────

  Widget _buildEducation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.avsCotisationsBonASavoir,
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
        _buildEduCard(
          Icons.trending_down,
          S.of(context)!.avsCotisationsEduBaremeTitle,
          S.of(context)!.avsCotisationsEduBaremeBody,
        ),
        _buildEduCard(
          Icons.people_outline,
          S.of(context)!.avsCotisationsEduDoubleChargeTitle,
          S.of(context)!.avsCotisationsEduDoubleChargeBody,
        ),
        _buildEduCard(
          Icons.calendar_today_outlined,
          S.of(context)!.avsCotisationsEduCotisationMinTitle,
          S.of(context)!.avsCotisationsEduCotisationMinBody,
        ),
      ],
    );
  }

  Widget _buildEduCard(IconData icon, String title, String body) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.appleSurface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: MintColors.white,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: MintColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.avsCotisationsDisclaimer,
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
}
