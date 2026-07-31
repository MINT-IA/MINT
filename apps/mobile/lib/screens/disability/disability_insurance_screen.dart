import 'package:flutter/material.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/domain/disability_gap_calculator.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/disability_scorecard_widget.dart';
import 'package:mint_mobile/widgets/coach/franchise_cost_widget.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';
import 'package:mint_mobile/widgets/premium/mint_premium_slider.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

// ────────────────────────────────────────────────────────────
//  P4 — COUVERTURE INVALIDITÉ
//  Bulletin scolaire (E) + Franchise LAMal (D)
//  Source : LAMal art. 64-64a, LAVS, LPP art. 23-26
// ────────────────────────────────────────────────────────────

class DisabilityInsuranceScreen extends StatefulWidget {
  const DisabilityInsuranceScreen({super.key});

  @override
  State<DisabilityInsuranceScreen> createState() =>
      _DisabilityInsuranceScreenState();
}

class _DisabilityInsuranceScreenState extends State<DisabilityInsuranceScreen> {
  double _grossMonthly = 8333;
  double _savings = 30000;
  bool _hasIjm = true;
  bool _hasPrivateInsurance = false;
  bool _seededFromProfile = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededFromProfile) return;
    _seededFromProfile = true;
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile == null) return;
    setState(() {
      final salary = profile.salaireBrutMensuel;
      if (salary > 0) _grossMonthly = salary.clamp(2000.0, 25000.0);
      final savings = profile.patrimoine.epargneLiquide;
      if (savings > 0) _savings = savings.clamp(0.0, 500000.0);
    });
  }

  // ── Scorecard items ───────────────────────────────────────

  // Bulletin de couverture via l'étalon unique DisabilityService (fin du
  // doublon 3-têtes, cf. V2-2-INVENTORY.md). L'assurance privée personnelle est
  // prise en compte via `hasPrivateInsurance`. Les libellés restent composés ici
  // (i18n ARB) : le service ne retourne jamais de texte FR.
  DisabilityCoverage get _coverage => DisabilityService.coverage(
        grossMonthly: _grossMonthly,
        savings: _savings,
        hasIjm: _hasIjm,
        hasPrivateInsurance: _hasPrivateInsurance,
      );

  List<CoverageItem> get _scorecardItems {
    final s = S.of(context)!;
    final cov = _coverage;

    final String ijmDetail;
    if (_hasIjm) {
      ijmDetail = s.disabilityGapIjmCoverage;
    } else if (_hasPrivateInsurance) {
      ijmDetail = s.disabilityInsPrivateCoverage;
    } else {
      ijmDetail = s.disabilityInsNoCoverage;
    }

    return [
      CoverageItem(
        label: s.disabilityGapApgLabel,
        grade: cov.ijmGrade,
        detail: ijmDetail,
        legalRef: 'LAMal art. 67-77',
        emoji: '🛡️',
      ),
      CoverageItem(
        label: s.disabilityGapAiLabel,
        grade: cov.aiGrade,
        detail: s.disabilityGapAiDetail(
            formatChf(DisabilityService.aiRenteFullMonthly)),
        legalRef: 'LAI art. 28',
        emoji: '🏛️',
      ),
      CoverageItem(
        label: s.disabilityGapLppLabel,
        grade: cov.lppGrade,
        detail: cov.hasLpp
            ? s.disabilityGapLppCovered
            : s.disabilityGapLppNotCovered,
        legalRef: 'LPP art. 23-26',
        emoji: '🏦',
      ),
      CoverageItem(
        label: s.disabilityGapSavingsLabel,
        grade: cov.savingsGrade,
        detail: s.disabilityInsSavingsDetail(
            cov.reserveMonths.toStringAsFixed(1)),
        emoji: '💰',
      ),
    ];
  }

  String get _overallGrade => _coverage.overallGrade;

  double get _lifeDropPercent => _coverage.lifeDropPercent;

  // ── Franchise options ─────────────────────────────────────

  static const List<FranchiseOption> _franchiseOptions = [
    FranchiseOption(franchiseAmount: 300, monthlyPremiumSavings: 0),
    FranchiseOption(franchiseAmount: 500, monthlyPremiumSavings: 10),
    FranchiseOption(franchiseAmount: 1000, monthlyPremiumSavings: 25),
    FranchiseOption(franchiseAmount: 1500, monthlyPremiumSavings: 40),
    FranchiseOption(franchiseAmount: 2000, monthlyPremiumSavings: 60),
    FranchiseOption(franchiseAmount: 2500, monthlyPremiumSavings: 80),
  ];

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildInputsCard(),
                const SizedBox(height: 20),
                DisabilityScorecardWidget(
                  items: _scorecardItems,
                  overallGrade: _overallGrade,
                  lifeDropPercent: _lifeDropPercent,
                ),
                const SizedBox(height: 20),
                const FranchiseCostWidget(
                  options: _franchiseOptions,
                  initialConsultationsPerYear: 3,
                ),
                const SizedBox(height: 20),
                EduDisclaimer(
                  text: S.of(context)!.disabilityInsDisclaimer,
                ),
                const SizedBox(height: 8),
                EduLegalSources(
                  sources: S.of(context)!.disabilityInsSources,
                ),
              ]),
            ),
          ),
        ],
      ))),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: MintColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MintColors.blueDark, MintColors.blueMaterial900],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 40, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    S.of(context)!.disabilityInsTitle,
                    style: MintTextStyles.headlineMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    S.of(context)!.disabilityInsSubtitle,
                    style: MintTextStyles.labelSmall(color: MintColors.white70),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Semantics(
        header: true,
        child: Text(
          S.of(context)!.disabilityInsAppBarTitle,
          style: MintTextStyles.titleMedium(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildInputsCard() {
    return MintSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MintEntrance(child: Text(
            S.of(context)!.disabilityInsRefineSituation,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
          )),
          const SizedBox(height: 16),
          MintEntrance(delay: const Duration(milliseconds: 100), child: _buildSliderRow(
            label: S.of(context)!.disabilityInsGrossSalary,
            value: _grossMonthly,
            min: 2000,
            max: 25000,
            divisions: 46,
            format: (v) => "CHF ${formatChf(v)}",
            onChanged: (v) => setState(() => _grossMonthly = v),
          )),
          const SizedBox(height: 12),
          MintEntrance(delay: const Duration(milliseconds: 200), child: _buildSliderRow(
            label: S.of(context)!.disabilityInsSavings,
            value: _savings,
            min: 0,
            max: 200000,
            divisions: 40,
            format: (v) => "CHF ${formatChf(v)}",
            onChanged: (v) => setState(() => _savings = v),
          )),
          const SizedBox(height: 16),
          MintEntrance(delay: const Duration(milliseconds: 300), child: _buildToggleRow(
            label: S.of(context)!.disabilityInsIjmEmployer,
            value: _hasIjm,
            onChanged: (v) => setState(() => _hasIjm = v),
          )),
          const SizedBox(height: 8),
          MintEntrance(delay: const Duration(milliseconds: 400), child: _buildToggleRow(
            label: S.of(context)!.disabilityInsPrivateLossInsurance,
            value: _hasPrivateInsurance,
            onChanged: (v) => setState(() => _hasPrivateInsurance = v),
          )),
        ],
      ),
    );
  }

  Widget _buildSliderRow({
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String Function(double) format,
    required void Function(double) onChanged,
  }) {
    return MintPremiumSlider(
      label: label,
      value: value,
      min: min,
      max: max,
      divisions: divisions,
      formatValue: format,
      onChanged: onChanged,
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeTrackColor: MintColors.primary,
        ),
      ],
    );
  }
}
