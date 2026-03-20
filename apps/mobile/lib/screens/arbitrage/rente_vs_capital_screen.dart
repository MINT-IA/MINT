import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/api_service.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_engine.dart';
import 'package:mint_mobile/services/financial_core/arbitrage_models.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/widgets/arbitrage/arbitrage_tornado_section.dart';
import 'package:mint_mobile/widgets/arbitrage/hypothesis_editor_widget.dart';
import 'package:mint_mobile/widgets/arbitrage/trajectory_comparison_chart.dart';
import 'package:mint_mobile/widgets/precision/field_help_tooltip.dart';
import 'package:mint_mobile/widgets/premium/mint_choice_card.dart';
import 'package:mint_mobile/widgets/premium/mint_confidence_notice.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_result_hero_card.dart';
import 'package:mint_mobile/widgets/premium/mint_signal_row.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';

/// Rente vs Capital arbitrage screen V2 — Decision Canvas.
///
/// V2 layout (spec §5.3):
///   1. Decision hero: "Rente ou capital." + subtitle
///   2. 3 MintChoiceCard: Rente / Capital / Mixte
///   3. Consequence comparison: MintResultHeroCard for selected option
///   4. 3 MintSignalRow: Revenu / Fiscalite / Transmission
///   5. MintConfidenceNotice (if no certificate)
///   6. Fast estimate inputs (age, retirement, salary)
///   7. CTA pill: "Comparer pour moi"
///   8. Advanced disclosure: "J'ai mon certificat LPP"
///   9. Explorer bloc (chart + life expectancy)
///  10. Affiner bloc (hypotheses + impact + tornado)
///  11. Disclaimer
///
/// NEVER ranks options. Side-by-side comparison only.
/// All text via i18n. No banned terms.
class RenteVsCapitalScreen extends StatefulWidget {
  const RenteVsCapitalScreen({super.key});

  @override
  State<RenteVsCapitalScreen> createState() => _RenteVsCapitalScreenState();
}

enum _InputMode { estimate, certificate }
enum _OutcomeMode { rente, capital, mixte }

class _RenteVsCapitalScreenState extends State<RenteVsCapitalScreen> {
  // -- V2 state --
  _OutcomeMode _selectedOutcome = _OutcomeMode.rente;
  bool _advancedExpanded = false;

  // -- Input mode --
  _InputMode _inputMode = _InputMode.estimate;

  // -- Estimate mode controllers --
  final _ageCtrl = TextEditingController(text: '50');
  final _ageRetraiteSlider = ValueNotifier<double>(65);
  final _salaryCtrl = TextEditingController(text: '100000');
  final _lppTotalCtrl = TextEditingController(text: '350000');

  // -- Certificate mode controllers --
  final _capitalObligCtrl = TextEditingController(text: '500000');
  final _capitalSurobCtrl = TextEditingController(text: '150000');
  final _renteCtrl = TextEditingController(text: '37000');
  final _tcObligCtrl = TextEditingController(text: '6.8');
  final _tcSurobCtrl = TextEditingController(text: '5.0');

  // -- Shared inputs --
  String _canton = 'VD';
  bool _isMarried = false;

  // -- Hypothesis sliders --
  Map<String, double> _hypotheses = {
    'rendement': 3.0,
    'swr': 4.0,
    'inflation': 2.0,
  };

  // -- Life expectancy slider --
  double _lifeExpectancy = 85;

  bool _isLoading = false;
  bool _hasError = false;
  int _requestCounter = 0;
  ArbitrageResult? _result;

  // -- CoachProfile auto-fill --
  bool _didAutoFill = false;
  Map<String, ProfileDataSource> _dataSources = {};
  bool _hasEstimatedValues = false;

  // -- New fields --
  double? _avsRenteMensuelle;
  final _rachatAnnuelCtrl = TextEditingController(text: '0');
  final _rachatMaxCtrl = TextEditingController(text: '0');
  bool _hasEpl = false;
  final _eplAmountCtrl = TextEditingController(text: '0');

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
    final provider = context.read<CoachProfileProvider>();
    final profile = provider.profile;
    if (profile == null) return;

    final sources = profile.dataSources;
    bool changed = false;
    bool hasEstimates = false;

    void apply(TextEditingController ctrl, String? value, String field) {
      if (value != null && value.isNotEmpty) {
        ctrl.text = value;
        changed = true;
        final src = sources[field];
        if (src != null && src != ProfileDataSource.certificate) {
          hasEstimates = true;
        }
      }
    }

    // Age from birth year
    final currentYear = DateTime.now().year;
    final age = currentYear - profile.birthYear;
    apply(_ageCtrl, age.toString(), 'age');

    // Gross annual salary
    final salaryAnnuel = profile.salaireBrutMensuel * profile.nombreDeMois;
    if (salaryAnnuel > 0) {
      apply(_salaryCtrl, salaryAnnuel.round().toString(), 'salaire_brut');
    }

    // LPP balance
    final lpp = profile.prevoyance.avoirLppTotal;
    if (lpp != null && lpp > 0) {
      apply(_lppTotalCtrl, lpp.round().toString(), 'prevoyance.avoirLppTotal');
    }

    // Canton
    final canton = profile.canton;
    if (cantonFullNames.containsKey(canton)) {
      _canton = canton;
      changed = true;
    }

    // Married
    final married = profile.etatCivil == CoachCivilStatus.marie;
    _isMarried = married;

    // LPP oblig/surob split
    final lppOblig = profile.prevoyance.avoirLppObligatoire;
    final lppSurob = profile.prevoyance.avoirLppSurobligatoire;
    if (lppOblig != null && lppOblig > 0) {
      apply(_capitalObligCtrl, lppOblig.round().toString(), 'prevoyance.avoirLppObligatoire');
    }
    if (lppSurob != null && lppSurob > 0) {
      apply(_capitalSurobCtrl, lppSurob.round().toString(), 'prevoyance.avoirLppSurobligatoire');
    }

    // Conversion rates from certificate
    final tcProfile = profile.prevoyance.tauxConversion;
    if (tcProfile > 0) {
      apply(_tcObligCtrl, (tcProfile * 100).toStringAsFixed(1), 'prevoyance.tauxConversion');
    }
    final tcSurobProfile = profile.prevoyance.tauxConversionSuroblig;
    if (tcSurobProfile != null && tcSurobProfile > 0) {
      apply(_tcSurobCtrl, (tcSurobProfile * 100).toStringAsFixed(1), 'prevoyance.tauxConversionSuroblig');
    }

    // AVS estimated monthly rente
    final avsRente = profile.prevoyance.renteAVSEstimeeMensuelle;
    if (avsRente != null && avsRente > 0) {
      _avsRenteMensuelle = avsRente;
      changed = true;
    }

    // Retirement age from profile
    final retirementAge = profile.targetRetirementAge;
    if (retirementAge != null && retirementAge >= 58 && retirementAge <= 70) {
      _ageRetraiteSlider.value = retirementAge.toDouble();
      changed = true;
    }

    // Rachat potential from profile
    final lacune = profile.prevoyance.lacuneRachatRestante;
    if (lacune > 0) {
      _rachatMaxCtrl.text = lacune.round().toString();
      changed = true;
    }

    if (changed) {
      _dataSources = Map.from(sources);
      _hasEstimatedValues = hasEstimates;
      _recalculate();
    }
  }

  @override
  void dispose() {
    _ageCtrl.dispose();
    _salaryCtrl.dispose();
    _lppTotalCtrl.dispose();
    _capitalObligCtrl.dispose();
    _capitalSurobCtrl.dispose();
    _renteCtrl.dispose();
    _tcObligCtrl.dispose();
    _tcSurobCtrl.dispose();
    _ageRetraiteSlider.dispose();
    _rachatAnnuelCtrl.dispose();
    _rachatMaxCtrl.dispose();
    _eplAmountCtrl.dispose();
    super.dispose();
  }

  /// Compute estimate-mode inputs from the LPP total entered by the user.
  void _recalculate() {
    _recalculateAsync();
  }

  Future<void> _recalculateAsync() async {
    final requestId = ++_requestCounter;
    final ageRetraite = _ageRetraiteSlider.value.round();

    double capitalOblig, capitalSurob, renteAnnuelle;
    double tcOblig, tcSurob;
    int? currentAge;
    double? salary;

    if (_inputMode == _InputMode.estimate) {
      final lppTotal =
          double.tryParse(_lppTotalCtrl.text.replaceAll("'", '')) ?? 350000;
      capitalOblig = lppTotal * 0.7;
      capitalSurob = lppTotal * 0.3;
      tcOblig = lppTauxConversionMin / 100;
      tcSurob = 0.05;
      renteAnnuelle = capitalOblig * tcOblig;
      currentAge = int.tryParse(_ageCtrl.text);
      salary = double.tryParse(_salaryCtrl.text.replaceAll("'", ''));
    } else {
      capitalOblig =
          double.tryParse(_capitalObligCtrl.text.replaceAll("'", '')) ?? 500000;
      capitalSurob =
          double.tryParse(_capitalSurobCtrl.text.replaceAll("'", '')) ?? 150000;
      renteAnnuelle =
          double.tryParse(_renteCtrl.text.replaceAll("'", '')) ?? 37000;
      tcOblig = (double.tryParse(_tcObligCtrl.text) ?? 6.8) / 100;
      tcSurob = (double.tryParse(_tcSurobCtrl.text) ?? 5.0) / 100;
      currentAge = null;
      salary = null;
    }

    // Rachat LPP: add future value of annual buybacks
    final rachatAnnuel = double.tryParse(_rachatAnnuelCtrl.text.replaceAll("'", '')) ?? 0;
    if (rachatAnnuel > 0 && currentAge != null) {
      final yearsToRetirement = math.max(0, _ageRetraite - currentAge);
      const lppReturn = 0.0125;
      final fvRachat = yearsToRetirement > 0
          ? rachatAnnuel * (math.pow(1 + lppReturn, yearsToRetirement) - 1) / lppReturn
          : rachatAnnuel;
      capitalOblig += fvRachat * 0.7;
      capitalSurob += fvRachat * 0.3;
    }

    // EPL: withdrawal for real estate reduces capital
    final eplAmount = _hasEpl
        ? (double.tryParse(_eplAmountCtrl.text.replaceAll("'", '')) ?? 0)
        : 0.0;
    if (eplAmount > 0) {
      final ratio = capitalOblig / math.max(1, capitalOblig + capitalSurob);
      capitalOblig = math.max(0, capitalOblig - eplAmount * ratio);
      capitalSurob = math.max(0, capitalSurob - eplAmount * (1 - ratio));
    }

    final capitalTotal = capitalOblig + capitalSurob;
    final horizon = math.max(30, (_lifeExpectancy - ageRetraite).round());

    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final result = await ApiService.compareRenteVsCapital(
        capitalLppTotal: capitalTotal,
        capitalObligatoire: capitalOblig,
        capitalSurobligatoire: capitalSurob,
        renteAnnuelleProposee: renteAnnuelle,
        tauxConversionObligatoire: tcOblig,
        tauxConversionSurobligatoire: tcSurob,
        canton: _canton,
        ageRetraite: ageRetraite,
        tauxRetrait: (_hypotheses['swr'] ?? 4.0) / 100,
        rendementCapital: (_hypotheses['rendement'] ?? 3.0) / 100,
        inflation: (_hypotheses['inflation'] ?? 2.0) / 100,
        horizon: horizon,
        isMarried: _isMarried,
      );
      if (!mounted || requestId != _requestCounter) return;
      setState(() => _result = result);
      return;
    } catch (_) {
      try {
        final fallback = ArbitrageEngine.compareRenteVsCapital(
          capitalLppTotal: capitalTotal,
          capitalObligatoire: capitalOblig,
          capitalSurobligatoire: capitalSurob,
          renteAnnuelleProposee: renteAnnuelle,
          tauxConversionObligatoire: tcOblig,
          tauxConversionSurobligatoire: tcSurob,
          canton: _canton,
          ageRetraite: ageRetraite,
          tauxRetrait: (_hypotheses['swr'] ?? 4.0) / 100,
          rendementCapital: (_hypotheses['rendement'] ?? 3.0) / 100,
          inflation: (_hypotheses['inflation'] ?? 2.0) / 100,
          horizon: horizon,
          isMarried: _isMarried,
          dataSources: _dataSources,
          currentAge: currentAge,
          grossAnnualSalary: salary,
        );
        if (!mounted || requestId != _requestCounter) return;
        setState(() => _result = fallback);
      } catch (_) {
        if (!mounted || requestId != _requestCounter) return;
        setState(() => _hasError = true);
      }
    } finally {
      if (mounted && requestId == _requestCounter) {
        setState(() => _isLoading = false);
      }
    }
  }

  int get _ageRetraite => _ageRetraiteSlider.value.round();

  List<TrajectoireOption> _optionsAsAgeTrajectories(
    List<TrajectoireOption> options,
  ) {
    return options.map((option) {
      final mappedTrajectory = <YearlySnapshot>[];
      for (int i = 0; i < option.trajectory.length; i++) {
        final snap = option.trajectory[i];
        mappedTrajectory.add(
          YearlySnapshot(
            year: _ageRetraite + i,
            netPatrimony: snap.netPatrimony,
            annualCashflow: snap.annualCashflow,
            cumulativeTaxDelta: snap.cumulativeTaxDelta,
          ),
        );
      }
      return TrajectoireOption(
        id: option.id,
        label: option.label,
        trajectory: mappedTrajectory,
        terminalValue: option.terminalValue,
        cumulativeTaxImpact: option.cumulativeTaxImpact,
      );
    }).toList();
  }

  // =====================================================================
  //  BUILD — V2 DECISION CANVAS
  // =====================================================================

  @override
  Widget build(BuildContext context) {
    final chartOptions = _result == null
        ? const <TrajectoireOption>[]
        : _optionsAsAgeTrajectories(_result!.options);

    return Scaffold(
      backgroundColor: MintColors.porcelaine,
      body: CustomScrollView(
        slivers: [
          // -- SliverAppBar --
          SliverAppBar(
            pinned: true,
            backgroundColor: MintColors.porcelaine,
            foregroundColor: MintColors.textPrimary,
            surfaceTintColor: MintColors.porcelaine,
            title: Text(
              S.of(context)!.renteVsCapitalAppBarTitle,
              style: MintTextStyles.headlineMedium(),
            ),
          ),

          // -- Content --
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: MintSpacing.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: MintSpacing.md),

                // ====================================================
                //  BLOC 1 — DECISION HERO
                // ====================================================
                _buildDecisionHero(),
                const SizedBox(height: MintSpacing.xl),

                // ====================================================
                //  BLOC 2 — CHOICE CARDS
                // ====================================================
                _buildChoiceCards(),
                const SizedBox(height: MintSpacing.xl),

                // -- Loading / Error --
                if (_isLoading && _result == null)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: MintSpacing.lg),
                    child: Center(child: CircularProgressIndicator()),
                  ),

                if (_hasError && _result == null)
                  _buildErrorBanner(),

                if (_result != null) ...[
                  // ====================================================
                  //  BLOC 3 — CONSEQUENCE COMPARISON
                  // ====================================================
                  _buildConsequenceHero(),
                  const SizedBox(height: MintSpacing.lg),

                  // ====================================================
                  //  BLOC 4 — SIGNAL ROWS (comparison)
                  // ====================================================
                  _buildSignalRows(),
                  const SizedBox(height: MintSpacing.lg),

                  // ====================================================
                  //  BLOC 5 — CONFIDENCE NOTICE
                  // ====================================================
                  _buildConfidenceNotice(),
                  const SizedBox(height: MintSpacing.xl),
                ],

                // ====================================================
                //  BLOC 6 — FAST ESTIMATE INPUTS
                // ====================================================
                _buildFastEstimateSection(),
                const SizedBox(height: MintSpacing.lg),

                // ====================================================
                //  BLOC 7 — CTA PILL
                // ====================================================
                _buildCtaPill(),
                const SizedBox(height: MintSpacing.xl),

                // ====================================================
                //  BLOC 8 — ADVANCED DISCLOSURE
                // ====================================================
                _buildAdvancedDisclosure(),
                const SizedBox(height: MintSpacing.xl),

                if (_result != null) ...[
                  // ====================================================
                  //  BLOC 9 — EXPLORER (chart + life expectancy)
                  // ====================================================
                  _buildExplorerBloc(chartOptions),
                  const SizedBox(height: MintSpacing.lg),

                  // ====================================================
                  //  BLOC 10 — EDUCATIONAL CARDS
                  // ====================================================
                  _buildEducationalCards(),
                  const SizedBox(height: MintSpacing.lg),

                  // ====================================================
                  //  BLOC 11 — AFFINER (hypotheses + impact + tornado)
                  // ====================================================
                  _buildAffinerBloc(),
                  const SizedBox(height: MintSpacing.lg),

                  // ====================================================
                  //  BLOC 12 — DISCLAIMER
                  // ====================================================
                  _buildDisclaimerCard(),
                  const SizedBox(height: MintSpacing.xl),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  //  BLOC 1 — DECISION HERO
  // =====================================================================

  Widget _buildDecisionHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.renteVsCapitalV2Title,
          style: MintTextStyles.displayMedium().copyWith(
            fontSize: 32,
            height: 1.1,
          ),
        ),
        const SizedBox(height: MintSpacing.sm),
        Text(
          S.of(context)!.renteVsCapitalV2Subtitle,
          style: MintTextStyles.bodyLarge(color: MintColors.textSecondary)
              .copyWith(fontSize: 17, height: 1.4),
        ),
      ],
    );
  }

  // =====================================================================
  //  BLOC 2 — CHOICE CARDS
  // =====================================================================

  Widget _buildChoiceCards() {
    return Column(
      children: [
        MintChoiceCard(
          title: S.of(context)!.renteVsCapitalRenteLabel,
          subtitle: S.of(context)!.renteVsCapitalChoiceRenteSubtitle,
          selected: _selectedOutcome == _OutcomeMode.rente,
          selectedColor: MintColors.saugeClaire,
          onTap: () => setState(() => _selectedOutcome = _OutcomeMode.rente),
        ),
        const SizedBox(height: MintSpacing.sm),
        MintChoiceCard(
          title: S.of(context)!.renteVsCapitalCapitalLabel,
          subtitle: S.of(context)!.renteVsCapitalChoiceCapitalSubtitle,
          selected: _selectedOutcome == _OutcomeMode.capital,
          selectedColor: MintColors.pecheDouce,
          onTap: () => setState(() => _selectedOutcome = _OutcomeMode.capital),
        ),
        const SizedBox(height: MintSpacing.sm),
        MintChoiceCard(
          title: S.of(context)!.renteVsCapitalMixteLabel,
          subtitle: S.of(context)!.renteVsCapitalChoiceMixteSubtitle,
          selected: _selectedOutcome == _OutcomeMode.mixte,
          selectedColor: MintColors.bleuAir,
          onTap: () => setState(() => _selectedOutcome = _OutcomeMode.mixte),
        ),
      ],
    );
  }

  // =====================================================================
  //  BLOC 3 — CONSEQUENCE HERO (adapts to selected outcome)
  // =====================================================================

  Widget _buildConsequenceHero() {
    final r = _result!;

    // Compute total capital from inputs for net-after-tax display
    final capitalTotal = _inputMode == _InputMode.estimate
        ? (double.tryParse(_lppTotalCtrl.text.replaceAll("'", '')) ?? 350000)
        : (double.tryParse(_capitalObligCtrl.text.replaceAll("'", '')) ?? 500000) +
          (double.tryParse(_capitalSurobCtrl.text.replaceAll("'", '')) ?? 150000);
    final capitalNet = r.isProjected ? r.capitalProjecte - r.impotRetraitCapital : capitalTotal - r.impotRetraitCapital;

    // For mixte: estimate surobligatoire portion (30% of total in estimate mode)
    final capitalSurob = _inputMode == _InputMode.estimate
        ? capitalTotal * 0.3
        : (double.tryParse(_capitalSurobCtrl.text.replaceAll("'", '')) ?? 150000);
    final surobNet = capitalSurob - (capitalTotal > 0 ? r.impotRetraitCapital * capitalSurob / capitalTotal : 0);

    switch (_selectedOutcome) {
      case _OutcomeMode.rente:
        return MintResultHeroCard(
          eyebrow: S.of(context)!.renteVsCapitalConsequenceRenteEyebrow,
          primaryValue: formatChfWithPrefix(r.renteNetMensuelle),
          primaryLabel: S.of(context)!.renteVsCapitalPerMonthForLife,
          narrative: S.of(context)!.renteVsCapitalConsequenceRenteNarrative,
          accentColor: MintColors.textPrimary,
          tone: MintSurfaceTone.sauge,
        );
      case _OutcomeMode.capital:
        return MintResultHeroCard(
          eyebrow: S.of(context)!.renteVsCapitalConsequenceCapitalEyebrow,
          primaryValue: formatChfWithPrefix(capitalNet),
          primaryLabel: S.of(context)!.renteVsCapitalNetAfterTax,
          secondaryValue: formatChfWithPrefix(r.capitalRetraitMensuel),
          secondaryLabel: S.of(context)!.renteVsCapitalPerMonth,
          narrative: S.of(context)!.renteVsCapitalConsequenceCapitalNarrative,
          accentColor: MintColors.textPrimary,
          tone: MintSurfaceTone.peche,
        );
      case _OutcomeMode.mixte:
        return MintResultHeroCard(
          eyebrow: S.of(context)!.renteVsCapitalConsequenceMixteEyebrow,
          primaryValue: formatChfWithPrefix(r.renteNetMensuelle),
          primaryLabel: S.of(context)!.renteVsCapitalConsequenceMixteRenteLabel,
          secondaryValue: formatChfWithPrefix(surobNet),
          secondaryLabel: S.of(context)!.renteVsCapitalConsequenceMixteCapitalLabel,
          narrative: S.of(context)!.renteVsCapitalConsequenceMixteNarrative,
          accentColor: MintColors.textPrimary,
          tone: MintSurfaceTone.bleu,
        );
    }
  }

  // =====================================================================
  //  BLOC 4 — SIGNAL ROWS
  // =====================================================================

  Widget _buildSignalRows() {
    final r = _result!;
    final renteMois = r.renteNetMensuelle;
    final capitalMois = r.capitalRetraitMensuel;

    // Revenu mensuel
    final revenuValue = _selectedOutcome == _OutcomeMode.rente
        ? formatChfWithPrefix(renteMois)
        : _selectedOutcome == _OutcomeMode.capital
            ? formatChfWithPrefix(capitalMois)
            : '${formatChfWithPrefix(renteMois)} + ${formatChfWithPrefix(capitalMois)}';

    // Fiscalite
    final fiscalValue = _selectedOutcome == _OutcomeMode.rente
        ? '~${formatChfWithPrefix(r.impotCumulRente)}'
        : _selectedOutcome == _OutcomeMode.capital
            ? '~${formatChfWithPrefix(r.impotRetraitCapital)}'
            : '~${formatChfWithPrefix(r.impotCumulRente * 0.7 + r.impotRetraitCapital * 0.3)}';

    // Transmission
    final transmissionValue = _selectedOutcome == _OutcomeMode.capital
        ? S.of(context)!.renteVsCapitalTransmissionCapitalValue
        : _isMarried
            ? S.of(context)!.renteVsCapitalTransmissionRenteMarried
            : S.of(context)!.renteVsCapitalTransmissionRenteSingle;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: const EdgeInsets.symmetric(
        horizontal: MintSpacing.lg,
        vertical: MintSpacing.sm,
      ),
      child: Column(
        children: [
          MintSignalRow(
            label: S.of(context)!.renteVsCapitalSignalRevenu,
            value: revenuValue,
          ),
          Divider(
            color: MintColors.border.withValues(alpha: 0.2),
            height: 1,
          ),
          MintSignalRow(
            label: S.of(context)!.renteVsCapitalSignalFiscalite,
            value: fiscalValue,
          ),
          Divider(
            color: MintColors.border.withValues(alpha: 0.2),
            height: 1,
          ),
          MintSignalRow(
            label: S.of(context)!.renteVsCapitalSignalTransmission,
            value: transmissionValue,
          ),
          // AVS complement if available
          if (_avsRenteMensuelle != null && _avsRenteMensuelle! > 0) ...[
            Divider(
              color: MintColors.border.withValues(alpha: 0.2),
              height: 1,
            ),
            MintSignalRow(
              label: 'AVS',
              value: S.of(context)!.renteVsCapitalAvsAmount(
                formatChf(_avsRenteMensuelle!),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // =====================================================================
  //  BLOC 5 — CONFIDENCE NOTICE
  // =====================================================================

  Widget _buildConfidenceNotice() {
    final r = _result!;
    final confidence = r.confidenceScore.round();
    final isLow = confidence < 50 || _hasEstimatedValues;

    return MintConfidenceNotice(
      percent: confidence,
      message: isLow
          ? S.of(context)!.renteVsCapitalConfidenceNoticeLow
          : S.of(context)!.renteVsCapitalConfidenceNoticeHigh,
      ctaLabel: isLow ? S.of(context)!.renteVsCapitalConfidenceCta : null,
      onTap: isLow
          ? () => setState(() => _advancedExpanded = true)
          : null,
    );
  }

  // =====================================================================
  //  BLOC 6 — FAST ESTIMATE INPUTS
  // =====================================================================

  Widget _buildFastEstimateSection() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context)!.renteVsCapitalFastEstimateTitle,
            style: MintTextStyles.titleMedium(),
          ),
          const SizedBox(height: MintSpacing.md),

          // Age
          _buildLabeledField(
            controller: _ageCtrl,
            label: S.of(context)!.renteVsCapitalAge,
            fieldName: 'age',
          ),
          const SizedBox(height: MintSpacing.sm),

          // Retirement age slider
          _buildRetirementAgeSlider(),
          const SizedBox(height: MintSpacing.sm),

          // Salary
          _buildLabeledField(
            controller: _salaryCtrl,
            label: S.of(context)!.renteVsCapitalSalary,
            fieldName: 'salaire_brut',
          ),
        ],
      ),
    );
  }

  // =====================================================================
  //  BLOC 7 — CTA PILL
  // =====================================================================

  Widget _buildCtaPill() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _recalculate,
        style: ElevatedButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: MintColors.white,
          shape: const StadiumBorder(),
          elevation: 0,
          textStyle: MintTextStyles.titleMedium(color: MintColors.white)
              .copyWith(fontWeight: FontWeight.w700),
        ),
        child: Text(S.of(context)!.renteVsCapitalCtaCompare),
      ),
    );
  }

  // =====================================================================
  //  BLOC 8 — ADVANCED DISCLOSURE
  // =====================================================================

  Widget _buildAdvancedDisclosure() {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: _advancedExpanded,
          onExpansionChanged: (v) => setState(() {
            _advancedExpanded = v;
            if (v) _inputMode = _InputMode.certificate;
          }),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: MintSpacing.lg,
            vertical: MintSpacing.xs,
          ),
          childrenPadding: const EdgeInsets.fromLTRB(
            MintSpacing.lg, 0, MintSpacing.lg, MintSpacing.lg,
          ),
          title: Text(
            S.of(context)!.renteVsCapitalAdvancedDisclosure,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w600),
          ),
          children: [
            // LPP total
            _buildLabeledField(
              controller: _lppTotalCtrl,
              label: S.of(context)!.renteVsCapitalLppTotal,
              fieldName: 'lpp_total',
            ),
            const SizedBox(height: MintSpacing.sm),

            // Certificate mode fields
            _buildLabeledField(
              controller: _capitalObligCtrl,
              label: S.of(context)!.renteVsCapitalLppOblig,
              fieldName: 'lpp_obligatoire',
            ),
            const SizedBox(height: MintSpacing.sm),
            _buildLabeledField(
              controller: _capitalSurobCtrl,
              label: S.of(context)!.renteVsCapitalLppSurob,
              fieldName: 'lpp_surobligatoire',
            ),
            const SizedBox(height: MintSpacing.sm),
            _buildLabeledField(
              controller: _renteCtrl,
              label: S.of(context)!.renteVsCapitalRenteProposed,
              fieldName: 'rente_projetee',
            ),
            const SizedBox(height: MintSpacing.sm),
            Row(
              children: [
                Expanded(
                  child: _buildLabeledField(
                    controller: _tcObligCtrl,
                    label: S.of(context)!.renteVsCapitalTcOblig,
                    isPercent: true,
                  ),
                ),
                const SizedBox(width: MintSpacing.sm),
                Expanded(
                  child: _buildLabeledField(
                    controller: _tcSurobCtrl,
                    label: S.of(context)!.renteVsCapitalTcSurob,
                    isPercent: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: MintSpacing.md),

            // Rachat LPP
            _buildRachatSection(),
            const SizedBox(height: MintSpacing.sm),

            // EPL
            _buildEplSection(),
            const SizedBox(height: MintSpacing.md),

            // Canton + Married
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(S.of(context)!.renteVsCapitalCanton, style: _labelStyle),
                      const SizedBox(height: MintSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: MintSpacing.sm),
                        decoration: BoxDecoration(
                          color: MintColors.surface,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButton<String>(
                          value: _canton,
                          isExpanded: true,
                          underline: const SizedBox.shrink(),
                          items: sortedCantonCodes.map((code) {
                            final name = cantonFullNames[code] ?? code;
                            return DropdownMenuItem(
                              value: code,
                              child: Text('$code - $name',
                                  style: MintTextStyles.bodyMedium()),
                            );
                          }).toList(),
                          onChanged: (v) {
                            if (v != null) { _canton = v; _recalculate(); }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MintSpacing.md),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(S.of(context)!.renteVsCapitalMarried, style: _labelStyle),
                    const SizedBox(height: MintSpacing.xs),
                    Semantics(
                      label: S.of(context)!.renteVsCapitalMarried,
                      toggled: _isMarried,
                      child: Switch(
                        value: _isMarried,
                        activeTrackColor: MintColors.primary,
                        onChanged: (v) { _isMarried = v; _recalculate(); },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // =====================================================================
  //  ERROR BANNER
  // =====================================================================

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(MintSpacing.md),
      margin: const EdgeInsets.only(bottom: MintSpacing.md),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: MintColors.error, size: 20),
          const SizedBox(width: MintSpacing.sm),
          Expanded(child: Text(
            S.of(context)!.renteVsCapitalErrorRetry,
            style: MintTextStyles.bodySmall(color: MintColors.error),
          )),
        ],
      ),
    );
  }

  // =====================================================================
  //  RETIREMENT AGE SLIDER
  // =====================================================================

  Widget _buildRetirementAgeSlider() {
    return MintPremiumSlider(
      label: S.of(context)!.renteVsCapitalRetirementAge,
      value: _ageRetraiteSlider.value,
      min: 58,
      max: 70,
      divisions: 12,
      formatValue: (v) => S.of(context)!.renteVsCapitalAgeYears(v.round()),
      onChanged: (v) {
        _ageRetraiteSlider.value = v;
        _recalculate();
      },
    );
  }

  // =====================================================================
  //  LABELED FIELD
  // =====================================================================

  Widget _buildLabeledField({
    required TextEditingController controller,
    required String label,
    String? fieldName,
    bool isPercent = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: _labelStyle)),
            if (fieldName != null)
              FieldHelpTooltip(fieldName: fieldName),
          ],
        ),
        const SizedBox(height: MintSpacing.xs),
        TextField(
          controller: controller,
          keyboardType: isPercent
              ? const TextInputType.numberWithOptions(decimal: true)
              : TextInputType.number,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          inputFormatters: isPercent
              ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))]
              : [FilteringTextInputFormatter.digitsOnly],
          style: MintTextStyles.bodyLarge(color: MintColors.textPrimary).copyWith(
            fontSize: 15,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: MintColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: MintSpacing.md, vertical: 14,
            ),
          ),
          onChanged: (_) => _recalculate(),
        ),
      ],
    );
  }

  // =====================================================================
  //  EXPLORER BLOC (slider + chart fused)
  // =====================================================================

  Widget _buildExplorerBloc(List<TrajectoireOption> chartOptions) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Slider: "Et si je vis jusqu'a..."
          MintPremiumSlider(
            label: S.of(context)!.renteVsCapitalLifeExpectancy,
            value: _lifeExpectancy,
            min: 70,
            max: 100,
            divisions: 30,
            formatValue: (v) => S.of(context)!.renteVsCapitalAgeYears(v.round()),
            onChanged: (v) {
              setState(() => _lifeExpectancy = v);
              _recalculate();
            },
          ),
          _buildDeltaAtAge(_lifeExpectancy.round()),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.renteVsCapitalLifeExpectancyRef,
            style: MintTextStyles.labelSmall(),
          ),

          const SizedBox(height: MintSpacing.lg),

          // Chart
          Text(
            S.of(context)!.renteVsCapitalChartTitle,
            style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.renteVsCapitalChartSubtitle,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
              fontSize: 12,
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          TrajectoryComparisonChart(
            options: chartOptions,
            breakevenYear: _result!.breakevenYear,
            selectedAxisLabel: S.of(context)!.renteVsCapitalChartAxisLabel,
          ),
        ],
      ),
    );
  }

  Widget _buildDeltaAtAge(int age) {
    if (_result == null) return const SizedBox.shrink();
    final yearIndex = age - _ageRetraite;
    if (yearIndex < 0) return const SizedBox.shrink();

    final renteOption = _result!.options.firstWhere(
      (o) => o.id == 'full_rente', orElse: () => _result!.options.first,
    );
    final capitalOption = _result!.options.firstWhere(
      (o) => o.id == 'full_capital', orElse: () => _result!.options.last,
    );

    if (yearIndex >= renteOption.trajectory.length ||
        yearIndex >= capitalOption.trajectory.length) {
      return Text(
        S.of(context)!.renteVsCapitalBeyondHorizon(age),
        style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
      );
    }

    final renteVal = renteOption.trajectory[yearIndex].netPatrimony;
    final capitalVal = capitalOption.trajectory[yearIndex].netPatrimony;
    final delta = capitalVal - renteVal;
    final winner = delta > 0
        ? S.of(context)!.renteVsCapitalCapitalLabel
        : S.of(context)!.renteVsCapitalRenteLabel;
    final winnerColor = delta > 0 ? MintColors.retirementLpp : MintColors.retirementAvs;

    return Container(
      padding: const EdgeInsets.all(MintSpacing.sm),
      decoration: BoxDecoration(
        color: winnerColor.withAlpha(10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            delta > 0 ? Icons.trending_up : Icons.trending_down,
            color: winnerColor, size: 20,
          ),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                  text: S.of(context)!.renteVsCapitalDeltaAtAge(age),
                  style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
                ),
                TextSpan(
                  text: '$winner = +${formatChf(delta.abs())} ',
                  style: MintTextStyles.bodySmall(color: winnerColor).copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: S.of(context)!.renteVsCapitalDeltaAdvance,
                  style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  //  EDUCATIONAL CARDS (3 before/after)
  // =====================================================================

  Widget _buildEducationalCards() {
    final r = _result!;
    final inflation = (_hypotheses['inflation'] ?? 2.0) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.renteVsCapitalEducationalTitle,
          style: MintTextStyles.titleMedium(),
        ),
        const SizedBox(height: MintSpacing.sm),

        // Card 1: Fiscalite
        _educationalCard(
          icon: Icons.receipt_long,
          iconColor: MintColors.pillarLpp,
          title: S.of(context)!.renteVsCapitalFiscalTitle,
          leftTitle: S.of(context)!.renteVsCapitalRenteLabel,
          leftSubtitle: S.of(context)!.renteVsCapitalFiscalLeftSubtitle,
          leftValue: '~${formatChf(r.impotCumulRente)}',
          leftDetail: S.of(context)!.renteVsCapitalFiscalOver30years,
          rightTitle: S.of(context)!.renteVsCapitalCapitalLabel,
          rightSubtitle: S.of(context)!.renteVsCapitalFiscalRightSubtitle,
          rightValue: '~${formatChf(r.impotRetraitCapital)}',
          rightDetail: S.of(context)!.renteVsCapitalFiscalAtRetrait,
          bottomText: r.impotCumulRente > r.impotRetraitCapital
              ? S.of(context)!.renteVsCapitalFiscalCapitalSaves(
                  formatChf(r.impotCumulRente - r.impotRetraitCapital),
                )
              : S.of(context)!.renteVsCapitalFiscalRenteSaves(
                  formatChf(r.impotRetraitCapital - r.impotCumulRente),
                ),
        ),
        const SizedBox(height: MintSpacing.sm),

        // Card 2: Inflation
        _educationalCard(
          icon: Icons.trending_down,
          iconColor: MintColors.warning,
          title: S.of(context)!.renteVsCapitalInflationTitle,
          leftTitle: S.of(context)!.renteVsCapitalInflationToday,
          leftSubtitle: '',
          leftValue: formatChf(r.renteNetMensuelle),
          leftDetail: S.of(context)!.renteVsCapitalPerMonth,
          rightTitle: S.of(context)!.renteVsCapitalInflationIn20Years,
          rightSubtitle: S.of(context)!.renteVsCapitalInflationPurchasingPower,
          rightValue: formatChf(r.renteReelleAn20 / 12),
          rightDetail: S.of(context)!.renteVsCapitalPerMonth,
          bottomText: S.of(context)!.renteVsCapitalInflationBottomText(
            ((1 - 1 / math.pow(1 + inflation, 20)) * 100).round(),
          ),
        ),
        const SizedBox(height: MintSpacing.sm),

        // Card 3: Transmission
        _educationalCard(
          icon: Icons.family_restroom,
          iconColor: MintColors.primary,
          title: S.of(context)!.renteVsCapitalTransmissionTitle,
          leftTitle: S.of(context)!.renteVsCapitalRenteLabel,
          leftSubtitle: _isMarried
              ? S.of(context)!.renteVsCapitalTransmissionLeftMarried
              : S.of(context)!.renteVsCapitalTransmissionLeftSingle,
          leftValue: _isMarried
              ? S.of(context)!.renteVsCapitalTransmissionLeftValueMarried(
                  formatChf(r.renteSurvivant / 12),
                )
              : S.of(context)!.renteVsCapitalTransmissionLeftValueSingle,
          leftDetail: _isMarried
              ? S.of(context)!.renteVsCapitalTransmissionLeftDetailMarried
              : S.of(context)!.renteVsCapitalTransmissionLeftDetailSingle,
          rightTitle: S.of(context)!.renteVsCapitalCapitalLabel,
          rightSubtitle: S.of(context)!.renteVsCapitalTransmissionRightSubtitle,
          rightValue: S.of(context)!.renteVsCapitalTransmissionRightValue,
          rightDetail: S.of(context)!.renteVsCapitalTransmissionRightDetail,
          bottomText: _isMarried
              ? S.of(context)!.renteVsCapitalTransmissionBottomMarried
              : S.of(context)!.renteVsCapitalTransmissionBottomSingle,
        ),
      ],
    );
  }

  Widget _educationalCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String leftTitle,
    required String leftSubtitle,
    required String leftValue,
    required String leftDetail,
    required String rightTitle,
    required String rightSubtitle,
    required String rightValue,
    required String rightDetail,
    required String bottomText,
  }) {
    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(title, style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
                  fontWeight: FontWeight.w700,
                )),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Before/After comparison
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(leftTitle, style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                    if (leftSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(leftSubtitle, style: MintTextStyles.micro()),
                    ],
                    const SizedBox(height: MintSpacing.xs),
                    Text(leftValue, style: MintTextStyles.titleMedium(), textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(leftDetail, style: MintTextStyles.micro()),
                  ],
                ),
              ),
              Container(width: 1, height: 60, color: MintColors.lightBorder),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(rightTitle, style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
                      fontWeight: FontWeight.w600,
                    )),
                    if (rightSubtitle.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(rightSubtitle, style: MintTextStyles.micro()),
                    ],
                    const SizedBox(height: MintSpacing.xs),
                    Text(rightValue, style: MintTextStyles.titleMedium(), textAlign: TextAlign.center),
                    const SizedBox(height: 2),
                    Text(rightDetail, style: MintTextStyles.micro()),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          // Bottom insight
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withAlpha(10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              bottomText,
              style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(
                fontSize: 12, height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  //  AFFINER BLOC (hypotheses + impact cards + tornado)
  // =====================================================================

  Widget _buildAffinerBloc() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.renteVsCapitalAffinerTitle,
          style: MintTextStyles.titleMedium(),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          S.of(context)!.renteVsCapitalAffinerSubtitle,
          style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
            fontSize: 12,
          ),
        ),
        const SizedBox(height: MintSpacing.md),

        // Hypothesis sliders
        HypothesisEditorWidget(
          hypotheses: [
            HypothesisConfig(
              key: 'rendement',
              label: S.of(context)!.renteVsCapitalHypRendement,
              min: 0, max: 8, divisions: 16, defaultValue: 3,
            ),
            HypothesisConfig(
              key: 'swr',
              label: S.of(context)!.renteVsCapitalHypSwr,
              min: 2, max: 6, divisions: 8, defaultValue: 4,
            ),
            HypothesisConfig(
              key: 'inflation',
              label: S.of(context)!.renteVsCapitalHypInflation,
              min: 0, max: 4, divisions: 8, defaultValue: 2,
            ),
          ],
          values: _hypotheses,
          onChanged: (updated) {
            _hypotheses = updated;
            _recalculate();
          },
        ),
        const SizedBox(height: MintSpacing.lg),

        // Impact cards
        _buildImpactCards(),
        const SizedBox(height: MintSpacing.sm),

        // Tornado in ExpansionTile
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: MintSpacing.sm),
          title: Text(
            S.of(context)!.renteVsCapitalTornadoToggle,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          children: [ArbitrageTornadoSection(result: _result!)],
        ),
        const SizedBox(height: MintSpacing.md),

        // Hypotheses detail
        _buildHypothesesSection(),
      ],
    );
  }

  // =====================================================================
  //  IMPACT CARDS
  // =====================================================================

  Widget _buildImpactCards() {
    if (_result == null) return const SizedBox.shrink();
    final variables = _result!.tornadoVariables;
    if (variables.isEmpty) return const SizedBox.shrink();

    final top = variables.where((v) => v.swing > 50).take(4).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    final maxSwing = top.first.swing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.renteVsCapitalImpactTitle,
          style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
        ),
        const SizedBox(height: MintSpacing.xs),
        Text(
          S.of(context)!.renteVsCapitalImpactSubtitle,
          style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
            fontSize: 12,
          ),
        ),
        const SizedBox(height: MintSpacing.sm),
        for (int i = 0; i < top.length; i++) ...[
          _impactCard(i + 1, top[i], maxSwing),
          if (i < top.length - 1) const SizedBox(height: MintSpacing.sm),
        ],
      ],
    );
  }

  Widget _impactCard(int rank, ArbitrageTornadoVariable v, double maxSwing) {
    final barFraction = maxSwing > 0 ? v.swing / maxSwing : 0.0;
    final lowDelta = v.lowValue - v.baseValue;
    final highDelta = v.highValue - v.baseValue;

    return MintSurface(
      tone: MintSurfaceTone.blanc,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: MintColors.primary.withAlpha(15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text('#$rank', style: MintTextStyles.micro(color: MintColors.primary).copyWith(
                    fontWeight: FontWeight.w700, fontStyle: FontStyle.normal,
                  )),
                ),
              ),
              const SizedBox(width: MintSpacing.sm),
              Expanded(
                child: Text(v.label, style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(
                  fontWeight: FontWeight.w600,
                )),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          // Impact bar
          Semantics(
            label: '${v.label}: ${_formatDelta(lowDelta)} / ${_formatDelta(highDelta)}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: barFraction,
                minHeight: 6,
                backgroundColor: MintColors.border.withAlpha(60),
                valueColor: AlwaysStoppedAnimation(MintColors.primary.withAlpha(180)),
              ),
            ),
          ),
          const SizedBox(height: MintSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${v.lowLabel} : ${_formatDelta(lowDelta)}',
                style: MintTextStyles.labelSmall(
                  color: lowDelta < 0
                      ? MintColors.danger
                      : MintColors.success,
                ),
              ),
              Text(
                '${v.highLabel} : ${_formatDelta(highDelta)}',
                style: MintTextStyles.labelSmall(
                  color: highDelta >= 0
                      ? MintColors.success
                      : MintColors.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================================
  //  HYPOTHESES EXPANDABLE
  // =====================================================================

  Widget _buildHypothesesSection() {
    if (_result == null) return const SizedBox.shrink();
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: MintSpacing.sm),
      title: Text(
        S.of(context)!.renteVsCapitalHypothesesTitle,
        style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(
          fontWeight: FontWeight.w600,
        ),
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
                  child: Text(h, style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(
                    fontSize: 12, height: 1.4,
                  )),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // =====================================================================
  //  DISCLAIMER CARD
  // =====================================================================

  Widget _buildDisclaimerCard() {
    if (_result == null) return const SizedBox.shrink();
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: MintSpacing.sm),
              Text(S.of(context)!.renteVsCapitalWarning,
                style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
                  fontSize: 12, fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(_result!.disclaimer,
            style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(
              height: 1.4,
            ),
          ),
          const SizedBox(height: MintSpacing.sm),
          Text(
            S.of(context)!.renteVsCapitalSources(_result!.sources.join(' | ')),
            style: MintTextStyles.micro(),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  //  RACHAT SECTION
  // =====================================================================

  Widget _buildRachatSection() {
    final maxRachat = double.tryParse(_rachatMaxCtrl.text.replaceAll("'", '')) ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.of(context)!.renteVsCapitalRachatLabel,
                style: _labelStyle,
              ),
            ),
            if (maxRachat > 0)
              Text(
                S.of(context)!.renteVsCapitalRachatMax(formatChf(maxRachat)),
                style: MintTextStyles.labelSmall(),
              ),
          ],
        ),
        const SizedBox(height: MintSpacing.xs),
        TextField(
          controller: _rachatAnnuelCtrl,
          keyboardType: TextInputType.number,
          onTapOutside: (_) => FocusScope.of(context).unfocus(),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
          decoration: InputDecoration(
            hintText: S.of(context)!.renteVsCapitalRachatHint,
            hintStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted),
            prefixText: 'CHF ',
            filled: true,
            fillColor: MintColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            suffixIcon: Tooltip(
              message: S.of(context)!.renteVsCapitalRachatTooltip,
              child: const Icon(Icons.info_outline, size: 18, color: MintColors.textMuted),
            ),
          ),
          onChanged: (_) => _recalculate(),
        ),
      ],
    );
  }

  // =====================================================================
  //  EPL SECTION
  // =====================================================================

  Widget _buildEplSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                S.of(context)!.renteVsCapitalEplLabel,
                style: _labelStyle,
              ),
            ),
            Semantics(
              label: S.of(context)!.renteVsCapitalEplLabel,
              toggled: _hasEpl,
              child: Switch(
                value: _hasEpl,
                activeTrackColor: MintColors.primary,
                onChanged: (v) => setState(() { _hasEpl = v; _recalculate(); }),
              ),
            ),
          ],
        ),
        if (_hasEpl) ...[
          const SizedBox(height: MintSpacing.xs),
          TextField(
            controller: _eplAmountCtrl,
            keyboardType: TextInputType.number,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary),
            decoration: InputDecoration(
              hintText: S.of(context)!.renteVsCapitalEplHint,
              hintStyle: MintTextStyles.bodyMedium(color: MintColors.textMuted),
              prefixText: 'CHF ',
              filled: true,
              fillColor: MintColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              suffixIcon: Tooltip(
                message: S.of(context)!.renteVsCapitalEplTooltip,
                child: const Icon(Icons.info_outline, size: 18, color: MintColors.textMuted),
              ),
            ),
            onChanged: (_) => _recalculate(),
          ),
          const SizedBox(height: MintSpacing.xs),
          Text(
            S.of(context)!.renteVsCapitalEplLegalRef,
            style: MintTextStyles.micro(),
          ),
        ],
      ],
    );
  }

  // =====================================================================
  //  FORMATTING HELPERS
  // =====================================================================

  static final _labelStyle = MintTextStyles.bodySmall(color: MintColors.textSecondary);

  static String _formatDelta(double delta) {
    final abs = delta.abs();
    String formatted;
    if (abs >= 1000000) {
      formatted = '${(abs / 1000000).toStringAsFixed(1)}M';
    } else if (abs >= 10000) {
      formatted = '${(abs / 1000).round()}k';
    } else {
      formatted = formatChf(abs);
    }
    return '${delta >= 0 ? '+' : '-'}$formatted';
  }
}
