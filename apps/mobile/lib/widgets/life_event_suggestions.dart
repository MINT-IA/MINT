import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  LIFE EVENT SUGGESTIONS
// ────────────────────────────────────────────────────────────
//
//  Contextual cards suggesting relevant life event modules
//  based on user profile data.
//
//  Used in:
//    - Financial report screen (post-wizard)
//    - Track tab (proactive suggestions)
// ────────────────────────────────────────────────────────────

class LifeEventSuggestion {
  final String title;
  final String reason;
  final IconData icon;
  final String route;
  final Color color;

  const LifeEventSuggestion({
    required this.title,
    required this.reason,
    required this.icon,
    required this.route,
    required this.color,
  });
}

/// Generates contextual life event suggestions based on profile.
List<LifeEventSuggestion> buildLifeEventSuggestions({
  required BuildContext context,
  required int age,
  required String civilStatus,
  required int childrenCount,
  required String employmentStatus,
  required double monthlyNetIncome,
  required String canton,
}) {
  final s = S.of(context)!;
  final suggestions = <LifeEventSuggestion>[];

  // ── Family ─────────────────────────────────────────────

  if (civilStatus == 'single' || civilStatus == 'concubinage') {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventMarriage,
      reason: s.lifeEventMarriageReason,
      icon: Icons.favorite_outline,
      route: '/mariage',
      color: MintColors.error,
    ));
  }

  if (civilStatus == 'concubinage') {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventConcubinage,
      reason: s.lifeEventConcubinageReason,
      icon: Icons.people_outline,
      route: '/concubinage',
      color: MintColors.warning,
    ));
  }

  if (civilStatus == 'married' && childrenCount == 0) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventBirth,
      reason: s.lifeEventBirthReason,
      icon: Icons.child_care,
      route: '/naissance',
      color: MintColors.info,
    ));
  }

  // ── Succession / Donation (age-driven) ─────────────────

  if (age >= 50 && childrenCount > 0) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSuccession,
      reason: s.lifeEventSuccessionReason,
      icon: Icons.account_balance_outlined,
      route: '/life-event/succession',
      color: MintColors.primary,
    ));
  }

  if (age >= 55 && monthlyNetIncome * 12 > 100000) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventDonation,
      reason: s.lifeEventDonationReason,
      icon: Icons.card_giftcard,
      route: '/life-event/donation',
      color: MintColors.info,
    ));
  }

  // ── Professional ───────────────────────────────────────

  if (age <= 28) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventFirstJob,
      reason: s.lifeEventFirstJobReason,
      icon: Icons.school_outlined,
      route: '/first-job',
      color: MintColors.info,
    ));
  }

  if (employmentStatus == 'employee' && age >= 30 && age <= 50) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventJobChange,
      reason: s.lifeEventJobChangeReason,
      icon: Icons.swap_horiz,
      route: '/simulator/job-comparison',
      color: MintColors.primary,
    ));
  }

  if (employmentStatus == 'independent') {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSelfEmployedTools,
      reason: s.lifeEventSelfEmployedReason,
      icon: Icons.storefront_outlined,
      route: '/segments/independant',
      color: MintColors.success,
    ));
  }

  if (age >= 55) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventRetirementPlanning,
      reason: s.lifeEventRetirementReason,
      icon: Icons.elderly,
      route: '/retirement',
      color: MintColors.primary,
    ));
  }

  // ── Housing ────────────────────────────────────────────

  if (monthlyNetIncome >= 5000 && age >= 25 && age <= 50) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventHomePurchase,
      reason: s.lifeEventHomePurchaseReason,
      icon: Icons.home_outlined,
      route: '/mortgage/affordability',
      color: MintColors.success,
    ));
  }

  // ── Mobility ───────────────────────────────────────────

  // High-tax cantons → suggest canton move
  const highTaxCantons = ['GE', 'VD', 'NE', 'JU', 'BE', 'BS'];
  if (highTaxCantons.contains(canton.toUpperCase())) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventCantonMove,
      reason: s.lifeEventCantonMoveReason,
      icon: Icons.map_outlined,
      route: '/fiscal',
      color: MintColors.warning,
    ));
  }

  // ── Health ─────────────────────────────────────────────

  if (childrenCount > 0 || monthlyNetIncome > 6000) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventDisability,
      reason: s.lifeEventDisabilityReason,
      icon: Icons.accessible,
      route: '/simulator/disability-gap',
      color: MintColors.error,
    ));
  }

  // Cap at 5 suggestions
  return suggestions.take(5).toList();
}

/// Widget that displays life event suggestion cards.
class LifeEventSuggestionsSection extends StatelessWidget {
  final List<LifeEventSuggestion> suggestions;

  const LifeEventSuggestionsSection({
    super.key,
    required this.suggestions,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MintColors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.timeline,
                  color: MintColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      S.of(context)!.lifeEventNextTitle,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    Text(
                      S.of(context)!.lifeEventNextSubtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (final suggestion in suggestions) ...[
            _buildSuggestionCard(context, suggestion),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _buildSuggestionCard(
      BuildContext context, LifeEventSuggestion suggestion) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => context.push(suggestion.route),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: suggestion.color.withValues(alpha: 0.20),
            ),
            boxShadow: [
              BoxShadow(
                color: suggestion.color.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: suggestion.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(suggestion.icon,
                    color: suggestion.color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.title,
                      style: GoogleFonts.montserrat(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      suggestion.reason,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: MintColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: suggestion.color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  S.of(context)!.lifeEventSimulate,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: suggestion.color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
