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
  final String? narrativeMessage; // LLM-enriched emotional message (null if no BYOK)
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
    this.narrativeMessage,
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
        borderRadius: const Borderconst Radius.circular(20),
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
                  borderRadius: const Borderconst Radius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: MintColors.surface,
                  borderRadius: const Borderconst Radius.circular(6),
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

          // Message — LLM narrative (if available) or static fallback
          if (narrativeMessage != null && narrativeMessage!.isNotEmpty) ...[
            Text(
              narrativeMessage!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.5,
                color: MintColors.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 12, color: MintColors.coachAccent),
                const SizedBox(width: 4),
                Text(
                  'Coach MINT',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ] else
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
                  borderRadius: const Borderconst Radius.circular(12),
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
