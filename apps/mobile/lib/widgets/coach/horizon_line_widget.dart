import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P7-F  Ligne d'horizon — Le mur de la fin des droits
//  Charte : L7 (Métaphore horizon) + L6 (Chiffre-choc)
//  Source : LACI art. 27-30, LASV (aide sociale)
// ────────────────────────────────────────────────────────────

class HorizonLineWidget extends StatelessWidget {
  const HorizonLineWidget({
    super.key,
    required this.monthlyBenefit,
    required this.totalDays,
    this.daysConsumed = 0,
  });

  final double monthlyBenefit;
  final int totalDays;
  final int daysConsumed;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final daysLeft = (totalDays - daysConsumed).clamp(0, totalDays);
    final monthsLeft = daysLeft / 21.7;
    final progressFraction = daysConsumed / totalDays;

    final s = S.of(context)!;
    return Semantics(
      label: 'Ligne horizon fin droits chomage',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTimeline(s, progressFraction, daysLeft, monthsLeft),
                  const SizedBox(height: 24),
                  _buildAfterLine(s),
                  const SizedBox(height: 16),
                  _buildChiffreChoc(s),
                  const SizedBox(height: 16),
                  _buildDisclaimer(s),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.successionBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🌅', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.horizonLineHeaderTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.horizonLineHeaderSubtitle(_fmt(monthlyBenefit)),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(S s, double fraction, int daysLeft, double monthsLeft) {
    const zoneColor = MintColors.scoreExcellent;
    const wallColor = MintColors.scoreCritique;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.horizonLineTrajectory,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 16),
        // Visual timeline
        SizedBox(
          height: 80,
          child: CustomPaint(
            size: const Size(double.infinity, 80),
            painter: _HorizonPainter(fraction: fraction),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.horizonLineSecureZone,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: zoneColor),
                ),
                Text(
                  s.horizonLineChfPerMonth(_fmt(monthlyBenefit)),
                  style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary),
                ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  s.horizonLineWall,
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: wallColor),
                ),
                Text(
                  s.horizonLineWallDay(totalDays.toString()),
                  style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
        if (daysLeft > 0) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: MintColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              s.horizonLineDaysLeft(daysLeft.toString(), monthsLeft.toStringAsFixed(1)),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: MintColors.info,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAfterLine(S s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.horizonLineAfterTitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.scoreCritique,
            ),
          ),
          const SizedBox(height: 8),
          _buildAfterItem(s.horizonLineAfterSocialAid, s.horizonLineAfterSocialAidSub),
          _buildAfterItem(s.horizonLineAfterComplementary, s.horizonLineAfterComplementarySub),
          _buildAfterItem(s.horizonLineAfterSavings, s.horizonLineAfterSavingsSub),
        ],
      ),
    );
  }

  Widget _buildAfterItem(String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.chevron_right, color: MintColors.scoreCritique, size: 16),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 11,
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

  Widget _buildChiffreChoc(S s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.scoreCritique.withValues(alpha: 0.08),
            MintColors.scoreCritique.withValues(alpha: 0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.horizonLineChiffreChocTitle(_fmt(monthlyBenefit)),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  s.horizonLineChiffreChocBody,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
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

  Widget _buildDisclaimer(S s) {
    return Text(
      s.horizonLineDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}

class _HorizonPainter extends CustomPainter {
  const _HorizonPainter({required this.fraction});
  final double fraction;

  @override
  void paint(Canvas canvas, Size size) {
    final safeWidth = size.width * (1 - fraction);
    final consumedWidth = size.width * fraction;
    const barHeight = 28.0;
    const top = 20.0;

    // Consumed (grey)
    if (consumedWidth > 0) {
      final consumed = Paint()..color = MintColors.greyBorderLight;
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          0, top, consumedWidth, top + barHeight,
          topLeft: const Radius.circular(8),
          bottomLeft: const Radius.circular(8),
        ),
        consumed,
      );
    }

    // Safe zone (green)
    if (safeWidth > 2) {
      final safe = Paint()..color = MintColors.scoreExcellent.withValues(alpha: 0.85);
      canvas.drawRRect(
        RRect.fromLTRBAndCorners(
          consumedWidth, top, size.width - 4, top + barHeight,
          topRight: const Radius.circular(8),
          bottomRight: const Radius.circular(8),
        ),
        safe,
      );
    }

    // Wall (red vertical)
    final wall = Paint()
      ..color = MintColors.scoreCritique
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(size.width - 2, 0),
      Offset(size.width - 2, size.height),
      wall,
    );
  }

  @override
  bool shouldRepaint(_HorizonPainter old) => old.fraction != fraction;
}
