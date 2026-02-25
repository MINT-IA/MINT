import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/services/scenario_narrator_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Scenario Narration Screen — Sprint S37.
///
/// Displays 3 retirement scenarios as narrative story cards,
/// each with color-coded header, capital amount, monthly income,
/// and educational narrative text.
///
/// Color coding:
///   - Prudent: trajectoryPrudent (amber/orange)
///   - Base: trajectoryBase (blue)
///   - Optimiste: trajectoryOptimiste (green)
class ScenarioNarrationScreen extends StatelessWidget {
  final ScenarioNarrationResult narration;

  const ScenarioNarrationScreen({
    super.key,
    required this.narration,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  'Trois scenarios pour visualiser ta retraite selon '
                  'differentes hypotheses de rendement.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Scenario cards
                for (int i = 0; i < narration.scenarios.length; i++) ...[
                  _ScenarioCard(
                    scenario: narration.scenarios[i],
                    color: _scenarioColor(i),
                    icon: _scenarioIcon(i),
                  ),
                  if (i < narration.scenarios.length - 1)
                    const SizedBox(height: 16),
                ],
                const SizedBox(height: 24),
                // Sources
                _buildSources(),
                const SizedBox(height: 16),
                // Disclaimer
                _buildDisclaimer(),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  APP BAR
  // ════════════════════════════════════════════════════════════════

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      backgroundColor: MintColors.primary,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [MintColors.primary, Color(0xFF2D2D30)],
            ),
          ),
        ),
        title: Text(
          'Tes scenarios retraite',
          style: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        centerTitle: false,
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  SCENARIO HELPERS
  // ════════════════════════════════════════════════════════════════

  Color _scenarioColor(int index) {
    switch (index) {
      case 0:
        return MintColors.trajectoryPrudent;
      case 1:
        return MintColors.trajectoryBase;
      case 2:
        return MintColors.trajectoryOptimiste;
      default:
        return MintColors.trajectoryBase;
    }
  }

  IconData _scenarioIcon(int index) {
    switch (index) {
      case 0:
        return Icons.shield_outlined;
      case 1:
        return Icons.balance_outlined;
      case 2:
        return Icons.trending_up;
      default:
        return Icons.balance_outlined;
    }
  }

  // ════════════════════════════════════════════════════════════════
  //  SOURCES
  // ════════════════════════════════════════════════════════════════

  Widget _buildSources() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: const BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sources',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ...narration.sources.map(
            (source) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '\u2022 ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textMuted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      source,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  DISCLAIMER
  // ════════════════════════════════════════════════════════════════

  Widget _buildDisclaimer() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        narration.disclaimer,
        textAlign: TextAlign.center,
        style: GoogleFonts.inter(
          fontSize: 11,
          color: MintColors.textMuted,
          height: 1.5,
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
//  SCENARIO CARD WIDGET
// ════════════════════════════════════════════════════════════════

class _ScenarioCard extends StatelessWidget {
  final NarratedScenario scenario;
  final Color color;
  final IconData icon;

  const _ScenarioCard({
    required this.scenario,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: const BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(8),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Color-coded left border
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.only(
                topLeft: const Radius.circular(16),
                bottomLeft: const Radius.circular(16),
              ),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header: icon + label
                  Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color.withAlpha(25),
                          borderRadius: const BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              scenario.label,
                              style: GoogleFonts.montserrat(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: MintColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Rendement : ${scenario.annualReturnPct.toStringAsFixed(scenario.annualReturnPct == scenario.annualReturnPct.roundToDouble() ? 0 : 1)}%/an',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: MintColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Capital amount
                  Text(
                    'CHF ${_formatChf(scenario.capitalFinal)}',
                    style: GoogleFonts.montserrat(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Monthly income
                  Text(
                    '~CHF ${_formatChf(scenario.monthlyIncome)}/mois',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Divider
                  Container(
                    height: 1,
                    color: MintColors.lightBorder,
                  ),
                  const SizedBox(height: 16),
                  // Narrative text
                  Text(
                    scenario.narrative,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Format CHF with Swiss apostrophe grouping (e.g. 1'250'000).
  String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    if (intVal < 0) buffer.write('-');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
