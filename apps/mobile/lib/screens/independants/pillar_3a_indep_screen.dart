import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/independants_service.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

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
        icon: const Icon(Icons.arrow_back, color: MintColors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 56, bottom: 16, right: 16),
        title: Text(
          S.of(context)!.pillar3aIndepTitle,
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
              S.of(context)!.pillar3aIndepHeaderInfo,
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
        color: MintColors.white,
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
                  S.of(context)!.pillar3aIndepLppToggle,
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _affilieLpp
                      ? S.of(context)!.pillar3aIndepPlafondWithLpp
                      : S.of(context)!.pillar3aIndepPlafondWithoutLpp,
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
            activeThumbColor: MintColors.success,
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
                S.of(context)!.pillar3aIndepRevenuNet,
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
              Text(S.of(context)!.pillar3aIndepChf0, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text(S.of(context)!.pillar3aIndepChf300k, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
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
                S.of(context)!.pillar3aIndepTauxMarginal,
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
              Text(S.of(context)!.pillar3aIndepTaux10, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
              Text(S.of(context)!.pillar3aIndepTaux45, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textMuted)),
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
              S.of(context)!.pillar3aIndepEconomieFiscale,
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
              color: MintColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context)!.pillar3aIndepChiffreChoc(IndependantsService.formatChf(r.avantageSurSalarie)),
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

  // ── Result Section ─────────────────────────────────────────

  Widget _buildResultSection() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          _buildResultRow(S.of(context)!.pillar3aIndepPlafondApplicable, IndependantsService.formatChf(r.plafond)),
          const SizedBox(height: 12),
          _buildResultRow(S.of(context)!.pillar3aIndepEconomieFiscaleAn, IndependantsService.formatChf(r.economieFiscale)),
          const Divider(height: 24),
          _buildResultRow(
            S.of(context)!.pillar3aIndepPlafondSalarie,
            IndependantsService.formatChf(r.plafondSalarie),
            color: MintColors.textMuted,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            S.of(context)!.pillar3aIndepEconomieSalarie,
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
    const petit = pilier3aPlafondAvecLpp;
    const grand = pilier3aPlafondSansLpp;
    final plafondIndep = r.plafond;
    final multiplier = (plafondIndep / petit).round();

    // 20-year projection at 4% compound interest
    final proj20Indep = plafondIndep * ((math.pow(1.04, 20) - 1) / 0.04);
    final proj20Salarie = petit * ((math.pow(1.04, 20) - 1) / 0.04);

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
          // ── Header with ×5 badge (P6-E / S42) ──
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context)!.pillar3aIndepPlafondsCompares,
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
                    S.of(context)!.pillar3aIndepSuperPouvoir(multiplier.toString()),
                    style: GoogleFonts.montserrat(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: MintColors.white,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Salarie bar
          _buildPlafondBar(
            label: S.of(context)!.pillar3aIndepSalarie,
            value: petit,
            maxValue: grand,
            color: MintColors.info,
          ),
          const SizedBox(height: 16),

          // Independant bar
          _buildPlafondBar(
            label: S.of(context)!.pillar3aIndepIndependantToi,
            value: plafondIndep,
            maxValue: grand,
            color: MintColors.success,
            highlight: true,
          ),
          const SizedBox(height: 16),

          // Max bar
          _buildPlafondBar(
            label: S.of(context)!.pillar3aIndepGrand3aMax,
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
                    S.of(context)!.pillar3aIndepEn20Ans,
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
                          S.of(context)!.pillar3aIndepSalarie, proj20Salarie, MintColors.info),
                      Text(
                        S.of(context)!.pillar3aIndepVs,
                        style: GoogleFonts.inter(
                            fontSize: 14, color: MintColors.textMuted),
                      ),
                      _buildProjectionColumn(
                          S.of(context)!.pillar3aIndepToi, proj20Indep, MintColors.success),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    S.of(context)!.pillar3aIndepDifference(IndependantsService.formatChf(proj20Indep - proj20Salarie)),
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
              S.of(context)!.pillar3aIndepBonASavoir,
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
          S.of(context)!.pillar3aIndepEduMultiTitle,
          S.of(context)!.pillar3aIndepEduMultiBody,
        ),
        _buildEduCard(
          Icons.warning_amber_rounded,
          S.of(context)!.pillar3aIndepEduConditionTitle,
          S.of(context)!.pillar3aIndepEduConditionBody,
        ),
        _buildEduCard(
          Icons.trending_up,
          S.of(context)!.pillar3aIndepEduInvestTitle,
          S.of(context)!.pillar3aIndepEduInvestBody,
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
              S.of(context)!.pillar3aIndepDisclaimer,
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
