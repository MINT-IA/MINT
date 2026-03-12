import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Hero card showing the GAP between current income and projected retirement.
///
/// Displays a chiffre choc (gap amount), before/after comparison,
/// a relatable metaphor, confidence bar, and optional scan CTA.
class HeroGapCard extends StatelessWidget {
  final double currentMonthlyNet;
  final double projectedMonthlyRetirement;
  final double confidencePercent;
  final int? missingFieldsCount;
  final int? confidenceBoostPercent;
  final VoidCallback? onScanTap;

  const HeroGapCard({
    super.key,
    required this.currentMonthlyNet,
    required this.projectedMonthlyRetirement,
    required this.confidencePercent,
    this.missingFieldsCount,
    this.confidenceBoostPercent,
    this.onScanTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final gap = currentMonthlyNet - projectedMonthlyRetirement;
    final hasGap = gap > 0;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary,
            MintColors.primary.withValues(alpha: 0.85),
          ],
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Title
          Text(
            hasGap ? s.heroGapTitle : s.heroGapCovered,
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),

          // Hero CHF amount
          _buildHeroAmount(s, gap, hasGap),
          const SizedBox(height: 20),

          // Before / After cards
          _buildBeforeAfter(s),
          const SizedBox(height: 16),

          // Metaphor
          Text(
            _metaphor(s, gap),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),

          // Confidence bar
          _buildConfidenceBar(s),

          // Scanner CTA
          if (onScanTap != null) ...[
            const SizedBox(height: 12),
            _buildScanCta(s),
          ],
        ],
      ),
    );
  }

  Widget _buildHeroAmount(S s, double gap, bool hasGap) {
    final displayValue = hasGap ? gap : projectedMonthlyRetirement;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            'CHF\u00a0${formatChf(displayValue)}',
            style: GoogleFonts.montserrat(
              fontSize: 36,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          Text(
            s.heroGapPerMonth,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBeforeAfter(S s) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _miniCard(s, s.heroGapToday, formatChf(currentMonthlyNet)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Icon(Icons.arrow_forward, color: Colors.white70, size: 20),
        ),
        _miniCard(s, s.heroGapRetirement, formatChf(projectedMonthlyRetirement)),
      ],
    );
  }

  Widget _miniCard(S s, String label, String amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$amount${s.heroGapPerMonth}',
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  String _metaphor(S s, double gap) {
    if (gap <= 0) return s.heroGapMetaphorSmall;
    if (gap > 5000) return s.heroGapMetaphor5k;
    if (gap > 3000) return s.heroGapMetaphor3k;
    if (gap > 1000) return s.heroGapMetaphor1k;
    return s.heroGapMetaphorSmall;
  }

  Widget _buildConfidenceBar(S s) {
    final pct = confidencePercent.clamp(0, 100);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${s.heroGapConfidence} ${pct.toStringAsFixed(0)}\u00a0%',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct / 100,
            minHeight: 6,
            backgroundColor: Colors.white30,
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildScanCta(S s) {
    return GestureDetector(
      onTap: onScanTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.document_scanner, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Text(
            s.heroGapScanCta,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.white,
              decoration: TextDecoration.underline,
              decorationColor: Colors.white70,
            ),
          ),
          if (confidenceBoostPercent != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '+$confidenceBoostPercent\u00a0%',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
