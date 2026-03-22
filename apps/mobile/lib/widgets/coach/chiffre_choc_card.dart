import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/coach/animated_chiffre.dart';
import 'package:mint_mobile/widgets/coach/chat_card_entrance.dart';

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
    return ChatCardEntrance(
      child: Container(
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
                  style: MintTextStyles.micro(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Animated counter
          AnimatedChiffre(
            value: value,
            prefix: prefix,
            suffix: suffix,
            textStyle: MintTextStyles.displayMedium(color: color).copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
            duration: const Duration(milliseconds: 1000),
          ),
          const SizedBox(height: 8),

          // Message — LLM narrative (if available) or static fallback
          if (narrativeMessage != null && narrativeMessage!.isNotEmpty) ...[
            Text(
              narrativeMessage!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(height: 1.5, fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.auto_awesome, size: 12, color: MintColors.coachAccent),
                const SizedBox(width: 4),
                Text(
                  'Coach MINT',
                  style: MintTextStyles.labelSmall(color: MintColors.textMuted),
                ),
              ],
            ),
          ] else
            Text(
              message,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(height: 1.5),
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
                    style: MintTextStyles.bodySmall().copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}
