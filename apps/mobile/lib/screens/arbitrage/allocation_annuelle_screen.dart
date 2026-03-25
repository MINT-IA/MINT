import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/arbitrage/breakeven_indicator_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/hypothesis_editor_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/trajectory_comparison_chart.dart';
import 'package:mint_mobile/widgets/coach/indicatif_banner.dart';
import 'package:mint_mobile/widgets/precision/smart_default_indicator.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Allocation annuelle arbitrage screen — compare 3a, rachat LPP,
/// amortissement indirect, and investissement libre.
///
/// Sprint S32 — Arbitrage Phase 1.
/// Design System: Category B — Simulator.
///
/// NEVER ranks options. Side-by-side comparison only.
/// No banned terms.
class AllocationAnnuelleScreen extends StatefulWidget {
  const AllocationAnnuelleScreen({super.key});

  @override
  State<AllocationAnnuelleScreen> createState() =>
      _AllocationAnnuelleScreenState();
}

class _AllocationAnnuelleScreenState extends State<AllocationAnnuelleScreen> {
  // ── Input controllers ──
  final _montantCtrl = TextEditingController(text: '7000');
  final _potentielRachatCtrl = TextEditingController(text: '50000');
  double _tauxMarginal = 30.0; // percentage
  bool _a3aMaxed = false;
  bool _hasRachatLpp = true;
  bool _isPropertyOwner = false;
  int _anneesAvantRetraite = 20;
  String _canton = 'VD';

  // ── Hypothesis sliders ──
  Map<String, double> _hypotheses = {
    'rendement_marche': 4.0,
    'rendement_lpp': 1.25,
    'rendement_3a': 2.0,
  };

  ArbitrageResult? _result;

  // ── CoachProfile auto-fill (P8 Phase 4) ──
  bool _didAutoFill = false;
  Map<String, ProfileDataSource> _dataSources = {};
  bool _hasEstimatedValues = false;

  @override
  void initState() {
    super.initState();
    _recalculate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didAutoFill) {
      _didAutoFill = true;
      _autoFillFromProfile();
    }
  }

  void _autoFillFromProfile() {
    try {
      final profile = context.read<CoachProfileProvider>().profile;
      if (profile == null) return;
      _autoFillFromProfileData(profile);
    } catch (_) {
      // Provider not in tree (tests) — keep defaults
    }
  }

  void _autoFillFromProfileData(CoachProfile profile) {

    // Annual contribution capacity: 3a max for salaried
    if (profile.salaireBrutMensuel > 0) {
      _montantCtrl.text = pilier3aPlafondAvecLpp.round().toString();
      _hasEstimatedValues = true;
    }

    // Canton from profile
    if (cantonFullNames.containsKey(profile.canton)) {
      _canton = profile.canton;
    }

    // Real marginal rate via RetirementTaxCalculator
    final revenu = profile.revenuBrutAnnuel;
    if (revenu > 0) {
      final rate = RetirementTaxCalculator.estimateMarginalRate(
        revenu,
        _canton,
      );
      _tauxMarginal = (rate * 100).roundToDouble().clamp(10, 50);
    }

    // Real lacune rachat LPP (not estimated 20%)
    final lacune = profile.prevoyance.lacuneRachatRestante;
    if (lacune > 0) {
      _potentielRachatCtrl.text = lacune.round().toString();
      _hasRachatLpp = true;
    } else if (profile.prevoyance.avoirLppTotal != null) {
      // Fallback: no lacune data, disable rachat
      _potentielRachatCtrl.text = '0';
      _hasRachatLpp = false;
    }

    _anneesAvantRetraite = profile.anneesAvantRetraite;
    _dataSources = profile.dataSources;
    _recalculate();
  }

  @override
  void dispose() {
    _montantCtrl.dispose();
    _potentielRachatCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    final montant =
        double.tryParse(_montantCtrl.text.replaceAll("'", '')) ?? 7000;
    final potentielRachat = _hasRachatLpp
        ? (double.tryParse(_potentielRachatCtrl.text.replaceAll("'", '')) ??
            50000)
        : 0.0;

    final result = ArbitrageEngine.compareAllocationAnnuelle(
      montantDisponible: montant,
      tauxMarginal: _tauxMarginal / 100,
      a3aMaxed: _a3aMaxed,
      potentielRachatLpp: potentielRachat,
      isPropertyOwner: _isPropertyOwner,
      tauxHypothecaire: 0.015,
      anneesAvantRetraite: _anneesAvantRetraite,
      rendement3a: (_hypotheses['rendement_3a'] ?? 2.0) / 100,
      rendementLpp: (_hypotheses['rendement_lpp'] ?? 1.25) / 100,
      rendementMarche: (_hypotheses['rendement_marche'] ?? 4.0) / 100,
      canton: _canton,
      dataSources: _dataSources,
    );

    setState(() => _result = result);
  }

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;

    return Scaffold(
      backgroundColor: MintColors.white,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          // ── AppBar: white standard (Design System §4.5) ──
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.white,
            foregroundColor: MintColors.textPrimary,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Semantics(
              header: true,
              child: Text(
                l.allocAnnuelleTitle,
                style: MintTextStyles.headlineMedium(),
              ),
            ),
          ),

          // ── Content ──
          SliverPadding(
            padding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.lg,
              vertical: MintSpacing.md,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // ── Inputs ──
                _buildInputSection(l),
                const SizedBox(height: MintSpacing.lg),

                // ── Chart ──
                if (_result != null && _result!.options.isNotEmpty) ...[
                  // ── Indicatif banner (P8 Phase 4) ──
                  IndicatifBanner(
                    confidenceScore: _result!.confidenceScore,
                    topEnrichmentCategory: '3a',
                  ),
                  if (_hasEstimatedValues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: MintSpacing.sm),
                      child: SmartDefaultIndicator(
                        source: l.allocAnnuellePreRempli,
                        confidence: _result!.confidenceScore / 100,
                      ),
                    ),
                  Semantics(
                    label: l.allocAnnuelleTrajectoires,
                    child: Text(
                      l.allocAnnuelleTrajectoires,
                      style: MintTextStyles.titleMedium(),
                    ),
                  ),
                  const SizedBox(height: MintSpacing.xs),
                  Text(
                    l.allocAnnuelleGraphHint,
                    style: MintTextStyles.labelSmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MintSpacing.sm),
                  TrajectoryComparisonChart(
                    options: _result!.options,
                    breakevenYear: _result!.breakevenYear,
                    colors: _colorsForOptions(_result!.options),
                  ),
                  const SizedBox(height: MintSpacing.lg),

                  // ── Terminal values ──
                  _buildTerminalValuesCard(l),
                  const SizedBox(height: MintSpacing.lg),

                  // ── Chiffre choc ──
                  _buildChiffreChocCard(l),
                  const SizedBox(height: MintSpacing.lg),

                  // ── Sensitivity ──
                  BreakevenIndicatorWidget(
                    breakevenYear: _result!.breakevenYear,
                    ageRetraite: 65,
                    horizon: _anneesAvantRetraite,
                    sensitivity: _result!.sensitivity,
                  ),
                  const SizedBox(height: MintSpacing.lg),

                  ArbitrageTornadoSection(result: _result!),
                  const SizedBox(height: MintSpacing.lg),

                  // ── Hypothesis sliders ──
                  HypothesisEditorWidget(
                    hypotheses: [
                      HypothesisConfig(
                        key: 'rendement_marche',
                        label: l.allocAnnuelleRendementMarche,
                        min: 0,
                        max: 8,
                        divisions: 16,
                        defaultValue: 4,
                      ),
                      HypothesisConfig(
                        key: 'rendement_lpp',
                        label: l.allocAnnuelleRendementLpp,
                        min: 0,
                        max: 4,
                        divisions: 8,
                        defaultValue: 1.25,
                      ),
                      HypothesisConfig(
                        key: 'rendement_3a',
                        label: l.allocAnnuelleRendement3a,
                        min: 0,
                        max: 5,
                        divisions: 10,
                        defaultValue: 2,
                      ),
                    ],
                    values: _hypotheses,
                    onChanged: (updated) {
                      _hypotheses = updated;
                      _recalculate();
                    },
                  ),
                  const SizedBox(height: MintSpacing.lg),

                  // ── Hypotheses list ──
                  _buildHypothesesSection(l),
                  const SizedBox(height: MintSpacing.lg),

                  // ── Encouraging message ──
                  Padding(
                    padding: const EdgeInsets.only(bottom: MintSpacing.md),
                    child: Text(
                      l.allocAnnuelleEncouragement,
                      style: MintTextStyles.bodyMedium(
                        color: MintColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // ── Disclaimer ──
                  _buildDisclaimerCard(l),
                  const SizedBox(height: MintSpacing.xl),
                ],
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  List<Color> _colorsForOptions(List<TrajectoireOption> options) {
    const colorMap = <String, Color>{
      '3a': MintColors.retirementAvs,
      'rachat_lpp': MintColors.retirementLpp,
      'amort_indirect': MintColors.trajectoryPrudent,
      'invest_libre': MintColors.purple,
    };
    return options
        .map((o) => colorMap[o.id] ?? MintColors.textMuted)
        .toList();
  }

  // ═══════════════════════════════════════════════════════════════
  //  INPUT SECTION
  // ═══════════════════════════════════════════════════════════════

  Widget _buildInputSection(S l) {
    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintEntrance(child: Text(
            l.allocAnnuelleBudgetTitle,
            style: MintTextStyles.titleMedium(),
          )),
          const SizedBox(height: MintSpacing.md),
          MintEntrance(delay: const Duration(milliseconds: 100), child: _buildTextField(
            controller: _montantCtrl,
            label: l.allocAnnuelleMontantLabel,
          )),
          const SizedBox(height: MintSpacing.md),

          // Taux marginal slider
          MintEntrance(delay: const Duration(milliseconds: 200), child: MintPremiumSlider(
            label: l.allocAnnuelleTauxMarginal,
            value: _tauxMarginal,
            min: 10,
            max: 50,
            divisions: 8,
            formatValue: (v) => '${v.toStringAsFixed(0)}\u00a0%',
            onChanged: (v) {
              setState(() => _tauxMarginal = v);
              _recalculate();
            },
          )),
          const SizedBox(height: MintSpacing.sm),

          // Annees avant retraite slider
          MintEntrance(delay: const Duration(milliseconds: 300), child: MintPremiumSlider(
            label: l.allocAnnuelleAnneesRetraite,
            value: _anneesAvantRetraite.toDouble(),
            min: 5,
            max: 40,
            divisions: 35,
            formatValue: (v) => l.allocAnnuelleAnneesValue(v.round()),
            onChanged: (v) {
              setState(() => _anneesAvantRetraite = v.round());
              _recalculate();
            },
          )),
          const SizedBox(height: MintSpacing.sm),

          // Toggles
          MintEntrance(delay: const Duration(milliseconds: 400), child: _buildToggle(
            label: l.allocAnnuelle3aMaxed,
            value: _a3aMaxed,
            onChanged: (v) {
              _a3aMaxed = v;
              _recalculate();
            },
          )),
          _buildToggle(
            label: l.allocAnnuelleRachatLpp,
            value: _hasRachatLpp,
            onChanged: (v) {
              _hasRachatLpp = v;
              _recalculate();
            },
          ),
          if (_hasRachatLpp) ...[
            const SizedBox(height: MintSpacing.sm),
            _buildTextField(
              controller: _potentielRachatCtrl,
              label: l.allocAnnuelleRachatMontant,
            ),
          ],
          _buildToggle(
            label: l.allocAnnuelleProprietaire,
            value: _isPropertyOwner,
            onChanged: (v) {
              _isPropertyOwner = v;
              _recalculate();
            },
          ),
          const SizedBox(height: MintSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: Semantics(
              button: true,
              label: l.allocAnnuelleComparer,
              child: FilledButton(
                onPressed: _recalculate,
                style: FilledButton.styleFrom(
                  backgroundColor: MintColors.primary,
                  foregroundColor: MintColors.white,
                  padding:
                      const EdgeInsets.symmetric(vertical: MintSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  l.allocAnnuelleComparer,
                  style: MintTextStyles.bodySmall(color: MintColors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
        ),
        const SizedBox(height: MintSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: MintTextStyles.bodyLarge(color: MintColors.textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: MintColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md,
              vertical: 14,
            ),
          ),
          onChanged: (_) => _recalculate(),
        ),
      ],
    );
  }

  Widget _buildToggle({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: MintSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
            ),
          ),
          Semantics(
            toggled: value,
            label: label,
            child: Switch(
              value: value,
              activeTrackColor: MintColors.primary,
              onChanged: (v) {
                setState(() => onChanged(v));
              },
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  TERMINAL VALUES CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildTerminalValuesCard(S l) {
    if (_result == null) return const SizedBox.shrink();
    final options = _result!.options;
    final colorMap = _colorsForOptions(options);

    return MintSurface(
      padding: const EdgeInsets.all(MintSpacing.md),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.allocAnnuelleValeurTerminale,
            style: MintTextStyles.titleMedium(),
          ),
          Text(
            l.allocAnnuelleApresAnnees(_anneesAvantRetraite),
            style: MintTextStyles.labelSmall(
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          for (int i = 0; i < options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: MintSpacing.sm),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: i < colorMap.length
                          ? colorMap[i]
                          : MintColors.textMuted,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: MintSpacing.sm),
                  Expanded(
                    child: Text(
                      options[i].label,
                      style: MintTextStyles.bodySmall(
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    _formatChf(options[i].terminalValue),
                    style: MintTextStyles.bodyMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  CHIFFRE CHOC CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildChiffreChocCard(S l) {
    if (_result == null) return const SizedBox.shrink();
    return Semantics(
      label: _result!.chiffreChoc,
      child: MintSurface(
        padding: const EdgeInsets.all(MintSpacing.lg),
        radius: 16,
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: MintColors.info.withAlpha(25),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.insights_rounded,
                color: MintColors.info,
                size: 24,
              ),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              _result!.chiffreChoc,
              style: MintTextStyles.bodyMedium(
                color: MintColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              _result!.displaySummary,
              style: MintTextStyles.labelSmall(
                color: MintColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  HYPOTHESES EXPANDABLE
  // ═══════════════════════════════════════════════════════════════

  Widget _buildHypothesesSection(S l) {
    if (_result == null) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: MintSpacing.sm),
      title: Text(
        l.allocAnnuelleHypotheses,
        style: MintTextStyles.titleMedium(),
      ),
      children: [
        for (final h in _result!.hypotheses)
          Padding(
            padding: const EdgeInsets.only(bottom: MintSpacing.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('  \u2022  ',
                    style: TextStyle(color: MintColors.textMuted)),
                Expanded(
                  child: Text(
                    h,
                    style: MintTextStyles.labelSmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════
  //  DISCLAIMER CARD
  // ═══════════════════════════════════════════════════════════════

  Widget _buildDisclaimerCard(S l) {
    if (_result == null) return const SizedBox.shrink();
    return Semantics(
      label: l.allocAnnuelleAvertissement,
      child: MintSurface(
        tone: MintSurfaceTone.porcelaine,
        padding: const EdgeInsets.all(MintSpacing.md),
        radius: 16,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: MintColors.textMuted,
                ),
                const SizedBox(width: MintSpacing.sm),
                Text(
                  l.allocAnnuelleAvertissement,
                  style: MintTextStyles.labelSmall(),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              _result!.disclaimer,
              style: MintTextStyles.micro(),
            ),
            const SizedBox(height: MintSpacing.sm),
            Text(
              l.allocAnnuelleSources(_result!.sources.join(' | ')),
              style: MintTextStyles.micro(),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatChf(double value) {
    final intVal = value.round().abs();
    final str = intVal.toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buffer.write("'");
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${value < 0 ? '-' : ''}${buffer.toString()}';
  }
}
