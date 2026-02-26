import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/forecaster_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/coach/mint_trajectory_chart.dart';

/// Trajectory chart section — wraps MintTrajectoryChart with title.
///
/// Pure presentational widget. All data passed as parameters.
class TrajectoryCard extends StatelessWidget {
  final CoachProfile profile;
  final ProjectionResult projection;
  final ProjectionResult? etSiProjection;

  const TrajectoryCard({
    super.key,
    required this.profile,
    required this.projection,
    this.etSiProjection,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n?.coachTrajectory ?? 'Ta trajectoire',
          style: GoogleFonts.montserrat(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: MintColors.card,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: MintTrajectoryChart(
            result: etSiProjection ?? projection,
            goalALabel: profile.goalA.label,
            goalAType: profile.goalA.type,
            initialDebt: profile.dettes.totalDettes,
            onTap: () => context.push('/retirement/projection'),
          ),
        ),
      ],
    );
  }
}
