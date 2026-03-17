import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
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
      backgroundColor: MintColors.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 100,
            pinned: true,
            backgroundColor: MintColors.primary,
            foregroundColor: MintColors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                'RATTRAPAGE 3A', // TODO: i18n
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: MintColors.white,
                  letterSpacing: 0.5,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [MintColors.primary, MintColors.primaryLight],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // 1. Hero Card
                _buildHeroCard(),
                const SizedBox(height: 24),

                // 2. Input Section
                _buildInputSection(),
                const SizedBox(height: 24),

                // 3. Chiffre Choc
                _buildChiffreChocCard(result),
                const SizedBox(height: 24),

                // 4. Breakdown
                _buildBreakdownSection(result),
                const SizedBox(height: 24),

                // 5. Avant / Apres
                _buildImpactComparison(result),
                const SizedBox(height: 24),

                // 6. Action Cards
                _buildActionCards(),
                const SizedBox(height: 24),

                // 7. Disclaimer & Sources
                _buildDisclaimerSection(result),
                const SizedBox(height: 40),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
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
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rattrapage 3a \u2014 Nouveaut\u00e9 2026', // TODO: i18n
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Rattrape jusqu\u2019\u00e0 10 ans de cotisations manqu\u00e9es', // TODO: i18n
                  style: TextStyle(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PARAM\u00c8TRES', // TODO: i18n
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

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
          const SizedBox(height: 16),

          // Marginal tax rate picker
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Taux marginal d\u2019imposition', // TODO: i18n
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  border: Border.all(color: MintColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<double>(
                    value: _tauxMarginal,
                    isDense: true,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
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
          const SizedBox(height: 16),

          // Has LPP toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Affili\u00e9\u00b7e \u00e0 une caisse LPP', // TODO: i18n
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _hasLpp
                          ? 'Petit 3a\u00a0: CHF\u00a07\u2019258/an' // TODO: i18n
                          : 'Grand 3a\u00a0: 20\u00a0% du revenu net, max CHF\u00a036\u2019288/an', // TODO: i18n
                      style: const TextStyle(
                        fontSize: 11,
                        color: MintColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _hasLpp,
                activeColor: MintColors.primary,
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
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(
            '\u00c9CONOMIES FISCALES ESTIM\u00c9ES', // TODO: i18n
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.white60,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'CHF\u00a0${formatChf(result.economiesFiscales)}',
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: MintColors.white,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result.chiffreChoc,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. Breakdown Section ──────────────────────────────────────

  Widget _buildBreakdownSection(Retroactive3aResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'D\u00c9TAIL PAR ANN\u00c9E', // TODO: i18n
            style: GoogleFonts.montserrat(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              const SizedBox(
                width: 60,
                child: Text(
                  'Ann\u00e9e', // TODO: i18n
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
              const Expanded(
                child: Text(
                  'Plafond', // TODO: i18n
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(
                width: 80,
                child: Text(
                  'D\u00e9ductible', // TODO: i18n
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
          const Divider(height: 16),

          // Retroactive year rows
          for (final entry in result.breakdown)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  SizedBox(
                    width: 60,
                    child: Text(
                      '${entry.year}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'CHF\u00a0${formatChf(entry.limit)}',
                      style: const TextStyle(fontSize: 12),
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

          const Divider(height: 16),

          // Total retroactive row
          Row(
            children: [
              SizedBox(
                width: 60,
                child: Text(
                  'Total', // TODO: i18n
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'CHF\u00a0${formatChf(result.totalRetroactive)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: MintColors.primary,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(width: 80),
            ],
          ),
          const SizedBox(height: 8),

          // Current year row (separate)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.appleSurface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 48,
                  child: Text(
                    '2026', // TODO: i18n (referenceYear)
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                const Expanded(
                  child: Text(
                    'Ann\u00e9e en cours', // TODO: i18n
                    style: TextStyle(
                      fontSize: 11,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  'CHF\u00a0${formatChf(result.totalCurrentYear)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Grand total row
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL D\u00c9DUCTIBLE EN 2026', // TODO: i18n
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: MintColors.white70,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'CHF\u00a0${formatChf(result.totalContribution)}',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MintColors.white,
                  ),
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
          'IMPACT AVANT / APR\u00c8S', // TODO: i18n
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildComparisonCard(
                title: 'SANS RATTRAPAGE', // TODO: i18n
                subtitle: 'Ann\u00e9e courante seule', // TODO: i18n
                amount: sansRattrapage,
                color: MintColors.warning,
                isHighlighted: false,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildComparisonCard(
                title: 'AVEC RATTRAPAGE', // TODO: i18n
                subtitle: '+ $_gapYears an${_gapYears > 1 ? "s" : ""} r\u00e9troactifs', // TODO: i18n
                amount: avecRattrapage,
                color: MintColors.success,
                isHighlighted: true,
              ),
            ),
          ],
        ),
        if (difference > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: MintColors.successBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.greenLight),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up, color: MintColors.greenDark, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Le rattrapage te fait \u00e9conomiser '
                    'CHF\u00a0${formatChf(difference)} de plus en imp\u00f4ts\u00a0!', // TODO: i18n
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: MintColors.greenForest,
                    ),
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
      padding: const EdgeInsets.all(16),
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
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: MintColors.textMuted,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'CHF\u00a0${formatChf(amount)}',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'd\u2019\u00e9conomie fiscale', // TODO: i18n
            style: TextStyle(
              fontSize: 11,
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
          'PROCHAINES \u00c9TAPES', // TODO: i18n
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildActionTile(
          icon: Icons.account_balance,
          title: 'Ouvrir un compte 3a', // TODO: i18n
          subtitle:
              'Compare les prestataires et ouvre un compte d\u00e9di\u00e9 au rattrapage.', // TODO: i18n
          color: MintColors.info,
        ),
        const SizedBox(height: 8),
        _buildActionTile(
          icon: Icons.checklist,
          title: 'Pr\u00e9parer les documents', // TODO: i18n
          subtitle:
              'Certificat de salaire, attestation de cotisations AVS, '
              'justificatif d\u2019absence de 3a pour chaque ann\u00e9e.', // TODO: i18n
          color: MintColors.categoryAmber,
        ),
        const SizedBox(height: 8),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
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
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: MintColors.warning, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  result.disclaimer,
                  style: const TextStyle(
                    fontSize: 11,
                    color: MintColors.deepOrange,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: MintColors.orangeRetroWarm, height: 1),
          const SizedBox(height: 12),
          Text(
            'SOURCES', // TODO: i18n
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: MintColors.deepOrange,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          for (final source in result.sources)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '\u2022 ',
                    style: TextStyle(fontSize: 11, color: MintColors.deepOrange),
                  ),
                  Expanded(
                    child: Text(
                      source,
                      style: const TextStyle(
                        fontSize: 11,
                        color: MintColors.deepOrange,
                        height: 1.3,
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
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: MintColors.textPrimary,
              ),
            ),
            Text(
              format,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
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
