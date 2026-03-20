import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  DATA QUALITY CARD — LOT 4 / Retirement Dashboard
// ────────────────────────────────────────────────────────────
//
//  Affiche les champs connus (coches vertes) et manquants (points ?).
//  CTA "Enrichir" avec estimation d'impact sur la precision.
//
//  Exemples :
//    knownFields  : ["AVS estimee : ~2'100/mois", "Canton : VD"]
//    missingFields: ["LPP : donnee manquante", "3a : donnee manquante"]
//    enrichImpact : "+15% precision"
//
//  Widget pur — aucune dependance Provider.
// ────────────────────────────────────────────────────────────

class DataQualityCard extends StatelessWidget {
  /// Champs renseignes (affichage avec icone validation).
  final List<String> knownFields;

  /// Champs manquants (affichage avec icone interrogation).
  final List<String> missingFields;

  /// Callback du bouton "Enrichir". Si null, navigue vers /scan.
  final VoidCallback? onEnrich;

  /// Texte d'impact potentiel (ex. "+15% pr\u00e9cision"). Optionnel.
  final String? enrichImpact;

  /// S46: 3-axis scores (0-100). When provided, displays axis breakdown.
  final double? completenessScore;
  final double? accuracyScore;
  final double? freshnessScore;
  final double? combinedScore;

  const DataQualityCard({
    super.key,
    required this.knownFields,
    required this.missingFields,
    this.onEnrich,
    this.enrichImpact,
    this.completenessScore,
    this.accuracyScore,
    this.freshnessScore,
    this.combinedScore,
  });

  @override
  Widget build(BuildContext context) {
    // Ne rien afficher si tout est renseigne et aucun CTA utile
    if (knownFields.isEmpty && missingFields.isEmpty) {
      return const SizedBox.shrink();
    }

    final l = S.of(context)!;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(l),
          if (completenessScore != null) ...[
            const SizedBox(height: 14),
            _buildAxisBreakdown(l),
          ],
          if (knownFields.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSection(
              title: l.dataQualityKnownSection,
              items: knownFields,
              isKnown: true,
            ),
          ],
          if (missingFields.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildSection(
              title: l.dataQualityMissingSection,
              items: missingFields,
              isKnown: false,
            ),
          ],
          if (missingFields.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildEnrichButton(context, l),
          ],
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  HEADER
  // ────────────────────────────────────────────────────────────

  Widget _buildHeader(S l) {
    final hasGaps = missingFields.isNotEmpty;
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: hasGaps
                ? MintColors.scoreAttention.withValues(alpha: 0.12)
                : MintColors.scoreExcellent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            hasGaps
                ? Icons.manage_search_outlined
                : Icons.check_circle_outline,
            color: hasGaps
                ? MintColors.scoreAttention
                : MintColors.scoreExcellent,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.dataQualityTitle,
                style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              Text(
                hasGaps
                    ? l.dataQualityMissingCount('${missingFields.length}')
                    : l.dataQualityComplete,
                style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
              ),
            ],
          ),
        ),
        if (enrichImpact != null)
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: MintColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              enrichImpact!,
              style: MintTextStyles.labelSmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }

  // ────────────────────────────────────────────────────────────
  //  3-AXIS BREAKDOWN (S46)
  // ────────────────────────────────────────────────────────────

  Widget _buildAxisBreakdown(S l) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          _buildAxisBar(l.dataQualityCompleteness, completenessScore!, MintColors.primary),
          const SizedBox(height: 8),
          _buildAxisBar(l.dataQualityAccuracy, accuracyScore ?? 25, MintColors.scoreExcellent),
          const SizedBox(height: 8),
          _buildAxisBar(l.dataQualityFreshness, freshnessScore ?? 50, MintColors.info),
          if (combinedScore != null) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: MintColors.lightBorder),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l.dataQualityCombined,
                  style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                Text(
                  '${combinedScore!.round()}\u00a0%',
                  style: MintTextStyles.bodyMedium(color: _scoreColor(combinedScore!)).copyWith(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAxisBar(String label, double value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 85,
          child: Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (value / 100).clamp(0, 1),
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 36,
          child: Text(
            '${value.round()}%',
            textAlign: TextAlign.right,
            style: MintTextStyles.labelSmall(color: _scoreColor(value)).copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }

  Color _scoreColor(double value) {
    if (value >= 70) return MintColors.scoreExcellent;
    if (value >= 40) return MintColors.scoreAttention;
    return MintColors.error;
  }

  // ────────────────────────────────────────────────────────────
  //  SECTION
  // ────────────────────────────────────────────────────────────

  Widget _buildSection({
    required String title,
    required List<String> items,
    required bool isKnown,
  }) {
    final color =
        isKnown ? MintColors.scoreExcellent : MintColors.scoreAttention;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600, letterSpacing: 0.3),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isKnown
                ? MintColors.scoreExcellent.withValues(alpha: 0.04)
                : MintColors.scoreAttention.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.15),
            ),
          ),
          child: Column(
            children: items
                .map((item) => _buildItem(
                      text: item,
                      isKnown: isKnown,
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildItem({required String text, required bool isKnown}) {
    final color =
        isKnown ? MintColors.scoreExcellent : MintColors.scoreAttention;
    final icon = isKnown ? Icons.check_circle_outline : Icons.help_outline;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: MintTextStyles.bodySmall(color: isKnown ? MintColors.textPrimary : MintColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  //  ENRICH BUTTON
  // ────────────────────────────────────────────────────────────

  Widget _buildEnrichButton(BuildContext context, S l) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onEnrich ?? () => context.push('/scan'),
        icon: const Icon(Icons.edit_outlined, size: 18),
        label: Text(
          enrichImpact != null
              ? l.dataQualityEnrichWithImpact(enrichImpact!)
              : l.dataQualityEnrich,
          style: MintTextStyles.bodyMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: MintColors.primary,
          side: const BorderSide(color: MintColors.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        ),
      ),
    );
  }
}
