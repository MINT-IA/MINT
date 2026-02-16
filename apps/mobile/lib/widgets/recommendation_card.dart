import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:mint_mobile/models/recommendation.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:provider/provider.dart';

class RecommendationCard extends StatelessWidget {
  final Recommendation recommendation;
  const RecommendationCard({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final hasDebt = context.watch<ProfileProvider>().profile?.hasDebt ?? false;

    // Gate the entire recommendation card when debt is active
    // except for debt-related recommendations themselves
    final isDebtRelated = recommendation.kind.toLowerCase().contains('debt') ||
        recommendation.kind.toLowerCase().contains('dette') ||
        recommendation.title.toLowerCase().contains('dette') ||
        recommendation.title.toLowerCase().contains('desendettement');

    if (hasDebt && !isDebtRelated) {
      return SafeModeGate(
        hasDebt: true,
        lockedTitle: 'Recommandation suspendue',
        lockedMessage:
            'Cette recommandation est desactivee en mode protection. '
            'Ta priorite est de stabiliser ta situation financiere.',
        child: const SizedBox.shrink(),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: MintColors.primary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    recommendation.kind.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                const Icon(Icons.info_outline, size: 18, color: MintColors.textMuted),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              recommendation.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              recommendation.summary,
              style: const TextStyle(
                fontSize: 14,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.flash_on, size: 16, color: MintColors.primary),
                const SizedBox(width: 8),
                const Text(
                  'Impact estimé :',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: MintColors.textPrimary),
                ),
                const Spacer(),
                Text(
                  'CHF ${recommendation.impact.amountCHF.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: MintColors.primary),
                ),
                Text(
                  ' / ${recommendation.impact.period.name}',
                  style: const TextStyle(fontSize: 11, color: MintColors.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (recommendation.evidenceLinks.isNotEmpty)
              const Text(
                'SOURCES & PREUVES',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: MintColors.textMuted, letterSpacing: 0.5),
              ),
            if (recommendation.evidenceLinks.isNotEmpty) const SizedBox(height: 8),
            for (var link in recommendation.evidenceLinks)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: InkWell(
                  onTap: () async {
                    final uri = Uri.tryParse(link.url);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Row(
                    children: [
                      const Icon(Icons.link, size: 14, color: MintColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          link.label,
                          style: const TextStyle(fontSize: 12, color: MintColors.primary, decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (recommendation.evidenceLinks.isNotEmpty) const SizedBox(height: 8),
            const SizedBox(height: 16),
            if (recommendation.nextActions.isNotEmpty)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    final action = recommendation.nextActions.first;
                    if (action.deepLink != null && action.deepLink!.isNotEmpty) {
                      context.push(action.deepLink!);
                    }
                  },
                  child: Text(recommendation.nextActions.first.label),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
