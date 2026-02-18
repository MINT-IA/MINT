import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Animated "shock figure" card that reveals a personalized financial insight.
///
/// Uses [TweenAnimationBuilder] for a smooth counter roll-up effect.
/// Each card displays:
///   - An animated CHF value (the "chiffre choc")
///   - A short explanatory message
///   - A legal source reference
///   - A CTA button routing to the relevant simulator
class ChiffreChocCard extends StatelessWidget {
  final double value;
  final String prefix;
  final String suffix;
  final String message;
  final String source;
  final String ctaLabel;
  final String ctaRoute;
  final IconData icon;
  final Color color;

  const ChiffreChocCard({
    super.key,
    required this.value,
    this.prefix = 'CHF ',
    this.suffix = '',
    required this.message,
    required this.source,
    required this.ctaLabel,
    required this.ctaRoute,
    required this.icon,
    this.color = MintColors.coachAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border(
          left: BorderSide(color: color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + source row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  source,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: MintColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Animated counter
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, animatedValue, _) {
              return Text(
                '$prefix${_formatNumber(animatedValue)}$suffix',
                style: GoogleFonts.montserrat(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: color,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              );
            },
          ),
          const SizedBox(height: 8),

          // Message
          Text(
            message,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: MintColors.textPrimary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),

          // CTA
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => context.push(ctaRoute),
              style: TextButton.styleFrom(
                backgroundColor: color.withValues(alpha: 0.08),
                foregroundColor: color,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ctaLabel,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(double n) {
    if (n >= 1000) {
      final formatted = n.toStringAsFixed(0);
      final buffer = StringBuffer();
      int count = 0;
      for (int i = formatted.length - 1; i >= 0; i--) {
        buffer.write(formatted[i]);
        count++;
        if (count % 3 == 0 && i > 0) buffer.write("'");
      }
      return buffer.toString().split('').reversed.join();
    }
    return n.toStringAsFixed(0);
  }
}
