import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

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
  required int age,
  required String civilStatus,
  required int childrenCount,
  required String employmentStatus,
  required double monthlyNetIncome,
  required String canton,
  required S s,
}) {
  final suggestions = <LifeEventSuggestion>[];

  // ── Family ─────────────────────────────────────────────

  if (civilStatus == 'single' || civilStatus == 'concubinage') {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugMariage,
      reason: s.lifeEventSugMariageReason,
      icon: Icons.favorite_outline,
      route: '/mariage',
      color: MintColors.error,
    ));
  }

  if (civilStatus == 'concubinage') {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugConcubinage,
      reason: s.lifeEventSugConcubinageReason,
      icon: Icons.people_outline,
      route: '/concubinage',
      color: MintColors.warning,
    ));
  }

  if (civilStatus == 'married' && childrenCount == 0) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugNaissance,
      reason: s.lifeEventSugNaissanceReason,
      icon: Icons.child_care,
      route: '/naissance',
      color: MintColors.info,
    ));
  }

  // ── Succession / Donation (age-driven) ─────────────────

  if (age >= 50 && childrenCount > 0) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugSuccession,
      reason: s.lifeEventSugSuccessionReason,
      icon: Icons.account_balance_outlined,
      route: '/succession',
      color: MintColors.primary,
    ));
  }

  if (age >= 55 && monthlyNetIncome * 12 > 100000) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugDonation,
      reason: s.lifeEventSugDonationReason,
      icon: Icons.card_giftcard,
      route: '/life-event/donation',
      color: MintColors.info,
    ));
  }

  // ── Professional ───────────────────────────────────────

  if (age <= 28) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugPremierEmploi,
      reason: s.lifeEventSugPremierEmploiReason,
      icon: Icons.school_outlined,
      route: '/first-job',
      color: MintColors.info,
    ));
  }

  if (employmentStatus == 'employee' && age >= 30 && age <= 50) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugChangementEmploi,
      reason: s.lifeEventSugChangementEmploiReason,
      icon: Icons.swap_horiz,
      route: '/simulator/job-comparison',
      color: MintColors.primary,
    ));
  }

  if (employmentStatus == 'independent') {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugOutilsIndependant,
      reason: s.lifeEventSugOutilsIndependantReason,
      icon: Icons.storefront_outlined,
      route: '/segments/independant',
      color: MintColors.success,
    ));
  }

  if (age >= 55) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugRetraite,
      reason: s.lifeEventSugRetraiteReason,
      icon: Icons.elderly,
      route: '/retraite',
      color: MintColors.primary,
    ));
  }

  // ── Housing ────────────────────────────────────────────

  if (monthlyNetIncome >= 5000 && age >= 25 && age <= 50) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugAchatImmo,
      reason: s.lifeEventSugAchatImmoReason,
      icon: Icons.home_outlined,
      route: '/hypotheque',
      color: MintColors.success,
    ));
  }

  // ── Mobility ───────────────────────────────────────────

  // High-tax cantons → suggest canton move
  const highTaxCantons = ['GE', 'VD', 'NE', 'JU', 'BE', 'BS'];
  if (highTaxCantons.contains(canton.toUpperCase())) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugDemenagement,
      reason: s.lifeEventSugDemenagementReason,
      icon: Icons.map_outlined,
      route: '/fiscal',
      color: MintColors.warning,
    ));
  }

  // ── Health ─────────────────────────────────────────────

  if (childrenCount > 0 || monthlyNetIncome > 6000) {
    suggestions.add(LifeEventSuggestion(
      title: s.lifeEventSugInvalidite,
      reason: s.lifeEventSugInvaliditeReason,
      icon: Icons.accessible,
      route: '/invalidite',
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
                      S.of(context)!.lifeEventSuggestionsHeader,
                      style: MintTextStyles.titleLarge(color: MintColors.textPrimary),
                    ),
                    Text(
                      S.of(context)!.lifeEventSuggestionsSubheader,
                      style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
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
      color: MintColors.transparent,
      child: Semantics(
        label: suggestion.title,
        button: true,
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
                      style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      suggestion.reason,
                      style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
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
                  S.of(context)!.lifeEventSuggestionsSimuler,
                  style: MintTextStyles.labelSmall(color: suggestion.color).copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}
