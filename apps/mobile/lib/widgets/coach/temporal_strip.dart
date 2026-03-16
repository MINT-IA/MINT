import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/temporal_priority_service.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Temporal strip widget (P3).
///
/// Horizontal scrollable strip showing time-sensitive items
/// (3a deadlines, tax deadlines, FRI check-ins, etc.).
///
/// Each chip shows: title + time constraint + personal number.
/// Tapping navigates to the relevant simulator via deeplink.
///
/// Consumes [TemporalPriorityService] output.
class TemporalStrip extends StatelessWidget {
  /// Prioritized temporal items to display.
  final List<TemporalItem> items;

  const TemporalStrip({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              const Icon(Icons.schedule, size: 14, color: MintColors.textMuted),
              const SizedBox(width: 6),
              Text(
                '\u00c0 ne pas manquer',
                style: GoogleFonts.montserrat(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textMuted,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) =>
                _buildChip(context, items[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildChip(BuildContext context, TemporalItem item) {
    final color = _colorForUrgency(item.urgency);

    return GestureDetector(
      onTap: () => context.push(item.deeplink),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.20),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Title
            Text(
              item.title,
              style: GoogleFonts.montserrat(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Time constraint
            Row(
              children: [
                Icon(Icons.timer_outlined, size: 11, color: color),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    item.timeConstraint,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Personal number
            Text(
              item.personalNumber,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: MintColors.textSecondary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _colorForUrgency(TemporalUrgency urgency) {
    return switch (urgency) {
      TemporalUrgency.critical => MintColors.error,
      TemporalUrgency.high => MintColors.warning,
      TemporalUrgency.medium => MintColors.primary,
      TemporalUrgency.low => MintColors.textSecondary,
    };
  }
}
