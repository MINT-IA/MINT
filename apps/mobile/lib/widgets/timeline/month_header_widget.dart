/// MonthHeaderWidget — collapsible month header for timeline grouping.
///
/// Phase 18: Full Living Timeline. Displays month/year label with
/// a chevron toggle. Current month starts expanded, past months collapsed.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:mint_mobile/models/timeline_node.dart';
import 'package:mint_mobile/theme/colors.dart';

class MonthHeaderWidget extends StatelessWidget {
  final TimelineMonth month;
  final bool isCollapsed;
  final VoidCallback onToggle;

  const MonthHeaderWidget({
    super.key,
    required this.month,
    required this.isCollapsed,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          children: [
            Text(
              month.label.toUpperCase(),
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
                color: MintColors.textSecondary,
              ),
            ),
            const Spacer(),
            Icon(
              isCollapsed ? Icons.expand_more : Icons.expand_less,
              color: MintColors.textMutedAaa,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
