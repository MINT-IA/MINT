import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/independants_service.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

// ────────────────────────────────────────────────────────────
//  PILLAR 3A INDEPENDANT SCREEN — Sprint S18
// ────────────────────────────────────────────────────────────
//
// Toggle LPP oui/non, slider revenu net, comparison
// "petit 3a" (7258) vs "grand 3a" (up to 36288).
// Chiffre choc: fiscal advantage over salarié.
// ────────────────────────────────────────────────────────────

class Pillar3aIndepScreen extends StatefulWidget {
  const Pillar3aIndepScreen({super.key});

  @override
  State<Pillar3aIndepScreen> createState() => _Pillar3aIndepScreenState();
}

class _Pillar3aIndepScreenState extends State<Pillar3aIndepScreen> {
  double _revenuNet = 100000;
  bool _affilieLpp = false;
  double _tauxMarginal = 0.30;
  Pillar3aIndepResult? _result;

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = IndependantsService.calculate3aIndependant(
        _revenuNet,
        _affilieLpp,
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
                _buildLppToggle(),
                const SizedBox(height: 20),
                _buildRevenuSlider(),
                const SizedBox(height: 20),
                _buildTauxSlider(),
                const SizedBox(height: 24),
                if (_result != null) ...[
                  _buildChiffreChoc(),
                  const SizedBox(height: 24),
                  _buildResultSection(),
                  const SizedBox(height: 24),
                  _buildComparisonBars(),
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
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        title: Text(
          '3e pilier indépendant',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
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
              'En tant qu\'indépendant\u00B7e sans LPP, tu as accès au '
              '"grand 3a" : tu peux déduire jusqu\'à 20% de ton revenu '
              'net (max CHF 36\'288/an), au lieu de CHF 7\'258 pour '
              'un\u00B7e salarié\u00B7e. C\'est un avantage fiscal majeur.',
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

  // ── LPP Toggle ─────────────────────────────────────────────

  Widget _buildLppToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Affilié\u00B7e à une LPP volontaire ?',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _affilieLpp
                      ? 'Plafond 3a : CHF 7\'258 (petit 3a)'
                      : 'Plafond 3a : 20% du revenu, max CHF 36\'288 (grand 3a)',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _affilieLpp,
            onChanged: (v) {
              _affilieLpp = v;
              _calculate();
            },
            activeColor: MintColors.success,
          ),
        ],
      ),
    );
  }

  // ── Revenu Slider ──────────────────────────────────────────

  Widget _buildRevenuSlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
                'Revenu net annuel',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                IndependantsService.formatChf(_revenuNet),
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
              value: _revenuNet,
              min: 0,
              max: 300000,
              divisions: 300,
              onChanged: (v) {
                _revenuNet = v;
                _calculate();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('CHF 0', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text("CHF 300'000", style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Taux Marginal Slider ───────────────────────────────────

  Widget _buildTauxSlider() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
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
                'Taux marginal d\'imposition',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                '${(_tauxMarginal * 100).toStringAsFixed(0)}%',
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
              value: _tauxMarginal * 100,
              min: 10,
              max: 45,
              divisions: 35,
              onChanged: (v) {
                _tauxMarginal = v / 100;
                _calculate();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('10%', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text('45%', style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Chiffre Choc ───────────────────────────────────────────

  Widget _buildChiffreChoc() {
    final r = _result!;
    if (r.avantageSurSalarie <= 0) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: MintColors.appleSurface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          children: [
            Text(
              IndependantsService.formatChf(r.economieFiscale),
              style: GoogleFonts.montserrat(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: MintColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'd\'économie fiscale annuelle grâce au 3e pilier',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.success,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            IndependantsService.formatChf(r.avantageSurSalarie),
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tu économises ${IndependantsService.formatChf(r.avantageSurSalarie)}/an '
            'd\'impôts de plus qu\'un\u00B7e salarié\u00B7e grâce au grand 3a',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Result Section ─────────────────────────────────────────

  Widget _buildResultSection() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          _buildResultRow('Plafond applicable', IndependantsService.formatChf(r.plafond)),
          const SizedBox(height: 12),
          _buildResultRow('Économie fiscale /an', IndependantsService.formatChf(r.economieFiscale)),
          const Divider(height: 24),
          _buildResultRow(
            'Plafond salarié\u00B7e',
            IndependantsService.formatChf(r.plafondSalarie),
            color: MintColors.textMuted,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            'Économie salarié\u00B7e',
            IndependantsService.formatChf(r.economieSalarie),
            color: MintColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 14, color: color ?? MintColors.textSecondary),
        ),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color ?? MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── Comparison Stacked Bars ────────────────────────────────

  Widget _buildComparisonBars() {
    final r = _result!;
    final petit = pilier3aPlafondAvecLpp;
    final grand = pilier3aPlafondSansLpp;
    final plafondIndep = r.plafond;
    final multiplier = (plafondIndep / petit).round();

    // 20-year projection at 4% compound interest
    final proj20Indep = plafondIndep * ((math.pow(1.04, 20) - 1) / 0.04);
    final proj20Salarie = petit * ((math.pow(1.04, 20) - 1) / 0.04);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header with ×5 badge (P6-E / S42) ──
          Row(
            children: [
              Expanded(
                child: Text(
                  'PLAFONDS COMPAR\u00c9S',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textMuted,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (!_affilieLpp)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: MintColors.success,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '\u00d7$multiplier ton super-pouvoir',
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Salarie bar
          _buildPlafondBar(
            label: 'Salari\u00e9\u00B7e',
            value: petit,
            maxValue: grand,
            color: MintColors.info,
          ),
          const SizedBox(height: 16),

          // Independant bar
          _buildPlafondBar(
            label: 'Ind\u00e9pendant\u00B7e (toi)',
            value: plafondIndep,
            maxValue: grand,
            color: MintColors.success,
            highlight: true,
          ),
          const SizedBox(height: 16),

          // Max bar
          _buildPlafondBar(
            label: 'Grand 3a (max l\u00e9gal)',
            value: grand,
            maxValue: grand,
            color: MintColors.textMuted.withValues(alpha: 0.3),
          ),

          // ── 20-year projection (P6-E chiffre-choc) ──
          if (!_affilieLpp) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.success.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: MintColors.success.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Text(
                    'En 20 ans \u00e0 4%',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: MintColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildProjectionColumn(
                          'Salari\u00e9\u00b7e', proj20Salarie, MintColors.info),
                      Text(
                        'vs',
                        style: GoogleFonts.inter(
                            fontSize: 14, color: MintColors.textMuted),
                      ),
                      _buildProjectionColumn(
                          'Toi', proj20Indep, MintColors.success),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Diff\u00e9rence\u00a0: +${IndependantsService.formatChf(proj20Indep - proj20Salarie)}',
                    style: GoogleFonts.montserrat(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: MintColors.success,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProjectionColumn(String label, double amount, Color color) {
    final millions = amount >= 1000000;
    final display = millions
        ? '${(amount / 1000000).toStringAsFixed(2)}M'
        : '${(amount / 1000).toStringAsFixed(0)}k';
    return Column(
      children: [
        Text(
          'CHF\u00a0$display',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted),
        ),
      ],
    );
  }

  Widget _buildPlafondBar({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
    bool highlight = false,
  }) {
    final ratio = (value / maxValue).clamp(0.0, 1.0);
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
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
                color: highlight ? MintColors.textPrimary : MintColors.textSecondary,
              ),
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
            value: ratio,
            minHeight: highlight ? 14 : 10,
            backgroundColor: MintColors.border.withValues(alpha: 0.2),
            valueColor: AlwaysStoppedAnimation(color),
          ),
        ),
      ],
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
          Icons.layers_outlined,
          'Ouvre plusieurs comptes 3a',
          'Même avec le grand 3a, la stratégie des comptes '
          'multiples (jusqu\'à 5) est recommandée pour optimiser '
          'le retrait échelonné à la retraite.',
        ),
        _buildEduCard(
          Icons.warning_amber_rounded,
          'Condition : pas de LPP',
          'Le grand 3a (20% du revenu, max 36\'288) n\'est '
          'accessible que si tu n\'es pas affilié\u00B7e à une '
          'LPP volontaire. Avec LPP, le plafond tombe à 7\'258.',
        ),
        _buildEduCard(
          Icons.trending_up,
          'Investir plutôt qu\'épargner',
          'Pour un horizon long (>10 ans), un 3a investi en '
          'actions peut offrir un rendement bien supérieur à un '
          'compte d\'épargne 3a classique.',
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
                color: Colors.white,
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
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Les économies fiscales sont calculées sur la base du '
              'taux marginal indiqué. Le taux réel dépend de ton '
              'canton, de ta commune et de ta situation familiale. '
              'Consulte un\u00B7e spécialiste pour un calcul personnalisé.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
