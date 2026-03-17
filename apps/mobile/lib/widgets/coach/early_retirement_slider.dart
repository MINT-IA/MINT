import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  EARLY RETIREMENT SLIDER — P1-C / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Slider intuitif pour explorer l'impact du depart anticipe.
//  Remplace les 7 barres par UN curseur avec zones colorees.
//
//  Zones :
//    58-62 : rouge  — "Risque : sacrifice financier important"
//    63-64 : orange — "Faisable avec compromis"
//    65    : vert   — "Standard, pas de penalite"
//    66-70 : bleu   — "Bonus, mais tu profites moins longtemps"
//
//  Widget pur — aucune dependance Provider.
//  Lois : L3 (3 niveaux) + L4 (raconte, ne montre pas)
// ────────────────────────────────────────────────────────────

/// Data for a single retirement age scenario.
class RetirementAgeScenario {
  /// Retirement age (58-70).
  final int age;

  /// Projected monthly income at this age.
  final double monthlyIncome;

  /// Percentage change vs standard retirement (65).
  final double deltaPercent;

  /// Total lifetime cost/gain vs 65 (approximate, over 25 years).
  final double? lifetimeDelta;

  const RetirementAgeScenario({
    required this.age,
    required this.monthlyIncome,
    required this.deltaPercent,
    this.lifetimeDelta,
  });
}

class EarlyRetirementSlider extends StatefulWidget {
  /// Scenarios for each retirement age (min 3).
  final List<RetirementAgeScenario> scenarios;

  /// Monthly income at standard retirement (65) for comparison.
  final double monthlyIncomeAt65;

  /// Initial selected age (defaults to 65).
  final int initialAge;

  /// Callback when user selects a new age.
  final ValueChanged<int>? onAgeChanged;

  const EarlyRetirementSlider({
    super.key,
    required this.scenarios,
    required this.monthlyIncomeAt65,
    this.initialAge = 65,
    this.onAgeChanged,
  });

  @override
  State<EarlyRetirementSlider> createState() => _EarlyRetirementSliderState();
}

class _EarlyRetirementSliderState extends State<EarlyRetirementSlider> {
  late int _selectedAge;

  @override
  void initState() {
    super.initState();
    _selectedAge = widget.initialAge;
  }

  RetirementAgeScenario? get _selectedScenario {
    try {
      return widget.scenarios.firstWhere((s) => s.age == _selectedAge);
    } catch (_) {
      return null;
    }
  }

  Color _zoneColor(int age) {
    if (age <= 62) return MintColors.scoreCritique;
    if (age <= 64) return MintColors.scoreAttention;
    if (age == 65) return MintColors.scoreExcellent;
    return MintColors.scoreBon; // 66+
  }

  String _zoneLabel(BuildContext context, int age) {
    final s = S.of(context)!;
    if (age <= 62) return s.earlyRetirementZoneRisky;
    if (age <= 64) return s.earlyRetirementZoneFeasible;
    if (age == 65) return s.earlyRetirementZoneStandard;
    return s.earlyRetirementZoneBonus;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.scenarios.isEmpty) return const SizedBox.shrink();

    final s = S.of(context)!;
    final minAge =
        widget.scenarios.map((sc) => sc.age).reduce((a, b) => a < b ? a : b);
    final maxAge =
        widget.scenarios.map((sc) => sc.age).reduce((a, b) => a > b ? a : b);
    final scenario = _selectedScenario;
    final color = _zoneColor(_selectedAge);

    return Semantics(
      label: s.earlyRetirementSemanticsLabel(_selectedAge),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: MintColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──
            Text(
              s.earlyRetirementHeader,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // ── Age display ──
            Center(
              child: Text(
                s.earlyRetirementAgeDisplay(_selectedAge),
                style: GoogleFonts.montserrat(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Zone label ──
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _zoneLabel(context, _selectedAge),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // ── Slider ──
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: color,
                inactiveTrackColor: MintColors.surface,
                thumbColor: color,
                overlayColor: color.withValues(alpha: 0.12),
                trackHeight: 6,
                thumbShape:
                    const RoundSliderThumbShape(enabledThumbRadius: 10),
              ),
              child: Slider(
                value: _selectedAge.toDouble(),
                min: minAge.toDouble(),
                max: maxAge.toDouble(),
                divisions: maxAge - minAge,
                onChanged: (value) {
                  setState(() => _selectedAge = value.round());
                  widget.onAgeChanged?.call(_selectedAge);
                },
              ),
            ),

            // ── Age labels under slider ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('$minAge',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: MintColors.textMuted)),
                Text('65',
                    style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MintColors.scoreExcellent)),
                Text('$maxAge',
                    style: GoogleFonts.inter(
                        fontSize: 11, color: MintColors.textMuted)),
              ],
            ),
            const SizedBox(height: 16),

            // ── Result panel ──
            if (scenario != null) _buildResultPanel(context, scenario, color),

            // ── Disclaimer ──
            const SizedBox(height: 12),
            Text(
              s.earlyRetirementDisclaimer,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: MintColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultPanel(BuildContext context, RetirementAgeScenario scenario, Color color) {
    final s = S.of(context)!;
    final delta = scenario.deltaPercent;
    final isGain = delta >= 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.earlyRetirementResultLine(scenario.age, formatChfWithPrefix(scenario.monthlyIncome)),
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isGain
                      ? MintColors.scoreExcellent.withValues(alpha: 0.12)
                      : MintColors.scoreCritique.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${isGain ? "+" : ""}${delta.toStringAsFixed(0)}%',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isGain
                        ? MintColors.scoreExcellent
                        : MintColors.scoreCritique,
                  ),
                ),
              ),
            ],
          ),
          if (scenario.age != 65) ...[
            const SizedBox(height: 6),
            Text(
              _buildNarrative(context, scenario),
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (scenario.lifetimeDelta != null) ...[
            const SizedBox(height: 4),
            Text(
              s.earlyRetirementLifetimeImpact(formatChfWithPrefix(scenario.lifetimeDelta!.abs())),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _buildNarrative(BuildContext context, RetirementAgeScenario scenario) {
    final s = S.of(context)!;
    final diff = scenario.monthlyIncome - widget.monthlyIncomeAt65;
    if (scenario.age < 65) {
      final years = 65 - scenario.age;
      return s.earlyRetirementNarrativeEarly(
        formatChfWithPrefix(diff.abs()),
        years,
        years > 1 ? 's' : '',
      );
    }
    final years = scenario.age - 65;
    return s.earlyRetirementNarrativeLate(
      formatChfWithPrefix(diff.abs()),
      years,
      years > 1 ? 's' : '',
    );
  }
}
