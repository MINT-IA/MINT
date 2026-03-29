import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/independants_service.dart';
import 'package:mint_mobile/widgets/premium/mint_amount_field.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_hero_number.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
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
                MintEntrance(child: _buildHeader()),
                const SizedBox(height: 20),
                MintEntrance(delay: const Duration(milliseconds: 100), child: _buildLppToggle()),
                const SizedBox(height: 20),
                _buildRevenuSlider(),
                const SizedBox(height: 20),
                _buildTauxSlider(),
                const SizedBox(height: 24),
                if (_result != null) ...[
                  MintEntrance(child: _buildChiffreChoc()),
                  const SizedBox(height: 24),
                  MintEntrance(delay: const Duration(milliseconds: 100), child: _buildResultSection()),
                  const SizedBox(height: 24),
                  MintEntrance(delay: const Duration(milliseconds: 150), child: _buildComparisonBars()),
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
      backgroundColor: MintColors.white,
      foregroundColor: MintColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(S.of(context)!.pillar3aIndepTitle, style: MintTextStyles.headlineMedium()),
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
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
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
                  style: MintTextStyles.titleMedium(),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  _affilieLpp
                      ? S.of(context)!.pillar3aIndepPlafondPetit
                      : S.of(context)!.pillar3aIndepPlafondGrand,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
          Semantics(
            toggled: _affilieLpp,
            label: 'Affilié LPP', // TODO: i18n
            child: Switch(
              value: _affilieLpp,
              onChanged: (v) {
                _affilieLpp = v;
                _calculate();
              },
              activeTrackColor: MintColors.success,
            ),
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
      child: MintAmountField(
        label: S.of(context)!.pillar3aIndepRevenuLabel,
        value: _revenuNet,
        formatValue: (v) => IndependantsService.formatChf(v),
        onChanged: (v) {
          setState(() {
            _revenuNet = v;
            _calculate();
          });
        },
        min: 0,
        max: 300000,
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
      child: MintPremiumSlider(
        label: S.of(context)!.pillar3aIndepTauxLabel,
        value: _tauxMarginal * 100,
        min: 10,
        max: 45,
        divisions: 35,
        formatValue: (v) => '${v.toStringAsFixed(0)}\u00a0%',
        onChanged: (v) {
          setState(() {
            _tauxMarginal = v / 100;
            _calculate();
          });
        },
      ),
    );
  }

  // ── Chiffre Choc ───────────────────────────────────────────

  Widget _buildChiffreChoc() {
    final r = _result!;
    if (r.avantageSurSalarie <= 0) {
      return Semantics(
        label: 'Économie fiscale : ${IndependantsService.formatChf(r.economieFiscale)} francs', // TODO: i18n
        child: MintSurface(
          tone: MintSurfaceTone.porcelaine,
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              MintHeroNumber(
                value: IndependantsService.formatChf(r.economieFiscale),
                caption: S.of(context)!.pillar3aIndepChiffreChocCaption,
                color: MintColors.primary,
              ),
            ],
          ),
        ),
      );
    }

    return Semantics(
      label: 'Avantage sur salarié : ${IndependantsService.formatChf(r.avantageSurSalarie)} francs', // TODO: i18n
      child: MintSurface(
        tone: MintSurfaceTone.sauge,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            MintHeroNumber(
              value: IndependantsService.formatChf(r.avantageSurSalarie),
              caption: S.of(context)!.pillar3aIndepChiffreChocAvantageSalarie(IndependantsService.formatChf(r.avantageSurSalarie)),
              color: MintColors.success,
            ),
          ],
        ),
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
          _buildResultRow(S.of(context)!.pillar3aIndepPlafondApplicableLabel, IndependantsService.formatChf(r.plafond)),
          const SizedBox(height: 12),
          _buildResultRow(S.of(context)!.pillar3aIndepEconomieFiscaleAnLabel, IndependantsService.formatChf(r.economieFiscale)),
          const Divider(height: 24),
          _buildResultRow(
            S.of(context)!.pillar3aIndepPlafondSalarieLabel,
            IndependantsService.formatChf(r.plafondSalarie),
            color: MintColors.textMuted,
          ),
          const SizedBox(height: 8),
          _buildResultRow(
            S.of(context)!.pillar3aIndepEconomieSalarieLabel,
            IndependantsService.formatChf(r.economieSalarie),
            color: MintColors.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _buildResultRow(String label, String value, {Color? color}) {
    return Semantics(
      label: '$label : $value', // TODO: i18n
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: MintTextStyles.bodyMedium(color: color ?? MintColors.textSecondary),
          ),
          Text(
            value,
            style: MintTextStyles.bodyMedium(color: color ?? MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
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
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
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
                    S.of(context)!.pillar3aIndepSuperPouvoir(multiplier),
                    style: MintTextStyles.labelSmall(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
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
                    S.of(context)!.pillar3aIndepEn20ans,
                    style: MintTextStyles.micro(color: MintColors.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildProjectionColumn(
                          S.of(context)!.pillar3aIndepSalarie, proj20Salarie, MintColors.info),
                      Text(
                        S.of(context)!.pillar3aIndepVs,
                        style: MintTextStyles.bodyMedium(color: MintColors.textMuted),
                      ),
                      _buildProjectionColumn(
                          S.of(context)!.pillar3aIndepToi, proj20Indep, MintColors.success),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    S.of(context)!.pillar3aIndepDifference(IndependantsService.formatChf(proj20Indep - proj20Salarie)),
                    style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w700),
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
          style: MintTextStyles.headlineMedium(color: color).copyWith(fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: MintTextStyles.micro(color: MintColors.textMuted),
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
              style: MintTextStyles.bodySmall(color: highlight ? MintColors.textPrimary : MintColors.textSecondary).copyWith(fontWeight: highlight ? FontWeight.w600 : FontWeight.w400),
            ),
            Text(
              IndependantsService.formatChf(value),
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
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
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEduCard(
          Icons.layers_outlined,
          S.of(context)!.pillar3aIndepEduComptesTitle,
          S.of(context)!.pillar3aIndepEduComptesBody,
        ),
        _buildEduCard(
          Icons.warning_amber_rounded,
          S.of(context)!.pillar3aIndepEduConditionTitle,
          S.of(context)!.pillar3aIndepEduConditionBody,
        ),
        _buildEduCard(
          Icons.trending_up,
          S.of(context)!.pillar3aIndepEduInvestirTitle,
          S.of(context)!.pillar3aIndepEduInvestirBody,
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
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    body,
                    style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
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
              style: MintTextStyles.bodySmall(color: MintColors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }
}
