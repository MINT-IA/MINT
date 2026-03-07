import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

// ────────────────────────────────────────────────────────────
//  CAREER TIMELAPSE WIDGET — P5-B / S42 UX Redesign
// ────────────────────────────────────────────────────────────
//
//  Slider "age de debut" montrant le patrimoine a 65 ans.
//  Chaque annee perdue coute ~30'000 CHF grace aux interets
//  composes.
//
//  Widget pur — aucune dependance Provider.
//  Lois : L2 (avant/apres) + L7 (metaphore bat graphique)
// ────────────────────────────────────────────────────────────

/// Data for a single starting age scenario.
class TimeLapseScenario {
  final int startAge;
  final double capitalAt65;

  const TimeLapseScenario({
    required this.startAge,
    required this.capitalAt65,
  });
}

class CareerTimeLapseWidget extends StatefulWidget {
  /// Scenarios by starting age.
  final List<TimeLapseScenario> scenarios;

  /// Monthly 3a contribution used for the projection.
  final double monthly3aContribution;

  /// Initial selected age.
  final int initialAge;

  const CareerTimeLapseWidget({
    super.key,
    required this.scenarios,
    required this.monthly3aContribution,
    this.initialAge = 25,
  });

  @override
  State<CareerTimeLapseWidget> createState() => _CareerTimeLapseWidgetState();
}

class _CareerTimeLapseWidgetState extends State<CareerTimeLapseWidget> {
  late int _selectedAge;

  @override
  void initState() {
    super.initState();
    _selectedAge = widget.initialAge;
  }

  TimeLapseScenario? get _selected {
    try {
      return widget.scenarios.firstWhere((s) => s.startAge == _selectedAge);
    } catch (_) {
      return null;
    }
  }

  double get _maxCapital =>
      widget.scenarios.isEmpty
          ? 1
          : widget.scenarios
              .map((s) => s.capitalAt65)
              .reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    if (widget.scenarios.isEmpty) return const SizedBox.shrink();

    final minAge = widget.scenarios
        .map((s) => s.startAge)
        .reduce((a, b) => a < b ? a : b);
    final maxAge = widget.scenarios
        .map((s) => s.startAge)
        .reduce((a, b) => a > b ? a : b);
    final selected = _selected;
    final earliest = widget.scenarios
        .reduce((a, b) => a.startAge < b.startAge ? a : b);
    final costPerYear = selected != null && selected.startAge > minAge
        ? (earliest.capitalAt65 - selected.capitalAt65) /
            (selected.startAge - minAge)
        : 0.0;

    return Semantics(
      label: 'Time-lapse carri\u00e8re. D\u00e9but \u00e0 $_selectedAge ans.',
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
            Text(
              'Et si tu avais commenc\u00e9 \u00e0\u2026',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),

            // ── Bars ──
            ...widget.scenarios.map((s) => _buildBar(s)),

            const SizedBox(height: 12),

            // ── Slider ──
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: MintColors.primary,
                inactiveTrackColor: MintColors.surface,
                thumbColor: MintColors.primary,
                trackHeight: 4,
              ),
              child: Slider(
                value: _selectedAge.toDouble(),
                min: minAge.toDouble(),
                max: maxAge.toDouble(),
                divisions: maxAge - minAge,
                onChanged: (v) => setState(() => _selectedAge = v.round()),
              ),
            ),

            // ── Chiffre-choc ──
            if (selected != null && costPerYear > 0)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: MintColors.scoreCritique.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${selected.startAge - minAge} an${selected.startAge - minAge > 1 ? "s" : ""} '
                  'd\u2019attente = ${formatChfWithPrefix((earliest.capitalAt65 - selected.capitalAt65).abs())} '
                  'de moins \u00e0 65 ans.\n'
                  'Les int\u00e9r\u00eats compos\u00e9s sont ton alli\u00e9 \u2014 '
                  'mais seulement si tu commences t\u00f4t.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.scoreCritique,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

            const SizedBox(height: 12),
            Text(
              'Projection \u00e0 4% net/an avec ${formatChfWithPrefix(widget.monthly3aContribution)}/mois en 3a. '
              'Outil \u00e9ducatif, ne constitue pas un conseil (LSFin).',
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

  Widget _buildBar(TimeLapseScenario s) {
    final isSelected = s.startAge == _selectedAge;
    final ratio = _maxCapital > 0 ? s.capitalAt65 / _maxCapital : 0.0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text(
              '${s.startAge} ans',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
                color: isSelected ? MintColors.primary : MintColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Container(
                  height: isSelected ? 16 : 10,
                  width: constraints.maxWidth * ratio,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? MintColors.primary
                        : MintColors.primary.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(4),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 60,
            child: Text(
              formatChfCompact(s.capitalAt65),
              textAlign: TextAlign.right,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? MintColors.primary : MintColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Compact CHF formatter (e.g. "680k").
String formatChfCompact(double value) {
  if (value >= 1000000) return '${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return '${(value / 1000).toStringAsFixed(0)}k';
  return formatChfWithPrefix(value);
}
