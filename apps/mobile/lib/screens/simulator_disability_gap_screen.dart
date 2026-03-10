import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mint_mobile/domain/disability_gap_calculator.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/simulators/simulator_card.dart';
import 'package:mint_mobile/services/report_persistence_service.dart';

/// Phase display colors
const _phaseColors = {
  'revenu': MintColors.success,
  'phase1': MintColors.success,
  'phase2': Color(0xFFF59E0B), // amber
  'phase3': MintColors.error,
};

/// Risk level colors
const _riskColors = {
  'critical': MintColors.error,
  'high': Color(0xFFEA580C), // orange
  'medium': Color(0xFFF59E0B), // amber
  'low': MintColors.success,
};

class SimulatorDisabilityGapScreen extends StatefulWidget {
  const SimulatorDisabilityGapScreen({super.key});

  @override
  State<SimulatorDisabilityGapScreen> createState() =>
      _SimulatorDisabilityGapScreenState();
}

class _SimulatorDisabilityGapScreenState
    extends State<SimulatorDisabilityGapScreen> {
  double _revenuMensuel = 8000;
  String _canton = 'ZH';
  EmploymentStatusType _statut = EmploymentStatusType.employee;
  int _anneesAnciennete = 5;
  bool _hasIjm = true;
  int _degreInvalidite = 100;

  DisabilityGapResult? _result;

  final _chf = NumberFormat('#,##0', 'fr_CH');

  @override
  void initState() {
    super.initState();
    ReportPersistenceService.markSimulatorExplored('disability_gap');
    _calculate();
  }

  void _calculate() {
    setState(() {
      // Estimate LPP disability benefit from income (LPP art. 23-24)
      // Rente invalidite LPP ≈ projected capital × conversion rate
      // Simplified: ~40% of coordinated salary for full disability
      double estimatedLppDisability = 0.0;
      if (_statut == EmploymentStatusType.employee) {
        final annualGross = _revenuMensuel * 12 / 0.78; // rough net→gross
        if (annualGross >= lppSeuilEntree) {
          final coordinated = (annualGross - lppDeductionCoordination)
              .clamp(lppSalaireCoordMin.toDouble(), lppSalaireCoordMax);
          // ~40% of coordinated salary as disability rente (LPP art. 24)
          estimatedLppDisability = coordinated * 0.40 / 12;
        }
      }

      _result = computeDisabilityGap(
        revenuMensuelNet: _revenuMensuel,
        statutProfessionnel: _statut,
        canton: _canton,
        anneesAnciennete: _anneesAnciennete,
        hasIjmCollective: _hasIjm,
        degreInvalidite: _degreInvalidite,
        lppDisabilityBenefit: estimatedLppDisability,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(S.of(context)!.disabilityGapTitle),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildInputsSection(),
            const SizedBox(height: 24),
            if (_result != null) ...[
              _buildStackedBarChart(),
              const SizedBox(height: 24),
              _buildGapAlertCard(),
              const SizedBox(height: 24),
              _buildPhaseDetailCards(),
              const SizedBox(height: 24),
              _buildActionsSection(),
              const SizedBox(height: 24),
            ],
            _buildEducationSection(),
            const SizedBox(height: 24),
            _buildDisclaimer(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // --- Header ---
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: MintColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.shield_outlined,
                color: MintColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context)!.disabilityGapTitle,
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  S.of(context)!.disabilityGapSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Inputs Section ---
  Widget _buildInputsSection() {
    return SimulatorCard(
      title: S.of(context)!.disabilityGapParamsTitle,
      subtitle: S.of(context)!.disabilityGapParamsSubtitle,
      icon: Icons.tune,
      child: Column(
        children: [
          _buildSlider(
            label: S.of(context)!.disabilityGapIncomeLabel,
            value: _revenuMensuel,
            min: 2000,
            max: 20000,
            divisions: 36,
            format: (v) => '${_chf.format(v)} CHF',
            onChanged: (v) {
              _revenuMensuel = v;
              _calculate();
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _buildCantonDropdown()),
              const SizedBox(width: 16),
              Expanded(child: _buildStatusSelector()),
            ],
          ),
          if (_statut == EmploymentStatusType.employee) ...[
            const SizedBox(height: 16),
            _buildSlider(
              label: S.of(context)!.disabilityGapSeniorityLabel,
              value: _anneesAnciennete.toDouble(),
              min: 0,
              max: 30,
              divisions: 30,
              format: (v) => '${v.toInt()} ans',
              onChanged: (v) {
                _anneesAnciennete = v.toInt();
                _calculate();
              },
            ),
            const SizedBox(height: 16),
            _buildIjmSwitch(),
          ],
          const SizedBox(height: 16),
          _buildSlider(
            label: S.of(context)!.disabilityGapDegreeLabel,
            value: _degreInvalidite.toDouble(),
            min: 40,
            max: 100,
            divisions: 6,
            format: (v) => '${v.toInt()}%',
            onChanged: (v) {
              _degreInvalidite = v.toInt();
              _calculate();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSlider({
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
                  fontSize: 13,
                  color: MintColors.textPrimary,
                ),
              ),
            ),
            Text(
              format(value),
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: MintColors.primary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
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

  Widget _buildCantonDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.disabilityGapCantonLabel,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: MintColors.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _canton,
              isExpanded: true,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: MintColors.textPrimary,
              ),
              items: supportedDisabilityCantons.map((c) {
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
        ),
      ],
    );
  }

  Widget _buildStatusSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.disabilityGapStatusLabel,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<EmploymentStatusType>(
          segments: [
            ButtonSegment(
              value: EmploymentStatusType.employee,
              label: Text(S.of(context)!.disabilityGapEmployee),
            ),
            ButtonSegment(
              value: EmploymentStatusType.selfEmployed,
              label: Text(S.of(context)!.disabilityGapSelfEmployed),
            ),
          ],
          selected: {_statut},
          onSelectionChanged: (v) {
            _statut = v.first;
            _calculate();
          },
          style: ButtonStyle(
            textStyle: WidgetStatePropertyAll(
              GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
            ),
            visualDensity: VisualDensity.compact,
          ),
        ),
      ],
    );
  }

  Widget _buildIjmSwitch() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            S.of(context)!.disabilityGapIjmLabel,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        Switch(
          value: _hasIjm,
          onChanged: (v) {
            _hasIjm = v;
            _calculate();
          },
          activeColor: MintColors.primary,
        ),
      ],
    );
  }

  // --- Stacked Bar Chart ---
  Widget _buildStackedBarChart() {
    final r = _result!;
    return SimulatorCard(
      title: S.of(context)!.disabilityGapChartTitle,
      subtitle: S.of(context)!.disabilityGapChartSubtitle,
      icon: Icons.show_chart,
      child: Column(
        children: [
          _buildBar(
            label: S.of(context)!.disabilityGapCurrentIncome,
            value: r.revenuActuel,
            maxValue: r.revenuActuel,
            color: _phaseColors['revenu']!,
            showGap: false,
          ),
          const SizedBox(height: 12),
          _buildBar(
            label:
                'Phase 1 — Employeur (${r.phase1DurationWeeks.toInt()} sem.)',
            value: r.phase1MonthlyBenefit,
            maxValue: r.revenuActuel,
            color: _phaseColors['phase1']!,
            showGap: true,
          ),
          const SizedBox(height: 12),
          _buildBar(
            label: 'Phase 2 — IJM (24 mois)',
            value: r.phase2MonthlyBenefit,
            maxValue: r.revenuActuel,
            color: _phaseColors['phase2']!,
            showGap: true,
          ),
          const SizedBox(height: 12),
          _buildBar(
            label: 'Phase 3 — AI + LPP',
            value: r.phase3MonthlyBenefit,
            maxValue: r.revenuActuel,
            color: _phaseColors['phase3']!,
            showGap: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBar({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
    required bool showGap,
  }) {
    final percentage = maxValue > 0 ? (value / maxValue) : 0.0;
    final gap = maxValue - value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: MintColors.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: Stack(
                children: [
                  // Background (gap)
                  Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: MintColors.border.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  // Benefit bar
                  FractionallySizedBox(
                    widthFactor: percentage,
                    child: Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.only(left: 8),
                      child: value > 0
                          ? Text(
                              '${_chf.format(value)} CHF',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
            if (showGap && gap > 0) ...[
              const SizedBox(width: 8),
              Text(
                'Gap: ${_chf.format(gap)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: MintColors.error,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }

  // --- Gap Alert Card ---
  Widget _buildGapAlertCard() {
    final r = _result!;
    final maxGap = [r.phase1Gap, r.phase2Gap, r.phase3Gap]
        .reduce((a, b) => a > b ? a : b);
    final riskColor = _riskColors[r.riskLevel]!;
    final riskLabel = {
      'critical': S.of(context)!.disabilityGapRiskCritical,
      'high': S.of(context)!.disabilityGapRiskHigh,
      'medium': S.of(context)!.disabilityGapRiskMedium,
      'low': S.of(context)!.disabilityGapRiskLow,
    }[r.riskLevel]!;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: riskColor.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: riskColor.withOpacity(0.15), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: riskColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  riskLabel.toUpperCase(),
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            S.of(context)!.disabilityGapMaxGap,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MintColors.textMuted,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${_chf.format(maxGap)} CHF/mois',
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.w800,
              color: riskColor,
            ),
          ),
          if (r.alerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...r.alerts.map((alert) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16, color: riskColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alert,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: MintColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ],
      ),
    );
  }

  // --- Phase Detail Cards ---
  Widget _buildPhaseDetailCards() {
    final r = _result!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.disabilityGapPhaseDetail,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildPhaseCard(
          title: S.of(context)!.disabilityGapPhase1Title,
          duration: S.of(context)!.disabilityGapPhase1Duration('${r.phase1DurationWeeks.toInt()}'),
          coverage: r.phase1MonthlyBenefit > 0 ? S.of(context)!.disabilityGapPhase1Full : S.of(context)!.disabilityGapNone,
          legalSource: 'CO art. 324a',
          color: _phaseColors['phase1']!,
        ),
        const SizedBox(height: 12),
        _buildPhaseCard(
          title: S.of(context)!.disabilityGapPhase2Title,
          duration: S.of(context)!.disabilityGapPhase2Duration,
          coverage: r.phase2MonthlyBenefit > 0
              ? S.of(context)!.disabilityGapPhase2Coverage(_chf.format(r.phase2MonthlyBenefit))
              : S.of(context)!.disabilityGapNoCoverage,
          legalSource: _hasIjm ? S.of(context)!.disabilityGapCollectiveInsurance : S.of(context)!.disabilityGapNotSubscribed,
          color: _phaseColors['phase2']!,
        ),
        const SizedBox(height: 12),
        _buildPhaseCard(
          title: S.of(context)!.disabilityGapPhase3Title,
          duration: S.of(context)!.disabilityGapPhase3Duration,
          coverage:
              'AI: ${_chf.format(r.aiRenteMensuelle)} CHF/mois\nLPP: ${_chf.format(r.lppDisabilityBenefit)} CHF/mois\nTotal: ${_chf.format(r.phase3MonthlyBenefit)} CHF/mois',
          legalSource: 'LAI art. 28 + LPP art. 23',
          color: _phaseColors['phase3']!,
        ),
      ],
    );
  }

  Widget _buildPhaseCard({
    required String title,
    required String duration,
    required String coverage,
    required String legalSource,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildPhaseInfoRow(S.of(context)!.disabilityGapDurationLabel, duration),
          const SizedBox(height: 6),
          _buildPhaseInfoRow(S.of(context)!.disabilityGapCoverageLabel, coverage),
          const SizedBox(height: 6),
          _buildPhaseInfoRow(S.of(context)!.disabilityGapLegalLabel, legalSource),
        ],
      ),
    );
  }

  Widget _buildPhaseInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: MintColors.textMuted,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  // --- Actions Section ---
  Widget _buildActionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.disabilityGapIfYouAre,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        if (_statut == EmploymentStatusType.selfEmployed && !_hasIjm) ...[
          _buildActionCard(
            icon: Icons.shield_outlined,
            title: S.of(context)!.disabilityGapActionSelfIjm,
            subtitle: S.of(context)!.disabilityGapActionSelfIjmSub,
            color: MintColors.error,
          ),
        ] else if (_statut == EmploymentStatusType.employee && !_hasIjm) ...[
          _buildActionCard(
            icon: Icons.health_and_safety,
            title: S.of(context)!.disabilityGapActionCheckHr,
            subtitle: S.of(context)!.disabilityGapActionCheckHrSub,
            color: const Color(0xFFEA580C),
          ),
        ] else if (_statut == EmploymentStatusType.employee && _hasIjm) ...[
          _buildActionCard(
            icon: Icons.description_outlined,
            title: S.of(context)!.disabilityGapActionConditions,
            subtitle: S.of(context)!.disabilityGapActionConditionsSub,
            color: MintColors.primary,
          ),
        ],
      ],
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
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
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Education Section ---
  Widget _buildEducationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.disabilityGapEduTitle,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        _buildExpandableTile(
          S.of(context)!.disabilityGapEduIjmTitle,
          S.of(context)!.disabilityGapEduIjmBody,
        ),
        const SizedBox(height: 8),
        _buildExpandableTile(
          S.of(context)!.disabilityGapEduCoTitle,
          S.of(context)!.disabilityGapEduCoBody,
        ),
      ],
    );
  }

  Widget _buildExpandableTile(String title, String content) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: MintColors.textPrimary,
            ),
          ),
          children: [
            Text(
              content,
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Disclaimer ---
  Widget _buildDisclaimer() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: Colors.orange.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              S.of(context)!.disabilityGapDisclaimer,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: Colors.orange.shade800,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
