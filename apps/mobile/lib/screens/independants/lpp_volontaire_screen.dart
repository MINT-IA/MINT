import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/independants_service.dart';

// ────────────────────────────────────────────────────────────
//  LPP VOLONTAIRE SCREEN — Sprint S18 / Independants complet
// ────────────────────────────────────────────────────────────
//
// Voluntary LPP simulator for self-employed workers.
// Slider: revenu net, age selector.
// Comparison: with vs without LPP volontaire (retirement gap).
// Chiffre choc: lost capitalization without voluntary LPP.
// ────────────────────────────────────────────────────────────

class LppVolontaireScreen extends StatefulWidget {
  const LppVolontaireScreen({super.key});

  @override
  State<LppVolontaireScreen> createState() => _LppVolontaireScreenState();
}

class _LppVolontaireScreenState extends State<LppVolontaireScreen> {
  double _revenuNet = 80000;
  int _age = 40;
  double _tauxMarginal = 0.30;
  LppVolontaireResult? _result;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = IndependantsService.calculateLppVolontaire(
        _revenuNet,
        _age,
        _tauxMarginal,
      );
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
                _buildRevenuSlider(),
                const SizedBox(height: 20),
                _buildAgeSlider(),
                const SizedBox(height: 20),
                _buildTauxSlider(),
                const SizedBox(height: 24),
                if (_result != null) ...[
                  _buildChiffreChoc(),
                  const SizedBox(height: 24),
                  _buildResultCards(),
                  const SizedBox(height: 24),
                  _buildRetirementComparison(),
                  const SizedBox(height: 24),
                  _buildAgeTable(),
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
          'LPP volontaire',
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
              'En tant qu\'indépendant\u00B7e, tu peux t\'affilier '
              'volontairement à une caisse de pension (LPP). Les '
              'cotisations sont entièrement déductibles de ton revenu '
              'imposable, et tu construis ton 2e pilier retraite.',
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

  // ── Sliders ────────────────────────────────────────────────

  Widget _buildRevenuSlider() {
    return _buildSliderCard(
      title: 'Revenu net annuel',
      valueLabel: IndependantsService.formatChf(_revenuNet),
      minLabel: 'CHF 0',
      maxLabel: "CHF 250'000",
      value: _revenuNet,
      min: 0,
      max: 250000,
      divisions: 250,
      onChanged: (v) {
        _revenuNet = v;
        _calculate();
      },
    );
  }

  Widget _buildAgeSlider() {
    return _buildSliderCard(
      title: 'Ton âge',
      valueLabel: '$_age ans',
      minLabel: '25 ans',
      maxLabel: '65 ans',
      value: _age.toDouble(),
      min: 25,
      max: 65,
      divisions: 40,
      onChanged: (v) {
        _age = v.toInt();
        _calculate();
      },
    );
  }

  Widget _buildTauxSlider() {
    return _buildSliderCard(
      title: 'Taux marginal d\'imposition',
      valueLabel: '${(_tauxMarginal * 100).toStringAsFixed(0)}%',
      minLabel: '10%',
      maxLabel: '45%',
      value: _tauxMarginal * 100,
      min: 10,
      max: 45,
      divisions: 35,
      onChanged: (v) {
        _tauxMarginal = v / 100;
        _calculate();
      },
    );
  }

  Widget _buildSliderCard({
    required String title,
    required String valueLabel,
    required String minLabel,
    required String maxLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                valueLabel,
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
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
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text(maxLabel, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Chiffre Choc ───────────────────────────────────────────

  Widget _buildChiffreChoc() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.error,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            IndependantsService.formatChf(r.capitalisationAnnuelle),
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: MintColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sans LPP volontaire, tu perds '
            '${IndependantsService.formatChf(r.capitalisationAnnuelle)}/an '
            'de capitalisation retraite',
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
                'Salaire coordonné',
                IndependantsService.formatChf(r.salaireCoordonne),
                Icons.account_balance_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Taux bonification',
                '${(r.tauxBonification * 100).toStringAsFixed(0)}%',
                Icons.trending_up,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                'Cotisation /an',
                IndependantsService.formatChf(r.cotisationAnnuelle),
                Icons.calendar_month_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                'Économie fiscale /an',
                IndependantsService.formatChf(r.economieFiscale),
                Icons.savings_outlined,
                valueColor: MintColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          'Tranche d\'âge',
          r.ageBracketLabel,
          Icons.person_outline,
          small: true,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon, {
    bool small = false,
    Color? valueColor,
    bool fullWidth = false,
  }) {
    final card = Container(
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
              fontSize: small ? 14 : 18,
              fontWeight: FontWeight.w700,
              color: valueColor ?? MintColors.textPrimary,
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

    return fullWidth ? SizedBox(width: double.infinity, child: card) : card;
  }

  // ── Retirement Comparison ──────────────────────────────────

  Widget _buildRetirementComparison() {
    final r = _result!;
    final maxVal = r.projectionAvecLpp > r.projectionSansLpp
        ? r.projectionAvecLpp
        : r.projectionSansLpp;
    if (maxVal <= 0) return const SizedBox.shrink();

    final sansRatio = r.projectionSansLpp / maxVal;
    final avecRatio = r.projectionAvecLpp / maxVal;
    final gap = r.projectionAvecLpp - r.projectionSansLpp;

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
                'PROJECTION RETRAITE ANNUELLE',
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

          // Sans LPP bar
          _buildProjectionBar(
            label: 'Sans LPP (AVS seule)',
            value: r.projectionSansLpp,
            ratio: sansRatio,
            color: MintColors.error,
          ),
          const SizedBox(height: 16),

          // Avec LPP bar
          _buildProjectionBar(
            label: 'Avec LPP volontaire',
            value: r.projectionAvecLpp,
            ratio: avecRatio,
            color: MintColors.success,
          ),
          const SizedBox(height: 16),

          // Gap highlight
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.add_circle_outline, size: 16, color: MintColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'La LPP volontaire pourrait ajouter '
                    '${IndependantsService.formatChf(gap)}/an '
                    'à ta rente de retraite',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.success,
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

  Widget _buildProjectionBar({
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
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(fontSize: 13, color: MintColors.textSecondary),
              ),
            ),
            Text(
              '${IndependantsService.formatChf(value)}/an',
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
            minHeight: 14,
            backgroundColor: MintColors.border.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
    );
  }

  // ── Age Bonification Table ─────────────────────────────────

  Widget _buildAgeTable() {
    final brackets = [
      ('25-34 ans', '7%', _age >= 25 && _age <= 34),
      ('35-44 ans', '10%', _age >= 35 && _age <= 44),
      ('45-54 ans', '15%', _age >= 45 && _age <= 54),
      ('55-65 ans', '18%', _age >= 55 && _age <= 65),
    ];

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
              const Icon(Icons.table_chart_outlined, size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                'TAUX DE BONIFICATION PAR ÂGE',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...brackets.map((b) => _buildBracketRow(b.$1, b.$2, b.$3)),
        ],
      ),
    );
  }

  Widget _buildBracketRow(String age, String taux, bool isCurrent) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isCurrent ? MintColors.primary.withValues(alpha: 0.06) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: isCurrent
            ? Border.all(color: MintColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              if (isCurrent)
                Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MintColors.primary,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'TOI',
                    style: GoogleFonts.inter(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: MintColors.white,
                    ),
                  ),
                ),
              Text(
                age,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                  color: isCurrent ? MintColors.textPrimary : MintColors.textSecondary,
                ),
              ),
            ],
          ),
          Text(
            taux,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: isCurrent ? MintColors.primary : MintColors.textSecondary,
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
              'BON À SAVOIR',
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
          Icons.account_balance_outlined,
          'Affiliation volontaire',
          'Les indépendant\u00B7e\u00B7s peuvent s\'affilier volontairement '
          'à la LPP via une fondation collective, une caisse de branche '
          'ou la caisse cantonale.',
        ),
        _buildEduCard(
          Icons.savings_outlined,
          'Double avantage fiscal',
          'Les cotisations LPP volontaires sont entièrement déductibles '
          'du revenu imposable. De plus, le capital LPP n\'est pas soumis '
          'à l\'impôt sur la fortune.',
        ),
        _buildEduCard(
          Icons.warning_amber_rounded,
          'Impact sur le 3a',
          'Si tu t\'affilies à une LPP volontaire, ton plafond 3a '
          'passe du "grand 3a" (max CHF 36\'288) au "petit 3a" '
          '(CHF 7\'258). Évalue le trade-off.',
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
          Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les projections de rente sont des estimations basées sur '
              'un rendement projeté de 1.5%/an et un taux de conversion '
              'de 6.8%. Les prestations réelles dépendent de la caisse '
              'de pension choisie et de l\'évolution des marchés. '
              'Consulte un\u00B7e spécialiste en prévoyance.',
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
