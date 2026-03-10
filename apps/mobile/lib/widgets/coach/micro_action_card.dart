import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/micro_action_engine.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Card widget for a single [MicroAction].
///
/// Displays: urgency badge + icon, title, description,
/// time estimate, CHF impact (if available), and CTA deeplink.
///
/// Used in:
/// - Post-check-in success screen
/// - Coach Agir screen (recommended actions section)
/// - Pulse screen (optional)
class MicroActionCard extends StatelessWidget {
  final MicroAction action;

  const MicroActionCard({super.key, required this.action});

  @override
  Widget build(BuildContext context) {
    final urgencyColor = _urgencyColor(action.urgency);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: urgencyColor, width: 3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push(action.deeplink),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: urgencyColor.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(action.icon, size: 20, color: urgencyColor),
                ),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        action.title,
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MintColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        action.description,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: MintColors.textSecondary,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      _buildMetaRow(),
                    ],
                  ),
                ),

                // Chevron
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: MintColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetaRow() {
    return Row(
      children: [
        // Time estimate
        Icon(Icons.schedule, size: 12, color: MintColors.textMuted),
        const SizedBox(width: 3),
        Text(
          '${action.estimatedMinutes} min',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
          ),
        ),

        // Impact CHF
        if (action.estimatedImpactChf != null) ...[
          const SizedBox(width: 12),
          Icon(Icons.savings_outlined, size: 12, color: MintColors.success),
          const SizedBox(width: 3),
          Text(
            '~CHF ${action.estimatedImpactChf!.round()}/an',
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: MintColors.success,
            ),
          ),
        ],

        // Source
        if (action.source != null) ...[
          const SizedBox(width: 12),
          Text(
            action.source!,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ],
    );
  }

  static Color _urgencyColor(MicroActionUrgency urgency) {
    return switch (urgency) {
      MicroActionUrgency.critical => MintColors.error,
      MicroActionUrgency.high => MintColors.warning,
      MicroActionUrgency.medium => MintColors.primary,
      MicroActionUrgency.low => MintColors.textSecondary,
    };
  }
}

/// Vertical list of [MicroActionCard]s with a section header.
///
/// Used in post-check-in and Agir screen.
class MicroActionSection extends StatelessWidget {
  final List<MicroAction> actions;
  final String title;

  const MicroActionSection({
    super.key,
    required this.actions,
    this.title = 'Prochaines etapes',
  });

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            title,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
        ),
        ...actions.map((a) => MicroActionCard(action: a)),
      ],
    );
  }
}
