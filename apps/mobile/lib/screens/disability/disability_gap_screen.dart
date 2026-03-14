import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/disability_cliff_widget.dart';
import 'package:mint_mobile/widgets/coach/disability_countdown_widget.dart';
import 'package:mint_mobile/widgets/coach/disability_reset_widget.dart';
import 'package:mint_mobile/widgets/coach/disability_scorecard_widget.dart';
import 'package:mint_mobile/widgets/coach/edu_shared_widgets.dart';

// ────────────────────────────────────────────────────────────
//  P4 — ÉCRAN PRINCIPAL INVALIDITÉ
//  La Falaise (A) + Reset silencieux (B) + Countdown (F) + Bulletin (E)
//  Source : LAI art. 28, LPP art. 23-26, CO art. 324a, LPGA art. 19
// ────────────────────────────────────────────────────────────

class DisabilityGapScreen extends StatefulWidget {
  const DisabilityGapScreen({super.key});

  @override
  State<DisabilityGapScreen> createState() => _DisabilityGapScreenState();
}

class _DisabilityGapScreenState extends State<DisabilityGapScreen> {
  double _grossMonthly = 8333; // ~100k/an
  int _age = 45;
  double _savings = 30000;
  bool _hasIjm = true;
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
      final age = DateTime.now().year - profile.birthYear;
      _age = age.clamp(18, 64);
      final savings = profile.patrimoine.epargneLiquide;
      if (savings > 0) _savings = savings.clamp(0.0, 500000.0);
    });
  }

  // ── Calcul des actes (La Falaise) ─────────────────────────

  List<DisabilityAct> _buildActs(S s) {
    // Acte 1 : Employeur -- 80% salaire (CO art. 324a, duree variable)
    final act1Income = _grossMonthly * 0.80;

    // Acte 2 : IJM -- 80% si souscrite, 0 sinon (24 mois max)
    final act2Income = _hasIjm ? _grossMonthly * 0.80 : 0.0;

    // Acte 3 : AI + LPP (definitif)
    final annualGross = _grossMonthly * 12;
    double lppInvalidity = 0.0;
    if (annualGross >= lppSeuilEntree) {
      final coordinated = (annualGross - lppDeductionCoordination)
          .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
      lppInvalidity = coordinated * 0.40 / 12;
    }
    final act3Income = aiRenteEntiere + lppInvalidity;

    return [
      DisabilityAct(
        label: s.disabilityGapAct1Label,
        subtitle: s.disabilityGapAct1Subtitle,
        durationLabel: s.disabilityGapAct1Duration,
        monthlyIncome: act1Income,
        emoji: '\uD83D\uDFE2',
        color: MintColors.success,
        detail: s.disabilityGapAct1Detail,
      ),
      DisabilityAct(
        label: _hasIjm ? s.disabilityGapAct2LabelIjm : s.disabilityGapAct2LabelNoIjm,
        subtitle: _hasIjm
            ? s.disabilityGapAct2SubtitleIjm
            : s.disabilityGapAct2SubtitleNoIjm,
        durationLabel: s.disabilityGapAct2Duration,
        monthlyIncome: act2Income,
        emoji: _hasIjm ? '\uD83D\uDFE1' : '\uD83D\uDD34',
        color: _hasIjm ? MintColors.amber : MintColors.error,
        detail: _hasIjm
            ? s.disabilityGapAct2DetailIjm
            : s.disabilityGapAct2DetailNoIjm,
      ),
      DisabilityAct(
        label: s.disabilityGapAct3Label,
        subtitle: s.disabilityGapAct3Subtitle,
        durationLabel: s.disabilityGapAct3Duration,
        monthlyIncome: act3Income,
        emoji: '\uD83D\uDD34',
        color: MintColors.error,
        detail: s.disabilityGapAct3Detail(_fmtChf(aiRenteEntiere), _fmtChf(lppInvalidity), _fmtChf(act3Income)),
      ),
    ];
  }

  // ── Calcul Reset silencieux (LPP) ────────────────────────

  double get _lppCapitalBefore {
    final yearsToRetirement = (65 - _age).clamp(0, 40);
    final annualGross = _grossMonthly * 12;
    if (annualGross < lppSeuilEntree) return 0;
    final coordinated = (annualGross - lppDeductionCoordination)
        .clamp(lppSalaireCoordMin, lppSalaireCoordMax);
    final rate = getLppBonificationRate(_age);
    final annualContrib = coordinated * rate;
    // Simplified: flat contributions, 1% employer return
    return annualContrib * yearsToRetirement * 1.5; // growth factor approximation
  }

  double get _lppCapitalAfter {
    // 50% disability → 50% salary reduction
    final reducedGross = _grossMonthly * 12 * 0.5;
    final yearsToRetirement = (65 - _age).clamp(0, 40);
    if (reducedGross < lppSeuilEntree) return 0;
    final coordinated = (reducedGross - lppDeductionCoordination)
        .clamp(0.0, lppSalaireCoordMax);
    if (coordinated <= 0) return 0;
    final rate = getLppBonificationRate(_age);
    final annualContrib = coordinated * rate;
    return annualContrib * yearsToRetirement * 1.5;
  }

  // ── Calcul Bulletin scolaire ─────────────────────────────

  List<CoverageItem> _buildScorecardItems(S s) {
    // APG/IJM grade
    final ijmGrade = _hasIjm ? 'B+' : 'F';
    final ijmDetail = _hasIjm
        ? s.disabilityGapIjmDetailYes
        : s.disabilityGapIjmDetailNo;

    // AI grade (systemic -- everyone gets it)
    const aiGrade = 'C';

    // LPP grade
    final annualGross = _grossMonthly * 12;
    final hasLpp = annualGross >= lppSeuilEntree;
    final lppGrade = hasLpp ? 'A-' : 'D';
    final lppDetail = hasLpp
        ? s.disabilityGapLppDetailYes
        : s.disabilityGapLppDetailNo;

    // Epargne urgence grade
    final monthsReserve = _savings / (_grossMonthly * 0.7);
    final String savingsGrade;
    if (monthsReserve >= 6) {
      savingsGrade = 'A';
    } else if (monthsReserve >= 3) {
      savingsGrade = 'C+';
    } else if (monthsReserve >= 1) {
      savingsGrade = 'D';
    } else {
      savingsGrade = 'F';
    }

    return [
      CoverageItem(
        label: s.disabilityGapApgLabel,
        grade: ijmGrade,
        detail: ijmDetail,
        legalRef: 'LAMal art. 67-77',
        emoji: '\uD83D\uDEE1\uFE0F',
      ),
      CoverageItem(
        label: s.disabilityGapAiLabel,
        grade: aiGrade,
        detail: s.disabilityGapAiDetail(_fmtChf(aiRenteEntiere)),
        legalRef: 'LAI art. 28',
        emoji: '\uD83C\uDFDB\uFE0F',
      ),
      CoverageItem(
        label: s.disabilityGapLppLabel,
        grade: lppGrade,
        detail: lppDetail,
        legalRef: 'LPP art. 23-26',
        emoji: '\uD83C\uDFE6',
      ),
      CoverageItem(
        label: s.disabilityGapSavingsLabel,
        grade: savingsGrade,
        detail: s.disabilityGapSavingsDetail(monthsReserve.toStringAsFixed(1)),
        emoji: '\uD83D\uDCB0',
      ),
    ];
  }

  String get _overallGrade {
    final hasIjmOk = _hasIjm;
    final annualGross = _grossMonthly * 12;
    final hasLpp = annualGross >= lppSeuilEntree;
    final monthsReserve = _savings / (_grossMonthly * 0.7);
    int score = 0;
    if (hasIjmOk) score += 3;
    if (hasLpp) score += 2;
    if (monthsReserve >= 3) score += 2;
    if (monthsReserve >= 6) score += 1;
    if (score >= 7) return 'B+';
    if (score >= 5) return 'C+';
    if (score >= 3) return 'C-';
    return 'D';
  }

  double _lifeDropPercent(List<DisabilityAct> acts) {
    final act3Income = acts.last.monthlyIncome;
    return ((1 - act3Income / _grossMonthly) * 100).clamp(0, 100);
  }

  static String _fmtChf(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  // ── Build ─────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final acts = _buildActs(s);
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(s),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 20),
                _buildInputsCard(s),
                const SizedBox(height: 20),
                DisabilityCliffWidget(
                  grossMonthly: _grossMonthly,
                  acts: acts,
                ),
                const SizedBox(height: 20),
                DisabilityCountdownWidget(
                  monthlyExpenses: _grossMonthly * 0.70,
                  initialSavings: _savings,
                ),
                const SizedBox(height: 20),
                if (_age >= 35 && _lppCapitalBefore > 0) ...[
                  DisabilityResetWidget(
                    currentAge: _age,
                    currentSalary: _grossMonthly * 12,
                    reducedSalary: _grossMonthly * 12 * 0.5,
                    capitalBefore: _lppCapitalBefore,
                    capitalAfter: _lppCapitalAfter,
                  ),
                  const SizedBox(height: 20),
                ],
                DisabilityScorecardWidget(
                  items: _buildScorecardItems(s),
                  overallGrade: _overallGrade,
                  lifeDropPercent: _lifeDropPercent(acts),
                ),
                const SizedBox(height: 20),
                EduDisclaimer(
                  text: s.disabilityGapDisclaimer,
                ),
                const SizedBox(height: 8),
                EduLegalSources(
                  sources: s.disabilityGapLegalSources,
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(S s) {
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
              colors: [MintColors.redWine, MintColors.darkRed],
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
                    s.disabilityGapStatLine1,
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.white70,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    s.disabilityGapStatLine2,
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: MintColors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: Text(
        s.disabilityGapTitle,
        style: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: MintColors.white,
        ),
      ),
    );
  }

  Widget _buildInputsCard(S s) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.disabilityGapYourSituation,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _buildSliderRow(
            label: s.disabilityGapGrossSalary,
            value: _grossMonthly,
            min: 2000,
            max: 25000,
            divisions: 46,
            format: (v) => 'CHF ${_fmtChf(v)}',
            onChanged: (v) => setState(() => _grossMonthly = v),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: s.disabilityGapYourAge,
            value: _age.toDouble(),
            min: 18,
            max: 64,
            divisions: 46,
            format: (v) => s.disabilityGapAgeYears(v.toInt()),
            onChanged: (v) => setState(() => _age = v.toInt()),
          ),
          const SizedBox(height: 12),
          _buildSliderRow(
            label: s.disabilityGapAvailableSavings,
            value: _savings,
            min: 0,
            max: 200000,
            divisions: 40,
            format: (v) => 'CHF ${_fmtChf(v)}',
            onChanged: (v) => setState(() => _savings = v),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  s.disabilityGapIjmSwitch,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Switch(
                value: _hasIjm,
                onChanged: (v) => setState(() => _hasIjm = v),
                activeThumbColor: MintColors.primary,
              ),
            ],
          ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textSecondary,
                ),
              ),
            ),
            Text(
              format(value),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.primary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            activeTrackColor: MintColors.primary,
            inactiveTrackColor: MintColors.border,
            thumbColor: MintColors.primary,
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
