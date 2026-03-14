import 'dart:math' show pow;
import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/first_job_service.dart';
import 'package:mint_mobile/widgets/educational/salary_breakdown_widget.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/widgets/coach/first_salary_film_widget.dart';
import 'package:mint_mobile/widgets/coach/budget_503020_widget.dart';
import 'package:mint_mobile/widgets/coach/career_timelapse_widget.dart';
import 'package:mint_mobile/widgets/coach/payslip_xray_widget.dart';
import 'package:mint_mobile/widgets/coach/job_change_checklist_widget.dart';
import 'package:mint_mobile/constants/social_insurance.dart';

// ────────────────────────────────────────────────────────────
//  FIRST JOB SCREEN — Sprint S19 / Premier emploi
// ────────────────────────────────────────────────────────────
//
// Interactive first job salary analyzer.
// Inputs: salary, age, canton, activity rate.
// Outputs: salary breakdown, 3a recommendation, LAMal franchise
//          comparison, checklist.
// ────────────────────────────────────────────────────────────

class FirstJobScreen extends StatefulWidget {
  const FirstJobScreen({super.key});

  @override
  State<FirstJobScreen> createState() => _FirstJobScreenState();
}

class _FirstJobScreenState extends State<FirstJobScreen> {
  double _salaire = 5000;
  int _age = 25;
  String _canton = 'ZH';
  double _tauxActivite = 100;
  FirstJobResult? _result;
  bool _seededFromProfile = false;

  // Checklist tracking
  final Set<int> _checkedItems = {};

  // Swiss cantons
  static const List<String> _cantons = [
    'AG', 'AI', 'AR', 'BE', 'BL', 'BS', 'FR', 'GE', 'GL', 'GR',
    'JU', 'LU', 'NE', 'NW', 'OW', 'SG', 'SH', 'SO', 'SZ', 'TG',
    'TI', 'UR', 'VD', 'VS', 'ZG', 'ZH',
  ];

  @override
  void initState() {
    super.initState();
    _calculate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_seededFromProfile) return;
    final profile = context.read<CoachProfileProvider>().profile;
    if (profile == null) return;
    final age = DateTime.now().year - profile.birthYear;
    // Don't seed a 45+ year-old's salary into a "premier emploi" screen
    if (age > 30) return;
    _seededFromProfile = true;
    setState(() {
      _salaire = profile.salaireBrutMensuel.clamp(2000, 15000);
      _age = age.clamp(18, 30);
      if (profile.canton.isNotEmpty) _canton = profile.canton;
    });
    _calculate();
  }

  void _calculate() {
    setState(() {
      _result = FirstJobService.analyzeSalary(
        salaireBrutMensuel: _salaire,
        age: _age,
        canton: _canton,
        tauxActivite: _tauxActivite,
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
                _buildSalaireSlider(),
                const SizedBox(height: 20),
                _buildAgeSlider(),
                const SizedBox(height: 20),
                _buildCantonAndActivity(),
                const SizedBox(height: 24),
                if (_result != null) ...[
                  _buildChiffreChoc(),
                  const SizedBox(height: 24),
                  SalaryBreakdownWidget(
                    brut: _result!.brut,
                    netEstime: _result!.netEstime,
                    cotisationsEmployeur: _result!.cotisationsEmployeur,
                    deductions: _result!.deductionItems,
                  ),
                  const SizedBox(height: 24),
                  // ── P5-C : Radiographie fiche de paie ──────────
                  PayslipXRayWidget(
                    grossSalary: _salaire,
                    netSalary: _salaire * 0.76,
                    employerHiddenCost: _salaire * 1.13,
                    deductions: [
                      PayslipLine(
                        label: S.of(context)!.firstJobPayslipAvs,
                        emoji: '🛡️',
                        amount: _salaire * 0.053,
                        percentage: 5.3,
                        explanation: S.of(context)!.firstJobPayslipAvsExpl,
                        legalRef: S.of(context)!.firstJobPayslipAvsRef,
                      ),
                      PayslipLine(
                        label: S.of(context)!.firstJobPayslipLpp,
                        emoji: '🏦',
                        amount: _salaire * 0.08,
                        percentage: 8.0,
                        explanation: S.of(context)!.firstJobPayslipLppExpl,
                        legalRef: S.of(context)!.firstJobPayslipLppRef,
                      ),
                      PayslipLine(
                        label: S.of(context)!.firstJobPayslipTax,
                        emoji: '🏛️',
                        amount: _salaire * 0.09,
                        percentage: 9.0,
                        explanation: S.of(context)!.firstJobPayslipTaxExpl,
                        legalRef: S.of(context)!.firstJobPayslipTaxRef,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _build3aRecommendation(),
                  const SizedBox(height: 24),
                  _build3aWarning(),
                  const SizedBox(height: 24),
                  _buildLamalComparison(),
                  const SizedBox(height: 24),
                  _buildChecklist(),
                  const SizedBox(height: 24),
                  // ── P11-C : Checklist changement de job ────────
                  JobChangeChecklistWidget(
                    items: [
                      ChecklistItem(
                        deadline: S.of(context)!.firstJobChecklistDeadlineBefore,
                        emoji: '📄',
                        action: S.of(context)!.firstJobChecklistActionLpp,
                        legalRef: S.of(context)!.firstJobChecklistRefLpp,
                        consequence: S.of(context)!.firstJobChecklistConsequenceLpp,
                      ),
                      ChecklistItem(
                        deadline: S.of(context)!.firstJobChecklistDeadline30,
                        emoji: '🏦',
                        action: S.of(context)!.firstJobChecklistActionTransfer,
                        legalRef: S.of(context)!.firstJobChecklistRefTransfer,
                        consequence: S.of(context)!.firstJobChecklistConsequenceTransfer,
                      ),
                      ChecklistItem(
                        deadline: S.of(context)!.firstJobChecklistDeadline1Month,
                        emoji: '🛡️',
                        action: S.of(context)!.firstJobChecklistActionLamal,
                        legalRef: S.of(context)!.firstJobChecklistRefLamal,
                      ),
                      ChecklistItem(
                        deadline: S.of(context)!.firstJobChecklistDeadlineFirstSalary,
                        emoji: '🏦',
                        action: S.of(context)!.firstJobChecklistAction3a,
                        legalRef: S.of(context)!.firstJobChecklistRef3a,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildEducation(),
                  const SizedBox(height: 24),
                  _buildMintAnalysisSection(),
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
          S.of(context)!.firstJobTitle,
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
          const Icon(Icons.celebration_outlined, color: MintColors.info, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.firstJobHeaderDesc,
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

  // ── Sliders ────────────────────────────────────────────────

  Widget _buildSalaireSlider() {
    return _buildSliderCard(
      title: S.of(context)!.firstJobSalaryTitle,
      valueLabel: FirstJobService.formatChf(_salaire),
      minLabel: S.of(context)!.firstJobSalaryMin,
      maxLabel: S.of(context)!.firstJobSalaryMax,
      value: _salaire,
      min: 2000,
      max: 15000,
      divisions: 260,
      onChanged: (v) {
        _salaire = v;
        _calculate();
      },
    );
  }

  Widget _buildAgeSlider() {
    return _buildSliderCard(
      title: S.of(context)!.unemploymentAgeSliderTitle,
      valueLabel: S.of(context)!.unemploymentAgeValue(_age),
      minLabel: S.of(context)!.unemploymentAgeMin,
      maxLabel: S.of(context)!.unemploymentAgeValue(30),
      value: _age.toDouble(),
      min: 18,
      max: 30,
      divisions: 12,
      onChanged: (v) {
        _age = v.toInt();
        _calculate();
      },
    );
  }

  Widget _buildSliderCard({
    required String title,
    required String valueLabel,
    required String minLabel,
    required String maxLabel,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Text(
                valueLabel,
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
              value: value,
              min: min,
              max: max,
              divisions: divisions,
              onChanged: onChanged,
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(minLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
              Text(maxLabel,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Canton + Activity Rate ─────────────────────────────────

  Widget _buildCantonAndActivity() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: MintColors.border.withValues(alpha: 0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canton dropdown
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.firstJobCanton,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: MintColors.appleSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: MintColors.border),
                ),
                child: DropdownButton<String>(
                  value: _canton,
                  underline: const SizedBox.shrink(),
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MintColors.primary,
                  ),
                  items: _cantons.map((c) {
                    return DropdownMenuItem(value: c, child: Text(c));
                  }).toList(),
                  onChanged: (v) {
                    if (v != null) {
                      _canton = v;
                      _calculate();
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Activity rate slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context)!.firstJobActivityRate,
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                '${_tauxActivite.toStringAsFixed(0)}%',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: MintColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: MintColors.primary,
              inactiveTrackColor: MintColors.border,
              thumbColor: MintColors.primary,
              overlayColor: MintColors.primary.withValues(alpha: 0.1),
              trackHeight: 6,
            ),
            child: Slider(
              value: _tauxActivite,
              min: 10,
              max: 100,
              divisions: 18,
              onChanged: (v) {
                _tauxActivite = v;
                _calculate();
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(S.of(context)!.firstJobActivityMin,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
              Text(S.of(context)!.firstJobActivityMax,
                  style: GoogleFonts.inter(
                      fontSize: 11, color: MintColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  // ── Chiffre Choc ───────────────────────────────────────────

  Widget _buildChiffreChoc() {
    final r = _result!;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            FirstJobService.formatChf(r.cotisationsEmployeur),
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: MintColors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            r.chiffreChoc,
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

  // ── 3a Recommendation ──────────────────────────────────────

  Widget _build3aRecommendation() {
    final r = _result!;
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
              const Icon(Icons.savings_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.firstJob3aHeader,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMiniMetric(
                  S.of(context)!.firstJob3aAnnualCap,
                  FirstJobService.formatChf(r.plafondAnnuel3a),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMiniMetric(
                  S.of(context)!.firstJob3aMonthlySuggestion,
                  FirstJobService.formatChf(r.montantMensuelSuggere3a),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.trending_up,
                    size: 16, color: MintColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context)!.firstJobTaxSavings(FirstJobService.formatChf(r.economieFiscaleEstimee3a)),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.success,
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

  Widget _buildMiniMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ── 3a WARNING ─────────────────────────────────────────────

  Widget _build3aWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: MintColors.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.firstJob3aWarningTitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.error,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _result!.alerte3a,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── LAMal Franchise Comparison ─────────────────────────────

  Widget _buildLamalComparison() {
    final r = _result!;
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
              const Icon(Icons.health_and_safety_outlined,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.firstJobLamalHeader,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Franchise cards
          ...r.franchiseOptions.map((option) {
            final isRecommended =
                option.franchise == r.franchiseRecommandee;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isRecommended
                    ? MintColors.success.withValues(alpha: 0.06)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isRecommended
                    ? Border.all(
                        color: MintColors.success.withValues(alpha: 0.4))
                    : Border.all(
                        color: MintColors.lightBorder.withValues(alpha: 0.5)),
              ),
              child: Row(
                children: [
                  if (isRecommended)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: MintColors.success,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        S.of(context)!.firstJobLamalTop,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: MintColors.white,
                        ),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      S.of(context)!.firstJobLamalFranchise('${option.franchise}'),
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight:
                            isRecommended ? FontWeight.w700 : FontWeight.w500,
                        color: isRecommended
                            ? MintColors.success
                            : MintColors.textPrimary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 3,
                    child: Text(
                      S.of(context)!.firstJobLamalPerMonth(FirstJobService.formatChf(option.primeMensuelle)),
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    S.of(context)!.firstJobLamalMaxPerYear(FirstJobService.formatChf(option.coutAnnuelMax)),
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 12),

          // Savings highlight
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.success.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.savings_outlined,
                    size: 16, color: MintColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    S.of(context)!.firstJobLamalSavingsHighlight(FirstJobService.formatChf(r.economieAnnuelleVs300)),
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: MintColors.success,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Note
          Text(
            r.noteLamal,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  // ── Checklist ──────────────────────────────────────────────

  Widget _buildChecklist() {
    final items = _result?.checklist ?? [];
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
              const Icon(Icons.checklist,
                  size: 16, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Text(
                S.of(context)!.firstJobChecklistHeader,
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(items.length, (index) {
            final checked = _checkedItems.contains(index);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (checked) {
                    _checkedItems.remove(index);
                  } else {
                    _checkedItems.add(index);
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step number or check
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: checked
                            ? MintColors.success
                            : MintColors.appleSurface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: checked
                              ? MintColors.success
                              : MintColors.border,
                          width: 1.5,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: checked
                          ? const Icon(Icons.check,
                              size: 16, color: MintColors.white)
                          : Text(
                              '${index + 1}',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: MintColors.textSecondary,
                              ),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        items[index],
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: checked
                              ? MintColors.textMuted
                              : MintColors.textPrimary,
                          decoration: checked
                              ? TextDecoration.lineThrough
                              : null,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
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
            const Icon(Icons.lightbulb_outline,
                size: 16, color: MintColors.textMuted),
            const SizedBox(width: 8),
            Text(
              S.of(context)!.unemploymentGoodToKnow,
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
          Icons.account_balance_outlined,
          S.of(context)!.firstJobEduLppTitle,
          S.of(context)!.firstJobEduLppBody,
        ),
        _buildEduCard(
          Icons.receipt_long_outlined,
          S.of(context)!.firstJobEdu13Title,
          S.of(context)!.firstJobEdu13Body,
        ),
        _buildEduCard(
          Icons.savings_outlined,
          S.of(context)!.firstJobEduBudgetTitle,
          S.of(context)!.firstJobEduBudgetBody,
        ),
        _buildEduCard(
          Icons.description_outlined,
          S.of(context)!.firstJobEduTaxTitle,
          S.of(context)!.firstJobEduTaxBody,
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

  // ── Analyse MINT ───────────────────────────────────────────

  Widget _buildMintAnalysisSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(),
        const SizedBox(height: 12),
        _buildScenarioChips(),
        const SizedBox(height: 16),
        FirstSalaryFilmWidget(grossMonthly: _salaire),
        const SizedBox(height: 20),
        _buildBudget503020(),
        const SizedBox(height: 20),
        _buildCareerTimeLapse(),
      ],
    );
  }

  /// Future Value of annuity: annual × ((1+r)^n - 1) / r
  static double _fvAnnuity(double annual, int years, {double r = 0.04}) {
    if (years <= 0) return 0;
    return annual * ((pow(1 + r, years) - 1) / r);
  }

  Widget _buildBudget503020() {
    final net = _result?.netEstime ?? _salaire * 0.85;
    final annualSavings = net * 0.20 * 12;
    final years = (65 - _age).clamp(0, 45);
    final fv = _fvAnnuity(annualSavings, years);
    return Budget503020Widget(
      netSalary: net,
      categories: [
        BudgetCategory(
          label: S.of(context)!.firstJobBudgetNeeds,
          emoji: '🏠',
          percent: 50,
          amount: net * 0.50,
          examples: [S.of(context)!.firstJobBudgetExRent, S.of(context)!.firstJobBudgetExLamal, S.of(context)!.firstJobBudgetExTransport, S.of(context)!.firstJobBudgetExFood],
        ),
        BudgetCategory(
          label: S.of(context)!.firstJobBudgetWants,
          emoji: '✨',
          percent: 30,
          amount: net * 0.30,
          examples: [S.of(context)!.firstJobBudgetExLeisure, S.of(context)!.firstJobBudgetExRestaurants, S.of(context)!.firstJobBudgetExTravel, S.of(context)!.firstJobBudgetExShopping],
        ),
        BudgetCategory(
          label: S.of(context)!.firstJobBudgetSavings,
          emoji: '🏦',
          percent: 20,
          amount: net * 0.20,
          examples: [S.of(context)!.firstJobBudgetEx3a, S.of(context)!.firstJobBudgetExSavings, S.of(context)!.firstJobBudgetExEmergency],
        ),
      ],
      chiffreChoc: S.of(context)!.firstJobBudgetChiffreChoc(
        "${(annualSavings.round() ~/ 1000)}'000",
        "${(fv.round() ~/ 1000)}'000",
      ),
    );
  }

  Widget _buildCareerTimeLapse() {
    const monthly3a = pilier3aPlafondAvecLpp / 12;
    const annual3a = monthly3a * 12;

    final candidateAges = [22, 25, 30, 35].where((a) => a <= _age + 5).toList();
    final scenarioAges = candidateAges.isEmpty ? [_age] : candidateAges;
    final scenarios = scenarioAges
        .map((a) => TimeLapseScenario(
              startAge: a,
              capitalAt65: _fvAnnuity(annual3a, (65 - a).clamp(0, 45)),
            ))
        .toList();

    return CareerTimeLapseWidget(
      scenarios: scenarios,
      monthly3aContribution: monthly3a,
      initialAge: _age,
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      children: [
        Expanded(
          child: Text(
            S.of(context)!.firstJobAnalysisHeader,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: _seededFromProfile
                ? MintColors.scoreExcellent.withValues(alpha: 0.1)
                : MintColors.scoreAttention.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _seededFromProfile
                  ? MintColors.scoreExcellent.withValues(alpha: 0.4)
                  : MintColors.scoreAttention.withValues(alpha: 0.4),
            ),
          ),
          child: Text(
            _seededFromProfile ? '📍 ${S.of(context)!.firstJobProfileBadge}' : '💡 ${S.of(context)!.firstJobIllustrativeBadge}',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _seededFromProfile
                  ? MintColors.scoreExcellent
                  : MintColors.scoreAttention,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildScenarioChips() {
    const median = 6500.0;
    final profileVal = _seededFromProfile
        ? context.read<CoachProfileProvider>().profile?.salaireBrutMensuel ?? 5000.0
        : 5000.0;
    final boosted = (profileVal * 1.20).clamp(2000.0, 15000.0);

    final scenarios = [
      (
        label: _seededFromProfile ? '\u{1F4CD} ${S.of(context)!.firstJobScenarioMySalary}' : '\u{1F4CD} ${S.of(context)!.firstJobScenarioDefault}',
        value: profileVal.clamp(2000.0, 15000.0),
        active: (_salaire - profileVal.clamp(2000.0, 15000.0)).abs() < 50,
      ),
      (
        label: '\u{1F1E8}\u{1F1ED} ${S.of(context)!.firstJobScenarioMedian}',
        value: median,
        active: (_salaire - median).abs() < 50,
      ),
      (
        label: '\u2728 ${S.of(context)!.firstJobScenarioPlus20}',
        value: boosted,
        active: (_salaire - boosted).abs() < 50,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: scenarios.map((s) {
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                setState(() => _salaire = s.value);
                _calculate();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: s.active
                      ? MintColors.primary
                      : MintColors.white,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: s.active ? MintColors.primary : MintColors.lightBorder,
                    width: s.active ? 2 : 1,
                  ),
                ),
                child: Text(
                  '${s.label}  CHF ${FirstJobService.formatChf(s.value)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: s.active ? MintColors.white : MintColors.textPrimary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
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
              S.of(context)!.firstJobDisclaimer,
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
