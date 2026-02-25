/// FRI Dashboard Card — Sprint S39.
///
/// Displays the Financial Resilience Index with:
///   - Total score in a large circle (color-coded)
///   - 4 horizontal bars (L, F, R, S) with labels
///   - Top improvement action with estimated delta
///   - Confidence gate: shows enrichment prompt if < 50%
///
/// Display rules (CRITICAL):
///   - Only shown if confidenceScore >= 50%
///   - Always show breakdown (never total alone)
///   - Always show top improvement action with estimated delta
///   - NEVER say "faible", "mauvais", "insuffisant"
///   - NEVER compare to other users
///   - Use: "solidite", "progression", "point le plus fragile"
///
/// Design:
///   - Material 3 Card with MintColors
///   - Montserrat headings, Inter body (GoogleFonts)
///   - Animated entrance (fade + slide)
///
/// All text in French (informal "tu"). No banned terms.
///
/// References:
///   - ONBOARDING_ARBITRAGE_ENGINE.md § V
///   - LAVS art. 21-29, LPP art. 14-16, LIFD art. 38
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/fri_breakdown_bars.dart';
import 'package:mint_mobile/widgets/fri_action_suggestion.dart';

/// Main FRI card for the dashboard.
///
/// Shows a color-coded total score circle, 4-component breakdown bars,
/// and the top improvement action. If [confidenceScore] < 50%, displays
/// an enrichment prompt instead of the score.
class FriDashboardCard extends StatefulWidget {
  /// Liquidity component score (0-25).
  final double liquidite;

  /// Fiscal efficiency component score (0-25).
  final double fiscalite;

  /// Retirement readiness component score (0-25).
  final double retraite;

  /// Structural risk component score (0-25).
  final double risque;

  /// Total FRI score (0-100).
  final double total;

  /// Profile confidence score (0-100). If < 50%, enrichment prompt is shown.
  final double confidenceScore;

  /// French text describing the top improvement action.
  final String topAction;

  /// Estimated FRI point improvement from the top action.
  final double topActionDelta;

  /// Callback when the card is tapped.
  final VoidCallback? onTap;

  const FriDashboardCard({
    super.key,
    required this.liquidite,
    required this.fiscalite,
    required this.retraite,
    required this.risque,
    required this.total,
    required this.confidenceScore,
    required this.topAction,
    required this.topActionDelta,
    this.onTap,
  });

  @override
  State<FriDashboardCard> createState() => _FriDashboardCardState();
}

class _FriDashboardCardState extends State<FriDashboardCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: const Offset.zero,
    ).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  /// Returns the color for the total FRI score.
  Color _scoreColor(double score) {
    if (score >= 75) return MintColors.scoreExcellent;
    if (score >= 55) return MintColors.scoreBon;
    if (score >= 35) return MintColors.scoreAttention;
    return MintColors.scoreCritique;
  }

  /// Returns a label for the score tier (never uses banned terms).
  String _scoreLabel(double score) {
    if (score >= 75) return 'Solidite excellente';
    if (score >= 55) return 'Bonne solidite';
    if (score >= 35) return 'En progression';
    return 'En construction';
  }

  @override
  Widget build(BuildContext context) {
    // Confidence gate: if < 50%, show enrichment prompt
    if (widget.confidenceScore < 50) {
      return _buildEnrichmentPrompt();
    }

    return _buildScoreCard();
  }

  /// Enrichment prompt shown when confidence < 50%.
  Widget _buildEnrichmentPrompt() {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MintColors.card,
              borderRadius: const BorderRadius.circular(20),
              border: Border.all(color: MintColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: MintColors.info.withAlpha(15),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: MintColors.info.withAlpha(20),
                        borderRadius: const BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.insights_rounded,
                        color: MintColors.info,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Ton indice de solidite',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: MintColors.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Enrichment message
                Text(
                  'Complete ton profil pour decouvrir ton indice '
                  'de solidite financiere. Il te faut encore '
                  'quelques informations.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: MintColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 14),

                // Confidence progress
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.circular(4),
                        child: SizedBox(
                          height: 6,
                          child: LinearProgressIndicator(
                            value: widget.confidenceScore / 100.0,
                            backgroundColor: MintColors.info.withAlpha(20),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              MintColors.info,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '${widget.confidenceScore.toStringAsFixed(0)}%',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: MintColors.info,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // CTA
                Text(
                  'Completer mon profil',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.info,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Full score card shown when confidence >= 50%.
  Widget _buildScoreCard() {
    final scoreColor = _scoreColor(widget.total);
    final scoreLabel = _scoreLabel(widget.total);

    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MintColors.card,
              borderRadius: const BorderRadius.circular(20),
              border: Border.all(color: MintColors.lightBorder),
              boxShadow: [
                BoxShadow(
                  color: scoreColor.withAlpha(20),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header: title + score circle ──
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ta solidite financiere',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: MintColors.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            scoreLabel,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              color: scoreColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Score circle
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withAlpha(18),
                        border: Border.all(color: scoreColor, width: 3),
                      ),
                      child: Center(
                        child: Text(
                          widget.total.toStringAsFixed(0),
                          style: GoogleFonts.montserrat(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: scoreColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // ── Breakdown bars ──
                FriBreakdownBars(
                  liquidite: widget.liquidite,
                  fiscalite: widget.fiscalite,
                  retraite: widget.retraite,
                  risque: widget.risque,
                ),
                const SizedBox(height: 18),

                // ── Divider ──
                Container(
                  height: 1,
                  color: MintColors.lightBorder,
                ),
                const SizedBox(height: 14),

                // ── Top action suggestion ──
                FriActionSuggestion(
                  actionText: widget.topAction,
                  estimatedDelta: widget.topActionDelta,
                  onTap: widget.onTap,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
