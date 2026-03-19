import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/retroactive_3a_calculator.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Simulateur de rattrapage 3a retroactif (nouveaute 2026).
///
/// Permet de visualiser les economies fiscales possibles en rattrapant
/// jusqu'a 10 annees de cotisations 3a manquees.
/// Base legale : OPP3 art. 7 (amendement 2026), LIFD art. 33 al. 1 let. e.
class Retroactive3aScreen extends StatefulWidget {
  const Retroactive3aScreen({super.key});

  @override
  State<Retroactive3aScreen> createState() => _Retroactive3aScreenState();
}

class _Retroactive3aScreenState extends State<Retroactive3aScreen> {
  int _gapYears = 5;
  double _tauxMarginal = 0.30;
  bool _hasLpp = true;

  static const _taxRates = [0.10, 0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.45, 0.50];

  Retroactive3aResult get _result => Retroactive3aCalculator.calculate(
        gapYears: _gapYears,
        tauxMarginal: _tauxMarginal,
        hasLpp: _hasLpp,
      );

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      backgroundColor: MintColors.white,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.white,
            surfaceTintColor: MintColors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
            foregroundColor: MintColors.textPrimary,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Rattrapage 3a', // TODO: i18n
              style: MintTextStyles.titleMedium(),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(MintSpacing.md),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Hero Card
                _buildHeroCard(),
                const SizedBox(height: MintSpacing.lg),

                // 2. Input Section
                _buildInputSection(),
                const SizedBox(height: MintSpacing.lg),

                // 3. Chiffre Choc
                _buildChiffreChocCard(result),
                const SizedBox(height: MintSpacing.lg),

                // 4. Breakdown
                _buildBreakdownSection(result),
                const SizedBox(height: MintSpacing.lg),

                // 5. Avant / Apres
                _buildImpactComparison(result),
                const SizedBox(height: MintSpacing.lg),

                // 6. Action Cards
                _buildActionCards(),
                const SizedBox(height: MintSpacing.lg),

                // 7. Disclaimer & Sources
                _buildDisclaimerSection(result),
                const SizedBox(height: MintSpacing.xxl),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── 1. Hero Card ──────────────────────────────────────────────

  Widget _buildHeroCard() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.lg),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(MintSpacing.md - 4),
            decoration: BoxDecoration(
              color: MintColors.accentPastel,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history_edu,
              size: 32,
              color: MintColors.accent,
            ),
          ),
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rattrapage 3a \u2014 Nouveaut\u00e9 2026', // TODO: i18n
                  style: MintTextStyles.titleMedium(),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  'Rattrape jusqu\u2019\u00e0 10 ans de cotisations manqu\u00e9es', // TODO: i18n
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. Input Section ──────────────────────────────────────────

  Widget _buildInputSection() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Param\u00e8tres', // TODO: i18n
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // Gap years slider
          _buildSliderRow(
            label: 'Ann\u00e9es \u00e0 rattraper', // TODO: i18n
            value: _gapYears.toDouble(),
            min: 1,
            max: 10,
            divisions: 9,
            format: '$_gapYears an${_gapYears > 1 ? "s" : ""}',
            onChanged: (v) => setState(() => _gapYears = v.round()),
          ),
          const SizedBox(height: MintSpacing.md),

          // Marginal tax rate picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Taux marginal d\u2019imposition', // TODO: i18n
                style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm + 4, vertical: MintSpacing.xs),
                decoration: BoxDecoration(
                  border: Border.all(color: MintColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<double>(
                    value: _tauxMarginal,
                    isDense: true,
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w700),
                    items: _taxRates
                        .map((r) => DropdownMenuItem(
                              value: r,
                              child: Text('${(r * 100).round()}\u00a0%'),
                            ))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _tauxMarginal = v);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.md),

          // Has LPP toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Affili\u00e9\u00b7e \u00e0 une caisse LPP', // TODO: i18n
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasLpp
                          ? 'Petit 3a\u00a0: CHF\u00a07\u2019258/an' // TODO: i18n
                          : 'Grand 3a\u00a0: 20\u00a0% du revenu net, max CHF\u00a036\u2019288/an', // TODO: i18n
                      style: MintTextStyles.labelSmall(color: MintColors.textMuted),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hasLpp,
                activeTrackColor: MintColors.primary,
                onChanged: (v) => setState(() => _hasLpp = v),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 3. Chiffre Choc Card ──────────────────────────────────────

  Widget _buildChiffreChocCard(Retroactive3aResult result) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg, vertical: MintSpacing.xl - 4),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '\u00c9conomies fiscales estim\u00e9es', // TODO: i18n
            style: MintTextStyles.labelSmall(color: MintColors.white60)
                .copyWith(fontWeight: FontWeight.w700, letterSpacing: 1.0),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            'CHF\u00a0${formatChf(result.economiesFiscales)}',
            style: MintTextStyles.displayMedium(color: MintColors.white),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            result.chiffreChoc,
            textAlign: TextAlign.center,
            style: MintTextStyles.bodySmall(color: MintColors.white70),
          ),
        ],
      ),
    );
  }

  // ── 4. Breakdown Section ──────────────────────────────────────

  Widget _buildBreakdownSection(Retroactive3aResult result) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md + 4),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'D\u00e9tail par ann\u00e9e', // TODO: i18n
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
          ),
          const SizedBox(height: MintSpacing.md),

          // Header
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  'Ann\u00e9e', // TODO: i18n
                  style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: Text(
                  'Plafond', // TODO: i18n
                  style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
              SizedBox(
                width: 80,
                child: Text(
                  'D\u00e9ductible', // TODO: i18n
                  style: MintTextStyles.labelSmall(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const Divider(height: MintSpacing.md),

          // Retroactive year rows
          for (final entry in result.breakdown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: MintSpacing.xs + 1),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${entry.year}',
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'CHF\u00a0${formatChf(entry.limit)}',
                      style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  SizedBox(
                    width: 80,
                    child: Icon(
                      entry.deductible
                          ? Icons.check_circle
                          : Icons.cancel,
                      size: 18,
                      color: entry.deductible
                          ? MintColors.success
                          : MintColors.error,
                    ),
                  ),
                ],
              ),
            ),

          const Divider(height: MintSpacing.md),

          // Total retroactive row
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  'Total', // TODO: i18n
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Text(
                  'CHF\u00a0${formatChf(result.totalRetroactive)}',
                  style: MintTextStyles.bodySmall(color: MintColors.primary)
                      .copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 80),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),

          // Current year row (separate)
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 48,
                  child: Text(
                    '${DateTime.now().year}', // TODO: i18n (referenceYear)
                    style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Ann\u00e9e en cours', // TODO: i18n
                    style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                  ),
                ),
                Text(
                  'CHF\u00a0${formatChf(result.totalCurrentYear)}',
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.sm + 4),

          // Grand total row
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total d\u00e9ductible en ${DateTime.now().year}', // TODO: i18n
                  style: MintTextStyles.labelSmall(color: MintColors.white70)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  'CHF\u00a0${formatChf(result.totalContribution)}',
                  style: MintTextStyles.titleMedium(color: MintColors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 5. Impact Comparison ──────────────────────────────────────

  Widget _buildImpactComparison(Retroactive3aResult result) {
    final sansRattrapage = result.totalCurrentYear * _tauxMarginal;
    final avecRattrapage = result.economiesFiscales +
        (result.totalCurrentYear * _tauxMarginal);
    final difference = avecRattrapage - sansRattrapage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Impact avant / apr\u00e8s', // TODO: i18n
          style: MintTextStyles.bodySmall(color: MintColors.textMuted),
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        Row(
          children: [
            Expanded(
              child: _buildComparisonCard(
                title: 'Sans rattrapage', // TODO: i18n
                subtitle: 'Ann\u00e9e courante seule', // TODO: i18n
                amount: sansRattrapage,
                color: MintColors.warning,
                isHighlighted: false,
              ),
            ),
            const SizedBox(width: MintSpacing.sm + 4),
            Expanded(
              child: _buildComparisonCard(
                title: 'Avec rattrapage', // TODO: i18n
                subtitle: '+ $_gapYears an${_gapYears > 1 ? "s" : ""} r\u00e9troactifs', // TODO: i18n
                amount: avecRattrapage,
                color: MintColors.success,
                isHighlighted: true,
              ),
            ),
          ],
        ),
        if (difference > 0) ...[
          const SizedBox(height: MintSpacing.sm + 4),
          Container(
            padding: const EdgeInsets.all(MintSpacing.md),
            decoration: BoxDecoration(
              color: MintColors.successBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.greenLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: MintColors.greenDark, size: 24),
                const SizedBox(width: MintSpacing.sm + 4),
                Expanded(
                  child: Text(
                    'Le rattrapage te fait \u00e9conomiser '
                    'CHF\u00a0${formatChf(difference)} de plus en imp\u00f4ts\u00a0!', // TODO: i18n
                    style: MintTextStyles.bodyMedium(color: MintColors.greenForest)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildComparisonCard({
    required String title,
    required String subtitle,
    required double amount,
    required Color color,
    required bool isHighlighted,
  }) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isHighlighted ? color : MintColors.border,
          width: isHighlighted ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            subtitle,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            'CHF\u00a0${formatChf(amount)}',
            style: MintTextStyles.headlineMedium(color: color),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            'd\u2019\u00e9conomie fiscale', // TODO: i18n
            style: MintTextStyles.labelSmall(
              color: isHighlighted ? color : MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── 6. Action Cards ───────────────────────────────────────────

  Widget _buildActionCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Prochaines \u00e9tapes', // TODO: i18n
          style: MintTextStyles.bodySmall(color: MintColors.textMuted),
        ),
        const SizedBox(height: MintSpacing.sm + 4),
        _buildActionTile(
          icon: Icons.account_balance,
          title: 'Ouvrir un compte 3a', // TODO: i18n
          subtitle:
              'Compare les prestataires et ouvre un compte d\u00e9di\u00e9 au rattrapage.', // TODO: i18n
          color: MintColors.info,
        ),
        const SizedBox(height: MintSpacing.sm),
        _buildActionTile(
          icon: Icons.checklist,
          title: 'Pr\u00e9parer les documents', // TODO: i18n
          subtitle:
              'Certificat de salaire, attestation de cotisations AVS, '
              'justificatif d\u2019absence de 3a pour chaque ann\u00e9e.', // TODO: i18n
          color: MintColors.categoryAmber,
        ),
        const SizedBox(height: MintSpacing.sm),
        _buildActionTile(
          icon: Icons.person_search,
          title: 'Consulter un\u00b7e sp\u00e9cialiste', // TODO: i18n
          subtitle:
              'Un\u00b7e expert\u00b7e fiscal\u00b7e peut confirmer ton taux marginal '
              'et optimiser le calendrier de versement.', // TODO: i18n
          color: MintColors.categoryPurple,
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(MintSpacing.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: MintSpacing.sm + 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  subtitle,
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: MintColors.textMuted,
          ),
        ],
      ),
    );
  }

  // ── 7. Disclaimer & Sources ───────────────────────────────────

  Widget _buildDisclaimerSection(Retroactive3aResult result) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
              const SizedBox(width: MintSpacing.sm + 4),
              Expanded(
                child: Text(
                  result.disclaimer,
                  style: MintTextStyles.micro(color: MintColors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm + 4),
          const Divider(height: 1),
          const SizedBox(height: MintSpacing.sm + 4),
          Text(
            'Sources', // TODO: i18n
            style: MintTextStyles.micro(color: MintColors.textMuted)
                .copyWith(fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
          ),
          const SizedBox(height: MintSpacing.xs + 2),
          for (final source in result.sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u2022 ',
                    style: MintTextStyles.micro(color: MintColors.textMuted),
                  ),
                  Expanded(
                    child: Text(
                      source,
                      style: MintTextStyles.micro(color: MintColors.textMuted),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String format,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
            Text(
              format,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: MintColors.primary,
          onChanged: onChanged,
        ),
      ],
    );
  }
}
