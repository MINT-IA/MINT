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
import 'package:mint_mobile/widgets/premium/mint_picker_tile.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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
                MintEntrance(child: _buildHeader()),
                const SizedBox(height: 20),
                MintEntrance(delay: const Duration(milliseconds: 100), child: _buildRevenuSlider()),
                const SizedBox(height: 20),
                _buildAgeSlider(),
                const SizedBox(height: 20),
                _buildTauxSlider(),
                const SizedBox(height: 24),
                if (_result != null) ...[
                  MintEntrance(child: _buildChiffreChoc()),
                  const SizedBox(height: 24),
                  MintEntrance(delay: const Duration(milliseconds: 100), child: _buildResultCards()),
                  const SizedBox(height: 24),
                  MintEntrance(delay: const Duration(milliseconds: 150), child: _buildRetirementComparison()),
                  const SizedBox(height: 24),
                  MintEntrance(delay: const Duration(milliseconds: 200), child: _buildAgeTable()),
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
      title: Text(S.of(context)!.lppVolontaireTitle, style: MintTextStyles.headlineMedium()),
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
              S.of(context)!.lppVolontaireHeaderInfo,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Inputs ────────────────────────────────────────────────

  Widget _buildRevenuSlider() {
    return _buildInputCard(
      child: MintAmountField(
        label: S.of(context)!.lppVolontaireRevenuLabel,
        value: _revenuNet,
        formatValue: (v) => IndependantsService.formatChf(v),
        onChanged: (v) {
          setState(() {
            _revenuNet = v;
            _calculate();
          });
        },
        min: 0,
        max: 250000,
      ),
    );
  }

  Widget _buildAgeSlider() {
    return _buildInputCard(
      child: MintPickerTile(
        label: S.of(context)!.lppVolontaireTonAge,
        value: _age,
        minValue: 25,
        maxValue: 65,
        formatValue: (v) => '$v ans',
        onChanged: (v) {
          setState(() {
            _age = v;
            _calculate();
          });
        },
      ),
    );
  }

  Widget _buildTauxSlider() {
    return _buildInputCard(
      child: MintPremiumSlider(
        label: S.of(context)!.lppVolontaireTauxMarginal,
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

  Widget _buildInputCard({required Widget child}) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.all(20),
      child: child,
    );
  }

  // ── Chiffre Choc ───────────────────────────────────────────

  Widget _buildChiffreChoc() {
    final r = _result!;
    return Semantics(
      label: S.of(context)!.semanticsLppCapitalisation(IndependantsService.formatChf(r.capitalisationAnnuelle)),
      child: MintSurface(
        tone: MintSurfaceTone.peche,
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            MintHeroNumber(
              value: IndependantsService.formatChf(r.capitalisationAnnuelle),
              caption: S.of(context)!.lppVolontaireChiffreChocCaption(IndependantsService.formatChf(r.capitalisationAnnuelle)),
              color: MintColors.success,
            ),
          ],
        ),
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
                S.of(context)!.lppVolontaireSalaireCoordLabel,
                IndependantsService.formatChf(r.salaireCoordonne),
                Icons.account_balance_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.lppVolontaireTauxBonifLabel,
                '${(r.tauxBonification * 100).toStringAsFixed(0)}\u00a0%',
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
                S.of(context)!.lppVolontaireCotisationLabel,
                IndependantsService.formatChf(r.cotisationAnnuelle),
                Icons.calendar_month_outlined,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                S.of(context)!.lppVolontaireEconomieFiscaleLabel,
                IndependantsService.formatChf(r.economieFiscale),
                Icons.savings_outlined,
                valueColor: MintColors.success,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildMetricCard(
          S.of(context)!.lppVolontaireTrancheAgeLabel,
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
    final card = Semantics(
      label: S.of(context)!.semanticsMetricLabelValue(label, value),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(child: Icon(icon, size: 18, color: MintColors.textMuted)),
            const SizedBox(height: 8),
            Text(
              value,
              style: (small ? MintTextStyles.bodyMedium(color: valueColor ?? MintColors.textPrimary) : MintTextStyles.headlineMedium(color: valueColor ?? MintColors.textPrimary)).copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: MintSpacing.xs),
            Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ],
        ),
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
                S.of(context)!.lppVolontaireProjectionTitle,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Sans LPP bar
          _buildProjectionBar(
            label: S.of(context)!.lppVolontaireSansLpp,
            value: r.projectionSansLpp,
            ratio: sansRatio,
            color: MintColors.success,
          ),
          const SizedBox(height: 16),

          // Avec LPP bar
          _buildProjectionBar(
            label: S.of(context)!.lppVolontaireAvecLpp,
            value: r.projectionAvecLpp,
            ratio: avecRatio,
            color: MintColors.success,
          ),
          const SizedBox(height: 16),

          // Gap highlight
          Semantics(
            label: S.of(context)!.semanticsLppGain(IndependantsService.formatChf(gap)),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: MintColors.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  ExcludeSemantics(child: const Icon(Icons.add_circle_outline, size: 16, color: MintColors.success)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.of(context)!.lppVolontaireGapLabel(IndependantsService.formatChf(gap)),
                      style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
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
                style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
              ),
            ),
            Text(
              '${IndependantsService.formatChf(value)}/an',
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
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
                S.of(context)!.lppVolontaireBonificationTitle,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
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
        color: isCurrent ? MintColors.primary.withValues(alpha: 0.06) : MintColors.transparent,
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
                    S.of(context)!.lppVolontaireToi,
                    style: MintTextStyles.micro(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              Text(
                age,
                style: MintTextStyles.bodyMedium(color: isCurrent ? MintColors.textPrimary : MintColors.textSecondary).copyWith(fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400),
              ),
            ],
          ),
          Text(
            taux,
            style: MintTextStyles.titleMedium(color: isCurrent ? MintColors.primary : MintColors.textSecondary),
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
              S.of(context)!.lppVolontaireBonASavoir,
              style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(letterSpacing: 1, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildEduCard(
          Icons.account_balance_outlined,
          S.of(context)!.lppVolontaireEduAffiliationTitle,
          S.of(context)!.lppVolontaireEduAffiliationBody,
        ),
        _buildEduCard(
          Icons.savings_outlined,
          S.of(context)!.lppVolontaireEduFiscalTitle,
          S.of(context)!.lppVolontaireEduFiscalBody,
        ),
        _buildEduCard(
          Icons.warning_amber_rounded,
          S.of(context)!.lppVolontaireEduImpact3aTitle,
          S.of(context)!.lppVolontaireEduImpact3aBody,
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
              S.of(context)!.lppVolontaireDisclaimer,
              style: MintTextStyles.bodySmall(color: MintColors.deepOrange),
            ),
          ),
        ],
      ),
    );
  }
}
