import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/services/segments_service.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  GENDER GAP PREVOYANCE SCREEN — Sprint S12 / Chantier 6
// ────────────────────────────────────────────────────────────

class GenderGapScreen extends StatefulWidget {
  const GenderGapScreen({super.key});

  @override
  State<GenderGapScreen> createState() => _GenderGapScreenState();
}

class _GenderGapScreenState extends State<GenderGapScreen> {
  // ── State ──────────────────────────────────────────────────
  double _tauxActivite = 60;
  double _revenuAnnuel = 85000;
  int _age = 40;
  double _avoirLpp = 120000;
  int _anneesCotisation = 15;
  String _canton = 'VD';

  GenderGapResult? _result;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeFromProfile();
    });
    _compute();
  }

  void _initializeFromProfile() {
    try {
      final provider = context.read<CoachProfileProvider>();
      if (!provider.hasProfile) return;
      final profile = provider.profile!;
      setState(() {
        if (profile.revenuBrutAnnuel > 0) {
          _revenuAnnuel = profile.revenuBrutAnnuel;
        }
        if (profile.age > 0) {
          _age = profile.age;
        }
        final lpp = profile.prevoyance.avoirLppTotal;
        if (lpp != null && lpp > 0) {
          _avoirLpp = lpp;
        }
        final annees = profile.prevoyance.anneesContribuees;
        if (annees != null && annees > 0) {
          _anneesCotisation = annees;
        }
        if (profile.canton.isNotEmpty) {
          _canton = profile.canton;
        }
      });
      _compute();
    } catch (_) {}
  }

  void _compute() {
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
    final s = S.of(context)!;
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        backgroundColor: MintColors.white,
        foregroundColor: MintColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          s.genderGapAppBarTitle,
          style: MintTextStyles.headlineMedium(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(MintSpacing.lg, MintSpacing.sm, MintSpacing.lg, MintSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MintEntrance(child: _buildHeader(s)),
            const SizedBox(height: MintSpacing.lg),
            MintEntrance(delay: const Duration(milliseconds: 100), child: _buildIntro(s)),
            const SizedBox(height: MintSpacing.lg),

            // Taux activite slider
            MintEntrance(delay: const Duration(milliseconds: 200), child: _buildTauxSlider(s)),
            const SizedBox(height: MintSpacing.lg),

            // Input section
            MintEntrance(delay: const Duration(milliseconds: 300), child: _buildInputSection(s)),
            const SizedBox(height: MintSpacing.lg),

            // Results
            if (_result != null) ...[
              _buildPensionComparison(s),
              const SizedBox(height: MintSpacing.lg),
              _buildCoordinationExplanation(s),
              const SizedBox(height: MintSpacing.lg),
              _buildOfsStatistic(s),
              const SizedBox(height: MintSpacing.lg),
              _buildRecommendations(s),
              const SizedBox(height: MintSpacing.lg),
            ],

            // Disclaimer
            MintEntrance(delay: const Duration(milliseconds: 400), child: _buildDisclaimer(s)),
            const SizedBox(height: MintSpacing.md),

            // Sources
            _buildSourcesFooter(s),
            const SizedBox(height: MintSpacing.xxl),
          ],
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader(S s) {
    return Semantics(
      header: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: MintColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.balance,
              color: MintColors.purple,
              size: 28,
            ),
          ),
          const SizedBox(width: MintSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.genderGapHeaderTitle,
                  style: MintTextStyles.headlineLarge().copyWith(fontSize: 24),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  s.genderGapHeaderSubtitle,
                  style: MintTextStyles.bodyMedium(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Intro ──────────────────────────────────────────────────

  Widget _buildIntro(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.info, size: 20),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              s.genderGapIntro,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ── Taux slider ────────────────────────────────────────────

  Widget _buildTauxSlider(S s) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintPremiumSlider(
            label: s.genderGapTauxActivite,
            value: _tauxActivite,
            min: 10,
            max: 100,
            divisions: 18,
            formatValue: (v) => '${v.round()}%',
            activeColor: _tauxActivite < 60
                ? MintColors.error
                : _tauxActivite < 80
                    ? MintColors.warning
                    : MintColors.success,
            onChanged: (value) {
              _tauxActivite = value;
              _compute();
            },
          ),
        ],
      ),
    );
  }

  // ── Input section ──────────────────────────────────────────

  Widget _buildInputSection(S s) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.genderGapParametres,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.md),
          _buildInputRow(s.genderGapRevenuAnnuel, GenderGapService.formatChf(_revenuAnnuel)),
          const SizedBox(height: MintSpacing.sm),
          _buildInputRow(s.genderGapAge, s.genderGapAgeValue('$_age')),
          const SizedBox(height: MintSpacing.sm),
          _buildInputRow(s.genderGapAvoirLpp, GenderGapService.formatChf(_avoirLpp)),
          const SizedBox(height: MintSpacing.sm),
          _buildInputRow(s.genderGapAnneesCotisation, '$_anneesCotisation'),
          const SizedBox(height: MintSpacing.sm),
          _buildInputRow(s.genderGapCanton, _canton),
          const SizedBox(height: MintSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: MintSpacing.sm),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.science_outlined, color: MintColors.info, size: 16),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: Text(
                    s.genderGapDemoMode,
                    style: MintTextStyles.labelSmall(color: MintColors.info),
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
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
        ),
        Text(
          value,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
        ),
      ],
    );
  }

  // ── Pension comparison ─────────────────────────────────────

  Widget _buildPensionComparison(S s) {
    final result = _result!;
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.genderGapRenteLppEstimee,
            style: MintTextStyles.headlineMedium().copyWith(fontSize: 18),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            s.genderGapProjection('${result.anneesRestantes}'),
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.lg),

          // Visual bars
          _buildPensionBar(
            label: s.genderGapAt100,
            amount: result.renteAt100Pct,
            maxAmount: result.renteAt100Pct,
            color: MintColors.success,
          ),
          const SizedBox(height: MintSpacing.sm),
          _buildPensionBar(
            label: s.genderGapAtTaux('${_tauxActivite.round()}'),
            amount: result.renteAtCurrentTaux,
            maxAmount: result.renteAt100Pct,
            color: _tauxActivite < 60 ? MintColors.error : MintColors.warning,
          ),
          const SizedBox(height: MintSpacing.lg),

          // Gap highlight
          Semantics(
            label: '${s.genderGapLacuneAnnuelle} ${GenderGapService.formatChf(result.lacuneAnnuelle)}',
            child: Container(
              padding: const EdgeInsets.all(MintSpacing.md),
              decoration: BoxDecoration(
                color: MintColors.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: MintColors.error.withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.genderGapLacuneAnnuelle,
                        style: MintTextStyles.bodyMedium(color: MintColors.error),
                      ),
                      Text(
                        GenderGapService.formatChf(result.lacuneAnnuelle),
                        style: MintTextStyles.headlineMedium(color: MintColors.error).copyWith(fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: MintSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.genderGapLacuneTotale,
                        style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                      ),
                      Text(
                        GenderGapService.formatChf(result.lacuneTotale),
                        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
                      ),
                    ],
                  ),
                ],
              ),
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
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            Text(
              '${GenderGapService.formatChf(amount)}${S.of(context)!.genderGapPerYear}',
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
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

  Widget _buildCoordinationExplanation(S s) {
    final result = _result!;
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.school_outlined, color: MintColors.purple, size: 20),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(
                  s.genderGapCoordinationTitle,
                  style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            s.genderGapCoordinationBody,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: MintSpacing.md),

          // Comparison table
          MintSurface(
            tone: MintSurfaceTone.porcelaine,
            padding: const EdgeInsets.all(12),
            radius: 12,
            child: Column(
              children: [
                _buildComparisonRow(
                  s.genderGapSalaireBrut100,
                  GenderGapService.formatChf(_revenuAnnuel),
                ),
                const Divider(height: MintSpacing.md),
                _buildComparisonRow(
                  s.genderGapSalaireCoordonne100,
                  GenderGapService.formatChf(result.salaireCoordonne100),
                ),
                const Divider(height: MintSpacing.md),
                _buildComparisonRow(
                  s.genderGapSalaireBrutTaux('${_tauxActivite.round()}'),
                  GenderGapService.formatChf(_revenuAnnuel * (_tauxActivite / 100)),
                ),
                const Divider(height: MintSpacing.md),
                _buildComparisonRow(
                  s.genderGapSalaireCoordonneTaux('${_tauxActivite.round()}'),
                  GenderGapService.formatChf(result.salaireCoordonneActuel),
                  highlight: true,
                ),
                const Divider(height: MintSpacing.md),
                _buildComparisonRow(
                  s.genderGapDeductionFixe,
                  GenderGapService.formatChf(result.deductionCoordination),
                ),
              ],
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            s.genderGapSourceCoordination,
            style: MintTextStyles.labelSmall(),
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
            style: MintTextStyles.labelSmall(
              color: highlight ? MintColors.error : MintColors.textSecondary,
            ),
          ),
        ),
        Text(
          value,
          style: MintTextStyles.bodySmall(
            color: highlight ? MintColors.error : MintColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ── OFS Statistic ──────────────────────────────────────────

  Widget _buildOfsStatistic(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.bar_chart, color: MintColors.purple, size: 24),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.genderGapStatOfsTitle,
                  style: MintTextStyles.titleMedium(color: MintColors.purple).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 6),
                Text(
                  GenderGapService.statistiqueOfs,
                  style: MintTextStyles.bodySmall(color: MintColors.purple),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Recommendations ────────────────────────────────────────

  Widget _buildRecommendations(S s) {
    final result = _result!;
    if (result.recommendations.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.lightbulb_outline, size: 16, color: MintColors.textMuted),
            const SizedBox(width: MintSpacing.sm),
            Text(
              s.genderGapRecommandations,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
        const SizedBox(height: MintSpacing.sm),
        ...result.recommendations.map((rec) => Padding(
          padding: const EdgeInsets.only(bottom: MintSpacing.sm),
          child: _buildRecommendationCard(rec),
        )),
      ],
    );
  }

  Widget _buildRecommendationCard(GenderGapRecommendation rec) {
    return Semantics(
      label: rec.title,
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              rec.title,
              style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              rec.description,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              rec.source,
              style: MintTextStyles.labelSmall(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer(S s) {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.warning.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.warning.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text(
              s.genderGapDisclaimer,
              style: MintTextStyles.micro(color: MintColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  // ── Sources footer ─────────────────────────────────────────

  Widget _buildSourcesFooter(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.genderGapSources,
          style: MintTextStyles.labelSmall(),
        ),
        const SizedBox(height: 6),
        Text(
          s.genderGapSourcesBody,
          style: MintTextStyles.labelSmall(),
        ),
      ],
    );
  }
}
